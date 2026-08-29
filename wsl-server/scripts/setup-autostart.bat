@echo off
chcp 65001 >nul
:: ==============================================================================
:: WSL Server Auto-Start Setup (完全自己完結型 1ファイル版)
:: 使い方: このファイル単体を右クリックして「管理者として実行」するだけでOKです。
:: 他のファイルやフォルダは一切不要です。
:: ==============================================================================

echo [1/3] 管理者権限の確認中...
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo 管理者権限に昇格して再起動しています...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [2/3] WSL 自動常駐・自動復旧タスクを登録中...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-WindowStyle Hidden -Command while($true){wsl.exe -d Ubuntu -u root --exec sleep infinity; Start-Sleep 2}'; $Trigger = New-ScheduledTaskTrigger -AtLogOn; $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries; Register-ScheduledTask -TaskName 'WSL-AutoStart-Server' -Action $Action -Trigger $Trigger -Settings $Settings -RunLevel Highest -Force; Start-ScheduledTask -TaskName 'WSL-AutoStart-Server';"

echo.
echo [3/3] 状態確認:
echo --------------------------------------------------
powershell -NoProfile -Command "Get-ScheduledTask -TaskName 'WSL-AutoStart-Server' | Select-Object TaskName, State"
echo.
powershell -NoProfile -Command "wsl.exe -l -v"
echo --------------------------------------------------
echo.
echo セットアップが完了しました！
echo ターミナルを閉じても、Ubuntu内部で再起動しても自動常駐します。
pause
