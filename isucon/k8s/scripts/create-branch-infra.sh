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

# ホスト名やNamespace、Application名、クラスタ内DNS名をブランチ固有に包括置換
TARGET_NS="isucon-${BRANCH}"
TARGET_HOST="isucon-${BRANCH}.aooba.net"

# 1. manifests 以下の全 YAML 内で namespace と DNS 名を置換
find "${BASE_DIR}/manifests-${BRANCH}" -type f -name "*.yml" | while read -r file; do
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/isucon.aooba.net/${TARGET_HOST}/g" "$file"
        sed -i '' "s/namespace: isucon/namespace: ${TARGET_NS}/g" "$file"
        sed -i '' "s/isucon\.svc\.cluster\.local/${TARGET_NS}.svc.cluster.local/g" "$file"
    else
        sed -i "s/isucon.aooba.net/${TARGET_HOST}/g" "$file"
        sed -i "s/namespace: isucon/namespace: ${TARGET_NS}/g" "$file"
        sed -i "s/isucon\.svc\.cluster\.local/${TARGET_NS}.svc.cluster.local/g" "$file"
    fi
done

# 2. argocd app.yml を置換
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/name: isucon-dev/name: isucon-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
    sed -i '' "s/path: isucon\/k8s\/manifests/path: isucon\/k8s\/manifests-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
    sed -i '' "s/namespace: isucon/namespace: ${TARGET_NS}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
else
    sed -i "s/name: isucon-dev/name: isucon-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
    sed -i "s/path: isucon\/k8s\/manifests/path: isucon\/k8s\/manifests-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
    sed -i "s/namespace: isucon/namespace: ${TARGET_NS}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml"
fi

echo "✓ Created manifests-${BRANCH} and argocd-${BRANCH} (Namespace: ${TARGET_NS}, Host: ${TARGET_HOST})."
echo "💡 To create namespace: kubectl create namespace ${TARGET_NS} --dry-run=client -o yaml | kubectl apply -f -"
echo "💡 To deploy manually: kubectl apply -k isucon/k8s/manifests-${BRANCH}/"
echo "💡 To deploy with ArgoCD: argocd app create -f isucon/k8s/argocd-${BRANCH}/app.yml --upsert"

