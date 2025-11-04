# Download Unity FBX files from GitLab
# This script clones the UnityFbx folder from the tum2twin-datasets repository
# into the Assets/3d_model directory

# Configuration
$REPO = "https://gitlab.lrz.de/tum-gis/tum2twin-datasets.git"
$BRANCH = "add-unity-fbx-files"
$REMOTE_FOLDER = "fbx/UnityFbx"
$TMP_DIR = "tmp_gitlab_clone"
$DEST_DIR = "Assets/3d_model"

# Get script directory (project root)
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $SCRIPT_DIR

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Unity FBX Download Script" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository: $REPO" -ForegroundColor Yellow
Write-Host "Branch: $BRANCH" -ForegroundColor Yellow
Write-Host "Remote folder: $REMOTE_FOLDER" -ForegroundColor Yellow
Write-Host "Destination: $DEST_DIR" -ForegroundColor Yellow
Write-Host ""

# Create destination directory if it doesn't exist
if (-Not (Test-Path $DEST_DIR)) {
    Write-Host "Creating destination directory: $DEST_DIR" -ForegroundColor Green
    New-Item -ItemType Directory -Path $DEST_DIR -Force | Out-Null
}

# Clean up any existing temporary clone
if (Test-Path $TMP_DIR) {
    Write-Host "Removing existing temporary clone directory..." -ForegroundColor Yellow
    Remove-Item -Path $TMP_DIR -Recurse -Force
}

# Clone repository with sparse checkout
Write-Host ""
Write-Host "Cloning repository (sparse, shallow)..." -ForegroundColor Green
try {
    # Initialize sparse clone
    git clone --depth 1 --filter=blob:none --sparse -b $BRANCH $REPO $TMP_DIR
    
    if ($LASTEXITCODE -ne 0) {
        throw "Git clone failed with exit code $LASTEXITCODE"
    }
    
    # Configure sparse checkout for specific folder
    Write-Host "Configuring sparse checkout for $REMOTE_FOLDER..." -ForegroundColor Green
    Push-Location $TMP_DIR
    git sparse-checkout init --cone
    git sparse-checkout set $REMOTE_FOLDER
    Pop-Location
    
    if ($LASTEXITCODE -ne 0) {
        throw "Sparse checkout configuration failed"
    }
    
    # Copy files to destination
    $SOURCE_PATH = Join-Path $TMP_DIR $REMOTE_FOLDER
    if (Test-Path $SOURCE_PATH) {
        Write-Host ""
        Write-Host "Copying files to $DEST_DIR..." -ForegroundColor Green
        
        # Copy all files and subdirectories
        Copy-Item -Path "$SOURCE_PATH\*" -Destination $DEST_DIR -Recurse -Force
        
        # Count copied files
        $fileCount = (Get-ChildItem -Path $DEST_DIR -Recurse -File | Measure-Object).Count
        Write-Host "Successfully copied $fileCount file(s)" -ForegroundColor Green
    }
    else {
        Write-Host "Warning: Source path not found: $SOURCE_PATH" -ForegroundColor Red
    }
    
    # Clean up temporary clone
    Write-Host ""
    Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
    Remove-Item -Path $TMP_DIR -Recurse -Force
    
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "Download complete!" -ForegroundColor Green
    Write-Host "Files are located in: $DEST_DIR" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Cyan
    
}
catch {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Red
    Write-Host "Error during download:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "======================================" -ForegroundColor Red
    
    # Clean up on error
    if (Test-Path $TMP_DIR) {
        Remove-Item -Path $TMP_DIR -Recurse -Force
    }
    
    exit 1
}
