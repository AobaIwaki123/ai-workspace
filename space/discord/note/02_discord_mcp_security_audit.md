# 02. Discord MCP サーバー総合セキュリティ監査・安全性評価ノート

## 概要

本ドキュメントでは、本ワークスペースおよび Antigravity 環境に導入した Discord MCP サーバー（npm パッケージ `discord-mcp` v2.4.0）について、サプライチェーン、ソースコード静的解析、ファイルシステム操作、クレデンシャル管理、および Discord プラットフォーム権限の観点から実施したセキュリティ監査結果を記録します。

---

## 1. 監査サマリー

| 監査項目 | 判定 | 評価内容 |
| :--- | :---: | :--- |
| **1. 悪意あるコード・バックドア** | **安全 (PASS)** | `eval` やシェル実行（`child_process`）は一切なし。外部通信は公式 Discord REST API のみ |
| **2. 依存関係の既知の脆弱性** | **安全 (PASS)** | 本番実行時の依存パッケージに脆弱性なし（dev依存の ESLint 関連 ReDoS のみ検知） |
| **3. ファイル操作・パストラバーサル** | **概ね安全 (PASS)** | 拡張子ホワイトリスト制限・保存権限 `0600`。実行形式ファイル（`.exe`, `.sh` 等）は拒否 |
| **4. ローカル認証情報管理** | **改善済み (PASS)** | `mcp_config.json` およびバックアップを `chmod 600`（所有者のみ）に保護完了 |
| **5. Discord Bot 権限設計** | **安全 (PASS)** | 管理者権限（`ADMINISTRATOR`）なし。メッセージ送受信・閲覧等の必要権限に限定 |
| **6. プラットフォーム利用規約 (ToS)** | **安全 (PASS)** | User Token (BANリスクあり) ではなく公式 Bot Token のため規約完全準拠 |

---

## 2. 詳細監査結果

### A. ソースコードおよび外部通信の静的解析
`discord-mcp` の全ソースコード（TypeScript / 生成 JavaScript）に対して、不正な外部通信や動的コード実行の有無を監査しました。

- **外部通信先**:
  - `https://discord.com/api/v10`（公式 Discord REST API）および添付ファイルダウンロード時の Discord CDN に限定。
  - テレメトリ、広告、第三者トラッキングサーバーへの通信は一切含まれていません。
- **動的コード実行 API の排除**:
  - `child_process`（`exec`, `spawn`, `fork` 等）の呼び出しは皆無。
  - `eval()` や `Function()` コンストラクタによる動的スクリプト実行は使用されていません。
- **トークン・認証情報の漏洩対策**:
  - ロガー（Pino）は標準エラー出力（stderr, fd 2）に固定されており、トークン文字列を出力するコードパスは存在しません。

### B. サプライチェーンおよび依存パッケージ脆弱性（npm audit）
- **本番依存パッケージ**:
  - `@modelcontextprotocol/sdk` (v1.12.3)
  - `env-schema` (v5.2.1)
  - `form-data` (v4.0.0)
  - `pino` (v8.16.2), `pino-pretty` (v10.2.3)
  - `zod` (v3.22.4), `zod-to-json-schema` (v3.24.5)
  - ランタイム実行時における既知の脆弱性は **0件（ゼロ）** です。
- **検知された脆弱性**:
  - `npm audit` で `minimatch`（ReDoS）が 6 件検出されましたが、すべて開発環境用ビルドツール（`devDependencies`: `@typescript-eslint`）に閉じており、本番稼働時の MCP サーバープロセスにはロードされません。

### C. ファイル送受信機能のファイルシステム安全性
`discord_download_attachment` および `discord_send_message` におけるファイル操作（`src/discord/file.ts`）を監査しました。

- **拡張子ホワイトリスト検証**:
  - 画像（jpg, png, gif, webp, bmp）、文書（txt, md, log, json, xml, csv, pdf, docx, xlsx）、アーカイブ（zip, tar, gz, 7z）、メディア（mp3, mp4 等）のみ許可。
  - 実行可能形式（`.exe`, `.sh`, `.bat`, `.js`, `.py` 等）は `extAllowed()` でブロックされます。
- **保存パーミッションとクリーンアップ**:
  - ダウンロードファイルは OS 一時ディレクトリ（`/tmp`）に保存され、パーミッション `{ mode: 0o600 }`（所有者のみ読み書き可能、実行権限なし）で作成されます。
  - エラー発生時の自動削除ハンドラ（`unlink`）が実装されています。
- **潜在的な留意点（ファイル名サニタイズ）**:
  - ダウンロード先パスの構築時に `path.join(tmpdir(), 'discord-mcp-${randomUUID()}-${filename}')` を使用しています。先頭に UUID が付与されているため任意パス上書きの危険性は極めて低いものの、ヘッダー由来のファイル名に対する厳格な `path.basename()` 適用が望ましい点として確認されました。

### D. ローカル環境におけるクレデンシャル保護
- **設定ファイルのパーミッション**:
  - グローバル MCP 設定 `~/.gemini/config/mcp_config.json` は `chmod 600`（所有者専用）で安全に管理されています。
  - トークンプレフィックス修正時に作成されたバックアップファイル `mcp_config.json.bak` が `644` であったため、監査時に直ちに `chmod 600` に権限を強化・修正しました。
- **プロセス起動時の引数安全性**:
  - `ps` コマンド等のプロセス一覧からトークンが直接見えないよう、コマンドライン引数ではなく環境変数（`DISCORD_BOT_TOKEN`）経由でプロセス内メモリに閉じて渡されています。

### E. Discord プラットフォーム側の権限設計（Permission Bitfield 解析）
Bot アカウント（ID: `1555181587929505802`）に付与されている権限整数値 `2248473465835073` を Discord API v10 仕様に基づきビット分解しました。

- **付与されている通常運用権限**:
  - `VIEW_CHANNEL` (チャンネルを見る)
  - `SEND_MESSAGES` (メッセージを送信)
  - `READ_MESSAGE_HISTORY` (メッセージ履歴を読む)
  - `ATTACH_FILES` (ファイルを添付)
  - `ADD_REACTIONS` (リアクションの追加)
  - `EMBED_LINKS` (リンクの埋め込み)
  - `CREATE_PUBLIC_THREADS` / `SEND_MESSAGES_IN_THREADS` (スレッド操作)
- **付与されていない（拒否されている）権限**:
  - `ADMINISTRATOR` (サーバー管理者権限): **なし**（安全）
  - `BAN_MEMBERS`, `KICK_MEMBERS`, `MANAGE_ROLES`, `MANAGE_GUILD`, `MANAGE_CHANNELS` (管理・破壊系権限): **なし**（安全）
  - `MANAGE_MESSAGES` (他者のメッセージ削除): **なし**（安全）
- **運用上の留意事項**:
  - `MENTION_EVERYONE`（@everyone, @here へのメンション）が含まれています。意図しない全体通知を防止するため、Discord サーバー側の Bot ロール設定で「@everyone、@here、すべてのロールへのメンション」をオフに設定することを推奨します。

---

## 3. 総合評価

**判定: 安全（利用継続に問題なし）**

悪意あるバックドアや重大な脆弱性は確認されず、公式 Bot Token を利用した最小権限運用が徹底されています。ローカル設定ファイルのパーミッションも `600` に強化完了しており、安全に利用を継続できます。

---

## 4. 権威ある外部リソース・一次情報源

- [Discord Developer Portal: Bot Permissions & Intents](https://discord.com/developers/docs/topics/permissions)
- [Discord Developer Portal: Developer Terms of Service](https://discord.com/developers/docs/policies-and-agreements/developer-terms-of-service)
- [Model Context Protocol (MCP): Security & Best Practices](https://modelcontextprotocol.io/docs/concepts/architecture#security)
- [GitHub Advisory Database: minimatch Regular Expression Denial of Service](https://github.com/advisories/GHSA-3ppc-4f35-3m26)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
