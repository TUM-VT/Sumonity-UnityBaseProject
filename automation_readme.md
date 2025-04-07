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