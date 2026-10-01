# Antigravity CLI コンテナサーバー化の実現可能性とアーキテクチャ設計

本ドキュメントは、Antigravity CLI (`agy`) をコンテナ (Docker / OCI) 環境下でヘッドレス実行し、外部からの API リクエスト（HTTP / SSE / WebSocket）を処理する AI エージェントサーバーとして構築・運用するための技術的実現性、アーキテクチャ選定、セキュリティ境界、および実装方針をまとめたものです。

---

## 1. 結論（実現可能性サマリー）

結論から述べると、**十分に実現可能であり、Antigravity CLI 自体がヘッドレスおよびプロセス間通信（IPC）を前提とした豊富なネイティブフラグ・出力形式を既に備えています**。

具体的には以下の要素が確認されています:
1. **非対話型実行モード (`--print` / `-p`)**:
   TTY (対話的ターミナル) を要求せず、引数としてプロンプトを受け取り、結果を標準出力に返して正常終了します。
2. **NDJSON ストリーミング (`--output-format stream-json`)**:
   推論思考 (`thoughts`)、ツール実行 (`tool_calls`)、テキスト生成デルタ (`text_delta`)、トークン消費量 (`usage`) が構造化された NDJSON (Newline Delimited JSON) で逐次出力されます。これは Server-Sent Events (SSE) や WebSocket にそのまま透過転送可能です。
3. **常駐プロセス間通信 (`--input-format stream-json --output-format stream-json`)**:
   標準入力 (stdin) から 1 行ごとに NDJSON メッセージを読み込み、ターンごとに実行して標準出力に逐次返す機能が備わっており、子プロセスを常駐させたデーモン通信が可能です。
4. **自動権限承認 (`--dangerously-skip-permissions`)**:
   CLI 特有の「コマンド実行・ファイル書き込み時の対話的確認プロンプト」を完全にバイパスし、無人・自動実行が可能です。
5. **ステートフルセッション管理 (`--conversation <id>`)**:
   会話 ID を保持・指定することで、複数ターンにわたるコンテキストを跨いだ対話の継続が可能です。

---

## 2. アーキテクチャパターンの比較検討

コンテナ内で Antigravity をサーバー化するアプローチとして、以下の 3 つの方式が考えられます。

| 方式 | 概要 | メリット | デメリット・注意点 | 推奨ユースケース |
| :--- | :--- | :--- | :--- | :--- |
| **A. Subprocess On-Demand 方式** | Web サーバー (FastAPI/Go/Node) がリクエストごとに `agy -p` を子プロセスとして起動 | ・最もシンプルで実装・保守が容易<br>・リクエスト単位でメモリやプロセスが完全隔離<br>・クラッシュ耐性が高い | ・リクエストごとにプロセス起動オーバーヘッド（1〜2秒程度）が発生<br>・多重同時実行時のリソース消費が大きい | バッチ処理、PoC、低〜中頻度の非同期ジョブ、CI連携 |
| **B. NDJSON Persistent IPC 方式** | コンテナ起動時に `agy --input-format stream-json --output-format stream-json` を常駐させ、パイプで対話 | ・起動オーバーヘッドが初回のみで高速レスポンス<br>・標準入出力経由のクリーンなストリーミング | ・プロセス生存監視・ヘルスチェックの実装が必要<br>・エージェントが異常停止した場合のリカバリ設計が必要 | 高頻度なチャットサービス、リアルタイムBot (Discord/Slack等) |
| **C. Python SDK 組み込み方式** | 公式 Python SDK (`google-antigravity`) を用いて FastAPI などの非同期ループ内で直接実行 | ・外部プロセスの起動・パイプ管理が不要<br>・Python コード内で思考・ツール呼び出しを型安全にフック可能 | ・`google-antigravity` の wheel パッケージ（プラットフォーム依存バイナリ）の入手が必要<br>・Python ランタイムに限定される | 高度なカスタマイズ、独自ツールの動的インジェクション |

---

## 3. コンテナ化 (Docker) における主要な設計課題と防衛策

### 3.1 認証情報 (Authentication) の注入
`agy` は実行時に Google OAuth トークン (`~/.gemini/antigravity-cli/antigravity-oauth-token`) または設定ファイル (`settings.json`) を参照します。

- **推奨方式 (Secret Volume Mount)**:
  ホスト側で認証済みのトークンディレクトリを Kubernetes Secret や Docker Read-Only Volume としてマウントします。
  ```bash
  docker run -d \
    -v ~/.gemini/antigravity-cli/antigravity-oauth-token:/root/.gemini/antigravity-cli/antigravity-oauth-token:ro \
    -v ~/.gemini/antigravity-cli/settings.json:/root/.gemini/antigravity-cli/settings.json:ro \
    -p 8080:8080 \
    my-antigravity-server
  ```
- **環境変数方式**:
  `GEMINI_API_KEY` または Vertex AI 用のサービスアカウント認証情報 (`GOOGLE_APPLICATION_CREDENTIALS`) が利用可能な場合は、12-Factor App に則りコンテナ環境変数から読み込ませます。

### 3.2 セキュリティとサンドボックス隔離 (最重要)
Antigravity は強力な自律エージェントであり、コード生成・コマンド実行 (`run_command`)・ファイル編集 (`write_to_file`) ツールを持ちます。
コンテナ内で `--dangerously-skip-permissions` を有効化して外部リクエストを受け付ける場合、**実質的にリモートコード実行 (RCE) が可能な環境**となります。

**必須防衛策**:
1. **コンテナ自体の非特権化**:
   - `root` ユーザーでの実行を禁止し、専用の非特権ユーザー（例: `uid 1000: agy`）でコンテナを動かします。
   - コンテナの `cap-drop=ALL` を適用し、不要な Linux ケーパビリティを全て剥奪します。
2. **ルートファイルシステムの読み取り専用化 (`read-only rootfs`)**:
   - 作業領域 (`/workspace`) および一時ディレクトリ (`/tmp`) のみを書き込み可能な `tmpfs` または使い捨てボリュームとします。
3. **ネットワーク境界**:
   - 外部インターネットへのアクセスが必要最小限（Google API / Vertex AI のドメインのみ）に限定されるよう、NetworkPolicy や Egress フィルタリングを設定します。
4. **使い捨てサンドボックス (Ephemeral Environment)**:
   - 破壊的なコード実行やビルドを伴うタスクの場合、Kubernetes Job や Firecracker microVM などの軽量仮想化環境をリクエスト単位で起動・破棄する構成を推奨します。

### 3.3 可観測性 (Observability) と ストリーミング配信
- **プロトコル**:
  `agy --output-format stream-json` から出力される NDJSON をそのまま利用し、FastAPI / Starlette の `StreamingResponse` または SSE (`text/event-stream`) 形式でクライアントにプッシュします。
- **構造化ロギング**:
  サーバー側ログには、リクエストID、会話ID (`conversation_id`)、実行秒数 (`duration_seconds`)、消費トークン数 (`usage.total_tokens`, `usage.thinking_tokens`) を構造化ログ (JSON) として出力します。

---

## 4. プロトタイプ実装構成案

### 4.1 コンテナイメージ構成 (Dockerfile 概要)
```dockerfile
FROM debian:bookworm-slim

# 依存パッケージのインストール (curl, git, python3 など)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 非特権ユーザーの作成
RUN useradd -m -u 1000 -s /bin/bash agyuser

# agy バイナリの配置 (Linux 用バイナリを配置)
COPY bin/agy /usr/local/bin/agy
RUN chmod +x /usr/local/bin/agy

# サーバーアプリケーションコードの配置
WORKDIR /app
COPY app/ /app/
RUN pip install --no-cache-dir fastapi uvicorn

USER agyuser
WORKDIR /workspace

EXPOSE 8080
CMD ["uvicorn", "main:app", "--app-dir", "/app", "--host", "0.0.0.0", "--port", "8080"]
```

### 4.2 FastAPI ラッパー実装イメージ (`main.py`)
```python
import json
import subprocess
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

app = FastAPI(title="Antigravity Agent API Server")

class ChatRequest(BaseModel):
    prompt: str
    conversation_id: str | None = None
    effort: str = "high"

@app.post("/api/v1/chat")
def chat(req: ChatRequest):
    cmd = [
        "agy",
        "--print", req.prompt,
        "--output-format", "json",
        "--dangerously-skip-permissions",
        "--effort", req.effort,
    ]
    if req.conversation_id:
        cmd.extend(["--conversation", req.conversation_id])

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail=result.stderr)

    return json.loads(result.stdout)

@app.post("/api/v1/chat/stream")
def chat_stream(req: ChatRequest):
    cmd = [
        "agy",
        "--print", req.prompt,
        "--output-format", "stream-json",
        "--dangerously-skip-permissions",
        "--effort", req.effort,
    ]
    if req.conversation_id:
        cmd.extend(["--conversation", req.conversation_id])

    def event_generator():
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        for line in proc.stdout:
            if line.strip():
                yield f"data: {line.strip()}\n\n"
        proc.wait()

    return StreamingResponse(event_generator(), media_type="text/event-stream")
```

---

## 5. 参考リソース・一次情報源

* **Google Antigravity 公式 CLI ドキュメント**:
  [https://antigravity.google/docs/cli/reference](https://antigravity.google/docs/cli/reference)
* **Google Antigravity Python SDK リポジトリ**:
  [https://github.com/google-antigravity/antigravity-sdk-python](https://github.com/google-antigravity/antigravity-sdk-python)
* **CIS Docker Benchmark (コンテナセキュリティ基準)**:
  [https://www.cisecurity.org/benchmark/docker](https://www.cisecurity.org/benchmark/docker)
* **The Twelve-Factor App (クラウドネイティブ設計原則)**:
  [https://12factor.net/](https://12factor.net/)
* **gVisor (Google 提供の安全なコンテナサンドボックスランタイム)**:
  [https://gvisor.dev/](https://gvisor.dev/)
