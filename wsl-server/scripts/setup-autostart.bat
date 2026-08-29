@echo off
chcp 65001 >nul
setlocal

:: ==============================================================================
:: WSL Server Auto-Start Setup (完全自己完結型 1ファイル版)
:: ==============================================================================

echo [1/3] Checking Administrator privileges...
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating to Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [2/3] Registering WSL Keep-Alive Scheduled Task...
set "TEMP_PS1=%TEMP%\wsl_autostart_setup_%RANDOM%.ps1"

(
echo $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command while($true){wsl.exe -d Ubuntu -u root --exec sleep infinity; Start-Sleep 2}"
echo $Trigger = New-ScheduledTaskTrigger -AtLogOn
echo $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
echo Register-ScheduledTask -TaskName "WSL-AutoStart-Server" -Action $Action -Trigger $Trigger -Settings $Settings -RunLevel Highest -Force
echo Start-ScheduledTask -TaskName "WSL-AutoStart-Server"
echo Write-Host ""
echo Write-Host "Task Status:" -ForegroundColor Cyan
echo Get-ScheduledTask -TaskName "WSL-AutoStart-Server" ^| Select-Object TaskName, State
echo Write-Host ""
echo Write-Host "WSL Status:" -ForegroundColor Cyan
echo wsl.exe -l -v
) > "%TEMP_PS1%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS1%"
del "%TEMP_PS1%" >nul 2>&1

echo.
echo [3/3] ============================================
echo Setup completed successfully!
echo WSL will now stay running in background across restarts.
echo ==================================================
pause
