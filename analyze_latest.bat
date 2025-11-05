@echo off
REM Position Accuracy Analysis - Quick Run Script
REM Usage: analyze_latest.bat

echo ================================================
echo Position Accuracy Log Analyzer
echo ================================================
echo.

REM Find the most recent CSV file in Logs/PositionAccuracy
set "LOG_DIR=Logs\PositionAccuracy"

if not exist "%LOG_DIR%" (
    echo Error: Log directory not found: %LOG_DIR%
    echo Please run a simulation first to generate log files.
    pause
    exit /b 1
)

REM Find the latest CSV file
for /f "delims=" %%i in ('dir /b /o-d /a-d "%LOG_DIR%\position_accuracy_*.csv" 2^>nul') do (
    set "LATEST_FILE=%LOG_DIR%\%%i"
    goto :found
)

echo Error: No log files found in %LOG_DIR%
echo Please run a simulation first to generate log files.
pause
exit /b 1

:found
echo Latest log file: %LATEST_FILE%
echo.
echo Starting analysis...
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python 3.x with pandas and matplotlib
    pause
    exit /b 1
)

REM Run the analysis script
python analyze_position_accuracy.py "%LATEST_FILE%"

echo.
echo ================================================
echo Analysis complete!
echo ================================================
echo.
echo Output files saved to: %LOG_DIR%\analysis\
echo.

pause
