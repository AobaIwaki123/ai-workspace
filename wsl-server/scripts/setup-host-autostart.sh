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
    \$DistroName = '$DISTRO_NAME'
    \$TaskName = '$TASK_NAME'
    Stop-ScheduledTask -TaskName \$TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName \$TaskName -Confirm:\$false -ErrorAction SilentlyContinue
    \$LoopCommand = 'while (\$true) { wsl.exe -d ' + \$DistroName + ' -u root --exec sleep infinity; Start-Sleep -Seconds 2 }'
    \$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-WindowStyle Hidden -NoProfile -NonInteractive -Command \"' + \$LoopCommand + '\"')
    \$Trigger = New-ScheduledTaskTrigger -AtLogOn
    \$Principal = New-ScheduledTaskPrincipal -UserId \$env:USERNAME -LogonType Interactive -RunLevel Highest
    \$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName \$TaskName -Action \$Action -Trigger \$Trigger -Principal \$Principal -Settings \$Settings -Force
    Start-ScheduledTask -TaskName \$TaskName
"

echo "WSL Keep-Alive Task has been registered in Windows Task Scheduler."
