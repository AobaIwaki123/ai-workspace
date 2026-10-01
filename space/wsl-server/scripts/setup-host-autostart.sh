#!/usr/bin/env bash
# ==============================================================================
# setup-host-autostart.sh
# WSL (Linux) 内部から Windows 側の register-autostart.ps1 を呼び出すスクリプト
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1_FILE="$SCRIPT_DIR/register-autostart.ps1"

# Windows パスに変換
if command -v wslpath >/dev/null 2>&1; then
    WIN_PS1_PATH="$(wslpath -w "$PS1_FILE")"
else
    WIN_PS1_PATH="$PS1_FILE"
fi

PS_EXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
if [[ ! -f "$PS_EXE" ]]; then
    PS_EXE="powershell.exe"
fi

echo "Running register-autostart.ps1 on Windows host..."
"$PS_EXE" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS1_PATH"
