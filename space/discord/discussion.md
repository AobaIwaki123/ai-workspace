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
| **Step 3** | **CLI スクリプト整備** | `space/discord/scripts/send-message.sh` の実装と検証 | 完了 |
| **Step 4** | **双方向 Bot 開発（必要時）** | イベント駆動（メンション応答等）のBot実装検討 | 未着手（要望に応じて実施） |
| **Step 5** | **Discord MCP スキル整備** | `discord-mcp` 利用知見、認証落とし穴、マトリクスを `.agents/skills/discord-mcp` に集約 | 完了 |
| **Step 6** | **MCP サーバー安全性監査** | パッケージ、静的コード、ファイル操作、権限、クレデンシャル監査を実施し `note/02` に整理 | 完了 |

---

## 調査・学習ノート一覧 (note/)

- [**01. Discord API および MCP セットアップ・疎通検証ノート**](./note/01_discord_api_and_mcp_setup.md): REST API 疎通、参加サーバー・チャンネル取得、MCP構成
- [**02. Discord MCP サーバー総合セキュリティ監査・安全性評価ノート**](./note/02_discord_mcp_security_audit.md): サプライチェーン、静的コード、ファイル操作、権限設計、ローカル保護

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
- [ ] Antigravity 再起動・新規セッションでの MCP ツール認識確認


