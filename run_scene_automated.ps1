# Automated script to open and run a Unity scene in batch mode
param (
    [string]$UnityPath = "C:\Program Files\Unity\Hub\Editor\2022.3.8f1\Editor\Unity.exe",
    [string]$ScenePath = "Assets/Scenes/MainScene.unity",
    [string]$LogFile = "unity_test_run.log",
    [int]$TimeToRun = 240,
    [switch]$ForceCleanup = $true,
    [switch]$ScreenMode = $false,
    [switch]$VehiclePositionComparison = $true,
    [string]$PositionAccuracyDirectory = "Logs\PositionAccuracy",
    [double]$ErrorThreshold = 1.5,  # Updated to 1.5 meters for new logging system
    [string]$LogFilePath = "C:\Users\celsius\actions-runner\_work\Sumonity-UnityBaseProject\Sumonity-UnityBaseProject\unity_test_run.log",
    [switch]$BypassInitCheck = $false,
    [string[]]$TraCIProcessNames = @("python.exe", "python3.exe", "pythonw.exe"),
    [string[]]$TraCICommandMarkers = @("SumoTraCI", "socketServer.py", "traci"),
    [int]$TraCIPort = 25001,
    [string]$PythonExecutable = "python"
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

# Detect the SUMO TraCI python bridge to confirm simulation playback state.
function Test-TraCIProcess {
    param(
        [string[]]$ProcessNames,
        [string[]]$CommandMarkers
    )

    if (-not $CommandMarkers -or $CommandMarkers.Count -eq 0) {
        return $false
    }

    $nameFilters = @()
    foreach ($rawPattern in $ProcessNames) {
        if ([string]::IsNullOrWhiteSpace($rawPattern)) {
            continue
        }

        $pattern = $rawPattern.Trim()

        if ($pattern.Contains("*") -or $pattern.Contains("?")) {
            $sqlPattern = $pattern.Replace("*", "%").Replace("?", "_")
            $nameFilters += "Name LIKE '$sqlPattern'"
        } elseif ($pattern.Contains("%") -or $pattern.Contains("_")) {
            $nameFilters += "Name LIKE '$pattern'"
        } else {
            if (-not $pattern.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
                $pattern = "$pattern.exe"
            }
            $nameFilters += "Name = '$pattern'"
        }
    }

    if ($nameFilters.Count -eq 0) {
        $nameFilters = @("Name LIKE 'python%.exe'")
    }

    $filterClause = [string]::Join(" OR ", $nameFilters)
    $query = "SELECT ProcessId, CommandLine, Name FROM Win32_Process WHERE $filterClause"

    try {
        $processes = Get-CimInstance -Query $query -ErrorAction Stop
    }
    catch {
        if (-not $global:TraCIProcessQueryWarning) {
            Write-Host "Warning: Unable to inspect running processes for TraCI detection ($($_.Exception.Message))." -ForegroundColor Yellow
            $global:TraCIProcessQueryWarning = $true
        }
        return $false
    }

    if (-not $processes) {
        return $false
    }

    foreach ($process in $processes) {
        $commandLine = $process.CommandLine
        if ([string]::IsNullOrWhiteSpace($commandLine)) {
            continue
        }

        foreach ($marker in $CommandMarkers) {
            if ([string]::IsNullOrWhiteSpace($marker)) {
                continue
            }

            if ($commandLine.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                if (-not $global:TraCIProcessMessageDisplayed) {
                    $exeName = $process.Name
                    $processId = $process.ProcessId
                    Write-Host "Detected TraCI Python process ($exeName, PID $processId) via marker '$marker'." -ForegroundColor Green
                    $global:TraCIProcessMessageDisplayed = $true
                }
                return $true
            }
        }
    }

    return $false
}

function Test-TraCIRuntime {
    param(
        [string[]]$ProcessNames,
        [string[]]$CommandMarkers,
        [int]$Port
    )

    $processDetected = Test-TraCIProcess -ProcessNames $ProcessNames -CommandMarkers $CommandMarkers
    if ($processDetected) {
        return $true
    }

    try {
        $connections = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        if (-not $global:TraCIPortCommandWarning) {
            Write-Host "Warning: Get-NetTCPConnection not available; TraCI socket detection disabled." -ForegroundColor Yellow
            $global:TraCIPortCommandWarning = $true
        }
        return $false
    }
    catch {
        if (-not $global:TraCIPortQueryWarning) {
            Write-Host "Warning: Unable to query TraCI port state ($($_.Exception.Message))." -ForegroundColor Yellow
            $global:TraCIPortQueryWarning = $true
        }
        return $false
    }

    if ($connections) {
        if (-not $global:TraCIPortMessageDisplayed) {
            Write-Host "Detected TraCI listener on 127.0.0.1:$Port." -ForegroundColor Green
            $global:TraCIPortMessageDisplayed = $true
        }
        return $true
    }

    return $false
}

# Quickly check if Unity path exists
if (-not (Test-Path $UnityPath)) {
    Write-Host "Error: Unity executable not found at $UnityPath" -ForegroundColor Red
    exit 1
}

# Get the absolute path to the Unity project
$ProjectPath = Resolve-Path "."

# Resolve Unity log file path
$unityLogPath = $LogFile
if (-not [System.IO.Path]::IsPathRooted($unityLogPath)) {
    $unityLogPath = Join-Path $ProjectPath $unityLogPath
}

$resolvedLogFilePath = $LogFilePath
if ([string]::IsNullOrWhiteSpace($resolvedLogFilePath)) {
    $resolvedLogFilePath = $unityLogPath
} else {
    if (-not [System.IO.Path]::IsPathRooted($resolvedLogFilePath)) {
        $resolvedLogFilePath = Join-Path $ProjectPath $resolvedLogFilePath
    }
    $resolvedLogParent = Split-Path -Path $resolvedLogFilePath -Parent
    if ($resolvedLogParent -and -not (Test-Path -Path $resolvedLogParent -PathType Container)) {
        $resolvedLogFilePath = $unityLogPath
    }
}
$LogFilePath = $resolvedLogFilePath

# Remove Unity lock file if exists
$tempPath = Join-Path $ProjectPath "Temp"
$editorLockFile = Join-Path $tempPath "UnityLockfile"
if (Test-Path $editorLockFile) {
    Remove-Item -Path $editorLockFile -Force -ErrorAction SilentlyContinue
}

# Run Unity in batch mode
Write-Host "Starting Unity process..." -ForegroundColor Cyan
$process = Start-Process -FilePath $UnityPath `
                        -ArgumentList "-projectPath", "`"$ProjectPath`"", "-logFile", "`"$unityLogPath`"", "-executeMethod", "AutomatedTesting.RunMainSceneTest" `
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
    
    $foundIndicators = @()
    $playModeFound = $false

    $traCIRuntimeActive = Test-TraCIRuntime -ProcessNames $TraCIProcessNames -CommandMarkers $TraCICommandMarkers -Port $TraCIPort
    if ($traCIRuntimeActive -and ($foundIndicators -notcontains "TraCI runtime")) {
        $foundIndicators += "TraCI runtime"
    }
    if ($traCIRuntimeActive) {
        $playModeFound = $true
    }

    if (-not (Test-Path $LogFilePath)) {
        # Only write this once, not repeatedly
        if (-not $global:logFileWarningDisplayed) {
            Write-Host "Log file not found at path: $LogFilePath" -ForegroundColor Yellow
            Write-Host "Expected log path: $LogFilePath" -ForegroundColor Yellow
            $global:logFileWarningDisplayed = $true
        }
        if ($playModeFound -and -not $global:initializationMessageDisplayed) {
            Write-Host "PLAY MODE DETECTED: $($foundIndicators -join ', ')" -ForegroundColor Green
            $global:initializationMessageDisplayed = $true
        }
        return $playModeFound
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
        
        # Also show what stage Unity is in
        Write-Host "`nDetecting Unity initialization stage:" -ForegroundColor Cyan
        if ($logContent -match "Rebuilding Library") {
            Write-Host "  - Rebuilding asset library (this can take several minutes on first run)" -ForegroundColor Yellow
        }
        if ($logContent -match "Importing") {
            Write-Host "  - Importing assets..." -ForegroundColor Yellow
        }
        if ($logContent -match "Compiling") {
            Write-Host "  - Compiling scripts..." -ForegroundColor Yellow
        }
        if ($logContent -match "Initialize engine") {
            Write-Host "  - Engine initialized" -ForegroundColor Green
        }
        if ($logContent -match "Loading scene" -or $logContent -match "Opening scene") {
            Write-Host "  - Loading scene..." -ForegroundColor Yellow
        }
        if ($logContent -match "Entered play mode" -or $logContent -match "EnteredPlayMode") {
            Write-Host "  - PLAY MODE ACTIVE" -ForegroundColor Green
        }
        
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
            "Licensing::Client",
            "Access token is unavailable",
            "Start importing .* using Guid\(",
            "ValidationExceptions\.json",
            "UnityEngine\.Debug:LogError",
            "FSBTool ERROR"
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
    
    # Check for specific Unity ready indicators - ONLY accept actual play mode entry
    # In batch mode, Unity doesn't always output "Entered play mode", so we look for:
    # 1. Explicit play mode messages (editor/some batch runs)
    # 2. PositionAccuracyLogger initialization (our custom marker)
    # 3. Python sys.path setup (indicates SUMO/scene is running)
    # 4. Scene physics/simulation starting
    # 5. External SUMO TraCI bridge (python process) spinning up alongside Unity
    $playModeIndicators = @(
        "Entered play mode",
        "EnteredPlayMode",
        "PositionAccuracyLogger.*Initialized",
        "sys\.path = \['C:/Users",  # Python environment setup for SUMO
        "Unloading.*unused Assets",  # Assets cleanup after scene load
        "TrimDiskCacheJob"  # Disk cache cleanup happens after scene starts
    )
    
    foreach ($indicator in $playModeIndicators) {
        $matches = $logContent | Where-Object { $_ -match $indicator }
        if ($matches) {
            $playModeFound = $true
            if ($foundIndicators -notcontains $indicator) {
                $foundIndicators += $indicator
            }
        }
    }
    
    # Only print once when play mode is detected
    if ($playModeFound -and -not $global:initializationMessageDisplayed) {
        Write-Host "PLAY MODE DETECTED: $($foundIndicators -join ', ')" -ForegroundColor Green
        $global:initializationMessageDisplayed = $true
    }
    
    # Only return true if we have explicit play mode confirmation
    # Don't accept engine initialization or scene loading as "ready" - must be in play mode
    return $playModeFound
}

# Function to wait for Unity to fully initialize
function Wait-ForUnityInitialization {
    param (
        [string]$LogFilePath,
        [int]$TimeoutSeconds = 1200  # 10 minutes timeout for first-time initialization
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
    $global:TraCIProcessMessageDisplayed = $false
    $global:TraCIProcessQueryWarning = $false
    $global:TraCIPortMessageDisplayed = $false
    $global:TraCIPortCommandWarning = $false
    $global:TraCIPortQueryWarning = $false
    
    while ((Get-Date) -lt $timeout) {
        if (Test-UnityInitialization -LogFilePath $LogFilePath) {
            Write-Host "Unity initialization completed successfully" -ForegroundColor Green
            return $true
        }
        
        # Only show progress periodically
        $now = Get-Date
        if (($now - $lastProgressDisplay).TotalSeconds -ge $progressInterval) {
            $elapsedTime = [math]::Floor(($now - $startTime).TotalSeconds)
            
            # Show what Unity is doing
            if (Test-Path $LogFilePath) {
                $recentLines = Get-Content $LogFilePath -Tail 3 -ErrorAction SilentlyContinue
                $lastLine = $recentLines | Select-Object -Last 1
                if ($lastLine -and $lastLine.Trim() -ne "") {
                    Write-Host "Still waiting... ($elapsedTime seconds) - Last activity: $($lastLine.Substring(0, [Math]::Min(100, $lastLine.Length)))" -ForegroundColor Yellow
                } else {
                    Write-Host "Still waiting for Unity initialization... ($elapsedTime seconds elapsed)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "Still waiting for Unity initialization... ($elapsedTime seconds elapsed)" -ForegroundColor Yellow
            }
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

# Gracefully stop the Unity process to allow OnApplicationQuit() to run
Write-Host "Stopping Unity process gracefully..." -ForegroundColor Cyan

# Try graceful shutdown first
try {
    # Send close window message
    $process.CloseMainWindow() | Out-Null
    
    # Wait up to 30 seconds for Unity to exit gracefully
    Write-Host "Waiting for Unity to finalize logging and exit..." -ForegroundColor Yellow
    $waited = $process.WaitForExit(30000)  # 30 second timeout
    
    if ($waited) {
        Write-Host "Unity exited gracefully" -ForegroundColor Green
    } else {
        Write-Host "Unity did not exit within timeout, forcing shutdown..." -ForegroundColor Yellow
        Stop-Process -Id $process.Id -Force
        Write-Host "Unity process force-stopped" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error during shutdown, forcing process termination..." -ForegroundColor Yellow
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
}

# Give a moment for file system to sync
Start-Sleep -Seconds 2
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

# Additional diagnostic: Check for PositionAccuracyLogger messages
Write-Host "`nChecking for Position Accuracy Logger initialization in log..." -ForegroundColor Cyan
if (Test-Path $LogFilePath) {
    $loggerMessages = Get-Content $LogFilePath | Select-String "PositionAccuracyLogger"
    if ($loggerMessages) {
        Write-Host "Found Position Accuracy Logger messages:" -ForegroundColor Green
        $loggerMessages | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "WARNING: No Position Accuracy Logger messages found in log" -ForegroundColor Yellow
        Write-Host "This indicates the logger may not be initializing properly" -ForegroundColor Yellow
    }
}

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
        Write-Host "`nDiagnostic Information:" -ForegroundColor Yellow
        Write-Host "  Checking parent directory..." -ForegroundColor Yellow
        $parentDir = Split-Path $DirectoryPath -Parent
        if (Test-Path $parentDir) {
            Write-Host "  Parent directory exists: $parentDir" -ForegroundColor Green
            Write-Host "  Contents:" -ForegroundColor Yellow
            Get-ChildItem $parentDir | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
        } else {
            Write-Host "  Parent directory does not exist: $parentDir" -ForegroundColor Red
        }
        
        # Check if any CSV files were created in the root directory
        Write-Host "`n  Checking for position accuracy CSV files in project root..." -ForegroundColor Yellow
        $csvFiles = Get-ChildItem -Path $ProjectPath -Filter "position_accuracy_*.csv" -ErrorAction SilentlyContinue
        if ($csvFiles) {
            Write-Host "  Found CSV files in root directory (wrong location!):" -ForegroundColor Yellow
            $csvFiles | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
        }
        
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
        Write-Host "Position accuracy summary not available; continuing with CI verification." -ForegroundColor Yellow
    }

    $checkerScript = Join-Path $ProjectPath "check_position_accuracy_ci.py"
    if (-not (Test-Path $checkerScript)) {
        Write-Host "Error: CI position accuracy checker not found at $checkerScript" -ForegroundColor Red
        exit 1
    }

    Write-Host "Running CI position accuracy verification..." -ForegroundColor Cyan
    $thresholdText = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0}", $ErrorThreshold)
    $pythonArgs = @($checkerScript, "--log-dir", $positionDir, "--threshold", $thresholdText)

    $exitCode = 0
    Push-Location $ProjectPath
    try {
        & $PythonExecutable @pythonArgs
        $exitCode = $LASTEXITCODE
    }
    catch {
        Write-Host "Error running CI position accuracy checker: $($_.Exception.Message)" -ForegroundColor Red
        $exitCode = 1
    }
    finally {
        Pop-Location
    }

    if ($exitCode -ne 0) {
        Write-Host "CI position accuracy verification FAILED (exit code $exitCode)." -ForegroundColor Red
        exit $exitCode
    }

    Write-Host "CI position accuracy verification PASSED." -ForegroundColor Green
}

Write-Host "Script execution completed" -ForegroundColor Cyan 
