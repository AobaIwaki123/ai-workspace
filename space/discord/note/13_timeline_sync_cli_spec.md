# タイムライン同期 CLI ツール設計仕様・要件定義ノート (timeline-sync CLI Spec)

このドキュメントは、AIとの壁打ちや日々のタスク管理で策定した「1日のタイムライン」や「スケジュール」を、Discordの指定チャンネル（`#ai` チャンネル等）へ即座に送信・同期する専用 CLI ツール（`timeline-sync`）の仕様・アーキテクチャ・実装要件をまとめた仕様書です。

---

## 1. 背景と解決する課題

### 1.1 現状の課題と摩擦
- 壁打ちや計画立案によって「本日のタイムライン」や「週末スケジュール」を確定させた後、出先（カフェ、移動中、現場）からそのスケジュールを確認するために、わざわざターミナルを開いたりリポジトリ内のMarkdownファイルを探す手間（閲覧摩擦）が発生している。
- 暫定運用として `space/discord/scripts/send-message.sh` や Discord MCP を利用して `#ai` チャンネルへ送信しているが、メッセージのフォーマット整形（箇条書き・Embed・リッチテキスト化）や、過去のタイムラインの上書き更新・ピン留めといった高機能な処理がシェルスクリプトでは保守しづらい。

### 1.2 目的・ゴール
- Markdownファイル（`private/memo/` や `discussion.md`）からタイムライン部分を自動抽出し、ワンコマンドで Discord の `#ai` チャンネル（ID: `1555181295590580295`）へ美しく整形された Embed / メッセージとして投稿・更新できる Go 製の専用 CLI ツール（`timeline-sync`）を構築する。

---

## 2. コマンド設計・インターフェース仕様

### 2.1 コマンド体系（CLI Interface）

```bash
# 1. テキストを直接指定してタイムラインを送信
timeline-sync send "【本日（10/29）のタイムライン】\n• 14:00〜16:00: カフェ読書..."

# 2. Markdownファイルからタイムラインを抽出して送信
timeline-sync from-file private/memo/2026-10-18-0005_handover_current_state_and_sunday_agenda.md

# 3. 直近の確定タイムラインを特定チャンネルへEmbed形式で送信（デフォルト: #ai）
timeline-sync send --channel 1555181295590580295 --embed

# 4. 前回のメッセージを上書き更新（同一日のスケジュール変更時）
timeline-sync update --message-id 1234567890 "【更新後タイムライン】..."
```

### 2.2 オプション・フラグ一覧
- `-c, --channel string`: 送信先チャンネルID（デフォルト: 環境変数 `DISCORD_TIMELINE_CHANNEL_ID` または `#ai` ID: `1555181295590580295`）
- `-e, --embed`: Discord Embed 形式（タイトル、カラーバー、フィールド構造）でリッチに装飾して送信
- `-u, --update-last`: 同一チャンネル内の直近のタイムラインメッセージを特定して Edit API で上書き更新
- `--dry-run`: 実際にDiscord APIへPOSTせず、整形されたペイロードを標準出力に表示

---

## 3. アーキテクチャとデータフロー

### 3.1 認証・設定管理
- **環境変数 / 設定ファイル**:
  - `DISCORD_BOT_TOKEN`: Discord Bot トークン（`private/.env.discord` から安全に読み込み）。
  - `DISCORD_TIMELINE_CHANNEL_ID`: デフォルトチャンネルID（`1555181295590580295`）。
- **認証情報保護**:
  - トークンやWebhook URLはリポジトリの追跡対象外（`private/` 内の `.env.discord`）に配置し、コミットを防止する。

### 3.2 タイムラインのパーサー機構（Markdown Parser）
- 入力ファイルから「タイムライン」「スケジュール」に該当するセクション（Markdown テーブルまたは箇条書きリスト）を正規表現または AST（`goldmark` 等）で自動抽出。
- 抽出したブロックを Discord の Embed フィールド（`Time`, `Task`, `Detail`）または Discord Markdown 形式に正規化。

---

## 4. 実装フェーズ（Roadmap）

| Phase | 項目 | 内容 |
| :--- | :--- | :--- |
| **Phase 1** | **PoC（最小送信CLI）** | Go 標準ライブラリ（`net/http`）を用いたシンプルなメッセージ送信機能の実装。 |
| **Phase 2** | **Embed 構築 & 整形** | Discord Webhook / REST API 仕様に準拠した Embed ペイロードビルダーの実装。 |
| **Phase 3** | **Markdown 自動抽出** | `discussion.md` や `private/memo/` からタイムライン表を解析するパーサーの実装。 |
| **Phase 4** | **更新・同期機構** | 過去メッセージの Edit（上書き）やピン留め連携機能の追加。 |

---

## 5. 参考文献 (Authoritative References)

- [Discord Developer Portal: Execute Webhook](https://discord.com/developers/docs/resources/webhook#execute-webhook) - Discord 公式 Webhook 実行・ペイロード仕様
- [Discord Developer Portal: Create Message](https://discord.com/developers/docs/resources/channel#create-message) - Discord REST API メッセージ作成仕様
- [Discord Developer Portal: Embed Object](https://discord.com/developers/docs/resources/channel#embed-object) - Discord Embed 構造仕様
- [The Go Programming Language: Standard Library](https://pkg.go.dev/std) - Go 標準ライブラリ公式ドキュメント
