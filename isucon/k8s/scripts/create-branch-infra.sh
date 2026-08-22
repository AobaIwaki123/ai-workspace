#!/usr/bin/env bash
# ==============================================================================
# create-branch-infra.sh - ブランチ/ユーザー別の独立k8s環境を作成するスクリプト
# ==============================================================================
set -euo pipefail

BRANCH="${1:-}"
if [ -z "$BRANCH" ]; then
    echo "Usage: $0 <branch-or-username>"
    echo "Example: $0 alice"
    exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Creating branch infra for '${BRANCH}'..."

cp -r "${BASE_DIR}/manifests" "${BASE_DIR}/manifests-${BRANCH}"
cp -r "${BASE_DIR}/argocd" "${BASE_DIR}/argocd-${BRANCH}"

# ホスト名やNamespace、Application名をブランチ固有に置換
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed
    sed -i '' "s/isucon.aooba.net/isucon-${BRANCH}.aooba.net/g" "${BASE_DIR}/manifests-${BRANCH}/ingress.yml"
    sed -i '' "s/name: isucon-dev/name: isucon-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
    sed -i '' "s/path: isucon\/k8s\/manifests/path: isucon\/k8s\/manifests-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
else
    # Linux sed
    sed -i "s/isucon.aooba.net/isucon-${BRANCH}.aooba.net/g" "${BASE_DIR}/manifests-${BRANCH}/ingress.yml"
    sed -i "s/name: isucon-dev/name: isucon-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
    sed -i "s/path: isucon\/k8s\/manifests/path: isucon\/k8s\/manifests-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
fi

echo "✓ Created manifests-${BRANCH} and argocd-${BRANCH}."
echo "💡 To deploy with ArgoCD: argocd app create -f isucon/k8s/argocd-${BRANCH}/app.yml --upsert"
echo "💡 To deploy manually: kubectl apply -k isucon/k8s/manifests-${BRANCH}/"
