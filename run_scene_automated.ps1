# Automated script to open and run a Unity scene in batch mode
param (
    [string]$UnityPath = "C:\Program Files\Unity\Hub\Editor\2022.3.8f1\Editor\Unity.exe",
    [string]$ScenePath = "Assets/Scenes/MainScene.unity",
    [string]$LogFile = "unity_test_run.log",
    [int]$TimeToRun = 60,
    [switch]$ForceCleanup = $true,
    [switch]$ScreenMode = $false,
    [switch]$VehiclePositionComparison = $true,
    [string]$PositionAccuracyDirectory = "Logs\PositionAccuracy",
    [double]$ErrorThreshold = 1.5,  # Updated to 1.5 meters for new logging system
    [string]$LogFilePath = "C:\Users\celsius\actions-runner\_work\Sumonity-UnityBaseProject\Sumonity-UnityBaseProject\unity_test_run.log",
    [switch]$BypassInitCheck = $false
)

# Simple progress indicator
Write-Host "--- Unity Scene Test Automation ---" -ForegroundColor Cyan

# Function to check for and clean up any existing Unity processes (simplified output)
function Cleanup-UnityProcesses {
    param(
        [bool]$Force = $false
    )
    
    $unityProcesses = Get-Process -Name "Unity" -ErrorAction SilentlyContinue
    
    if ($unityProcesses -and $unityProcesses.Count -gt 0) {
        Write-Host "Cleaning up $($unityProcesses.Count) existing Unity process(es)..." -ForegroundColor Yellow
        if ($Force) {
            foreach ($proc in $unityProcesses) {
                Stop-Process -Id $proc.Id -Force
            }
            
            # Clean up Temp directory
            $ProjectPath = Resolve-Path "."
            $tempPath = Join-Path $ProjectPath "Temp"
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            Start-Sleep -Seconds 2
        }
    }
}

# Run cleanup check without verbose messages
Cleanup-UnityProcesses -Force $ForceCleanup

# Quickly check if Unity path exists
if (-not (Test-Path $UnityPath)) {
    Write-Host "Error: Unity executable not found at $UnityPath" -ForegroundColor Red
    exit 1
}

# Get the absolute path to the Unity project
$ProjectPath = Resolve-Path "."

# Remove Unity lock file if exists
$tempPath = Join-Path $ProjectPath "Temp"
$editorLockFile = Join-Path $tempPath "UnityLockfile"
if (Test-Path $editorLockFile) {
    Remove-Item -Path $editorLockFile -Force -ErrorAction SilentlyContinue
}

# Run Unity in batch mode
Write-Host "Starting Unity process..." -ForegroundColor Cyan
$process = Start-Process -FilePath $UnityPath `
                        -ArgumentList "-projectPath", "`"$ProjectPath`"", "-logFile", "`"$LogFile`"", "-executeMethod", "AutomatedTesting.RunMainSceneTest" `
                        -PassThru
                       
if ($null -eq $process) {
    Write-Host "Error: Failed to start Unity process." -ForegroundColor Red
    exit 1
}

# Function to check Unity initialization status
function Test-UnityInitialization {
    param (
        [string]$LogFilePath
    )
    
    if (-not (Test-Path $LogFilePath)) {
        # Only write this once, not repeatedly
        if (-not $global:logFileWarningDisplayed) {
            Write-Host "Log file not found at path: $LogFilePath" -ForegroundColor Yellow
            Write-Host "Expected log path: $LogFilePath" -ForegroundColor Yellow
            $global:logFileWarningDisplayed = $true
        }
        return $false
    }
    
    # Show that we found the log file on first read
    if (-not $global:logFileFoundDisplayed) {
        Write-Host "Log file found at: $LogFilePath" -ForegroundColor Green
        $fileSize = (Get-Item $LogFilePath).Length
        Write-Host "Current log file size: $fileSize bytes" -ForegroundColor Cyan
        $global:logFileFoundDisplayed = $true
    }
    
    $logContent = Get-Content $LogFilePath -Tail 200
    $initializationComplete = $false
    $sceneLoaded = $false
    $errorsFound = $false
    
    # Debug: Show last few log lines on first check
    if (-not $global:logLinesDisplayed) {
        Write-Host "`nRecent log entries (for debugging):" -ForegroundColor Cyan
        $logContent | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        $global:logLinesDisplayed = $true
    }
    
    # Check for initialization sequence
    foreach ($line in $logContent) {
        if ($line -match "Initialize engine version") {
            $initializationComplete = $true
        }
        if ($line -match "Loading scene" -or $line -match "Loaded scene" -or $line -match "Opening scene") {
            $sceneLoaded = $true
        }
        
        # Check for position accuracy logger initialization as a positive signal
        if ($line -match "PositionAccuracyLogger.*Initialized") {
            Write-Host "Position Accuracy Logger initialized successfully" -ForegroundColor Green
            $sceneLoaded = $true
        }
        
        # Now that we've identified all the patterns to filter, let's add the Licensing Module error to the non-critical patterns
        $nonCriticalPatterns = @(
            "fallback shader .* not found",
            "Certificate has expired",
            "LogAssemblyErrors",
            "will not be compiled because it exists outside",
            "Cert verify failed",
            "EditorUpdateCheck",
            "Licensing::Module",
            "Access token is unavailable",
            "Start importing .* using Guid\(",
            "ValidationExceptions\.json",
            "UnityEngine\.Debug:LogError"
        )

        # Filter out common non-critical errors
        $isNonCriticalError = $false
        foreach ($pattern in $nonCriticalPatterns) {
            if ($line -match $pattern) {
                $isNonCriticalError = $true
                break
            }
        }
        
        if (($line -match "ERROR" -or $line -match "Exception") -and -not $isNonCriticalError) {
            $errorsFound = $true
            Write-Host "Found critical error in Unity log: $line" -ForegroundColor Red
        }
    }
    
    # Check for specific Unity ready indicators (more flexible patterns)
    $readyIndicators = @(
        "Unity Editor is ready",
        "Scene loaded",
        "All packages loaded",
        "Project loaded",
        "Initialization complete",
        "Loaded scene",
        "Successfully loaded",
        "Started playing",
        "Scene is active",
        "Play mode started",
        "PositionAccuracyLogger",
        "AutomatedTesting",
        "RunMainSceneTest",
        "Initialize mono",
        "GfxDevice:",
        "Begin MonoManager"
    )
    
    $readyCount = 0
    $foundIndicators = @()
    foreach ($indicator in $readyIndicators) {
        $matches = $logContent | Where-Object { $_ -match $indicator }
        if ($matches) {
            $readyCount++
            # Only add to foundIndicators if not already there (avoid duplicates)
            if ($foundIndicators -notcontains $indicator) {
                $foundIndicators += $indicator
            }
        }
    }
    
    # Only print once when initialization indicators are found
    # Avoid printing this multiple times by using a global variable
    if ($readyCount -gt 0 -and $foundIndicators.Count -gt 0 -and -not $global:initializationMessageDisplayed) {
        Write-Host "Found $readyCount initialization indicator(s): $($foundIndicators -join ', ')" -ForegroundColor Green
        $global:initializationMessageDisplayed = $true
    }
    
    # More lenient check: Return true if we have any indicators OR scene is loaded OR enough log content
    # This is because batch mode Unity may not output all the usual messages
    $logContentHasMinimumSize = $logContent.Count -gt 20
    
    return (($initializationComplete -and $sceneLoaded -and -not $errorsFound) -or 
            $readyCount -ge 2 -or 
            ($logContentHasMinimumSize -and $sceneLoaded))
}

# Function to wait for Unity to fully initialize
function Wait-ForUnityInitialization {
    param (
        [string]$LogFilePath,
        [int]$TimeoutSeconds = 180  # Reduced to 3 minutes timeout
    )
    
    Write-Host "Waiting for Unity to fully initialize..." -ForegroundColor Cyan
    $startTime = Get-Date
    $timeout = $startTime.AddSeconds($TimeoutSeconds)
    $lastProgressDisplay = Get-Date
    $progressInterval = 10  # Show progress every 10 seconds
    
    # Reset global variables
    $global:logFileWarningDisplayed = $false
    $global:logFileFoundDisplayed = $false
    $global:logLinesDisplayed = $false
    $global:initializationMessageDisplayed = $false
    
    while ((Get-Date) -lt $timeout) {
        if (Test-UnityInitialization -LogFilePath $LogFilePath) {
            Write-Host "Unity initialization completed successfully" -ForegroundColor Green
            return $true
        }
        
        # Only show progress periodically
        $now = Get-Date
        if (($now - $lastProgressDisplay).TotalSeconds -ge $progressInterval) {
            $elapsedTime = [math]::Floor(($now - $startTime).TotalSeconds)
            Write-Host "Still waiting for Unity initialization... ($elapsedTime seconds elapsed)" -ForegroundColor Yellow
            $lastProgressDisplay = $now
        }
        
        Start-Sleep -Seconds 2
    }
    
    Write-Host "Timeout waiting for Unity initialization" -ForegroundColor Red
    return $false
}

# Quick check if process is still running after 5 seconds
Start-Sleep -Seconds 5
if ($process.HasExited) {
    Write-Host "Error: Unity process exited unexpectedly." -ForegroundColor Red
    exit 1
}

# Wait for Unity to fully initialize
if ($BypassInitCheck) {
    Write-Host "Bypassing Unity initialization check as requested" -ForegroundColor Yellow
    Write-Host "Waiting 15 seconds for Unity to start..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15
    $initialized = $true
} else {
    $initialized = Wait-ForUnityInitialization -LogFilePath $LogFilePath
    
    # If initialization check failed, but process is still running, give benefit of doubt
    if (-not $initialized -and -not $process.HasExited) {
        Write-Host "Warning: Standard initialization checks failed, but Unity is still running" -ForegroundColor Yellow
        Write-Host "Proceeding anyway - Unity may be running in batch mode with minimal logging" -ForegroundColor Yellow
        $initialized = $true
    }
}

if (-not $initialized) {
    Write-Host "Error: Unity failed to initialize within timeout period" -ForegroundColor Red
    Stop-Process -Id $process.Id -Force
    exit 1
}

# Wait for the specified time
Write-Host "Running scene for $TimeToRun seconds..." -ForegroundColor Cyan
Start-Sleep -Seconds $TimeToRun

# Kill the Unity process after the specified time
Write-Host "Stopping Unity process..." -ForegroundColor Cyan
Stop-Process -Id $process.Id -Force
Write-Host "Unity process stopped" -ForegroundColor Green

# Function to parse the log file for errors
function Analyze-LogFile {
    param (
        [string]$LogFilePath
    )
    
    Write-Host "Analyzing log file..." -ForegroundColor Cyan
    if (Test-Path $LogFilePath) {
        $content = Get-Content $LogFilePath
        $errorCount = ($content | Select-String -Pattern "ERROR" -CaseSensitive).Count
        
        if ($errorCount -gt 0) {
            Write-Host "Found $errorCount errors in log file" -ForegroundColor Red
        } else {
            Write-Host "No errors found in log file" -ForegroundColor Green
        }
    } else {
        Write-Host "Log file not found at $LogFilePath" -ForegroundColor Yellow
    }
}

# Analyze the log after completion
Analyze-LogFile -LogFilePath $LogFilePath

# Function to evaluate position accuracy statistics from new logging system
function Evaluate-PositionAccuracyStatistics {
    param (
        [string]$DirectoryPath,
        [double]$Threshold
    )
    
    Write-Host "Evaluating position accuracy statistics from new logging system..." -ForegroundColor Cyan
    Write-Host "Looking for statistics summary files in: $DirectoryPath" -ForegroundColor Cyan
    Write-Host "Error threshold: $Threshold meters" -ForegroundColor Cyan
    
    if (-not (Test-Path $DirectoryPath)) {
        Write-Host "Position accuracy directory not found at $DirectoryPath" -ForegroundColor Red
        return $null
    }
    
    # Find the most recent statistics summary file
    $summaryFiles = Get-ChildItem -Path $DirectoryPath -Filter "statistics_summary_*.txt" -ErrorAction SilentlyContinue
    
    if (-not $summaryFiles -or $summaryFiles.Count -eq 0) {
        Write-Host "No statistics summary files found in $DirectoryPath" -ForegroundColor Yellow
        Write-Host "Expected format: statistics_summary_YYYY-MM-DD_HH-mm-ss.txt" -ForegroundColor Yellow
        return $null
    }
    
    # Get the most recent file
    $latestFile = $summaryFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "Found statistics summary file: $($latestFile.Name)" -ForegroundColor Green
    Write-Host "File last modified: $($latestFile.LastWriteTime)" -ForegroundColor Cyan
    
    try {
        $content = Get-Content -Path $latestFile.FullName
        
        # Parse the file for average position error (handle both comma and period decimal separators)
        $avgErrorLine = $content | Where-Object { $_ -match "Average Position Error:\s*([\d.,]+)\s*m" }
        
        if ($avgErrorLine) {
            # Replace comma with period for parsing (handle European number format)
            $avgErrorString = $Matches[1] -replace ',', '.'
            $avgError = [double]$avgErrorString
            Write-Host "Overall Average Position Error: $avgError meters" -ForegroundColor Cyan
            
            # Check if within threshold
            if ($avgError -gt $Threshold) {
                Write-Host "ERROR: Average position error ($avgError m) exceeds threshold of $Threshold meters" -ForegroundColor Red
                
                # Parse per-vehicle statistics for more details
                Write-Host "`nPer-Vehicle Statistics:" -ForegroundColor Yellow
                $inVehicleSection = $false
                foreach ($line in $content) {
                    if ($line -match "=== Per-Vehicle Statistics ===") {
                        $inVehicleSection = $true
                        continue
                    }
                    if ($inVehicleSection -and $line.Trim() -ne "") {
                        Write-Host "  $line" -ForegroundColor Yellow
                    }
                }
                
                return $false
            } else {
                Write-Host "Position accuracy is within acceptable limits (threshold: $Threshold m)" -ForegroundColor Green
                
                # Also check for total entries to ensure we got enough data
                $totalEntriesLine = $content | Where-Object { $_ -match "Total Entries Logged:\s*(\d+)" }
                if ($totalEntriesLine) {
                    $totalEntries = [int]($Matches[1])
                    Write-Host "Total entries logged: $totalEntries" -ForegroundColor Cyan
                    
                    if ($totalEntries -lt 10) {
                        Write-Host "WARNING: Very few entries logged ($totalEntries). Results may not be reliable." -ForegroundColor Yellow
                    }
                }
                
                # Show active vehicles count
                $activeVehiclesLine = $content | Where-Object { $_ -match "Active Vehicles:\s*(\d+)" }
                if ($activeVehiclesLine) {
                    $activeVehicles = [int]($Matches[1])
                    Write-Host "Active vehicles tracked: $activeVehicles" -ForegroundColor Cyan
                }
                
                return $true
            }
        } else {
            Write-Host "Could not parse Average Position Error from statistics summary" -ForegroundColor Yellow
            Write-Host "File content preview:" -ForegroundColor Yellow
            $content | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            return $null
        }
    }
    catch {
        Write-Host "Error reading or parsing statistics summary: $_" -ForegroundColor Red
        return $null
    }
}

# Check for vehicle position accuracy results from new logging system
if ($VehiclePositionComparison) {
    Write-Host "Checking for position accuracy statistics from new logging system..." -ForegroundColor Cyan
    $positionDir = Join-Path $ProjectPath $PositionAccuracyDirectory
    
    # Evaluate the position accuracy statistics
    $evalResult = Evaluate-PositionAccuracyStatistics -DirectoryPath $positionDir -Threshold $ErrorThreshold
    
    if ($evalResult -eq $false) {
        Write-Host "Position accuracy test FAILED - Error exceeds threshold" -ForegroundColor Red
        exit 1  # Exit with error code for pipeline integration
    } elseif ($evalResult -eq $true) {
        Write-Host "Position accuracy test PASSED" -ForegroundColor Green
    } else {
        Write-Host "Position accuracy test INCONCLUSIVE - No data available or parsing error" -ForegroundColor Yellow
        Write-Host "This may indicate the simulation did not run long enough or logger was not initialized" -ForegroundColor Yellow
        exit 1  # Exit with error code since we expect position data
    }
}

Write-Host "Script execution completed" -ForegroundColor Cyan 
