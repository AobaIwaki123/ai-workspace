#!/usr/bin/env bash
# add-permission.sh - Add a command allowlist entry to Antigravity settings.json
set -euo pipefail

SETTINGS_FILE="${SETTINGS_FILE:-$HOME/.gemini/antigravity-cli/settings.json}"
WORKSPACE_SETTINGS=".agents/settings.json"

usage() {
  cat <<EOF
Usage: $0 [options] <command-pattern>

Options:
  -w, --workspace    Add to workspace settings (.agents/settings.json) instead of global
  -f, --file PATH    Explicit path to settings.json
  -t, --type TYPE    Permission type: 'allow' (default) or 'deny'
  -h, --help         Show this help message

Examples:
  $0 "git status"
  $0 -w "npm run lint.*"
  $0 -t deny "rm -rf /"
EOF
}

TARGET_TYPE="allow"
USE_WORKSPACE=false
CUSTOM_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -w|--workspace)
      USE_WORKSPACE=true
      shift
      ;;
    -f|--file)
      CUSTOM_FILE="$2"
      shift 2
      ;;
    -t|--type)
      TARGET_TYPE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  echo "Error: Command pattern is required." >&2
  usage
  exit 1
fi

CMD_PATTERN="$1"

if [[ -n "$CUSTOM_FILE" ]]; then
  TARGET_FILE="$CUSTOM_FILE"
elif [[ "$USE_WORKSPACE" == true ]]; then
  TARGET_FILE="$WORKSPACE_SETTINGS"
else
  TARGET_FILE="$SETTINGS_FILE"
fi

mkdir -p "$(dirname "$TARGET_FILE")"

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "{}" > "$TARGET_FILE"
fi

RULE_ENTRY="command($CMD_PATTERN)"

# Use python3 to safely update JSON
python3 - <<EOF
import json
import sys

target_file = "$TARGET_FILE"
rule_entry = "$RULE_ENTRY"
target_type = "$TARGET_TYPE"

try:
    with open(target_file, "r") as f:
        data = json.load(f)
except Exception:
    data = {}

if "permissions" not in data or not isinstance(data["permissions"], dict):
    data["permissions"] = {}

if target_type not in data["permissions"] or not isinstance(data["permissions"][target_type], list):
    data["permissions"][target_type] = []

if rule_entry not in data["permissions"][target_type]:
    data["permissions"][target_type].append(rule_entry)
    with open(target_file, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"✓ Added '{rule_entry}' to {target_type} in {target_file}")
else:
    print(f"• Rule '{rule_entry}' is already present in {target_type} ({target_file})")
EOF
