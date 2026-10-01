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
| **Step 4** | **Shift-Left GitOps & CI 体系化** | Fast-Forward ステージング生成、事前コンテナ Push、`ci-*` (Go/Scripts/Workflows) 静的解析の導入 | ✅ 完了 ([ADR-0001](adr/0001-shift-left-gitops-release-pipeline.md), [ADR-0002](adr/0002-single-responsibility-pr-and-strict-ci-filters.md)) |
| **Step 5** | **自宅 k8s (ArgoCD) 実稼働 & 外部連携** | `lumitree` を自宅 k8s にデプロイし、Google カレンダー購読および Live API Monitoring 連携 | ✅ 稼働中 (v1.5.0 Running) |

---

## 📝 決定事項 (ADR一覧)

- [**`ADR-0001: 保護ルールを維持した Shift-Left GitOps リリースパイプラインの採用`**](adr/0001-shift-left-gitops-release-pipeline.md)
- [**`ADR-0002: 単一責務 PR (Single Responsibility PR) 原則と CI 体系化の採用`**](adr/0002-single-responsibility-pr-and-strict-ci-filters.md)

---

## 📌 達成済みマイルストーン & 直近のアクション

- [x] TimeTree 公開カレンダー内部APIの仕様特定と疎通確認
- [x] イベント取得スクリプト `fetch_events.py` の作成
- [x] Go 製専用リポジトリ `lumitree` の立ち上げと v1.0.0 リリース
- [x] 自宅 k8s クラスタへの `lumitree` デプロイ（`v1.5.0` 正常稼働中）
- [x] Shift-Left GitOps リリースパイプライン（Pattern A）の完全自動化
- [x] CI の体系化・Path Filter 分離 (`ci-go.yml`, `ci-scripts.yml`, `ci-workflows.yml`)
- [ ] Release Push 起点での Live API Monitoring 連動 (検討中)
- [ ] Google カレンダー / Apple カレンダーでの Webcal 自動同期登録
