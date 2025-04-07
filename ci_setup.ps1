# CI/CD compatible setup script for TUM Main Campus Unity Project

# Set execution policy
Set-ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue

# Check Python 3.11 installation
try {
    $pythonVersion = python --version
    if (-not ($pythonVersion -like "*3.11*")) {
        Write-Error "Python 3.11 is required. Current version: $pythonVersion"
        exit 1
    }
} catch {
    Write-Error "Python is not installed or not in PATH"
    exit 1
}

# Install vcstool2
Write-Output "Installing vcstool2..."
pip install vcstool2 --quiet

# Import submodules using vcs
Write-Output "Importing submodules..."
# Use Get-Content to properly handle the input file in PowerShell
Get-Content -Path "assets.repos" | vcs import

# Create Assets/3d_model directory if it doesn't exist
if (-not (Test-Path "Assets/3d_model")) {
    New-Item -ItemType Directory -Path "Assets/3d_model" -Force | Out-Null
}

# Download 3D model
Write-Output "Downloading 3D model..."
Invoke-WebRequest -Uri "https://gitlab.lrz.de/tum-gis/tum2twin-datasets/-/raw/0ec6f8d87cfe58ac03bdae2c690632c08fd3d625/fbx/tum_main_campus.fbx" -OutFile "Assets/3d_model/tum_main_campus.fbx"

# Setup Sumo Python environment
Write-Output "Setting up Sumo Python environment..."
Push-Location "Assets/Sumonity/SumoTraCI"

# Install virtualenv
pip install virtualenv --quiet

# Create virtual environment
python -m venv venv

# Use the activate script
$activateScript = ".\venv\Scripts\Activate.ps1"
. $activateScript

# Install requirements
pip install -r requirements.txt --quiet

# Return to original directory
Pop-Location

Write-Output "Setup completed successfully!" 