# TicketDive URL解析・内部データ構造および既存OSS調査ノート

本ドキュメントでは、電子チケット販売プラットフォーム「TicketDive（チケットダイブ）」のイベントURL解析、内部SSRデータ構造（Next.js / SuperJSON）、GitHub上の既存実装の網羅的調査、および汎用APIサーバー設計についてまとめます。

---

## 1. 対象URLとURLスキーム仕様

TicketDiveにおけるイベントページURLは以下の体系で提供されています。

| URLパターン | 種別 | リダイレクト挙動・補足 |
|:---|:---|:---|
| `https://ticketdive.com/event/<eventId>` | 公式正規URL | Next.js SSRにより完全なHTML・メタデータを返却 |
| `https://t-dv.com/<eventId>` | 公式短縮URL | `HTTP/2 301 Moved Permanently` で `https://ticketdive.com/event/<eventId>` に自動転送 |
| `https://ticketdive.com/event/fc/<eventId>` | ファンクラブ限定イベント | 一部認証・会員連携用プロパティを含むイベントページ |

### 検証対象イベント例
- URL: `https://ticketdive.com/event/plkt1022` (短縮URL: `https://t-dv.com/plkt1022`)
- イベント名: `2026/10/22(木) 「笑う門にはプリュきたる!! 」@WOMBLIVE`
- 会場: `WOMBLIVE`

---

## 2. GitHub既存リポジトリの網羅的調査結果

GitHub上でTicketDive関連の既存OSS・コードを検索し、フォークして拡張できる実装が存在するか検証しました。

| リポジトリ | 言語 | 概要 | フォーク・拡張可否の評価 |
|:---|:---|:---|:---|
| `M0CH4771/ticket-timetable-builder` | JavaScript / HTML | TicketDive URLから情報を取得してタイムテーブルを組むCloudflare Worker + Pages | **参考可能（Worker Proxy）**: Worker内でHTML取得と正規表現パースを実施しているが、APIサーバーではなく特定用途のフロントエンド。 |
| `kiisaan/Falench.-ticketdive-bot` | Python | 特定アーティスト向けのチケット発売監視・LINE/Discord通知Bot | **参考可能（パース知見）**: `__NEXT_DATA__` をBeautifulSoupで抽出する手法を採用。ただし監視スクリプトでありAPIサーバーではない。 |
| `scarlet0725/ticketdive-go` | - | Go製チケットダイブライブラリ構想 | **不可**: `.gitignore` と `README.md` のみで実装コードが存在しない。 |
| `potetoooookun-create/ticketdive` | JavaScript | チケット自動購入ツール構想 | **不可**: `package.json`（Puppeteer依存）のみで実装コードなし。 |
| `mhiroto114514/TicketDive` | Python | DrissionPageを用いたブラウザ自動購入ボット | **対象外**: APIサーバーではなく、ブラウザ自動操作スクリプト。 |
| `john19875624/ticketdive-auto-entry` | JavaScript | Tampermonkey用フォーム自動入力UserScript | **対象外**: ブラウザクライアント上のDOM操作ツール。 |

### 結論
GitHub上には、**汎用的なTicketDive API Serverとして成立している既存リポジトリは存在しません**でした。
したがって、既存リポジトリをForkするよりも、`space/timetree`（`lumitree`）の設計実績に倣い、**堅牢で軽量なAPIサーバー（Go製またはPython/Node製）を新規構築する方が保守性・性能面で最適**です。

---

## 3. TicketDiveの内部データ構造

TicketDiveのフロントエンドはNext.jsで構築されており、SSR（Server-Side Rendering）時に生成される埋め込みJSON（`__NEXT_DATA__`）の中に、イベントの完全なリレーショナルデータが含まれています。

### 3.1 データ取得経路

1. **HTML埋め込み抽出（一次推奨）**:
   - `GET https://ticketdive.com/event/<eventId>`
   - `<script id="__NEXT_DATA__" type="application/json">` 内のJSONをパース。
   - `props.pageProps.__superjsonProps.json` に構造化データが格納されている。
2. **Next.js Data JSON Endpoint（高速二次経路）**:
   - `GET https://ticketdive.com/_next/data/<buildId>/event/<eventId>.json`
   - `buildId` が判明している場合、HTMLを介さずJSONを直接取得可能。
   - `buildId` の更新（デプロイ）時はHTML側から動的に再取得してフォールバック。

### 3.2 抽出可能なデータフィールド

```text
props.pageProps.__superjsonProps.json
├── eventDetail
│   ├── event
│   │   ├── id: "drIPQl23ZVboh1BWQy6y" (Firestore/DB UID)
│   │   ├── name: "2026/10/22(木) 「笑う門にはプリュきたる!! 」@WOMBLIVE"
│   │   ├── detail: "出演者、注意事項、タイムテーブル等の全文"
│   │   ├── release: "2026-09-28T13:00:00.000Z"
│   │   ├── createdAt / updatedAt
│   ├── stages (配列)
│   │   └── [0]
│   │       ├── id: "RyL58qx8oMmAtzapdEZY"
│   │       ├── stageName: "WOMBLIVE"
│   │       ├── startStage: "2026-10-22T06:45:00.000Z" (開演)
│   │       ├── openVenue: "2026-10-22T06:15:00.000Z" (開場)
│   │       ├── venue: { name: "WOMBLIVE", address: "" }
│   │       └── artists: [ { id: "honeyspice-re", name: "ハニースパイスRe." }, ... ]
│   └── ticketInfoList (販売枠配列)
│       ├── [0]: 一般販売
│       │   ├── startApply: "2026-10-02T11:00:00.000Z" (受付開始)
│       │   ├── endApply: "2026-10-22T06:45:00.000Z" (受付終了)
│       │   ├── receptionType: "first" (先着) / "lottery" (抽選)
│       │   ├── paymentChannels: ["card", "konbini"]
│       │   ├── customize: [ アンケート項目 (例: お目当ての出演者選択リスト) ]
│       │   └── ticketTypes:
│       │       ├── 一般前方チケット: 4,200円 (fee: 340円), remainingRate: 1, status: "applied"
│       │       └── 一般チケット: 2,700円 (fee: 270円), remainingRate: 1, status: "applied"
│       └── [1]: 最前OP 一般販売
│           └── ticketTypes: 各出演者別最前オプション (1,000円, 売り切れ状況 remainingRate: 0, status: "closed")
└── eventImages (フライヤー画像配列)
    └── [0]: { imageSource: "https://storage.googleapis.com/playyte-ticket-prod_event/...", width: 1190, height: 1684 }
```

---

## 4. APIサーバーのインターフェース設計

APIサーバーとして提供すべきエンドポイント仕様を定義します。

### 4.1 エンドポイント一覧

| メソッド | パス | 説明 | パラメータ |
|:---|:---|:---|:---|
| `GET` | `/health` | サーバーヘルスチェック | なし |
| `GET` | `/api/events/:eventId` | イベントID指定取得 | パスパラメータ: `eventId`（例: `plkt1022`） |
| `GET` | `/api/events?url=<url>` | URLクエリパラメータ指定取得 | クエリパラメータ: `url`（短縮URL可） |
| `POST` | `/api/events/parse` | URLまたはIDをBodyで送信してパース | JSON Body: `{"url": "https://..."}` または `{"id": "..."}` |

### 4.2 レスポンスモデル（JSON例）

```json
{
  "success": true,
  "data": {
    "id": "drIPQl23ZVboh1BWQy6y",
    "slug": "plkt1022",
    "name": "2026/10/22(木) 「笑う門にはプリュきたる!! 」@WOMBLIVE",
    "url": "https://ticketdive.com/event/plkt1022",
    "shortUrl": "https://t-dv.com/plkt1022",
    "detail": "...",
    "venue": {
      "name": "WOMBLIVE",
      "address": ""
    },
    "schedule": {
      "openAt": "2026-10-22T06:15:00.000Z",
      "startAt": "2026-10-22T06:45:00.000Z"
    },
    "artists": [
      { "id": "honeyspice-re", "name": "ハニースパイスRe." },
      { "id": "japanarizm", "name": "JAPANARIZM" }
    ],
    "tickets": [
      {
        "groupName": "一般販売",
        "startApply": "2026-10-02T11:00:00.000Z",
        "endApply": "2026-10-22T06:45:00.000Z",
        "receptionType": "first",
        "types": [
          {
            "id": "5ekMbDP1Vhc1qgIt6etj",
            "name": "一般前方チケット",
            "price": 4200,
            "fee": 340,
            "status": "applied",
            "isSoldOut": false,
            "remainingRate": 1,
            "maxNumPerApply": 4
          }
        ]
      }
    ],
    "images": [
      "https://storage.googleapis.com/playyte-ticket-prod_event/hzsyeJVthg6Sdo1YKi48_109549_1790515454273.jpeg"
    ]
  }
}
```

---

## 5. 参考文献・公的ソース (Authoritative External Sources)

1. [Next.js Documentation: Data Fetching and __NEXT_DATA__](https://nextjs.org/docs/pages/building-your-application/data-fetching) - Next.js公式ドキュメント。SSR時のハイドレーションデータ構造と仕様。
2. [W3C Technical Architecture Group: Design of URI Syntaxes and URL Redirection](https://www.w3.org/TR/chips/#url) - W3CによるHTTPリダイレクト（301/302）およびURI設計標準。
3. [RFC 9110: HTTP Semantics (Field Definitions and Status Codes)](https://www.rfc-editor.org/rfc/rfc9110.html) - IETFによる公式HTTP標準仕様。
4. [TicketDive 公式サービス利用規約およびプライバシーポリシー](https://ticketdive.com/terms) - TicketDive公式利用規約。
