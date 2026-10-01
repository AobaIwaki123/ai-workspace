# Discord MCP Patterns & Best Practices

本ドキュメントでは、AI エージェントが Discord MCP を通じて Discord と円滑にやり取りするための実践的な実装パターン、文字数制限対策、およびセキュリティ運用原則について解説します。

---

## 1. メッセージ送信と文字数制限対策

### 2000文字制限と分割送信（Chunking）
Discord の 1 メッセージあたりの上限文字数は 2000 文字です。
AI エージェントの生成テキスト（調査レポート、コード差分、ログ出力等）が 2000 文字を超える場合は、事前に 1800〜1900 文字程度を目安に分割し、複数回に分けて `discord_send_message` を呼び出します。

分割時のポイント:
- 改行コード（`\n\n` や `\n`）の区切り位置で分割し、文章やコードブロックの途中で途切れないように配慮します。
- コードブロック（` ``` `）をまたぐ場合、分割後の各ブロックの先頭と末尾にバッククォートを適切に補完します。

#### 推奨チャンキング実装（改行優先分割）
```javascript
function chunkText(text, limit = 1900) {
  const chunks = [];
  let remaining = text;
  while (remaining.length > limit) {
    let index = remaining.lastIndexOf('\n', limit);
    if (index === -1) index = limit;
    chunks.push(remaining.slice(0, index));
    remaining = remaining.slice(index).trimStart();
  }
  if (remaining.length > 0) {
    chunks.push(remaining);
  }
  return chunks;
}
```

### 双方向 Bot Runner パターン（Gateway 接続 + agy 起動）
Discord イベント起点で自律 AI アシスタントを稼働させる場合:
1. **スラッシュコマンド（`/agy <prompt>`）**: 3 秒以内に `deferReply` を返し、`agy` サブプロセス実行完了後に `editReply`（および 2 報目以降は `followUp`）でチャンキング送信。
2. **Bot メンション（`@Bot <prompt>`）**: メッセージ受信時に `eyes` リアクションで受付を通知し、`agy` 完了後にスレッドまたはインライン返信で送信。
3. **実行ディレクトリと環境**: リポジトリルートを `cwd` として指定し、`ai-workspace` 内の全知見・スキルを注入。

### 返信（Reply / `replyTo`）の活用
特定の文脈や質問に対して返信を行う場合は、対象メッセージの ID を `replyTo` に指定します。これにより、Discord 上でインライン返信として表示され、議論の流れが明確になります。

```json
{
  "channelId": "1555181295590580295",
  "replyTo": "1555186101402996747",
  "content": "ご質問いただいた調査結果を報告します。"
}
```

---

## 2. 履歴取得と検索の活用パターン

### チャンネル文脈の把握
タスク開始時に直近の状況や指示を確認する場合、`discord_get_message_history` を使用して直近 20〜50 件のメッセージを取得します。

```json
{
  "channelId": "1555181295590580295",
  "limit": 30
}
```

### キーワード検索とフォールバック挙動
過去の特定の議論や URL を探す際は `discord_search_messages` を使用します。
`discord-mcp` はギルド検索 API を試行し、Bot 権限等で失敗した場合は自動的に直近 100 件の履歴検索へフォールバックする設計になっています。そのため、検索結果が空でもエラーになりにくい安定した取得が可能です。

```json
{
  "channelId": "1555181295590580295",
  "query": "デプロイ",
  "limit": 10
}
```

---

## 3. リアクションによる進行状況の可視化

タスクの進行ステータスを Discord 上で表現するために、メッセージへのリアクション付与（`discord_add_reaction`）を活用します。

- 処理開始 / 受領: `eyes` (`👀`)
- 処理成功 / 完了: `white_check_mark` (`✅`) または `+1` (`👍`)
- エラー / 要確認: `warning` (`⚠️`) または `x` (`❌`)

```json
{
  "channelId": "1555181295590580295",
  "messageId": "1555186101402996747",
  "emoji": "👀"
}
```

---

## 4. 個別ダイレクトメッセージ（DM）の送信手順

Bot アカウントは `discord_get_dm_channels`（DMチャンネル一覧の取得）を実行できませんが、特定ユーザーの ID が分かっている場合は以下の 2 ステップで DM を送信できます。

1. **`discord_create_dm` の実行**:
   引数に `userId` を渡し、そのユーザーとの DM チャンネルを開設または既存チャンネル ID を取得します。
   ```json
   { "userId": "123456789012345678" }
   ```
2. **`discord_send_message` の実行**:
   返却された DM チャンネル ID に対してメッセージを送信します。
   ```json
   {
     "channelId": "<返却されたDMチャンネルID>",
     "content": "ダイレクトメッセージの通知です。"
   }
   ```

---

## 5. セキュリティと認証情報管理

### トークンの保護
- `DISCORD_BOT_TOKEN` は絶対に Git リポジトリ（コード、コミット、PR）にコミットしてはなりません。
- 設定ファイル `~/.gemini/config/mcp_config.json` は適切なファイルアクセス権限（`chmod 600`）を設定し、他のシステムユーザーからの読み取りを制限します。

```bash
chmod 600 ~/.gemini/config/mcp_config.json
```

---

## 6. 権威ある公式リソース

- [Discord Developer Portal: Message Components & Embeds](https://discord.com/developers/docs/interactions/message-components)
- [Discord Developer Portal: Channel Resource & Message Formats](https://discord.com/developers/docs/resources/channel#create-message)
- [Discord Developer Portal: Best Practices](https://discord.com/developers/docs/topics/community-resources)
