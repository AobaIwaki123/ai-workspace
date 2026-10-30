#!/usr/bin/env bash
set -euo pipefail

# check-updates.sh
# Audits dependencies and toolchains across npm, Go, Dockerfile, and GitHub Actions.

TARGET_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR_ABS="$(cd "$TARGET_DIR" && pwd)"

echo "=== Dependency and Toolchain Audit ==="
echo "Target directory: $TARGET_DIR_ABS"
echo ""

echo "--- 1. Toolchain Probe ---"
if command -v node >/dev/null 2>&1; then
  echo "Node.js (local): $(node -v)"
fi
if command -v npm >/dev/null 2>&1; then
  echo "npm (local): $(npm -v)"
fi
if command -v go >/dev/null 2>&1; then
  echo "Go (local): $(go version)"
fi
if command -v docker >/dev/null 2>&1; then
  echo "Docker Node (alpine latest): $(docker run --rm node:alpine node -v 2>/dev/null || echo 'Docker daemon not running')"
fi
echo ""

echo "--- 2. Renovate CLI Multi-Ecosystem Scan ---"
"$SCRIPT_DIR/run-renovate.sh" "$TARGET_DIR_ABS" || {
  echo "Renovate dry-run finished with non-zero exit or warning."
}
echo ""

echo "--- 3. Native Package Manager Audits ---"
# Check npm packages if package.json exists
find "$TARGET_DIR_ABS" -name "package.json" -not -path "*/node_modules/*" -not -path "*/.worktrees/*" | while read -r pkg_file; do
  pkg_dir="$(dirname "$pkg_file")"
  echo "NPM Outdated Check in: $pkg_dir"
  (cd "$pkg_dir" && npm outdated || true)
  echo ""
done

# Check Go modules if go.mod exists
find "$TARGET_DIR_ABS" -name "go.mod" -not -path "*/.worktrees/*" | while read -r gomod_file; do
  mod_dir="$(dirname "$gomod_file")"
  echo "Go Module Outdated Check in: $mod_dir"
  (cd "$mod_dir" && go list -u -m all 2>/dev/null | grep -E "\[" || echo "All Go modules up to date.")
  echo ""
done

echo "=== Audit Complete ==="
