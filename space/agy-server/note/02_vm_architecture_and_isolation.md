# VM (仮想マシン) を活用した Antigravity AI サーバーアーキテクチャ

本ドキュメントは、Antigravity CLI (`agy`) を Docker コンテナではなく **VM (仮想マシン / microVM)** 上で稼働させ、安全かつ柔軟な AI エージェントサーバーとして運用するためのアーキテクチャ設計、分離レベル、仮想化技術の比較、および実装構成案をまとめたものです。

---

## 1. なぜコンテナより VM が適しているのか (Why VM?)

AI エージェント（自律的にコマンドを実行し、ファイルを変更し、環境をセットアップするエージェント）をサーバー化する際、コンテナ（OSレベル仮想化）と比較して VM（ハードウェアレベル仮想化）には以下の決定的な優位性があります。

### 1.1 ハードウェアレベルの安全なサンドボックス (Isolation)
- **コンテナの限界**:
  コンテナはホストと Linux カーネルを共有するため、エージェントが特権昇格やカーネル脆弱性（Dirty COW 等）を突いた場合、コンテナブレイクアウトのリスクが存在します。
- **VM の優位性**:
  ハイパーバイザ（KVM、Apple Virtualization.framework 等）による完全なハードウェア境界で隔離されているため、エージェントが `sudo` を使って root 権限でパッケージをインストールしたり、破壊的なコマンド（誤ったファイル削除や無限ループ）を実行しても、ホストや他環境に被害が及びません。

### 1.2 フル Linux 環境（Docker in VM, systemd）のネイティブ動作
- エージェントに「アプリの Dockerfile を書いて起動してテストして」と指示する場合、コンテナ内で Docker を動かす (Docker in Docker: DinD) のは権限やストレージドライバの制約が多く不安定です。
- VM 上であれば、通常の Ubuntu / Debian マシンと全く同一であるため、`systemd`、Docker デーモン、パッケージマネージャ (`apt` / `dnf`)、各種言語ランタイムが制約なくネイティブ動作します。

### 1.3 スナップショットと高速リセット (CoW: Copy-on-Write)
- 初期セットアップ完了時点（`agy` インストール済み・認証済み・ベース開発ツール導入済み）のゴールデンイメージを作成しておけば、エージェントが作業を終えるたびに数秒で初期クリーン状態にロールバック、または状態の保存が可能です。

---

## 2. 仮想化技術と実行基盤の比較

利用環境（ローカル Mac、自前サーバー、クラウド）に応じて最適な VM 基盤を選択します。

| 仮想化技術 | 実行環境 | 起動速度 | リソース効率 | 特徴・向いている用途 |
| :--- | :--- | :--- | :--- | :--- |
| **Lima (Linux on Mac)** | macOS (Apple Silicon / Intel) | 約 5〜10 秒 | 高 (Virtualization.framework) | **Mac ローカルでの検証・開発に最適**。brew で導入でき、ポート転送やディレクトリ共有が極めて容易。 |
| **Multipass (Canonical)** | macOS / Linux / Windows | 約 10〜15 秒 | 中 (QEMU / Hyper-V) | Ubuntu 公式の軽量 VM 管理ツール。CLI 1発でインスタンスの起動・破棄が可能。 |
| **Firecracker (microVM)** | Linux (KVM 有効ホスト) | **5ミリ秒〜数秒** | **極めて高い** (数 MB RAM) | AWS Lambda / Fly.io 採用の microVM。リクエスト単位で完全な使い捨て VM を高速起動したい場合に最強。 |
| **Proxmox VE / KVM** | 自宅サーバー / 専用サーバー | 約 15〜30 秒 | 中〜高 (完全仮想化) | 24時間運用のホームラボや自前インフラ向き。Web UI や API から VM スナップショット・クローンを管理可能。 |
| **Cloud VM (GCP GCE / AWS EC2)** | パブリッククラウド | 約 30〜60 秒 | 従量課金 | 常時稼働のチーム向け API サーバー、またはスポットインスタンスでのバッチ処理。 |

---

## 3. 推奨アーキテクチャ設計 (FastAPI + agy on VM)

VM 内部に軽量な Web サーバー（FastAPI）を配置し、内部の `agy` CLI を呼び出して外部（ホストや他クライアント）に API / ストリーミングを提供する構成です。

### 3.1 システム構成要素

1. **Host OS (macOS または Linux 物理マシン)**:
   - クライアント（ブラウザ、Discord Bot、IDE、CLI）からのリクエストを受け付けるか、VM の特定ポート（例: `8080`）へ転送。
2. **VM 内部 (Guest OS: Ubuntu 24.04 LTS)**:
   - **`agy` CLI**: インストール済みバイナリ。`--dangerously-skip-permissions` で動作。
   - **認証情報**: `~/.gemini/antigravity-cli/` に保存された OAuth トークン。
   - **API ラッパー (Python FastAPI / uvicorn)**:
     - `POST /api/v1/chat`: 同期実行 (`--output-format json`)
     - `POST /api/v1/chat/stream`: SSE ストリーミング (`--output-format stream-json`)
     - `POST /api/v1/reset`: スナップショットまたはワークスペースのリセット
   - **作業ディレクトリ (`/home/ubuntu/workspace`)**:
     - エージェントが自由に変更・コード生成できる隔離ディレクトリ。
3. **通信境界**:
   - VM とホスト間は内部ブリッジネットワークまたはポートフォワーディング（`localhost:8080`）で通信。
   - 外部公開する場合は Tailscale や Cloudflare Tunnel 経由で暗号化してアクセス。

---

## 4. ローカル Mac での最短 PoC 手順 (Lima を利用する場合)

macOS 上で手軽に安全な Linux VM を立ち上げるツールとして `lima` を推奨します。

### ステップ 1: Lima のインストール
```bash
brew install lima
```

### ステップ 2: VM の作成と起動 (Ubuntu インスタンス)
```bash
# Ubuntu の軽量 VM を起動
limactl start --name=agy-server template://ubuntu-lts
```

### ステップ 3: 認証情報とバイナリの転送
ホストマシン上の認証トークンを VM 内部の対応ディレクトリに安全にコピーします。
```bash
# VM 内にディレクトリ作成
limactl shell agy-server mkdir -p ~/.gemini/antigravity-cli

# トークンと設定のコピー
limactl copy ~/.gemini/antigravity-cli/antigravity-oauth-token agy-server:~/.gemini/antigravity-cli/
limactl copy ~/.gemini/antigravity-cli/settings.json agy-server:~/.gemini/antigravity-cli/

# Linux 用 agy バイナリのインストール (または VM 内でインストーラ実行)
limactl shell agy-server -- bash -c "curl -fsSL https://antigravity.google/install.sh | bash"
```

### ステップ 4: VM 内で API サーバー起動
VM 内部のポート `8080` をホストの `8080` に転送し、FastAPI サーバーを常駐させます。

---

## 5. 本番・常時運用に向けた自動化と運用設計

1. **systemd による自動起動と常駐化**:
   - VM 起動時に FastAPI サービスが自動起動するよう `systemd` ユニットファイル (`/etc/systemd/system/agy-server.service`) を設定。
2. **ワークスペース自動クリーンアップ**:
   - セッション完了時、または一定時間経過後に `/workspace` の作業履歴を `git reset --hard` または tmpfs の再マウントでリセット。
3. **リソース制限**:
   - VM に割り当てる CPU コア数（例: 2〜4 コア）やメモリ（例: 4〜8 GB）を制限し、エージェントが暴走してもホスト OS の動作を阻害しないよう制御。

---

## 6. 関連リソース

* **Lima (Linux virtual machines on macOS)**:
  [https://github.com/lima-vm/lima](https://github.com/lima-vm/lima)
* **Firecracker microVM (AWS)**:
  [https://firecracker-microvm.github.io/](https://firecracker-microvm.github.io/)
* **Multipass (Canonical)**:
  [https://multipass.run/](https://multipass.run/)
* **Tailscale (Secure WireGuard Mesh Network)**:
  [https://tailscale.com/](https://tailscale.com/)
* **Google Antigravity CLI Reference**:
  [https://antigravity.google/docs/cli/reference](https://antigravity.google/docs/cli/reference)
