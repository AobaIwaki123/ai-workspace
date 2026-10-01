#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  WSL2 Storage I/O Benchmark (ext4 vs 9p /mnt/c)"
echo "============================================================"

TEST_SIZE="256M"

# 1. ext4 Native Linux Storage (~/ai-workspace/scratch)
EXT4_DIR="/home/aoba/ai-workspace/scratch/io_test"
mkdir -p "$EXT4_DIR"
echo "[1/2] Benchmarking ext4 Native Storage ($EXT4_DIR)..."

# Write test
echo -n "  Sequential Write (256MB): "
dd if=/dev/zero of="$EXT4_DIR/test.tmp" bs=1M count=256 conv=fdatasync 2>&1 | awk '/copied/ {print $(NF-1), $NF}'

# Read test (drop cache effect using sync)
echo -n "  Sequential Read (256MB):  "
dd if="$EXT4_DIR/test.tmp" of=/dev/null bs=1M count=256 2>&1 | awk '/copied/ {print $(NF-1), $NF}'
rm -f "$EXT4_DIR/test.tmp"

echo "------------------------------------------------------------"

# 2. Windows 9p Mount (/mnt/c/Users)
WIN_DIR="/mnt/c/Users/Public"
if [ -d "$WIN_DIR" ]; then
    echo "[2/2] Benchmarking Windows 9p Mount ($WIN_DIR)..."
    echo -n "  Sequential Write (256MB): "
    dd if=/dev/zero of="$WIN_DIR/test_wsl_io.tmp" bs=1M count=256 conv=fdatasync 2>&1 | awk '/copied/ {print $(NF-1), $NF}' || echo "Write failed"
    
    echo -n "  Sequential Read (256MB):  "
    dd if="$WIN_DIR/test_wsl_io.tmp" of=/dev/null bs=1M count=256 2>&1 | awk '/copied/ {print $(NF-1), $NF}' || echo "Read failed"
    rm -f "$WIN_DIR/test_wsl_io.tmp"
else
    echo "[2/2] Windows Public dir not accessible, skipping."
fi

echo "============================================================"
