#!/usr/bin/env bash
# deploy-to-vm.sh - Deploy Discord Bot and tokens from local machine to VM
set -euo pipefail

TARGET_HOST="${1:-discord-bot.vm}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

OAUTH_TOKEN="$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
DISCORD_ENV="$WORKSPACE_ROOT/private/.env.discord"

echo "=== Deploying Discord Bot to $TARGET_HOST ==="

# 1. 必要なローカル認証ファイルの検証
if [[ ! -f "$OAUTH_TOKEN" ]]; then
  echo "Error: Google OAuth token not found at $OAUTH_TOKEN"
  exit 1
fi
if [[ ! -f "$DISCORD_ENV" ]]; then
  echo "Error: Discord token file not found at $DISCORD_ENV"
  exit 1
fi

# 2. 対象ホストの SSH 疎通確認
echo "Checking SSH connectivity to $TARGET_HOST..."
ssh -o ConnectTimeout=5 "$TARGET_HOST" "hostname" > /dev/null
echo "SSH connection verified."

# 3. リモートディレクトリ作成
echo "Preparing remote directories..."
ssh "$TARGET_HOST" "mkdir -p ~/.gemini/antigravity-cli ~/ai-workspace/private"

# 4. 認証トークンの転送
echo "Transferring authentication tokens..."
scp -p "$OAUTH_TOKEN" "$TARGET_HOST:~/.gemini/antigravity-cli/antigravity-oauth-token"
ssh "$TARGET_HOST" "chmod 600 ~/.gemini/antigravity-cli/antigravity-oauth-token"

scp -p "$DISCORD_ENV" "$TARGET_HOST:~/ai-workspace/private/.env.discord"
ssh "$TARGET_HOST" "chmod 600 ~/ai-workspace/private/.env.discord"

# settings.json があれば転送
if [[ -f "$HOME/.gemini/antigravity-cli/settings.json" ]]; then
  scp -p "$HOME/.gemini/antigravity-cli/settings.json" "$TARGET_HOST:~/.gemini/antigravity-cli/settings.json"
fi

# 5. リポジトリコードの同期 (rsync)
echo "Syncing workspace code to $TARGET_HOST..."
rsync -avz --delete \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '.venv' \
  --exclude '__pycache__' \
  --exclude 'private' \
  "$WORKSPACE_ROOT/" "$TARGET_HOST:~/ai-workspace/"

# 6. リモートでセットアップスクリプトを実行
echo "Running setup-vm-bot.sh on $TARGET_HOST..."
ssh -t "$TARGET_HOST" "cd ~/ai-workspace && sudo ./space/discord/scripts/setup-vm-bot.sh"

echo "=== Deployment to $TARGET_HOST Completed Successfully ==="
