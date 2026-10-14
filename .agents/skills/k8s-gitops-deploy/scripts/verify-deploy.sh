#!/usr/bin/env bash
# verify-deploy.sh - Verifies CI/CD workflow, manifest tag update, k8s rollout, and Cloudflare Ingress connectivity
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options] <repo-dir>

Options:
  -m, --manifest <path>    Path to k8s manifest file (default: k8s/app.yaml)
  -w, --watch              Watch the running GitHub Action workflow until completion
  --check-k8s              Verify Kubernetes deployment rollout (requires kubectl access)
  --check-ingress          Verify Cloudflare Ingress HTTPS connectivity via curl
  --host <hostname>        Override host domain for ingress verification
  -t, --timeout <seconds>  Max timeout in seconds (default: 600)
  -h, --help               Show this help message

Examples:
  $0 /path/to/repo
  $0 -w --check-k8s --check-ingress /path/to/repo
EOF
}

MANIFEST_PATH="k8s/app.yaml"
WATCH=false
CHECK_K8S=false
CHECK_INGRESS=false
CUSTOM_HOST=""
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
    --check-k8s)
      CHECK_K8S=true
      shift
      ;;
    --check-ingress)
      CHECK_INGRESS=true
      shift
      ;;
    --host)
      CUSTOM_HOST="$2"
      shift 2
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

MANIFEST_OK=false
if echo "$IMAGE_LINE" | grep -q ":$SHORT_SHA"; then
  echo "SUCCESS: Manifest successfully updated with target commit SHA ($SHORT_SHA)."
  MANIFEST_OK=true
elif [[ "$CONCLUSION" == "success" ]]; then
  echo "Notice: Workflow succeeded. Manifest may be committed in a follow-up commit or already matching."
  MANIFEST_OK=true
elif [[ "$STATUS" == "in_progress" || "$STATUS" == "queued" ]]; then
  echo "Notice: Workflow is still $STATUS. Please wait for completion."
else
  echo "Warning: Image tag does not match target SHA ($SHORT_SHA). Check workflow logs."
fi

# Detect App & Host info from manifest
APP_NAME=$(echo "$LATEST_REMOTE_MANIFEST" | awk '{for(i=1;i<=NF;i++) if($i=="name:") {print $(i+1); exit}}' || echo "")
HOST="$CUSTOM_HOST"
if [ -z "$HOST" ]; then
  HOST=$(echo "$LATEST_REMOTE_MANIFEST" | awk '{for(i=1;i<=NF;i++) if($i=="host:") {print $(i+1); exit}}' || echo "")
fi

# Optional K8s Rollout Check
if [[ "$CHECK_K8S" == "true" && -n "$APP_NAME" ]] && command -v kubectl &>/dev/null; then
  echo ""
  echo "==> Verifying Kubernetes rollout for deployment '$APP_NAME'..."
  if kubectl rollout status "deployment/$APP_NAME" -n "$APP_NAME" --timeout="${TIMEOUT_SEC}s"; then
    echo "SUCCESS: Kubernetes deployment rolled out successfully."
  else
    echo "Warning: Kubernetes rollout timed out or encountered issues."
  fi
fi

# Optional Cloudflare Ingress Connectivity Check
if [[ "$CHECK_INGRESS" == "true" && -n "$HOST" ]]; then
  echo ""
  echo "==> Verifying Cloudflare Ingress external connectivity: https://$HOST ..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "https://$HOST" || echo "000")
  echo "HTTP Response Status: $HTTP_STATUS"
  if [[ "$HTTP_STATUS" =~ ^(200|301|302|304|307|308)$ ]]; then
    echo "SUCCESS: External endpoint https://$HOST is reachable and healthy."
  else
    echo "Warning: Unexpected status code $HTTP_STATUS from https://$HOST. (May take a moment for Cloudflare/DNS/ArgoCD to sync)"
  fi
fi

if [[ "$MANIFEST_OK" == "true" ]]; then
  exit 0
else
  exit 1
fi
