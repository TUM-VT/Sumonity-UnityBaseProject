# Automated setup script for TUM Main Campus Unity Project

# Ensure script is running with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator!"
    Break
}

# Set execution policy
Set-ExecutionPolicy Unrestricted -Force

# Function to check if a command exists
function Test-CommandExists {
    param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try { if (Get-Command $command) { return $true } }
    catch { return $false }
    finally { $ErrorActionPreference = $oldPreference }
}

# Install PowerShell modules if needed
if (Get-Module -ListAvailable -Name "powershell-yaml") {
    Write-Host "PowerShell YAML module is already installed"
} else {
    Write-Host "Installing PowerShell YAML module..."
    Install-Module -Name powershell-yaml -Force
}

# Import required modules
Import-Module powershell-yaml

# Check Python 3.11 installation
if (-not (Test-CommandExists python)) {
    Write-Host "Python 3.11 is not installed. Please install Python 3.11 from https://www.python.org/downloads/"
    Exit 1
}

$pythonVersion = python --version
if (-not ($pythonVersion -like "*3.11*")) {
    Write-Host "Python 3.11 is required. Current version: $pythonVersion"
    Exit 1
}

# Install vcstool2
Write-Host "Installing vcstool2..."
pip install vcstool2

# Importing submodules using vcs
Write-Host "Importing submodules..."
# Try multiple potential locations for vcs
$vcsCommand = $null

# First try: installed via pip command
try {
    $vcsPath = (python -m pip show vcstool2 -f | Select-String "Location:" | ForEach-Object { $_.ToString().Split("Location:")[1].Trim() }) + "\Scripts\vcs.exe"
    if (Test-Path $vcsPath) {
        $vcsCommand = $vcsPath
    }
} catch {
    Write-Host "Could not find vcs.exe in pip location"
}

# Use the vcs command if found, otherwise fall back to direct git clone
if ($vcsCommand) {
    Write-Host "Using vcs command at $vcsCommand"
    Get-Content -Path "assets.repos" | & $vcsCommand import
} else {
    Write-Host "Falling back to manual Git clone method using the assets.repos file..."
    
    try {
        # Read and parse the assets.repos file
        $reposContent = Get-Content -Path "assets.repos" -Raw
        $reposYaml = ConvertFrom-Yaml -Yaml $reposContent
        
        if ($null -eq $reposYaml -or $null -eq $reposYaml.repositories) {
            throw "Invalid YAML structure in assets.repos"
        }
        
        foreach ($repoPath in $reposYaml.repositories.Keys) {
            $repo = $reposYaml.repositories[$repoPath]
            $url = $repo.url
            $branch = $repo.version
            
            if (-not (Test-Path $repoPath)) {
                Write-Host "Cloning repository to $repoPath..."
                # Create the directory structure if it doesn't exist
                New-Item -ItemType Directory -Path (Split-Path -Parent $repoPath) -Force | Out-Null
                git clone -b $branch $url $repoPath
            } else {
                Write-Host "Directory $repoPath already exists, skipping..."
            }
        }
    } catch {
        Write-Host "Error parsing or using assets.repos file: $_"
        Write-Host "Using hardcoded repository information as fallback..."
        
        # Define repositories from assets.repos manually as fallback
        $repositories = @(
            @{
                path = "Assets/Sumonity"
                url = "https://github.com/TUM-VT/Sumonity.git"
                branch = "dev-version-2"
            },
            @{
                path = "Assets/BicycleModel"
                url = "https://github.com/TUM-VT/Sumonity-UnityModelTemplate.git"
                branch = "bicycle"
            },
            @{
                path = "Assets/CarModel"
                url = "https://github.com/TUM-VT/Sumonity-UnityModelTemplate.git" 
                branch = "car"
            },
            @{
                path = "Assets/BusModel"
                url = "https://github.com/TUM-VT/Sumonity-UnityModelTemplate.git"
                branch = "bus"
            },
            @{
                path = "Assets/TaxiModel"
                url = "https://github.com/TUM-VT/Sumonity-UnityModelTemplate.git"
                branch = "taxi"
            },
            @{
                path = "Assets/parkedvehiclespawner"
                url = "https://github.com/TUM-VT/Sumonity-ParkedVehicleSpawner.git"
                branch = "main"
            },
            @{
                path = "Assets/PedestrianModel"
                url = "https://github.com/TUM-VT/Sumonity-PedestrianModel.git"
                branch = "main"
            }
        )

        foreach ($repo in $repositories) {
            if (-not (Test-Path $repo.path)) {
                Write-Host "Cloning repository to $($repo.path)..."
                New-Item -ItemType Directory -Path $repo.path -Force | Out-Null
                git clone -b $repo.branch $repo.url $repo.path
            } else {
                Write-Host "Directory $($repo.path) already exists, skipping..."
            }
        }

        # Special case for nested repository
        if (Test-Path "Assets/Sumonity") {
            $sumoTraciPath = "Assets/Sumonity/SumoTraCI"
            if (-not (Test-Path $sumoTraciPath)) {
                New-Item -ItemType Directory -Path $sumoTraciPath -Force | Out-Null
            }
            
            $sumoProjectPath = "Assets/Sumonity/SumoTraCI/sumoProject"
            if (-not (Test-Path $sumoProjectPath)) {
                Write-Host "Cloning sumoProject repository..."
                git clone -b main https://github.com/TUM-VT/Sumonity-SumoProject.git $sumoProjectPath
            }
        }
    }
}

# Create Assets/3d_model directory if it doesn't exist
if (-not (Test-Path "Assets/3d_model")) {
    New-Item -ItemType Directory -Path "Assets/3d_model" -Force
}

# Download 3D model
Write-Host "Downloading 3D model..."
Invoke-WebRequest -Uri "https://gitlab.lrz.de/tum-gis/tum2twin-datasets/-/raw/0ec6f8d87cfe58ac03bdae2c690632c08fd3d625/fbx/tum_main_campus.fbx" -OutFile "Assets/3d_model/tum_main_campus.fbx"

# Setup Sumo Python environment
Write-Host "Setting up Sumo Python environment..."

# Check if Sumonity/SumoTraCI path exists after import
if (-not (Test-Path "Assets/Sumonity/SumoTraCI")) {
    Write-Host "Assets/Sumonity/SumoTraCI directory does not exist yet. This is expected if the vcstool import hasn't completed."
    Write-Host "You may need to run the setup script again after the repositories are cloned, or manually set up the Python environment."
    Exit 0
}

cd Assets/Sumonity/SumoTraCI

# Install virtualenv
pip install virtualenv

# Create and activate virtual environment
python -m venv venv
.\venv\Scripts\Activate

# Install requirements
pip install -r requirements.txt

Write-Host "Setup completed successfully!"
Write-Host "You can now open the project in Unity and run the 'Main Campus' scene."