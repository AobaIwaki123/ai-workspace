# 04. スラッシュコマンドとメンションの比較 & リポジトリ知識駆動 Bot 設計

本ドキュメントでは、Discord Bot における「スラッシュコマンド」と「@メンション」の仕様差、タイムアウト特性、および本リポジトリ (`ai-workspace`) の知識・スキルをフル活用して自律タスクを実行させるための設計をまとめます。

---

## 1. スラッシュコマンド vs @メンション の比較

| 観点 | スラッシュコマンド (`/agy <prompt>`) | @メンション (`@mcp <prompt>`) |
| :--- | :--- | :--- |
| **ユーザー体験 (UI/UX)** | ・`/` を入力すると補完やパラメータ説明が表示される<br>・スマホやPCで入力しやすい | ・通常のチャット感覚で話しかけられる<br>・返信（リプライ）ツリーとの親和性が高い |
| **権限要件** | **Message Content Intent 一切不要**（引数として安全に届く） | **Message Content Intent 不要**（Botメンション例外規定により取得可能） |
| **Discord API のタイムアウト制約 (超重要)** | **3秒以内に一次応答 (`deferReply`) が必須**。<br>これを超えると「インタラクションに失敗しました」となるため、即座に defer して後から `editReply` する非同期処理が必要。 | 3秒ルールのような厳格な制約はなく、`sendTyping()` を維持しながら長時間の処理結果を `channel.send()` できる。 |
| **誤爆・ノイズ** | コマンド明示のため誤爆ゼロ | 他の Bot や会話との混同が起きにくいが、メンション忘れで反応しないことがある |
| **推奨運用** | **基本はスラッシュコマンドをメインとし、メンションでも両対応させる構成がベスト** |

---

## 2. 「このリポジトリの知識をベースに任意のことをやらせる」仕組み

Antigravity CLI (`agy`) は、実行時のカレントディレクトリ (`cwd`) に存在するファイル・規約・スキルをすべて認識して推論・実行を行います。

### 2.1 実行コンテキストの渡し方
Bot スクリプトから `agy` を呼び出す際、`cwd` をリポジトリルート（`/Users/aobaiwaki/ai-workspace`）に固定します。

```javascript
// agy の呼び出しイメージ
const proc = spawn('agy', [
  '--print', prompt,
  '--output-format', 'json',
  '--dangerously-skip-permissions',
  '--effort', 'high'
], {
  cwd: '/Users/aobaiwaki/ai-workspace', // リポジトリルートを指定
  env: process.env
});
```

これにより、`agy` は以下のリソースをすべて利用可能になります:
1. **リポジトリ規約 (`AGENTS.md`)**:
   - 作業ルール、Mermaid 規約、絵文字不使用規約などを遵守。
2. **利用可能スキル (`.agents/skills/`)**:
   - `lumitree`: TimeTree 公開カレンダーからのアイドル・ライブ日程取得 (`fetch-events.py`)
   - `discord-mcp`: Discord チャンネル操作・メッセージ履歴検索
   - `auto-allow-command`: コマンド許可の自動判定
   - `stacked-pr`: PR チェーン管理
3. **過去の調査・ナレッジ (`space/*/note/`)**:
   - Discord API 連携手順、TimeTree 仕様、VM 設計など。

### 2.2 セッション維持（スレッド連携）
- Discord の **スレッド (Thread)** 機能を活用します。
- スラッシュコマンド `/agy` が実行されたら、その返答を起点に新しいスレッドを作成。
- そのスレッドの ID を `agy --conversation <conversation_id>` と紐付けて保持します。
- これにより、スレッド内で「さっきのライブの会場はどこ？」「それをDiscordに送って」と追加で発言した際、**前回の文脈（コンテキスト）を引き継いだまま連続して指示** を出せるようになります。

---

## 3. 実装ロードマップ

1. **Bot パッケージのセットアップ**:
   - `space/discord/bot/` に Node.js (`discord.js`) プロジェクトを作成。
2. **ギルド（サーバー）専用スラッシュコマンド登録**:
   - サーバーID `1034269547403943989` 宛てに即時反映される `/agy <prompt>` コマンドを登録。
3. **3秒ルール対応の非同期ハンドラ**:
   - `await interaction.deferReply()` -> `agy` サブプロセス実行 -> `await interaction.editReply()`
4. **メンションハンドラ (`on('messageCreate')`)**:
   - `@mcp <prompt>` でも同様に起動できるよう両対応化。
5. **起動スクリプトの作成**:
   - `private/.env.discord` のトークンを読み込んでワンコマンドで起動する `space/discord/scripts/run-bot.sh` を整備。
