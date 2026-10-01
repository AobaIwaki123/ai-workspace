# Ubuntu VM 移行・セットアップガイド (SSH / scp 最短手順)

本ドキュメントは、ローカルマシンで検証完了した「Discord Bot Runner + Antigravity CLI」の実行環境を、外部の **Ubuntu サーバー (VM)** へ最も手数が少なくトラブルの起きにくい方法で移行・常駐稼働させるための完全手順書です。

---

## 1. 移行の前提と全体フロー

### 前提条件
- 接続先: Ubuntu 22.04 LTS または 24.04 LTS の VM
- ホスト (Mac) から `ssh user@<vm-ip>` でパスワードなし (SSH 鍵) ログインが可能
- ポート開放: **一切不要**（Discord Gateway は Bot からの Outbound HTTPS/WSS 接続のみを使用するため、Inbound ポートを開ける必要がありません）

### 最短フロー概要
1. **VM 側**: 依存パッケージ (Node.js, git) と Antigravity CLI のインストール
2. **ホスト側 -> VM 側**: 認証トークンと設定ファイルを `scp` コピー
3. **VM 側**: リポジトリの clone と Bot の起動・常駐化 (`systemd` または `tmux`)

---

## 2. ステップ 1: VM 側の基本環境構築

VM に SSH 接続し、Node.js と Antigravity CLI を導入します。

```bash
# 1. VM へ SSH ログイン
ssh user@<vm-ip>

# 2. パッケージ一覧の更新と基本ツールの導入
sudo apt update && sudo apt install -y curl git python3 python3-pip

# 3. Node.js (v22 LTS または v20 LTS) の導入 (NodeSource 経由)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# バージョン確認 (node v22.x, npm が表示されれば OK)
node -v
npm -v

# 4. Antigravity CLI (agy) のインストール
curl -fsSL https://antigravity.google/install.sh | bash

# PATH の反映確認
export PATH="$HOME/.local/bin:$PATH"
agy --help
```

---

## 3. ステップ 2: 認証情報の転送 (scp)

VM 側で Google のブラウザ認証をやり直す必要はありません。
**手元の Mac で既に認証済みの OAuth トークンを VM へコピーするだけで、即座に認証済み状態になります。**

Mac のターミナル（ローカル）から実行します:

```bash
# 1. VM 側に設定ディレクトリを作成
ssh user@<vm-ip> "mkdir -p ~/.gemini/antigravity-cli"

# 2. Google OAuth トークンと設定ファイルをコピー
scp ~/.gemini/antigravity-cli/antigravity-oauth-token user@<vm-ip>:~/.gemini/antigravity-cli/
scp ~/.gemini/antigravity-cli/settings.json user@<vm-ip>:~/.gemini/antigravity-cli/

# 3. パーミッションを保護 (600)
ssh user@<vm-ip> "chmod 600 ~/.gemini/antigravity-cli/antigravity-oauth-token"
```

### 動作確認 (VM 上で実行)
```bash
ssh user@<vm-ip>
agy -p "Respond with: SUCCESS" --output-format text
# -> "SUCCESS" と返ってくれば認証連携完了
```

---

## 4. ステップ 3: リポジトリ配置と Discord トークン設定

VM 上で本リポジトリを展開し、Discord Bot Token を配置します。

```bash
# VM 上で作業
cd ~
git clone https://github.com/AobaIwaki123/ai-workspace.git
cd ai-workspace

# private ディレクトリを作成
mkdir -p private
chmod 700 private
```

Mac（ローカル）から Discord Token ファイルをコピーします:
```bash
# Mac から実行
scp private/.env.discord user@<vm-ip>:~/ai-workspace/private/.env.discord
ssh user@<vm-ip> "chmod 600 ~/ai-workspace/private/.env.discord"
```

---

## 5. ステップ 4: Bot の起動と常駐化

VM 上で Bot の依存関係をインストールし、常駐化します。

### 手法 A: systemd による自動起動常駐化（最も推奨・再起動耐性あり）
VM 自体が再起動しても自動で復帰する運用標準の構成です。

VM 上でサービスファイルを作成します:
```bash
sudo tee /etc/systemd/system/discord-agy-bot.service <<EOF
[Unit]
Description=Antigravity Discord Bot Runner
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME/ai-workspace/space/discord/bot
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

サービスの有効化と起動:
```bash
# 初回 npm install
cd ~/ai-workspace/space/discord/bot && npm install

# サービスの登録と起動
sudo systemctl daemon-reload
sudo systemctl enable --now discord-agy-bot

# ステータス確認
sudo systemctl status discord-agy-bot
```

### 手法 B: tmux を使った手動起動（手軽にログを見たい場合）
```bash
# tmux セッション作成
tmux new -s agy-bot

# 起動
cd ~/ai-workspace
./space/discord/scripts/run-bot.sh

# デタッチ (Ctrl+B を押した後に D)
# アタッチして確認する場合: tmux a -t agy-bot
```

---

## 6. 運用・保守コマンド集

```bash
# リアルタイムログ監視
journalctl -u discord-agy-bot -f

# Bot の再起動 (コード更新時など)
sudo systemctl restart discord-agy-bot

# リポジトリの最新化
cd ~/ai-workspace
git pull origin main
sudo systemctl restart discord-agy-bot
```

---

## 7. 参考リソース

* [NodeSource Node.js Binary Distributions](https://github.com/nodesource/distributions)
* [systemd Service Management Guide](https://systemd.io/)
* [OpenSSH Manual Pages: scp](https://man.openbsd.org/scp)
* [Google Antigravity CLI Installation](https://antigravity.google/docs/cli/reference)
