---
name: discord-mcp
description: >-
  Interacts with Discord using the Discord MCP server. Sends messages, inspects channel history, searches text,
  manages reactions, and handles attachments. Use this skill when the user asks to send Discord messages, read channels,
  interact with Discord MCP tools, or diagnose Discord MCP authentication (401/403) and setup issues.
---

# Discord MCP Skill

本スキルは、`discord-mcp` サーバーを通じて Discord チャンネルへのメッセージ送信、履歴取得、検索、リアクション管理、添付ファイル処理を安全かつ確実に行うための標準手順とノウハウを提供します。

---

## 1. 発動トリガー

以下のような状況で本スキルを実行します:
- ユーザーが「Discord にメッセージを送って」「Discord のチャンネル履歴を読んで」「Discord MCP で検索して」と指示した時
- Discord 上の特定チャンネル（例: `#ai`, `#技術`, `#重要` 等）と連携して通知やレポートを投稿したい時
- Discord MCP の呼び出しで `401: Unauthorized` や `403: Forbidden` などのエラーが発生し、診断・復旧を行いたい時
- Discord Bot の設定やトークン認証（`Bot ` プレフィックス要件）を確認したい時

---

## 2. 前提条件と認証ヘルスチェック

Discord MCP は Node.js 製の `discord-mcp` パッケージで稼働します。
Discord API v10 の仕様により、Bot Token 利用時は環境変数 `DISCORD_BOT_TOKEN` の先頭に **`Bot ` プレフィックスが必須**です（プレフィックスがない場合、Discord API は `401 Unauthorized` を返します）。

### 診断スクリプトの実行
設定ファイル（`~/.gemini/config/mcp_config.json`）と Discord API 接続性を検証します。

```bash
./.agents/skills/discord-mcp/scripts/check-discord-mcp.sh
```

- トークンに `Bot ` プレフィックスが不足している場合は、以下の修復スクリプトを実行して設定を更新します。

```bash
./.agents/skills/discord-mcp/scripts/fix-token-prefix.sh
```

---

## 3. 主要操作フロー

Discord ツールは Lazy MCP ツールとして登録されており、`call_mcp_tool` を介して呼び出します（`ServerName: "discord"`）。

### ワークフロー A: メッセージの送信と返信
1. 送信先チャンネル ID を確認します（`check-discord-mcp.sh` の出力結果やユーザー指定から取得）。
2. メッセージ本文を準備します。2000 文字を超える場合は 1800 文字程度を目安に分割します。
3. `call_mcp_tool` で `discord_send_message` を実行します。

```json
{
  "ServerName": "discord",
  "ToolName": "discord_send_message",
  "Arguments": {
    "channelId": "<channel_id>",
    "content": "通知メッセージ本文"
  }
}
```

特定のメッセージに対するインライン返信を行う場合は、`replyTo` に親メッセージ ID を指定します。

### ワークフロー B: チャンネル履歴の確認と要約
1. `discord_get_message_history` を呼び出し、直近のメッセージを取得します。
2. 取得したメッセージ一覧（タイムスタンプ、ユーザー名、本文）を解析し、ユーザーに要点を報告します。

```json
{
  "ServerName": "discord",
  "ToolName": "discord_get_message_history",
  "Arguments": {
    "channelId": "<channel_id>",
    "limit": 20
  }
}
```

### ワークフロー C: キーワード検索
チャンネル内の特定トピックや過去の議論を検索します。

```json
{
  "ServerName": "discord",
  "ToolName": "discord_search_messages",
  "Arguments": {
    "channelId": "<channel_id>",
    "query": "リリース",
    "limit": 10
  }
}
```

### ワークフロー D: リアクションの付与
タスクの受領や完了確認をメッセージへのリアクションで表現します。

```json
{
  "ServerName": "discord",
  "ToolName": "discord_add_reaction",
  "Arguments": {
    "channelId": "<channel_id>",
    "messageId": "<message_id>",
    "emoji": "👍"
  }
}
```

---

## 4. Bot Token 利用時の重要制約

Discord Bot アカウントには以下の制限が存在します。実行不可のツールを呼び出すと API エラー（400 / 403）となります。

1. **利用不可のツール**:
   - `discord_get_dm_channels`: Bot は全 DM 一覧エンドポイントにアクセスできません。
   - `discord_get_friends`, `discord_add_friend`, `discord_remove_friend`: Bot にはフレンド機能が存在しません。
2. **個別 DM 送信の手順**:
   特定ユーザーへの DM 送信は、まず `discord_create_dm`（`userId` を指定）で DM チャンネルを開設し、返却されたチャンネル ID に対して `discord_send_message` を実行します。
3. **プレゼンス更新の制約**:
   `discord_update_presence` は Gateway 接続を伴わないため、Discord クライアント側へのステータス反映は行われません（ログ出力のみ）。

---

## 5. 検証ループ（Verification Loop）

Discord 操作を行った後は、以下の手順で成否を確認します:

1. **ツールの実行結果確認**:
   - `discord_send_message` の戻り値にメッセージ ID（`Message sent (ID: ...)`）が含まれているか確認します。
   - エラーが発生した場合は HTTP ステータスコード（401, 403, 404, 429）を特定し、[トラブルシューティングガイド](./references/troubleshooting-and-auth.md) に沿って対処します。
2. **履歴による整合性検証**:
   - 送信直後に `discord_get_message_history`（`limit: 1`）を取得し、意図した内容が正しく投稿されているかを確認します。

---

## 6. 関連リファレンス

- [**`references/tools-reference.md`**](./references/tools-reference.md): 全ツールの詳細仕様、引数一覧、Bot 利用可否マトリクス
- [**`references/troubleshooting-and-auth.md`**](./references/troubleshooting-and-auth.md): 401/403/429 エラー原因と対策、Bot 権限設計、トークン仕様
- [**`references/patterns-and-best-practices.md`**](./references/patterns-and-best-practices.md): 長文分割送信、返信、リアクション活用、セキュリティ運用
