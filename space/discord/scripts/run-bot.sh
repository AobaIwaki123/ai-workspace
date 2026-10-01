#!/usr/bin/env bash
# run-bot.sh - Start the Antigravity Discord Bot Runner
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BOT_DIR="$WORKSPACE_ROOT/space/discord/bot"

echo "=== Starting Antigravity Discord Bot Runner ==="
echo "Workspace root: $WORKSPACE_ROOT"
echo "Bot directory: $BOT_DIR"

cd "$BOT_DIR"

# 依存パッケージの存在確認
if [[ ! -d "node_modules" ]]; then
  echo "Installing dependencies..."
  npm install
fi

# スラッシュコマンドの登録確認（必要時）
if [[ "${1:-}" == "--register" ]]; then
  echo "Registering slash commands..."
  node register-commands.js
fi

echo "Launching bot..."
exec node index.js
