@echo off
:: ==============================================================================
:: WSL サーバー自動常駐・自動復旧タスク 一括セットアップスクリプト
:: 使い方: 本ファイルを右クリックして「管理者として実行」してください。
:: ==============================================================================

echo [1/3] 管理者権限の確認中...
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo 管理者権限で再実行しています...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [2/3] WSL 自動常駐・自動復旧タスク (Keep-Alive Loop) を登録中...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$DistroName = 'Ubuntu';" ^
    "$TaskName = 'WSL-AutoStart-Server';" ^
    "$LoopCommand = 'while ($true) { wsl.exe -d ' + $DistroName + ' -u root --exec sleep infinity; Start-Sleep -Seconds 2 }';" ^
    "$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-WindowStyle Hidden -NoProfile -NonInteractive -Command \"' + $LoopCommand + '\"');" ^
    "$Trigger = New-ScheduledTaskTrigger -AtLogOn;" ^
    "$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest;" ^
    "$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1);" ^
    "Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings;" ^
    "Start-ScheduledTask -TaskName $TaskName;"

echo [3/3] 状態確認中...
powershell -NoProfile -Command "wsl.exe -l -v"

echo.
echo ==============================================================================
echo 完了しました！
echo ターミナルを閉じても、Ubuntu 内部で再起動しても自動で常駐・復旧します。
echo ==============================================================================
pause
