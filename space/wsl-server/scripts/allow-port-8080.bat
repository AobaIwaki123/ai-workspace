@echo off
chcp 65001 >nul
setlocal

:: ==============================================================================
:: Windows Firewall Port 8080 Opener for WSL2 AI Gateway (Auto-Elevating)
:: ==============================================================================

echo [1/2] Checking Administrator privileges...
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating to Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [2/2] Adding Firewall Inbound Rule for Port 8080...
netsh advfirewall firewall delete rule name="WSL2 AI Gateway (Port 8080)" >nul 2>&1
netsh advfirewall firewall add rule name="WSL2 AI Gateway (Port 8080)" dir=in action=allow protocol=TCP localport=8080 profile=any >nul

if %errorlevel% equ 0 (
    echo.
    echo =======================================================
    echo   SUCCESS: Port 8080 is now OPEN in Windows Firewall!
    echo =======================================================
    echo.
    echo Rule verification:
    netsh advfirewall firewall show rule name="WSL2 AI Gateway (Port 8080)" | findstr /i "Rule Name Enabled Protocol LocalPort Action"
    echo.
    echo External endpoints are now accessible:
    echo   - OpenAI Chat API:         http://192.168.11.15:8080/v1/chat/completions
    echo   - Benchmark JSON Metadata: http://192.168.11.15:8080/api/benchmarks
    echo   - Health Check:            http://192.168.11.15:8080/health
) else (
    echo.
    echo [ERROR] Failed to add firewall rule. Error code: %errorlevel%
)

echo.
pause
