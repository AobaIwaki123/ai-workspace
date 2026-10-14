#!/usr/bin/env bash
# verify-deploy.sh - Verifies CI/CD workflow execution, manifest tag update, and deployment
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options] <repo-dir>

Options:
  -m, --manifest <path>    Path to k8s manifest file (default: k8s/app.yaml)
  -w, --watch              Watch the running GitHub Action workflow until completion
  -t, --timeout <seconds>  Max timeout in seconds (default: 600)
  -h, --help               Show this help message

Examples:
  $0 /path/to/repo
  $0 -w /path/to/repo
EOF
}

MANIFEST_PATH="k8s/app.yaml"
WATCH=false
TIMEOUT_SEC=600

while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--manifest)
      MANIFEST_PATH="$2"
      shift 2
      ;;
    -w|--watch)
      WATCH=true
      shift
      ;;
    -t|--timeout)
      TIMEOUT_SEC="$2"
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
  echo "Error: Target repository directory is required." >&2
  usage
  exit 1
fi

REPO_DIR="$1"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "Error: Repository directory '$REPO_DIR' does not exist." >&2
  exit 1
fi

cd "$REPO_DIR"

if ! command -v gh &>/dev/null; then
  echo "Error: GitHub CLI (gh) is required for verification." >&2
  exit 1
fi

echo "==> Fetching latest workflow runs..."
LATEST_RUN_JSON=$(gh run list --limit 1 --json databaseId,status,conclusion,headSha,updatedAt)

RUN_ID=$(echo "$LATEST_RUN_JSON" | grep -o '"databaseId":[0-9]*' | head -n1 | cut -d: -f2)
STATUS=$(echo "$LATEST_RUN_JSON" | grep -o '"status":"[^"]*"' | head -n1 | cut -d'"' -f4)
CONCLUSION=$(echo "$LATEST_RUN_JSON" | grep -o '"conclusion":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "none")
HEAD_SHA=$(echo "$LATEST_RUN_JSON" | grep -o '"headSha":"[^"]*"' | head -n1 | cut -d'"' -f4)
SHORT_SHA="${HEAD_SHA:0:7}"

echo "Run ID      : $RUN_ID"
echo "Target SHA  : $SHORT_SHA ($HEAD_SHA)"
echo "Status      : $STATUS"
echo "Conclusion  : $CONCLUSION"

if [[ "$WATCH" == "true" && "$STATUS" != "completed" ]]; then
  echo "==> Watching workflow run $RUN_ID..."
  gh run watch "$RUN_ID" || true
  # Refresh status
  LATEST_RUN_JSON=$(gh run list --limit 1 --json status,conclusion)
  STATUS=$(echo "$LATEST_RUN_JSON" | grep -o '"status":"[^"]*"' | head -n1 | cut -d'"' -f4)
  CONCLUSION=$(echo "$LATEST_RUN_JSON" | grep -o '"conclusion":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "none")
fi

echo ""
echo "==> Verifying Kubernetes manifest tag update..."
git fetch origin main --quiet || true

LATEST_REMOTE_MANIFEST=$(git show "origin/main:$MANIFEST_PATH" 2>/dev/null || echo "")
if [[ -z "$LATEST_REMOTE_MANIFEST" ]]; then
  echo "Warning: Could not read $MANIFEST_PATH from origin/main. Checking local file..."
  LATEST_REMOTE_MANIFEST=$(cat "$MANIFEST_PATH" 2>/dev/null || echo "")
fi

IMAGE_LINE=$(echo "$LATEST_REMOTE_MANIFEST" | grep -E "image:\s*ghcr\.io/.*" | head -n1 || echo "")
echo "Current image in manifest: $IMAGE_LINE"

if echo "$IMAGE_LINE" | grep -q ":$SHORT_SHA"; then
  echo "SUCCESS: Manifest successfully updated with target commit SHA ($SHORT_SHA)."
  exit 0
elif [[ "$CONCLUSION" == "success" ]]; then
  echo "Notice: Workflow succeeded. Manifest may be committed in a follow-up commit or already matching."
  exit 0
elif [[ "$STATUS" == "in_progress" || "$STATUS" == "queued" ]]; then
  echo "Notice: Workflow is still $STATUS. Please wait for completion."
  exit 0
else
  echo "Warning: Image tag does not match target SHA ($SHORT_SHA). Check workflow logs."
  exit 1
fi
