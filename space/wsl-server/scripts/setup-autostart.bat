@echo off
chcp 65001 >nul
setlocal

:: ==============================================================================
:: WSL Server Auto-Start Setup (完全自己完結型 1ファイル版)
:: ==============================================================================

echo [1/2] Checking Administrator privileges...
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating to Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [2/2] Creating Keep-Alive script and registering Scheduled Task...
:: バッチ自身が直接スクリプトファイルを配置（PowerShellのEncoding非互換を完全排除）
(
echo while ($true^) {
echo     wsl.exe -u root --exec /bin/sleep infinity
echo     Start-Sleep -Seconds 2
echo }
) > "%USERPROFILE%\.wsl_keepalive.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File \"%USERPROFILE%\.wsl_keepalive.ps1\"';" ^
    "$trigger = New-ScheduledTaskTrigger -AtLogOn;" ^
    "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries;" ^
    "Register-ScheduledTask -TaskName 'WSL-AutoStart-Server' -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force;" ^
    "Start-ScheduledTask -TaskName 'WSL-AutoStart-Server';"

echo.
echo ==================================================
echo Task Status:
powershell -NoProfile -Command "Get-ScheduledTask -TaskName 'WSL-AutoStart-Server' | Select-Object TaskName, State"
echo.
echo WSL Status:
wsl.exe -l -v
echo ==================================================
echo.
echo Setup completed successfully!
pause
