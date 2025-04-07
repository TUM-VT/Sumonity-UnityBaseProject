using UnityEngine;
using UnityEditor;
using System.IO;
using System;
using System.Collections;
using UnityEngine.SceneManagement;
using UnityEditor.SceneManagement;

/// <summary>
/// Editor script for automated testing of Unity scenes
/// </summary>
public static class AutomatedTesting
{
    private static string logFilePath = "automated_test_results.log";
    private static System.Diagnostics.Stopwatch stopwatch = new System.Diagnostics.Stopwatch();
    
    /// <summary>
    /// Run automated test for a specific scene
    /// </summary>
    [MenuItem("Tools/Automated Testing/Run Test on Current Scene")]
    public static void RunTestOnCurrentScene()
    {
        Debug.Log("[AutomatedTesting] Starting automated test on current scene: " + EditorSceneManager.GetActiveScene().name);
        
        // Save the current scene first
        EditorSceneManager.SaveOpenScenes();
        
        // Add a log message before registering for state changes
        Debug.Log("[AutomatedTesting] Registering for PlayModeStateChanged events...");
        
        // Register for the play mode state change to perform testing
        EditorApplication.playModeStateChanged += TestPlayModeStateChanged;
        
        // Start the test by entering play mode
        Debug.Log("[AutomatedTesting] Entering play mode...");
        EditorApplication.isPlaying = true;
    }
    
    /// <summary>
    /// Run automated test on a specific scene by path
    /// </summary>
    public static void RunTestOnScene(string scenePath)
    {
        Debug.Log("[AutomatedTesting] Opening scene for testing: " + scenePath);
        
        // Open the specified scene
        EditorSceneManager.OpenScene(scenePath);
        
        // Run the test on the now-current scene
        RunTestOnCurrentScene();
    }
    
    /// <summary>
    /// Method that can be called via command line with -executeMethod
    /// </summary>
    public static void RunMainSceneTest()
    {
        Debug.Log("[AutomatedTesting] RunMainSceneTest called via command line");
        
        // If we're running in batch mode, generate fallback results just in case
        if (Application.isBatchMode)
        {
            Debug.Log("[AutomatedTesting] Running in batch mode, generating fallback results");
            GenerateFallbackTestResults("Batch mode direct results - Play mode may not work in batch mode");
        }
        else
        {
            Debug.Log("[AutomatedTesting] Running in screen mode, will visualize the testing");
        }
        
        // Run the test normally in either mode
        Debug.Log("[AutomatedTesting] Will now attempt normal testing process");
        RunTestOnScene("Assets/Scenes/MainScene.unity");
    }
    
    private static void TestPlayModeStateChanged(PlayModeStateChange state)
    {
        Debug.Log($"[AutomatedTesting] PlayMode state changed to: {state}");
        
        switch(state)
        {
            case PlayModeStateChange.EnteredPlayMode:
                // Play mode has started, initialize testing
                Debug.Log("[AutomatedTesting] Entered play mode, starting performance test...");
                stopwatch.Start();
                
                // Instead of using EditorCoroutineUtility, we'll use EditorApplication.update
                EditorApplication.update += MonitorPerformance;
                break;
                
            case PlayModeStateChange.ExitingPlayMode:
                // Test completed, record results
                Debug.Log("[AutomatedTesting] Exiting play mode, completing test...");
                stopwatch.Stop();
                
                // Make sure to unregister the update callback
                EditorApplication.update -= MonitorPerformance;
                
                // Log test summary
                Debug.Log($"[AutomatedTesting] Test completed. Total run time: {stopwatch.Elapsed.TotalSeconds:F2} seconds");
                LogTestResults();
                
                // Unregister the event to avoid multiple registrations
                EditorApplication.playModeStateChanged -= TestPlayModeStateChanged;
                break;
                
            case PlayModeStateChange.EnteredEditMode:
                Debug.Log("[AutomatedTesting] Entered edit mode after play mode.");
                break;
                
            case PlayModeStateChange.ExitingEditMode:
                Debug.Log("[AutomatedTesting] Exiting edit mode to enter play mode.");
                break;
        }
    }
    
    // Performance monitoring variables
    private static float startTime = 0;
    private static int frameCount = 0;
    private static float totalFrameTime = 0;
    private static float minFps = float.MaxValue;
    private static float maxFps = 0;
    private static bool monitoringStarted = false;
    private static float lastUpdateTime = 0;
    
    private static void MonitorPerformance()
    {
        if (!EditorApplication.isPlaying)
        {
            Debug.Log("[AutomatedTesting] MonitorPerformance called, but not in play mode. This shouldn't happen.");
            return;
        }
        
        // Initialize monitoring if not started
        if (!monitoringStarted)
        {
            startTime = Time.realtimeSinceStartup;
            frameCount = 0;
            totalFrameTime = 0;
            minFps = float.MaxValue;
            maxFps = 0;
            monitoringStarted = true;
            lastUpdateTime = startTime;
            Debug.Log("[AutomatedTesting] Performance monitoring started");
            return;
        }
        
        // Skip a few frames to let things stabilize if needed
        if (frameCount < 10)
        {
            frameCount++;
            return;
        }
        
        // Calculate frame time
        float currentTime = Time.realtimeSinceStartup;
        float deltaTime = currentTime - lastUpdateTime;
        lastUpdateTime = currentTime;
        
        // Only update stats every few frames to reduce overhead
        if (frameCount % 5 == 0)
        {
            frameCount++;
            totalFrameTime += deltaTime;
            
            float currentFps = 1.0f / Mathf.Max(deltaTime, 0.0001f);
            minFps = Mathf.Min(minFps, currentFps);
            maxFps = Mathf.Max(maxFps, currentFps);
            
            // Log the current frame stats periodically
            if (frameCount % 30 == 0)
            {
                Debug.Log($"[AutomatedTesting] Frame {frameCount}: FPS = {currentFps:F1}, Memory = {(SystemInfo.systemMemorySize / 1024.0f):F1} GB");
            }
        }
        else
        {
            frameCount++;
        }
        
        // Check if we've monitored for long enough (10 seconds)
        if (currentTime - startTime > 10)
        {
            // Log performance results
            float avgFps = frameCount / Mathf.Max(totalFrameTime, 0.001f);
            Debug.Log($"[AutomatedTesting] Performance Test Results:");
            Debug.Log($"[AutomatedTesting] - Average FPS: {avgFps:F1}");
            Debug.Log($"[AutomatedTesting] - Min FPS: {minFps:F1}");
            Debug.Log($"[AutomatedTesting] - Max FPS: {maxFps:F1}");
            Debug.Log($"[AutomatedTesting] - Frames analyzed: {frameCount}");
            
            // Try writing results file directly here as a backup
            string results = $"=== AUTOMATED TEST RESULTS (FROM MONITOR) ===\n" +
                             $"Date: {DateTime.Now}\n" +
                             $"Scene: {SceneManager.GetActiveScene().name}\n" +
                             $"Test duration: {(currentTime - startTime):F2} seconds\n" +
                             $"Performance: Avg FPS = {avgFps:F1}, Min FPS = {minFps:F1}, Max FPS = {maxFps:F1}\n" +
                             $"System: {SystemInfo.operatingSystem}, {SystemInfo.processorType}, {SystemInfo.graphicsDeviceName}\n" +
                             $"============================================";
                             
            Debug.Log(results);
            
            try {
                // Also write to a file - make sure this works in batch mode
                string filePath = Path.Combine(Application.dataPath, "..", "automated_test_results_monitor.log");
                File.AppendAllText(filePath, results + "\n\n");
                Debug.Log($"[AutomatedTesting] Test results written to {filePath} from monitor");
            }
            catch (Exception ex) {
                Debug.LogError($"[AutomatedTesting] Failed to write results from monitor: {ex.Message}");
            }
            
            // Unregister to stop monitoring
            EditorApplication.update -= MonitorPerformance;
            monitoringStarted = false;
            
            // Log that we're attempting to exit play mode
            Debug.Log("[AutomatedTesting] Test complete. Attempting to exit play mode...");
            
            // Check if we need to automatically exit play mode after the test
            if (EditorApplication.isPlaying)
            {
                // Try registering a delayed callback to ensure this is processed
                EditorApplication.delayCall += () => {
                    Debug.Log("[AutomatedTesting] Delayed call executed to exit play mode");
                    EditorApplication.isPlaying = false;
                };
                
                // Also try the direct approach as a backup
                Debug.Log("[AutomatedTesting] Setting EditorApplication.isPlaying = false");
                EditorApplication.isPlaying = false;
            }
        }
    }
    
    private static void LogTestResults()
    {
        Debug.Log("[AutomatedTesting] LogTestResults() called - starting to log results");
        
        try
        {
            string results = $"=== AUTOMATED TEST RESULTS ===\n" +
                             $"Date: {DateTime.Now}\n" +
                             $"Scene: {SceneManager.GetActiveScene().name}\n" +
                             $"Test duration: {stopwatch.Elapsed.TotalSeconds:F2} seconds\n" +
                             $"System: {SystemInfo.operatingSystem}, {SystemInfo.processorType}, {SystemInfo.graphicsDeviceName}\n" +
                             $"============================================";
                             
            Debug.Log("[AutomatedTesting] Results formatted: " + results);
            
            // Get the actual path for logging purposes
            string directoryPath = Path.Combine(Application.dataPath, "..");
            string filePath = Path.Combine(directoryPath, logFilePath);
            Debug.Log($"[AutomatedTesting] Writing results to file: {filePath}");
            
            // Check if directory exists and is writable
            Debug.Log($"[AutomatedTesting] Directory exists: {Directory.Exists(directoryPath)}, Is writable: {IsDirectoryWritable(directoryPath)}");
            
            // Write to file with exception handling
            try
            {
                File.AppendAllText(filePath, results + "\n\n");
                Debug.Log($"[AutomatedTesting] Test results successfully written to {filePath}");
            }
            catch (Exception ex)
            {
                Debug.LogError($"[AutomatedTesting] Failed to write to file {filePath}: {ex.Message}");
                
                // Try an alternative location - maybe the project root is read-only
                string altFilePath = Path.Combine(Application.temporaryCachePath, "automated_test_results_fallback.log");
                try
                {
                    File.AppendAllText(altFilePath, results + "\n\n");
                    Debug.Log($"[AutomatedTesting] Test results written to alternate location: {altFilePath}");
                }
                catch (Exception altEx)
                {
                    Debug.LogError($"[AutomatedTesting] Failed to write to alternate location: {altEx.Message}");
                }
            }
        }
        catch (Exception ex)
        {
            Debug.LogError($"[AutomatedTesting] Error in LogTestResults: {ex.Message}");
            Debug.LogError($"[AutomatedTesting] Stack trace: {ex.StackTrace}");
        }
    }

    // Helper method to check if a directory is writable
    private static bool IsDirectoryWritable(string dirPath)
    {
        try
        {
            using (FileStream fs = File.Create(
                Path.Combine(dirPath, Path.GetRandomFileName()), 
                1, 
                FileOptions.DeleteOnClose))
            {
                // If we can create and write to a file, the directory is writable
                return true;
            }
        }
        catch
        {
            return false;
        }
    }

    // Method to generate fallback test results when play mode doesn't work in batch mode
    private static void GenerateFallbackTestResults(string reason)
    {
        Debug.Log($"[AutomatedTesting] Generating fallback test results: {reason}");
        
        try
        {
            // Collect system information
            string sceneInfo = "Unknown Scene";
            try { sceneInfo = EditorSceneManager.GetActiveScene().name; } catch { /* ignore errors */ }
            
            string gpuInfo = "Unknown GPU";
            try { gpuInfo = SystemInfo.graphicsDeviceName; } catch { /* ignore errors */ }
            
            string processorInfo = "Unknown CPU";
            try { processorInfo = SystemInfo.processorType; } catch { /* ignore errors */ }
            
            string osInfo = "Unknown OS";
            try { osInfo = SystemInfo.operatingSystem; } catch { /* ignore errors */ }
            
            // Create the results text
            string results = $"=== AUTOMATED TEST RESULTS (FALLBACK) ===\n" +
                            $"Date: {DateTime.Now}\n" +
                            $"Scene: {sceneInfo}\n" +
                            $"Note: Full test not run - {reason}\n" +
                            $"System: {osInfo}, {processorInfo}, {gpuInfo}\n" +
                            $"Unity Version: {Application.unityVersion}\n" +
                            $"============================================";
                            
            Debug.Log(results);
            
            // Try multiple locations to ensure we get results somewhere
            string[] possiblePaths = new string[] {
                Path.Combine(Application.dataPath, "..", logFilePath),
                Path.Combine(Application.dataPath, logFilePath),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), logFilePath),
                Path.Combine(Path.GetTempPath(), logFilePath)
            };
            
            bool savedSuccessfully = false;
            
            foreach (string path in possiblePaths)
            {
                try {
                    File.AppendAllText(path, results + "\n\n");
                    Debug.Log($"[AutomatedTesting] Fallback test results written to {path}");
                    savedSuccessfully = true;
                    break; // Stop trying after successful save
                }
                catch (Exception ex) {
                    Debug.LogWarning($"[AutomatedTesting] Failed to write to {path}: {ex.Message}");
                    // Continue to next path
                }
            }
            
            if (!savedSuccessfully)
            {
                Debug.LogError("[AutomatedTesting] Failed to write results to any location. Dumping to log:");
                Debug.LogError(results);
            }
        }
        catch (Exception ex)
        {
            Debug.LogError($"[AutomatedTesting] Critical error in fallback results: {ex.Message}");
            Debug.LogError($"[AutomatedTesting] Stack trace: {ex.StackTrace}");
        }
    }
} 