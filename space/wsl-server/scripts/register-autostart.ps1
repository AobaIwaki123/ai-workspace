# ==============================================================================
# register-autostart.ps1
# WSL Server Keep-Alive & Auto-Recovery Task Registration
# ==============================================================================

# 1. Action: Loop watcher that keeps WSL running and restarts it on failure
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command while(`$true){wsl.exe -d Ubuntu -u root --exec sleep infinity; Start-Sleep 2}"

# 2. Trigger & Settings
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# 3. Register & Start Task
Register-ScheduledTask -TaskName "WSL-AutoStart-Server" -Action $Action -Trigger $Trigger -Settings $Settings -RunLevel Highest -Force
Start-ScheduledTask -TaskName "WSL-AutoStart-Server"

# 4. Status Output
Write-Host "Task Status:" -ForegroundColor Cyan
Get-ScheduledTask -TaskName "WSL-AutoStart-Server" | Select-Object TaskName, State
Write-Host ""
Write-Host "WSL Status:" -ForegroundColor Cyan
wsl.exe -l -v
