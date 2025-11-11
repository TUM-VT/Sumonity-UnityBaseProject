# Automation Scripts for TUM Main Campus Unity Project

This directory contains scripts to automate the setup process for the TUM Main Campus Unity Project.

## Available Scripts

### setup.bat
A Windows batch file that:
- Requests administrator privileges (required for some operations)
- Runs the PowerShell setup script with proper execution policy
- Suitable for manual installation on a development machine

Usage:
```
setup.bat
```

### setup.ps1
The main PowerShell setup script for developer workstations that:
- Verifies Python 3.11 installation
- Installs vcstool2
- Imports submodules using vcs
- Downloads the required 3D model
- Sets up the Sumo Python environment
- Provides detailed feedback and halts on errors

Usage (if running directly):
```
PowerShell -ExecutionPolicy Bypass -File setup.ps1
```

### ci_setup.ps1
A CI/CD compatible PowerShell script that:
- Runs non-interactively
- Has minimal output suitable for CI/CD environments
- Uses error codes for pipeline integration
- Avoids prompts and user interaction
- Safely handles paths and directory changes

Usage in CI/CD environments:
```
PowerShell -ExecutionPolicy Bypass -File ci_setup.ps1
```

### run_unity_ci_simulation.bat
Runs the Unity editor in batch mode to execute the CI simulation entry point. Accepts optional arguments to pick a scene and control run duration. Requires the `UNITY_PATH` environment variable or the `-unityPath` argument to point at your Unity executable (e.g. `C:\Program Files\Unity\Hub\Editor\2022.3.20f1\Editor\Unity.exe`).

Usage examples:
```
:: Common case with environment variable
set UNITY_PATH="C:\Program Files\Unity\Hub\Editor\2022.3.20f1\Editor\Unity.exe"
run_unity_ci_simulation.bat -scenePath Assets/Scenes/MainScene.unity -simulationSeconds 60

:: Override editor path per call
run_unity_ci_simulation.bat -unityPath "D:\Unity\Editor\Unity.exe" -scenePath Assets/Scenes/MainScene.unity -timeoutSeconds 600

:: Observe the run in the editor UI
run_unity_ci_simulation.bat -withGui -simulationSeconds 30

:: Override accuracy threshold and Python interpreter
run_unity_ci_simulation.bat -simulationSeconds 30 --threshold 1.2 --python "C:\\Python311\\python.exe"

:: Skip the post-run accuracy validation phase
run_unity_ci_simulation.bat --skipAccuracy
```

Unity CLI arguments are forwarded, so additional flags (such as `-buildTarget`) can be appended after the known options. The script already issues an orderly shutdown via the CI entry point, so you normally do **not** need to add `-quit`.

After Unity exits successfully the batch file launches `check_position_accuracy_ci.py` (unless `--skipAccuracy` is specified). The analyzer prints per-vehicle mean position errors and turns the overall exit code non-zero when any vehicle exceeds the configured threshold.

### check_position_accuracy_ci.py
Parses the newest summary text under `Logs/PositionAccuracy` (files named `statistics_summary_*.txt`) and falls back to CSV logs if no summary is found. It checks the mean `PositionError` for each vehicle and returns a non-zero exit code when any vehicle exceeds the target threshold (default `1.5 m`).

Usage examples:
```
python check_position_accuracy_ci.py
python check_position_accuracy_ci.py --threshold 1.0
python check_position_accuracy_ci.py --log-file Logs/PositionAccuracy/position_accuracy_2025-11-11_13-46-28.csv --threshold 1.25
python check_position_accuracy_ci.py --log-file Logs/PositionAccuracy/statistics_summary_2025-11-11_14-03-39.txt
```

Integrate this into CI after the simulation step so pipelines fail automatically when average positional accuracy drifts above the agreed limit.

## Requirements

- Windows 10/11
- PowerShell 5.1 or higher
- Administrator privileges (for the setup.bat and setup.ps1 scripts)
- Python 3.11 (must be installed before running the scripts)
- Git and Git Bash (must be installed before running the scripts)

## Notes for CI/CD Integration

When integrating with CI/CD systems:
1. Ensure the runner has Python 3.11 installed
2. Use the ci_setup.ps1 script
3. Check the exit code to determine success/failure
4. Artifacts should include the complete Unity project directory

Example Azure DevOps pipeline step:
```yaml
- task: PowerShell@2
  inputs:
    filePath: '$(Build.SourcesDirectory)/ci_setup.ps1'
    failOnStderr: true
  displayName: 'Setup TUM Main Campus Unity Project'
``` 