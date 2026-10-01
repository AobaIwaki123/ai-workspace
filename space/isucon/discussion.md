# ISUCON 準備ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、ISUCON初参加に向けた準備状況、ロードマップ、議論の方向性を記録・管理します。

---

## 🎯 目標

- **初参加で予選突破 or 完走＆高スコア達成**
- 3人チームの連携フロー、計測・改善サイクル、秘伝のタレの確立
- ローカル & Kubernetes クラスタでの模擬環境演習 ＆ クラウド本番演習

---

## 👥 チーム体制・基本戦略

- **チーム人数**: 3名
- **採用言語**: Go / TypeScript (Node.js)
  - 基本戦略: 主力言語は **Go**（高速性・pprofの充実・ISUCON過去問での圧倒的な情報量）を第一候補としつつ、チームの習熟度に応じて **TypeScript** も対応可能な体制を整備。
- **演習環境**:
  - ローカル模擬環境 (Docker Compose)
  - Kubernetes クラスタ (Kustomize / 個人環境マルチテナント)
  - クラウド環境 (AWS EC2 / CloudFormation)

---

## 🗺️ ISUCON 準備ロードマップ (全5ステップ)

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **チーム体制＆戦略決定** | 3人の役割分担（インフラ・計測/アプリA/アプリB）、採用言語の確定 | ✅ 完了 ([ADR-0001](adr/0001-team-structure-and-languages.md)) |
| **Step 2** | **測定手法の整理 & サンドボックス演習** | alp, pt-query-digest, pprof を使った測定サイクルのローカル & k8s実践 | ✅ 完了 ([local](local-sandbox/), [k8s](k8s/), [note/11](note/11_k8s_sandbox_guide.md)) |
| **Step 3** | **秘伝のタレ（スクリプト・設定）の整備** | デプロイ自動化、ログローテート、Go/TSビルドスクリプト、Nginx/MySQL設定 | 🔄 進行中 ([scripts](scripts/), [templates](templates/)) |
| **Step 4** | **クラウド過去問演習（1〜2問）** | AWS上で過去問（ISUCON11〜13等）を構築し、本番同様のタイムトライアル実施 | 🔄 準備中 ([note/07_cloud_practice_env.md](note/07_cloud_practice_env.md)) |
| **Step 5** | **当日リハーサル＆チェックリスト確認** | 当日タイムライン、デプロイ競合防止、再起動試験の確認 | 📋 準備済み ([note/05_checklist.md](note/05_checklist.md)) |

---

## 📝 決定事項 (ADR一覧)

- [**`ADR-0001: チーム体制・役割分担と採用言語（Go / TypeScript）の決定`**](adr/0001-team-structure-and-languages.md)

---

## 📌 直近のネクストアクション

- [x] チーム人数（3人）、採用言語（Go / TypeScript）、クラウド環境演習の確定
- [x] ローカル模擬環境（`local-sandbox/`）の構築と測定手法ハンズオンの整備
- [x] Kubernetes クラスタ向けサンドボックス（`k8s/`）とマルチプレイガイドの整備
- [ ] 3人の役割分担の最終アサイン（誰がどの担当をするか）
- [ ] k8s または AWS 上での模擬演習の実施
