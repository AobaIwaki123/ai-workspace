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
| **Step 4** | **クラウド過去問演習（1〜2問）** | AWS (ISUCON11予選) を構築し、本番同様のタイムトライアル実施 | 🔄 進行中 (ISUCON14 Proxmox移行、初回スコア914・pass=true) ([note/07](note/07_cloud_practice_env.md)) |
| **Step 5** | **当日リハーサル＆チェックリスト確認** | 当日タイムライン、デプロイ競合防止、再起動試験の確認 | 📋 準備済み ([note/05_checklist.md](note/05_checklist.md)) |

---

## 📝 決定事項 (ADR一覧)

- [**`ADR-0001: チーム体制・役割分担と採用言語（Go / TypeScript）の決定`**](adr/0001-team-structure-and-languages.md)

---

## 📌 直近のネクストアクション

- [x] チーム人数（3人）、採用言語（Go / TypeScript）、クラウド環境演習の確定
- [x] ローカル模擬環境（`local-sandbox/`）の構築と測定手法ハンズオンの整備
- [x] Kubernetes クラスタ向けサンドボックス（`k8s/`）とマルチプレイガイドの整備
- [x] 1Password CLI (`op`) 連携による安全な AWS 操作環境の確立 (ディスク平文キー保存ゼロ)
- [x] AWS 上への ISUCON11 予選環境の起動と初回ベースライン計測完了 (1,278点 pass)
- [x] 演習終了時のインスタンス破棄完了 (EC2課金停止・ゼロコスト待機中)
- [x] 演習用EC2の停止・起動スクリプトと公開IP変更時のSSH Config更新コマンドを整備
- [ ] ISUCON11 予選サーバーの初動セットアップ (Git管理化、alp / スロークエリ計測ログ設定の投入)
- [ ] ボトルネック特定 (alp / pt-query-digest) と第1弾チューニング (DBインデックス等)

## 2026-10-11 Proxmox移行の実績

- Terraformで `pve201` に `isucon14` VM（VMID 236、2 vCPU、4GB、32GB、`192.168.11.236`）を作成・起動。
- AWSから公式ISUCON14のGo実装、決済モック、静的ファイル、SQL初期データ、環境変数を移行。
- MySQL 8.0、Nginx、Go 1.22、`alp`、`pt-query-digest` 等の計測基盤を導入し、systemdサービスを起動。
- 事前チェックは `pass=true`、フルベンチは `pass=true / スコア914`。評価APIの502が97件あるため、次回はその原因分析から再開する。
- 移行元AWS EC2（`i-0ef519f88f2d7041e`）は停止済み。終了はせず、比較用に復旧可能な状態で保持する。

## 2026-10-25 現在地

- デグレPR（#34, #35, #37, #38, #42）を除外し、効果の高かった施策のみでクリーンな積み上げ型PRスタック（PR #33, PR #47 〜 PR #53）を再構成・全件プッシュ完了。
- 複数セッション競合を防ぐリモート排他ロック機構（PR #56）およびサブMake修正（PR #57）を `main` にマージ済み。
- 新PRスタック先端（PR #53: `perf/matching-candidate-availability-query`）でのベンチマーク走行において、**3,541点（✅ PASS / エラー0件）** を達成（基準値 2,326点から +1,215点）。
- 次期ボトルネック（クエリ負荷第2位・27.6%を占める `chairs.access_token` 認証負荷）について、オンメモリキャッシュ等の導入検討を [Issue #59](https://github.com/sharehouse-sanhaimu/isucon14-retry/issues/59) として新規起票し別セッションへ委譲。
- **次回アクション**: 検証済みPRスタック（PR #33, PR #47 〜 PR #53）を親から順次 `main` へマージし、新ベースラインを 3,500点台へ固定する。
