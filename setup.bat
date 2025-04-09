@echo off
:: Check for administrative privileges
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

if %errorlevel% neq 0 (
    echo Running as administrator...
    PowerShell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:: Change to the script directory
cd /d "%~dp0"

:: Check if Git Bash is available
where bash >nul 2>nul
if %errorlevel% equ 0 (
    echo Git Bash found, will be used for VCS operations if needed
) else (
    echo WARNING: Git Bash not found in PATH. Some operations might fail.
    echo Please install Git for Windows with Git Bash to ensure full compatibility.
)

:: Run the PowerShell setup script
PowerShell -ExecutionPolicy Bypass -File setup.ps1

pause 