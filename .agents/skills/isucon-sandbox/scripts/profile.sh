#!/usr/bin/env bash
# ==============================================================================
# profile.sh - ISUCON 測定ログ (alp / pt-query-digest) の一括解析スクリプト
# ==============================================================================
set -euo pipefail

MODE="${1:-local}" # "local" or "k8s"
TARGET_DIR="${2:-.}"
ALP_MATCH="${3:-/api/posts/[0-9]+}"

case "$MODE" in
  local)
    echo "📊 Running local analysis (alp & slow-query)..."
    if [[ -f "$TARGET_DIR/logs/nginx/access.log" ]]; then
      echo "=== Nginx Access Log (alp) ==="
      docker run --rm -v "$(cd "$TARGET_DIR" && pwd)/logs/nginx:/var/log/nginx" tkuchiki/alp:latest ltsv --file=/var/log/nginx/access.log --sort=sum -r -m "$ALP_MATCH"
    else
      echo "⚠️ No nginx access log found in $TARGET_DIR/logs/nginx/access.log"
    fi

    if [[ -f "$TARGET_DIR/logs/mysql/mysql-slow.log" ]]; then
      echo ""
      echo "=== MySQL Slow Query Log (pt-query-digest) ==="
      docker run --rm -v "$(cd "$TARGET_DIR" && pwd)/logs/mysql:/var/log/mysql" percona/percona-toolkit:latest pt-query-digest /var/log/mysql/mysql-slow.log | head -n 40
    else
      echo "⚠️ No mysql slow log found in $TARGET_DIR/logs/mysql/mysql-slow.log"
    fi
    ;;

  k8s)
    NAMESPACE="${TARGET_DIR:-isucon}"
    echo "📊 Running Kubernetes cluster analysis (Namespace: $NAMESPACE)..."
    echo "=== Nginx Access Log (alp) ==="
    NGINX_POD=$(kubectl get pod -l app=isucon-nginx -n "$NAMESPACE" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
    if [[ -n "$NGINX_POD" ]]; then
      kubectl exec "$NGINX_POD" -n "$NAMESPACE" -c nginx -- cat /var/log/nginx/access.log | \
      docker run --rm -i tkuchiki/alp:latest ltsv --sort=sum -r -m "$ALP_MATCH"
    fi

    echo ""
    echo "=== MySQL Slow Query Log (pt-query-digest) ==="
    MYSQL_POD=$(kubectl get pod -l app=isucon-mysql -n "$NAMESPACE" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
    if [[ -n "$MYSQL_POD" ]]; then
      kubectl exec "$MYSQL_POD" -n "$NAMESPACE" -c mysql -- cat /var/log/mysql/mysql-slow.log | \
      docker run --rm -i percona/percona-toolkit:latest pt-query-digest | head -n 40
    fi
    ;;

  *)
    echo "Usage: $0 [local|k8s] [target-dir-or-namespace] [alp-match-pattern]"
    exit 1
    ;;
esac
