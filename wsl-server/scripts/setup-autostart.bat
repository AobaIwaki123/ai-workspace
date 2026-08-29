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
    "$DistroName = 'Ubuntu';" ^
    "$TaskName = 'WSL-AutoStart-Server';" ^
    "$LoopCommand = 'while ($true) { wsl.exe -d ' + $DistroName + ' -u root --exec sleep infinity; Start-Sleep -Seconds 2 }';" ^
    "$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-WindowStyle Hidden -NoProfile -NonInteractive -Command \"' + $LoopCommand + '\"');" ^
    "$Trigger = New-ScheduledTaskTrigger -AtLogOn;" ^
    "$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest;" ^
    "$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1);" ^
    "Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force;" ^
    "Start-ScheduledTask -TaskName $TaskName;"

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
