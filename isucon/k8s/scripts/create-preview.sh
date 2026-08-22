#!/usr/bin/env bash
# ==============================================================================
# create-preview.sh - ブランチ/PRごとの独立Preview環境をArgoCDで立ち上げるスクリプト
# ==============================================================================
set -euo pipefail

ENV_NAME="${1:-}"
BRANCH="${2:-}"

if [ -z "$ENV_NAME" ] || [ -z "$BRANCH" ]; then
    echo "Usage: $0 <preview-name> <branch-name>"
    echo "Example: $0 frontend-ui feature/isucon-frontend-ui"
    exit 1
fi

APP_NAME="isucon-${ENV_NAME}"
NAMESPACE="isucon-${ENV_NAME}"
HOST="${APP_NAME}.aooba.net"

echo "=========================================="
echo "🚀 Preview 環境をデプロイします..."
echo "Application: ${APP_NAME}"
echo "Namespace:   ${NAMESPACE}"
echo "Branch:      ${BRANCH}"
echo "Host URL:    https://${HOST}"
echo "=========================================="

# 1. Namespace 作成
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# 2. ArgoCD Application マニフェストを生成 & 適用 (Kustomize Ingress パッチ付き)
cat <<EOF | kubectl apply -n argocd -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://github.com/AobaIwaki123/ai-workspace'
    targetRevision: '${BRANCH}'
    path: isucon/k8s/manifests
    kustomize:
      namespace: ${NAMESPACE}
      patches:
        - target:
            kind: Ingress
            name: isucon-ingress
          patch: |-
            - op: replace
              path: /spec/rules/0/host
              value: ${HOST}
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
EOF

# 3. Hard refresh & Sync 指示
sleep 3
kubectl patch application -n argocd "${APP_NAME}" --type merge -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}' || true

echo "✓ Preview 環境 '${APP_NAME}' を作成しました！"
echo "🌐 アクセスURL: https://${HOST}"
echo "💡 削除コマンド: ./isucon/k8s/scripts/delete-preview.sh ${ENV_NAME}"
