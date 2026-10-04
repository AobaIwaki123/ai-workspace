# Google Drive MCP サーバーのセットアップ手順とアーキテクチャ (12_google_drive_mcp_setup_and_architecture.md)

本ドキュメントは、Antigravity や Claude などの AI エージェントから Google Drive 内のファイルやドキュメントを安全に検索・参照・操作するための MCP (Model Context Protocol) サーバーの選定基準、Google Cloud Console での OAuth 設定、および具体的なセットアップ手順を網羅的にまとめた解説書です。

---

## 1. Google Drive MCP の現状とエコシステム変遷

Google Drive 連携の MCP サーバーには、提供元や通信方式によって以下の 2 大アプローチが存在します。

| アプローチ | ① Google Cloud 公式 Managed MCP | ② ローカル stdio MCP (オープンソース) |
| :--- | :--- | :--- |
| **提供元** | Google 公式 (Google Cloud / Workspace) | コミュニティ保守 / MCP リファレンス |
| **通信形態** | リモート HTTPS (`https://docs.cloud.google.com/mcp`) | ローカルプロセス (`stdio`, Node.js / npx) |
| **権限・機能** | **フル操作 (Read & Write)**<br>作成、編集、削除、権限管理、共有 | **参照・検索中心 (Read-Only)**<br>検索、一覧、読み取り（Docs→Markdown変換） |
| **推奨ユースケース** | チーム運用、Web UI 連携、ファイル新規作成 | 個人開発、ローカル CLI、ドキュメント参照 |

> **知見（重要）**:
> Anthropic 公式モノレポ（`modelcontextprotocol/servers`）にあった初期の `@modelcontextprotocol/server-gdrive` は、リフレッシュトークンの自動更新バグ等の理由から 2025 年 5 月にアーカイブ（`servers-archived`）されました。
> そのため、ローカル `stdio` を利用する場合は、トークン永続化バグが修正されたコミュニティ保守版（`@modelcontextprotocol/server-google-drive` 等）または Google Cloud 公式のマネージド Remote MCP を利用するのが現在の業界標準です。

---

## 2. セットアップの完全手順 (Step-by-Step)

ここでは、最も標準的で手元環境（Antigravity CLI）から導入しやすい **OAuth 2.0 (デスクトップアプリ) を用いたローカル MCP 構成** をベースに解説します。

### Step 1: Google Cloud Console での API 有効化
1. [Google Cloud Console](https://console.cloud.google.com/) にアクセスし、プロジェクトを選択（または新規作成）。
2. 「API とサービス」>「ライブラリ」を開く。
3. **「Google Drive API」** を検索し、**有効にする** をクリック。
   * （必要に応じて Google Docs API, Google Sheets API も有効化）

### Step 2: OAuth 同意画面 (Consent Screen) の構成
1. 「API とサービス」>「OAuth 同意画面」を開く。
2. User Type で **「外部」**（組織内 Google Workspace の場合は「内部」）を選択して作成。
3. アプリ情報（アプリ名: `Antigravity Drive MCP`、ユーザーサポートメール等）を入力。
4. **スコープの追加 (最小権限の原則)**:
   * 参照のみの場合: `https://www.googleapis.com/auth/drive.readonly`
   * アプリが作成したファイルのみ操作する場合: `https://www.googleapis.com/auth/drive.file`
   * ※全権限（`drive`）は意図しないファイル変更・削除を防ぐため避けることを推奨。
5. テストユーザーに、利用する自身の Google アカウント（Gmail / Workspace アドレス）を追加して保存。

### Step 3: OAuth 2.0 クライアント ID の発行
1. 「API とサービス」>「認証情報」を開く。
2. 「認証情報を作成」> **「OAuth クライアント ID」** を選択。
3. アプリケーションの種類で **「デスクトップ アプリ (Desktop App)」** を選択。
4. 名前（例: `Drive MCP Client`）を入力して作成。
5. 作成完了画面で **「JSON をダウンロード」** をクリックし、ファイルを保存。
   * クライアント ID（`...apps.googleusercontent.com`）
   * クライアント シークレット（`GOCSPX-...`）

### Step 4: クレデンシャルの配置
ダウンロードした JSON ファイルを、安全なパスに配置しパーミッションを保護します。

```bash
# クレデンシャル保存ディレクトリを作成
mkdir -p ~/.gemini/credentials
cp ~/Downloads/client_secret_*.json ~/.gemini/credentials/gdrive-credentials.json
chmod 600 ~/.gemini/credentials/gdrive-credentials.json
```

### Step 5: Antigravity MCP 設定ファイルへの登録
`~/.gemini/config/mcp_config.json`（または対象ワークスペース設定）に以下を追記します。

```json
{
  "mcpServers": {
    "gdrive": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-google-drive"],
      "env": {
        "CLIENT_ID": "YOUR_CLIENT_ID.apps.googleusercontent.com",
        "CLIENT_SECRET": "YOUR_CLIENT_SECRET",
        "CREDENTIALS_PATH": "/Users/aobaiwaki/.gemini/credentials/gdrive-credentials.json"
      }
    }
  }
}
```

### Step 6: 初回認証（OAuth 認可フロー）
1. 初回起動時、またはターミナルから事前認証を実行すると、ブラウザが自動的に開きます。
2. Google ログイン画面で対象アカウントを選択し、アクセス許可（Google ドライブの閲覧）を「許可」します。
3. 認証が完了すると、リフレッシュトークンがローカル（例: `~/.gdrive-token.json` 等）に暗号化/保護保存され、以降はバックグラウンドで自動リフレッシュされます。

---

## 3. 提供される主要ツール一覧

MCP サーバーが正常起動すると、AI エージェントは以下のツールをネイティブに利用可能になります。

| ツール名 | 説明 | 主な引数 |
| :--- | :--- | :--- |
| `gdrive_search` | ファイル名やキーワード、更新日でドライブ内を検索 | `query` (クエリ文字列), `pageSize` |
| `gdrive_list` | 指定フォルダ内のファイルやサブフォルダを一覧表示 | `folderId` (デフォルトはルート) |
| `gdrive_read_file` | ファイルの内容を取得。Docs は Markdown、Sheets は CSV に自動変換して返却 | `fileId` (Google Drive ファイル ID) |
| `gdrive_get_metadata` | ファイルのサイズ、更新日時、オーナー、MIME タイプ等を取得 | `fileId` |

---

## 4. セキュリティとガバナンスのベストプラクティス

1. **スコープの最小化**:
   - 不要な書き込み・削除権限（`drive` フルアクセス）を与えず、`drive.readonly` に限定することで、AI による誤削除やファイル上書き事故を完全に防止します。
2. **トークンファイルのアクセス制御**:
   - `credentials.json` および認可トークンファイルは必ず `chmod 600` を適用し、Git リポジトリにコミットしないよう `.gitignore` に登録します。
3. **データ流出（Data Exfiltration）の防止**:
   - [note/11](./11_oauth_token_lifecycle_and_security_threat_model.md) で整理したプロンプトインジェクション対策と同様に、外部チャット（Discord 等）から Drive 内の機密ドキュメントを不用意に読み出して全文送信させないガードレールを意識します。

---

## 5. 権威ある参考リソース

* [Google Cloud MCP Servers Official Documentation](https://docs.cloud.google.com/mcp)
* [Google Drive API v3 Reference (Google for Developers)](https://developers.google.com/drive/api/guides/about-sdk)
* [Model Context Protocol Specification](https://modelcontextprotocol.io/)
* [Google Identity: Setting up OAuth 2.0 for Desktop Applications](https://developers.google.com/identity/protocols/oauth2/native-app)
* [OWASP Top 10 for Large Language Model Applications: Sensitive Information Disclosure](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
