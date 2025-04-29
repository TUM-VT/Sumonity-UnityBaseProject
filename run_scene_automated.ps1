# Automated script to open and run a Unity scene in batch mode
param (
    [string]$UnityPath = "C:\Program Files\Unity\Hub\Editor\2022.3.8f1\Editor\Unity.exe",
    [string]$ScenePath = "Assets/Scenes/MainScene.unity",
    [string]$LogFile = "unity_test_run.log",
    [int]$TimeToRun = 60,
    [switch]$ForceCleanup = $true,
    [switch]$ScreenMode = $false,
    [switch]$VehiclePositionComparison = $true,
    [string]$PositionComparisonFile = "vehicle_position_comparison.csv",
    [double]$ErrorThreshold = 2.0,
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
            $global:logFileWarningDisplayed = $true
        }
        return $false
    }
    
    $logContent = Get-Content $LogFilePath -Tail 100
    $initializationComplete = $false
    $sceneLoaded = $false
    $errorsFound = $false
    
    # Check for initialization sequence
    foreach ($line in $logContent) {
        if ($line -match "Initialize engine version") {
            $initializationComplete = $true
        }
        if ($line -match "Loading scene") {
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
    
    # Check for specific Unity ready indicators
    $readyIndicators = @(
        "Unity Editor is ready",
        "Scene loaded successfully",
        "All packages loaded",
        "Project loaded successfully",
        "Initialization complete",
        "Loaded scene",
        "Scene has been loaded",
        "Successfully loaded",
        "Started playing",
        "Scene is active",
        "Play mode started"
    )
    
    $readyCount = 0
    $foundIndicators = @()
    foreach ($indicator in $readyIndicators) {
        if ($logContent -match $indicator) {
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
        Write-Host "Found initialization indicators: $($foundIndicators -join ', ')" -ForegroundColor Green
        $global:initializationMessageDisplayed = $true
    }
    
    # Return true if we have either:
    # 1. Both initialization and scene loading complete, and no critical errors, OR
    # 2. At least 1 ready indicator is found
    return (($initializationComplete -and $sceneLoaded -and -not $errorsFound) -or $readyCount -ge 1)
}

# Function to wait for Unity to fully initialize
function Wait-ForUnityInitialization {
    param (
        [string]$LogFilePath,
        [int]$TimeoutSeconds = 900  # 15 minutes timeout
    )
    
    Write-Host "Waiting for Unity to fully initialize..." -ForegroundColor Cyan
    $startTime = Get-Date
    $timeout = $startTime.AddSeconds($TimeoutSeconds)
    $lastProgressDisplay = Get-Date
    $progressInterval = 10  # Show progress every 10 seconds
    
    # Reset global variables
    $global:logFileWarningDisplayed = $false
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
    $initialized = $true
} else {
    $initialized = Wait-ForUnityInitialization -LogFilePath $LogFilePath
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

# Function to evaluate position comparison data
function Evaluate-PositionComparisonData {
    param (
        [string]$FilePath,
        [double]$Threshold
    )
    
    Write-Host "Evaluating vehicle position comparison data..." -ForegroundColor Cyan
    if (Test-Path $FilePath) {
        try {
            $data = Import-Csv -Path $FilePath
            $avgErrorCol = $data | Where-Object { $_.PSObject.Properties.Name -contains "AverageError" }
            
            if ($avgErrorCol) {
                # Find the AverageError value - could be in different formats depending on CSV structure
                $avgError = $null
                if ($data[-1].AverageError) {
                    # If AverageError is a direct column
                    $avgError = [double]$data[-1].AverageError
                } elseif ($data.AverageError) {
                    # If CSV has just one row with stats
                    $avgError = [double]$data.AverageError
                }
                
                if ($null -ne $avgError) {
                    Write-Host "Average position error: $avgError meters" -ForegroundColor Cyan
                    
                    # Check for individual passenger vehicles exceeding the threshold
                    $passengersOverThreshold = $data | Where-Object { 
                        $_.VehicleType -like "*passenger*" -and 
                        [double]($_.AverageError -replace ',', '.') -gt $Threshold 
                    }
                    
                    if ($passengersOverThreshold -and $passengersOverThreshold.Count -gt 0) {
                        Write-Host "ERROR: Found $($passengersOverThreshold.Count) passenger vehicle(s) with average error exceeding threshold of $Threshold meters" -ForegroundColor Red
                        foreach ($vehicle in $passengersOverThreshold) {
                            Write-Host "  - Vehicle $($vehicle.VehicleID): Average error = $($vehicle.AverageError) meters" -ForegroundColor Red
                        }
                        return $false
                    }
                    
                    if ($avgError -gt $Threshold) {
                        Write-Host "ERROR: Average position error ($avgError m) exceeds threshold of $Threshold meters" -ForegroundColor Red
                        return $false
                    } else {
                        Write-Host "Position accuracy is within acceptable limits" -ForegroundColor Green
                        return $true
                    }
                } else {
                    Write-Host "Could not find AverageError value in the CSV file" -ForegroundColor Yellow
                    return $null
                }
            } else {
                Write-Host "AverageError column not found in the position comparison data" -ForegroundColor Yellow
                return $null
            }
        }
        catch {
            Write-Host "Error parsing position comparison data: $_" -ForegroundColor Red
            return $null
        }
    } else {
        Write-Host "Position comparison file not found at $FilePath" -ForegroundColor Yellow
        return $null
    }
}

# Check for vehicle position comparison results
if ($VehiclePositionComparison) {
    Write-Host "Checking for vehicle position comparison results..." -ForegroundColor Cyan
    $positionFile = Join-Path $ProjectPath $PositionComparisonFile
    if (Test-Path $positionFile) {
        Write-Host "Vehicle position comparison data saved to $positionFile" -ForegroundColor Green
        
        # Evaluate the position data
        $evalResult = Evaluate-PositionComparisonData -FilePath $positionFile -Threshold $ErrorThreshold
        
        if ($evalResult -eq $false) {
            Write-Host "Position comparison test FAILED" -ForegroundColor Red
            exit 1  # Exit with error code for pipeline integration
        } elseif ($evalResult -eq $true) {
            Write-Host "Position comparison test PASSED" -ForegroundColor Green
        } else {
            Write-Host "Position comparison test INCONCLUSIVE" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No vehicle position comparison data found" -ForegroundColor Red
        Write-Host "Position comparison test FAILED - No data available" -ForegroundColor Red
        exit 1  # Exit with error code for pipeline integration
    }
}

Write-Host "Script execution completed" -ForegroundColor Cyan 