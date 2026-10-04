# Discord連携とMCP・API自動化 ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、Discord連携、MCPサーバー導入、メッセージ送受信や自動化に関する目的、ロードマップ、進捗を記録・管理します。

---

## 目的・ゴール

- Antigravity およびスクリプト環境から Discord へのメッセージ送信・履歴取得を行える基盤を構築する。
- 認証情報の安全な管理（Git除外・パーミッション制御）を徹底する。

---

## ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **認証確認 & 疎通テスト** | Bot Token の検証、所属サーバー・チャンネル一覧取得、テストメッセージ送信 | 完了 |
| **Step 2** | **MCP サーバー構成** | `~/.gemini/config/mcp_config.json` への `discord-mcp` 登録 | 完了 |
| **Step 4** | **双方向 Bot 開発（Discord メッセージ起点で agy 起動）** | メンション・スラッシュコマンドを契機に `agy` を呼び出す Bot 実装、長文制御、リトライ機構 | 完了 ([note/03](./note/03_slash_commands_vs_mentions.md), [note/04](./note/04_repository_context_injection.md), [note/05](./note/05_discord_bot_runner_implementation.md)) |
| **Step 5** | **Discord MCP スキル整備** | `discord-mcp` 利用知見、認証落とし穴、マトリクスを `.agents/skills/discord-mcp` に集約 | 完了 |
| **Step 6** | **MCP サーバー安全性監査** | パッケージ、静的コード、ファイル操作、権限、クレデンシャル監査を実施し `note/02` に整理 | 完了 |
| **Step 7** | **Proxmox VM 構築 & 常駐化移行** | Terraform (`terraform.vm`) による Ubuntu VM 起票、Ansible による環境初期化、AI フレンドリー基盤設計 | 進行中 ([note/09](./note/09_proxmox_vm_provisioning_and_ai_friendly_automation.md)) |

---

## 調査・学習ノート一覧 (note/)

- [**01. Discord API および MCP セットアップ・疎通検証ノート**](./note/01_discord_api_and_mcp_setup.md): REST API 疎通、参加サーバー・チャンネル取得、MCP構成
- [**02. Discord MCP サーバー総合セキュリティ監査・安全性評価ノート**](./note/02_discord_mcp_security_audit.md): サプライチェーン、静的コード、ファイル操作、権限設計、ローカル保護
- [**03. スラッシュコマンド (Interactions API) と @メンション の仕様比較**](./note/03_slash_commands_vs_mentions.md): UI/UX、権限要件、3秒タイムアウトルールと deferReply
- [**04. リポジトリ知識（規約・スキル・ナレッジ）の自律継承メカニズム**](./note/04_repository_context_injection.md): cwd 設定による AGENTS.md, skills, space の自動認識
- [**05. Discord Bot Runner の実装設計とメッセージ自動分割 (Chunking)**](./note/05_discord_bot_runner_implementation.md): 常駐 Bot 実装、2000文字チャンキング、自動リトライ
- [**06. Message Content Intent の 2 段階有効化ルールと Token ライフサイクル**](./note/06_message_content_intent_two_phase_activation.md): Portal 許可 + クライアント宣言、Token 再生成不要の仕様
- [**07. 複数メッセージ受信時の並行実行挙動・競合リスクと制御設計**](./note/07_concurrency_and_multiple_messages.md): プロセス並行性、Out-of-Order完了、作業ツリー競合、直列キューイングとWorktree分離案
- [**08. セッション記憶の持続性メカニズム**](./note/08_session_memory_and_context_persistence.md): 独立プロセスで直近記憶が維持される理由、conversation_summaries.db、作業ツリーの外部記憶機能
- [**09. Proxmox VM プロビジョニング手順と AI フレンドリーな自動化基盤設計**](./note/09_proxmox_vm_provisioning_and_ai_friendly_automation.md): Terraform / Ansible 実践手順、非対話 SSH/PATH 問題、Tailscale Tag 運用、統合ラッパー案
- [**10. API駆動型 Homelab オーケストレーション基盤設計**](./note/10_api_driven_homelab_orchestration_architecture.md): Terraform/Ansible のマイクロ API 化、RBAC・スコープ制限、非同期ジョブ制御、MCP 連携案
- [**11. OAuth トークンライフサイクルとヘッドレス VM 運用における脅威モデル・セキュリティ監査**](./note/11_oauth_token_lifecycle_and_security_threat_model.md): リフレッシュトークン永続化仕様、プロンプトインジェクションによるトークン強奪リスク、多層防御策
- [**12. Google Drive MCP サーバーのセットアップ手順とアーキテクチャ**](./note/12_google_drive_mcp_setup_and_architecture.md): Google Cloud 公式 Managed vs ローカル stdio、OAuth 同意画面・Desktop App 構成、最小スコープ設計

---

## 決定事項 (ADR一覧)

- クレデンシャルは `private/.env.discord`（chmod 600, Git追跡除外）に保管し、スクリプトおよび各ツールから参照する。
- グローバルMCP設定 `~/.gemini/config/mcp_config.json` に `discord-mcp` を登録（`DISCORD_BOT_TOKEN` には `Bot ` プレフィックスを付与）。
- Discord MCP の利用手順・仕様・診断は `.agents/skills/discord-mcp/` に集約。

---

## 直近のネクストアクション

- [x] Discord REST API 経由での `#ai` チャンネルへのテストメッセージ送信
- [x] CLIメッセージ送信スクリプト `send-message.sh` の作成と動作確認
- [x] MCPサーバー設定の構成
- [x] Discord MCP スキル（`.agents/skills/discord-mcp`）の作成と検証
- [x] Discord MCP サーバーのセキュリティ・安全性チェックとノート整理 (`note/02`)
- [x] Proxmox VM (`discord-bot`, VMID: 235, IP: 192.168.11.235) の起票 (Terraform)
- [ ] Ansible による VM 初期化完了の確認
- [ ] Discord Bot Runner & `agy` CLI の VM デプロイと `systemd` 常駐化
- [ ] AI フレンドリーなプロビジョニングラッパースクリプトの検討・実装



