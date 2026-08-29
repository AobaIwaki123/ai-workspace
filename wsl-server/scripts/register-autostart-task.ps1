# register-autostart-task.ps1
# Windows 起動時 / ログオン時に WSL をバックグラウンドで自動常駐・自動復旧させるタスクスケジューラ登録スクリプト
# (Ubuntu 側で再起動や停止が発生しても即座に自動再起動して常駐を維持します)

param (
    [string]$DistroName = "Ubuntu"
)

Write-Host "Setting up resilient background keep-alive task for WSL distro: $DistroName..." -ForegroundColor Cyan

# 1. タスク定義の作成
# - PowerShell ループにより、WSL 内部で reboot や crash が発生しても 2秒後に自動再起動する
$TaskName = "WSL-AutoStart-Server"
$LoopCommand = "while (`$true) { wsl.exe -d $DistroName -u root --exec sleep infinity; Start-Sleep -Seconds 2 }"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -NonInteractive -Command `"$LoopCommand`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)

# 2. タスクスケジューラへの登録（-Force で既存タスクを自動上書き）
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force

# 4. タスクの即時開始
Write-Host "Starting task immediately..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName

Start-Sleep -Seconds 3
$WslStatus = wsl.exe -l -v
Write-Host "WSL Status:" -ForegroundColor Green
Write-Host $WslStatus

Write-Host "Completed! WSL will now automatically recover even if Ubuntu is rebooted or stopped internally." -ForegroundColor Green

