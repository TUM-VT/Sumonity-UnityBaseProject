@echo off
REM Quick test of the updated CI script
REM This runs a short 30-second test to verify everything works

echo ================================================
echo CI Script Test - Updated Position Accuracy System
echo ================================================
echo.
echo This will:
echo   1. Start Unity in batch mode
echo   2. Run simulation for 30 seconds
echo   3. Check for position accuracy statistics
echo   4. Verify average error is below 1.5 meters
echo.
echo Press Ctrl+C to cancel, or any key to continue...
pause >nul

echo.
echo Starting test run...
echo.
echo NOTE: Using -BypassInitCheck for faster testing
echo       Unity will wait 15 seconds then proceed
echo.

powershell -ExecutionPolicy Bypass -File run_scene_automated.ps1 -TimeToRun 30 -ErrorThreshold 1.5 -BypassInitCheck

echo.
echo ================================================
echo Test Complete
echo ================================================
echo.
echo Check the output above for:
echo   - "Position accuracy test PASSED" = Success
echo   - "Position accuracy test FAILED" = Accuracy below threshold
echo   - "INCONCLUSIVE" = No data found (logger may not be initialized)
echo.
pause
