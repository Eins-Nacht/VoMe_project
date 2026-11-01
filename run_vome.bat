
@echo off
setlocal
title VoMe Launcher

echo =====================================
echo          Starting VoMe Project
echo =====================================

echo.
echo [1/3] Checking existing VoMe Backend...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$targets = @(Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'python.exe' -or $_.Name -eq 'pythonw.exe') -and $_.CommandLine -match 'uvicorn\s+app\.main:app' }); if ($targets.Count -gt 0) { Write-Host ('Found ' + $targets.Count + ' existing Backend process(es).'); foreach ($p in $targets) { Write-Host ('Stopping PID ' + $p.ProcessId); taskkill /PID $p.ProcessId /T /F | Out-Null }; Start-Sleep -Seconds 2; Write-Host 'Backend cleanup completed.' } else { Write-Host 'No existing VoMe Backend found.' }"

if errorlevel 1 (
    echo [ERROR] Failed to check or stop existing Backend.
    pause
    exit /b 1
)

echo.
echo [2/3] Starting Backend...

set "VOME_PYTHON=C:\Users\sheeg\AppData\Local\Python\pythoncore-3.14-64\python.exe"
if not exist "%VOME_PYTHON%" (
    echo [ERROR] VoMe Python executable was not found:
    echo %VOME_PYTHON%
    pause
    exit /b 1
)

start "VoMe Backend" /D "%~dp0backend" cmd /k "set WHISPER_MODEL=Systran/faster-whisper-small&& set WHISPER_DEVICE=cpu&& set WHISPER_COMPUTE_TYPE=int8&& set HF_HUB_OFFLINE=1&& "%VOME_PYTHON%" -m alembic upgrade head && "%VOME_PYTHON%" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"

timeout /t 3 /nobreak >nul

echo.
echo [3/3] Starting Flutter...

start "VoMe Flutter" /D "%~dp0vome" cmd /k "flutter pub get && flutter run"

echo.
echo =====================================
echo   VoMe Backend and Flutter launched
echo =====================================

pause
endlocal
