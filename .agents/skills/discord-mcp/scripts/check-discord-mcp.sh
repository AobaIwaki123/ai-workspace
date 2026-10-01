#!/usr/bin/env bash
# check-discord-mcp.sh - Discord MCP Configuration & API Health Checker
set -euo pipefail

CONFIG_FILE="${HOME}/.gemini/config/mcp_config.json"

echo "=== Discord MCP Configuration & Health Check ==="

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] MCP config file not found: $CONFIG_FILE" >&2
  exit 1
fi

echo "[INFO] Checking config file: $CONFIG_FILE"

# Extract token using python3
TOKEN=$(python3 -c '
import json, sys
try:
    with open("'"$CONFIG_FILE"'", "r") as f:
        data = json.load(f)
    token = data.get("mcpServers", {}).get("discord", {}).get("env", {}).get("DISCORD_BOT_TOKEN", "")
    print(token)
except Exception as e:
    sys.exit(1)
')

if [[ -z "$TOKEN" ]]; then
  echo "[ERROR] DISCORD_BOT_TOKEN is not defined in $CONFIG_FILE" >&2
  exit 1
fi

echo "[INFO] DISCORD_BOT_TOKEN detected."

# Check for "Bot " prefix
if [[ "$TOKEN" =~ ^Bot\  ]]; then
  echo "[OK] Token has 'Bot ' prefix (Required by discord-mcp for Bot Token)."
  AUTH_HEADER="$TOKEN"
else
  echo "[WARNING] Token does NOT start with 'Bot ' prefix."
  echo "          discord-mcp sends the raw string as Authorization header."
  echo "          Without 'Bot ', Discord API v10 will return 401 Unauthorized."
  echo "          Use scripts/fix-token-prefix.sh to prepend 'Bot '."
  AUTH_HEADER="Bot $TOKEN"
fi

echo ""
echo "=== Discord API Connectivity Test ==="
echo "[INFO] Testing Discord API endpoint: /users/@me"

USER_RES=$(curl -s -w "\n%{http_code}" -H "Authorization: $AUTH_HEADER" https://discord.com/api/v10/users/@me)
HTTP_STATUS=$(echo "$USER_RES" | tail -n 1)
USER_BODY=$(echo "$USER_RES" | sed '$d')

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "[ERROR] Discord API returned HTTP $HTTP_STATUS" >&2
  echo "[RESPONSE] $USER_BODY" >&2
  exit 1
fi

BOT_NAME=$(python3 - "$USER_BODY" <<'EOF'
import json, sys
d = json.loads(sys.argv[1])
username = d.get("username", "Unknown")
discriminator = d.get("discriminator", "0")
user_id = d.get("id", "Unknown")
is_bot = d.get("bot", False)
print(f"{username}#{discriminator} (ID: {user_id}, Bot: {is_bot})")
EOF
)
echo "[OK] Authenticated successfully as: $BOT_NAME"

echo ""
echo "=== Joined Guilds & Accessible Channels ==="
GUILDS_RES=$(curl -s -H "Authorization: $AUTH_HEADER" https://discord.com/api/v10/users/@me/guilds)

python3 - "$GUILDS_RES" "$AUTH_HEADER" <<'EOF'
import json, sys, urllib.request

guilds_raw = sys.argv[1]
auth_header = sys.argv[2]

try:
    guilds = json.loads(guilds_raw)
except Exception:
    print("[ERROR] Failed to parse guilds response")
    sys.exit(0)

if not guilds:
    print("[INFO] Bot is not in any guilds yet. Invite the bot to a server.")
    sys.exit(0)

for g in guilds:
    gid = g.get("id")
    gname = g.get("name")
    print(f"Guild: {gname} (ID: {gid})")
    
    req = urllib.request.Request(
        f"https://discord.com/api/v10/guilds/{gid}/channels",
        headers={"Authorization": auth_header, "User-Agent": "DiscordBot-Check"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            channels = json.loads(resp.read().decode("utf-8"))
            channels.sort(key=lambda c: c.get("position", 0))
            for ch in channels:
                ctype = ch.get("type")
                ch_name = ch.get("name")
                ch_id = ch.get("id")
                type_label = "TEXT" if ctype == 0 else ("VOICE" if ctype == 2 else ("CATEGORY" if ctype == 4 else f"TYPE_{ctype}"))
                if ctype in (0, 2):
                    print(f"  - [{type_label}] #{ch_name} (ID: {ch_id})")
    except Exception as e:
        print(f"  [WARN] Could not fetch channels for guild {gid}: {e}")
EOF

echo ""
echo "[OK] Discord MCP diagnostic completed."
