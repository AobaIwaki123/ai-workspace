# Discord MCP Troubleshooting & Authentication Guide

本ドキュメントでは、`discord-mcp` 利用時における認証の仕組み、典型的なエラー事象（401, 403, 429等）の原因と解決手順、および Discord Developer Portal における権限設計について詳述します。

---

## 1. 認証の仕組みと「Bot 」プレフィックス問題

### Discord API v10 の認証ヘッダー仕様
Discord HTTP API v10 では、Bot アカウントとして認証を行う場合、HTTP リクエストヘッダーに以下の形式でトークンを渡す必要があります。

```http
Authorization: Bot <YOUR_BOT_TOKEN>
```

一方で、一般ユーザーアカウント（User Token / Self-Bot）の場合はプレフィックスなしの形式が用いられます。

```http
Authorization: <USER_TOKEN>
```

### `discord-mcp` サーバー実装上の落とし穴
Node.js 製の `discord-mcp` パッケージ（v2.4.0 現在）では、内部の API クライアント (`src/discord/service.ts`) が以下のように記述されています。

```typescript
const headers = {
    Authorization: this.token,
    'User-Agent': 'DiscordBot (https://github.com/anthropics/discord-mcp, 2.0.0)',
    ...options.headers
};
```

コード側で `this.token` に対して自動で `Bot ` を付加していません。そのため、設定ファイル（`~/.gemini/config/mcp_config.json` 等）の環境変数 `DISCORD_BOT_TOKEN` に生のトークン（例: `MTU1NTE...`）をそのまま記述すると、Discord API へ `Authorization: MTU1NTE...` が送信され、**401: Unauthorized** エラーが発生します。

### 解決策
Bot Token を利用する際は、環境変数側であらかじめプレフィックスを含めて定義します。

```json
{
  "mcpServers": {
    "discord": {
      "command": "npx",
      "args": ["-y", "discord-mcp@latest"],
      "env": {
        "DISCORD_BOT_TOKEN": "Bot MTU1NTE4MTU4NzkyOTUwNTgwMg..."
      }
    }
  }
}
```

付属のスクリプト [`scripts/fix-token-prefix.sh`](../scripts/fix-token-prefix.sh) を実行することで、設定ファイルのトークン先頭に自動で `Bot ` を安全に補完できます。

---

## 2. 典型的なエラーコードとトラブルシューティング

| エラーコード | 主な原因 | 調査手順と解決策 |
| :--- | :--- | :--- |
| **401: Unauthorized** | トークンの指定ミス、失効、または `Bot ` プレフィックスの欠落 | 1. [`scripts/check-discord-mcp.sh`](../scripts/check-discord-mcp.sh) を実行し、API直接疎通を確認する。<br>2. トークンが `Bot ` で始まっているか確認する。<br>3. トークンが再生成されていないか Developer Portal で確認する。 |
| **403: Forbidden** | Bot が対象ギルド・チャンネルに参加していない、または操作権限が不足 | 1. 対象チャンネルで Bot ロールに「チャンネルを見る」「メッセージを送信」が付与されているか確認する。<br>2. Bot 非対応エンドポイント（`get_dm_channels`, `get_friends` 等）を呼び出していないか確認する。 |
| **404: Not Found** | チャンネルIDやメッセージIDが存在しない | 1. チャンネルIDが正しいか確認する。<br>2. 削除済みメッセージIDを参照していないか確認する。 |
| **429: Too Many Requests** | Discord API のレートリミット到達 | `discord-mcp` は `x-ratelimit-reset-after` ヘッダーに基づく自動待機・リトライ機能を備えていますが、短時間に大量のメッセージ送信・検索を行うと遅延が発生します。リクエスト間隔を空けてください。 |
| **50001: Missing Access** | ギルドまたはチャンネルへのアクセス権がない | Bot が当該サーバーに追加されていないか、プライベートチャンネルの閲覧権限が与えられていません。 |

---

## 3. Discord Developer Portal での設定手順

Bot を正常に稼働させるためには、Discord Developer Portal での権限設定が不可欠です。

### 1. Bot の作成とトークン取得
1. [Discord Developer Portal - Applications](https://discord.com/developers/applications) にアクセスします。
2. 「New Application」を作成し、左メニュー「Bot」を開きます。
3. 「Reset Token」をクリックして Bot Token を取得します。

### 2. 特権インテント（Privileged Gateway Intents）
メッセージ内容の取得や検索を安定して行うため、Bot 設定画面の「Privileged Gateway Intents」にて以下を有効化することを推奨します。
- **Message Content Intent**: メッセージ本文の読み取りに必要
- **Server Members Intent**: サーバーメンバー情報の取得（必要に応じて）

### 3. ギルドへの招待 URL 生成
1. 左メニュー「OAuth2」→「URL Generator」を開きます。
2. **SCOPES**: `bot` を選択。
3. **BOT PERMISSIONS**: 最低限以下にチェックを入れます。
   - `View Channels` (チャンネルを見る)
   - `Send Messages` (メッセージを送信)
   - `Read Message History` (メッセージ履歴を読む)
   - `Attach Files` (ファイルを添付)
   - `Add Reactions` (リアクションの追加)
4. 生成された URL をブラウザで開き、Bot を運用対象の Discord サーバー（ギルド）に招待します。

---

## 4. 権威ある公式リソース

- [Discord Developer Portal: Documentation](https://discord.com/developers/docs/intro)
- [Discord API Reference: Authentication](https://discord.com/developers/docs/reference#authentication)
- [Discord API Reference: Rate Limits](https://discord.com/developers/docs/topics/rate-limits)
- [Discord Developer Portal: Applications Dashboard](https://discord.com/developers/applications)
- [Model Context Protocol (MCP) Official Specification](https://modelcontextprotocol.io/)
