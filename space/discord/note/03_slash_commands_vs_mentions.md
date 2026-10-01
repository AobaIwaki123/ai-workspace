# スラッシュコマンド (Interactions API) と @メンション の仕様比較

本ドキュメントは、Discord Bot をユーザーインターフェースとして設計する際、スラッシュコマンド（Application Commands）と @メンション（Message Create）の機能差、権限要件、および Discord API 固有のタイムアウト制約の知見をまとめた技術ノートです。

---

## 1. スラッシュコマンド vs @メンション の詳細比較

| 観点 | スラッシュコマンド (`/agy <prompt>`) | @メンション (`@mcp <prompt>`) |
| :--- | :--- | :--- |
| **ユーザー体験 (UI/UX)** | ・`/` を打つとコマンド名や引数の説明がポップアップ表示され、入力補完が効く<br>・スマホや PC で入力しやすい | ・通常のチャット感覚で文章の中に自然に組み込める<br>・スレッドや返信ツリーとの親和性が高い |
| **権限要件** | **Message Content Intent（読み取り権限）は完全に不要**。<br>Discord クライアント側から安全にフォーム値として届く。 | **Message Content Intent が必須**（または Bot 自身が明示的にメンションされたメッセージに限る）。 |
| **Discord API のタイムアウト制約** | **3 秒以内に一次応答 (`deferReply`) を返さないとインタラクションエラーになる**（Bot 側で即座に応答保留し、後から `editReply` する設計が必須）。 | 3 秒ルールのような厳格な制約はなく、`sendTyping()`（入力中...）を定期送信しながら完了を待てる。 |
| **誤爆の防止** | 明示的なコマンド呼び出しのため誤爆ゼロ。 | 他の Bot との重複や、メンション漏れで無反応になるケースがある。 |

---

## 2. スラッシュコマンドの 3 秒タイムアウトルール対策

### 2.1 課題
Discord の Interactions API は、ユーザーがスラッシュコマンドを実行してから **3 秒以内** に Bot が何らかのレスポンス（ACK）を返さないと、クライアント画面上に「このインタラクションは失敗しました」というエラーが表示されます。
Antigravity CLI による推論やツール実行は通常 5〜20 秒程度を要するため、同期処理では必ずタイムアウトします。

### 2.2 解決策: `deferReply()` による非同期化
コマンド受信直後に `interaction.deferReply()` を呼び出すことで、Discord 側に「Bot は考え中...」という状態を通知し、有効期限を 15 分間に延長します。
処理完了後、`interaction.editReply()` を使って実際の回答内容に更新します。

```javascript
client.on('interactionCreate', async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'agy') {
    // 3秒ルール回避のため、何よりも先に即座に応答を保留
    await interaction.deferReply();

    try {
      const result = await executeAgyWithRetry(prompt);
      await interaction.editReply(result.response);
    } catch (err) {
      await interaction.editReply(`エラー: ${err.message}`);
    }
  }
});
```

---

## 3. 両対応（ハイブリッド）運用の推奨

- **普段の操作**: スラッシュコマンド `/agy` をメインとして案内（入力補完が効き、権限トラブルが一切ない）。
- **自然な会話**: メンション `@mcp` にもハンドラを用意しておくことで、通常のチャット文脈からの呼び出しにも柔軟に応答可能。

---

## 4. 参考リソース

* [Discord Developer Portal: Application Commands](https://discord.com/developers/docs/interactions/application-commands)
* [discord.js Guide: Slash Commands](https://discordjs.guide/slash-commands/)
* [discord.js Guide: Deferring Responses](https://discordjs.guide/slash-commands/response-methods.html#deferred-responses)
