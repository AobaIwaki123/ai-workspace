@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo [1/2] Checking Administrator privileges...
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating to Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [2/2] Running register-autostart.ps1...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0register-autostart.ps1"

echo.
echo ==================================================
echo Setup completed!
echo ==================================================
pause
