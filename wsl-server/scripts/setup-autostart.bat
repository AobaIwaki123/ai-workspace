@echo off
chcp 65001 >nul
:: ==============================================================================
:: WSL Server Auto-Recovery & Keep-Alive Task Setup
:: ==============================================================================

echo [1/3] Checking Administrator privileges...
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating to Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [2/3] Registering WSL Keep-Alive Scheduled Task...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-WindowStyle Hidden -Command while($true){wsl.exe -d Ubuntu -u root --exec sleep infinity; Start-Sleep 2}';" ^
    "$Trigger = New-ScheduledTaskTrigger -AtLogOn;" ^
    "$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries;" ^
    "Register-ScheduledTask -TaskName 'WSL-AutoStart-Server' -Action $Action -Trigger $Trigger -Settings $Settings -RunLevel Highest -Force;" ^
    "Start-ScheduledTask -TaskName 'WSL-AutoStart-Server';"

echo.
echo [3/3] Checking Task & WSL Status:
echo --------------------------------------------------
powershell -NoProfile -Command "Get-ScheduledTask -TaskName 'WSL-AutoStart-Server' | Select-Object TaskName, State"
echo.
powershell -NoProfile -Command "wsl.exe -l -v"
echo --------------------------------------------------
echo.
echo Setup completed successfully!
echo WSL is now running in background and will auto-restart on internal reboot.
pause
