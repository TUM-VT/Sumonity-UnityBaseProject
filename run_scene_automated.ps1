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
    [double]$ErrorThreshold = 2.0
)

Write-Host "Starting Unity scene automation script..." -ForegroundColor Cyan

# Function to check for and clean up any existing Unity processes
function Cleanup-UnityProcesses {
    param(
        [bool]$Force = $false
    )
    
    Write-Host "Checking for existing Unity processes..." -ForegroundColor Yellow
    $ProjectPath = Resolve-Path "."
    $unityProcesses = Get-Process -Name "Unity" -ErrorAction SilentlyContinue
    
    if ($unityProcesses -and $unityProcesses.Count -gt 0) {
        Write-Host "Found $($unityProcesses.Count) running Unity process(es)" -ForegroundColor Yellow
        if ($Force) {
            Write-Host "Force cleaning up Unity processes..." -ForegroundColor Yellow
            foreach ($proc in $unityProcesses) {
                Stop-Process -Id $proc.Id -Force
            }
            
            # Clean up Temp directory
            $tempPath = Join-Path $ProjectPath "Temp"
            if (Test-Path $tempPath) {
                Write-Host "Cleaning up Temp directory..." -ForegroundColor Yellow
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            Start-Sleep -Seconds 2
        }
    } else {
        Write-Host "No existing Unity processes found" -ForegroundColor Green
    }
}

# Run cleanup check
Write-Host "Running initial cleanup check..." -ForegroundColor Cyan
Cleanup-UnityProcesses -Force $ForceCleanup

# Check if Unity path exists
Write-Host "Verifying Unity executable path..." -ForegroundColor Cyan
if (-not (Test-Path $UnityPath)) {
    Write-Host "Error: Unity executable not found at $UnityPath" -ForegroundColor Red
    exit 1
}
Write-Host "Unity executable found at $UnityPath" -ForegroundColor Green

# Get the absolute path to the Unity project
$ProjectPath = Resolve-Path "."
Write-Host "Project path: $ProjectPath" -ForegroundColor Cyan

# Additional cleanup - specifically target lock files
Write-Host "Checking for Unity lock files..." -ForegroundColor Cyan
$tempPath = Join-Path $ProjectPath "Temp"
$editorLockFile = Join-Path $tempPath "UnityLockfile"

if (Test-Path $editorLockFile) {
    Write-Host "Removing Unity lock file..." -ForegroundColor Yellow
    Remove-Item -Path $editorLockFile -Force -ErrorAction SilentlyContinue
}

# Run Unity in screen mode
Write-Host "Starting Unity process..." -ForegroundColor Cyan
$process = Start-Process -FilePath $UnityPath `
                         -ArgumentList "-projectPath", "`"$ProjectPath`"", "-logFile", "`"$LogFile`"", "-executeMethod", "AutomatedTesting.RunMainSceneTest" `
                         -PassThru

if ($null -eq $process) {
    Write-Host "Error: Failed to start Unity process." -ForegroundColor Red
    exit 1
}
Write-Host "Unity process started successfully (PID: $($process.Id))" -ForegroundColor Green

# Wait a few seconds to check if process is still running
Write-Host "Waiting for Unity process to initialize..." -ForegroundColor Cyan
Start-Sleep -Seconds 5
if ($process.HasExited) {
    Write-Host "Error: Unity process exited unexpectedly." -ForegroundColor Red
    exit 1
}
Write-Host "Unity process is running" -ForegroundColor Green

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
Analyze-LogFile -LogFilePath $LogFile

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