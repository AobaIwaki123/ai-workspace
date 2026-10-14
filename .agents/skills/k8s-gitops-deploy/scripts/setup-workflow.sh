#!/usr/bin/env bash
# setup-workflow.sh - Installs GitOps SHA-tagging workflow into a target repo
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options] <target-repo-dir>

Options:
  -m, --manifest <path>   Path to k8s manifest file (default: k8s/app.yaml)
  -h, --help              Show this help message

Examples:
  $0 /path/to/repo
  $0 -m k8s/deployment.yaml /path/to/repo
EOF
}

MANIFEST_PATH="k8s/app.yaml"

while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--manifest)
      MANIFEST_PATH="$2"
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

TARGET_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../resources/deploy.yml"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Target directory '$TARGET_DIR' does not exist." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: Template file '$TEMPLATE_FILE' not found." >&2
  exit 1
fi

WORKFLOW_DIR="$TARGET_DIR/.github/workflows"
DEST_FILE="$WORKFLOW_DIR/deploy.yml"

mkdir -p "$WORKFLOW_DIR"
cp "$TEMPLATE_FILE" "$DEST_FILE"

# Customize manifest path if not default
if [[ "$MANIFEST_PATH" != "k8s/app.yaml" ]]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|k8s/app.yaml|$MANIFEST_PATH|g" "$DEST_FILE"
  else
    sed -i "s|k8s/app.yaml|$MANIFEST_PATH|g" "$DEST_FILE"
  fi
fi

echo "Successfully installed GitOps workflow to: $DEST_FILE"
echo "Target manifest: $MANIFEST_PATH"
