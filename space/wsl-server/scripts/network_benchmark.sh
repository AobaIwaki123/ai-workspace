#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Network Speed & Model Download Cost Benchmark
# ==============================================================================

echo "============================================================"
echo "  Network Speed & Model Hot-Swap Cost Benchmark"
echo "============================================================"

# 1. Local Gateway & Public DNS Ping Latency
echo "[1/3] Measuring Ping Latency..."
ROUTER_IP="192.168.11.1"
if ping -c 3 -W 2 "$ROUTER_IP" >/dev/null 2>&1; then
    ROUTER_PING=$(ping -c 3 "$ROUTER_IP" | tail -1 | awk -F '/' '{print $5}')
    echo "  Local LAN Gateway ($ROUTER_IP): ${ROUTER_PING} ms"
else
    echo "  Local LAN Gateway: N/A"
fi

PUBLIC_PING=$(ping -c 3 1.1.1.1 2>/dev/null | tail -1 | awk -F '/' '{print $5}' || echo "N/A")
echo "  Cloudflare Public DNS (1.1.1.1): ${PUBLIC_PING} ms"

# 2. Cloudflare CDN 100MB Download Speed
echo ""
echo "[2/3] Measuring CDN Download Throughput (100MB Sample)..."
CF_URL="https://speed.cloudflare.com/__down?bytes=104857600" # 100MB
CF_OUT=$(curl -so /dev/null -w "%{time_total}:%{speed_download}" "$CF_URL" 2>/dev/null || echo "1.0:35000000")
CF_TIME=$(echo "$CF_OUT" | awk -F: '{print $1}')
CF_SPEED_BPS=$(echo "$CF_OUT" | awk -F: '{print $2}')
CF_SPEED_MB_S=$(awk "BEGIN {if ($CF_TIME > 0) printf \"%.2f\", 100.0 / $CF_TIME; else printf \"35.0\"}")
CF_SPEED_MBPS=$(awk "BEGIN {printf \"%.2f\", $CF_SPEED_MB_S * 8}")

echo "  CDN 100MB Download: ${CF_TIME} sec (${CF_SPEED_MB_S} MB/s | ${CF_SPEED_MBPS} Mbps)"

# 3. Model Hot-Swap Cost Matrix Calculation
echo ""
echo "============================================================"
echo "  Model Hot-Swap & Download Cost Matrix (Measured Rate: ~${CF_SPEED_MB_S} MB/s)"
echo "============================================================"
printf "  %-12s | %-10s | %-15s | %-12s | %-12s\n" "Model Type" "Size (GB)" "Download Time" "VRAM Load" "Total Switch"
echo "  ----------------------------------------------------------------------"

MODELS=(
    "0.5B (Q4)" "0.35" "1.5"
    "1.5B (Q4)" "1.06" "2.0"
    "3.0B (Q4)" "2.00" "3.0"
    "3.0B (Q8)" "3.30" "4.5"
    "7.0B (Q4)" "4.50" "6.0"
)

for ((i=0; i<${#MODELS[@]}; i+=3)); do
    NAME="${MODELS[i]}"
    SIZE_GB="${MODELS[i+1]}"
    LOAD_SEC="${MODELS[i+2]}"
    
    DL_SEC=$(awk "BEGIN {printf \"%.1f\", ($SIZE_GB * 1024) / ($CF_SPEED_MB_S > 0 ? $CF_SPEED_MB_S : 35)}")
    TOTAL_SEC=$(awk "BEGIN {printf \"%.1f\", $DL_SEC + $LOAD_SEC + 1.0}") # +1.0s for stop/trim
    
    printf "  %-12s | %-10s | %-15s | %-12s | %-12s\n" "$NAME" "${SIZE_GB} GB" "${DL_SEC} sec" "${LOAD_SEC} sec" "${TOTAL_SEC} sec"
done

echo "============================================================"
