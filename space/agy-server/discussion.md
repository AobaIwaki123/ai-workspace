# Antigravity CLI コンテナサーバー化 ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、Antigravity CLI (`agy`) をコンテナ (Docker/Kubernetes) 内で呼び出し、AI エージェントサーバーとして外部（HTTP / SSE / WebSocket）に公開・運用するための設計・検証およびロードマップを管理します。

---

## 目的・ゴール

1. **ヘッドレス AI サーバー化**:
   - `agy` CLI の自律エージェント能力（コード実行、ツール呼び出し、推論）をコンテナ内にカプセル化し、API 経由で呼び出せるようにする。
2. **ストリーミング & セッション管理**:
   - 思考プロセスやトークン生成をリアルタイムでストリーミング（SSE / WebSocket）配信し、会話 ID に基づく継続セッションを維持する。
3. **サンドボックスとセキュリティの担保**:
   - `--dangerously-skip-permissions` を適用した際の任意コード実行リスクを考慮し、非特権コンテナや使い捨て実行基盤を設計する。

---

## ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **CLI ヘッドレス機能・オプション検証** | `--print`, `--output-format json/stream-json`, `--effort` 等の動作確認 | 完了 ([note/01](./note/01_feasibility_and_architecture.md), [note/03](./note/03_agy_headless_cli_options.md)) |
| **Step 2** | **プロンプト制御 & 耐障害性設計** | 長文回答の抑制、要約ラッパー、gRPCタイムアウトの自動リトライ | 完了 ([note/04](./note/04_chat_prompt_tuning_and_latency.md), [note/05](./note/05_network_timeout_and_retry_design.md)) |
| **Step 3** | **コンテナ vs VM アーキテクチャ選定** | ハードウェア分離、DinD、スナップショット高速復元の比較と選定 | 完了 ([note/02](./note/02_vm_architecture_and_isolation.md), [note/06](./note/06_container_vs_vm_isolation.md), [note/07](./note/07_virtualization_platforms_comparison.md)) |
| **Step 4** | **Ubuntu VM 移行手順・systemd 常駐化設計** | SSH / scp を用いた最短移行手順、systemd サービス化 | 完了 ([note/08](./note/08_ubuntu_vm_migration_guide.md)) |
| **Step 5** | **実機デプロイ・常時稼働検証** | 実際の Ubuntu サーバー上での疎通確認と運用テスト | 次フェーズ |

---

## 決定事項 (ADR一覧)

- 未確定（PoC の結果を踏まえて決定予定）

---

## 直近のネクストアクション

- [x] `agy -p` の JSON および `stream-json` 出力の挙動検証
- [x] アーキテクチャ比較およびセキュリティ設計ドキュメントの起票
- [ ] ユーザーへの方向性確認（FastAPI サブプロセス方式 vs NDJSON 常駐方式 vs Python SDK 方式の選定）
