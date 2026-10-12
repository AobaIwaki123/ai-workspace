# 01: note.com 内部API仕様と薄いCLI（luminote）設計メモ

## 1. 概要と目的

本ノートは、ブラウザ閲覧時に発生するSNSノイズ（他者のコメント、おすすめ欄、過剰なビジュアル刺激、アルゴリズムの誘導）を完全に排除し、AIおよびローカルエディタ（Markdown）上で静かにテキストのみを精読・要約するための薄いCLIツール（`luminote`）の設計仕様とAPI調査結果をまとめる。

---

## 2. メモ対象クリエイター・検証記事

* **クリエイター**: **雨宮サク** (`amamiya_saku`)
  * note URL: [https://note.com/amamiya_saku](https://note.com/amamiya_saku)
* **検証記事**:
  * タイトル: **『貪欲』**
  * URL: [https://note.com/amamiya_saku/n/n004679417efb](https://note.com/amamiya_saku/n/n004679417efb)
  * Note Key: `n004679417efb`
  * 内容要旨: チャンスを貪欲に掴む姿勢。完璧にできないことや失敗を恐れて考える時間を設ける前に、まず1歩飛び込む生き様。

---

## 3. note.com 内部API (v3) 仕様

note.com の公開記事は、Next.js Webアプリが利用している内部REST API経由で直接取得可能である。

### (1) 単一記事の取得エンドポイント
```http
GET https://note.com/api/v3/notes/{note_key}
User-Agent: Mozilla/5.0
```

* **認証**: 無料公開記事であれば不要（パブリック取得可能）。
* **レスポンス形式**: JSON
* **主要フィールド構造**:

| フィールドパス | 型 | 説明 |
| :--- | :--- | :--- |
| `data.name` | string | 記事タイトル |
| `data.user.nickname` | string | 著者表示名（例: 雨宮サク） |
| `data.user.urlname` | string | 著者ID（例: `amamiya_saku`） |
| `data.publish_at` | string (ISO8601) | 公開日時 |
| `data.like_count` | integer | スキ（いいね）数 |
| `data.body` | string (HTML) | 本文HTML（`<p>`、`<br>`、`<strong>`、`<img>`等） |
| `data.hashtag_notes[].hashtag.name` | array[string] | 付与ハッシュタグ一覧 |
| `data.eyecatch` | string (URI) | アイキャッチ画像URL |

### (2) クリエイター記事一覧の取得（参考）
```http
GET https://note.com/api/v2/creators/{urlname}/contents?kind=note&page={page}
```

---

## 4. 薄いCLI設計 (`scripts/fetch_note.py`)

AIからの直接呼び出し、およびターミナルでの即時利用を想定し、**外部依存ゼロ（Python 3 標準ライブラリのみ）**で動作する軽量スクリプトとして設計する。

### 仕様要件
1. **入力**: noteの記事URL（または note_key）
2. **変換**: 本文HTMLを簡易Markdownに正規化（不要タグ除去、改行・強調の維持）
3. **出力**: 標準出力（stdout）へのMarkdown表示、またはファイル保存オプション
4. **依存関係**: `urllib.request`, `json`, `html`, `re`, `sys`, `argparse` のみ

---

## 5. lumi-spec との位置づけ（アーキテクチャ方針）

* **イベントスキーマとの分離**:
  `lumi-spec` の現行コア（`event-candidate.v1.json`）はライブや開場開演のスケジュール契約であるため、記事データを無理にイベント型に統合することは避ける（YAGNI原則）。
* **エンティティ契約との連携**:
  `lumi-spec` の `schema/entity.v1.json` の `social_links`（`platform: "note"`）としてクリエイターURLを保持し、Entity ID（例: `amamiyasaku`）から本CLIをフックする連携を将来スコープとする。

---

## 参考文献
- note.com 公式: [https://note.com/](https://note.com/)
- lumi-spec データ契約: [schema/entity.v1.json](file:///Users/aobaiwaki/ai-workspace/space/lumi-spec/schema/entity.v1.json)
