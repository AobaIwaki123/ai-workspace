#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GPU Service Manager (llama-server with Storage Guard & Hot-Swap)
# ==============================================================================

WORKSPACE_DIR="/home/aoba/ai-workspace"
MODELS_DIR="$WORKSPACE_DIR/models"
SCRATCH_BIN="$WORKSPACE_DIR/scratch/llama-vulkan/llama-b10679"
SERVER_BIN="$SCRATCH_BIN/llama-server"
CONFIG_FILE="$WORKSPACE_DIR/wsl-server/gpu-service.env"
PID_FILE="$WORKSPACE_DIR/scratch/gpu-service.pid"
LOG_FILE="$WORKSPACE_DIR/scratch/gpu-service.log"

mkdir -p "$MODELS_DIR" "$WORKSPACE_DIR/scratch"

# Default configuration if not present
if [ ! -f "$CONFIG_FILE" ]; then
    cat << 'EOF' > "$CONFIG_FILE"
# GPU Service Environment Configuration
HOST="0.0.0.0"
PORT="8080"
MODEL_FILE="qwen2.5-1.5b-instruct-q4_k_m.gguf"
N_GPU_LAYERS="99"
CONTEXT_SIZE="2048"
THREADS="6"
EOF
fi

source "$CONFIG_FILE"

get_current_model_path() {
    echo "$MODELS_DIR/$MODEL_FILE"
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

start_service() {
    if is_running; then
        echo "[INFO] GPU Service is already running (PID: $(cat "$PID_FILE"))."
        return 0
    fi

    local model_path
    model_path=$(get_current_model_path)
    if [ ! -f "$model_path" ]; then
        echo "[ERROR] Model file not found: $model_path"
        echo "Please place a GGUF model in $MODELS_DIR or run '$0 switch <model-url>'."
        exit 1
    fi

    echo "[INFO] Starting llama-server on $HOST:$PORT with model $(basename "$model_path")..."
    export LD_LIBRARY_PATH="$SCRATCH_BIN:${LD_LIBRARY_PATH:-}"
    nohup "$SERVER_BIN" \
        -m "$model_path" \
        --host "$HOST" \
        --port "$PORT" \
        -ngl "$N_GPU_LAYERS" \
        -c "$CONTEXT_SIZE" \
        -t "$THREADS" \
        --alias "default-llm" \
        </dev/null > "$LOG_FILE" 2>&1 &

    local new_pid=$!
    disown "$new_pid" 2>/dev/null || true
    echo "$new_pid" > "$PID_FILE"
    
    echo -n "[INFO] Waiting for server to initialize model..."
    for i in {1..30}; do
        if grep -q "model loaded" "$LOG_FILE" 2>/dev/null; then
            echo " Ready!"
            echo "[SUCCESS] GPU Service started successfully (PID: $new_pid)."
            echo "  LAN Endpoint: http://192.168.11.15:$PORT"
            echo "  OpenAI Chat API: http://192.168.11.15:$PORT/v1/chat/completions"
            echo "  Web UI: http://192.168.11.15:$PORT/"
            return 0
        fi
        if ! kill -0 "$new_pid" 2>/dev/null; then
            echo " Failed!"
            echo "[ERROR] Process exited unexpectedly. Log output:"
            cat "$LOG_FILE" | tail -n 20
            exit 1
        fi
        sleep 0.5
        echo -n "."
    done

    echo " Timeout!"
    echo "[WARN] Server is starting but model initialization took longer than expected."
}

stop_service() {
    if ! is_running; then
        echo "[INFO] GPU Service is not running."
        rm -f "$PID_FILE"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    echo "[INFO] Stopping GPU Service (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    echo "[SUCCESS] GPU Service stopped."
}

show_status() {
    echo "============================================================"
    echo "  GPU Service Status & Storage Overview"
    echo "============================================================"
    if is_running; then
        echo "  Service: RUNNING (PID: $(cat "$PID_FILE"))"
        echo "  Endpoint: http://192.168.11.15:$PORT (OpenAI API / Web UI)"
    else
        echo "  Service: STOPPED"
    fi
    echo ""
    echo "  [Configuration]"
    echo "  Active Model: $MODEL_FILE"
    echo "  GPU Offload Layers: $N_GPU_LAYERS"
    echo "  Context Size: $CONTEXT_SIZE"
    echo ""
    echo "  [Models Storage (${MODELS_DIR})]"
    ls -lh "$MODELS_DIR" | grep ".gguf" || echo "  No GGUF models stored."
    echo ""
    echo "  [Disk Space Overview]"
    df -h / | awk 'NR==1 || NR==2 {print "  " $0}'
    echo "============================================================"
}

switch_model() {
    local target_url="$1"
    local filename
    filename=$(basename "$target_url" | cut -d'?' -f1)

    echo "[INFO] Switching model to: $filename"
    echo "[1/4] Stopping current service..."
    stop_service

    echo "[2/4] Cleaning old models to save disk storage..."
    for f in "$MODELS_DIR"/*.gguf; do
        if [ -f "$f" ] && [ "$(basename "$f")" != "$filename" ]; then
            echo "  Removing old model: $(basename "$f")"
            rm -f "$f"
        fi
    done

    echo "[3/4] Downloading new model if needed..."
    if [ ! -f "$MODELS_DIR/$filename" ]; then
        curl -L -o "$MODELS_DIR/$filename" "$target_url"
    else
        echo "  Model already exists locally."
    fi

    # Update env config
    sed -i "s/^MODEL_FILE=.*/MODEL_FILE=\"$filename\"/" "$CONFIG_FILE"

    echo "[4/4] Freeing trimmed SSD blocks back to Windows host (fstrim)..."
    sudo fstrim -v / 2>/dev/null || true

    echo "[INFO] Starting service with new model..."
    start_service
}

test_kana_conversion() {
    local endpoint="http://127.0.0.1:$PORT/v1/chat/completions"
    local sample_input="${1:-AKB, AWS, USB, CI/CD, iPhone, Kubernetes}"

    if ! is_running; then
        echo "[INFO] Starting service first..."
        start_service
    fi

    echo "[TEST] Testing English -> Japanese Katakana Reading Conversion..."
    echo "  Input: $sample_input"
    echo "------------------------------------------------------------"

    local payload
    payload=$(jq -n \
        --arg input "$sample_input" \
        '{
            model: "default-llm",
            messages: [
                {
                    role: "system",
                    content: "あなたは英単語やアルファベット略語を正確な日本語カタカナ読みに変換するAIです。\n\n【ルール】\n1. アルファベットの略語（頭字語）は、1文字ずつアルファベット読みをつなげます。\n   - A=エー, B=ビー, C=シー, D=ディー, E=イー, G=ジー, H=エイチ, I=アイ, K=ケー, M=エム, N=エヌ, P=ピー, R=アール, S=エス, T=ティー, U=ユー, V=ブイ, W=ダブリュー, X=エックス, Y=ワイ, Z=ゼット\n   - 例: AKB -> エーケービー, AWS -> エーダブリューエス, USB -> ユーエスビー, CI/CD -> シーアイシーディー\n2. 一般的な英単語・製品名は、標準的な日本語カタカナ表記にします。\n   - 例: Apple -> アップル, iPhone -> アイフォーン, Google -> グーグル, Kubernetes -> クバネティス\n\n出力は カタカナ読みのみ を箇条書きで答えてください。"
                },
                {
                    role: "user",
                    content: ("次の英語をカタカナ読みに変換してください:\n" + $input)
                }
            ],
            temperature: 0.0,
            max_tokens: 128
        }')

    local response
    response=$(curl -s -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "$payload")

    echo "  Response Output:"
    echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null || echo "$response"
    echo "------------------------------------------------------------"
}

case "${1:-status}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        start_service
        ;;
    status)
        show_status
        ;;
    switch)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 switch <model-download-url>"
            exit 1
        fi
        switch_model "$2"
        ;;
    test)
        test_kana_conversion "${2:-}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|switch <url>|test [text]}"
        exit 1
        ;;
esac
