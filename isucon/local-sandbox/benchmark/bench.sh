#!/usr/bin/env bash
# ==========================================
# ローカル模擬ベンチマーカースクリプト
# ==========================================
set -euo pipefail

TARGET_URL="${1:-http://localhost:80}"
DURATION_SEC="${2:-10}"
CONCURRENCY=5

echo "=========================================="
echo "🚀 模擬ベンチマークを開始します..."
echo "ターゲット: ${TARGET_URL}"
echo "実行時間: ${DURATION_SEC} 秒 (並行数: ${CONCURRENCY})"
echo "=========================================="

END_TIME=$(( $(date +%s) + DURATION_SEC ))
TOTAL_REQUESTS=0
SUCCESS_COUNT=0
FAIL_COUNT=0

run_worker() {
    local worker_id=$1
    local req_count=0
    local ok_count=0
    local ng_count=0

    while [ $(date +%s) -lt $END_TIME ]; do
        # 1. 投稿一覧取得 (N+1ボトルネック)
        if curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/posts" > /dev/null; then
            ok_count=$((ok_count + 1))
        else
            ng_count=$((ng_count + 1))
        fi

        # 2. 投稿詳細取得 (スロークエリボトルネック)
        post_id=$(( (RANDOM % 20) + 1 ))
        if curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/posts/${post_id}" > /dev/null; then
            ok_count=$((ok_count + 1))
        else
            ng_count=$((ng_count + 1))
        fi

        # 3. CPU負荷エンドポイント
        if curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/heavy-calc" > /dev/null; then
            ok_count=$((ok_count + 1))
        else
            ng_count=$((ng_count + 1))
        fi

        req_count=$((req_count + 3))
    done

    echo "${ok_count},${ng_count},${req_count}" > "/tmp/bench_res_${worker_id}.txt"
}

# 並行ワーカー起動
for i in $(seq 1 $CONCURRENCY); do
    run_worker $i &
done

wait

# 結果集計
for i in $(seq 1 $CONCURRENCY); do
    if [ -f "/tmp/bench_res_${i}.txt" ]; then
        IFS=',' read -r ok ng tot < "/tmp/bench_res_${i}.txt"
        SUCCESS_COUNT=$((SUCCESS_COUNT + ok))
        FAIL_COUNT=$((FAIL_COUNT + ng))
        TOTAL_REQUESTS=$((TOTAL_REQUESTS + tot))
        rm -f "/tmp/bench_res_${i}.txt"
    fi
done

QPS=$(( TOTAL_REQUESTS / DURATION_SEC ))
SCORE=$(( SUCCESS_COUNT * 10 - FAIL_COUNT * 50 ))

echo "=========================================="
echo "🏁 ベンチマーク終了"
echo "総リクエスト数: ${TOTAL_REQUESTS}"
echo "成功: ${SUCCESS_COUNT}, 失敗: ${FAIL_COUNT}"
echo "QPS: ${QPS} req/sec"
echo "🏆 スコア: ${SCORE}"
echo "=========================================="
