#!/usr/bin/env bash
set -euo pipefail

# run-renovate.sh
# Runs Renovate CLI dry-run lookup against the specified directory or current repo.

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

# Retrieve GitHub Token if available via GitHub CLI
GITHUB_TOKEN="${GITHUB_COM_TOKEN:-}"
if [[ -z "$GITHUB_TOKEN" ]] && command -v gh >/dev/null 2>&1; then
  GITHUB_TOKEN="$(gh auth token 2>/dev/null || echo "")"
fi

export GITHUB_COM_TOKEN="$GITHUB_TOKEN"
export RENOVATE_REQUIRE_CONFIG="ignored"
export RENOVATE_ONBOARDING="false"
export LOG_LEVEL="${LOG_LEVEL:-info}"

echo "Starting Renovate dry-run lookup in $(pwd)..."
npx --yes renovate --platform=local --dry-run=lookup
