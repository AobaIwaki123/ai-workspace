#!/usr/bin/env bash
set -euo pipefail

# Usage: ./setup-argocd.sh [OPTIONS] <target-repo-dir>
# Generates and optionally applies an ArgoCD Application manifest for the repository.

APP_NAME=""
MANIFEST_PATH="k8s"
APPLY=false
OUTPUT_FILE=""

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] <target-repo-dir>

Options:
  -n, --name <name>         ArgoCD application name (default: repository directory name)
  -p, --path <path>         Path within repo containing manifests (default: k8s)
  --apply                   Apply directly to cluster via kubectl
  -o, --output <file>       Output file path (default: print to stdout if not applying)
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
    -p|--path)
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --apply)
      APPLY=true
      shift
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
TEMPLATE_FILE="$SCRIPT_DIR/../resources/argocd-app.yaml.template"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: template file not found at $TEMPLATE_FILE" >&2
  exit 1
fi

if [ -z "$APP_NAME" ]; then
  APP_NAME="$(basename "$TARGET_DIR" | tr '[:upper:]' '[:lower:]')"
fi

# Detect repo slug
REPO_SLUG=""
if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REMOTE_URL="$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    REPO_SLUG="${BASH_REMATCH[1]}"
  fi
fi

if [ -z "$REPO_SLUG" ] && command -v gh >/dev/null 2>&1; then
  REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi

if [ -z "$REPO_SLUG" ]; then
  echo "Error: could not detect GitHub repository slug (owner/repo). Please ensure git remote origin is configured." >&2
  exit 1
fi

GENERATED="$(sed -e "s|__APP_NAME__|$APP_NAME|g" \
                 -e "s|__REPO_SLUG__|$REPO_SLUG|g" \
                 -e "s|__MANIFEST_PATH__|$MANIFEST_PATH|g" \
                 "$TEMPLATE_FILE")"

if [ -n "$OUTPUT_FILE" ]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  echo "$GENERATED" > "$OUTPUT_FILE"
  echo "ArgoCD Application manifest written to $OUTPUT_FILE"
fi

if [ "$APPLY" = true ]; then
  echo "$GENERATED" | kubectl apply -f -
  echo "ArgoCD Application '$APP_NAME' applied successfully to cluster."
elif [ -z "$OUTPUT_FILE" ]; then
  echo "$GENERATED"
fi
