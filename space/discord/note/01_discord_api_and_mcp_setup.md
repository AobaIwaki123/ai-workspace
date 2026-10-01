# 01. Discord API および MCP セットアップ・疎通検証ノート

## 概要

本ドキュメントでは、Discord Bot Token を用いた Discord REST API への接続確認、メッセージ送信テスト、および Antigravity 向け Model Context Protocol (MCP) サーバーの構成手順と検証結果を記録します。

---

## 認証・環境情報

- **Bot アカウント**: `mcp` (ID: `1555181587929505802`)
- **対象サーバー**: `個人用` (ID: `1034269547403943989`)
- **検証先チャンネル**: `#ai` (ID: `1555181295590580295`)
- **クレデンシャル管理**:
  - `private/.env.discord`（パーミッション 600、Git 管理外）に `DISCORD_BOT_TOKEN` を格納。

---

## 疎通確認結果

### 1. Bot アカウント確認 (`GET /users/@me`)
- HTTP Status: 200 OK
- 応答:
  - `id`: `1555181587929505802`
  - `username`: `mcp`
  - `bot`: `true`

### 2. 参加サーバー取得 (`GET /users/@me/guilds`)
- HTTP Status: 200 OK
- 参加サーバー: `個人用` (`1034269547403943989`)

### 3. メッセージ送信テスト (`POST /channels/1555181295590580295/messages`)
- 送信先: `#ai` (ID: `1555181295590580295`)
- 送信成功メッセージID:
  - 手動テスト: `1555183562490122310`
  - スクリプト経由: `1555183984454139905`

---

## MCP (Model Context Protocol) サーバー設定

Antigravity から Discord 操作を呼び出せるよう、`~/.gemini/config/mcp_config.json` に以下の設定を反映しました。

```json
{
  "mcpServers": {
    "discord": {
      "command": "npx",
      "args": ["-y", "discord-mcp@latest"],
      "env": {
        "DISCORD_BOT_TOKEN": "..."
      }
    }
  }
}
```

利用可能な主なツール:
- `discord_send_message`: 指定チャンネルへのメッセージ送信
- `discord_get_message_history`: チャンネルの会話履歴取得
- `discord_get_channel`: チャンネル情報の取得
- `discord_add_reaction`: リアクション付与

---

## 再現用 CLI スクリプト

`space/discord/scripts/send-message.sh` にスクリプトを配置。

```bash
# デフォルトで #ai チャンネルに送信
./space/discord/scripts/send-message.sh "任意のメッセージ"

# チャンネルIDを指定して送信
./space/discord/scripts/send-message.sh "任意のメッセージ" <CHANNEL_ID>
```

---

## 参考・一次情報源

- [Discord Developer Portal: Documentation](https://discord.com/developers/docs/intro)
- [Discord Developer Portal: Channel Messages API](https://discord.com/developers/docs/resources/channel#create-message)
- [Model Context Protocol 公式サイト](https://modelcontextprotocol.io/)
- [discord-mcp (GitHub)](https://github.com/olivierdebeufderijcker/discord-mcp)
