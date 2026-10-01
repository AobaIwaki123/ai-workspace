#!/usr/bin/env bash
set -euo pipefail

# デフォルトチャンネル: #ai (1555181295590580295)
DEFAULT_CHANNEL_ID="1555181295590580295"

ENV_FILE="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"/private/.env.discord
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

if [[ -z "${DISCORD_BOT_TOKEN:-}" ]]; then
  echo "Error: DISCORD_BOT_TOKEN is not set. Please define it in private/.env.discord or environment." >&2
  exit 1
fi

MESSAGE="${1:-}"
CHANNEL_ID="${2:-$DEFAULT_CHANNEL_ID}"

if [[ -z "$MESSAGE" ]]; then
  echo "Usage: $0 <message> [channel_id]" >&2
  echo "Example: $0 'Hello from terminal!' 1555181295590580295" >&2
  exit 1
fi

PAYLOAD=$(node -e "console.log(JSON.stringify({ content: process.argv[1] }))" "$MESSAGE")

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "https://discord.com/api/v10/channels/$CHANNEL_ID/messages")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  MESSAGE_ID=$(node -e "console.log(JSON.parse(process.argv[1]).id)" "$BODY")
  echo "Message sent successfully! (ID: $MESSAGE_ID, Channel: $CHANNEL_ID)"
else
  echo "Failed to send message (HTTP $HTTP_CODE):" >&2
  echo "$BODY" >&2
  exit 1
fi
