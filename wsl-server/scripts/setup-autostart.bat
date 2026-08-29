@echo off
chcp 65001 >nul
setlocal

:: ==============================================================================
:: WSL Server Auto-Start Setup (タスクスケジューラ完全動作版)
:: ==============================================================================

echo [1/3] Checking Administrator privileges...
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating to Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [2/3] Installing Keep-Alive script to %USERPROFILE%\.wsl_keepalive.ps1 ...
set "TARGET_PS1=%USERPROFILE%\.wsl_keepalive.ps1"

(
echo # WSL Server Keep-Alive Watcher
echo while ($true) {
echo     wsl.exe -u root --exec /bin/sleep infinity
echo     Start-Sleep -Seconds 2
echo }
) > "%TARGET_PS1%"

echo [3/3] Registering Scheduled Task to run %TARGET_PS1% ...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File \"'%USERPROFILE%\.wsl_keepalive.ps1'\"';" ^
    "$Trigger = New-ScheduledTaskTrigger -AtLogOn;" ^
    "$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries;" ^
    "Register-ScheduledTask -TaskName 'WSL-AutoStart-Server' -Action $Action -Trigger $Trigger -Settings $Settings -RunLevel Highest -Force;" ^
    "Start-ScheduledTask -TaskName 'WSL-AutoStart-Server';"

echo.
echo Waiting for task to launch WSL...
timeout /t 3 >nul

echo --------------------------------------------------
echo Task Status:
powershell -NoProfile -Command "Get-ScheduledTask -TaskName 'WSL-AutoStart-Server' | Select-Object TaskName, State"
echo.
echo WSL Status:
wsl.exe -l -v
echo --------------------------------------------------
echo.
echo Setup completed!
pause
