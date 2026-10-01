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
| **Step 1** | **CLI ヘッドレス機能の検証** | `--print`, `--output-format json/stream-json`, `--conversation` の動作確認 | 完了 |
| **Step 2** | **アーキテクチャ設計** | コンテナ方式と VM 方式の比較・セキュリティ境界の定義 | 完了 ([note/01](./note/01_feasibility_and_architecture.md), [note/02](./note/02_vm_architecture_and_isolation.md)) |
| **Step 3** | **VM 環境構築 (Lima / Multipass)** | macOS ローカルまたはLinux VM 上でのインスタンス作成・トークン連携 | 進行中 |
| **Step 4** | **API ラッパー実装 (PoC)** | FastAPI / uvicorn による同期・ストリーミング API 実装 | 次フェーズ |

---

## 決定事項 (ADR一覧)

- 未確定（PoC の結果を踏まえて決定予定）

---

## 直近のネクストアクション

- [x] `agy -p` の JSON および `stream-json` 出力の挙動検証
- [x] アーキテクチャ比較およびセキュリティ設計ドキュメントの起票
- [ ] ユーザーへの方向性確認（FastAPI サブプロセス方式 vs NDJSON 常駐方式 vs Python SDK 方式の選定）
