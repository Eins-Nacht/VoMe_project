
@echo off
title VoMe Launcher

echo =====================================
echo          Starting VoMe Project
echo =====================================

echo.
echo [1/2] Starting Backend...

start "VoMe Backend" /D "%~dp0backend" cmd /k "python -m alembic upgrade head && python -m uvicorn app.main:app --reload"

timeout /t 2 /nobreak >nul

echo.
echo [2/2] Starting Flutter...

start "VoMe Flutter" /D "%~dp0vome" cmd /k "flutter pub get && flutter run"

echo.
echo =====================================
echo   VoMe Backend and Flutter launched
echo =====================================
