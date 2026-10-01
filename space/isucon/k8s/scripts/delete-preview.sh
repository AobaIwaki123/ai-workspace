#!/usr/bin/env bash
# ==============================================================================
# delete-preview.sh - Preview環境をきれいに削除するスクリプト
# ==============================================================================
set -euo pipefail

ENV_NAME="${1:-}"
if [ -z "$ENV_NAME" ]; then
    echo "Usage: $0 <preview-name>"
    echo "Example: $0 pr10"
    exit 1
fi

APP_NAME="isucon-${ENV_NAME}"
NAMESPACE="isucon-${ENV_NAME}"

echo "==> Deleting preview environment '${APP_NAME}'..."

# ArgoCD Application 削除 (finalizer で全リソースが自動削除される)
kubectl delete application -n argocd "${APP_NAME}" --ignore-not-found=true

# Namespace 削除
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true

echo "✓ Deleted preview environment '${APP_NAME}'."
