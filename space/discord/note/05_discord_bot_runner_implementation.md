# Discord Bot Runner の実装設計とメッセージ自動分割 (Chunking)

本ドキュメントは、ローカルマシンをサーバーに見立てて常駐稼働させる Discord Bot Runner（`space/discord/bot/index.js`）の実装構成、自動リトライ、および Discord の 2,000 文字上限に対するメッセージチャンキング（分割送信）ロジックの知見をまとめた技術ノートです。

---

## 1. 全体アーキテクチャ

Bot Runner は以下のファイルで構成されています:

```
space/discord/
├── bot/
│   ├── index.js              # メインの常駐プロセス (Gateway 接続、イベントハンドラ、agy 呼び出し)
│   ├── register-commands.js  # スラッシュコマンド (/agy) の登録スクリプト
│   ├── package.json          # 依存関係定義 (discord.js, dotenv)
│   └── package-lock.json
└── scripts/
    └── run-bot.sh            # 依存確認と Bot 起動を行うワンライナースクリプト
```

---

## 2. 2,000 文字制限対策（メッセージ自動チャンキング）

### 2.1 課題
Discord API では、1 回のメッセージ送信（`channel.send()` または `interaction.reply()`）で送信できる文字数が **最大 2,000 文字** に制限されています。
これを超える文字列を送信しようとすると `DiscordAPIError[50035]: Invalid Form Body (BASE_TYPE_MAX_LENGTH)` エラーが発生します。

### 2.2 解決策: 改行優先のスマートチャンキング関数
単に 1,900 文字で機械的にスライスすると、単語やマークダウンコードブロックの途中で分断されて表示が崩れます。
そのため、**制限値（1,900 文字）以内で最も近い改行コード (`\n`) を探して安全に分割** するヘルパー関数を実装しています。

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

### 2.3 送信処理の流れ
1. 分割された最初の chunk を `interaction.editReply(chunks[0])` で返信。
2. 2 つ目以降の chunk が存在する場合、`interaction.followUp(chunks[i])` で順番に後続メッセージとして送信。

---

## 3. 安全なクレデンシャル管理と起動スクリプト

1. **クレデンシャル管理**:
   - Bot Token は `private/.env.discord`（chmod 600、Git 管理除外）に保管。
   - スクリプト起動時に環境変数が無ければ `private/.env.discord` を自動読み込み。
2. **ワンライナー起動スクリプト (`run-bot.sh`)**:
   - `node_modules` の存在確認と `npm install` の自動化。
   - `exec node index.js` によるクリーンなプロセス起動。

```bash
# 起動コマンド
./space/discord/scripts/run-bot.sh
```

---

## 4. 参考リソース

* [discord.js Guide: Handling Long Messages](https://discordjs.guide/popular-topics/common-questions.html#how-do-i-send-a-message-longer-than-2000-characters)
* [Discord Developer Portal: Message Resource](https://discord.com/developers/docs/resources/channel#message-object)
