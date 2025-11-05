@echo off
REM Debug script to check what's in the Unity log file
REM This helps diagnose initialization detection issues

echo ================================================
echo Unity Log File Debugger
echo ================================================
echo.

set "LOG_FILE=unity_test_run.log"

if not exist "%LOG_FILE%" (
    echo Log file not found: %LOG_FILE%
    echo.
    echo Starting Unity briefly to create log file...
    timeout /t 3 /nobreak >nul
    
    REM Start Unity briefly
    start /min "" "C:\Program Files\Unity\Hub\Editor\2022.3.8f1\Editor\Unity.exe" -projectPath "%CD%" -logFile "%LOG_FILE%" -batchmode -quit
    
    echo Waiting 20 seconds for Unity to start and create log...
    timeout /t 20 /nobreak
)

if exist "%LOG_FILE%" (
    echo.
    echo ================================================
    echo Last 50 lines of Unity log:
    echo ================================================
    echo.
    
    powershell -Command "Get-Content '%LOG_FILE%' -Tail 50"
    
    echo.
    echo ================================================
    echo Searching for initialization keywords:
    echo ================================================
    
    powershell -Command "$content = Get-Content '%LOG_FILE%'; Write-Host 'Initialize engine version:' (($content | Select-String 'Initialize engine version').Count) 'matches'; Write-Host 'Loading scene:' (($content | Select-String 'Loading scene').Count) 'matches'; Write-Host 'Loaded scene:' (($content | Select-String 'Loaded scene').Count) 'matches'; Write-Host 'PositionAccuracyLogger:' (($content | Select-String 'PositionAccuracyLogger').Count) 'matches'; Write-Host 'AutomatedTesting:' (($content | Select-String 'AutomatedTesting').Count) 'matches'; Write-Host 'GfxDevice:' (($content | Select-String 'GfxDevice:').Count) 'matches'"
    
    echo.
    echo ================================================
    echo Log file info:
    echo ================================================
    dir "%LOG_FILE%"
) else (
    echo Log file still not found after waiting.
    echo Unity may not have started properly.
)

echo.
pause
