# TimeTree 公開カレンダー連携 ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、TimeTree 公開カレンダー（例: `ilife_official` 等）からの情報取得、利用用途（Googleカレンダー連携、通知Bot等）、ロードマップ、進捗を記録・管理します。

---

## 🎯 目的・ゴール

- TimeTree の公開カレンダーからイベント情報を自動的・安定的に抽出する。
- 抽出したイベントデータを活用し、カレンダー同期（iCal / Google Calendar）やリマインダー通知（Discord, Slack, LINE等）を可能にする。

---

## 🗺️ ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **API・アクセス制限の調査** | Webフロントエンド内部APIの特定、ヘッダー/CSRFトークン要件の検証 | ✅ 完了 ([note/01](note/01_public_calendar_api_research.md)) |
| **Step 2** | **取得スクリプトの実装** | Python によるイベント取得・パーススクリプト作成 | ✅ 完了 ([scripts/fetch_events.py](scripts/fetch_events.py)) |
| **Step 3** | **専用リポジトリへの切り出し (`lumitree`)** | Go 製 CLI, iCalendar (.ics), OpenAPI 準拠 HTTP Proxy, k8s デプロイ基盤の構築 | ✅ 完了 ([github.com/AobaIwaki123/lumitree](https://github.com/AobaIwaki123/lumitree)) |
| **Step 4** | **外部連携（Discord / Google Cal / 自宅k8s）** | `lumitree` を自宅 k8s にデプロイし、Google カレンダー購読および Discord Bot 等との連携 | 🔄 進行可能 |

---

## 📝 決定事項 (ADR一覧)

- [**`ADR-0001: 専用リポジトリ lumitree (Go実装) への責務分離と OpenAPI/iCal Proxy アーキテクチャの採用`**](https://github.com/AobaIwaki123/lumitree/blob/main/docs/architecture.md#4-設計上のトレードオフと決定事項-adr)

---

## 📌 直近のネクストアクション

- [x] TimeTree 公開カレンダー内部APIの仕様特定と疎通確認
- [x] イベント取得スクリプト `fetch_events.py` の作成
- [x] Go 製専用リポジトリ `lumitree` の立ち上げと v1.0.0 リリース
- [ ] 自宅 k8s クラスタへの `lumitree` デプロイ（`kubectl apply -k k8s/`）
- [ ] Google カレンダーへの `.ics` Webcal 購読 URL 登録
