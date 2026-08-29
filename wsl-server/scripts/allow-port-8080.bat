@echo off
echo =======================================================
echo   Opening Port 8080 for WSL2 AI Gateway in Windows Firewall
echo =======================================================

netsh advfirewall firewall add rule name="WSL2 AI Gateway (Port 8080)" dir=in action=allow protocol=TCP localport=8080

if %ERRORLEVEL% equ 0 (
    echo.
    echo [SUCCESS] Port 8080 is now OPEN for LAN incoming traffic!
    echo External devices (k8s cluster, phone, browser) can now access:
    echo   - http://192.168.11.15:8080/v1/chat/completions
    echo   - http://192.168.11.15:8080/api/benchmarks
) else (
    echo.
    echo [ERROR] Failed to add firewall rule. Please Run as Administrator.
)
pause
