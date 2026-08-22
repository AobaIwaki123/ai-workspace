#!/usr/bin/env bash
# ==============================================================================
# create-env.sh - メンバー/ブランチ別環境の即時作成・デプロイスクリプト
# ==============================================================================
set -euo pipefail

TARGET_BASE="${1:-./isucon/k8s}"
ENV_NAME="${2:-}"

if [[ -z "$ENV_NAME" ]]; then
  echo "Usage: $0 <k8s-base-dir> <env-name/username>"
  echo "Example: $0 ./isucon/k8s alice"
  exit 1
fi

echo "🚀 Creating dedicated ISUCON environment for '$ENV_NAME'..."

if [[ -f "$TARGET_BASE/scripts/create-branch-infra.sh" ]]; then
  "$TARGET_BASE/scripts/create-branch-infra.sh" "$ENV_NAME"
else
  echo "❌ Error: create-branch-infra.sh not found in '$TARGET_BASE/scripts'"
  exit 1
fi

echo "✓ Dedicated manifests generated: $TARGET_BASE/manifests-$ENV_NAME"
echo "✓ Dedicated ArgoCD app generated: $TARGET_BASE/argocd-$ENV_NAME"
echo ""
echo "💡 Deploy with:"
echo "   kubectl apply -k $TARGET_BASE/manifests-$ENV_NAME"
echo "   # or"
echo "   argocd app create -f $TARGET_BASE/argocd-$ENV_NAME/app.yml --upsert"
