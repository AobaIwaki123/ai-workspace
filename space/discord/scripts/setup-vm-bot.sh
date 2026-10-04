#!/usr/bin/env bash
# setup-vm-bot.sh - Setup dependencies and systemd service for Discord Bot on VM
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BOT_DIR="$WORKSPACE_ROOT/space/discord/bot"

RUN_USER="${SUDO_USER:-$(whoami)}"
RUN_HOME="$(eval echo "~$RUN_USER")"

echo "=== Discord Bot VM Setup ==="
echo "Target User: $RUN_USER"
echo "Target Home: $RUN_HOME"
echo "Workspace:   $WORKSPACE_ROOT"
echo "Bot Dir:     $BOT_DIR"

# 1. Node.js (v22 / v20) の確認とインストール
if ! command -v node >/dev/null 2>&1; then
  echo "Installing Node.js (v22 LTS)..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "Node.js is already installed: $(node -v)"
fi

# 2. Antigravity CLI (agy) の確認とインストール
if ! command -v agy >/dev/null 2>&1 && [[ ! -f "$RUN_HOME/.local/bin/agy" ]]; then
  echo "Installing Antigravity CLI (agy)..."
  sudo -u "$RUN_USER" bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash"
else
  echo "Antigravity CLI (agy) is already installed."
fi

# 3. Bot 依存パッケージのインストール
echo "Installing npm dependencies in $BOT_DIR..."
sudo -u "$RUN_USER" bash -c "cd '$BOT_DIR' && npm install"

# 4. systemd サービスファイルの生成
SERVICE_FILE="/etc/systemd/system/discord-agy-bot.service"
echo "Creating systemd service: $SERVICE_FILE"

cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Antigravity Discord Bot Runner
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$BOT_DIR
Environment=PATH=$RUN_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$(which node) index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 5. systemd リロードと自動起動・起動
echo "Reloading systemd and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable --now discord-agy-bot

echo "=== Setup Completed Successfully ==="
sudo systemctl status discord-agy-bot --no-pager
