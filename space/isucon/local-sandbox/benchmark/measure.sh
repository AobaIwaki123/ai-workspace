#!/usr/bin/env bash
# ==========================================
# 計測結果の収集・保存・比較スクリプト
# make measure で呼び出す
# ==========================================
set -euo pipefail

SANDBOX_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="${SANDBOX_DIR}/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="${RESULTS_DIR}/${TIMESTAMP}"
LATEST_LINK="${RESULTS_DIR}/latest"
PREVIOUS_LINK="${RESULTS_DIR}/previous"

TARGET_URL="${1:-http://localhost:8080}"
DURATION="${2:-10}"
ALP_MATCH='"/api/posts/[0-9]+"'

mkdir -p "${RUN_DIR}"

# ==========================================
# 1. ベンチマーク実行
# ==========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📏 計測開始: ${TIMESTAMP}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ログクリア
make -C "${SANDBOX_DIR}" clean-logs 2>/dev/null || true

# ベンチ実行 & 結果キャプチャ
BENCH_OUTPUT=$("${SANDBOX_DIR}/benchmark/bench.sh" "${TARGET_URL}" "${DURATION}" 2>&1)
echo "${BENCH_OUTPUT}" > "${RUN_DIR}/bench.txt"

# スコア等をJSONで保存
TOTAL=$(echo "${BENCH_OUTPUT}" | grep '総リクエスト数' | grep -o '[0-9]*')
SUCCESS=$(echo "${BENCH_OUTPUT}" | grep '成功:' | sed 's/.*成功: \([0-9]*\).*/\1/')
FAIL=$(echo "${BENCH_OUTPUT}" | grep '失敗:' | sed 's/.*失敗: \([0-9]*\).*/\1/')
QPS=$(echo "${BENCH_OUTPUT}" | grep 'QPS:' | grep -o '[0-9]*' | head -1)
SCORE=$(echo "${BENCH_OUTPUT}" | grep 'スコア:' | grep -o '[0-9-]*')

cat > "${RUN_DIR}/summary.json" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "total_requests": ${TOTAL:-0},
  "success": ${SUCCESS:-0},
  "fail": ${FAIL:-0},
  "qps": ${QPS:-0},
  "score": ${SCORE:-0},
  "duration_sec": ${DURATION}
}
EOF

# ==========================================
# 2. alp 結果取得
# ==========================================
ALP_OUTPUT=$(alp ltsv --file="${SANDBOX_DIR}/logs/nginx/access.log" --sort=sum -r -m "/api/posts/[0-9]+" 2>&1 || echo "alp failed")
echo "${ALP_OUTPUT}" > "${RUN_DIR}/alp.txt"

# alpのCSV版も保存（比較用）
alp ltsv --file="${SANDBOX_DIR}/logs/nginx/access.log" --sort=sum -r -m "/api/posts/[0-9]+" --format=tsv 2>/dev/null > "${RUN_DIR}/alp.tsv" || true

# ==========================================
# 3. pt-query-digest 結果取得
# ==========================================
SLOW_OUTPUT=$(docker run --rm -v "${SANDBOX_DIR}/logs/mysql:/var/log/mysql" percona/percona-toolkit:latest pt-query-digest /var/log/mysql/mysql-slow.log 2>&1 | head -n 50)
echo "${SLOW_OUTPUT}" > "${RUN_DIR}/slow.txt"

# ==========================================
# 4. リンク更新
# ==========================================
if [ -L "${LATEST_LINK}" ]; then
    PREV_TARGET=$(readlink "${LATEST_LINK}")
    rm -f "${PREVIOUS_LINK}"
    ln -s "${PREV_TARGET}" "${PREVIOUS_LINK}"
fi
rm -f "${LATEST_LINK}"
ln -s "${RUN_DIR}" "${LATEST_LINK}"

# ==========================================
# 5. 結果表示
# ==========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 計測結果: ${TIMESTAMP}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🏆 スコア: ${SCORE}   (QPS: ${QPS} req/sec, 成功: ${SUCCESS}, 失敗: ${FAIL})"
echo ""
echo "── alp (エンドポイント別 SUM 降順) ──"
echo "${ALP_OUTPUT}"
echo ""
echo "── pt-query-digest (上位クエリ) ──"
echo "${SLOW_OUTPUT}" | grep -A 20 "^# Profile" || echo "${SLOW_OUTPUT}" | tail -20
echo ""

# ==========================================
# 6. 前回比較
# ==========================================
if [ -L "${PREVIOUS_LINK}" ] && [ -f "${PREVIOUS_LINK}/summary.json" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📈 前回との比較"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    PREV_SCORE=$(cat "${PREVIOUS_LINK}/summary.json" | grep '"score"' | grep -o '[0-9-]*')
    PREV_QPS=$(cat "${PREVIOUS_LINK}/summary.json" | grep '"qps"' | grep -o '[0-9]*')
    PREV_FAIL=$(cat "${PREVIOUS_LINK}/summary.json" | grep '"fail"' | grep -o '[0-9]*')
    PREV_TS=$(cat "${PREVIOUS_LINK}/summary.json" | grep '"timestamp"' | sed 's/.*: *"\(.*\)".*/\1/')

    SCORE_DIFF=$((SCORE - PREV_SCORE))
    QPS_DIFF=$((QPS - PREV_QPS))

    if [ ${SCORE_DIFF} -gt 0 ]; then
        SCORE_ICON="🟢 ↑"
    elif [ ${SCORE_DIFF} -lt 0 ]; then
        SCORE_ICON="🔴 ↓"
    else
        SCORE_ICON="⚪ →"
    fi

    echo ""
    printf "%-20s  %-15s  %-15s  %-10s\n" "" "前回(${PREV_TS})" "今回(${TIMESTAMP})" "差分"
    printf "%-20s  %-15s  %-15s  %-10s\n" "────────────────" "──────────────" "──────────────" "────────"
    printf "%-20s  %-15s  %-15s  %s %+d\n" "🏆 スコア" "${PREV_SCORE}" "${SCORE}" "${SCORE_ICON}" "${SCORE_DIFF}"
    printf "%-20s  %-15s  %-15s  %+d\n" "⚡ QPS" "${PREV_QPS} req/sec" "${QPS} req/sec" "${QPS_DIFF}"
    printf "%-20s  %-15s  %-15s\n" "❌ 失敗" "${PREV_FAIL}" "${FAIL}"
    echo ""
else
    echo "ℹ️  初回計測のため比較データなし。次回以降は前回との差分が表示されます。"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 結果保存先: ${RUN_DIR}/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
