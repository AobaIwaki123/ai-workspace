# register-autostart-task.ps1
# Windows 起動時 / ログオン時に WSL をバックグラウンドで自動常駐させるタスクスケジューラ登録スクリプト

# 実行には管理者権限の PowerShell が必要です
param (
    [string]$DistroName = "Ubuntu"
)

Write-Host "Setting up background keep-alive task for WSL distro: $DistroName..." -ForegroundColor Cyan

# 1. 既存タスクの確認・削除（重複防止）
$TaskName = "WSL-AutoStart-Server"
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Write-Host "Updating existing task: $TaskName..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# 2. タスク定義の作成
# - 画面を出さずにバックグラウンドで sleep infinity を実行して WSL プロセスを維持
$Action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d $DistroName -u root --exec sleep infinity"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

# 3. タスクスケジューラへの登録
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings

# 4. タスクの即時開始
Write-Host "Starting task immediately..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName

Start-Sleep -Seconds 2
$WslStatus = wsl.exe -l -v
Write-Host "WSL Status:" -ForegroundColor Green
Write-Host $WslStatus

Write-Host "Completed! WSL will now stay running in background across restarts and terminal closures." -ForegroundColor Green
