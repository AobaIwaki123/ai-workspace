#!/usr/bin/env bash
# fix-token-prefix.sh - Prepend 'Bot ' prefix to DISCORD_BOT_TOKEN in mcp_config.json
set -euo pipefail

CONFIG_FILE="${HOME}/.gemini/config/mcp_config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

python3 - "$CONFIG_FILE" <<'EOF'
import json
import sys
import shutil

config_path = sys.argv[1]

with open(config_path, "r", encoding="utf-8") as f:
    data = json.load(f)

servers = data.get("mcpServers", {})
discord = servers.get("discord", {})
env = discord.get("env", {})
token = env.get("DISCORD_BOT_TOKEN", "")

if not token:
    print("[ERROR] DISCORD_BOT_TOKEN not found in mcp_config.json")
    sys.exit(1)

if token.startswith("Bot "):
    print("[INFO] DISCORD_BOT_TOKEN already has 'Bot ' prefix. No changes needed.")
    sys.exit(0)

# Create backup
bak_path = f"{config_path}.bak"
shutil.copyfile(config_path, bak_path)
import os
os.chmod(bak_path, 0o600)
print(f"[INFO] Backup created at: {bak_path} (mode: 600)")

# Update token
env["DISCORD_BOT_TOKEN"] = f"Bot {token}"
discord["env"] = env
servers["discord"] = discord
data["mcpServers"] = servers

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("[OK] Successfully prepended 'Bot ' prefix to DISCORD_BOT_TOKEN.")
print("[NOTE] If an MCP server process is already running, restart the session or agy CLI to reload the environment variable.")
EOF
