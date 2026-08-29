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

echo [2/3] Installing Keep-Alive script and registering Scheduled Task...
set "SETUP_SCRIPT=%TEMP%\wsl_setup_runner_%RANDOM%.ps1"

(
echo $ps1Content = @"
echo while ($true^) {
echo     wsl.exe -u root --exec /bin/sleep infinity
echo     Start-Sleep -Seconds 2
echo }
echo "@
echo $ps1Path = "`$env:USERPROFILE\.wsl_keepalive.ps1"
echo Set-Content -Path $ps1Path -Value $ps1Content -Encoding UTF8 -Force
echo $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"`$ps1Path`""
echo $trigger = New-ScheduledTaskTrigger -AtLogOn
echo $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
echo Register-ScheduledTask -TaskName "WSL-AutoStart-Server" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force
echo Start-ScheduledTask -TaskName "WSL-AutoStart-Server"
echo Start-Sleep -Seconds 2
echo Write-Host ""
echo Write-Host "=== TASK STATUS ===" -ForegroundColor Cyan
echo Get-ScheduledTask -TaskName "WSL-AutoStart-Server" ^| Select-Object TaskName, State
echo Write-Host ""
echo Write-Host "=== WSL STATUS ===" -ForegroundColor Cyan
echo wsl.exe -l -v
) > "%SETUP_SCRIPT%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SETUP_SCRIPT%"
del "%SETUP_SCRIPT%" >nul 2>&1

echo.
echo ==================================================
echo Setup completed successfully!
echo WSL will now stay running in background across restarts.
echo ==================================================
pause
