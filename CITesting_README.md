# Automated Testing for Unity Environment

This directory contains scripts for automatically testing the Unity environment by opening and running scenes.

## Setup

1. Ensure you have the proper files in place:
   - `Assets/Scripts/CITesting/AutomatedTesting.cs`: The Unity editor script for running tests
   - `run_scene_automated.ps1`: PowerShell script to launch Unity in batch mode

2. Make sure your Unity installation path is correct in the `run_scene_automated.ps1` script:
   ```powershell
   [string]$UnityPath = "C:\Program Files\Unity\Hub\Editor\2022.3.16f1\Editor\Unity.exe"
   ```
   Update this path if your Unity installation is in a different location.

## Running Tests

### Option 1: Using PowerShell Script (Automated)

1. Open PowerShell and navigate to the project root directory
2. Run the automation script:
   ```powershell
   .\run_scene_automated.ps1
   ```

   Optional parameters:
   - `-UnityPath`: Path to Unity executable
   - `-ScenePath`: Path to the scene you want to test (default: "Assets/Scenes/MainScene.unity")
   - `-LogFile`: Path to save the log output (default: "unity_test_run.log")
   - `-TimeToRun`: Seconds to run the scene before stopping (default: 60)

   Example with custom parameters:
   ```powershell
   .\run_scene_automated.ps1 -ScenePath "Assets/Scenes/OtherScene.unity" -TimeToRun 120
   ```

### Option 2: Using Unity Editor (Manual)

1. Open the Unity project
2. Go to `Tools > Automated Testing > Run Test on Current Scene` in the Unity editor menu
3. The scene will run and automatically collect performance data

## Understanding Test Results

After running tests, check:

1. `unity_test_run.log`: Contains Unity's output during the test
2. `automated_test_results.log`: Contains performance metrics collected during the test

## Custom Tests

To create custom tests, modify the `AutomatedTesting.cs` script to include additional metrics or testing logic.

## Continuous Integration

This testing system can be integrated into CI/CD pipelines. The PowerShell script is designed to run headlessly with the `-nographics` parameter.

Example workflow:
1. CI system checks out the repository
2. Runs `run_scene_automated.ps1`
3. Analyzes log files for performance metrics or errors
4. Reports results to the pipeline

## Troubleshooting

- **Unity Not Found**: Update the `$UnityPath` parameter to point to your Unity installation
- **Scene Not Found**: Make sure the scene path is correct
- **Editor Script Errors**: Check Unity Editor logs for compilation errors 