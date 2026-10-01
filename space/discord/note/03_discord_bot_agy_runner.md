# 03. Discord メッセージ起点で Antigravity CLI を駆動する Bot 設計

本ドキュメントは、ローカルマシン（Mac）をサーバーに見立てて常駐させ、Discord からのメッセージ受信をトリガーにしてローカルの Antigravity CLI (`agy`) を実行し、その結果を Discord へ返信する Bot システムの設計と権限回避策をまとめたものです。

---

## 1. 権限スコープ問題の解決策（Read Message / Message Content なしでの動作）

Discord API の仕様上、一般メッセージの内容を取得するには通常 `MESSAGE_CONTENT` 特権インテント（Privileged Intent）が必要ですが、**以下のいずれかの方法により、read message 権限を追加・変更せずともメッセージ内容を取得して Bot を駆動することが可能**です。

### 解決策 A: Bot へのメンション (`@mcp <プロンプト>`) 【即座に利用可能】
Discord の公式仕様により、**Bot が明示的にメンションされたメッセージに限っては、特権インテント（Message Content Intent）が無くても `message.content` を受信できる**例外規定が存在します。
- ユーザー操作: `@mcp 〇〇について教えて`
- Bot 側: メンションを検知し、メンション部分を除去した残りのテキストを `agy` に渡す。

### 解決策 B: スラッシュコマンド (`/agy <prompt>`) 【推奨】
Discord の Interactions API（スラッシュコマンド）を使用します。
- メッセージ読み取り権限や特権インテントは一切不要。
- Discord クライアント側に入力補完が表示され、最も操作性が高い。
- ユーザー操作: `/agy prompt:〇〇`

### 解決策 C: Developer Portal でトグルを ON にする（自由発言を受信したい場合）
もしメンションなしで `#ai` チャンネルの通常発言をすべて拾わせたい場合:
1. [Discord Developer Portal](https://discord.com/developers/applications) にアクセス。
2. 対象 Bot（`mcp`）を選択 -> 左メニューの **Bot** を開く。
3. **Privileged Gateway Intents** セクションの **MESSAGE CONTENT INTENT** をトグル ON にする。
4. 個人 Bot（100 サーバー未満）であれば審査なしで即時反映されます。

---

## 2. システムアーキテクチャ

1. **常駐 Bot プロセス (Runner)**:
   - ローカル Mac 上で Node.js (`discord.js`) または Python (`discord.py`) スクリプトをバックグラウンド実行。
   - Discord Gateway (WebSocket) に接続し、待受状態を維持。
2. **イベントハンドラ**:
   - メッセージ受信時、Bot 宛てのメンションまたは対象チャンネル（`#ai`: `1555181295590580295`）であることを判定。
   - Discord API に「入力中... (`sendTyping()`)」ステータスを送信。
3. **Antigravity CLI 呼び出し**:
   - サブプロセスとして `agy` を非同期実行:
     ```bash
     agy -p "<prompt>" --output-format json --dangerously-skip-permissions
     ```
   - レスポンス（JSON）から回答本文 (`response`)、所要時間、トークン消費量を抽出。
4. **Discord への返信**:
   - Discord の 1 メッセージ上限（2,000 文字）を超える場合は自動で chunk 分割して送信。
   - スレッドを作成して返信することで、チャンネルの会話が散らからないようにする構成も可能。

---

## 3. 実装アプローチ比較

| 項目 | Node.js (`discord.js`) | Python (`discord.py`) |
| :--- | :--- | :--- |
| **環境** | Node.js v26.3.0 導入済み | Python 3.14 (venv 作成が必要) |
| **イベントループ** | 非同期 I/O と子プロセス管理が標準で軽量 | asyncio を利用 |
| **依存関係管理** | `package.json` で完結 | `requirements.txt` + venv |
| **実装速度** | 単一スクリプトで即座に動作可能 | 同様 |

---

## 4. セキュリティと安全性の考慮

- **コマンド注入防止**:
  Discord から受け取ったプロンプト文字列はシェル展開（`bash -c`）を介さず、引数配列（`execFile` または `subprocess.run(args)`）として直接渡すことで、不正なシェルインジェクションを防止します。
- **実行権限の制御**:
  Bot を稼働させる専用の作業ディレクトリ（例: `/Users/aobaiwaki/ai-workspace/space/discord/bot-workspace`）を `cwd` に指定し、エージェントが関係ないディレクトリを触らないようにします。

---

## 5. 参考リソース

* [Discord Developer Portal: Message Content Intent FAQ](https://support-dev.discord.com/hc/en-us/articles/4404772028055-Message-Content-Privileged-Intent-FAQ)
* [discord.js Guide](https://discordjs.guide/)
* [Google Antigravity CLI Reference](https://antigravity.google/docs/cli/reference)
