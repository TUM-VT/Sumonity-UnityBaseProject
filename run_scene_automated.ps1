# Automated script to open and run a Unity scene in batch mode
param (
    [string]$UnityPath = "C:\Program Files\Unity\Hub\Editor\2022.3.8f1\Editor\Unity.exe", # Update with your Unity version
    [string]$ScenePath = "Assets/Scenes/MainScene.unity",
    [string]$LogFile = "unity_test_run.log",
    [int]$TimeToRun = 60, # Time in seconds to let the scene run before closing
    [switch]$ForceCleanup = $true, # Force cleanup of existing Unity processes
    [switch]$ScreenMode = $false  # New parameter for screen mode
)

# Function to check for and clean up any existing Unity processes
function Cleanup-UnityProcesses {
    param(
        [bool]$Force = $false,
        [string]$ProjectName = ""
    )
    
    # Get absolute path to identify our project
    $ProjectPath = Resolve-Path "."
    $ProjectName = Split-Path $ProjectPath -Leaf
    
    Write-Host "Checking for existing Unity processes..." -ForegroundColor Cyan
    $unityProcesses = Get-Process -Name "Unity" -ErrorAction SilentlyContinue
    
    if ($unityProcesses -and $unityProcesses.Count -gt 0) {
        Write-Host "Found $($unityProcesses.Count) Unity process(es) running." -ForegroundColor Yellow
        
        if ($Force) {
            Write-Host "Stopping all Unity processes..." -ForegroundColor Yellow
            foreach ($proc in $unityProcesses) {
                Write-Host "  Stopping Unity process with ID: $($proc.Id)" -ForegroundColor Yellow
                Stop-Process -Id $proc.Id -Force
            }
            Write-Host "All Unity processes stopped." -ForegroundColor Green
            
            # Also clean up Temp directory to remove any lock files
            $tempPath = Join-Path $ProjectPath "Temp"
            if (Test-Path $tempPath) {
                Write-Host "Cleaning up Temp directory..." -ForegroundColor Yellow
                try {
                    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "Temp directory cleaned." -ForegroundColor Green
                } catch {
                    Write-Host "Warning: Could not fully clean Temp directory. Some files may be locked." -ForegroundColor Yellow
                }
            }
            
            # Wait a moment for processes to fully terminate
            Start-Sleep -Seconds 2
        } else {
            Write-Host "Warning: Unity processes are running. This might cause conflicts." -ForegroundColor Yellow
            Write-Host "Use -ForceCleanup parameter to automatically terminate Unity processes." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No Unity processes found. Continuing..." -ForegroundColor Green
    }
}

# Run cleanup check
Cleanup-UnityProcesses -Force $ForceCleanup

# Check if Unity path exists
if (-not (Test-Path $UnityPath)) {
    Write-Host "Error: Unity executable not found at $UnityPath" -ForegroundColor Red
    Write-Host "Please update the UnityPath parameter to point to your Unity installation" -ForegroundColor Yellow
    exit 1
}

# Get the absolute path to the Unity project
$ProjectPath = Resolve-Path "."

# Additional cleanup - specifically target certain lock files
$tempPath = Join-Path $ProjectPath "Temp"
$editorLockFile = Join-Path $tempPath "UnityLockfile"

if (Test-Path $editorLockFile) {
    Write-Host "Found Unity lock file. Removing..." -ForegroundColor Yellow
    try {
        Remove-Item -Path $editorLockFile -Force -ErrorAction SilentlyContinue
        Write-Host "Unity lock file removed." -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not remove Unity lock file. You may need to restart your computer." -ForegroundColor Red
    }
}

Write-Host "Starting Unity in batch mode to run scene: $ScenePath" -ForegroundColor Cyan
Write-Host "Unity executable: $UnityPath" -ForegroundColor Cyan
Write-Host "Project path: $ProjectPath" -ForegroundColor Cyan
Write-Host "Test will run for $TimeToRun seconds" -ForegroundColor Cyan

# Run Unity in screen mode
$process = Start-Process -FilePath $UnityPath `
                         -ArgumentList "-projectPath", "`"$ProjectPath`"", "-logFile", "`"$LogFile`"", "-executeMethod", "AutomatedTesting.RunMainSceneTest" `
                         -PassThru

if ($null -eq $process) {
    Write-Host "Error: Failed to start Unity process." -ForegroundColor Red
    exit 1
}

Write-Host "Unity process started with ID: $($process.Id)" -ForegroundColor Green

# Wait a few seconds to check if process is still running (detect early crashes)
Start-Sleep -Seconds 5
if ($process.HasExited) {
    Write-Host "Error: Unity process exited unexpectedly. Check the log file for details." -ForegroundColor Red
    Analyze-LogFile -LogFilePath $LogFile
    exit 1
}

# Wait for the specified time
Write-Host "Waiting for $TimeToRun seconds while the scene runs..." -ForegroundColor Yellow
Start-Sleep -Seconds $TimeToRun

# Kill the Unity process after the specified time
Write-Host "Time elapsed. Stopping Unity process..." -ForegroundColor Yellow
Stop-Process -Id $process.Id -Force

Write-Host "Test completed. Check $LogFile for details." -ForegroundColor Green

# Function to parse the log file for errors or specific test results
function Analyze-LogFile {
    param (
        [string]$LogFilePath
    )
    
    if (Test-Path $LogFilePath) {
        $content = Get-Content $LogFilePath
        
        # Count errors
        $errorCount = ($content | Select-String -Pattern "ERROR" -CaseSensitive).Count
        
        Write-Host "Log Analysis:" -ForegroundColor Cyan
        Write-Host "- Total lines: $($content.Count)" -ForegroundColor Cyan
        Write-Host "- Error count: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) {"Red"} else {"Green"})
        
        # Show the last few lines which might contain test results
        Write-Host "Last 10 lines of log:" -ForegroundColor Cyan
        $content | Select-Object -Last 10
    } else {
        Write-Host "Log file not found at $LogFilePath" -ForegroundColor Red
    }
}

# Analyze the log after completion
Analyze-LogFile -LogFilePath $LogFile

# Check for test results file
$testResultsFile = "automated_test_results.log"
$possiblePaths = @(
    "$testResultsFile",  # Current directory
    "Assets/$testResultsFile",  # Assets folder
    "$env:TEMP\$testResultsFile",  # Temp directory
    "$env:USERPROFILE\Desktop\$testResultsFile"  # Desktop
)

$resultsFound = $false
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        Write-Host "`nAutomated Test Results found at: $path" -ForegroundColor Green
        Get-Content $path | Select-Object -Last 10
        $resultsFound = $true
        break
    }
}

if (-not $resultsFound) {
    Write-Host "No test results file found in any expected location" -ForegroundColor Yellow
    
    # Search log file for clues about why the test results file wasn't created
    if (Test-Path $LogFile) {
        Write-Host "Searching log for automated testing messages..." -ForegroundColor Yellow
        $testingMessages = Get-Content $LogFile | Select-String -Pattern "AutomatedTesting|Test completed|Performance Test Results|test_results.log" -Context 0,1
        
        if ($testingMessages -and $testingMessages.Count -gt 0) {
            Write-Host "Found $($testingMessages.Count) testing-related log entries:" -ForegroundColor Cyan
            foreach ($msg in $testingMessages) {
                Write-Host $msg -ForegroundColor Cyan
            }
        } else {
            Write-Host "No testing log messages found. The test may not have run properly." -ForegroundColor Red
        }
    }
}

# If you want to run specific tests, you could set up an editor script in Unity that's invoked with the -executeMethod parameter
# Example: "-executeMethod", "TestRunner.RunAutomatedTests" 