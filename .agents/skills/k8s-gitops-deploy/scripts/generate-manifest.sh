#!/usr/bin/env bash
set -euo pipefail

# Usage: ./generate-manifest.sh [OPTIONS] <target-repo-dir>
# Generates a standard k8s/app.yaml including Namespace, Deployment, Service, and Cloudflare Ingress.

APP_NAME=""
PORT="8080"
HOST=""
HEALTH_PATH="/healthz"
OUTPUT_FILE=""

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] <target-repo-dir>

Options:
  -n, --name <name>         Application & namespace name (default: repository directory name)
  -p, --port <port>         Container port (default: 8080)
  -h, --host <host>         Cloudflare Ingress domain (default: <name>.aooba.net)
  --health-path <path>      Health check endpoint path (default: /healthz)
  -o, --output <file>       Output file path (default: <target-repo-dir>/k8s/app.yaml)
  --help                    Show this help message
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      APP_NAME="$2"
      shift 2
      ;;
    -p|--port)
      PORT="$2"
      shift 2
      ;;
    -h|--host)
      HOST="$2"
      shift 2
      ;;
    --health-path)
      HEALTH_PATH="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      if [ -z "${TARGET_DIR:-}" ]; then
        TARGET_DIR="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        usage
      fi
      ;;
  esac
done

if [ -z "${TARGET_DIR:-}" ]; then
  echo "Error: target repository directory is required." >&2
  usage
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../resources/app.yaml.template"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: template file not found at $TEMPLATE_FILE" >&2
  exit 1
fi

if [ -z "$APP_NAME" ]; then
  APP_NAME="$(basename "$TARGET_DIR" | tr '[:upper:]' '[:lower:]')"
fi

if [ -z "$HOST" ]; then
  HOST="${APP_NAME}.aooba.net"
fi

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$TARGET_DIR/k8s/app.yaml"
fi

# Detect repository owner from git remote or gh cli
IMAGE_OWNER=""
if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REMOTE_URL="$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/ ]]; then
    IMAGE_OWNER="${BASH_REMATCH[1]}"
  fi
fi

if [ -z "$IMAGE_OWNER" ] && command -v gh >/dev/null 2>&1; then
  IMAGE_OWNER="$(gh repo view --json owner -q .owner.login 2>/dev/null || true)"
fi

if [ -z "$IMAGE_OWNER" ]; then
  IMAGE_OWNER="$(whoami | tr '[:upper:]' '[:lower:]')"
fi
IMAGE_OWNER="$(echo "$IMAGE_OWNER" | tr '[:upper:]' '[:lower:]')"

# Detect initial SHA tag
INITIAL_TAG="latest"
if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  INITIAL_TAG="$(git -C "$TARGET_DIR" rev-parse --short HEAD 2>/dev/null || echo "latest")"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

sed -e "s/__APP_NAME__/$APP_NAME/g" \
    -e "s/__IMAGE_OWNER__/$IMAGE_OWNER/g" \
    -e "s/__PORT__/$PORT/g" \
    -e "s/__INITIAL_TAG__/$INITIAL_TAG/g" \
    -e "s|__HEALTH_PATH__|$HEALTH_PATH|g" \
    -e "s/__HOST__/$HOST/g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "Generated Kubernetes manifest with Cloudflare Ingress:"
echo "  Target:      $OUTPUT_FILE"
echo "  App Name:    $APP_NAME"
echo "  Image:       ghcr.io/$IMAGE_OWNER/$APP_NAME:$INITIAL_TAG"
echo "  Host:        $HOST (via ingressClassName: cloudflare-tunnel)"
echo "  Port:        $PORT (probe: $HEALTH_PATH)"
