# TimeTree 公開カレンダー内部API調査・アクセス仕様

TimeTree の公開カレンダー（例: `https://timetreeapp.com/public_calendars/ilife_official`）からイベントデータをプログラムで取得するための仕様・制限・実装手順のまとめです。

---

## 1. 概要と背景

- **公式開発者API (TimeTree Connect)**: 2023年12月22日をもってサービス終了しており、パブリックな公式APIトークンによる取得はできません。
- **公開Web版の内部API**: Webフロントエンド（React/Vite SPA）が利用している内部エンドポイント経由で、認証（ログイン）なしでイベント一覧の取得が可能です。

---

## 2. API エンドポイント仕様

### ① カレンダー基本情報の取得
```http
GET https://timetreeapp.com/api/v2/public_calendars/{alias_code}
```
- **パラメータ**:
  - `alias_code` (string): URL末尾の識別子（例: `ilife_official`）
- **レスポンス例**:
  ```json
  {
    "public_calendar": {
      "id": 46438,
      "alias_code": "ilife_official",
      "name": "iLiFE!",
      "overview": "",
      "images": {
        "cover": {
          "url": "https://attachments.timetreeapp.com/public_calendar/...",
          "thumbnail_url": "..."
        }
      },
      "links": {
        "twitter": "https://x.com/iLiFE_official"
      }
    }
  }
  ```

### ② イベント一覧の取得
```http
GET https://timetreeapp.com/api/v2/public_calendars/{alias_code}/public_events
```
- **クエリパラメータ（任意）**:
  - `year`: 対象年（例: `2026`）
  - `month`: 対象月（例: `8`）
  - `page`: ページネーション番号
- **レスポンス例**:
  ```json
  {
    "paging": {
      "current_page": 1,
      "total_pages": 1
    },
    "public_events": [
      {
        "id": 12345678,
        "uuid": "...",
        "title": "MEGALiFE! 先行物販＠Kアリーナ横浜",
        "description": "物販のご案内...",
        "start_at": 1787616000000,
        "end_at": 1787616000000,
        "all_day": false,
        "start_timezone": "Asia/Tokyo",
        "end_timezone": "Asia/Tokyo",
        "location": "Kアリーナ横浜",
        "url": "",
        "images": []
      }
    ]
  }
  ```

---

## 3. アクセス制限と必須リクエストヘッダー

単純に `curl` や `fetch` で API を叩くと `400 Bad Request`（`{"error":{"code":-401,"message":"failed to api request"}}`）が発生します。
正常にリクエストを通すためには以下の手順が必要です。

### 必須要件

1. **セッションCookieの取得**:
   - 初期ページ `https://timetreeapp.com/public_calendars/{alias_code}` へ GET リクエストを送り、レスポンスの `Set-Cookie` (`_session_id`) を保持する。
2. **CSRF トークンの抽出**:
   - 初期ページの HTML ソース内の `<meta name="csrf-token" content="...">` からトークン文字列を抽出する。
3. **必須ヘッダーの付与**:
   - `X-CSRF-Token`: 上記で取得した CSRF トークン
   - `X-TimeTreeA`: `web/2.1.0/1.0.0`（クライアントバージョン識別子）
   - `User-Agent`: ブラウザ相当の User-Agent
   - `Referer`: `https://timetreeapp.com/public_calendars/{alias_code}`
   - `Cookie`: `_session_id=...`

---

## 4. セキュリティ・WAF・制限事項

- **Cloudflare / Bot 対策**:
  - 現在のところ、Turnstile による JavaScript 実行チェックや 403 遮断はかかっておらず、HTTP クライアントから直接通信可能です。
- **レートリミット**:
  - 短時間に極端な頻度（毎秒数十回など）で叩くと 429 Too Many Requests や一時的ブロックの対象になるリスクがあります。
  - 定期実行する場合は 10分〜1時間間隔、あるいはキャッシュ機構を設けるのが適切です。
- **内部仕様変更リスク**:
  - フロントエンドのビルドバージョン更新（`X-TimeTreeA` やエンドポイント変更）に伴い、突然通信できなくなる可能性があります。
