@echo off
setlocal ENABLEDELAYEDEXPANSION

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

set "UNITY_PATH=%UNITY_PATH%"
set "SCENE_ARG=Assets/Scenes/MainScene.unity"
set "SIM_SECONDS="
set "TIMEOUT_SECONDS="
set "EXTRA_ARGS="
set "HEADLESS=1"
set "RUN_ACCURACY=1"
set "ACCURACY_THRESHOLD=1.5"
set "PYTHON_CMD=python"
set "ACCURACY_SCRIPT=%PROJECT_DIR%\check_position_accuracy_ci.py"

:parse
if "%~1"=="" goto run
if /I "%~1"=="-unityPath" (
    set "UNITY_PATH=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-scenePath" (
    set "SCENE_ARG=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-simulationSeconds" (
    set "SIM_SECONDS=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-timeoutSeconds" (
    set "TIMEOUT_SECONDS=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-withGui" (
    set "HEADLESS=0"
    shift
    goto parse
)
if /I "%~1"=="--threshold" (
    set "ACCURACY_THRESHOLD=%~2"
    set "RUN_ACCURACY=1"
    shift
    shift
    goto parse
)
if /I "%~1"=="--skipAccuracy" (
    set "RUN_ACCURACY=0"
    shift
    goto parse
)
if /I "%~1"=="--python" (
    set "PYTHON_CMD=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="--accuracyScript" (
    set "ACCURACY_SCRIPT=%~2"
    shift
    shift
    goto parse
)
set "EXTRA_ARGS=!EXTRA_ARGS! %~1"
shift
goto parse

:run
if not defined UNITY_PATH (
    echo [ERROR] UNITY_PATH environment variable not set. Use -unityPath or set it before calling this script.
    exit /b 1
)

if not exist "%PROJECT_DIR%\Logs" mkdir "%PROJECT_DIR%\Logs" >nul 2>&1
set "LOG_FILE=%PROJECT_DIR%\Logs\ci-simulation.log"

set "UNITY_ARGS=-projectPath ""%PROJECT_DIR%"" -logFile ""%LOG_FILE%"" -executeMethod Sumonity.EditorCI.CIEntryPoints.RunHeadlessSimulation -scenePath ""%SCENE_ARG%"""
if "%HEADLESS%"=="1" set "UNITY_ARGS=-batchmode -nographics %UNITY_ARGS%"
if defined SIM_SECONDS set "UNITY_ARGS=!UNITY_ARGS! -simulationSeconds %SIM_SECONDS%"
if defined TIMEOUT_SECONDS set "UNITY_ARGS=!UNITY_ARGS! -timeoutSeconds %TIMEOUT_SECONDS%"
if defined EXTRA_ARGS set "UNITY_ARGS=!UNITY_ARGS! %EXTRA_ARGS%"

echo [INFO] Launching Unity from %UNITY_PATH%
echo [INFO] Scene: %SCENE_ARG%
"%UNITY_PATH%" !UNITY_ARGS!
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
    echo [ERROR] Unity exited with code %EXITCODE%.
) else (
    echo [INFO] Unity exited successfully.

    if "%RUN_ACCURACY%"=="1" (
        if exist "%ACCURACY_SCRIPT%" (
            echo [INFO] Running accuracy analysis with threshold %ACCURACY_THRESHOLD%m...
            "%PYTHON_CMD%" "%ACCURACY_SCRIPT%" --threshold %ACCURACY_THRESHOLD%
            set "ANALYSIS_EXIT=!ERRORLEVEL!"
            if not "!ANALYSIS_EXIT!"=="0" (
                echo [ERROR] Accuracy check failed with code !ANALYSIS_EXIT!.
                set "EXITCODE=!ANALYSIS_EXIT!"
            ) else (
                echo [INFO] Accuracy check passed.
            )
        ) else (
            echo [WARN] Accuracy script not found at "%ACCURACY_SCRIPT%". Skipping accuracy validation.
        )
    )
)

endlocal & exit /b %EXITCODE%
