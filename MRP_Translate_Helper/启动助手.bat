@echo off
rem Double-click to start the MRP translation helper. The window title shows its status.
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel%==0 (
    py -3 mrptr_helper.py
) else (
    python mrptr_helper.py
)
echo.
pause
