#!/usr/bin/env bash
# ==============================================================================
# setup-host-autostart.sh
# WSL (Linux) 内部から Windows 側のタスクスケジューラ常駐タスクを自動登録するスクリプト
# ==============================================================================

set -euo pipefail

DISTRO_NAME="${1:-Ubuntu}"
TASK_NAME="WSL-AutoStart-Server"

echo "Registering Windows Scheduled Task for WSL auto-recovery from inside Linux..."

# powershell.exe の存在確認
PS_EXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
if [[ ! -f "$PS_EXE" ]]; then
    PS_EXE="powershell.exe"
fi

# PowerShell コマンドを実行してタスクスケジューラに登録
"$PS_EXE" -NoProfile -ExecutionPolicy Bypass -Command "
    \$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-WindowStyle Hidden -Command while(\$true){wsl.exe -d $DISTRO_NAME -u root --exec sleep infinity; Start-Sleep 2}'
    \$Trigger = New-ScheduledTaskTrigger -AtLogOn
    \$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName '$TASK_NAME' -Action \$Action -Trigger \$Trigger -Settings \$Settings -RunLevel Highest -Force
    Start-ScheduledTask -TaskName '$TASK_NAME'
"

echo "WSL Keep-Alive Task has been registered in Windows Task Scheduler."
