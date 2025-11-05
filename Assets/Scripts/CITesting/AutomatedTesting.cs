using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using System;
using tum_car_controller;

/// <summary>
/// Editor script for automated testing of Unity scenes
/// </summary>
public static class AutomatedTesting
{
    private const string LOG_TAG = "[AutomatedTesting]";
    
    // Simple static constructor to ensure we see when the class is loaded
    static AutomatedTesting()
    {
        Debug.LogError($"{LOG_TAG} Static constructor called");
    }
    
    /// <summary>
    /// Run automated test for a specific scene
    /// </summary>
    [MenuItem("Tools/Automated Testing/Run Test on Current Scene")]
    public static void RunTestOnCurrentScene()
    {
        Debug.LogError($"{LOG_TAG} Starting play mode directly");
        try
        {
            // Save the current scene
            EditorSceneManager.SaveOpenScenes();
            Debug.LogError($"{LOG_TAG} Saved current scene");
            
            // Simply enter play mode if not compiling
            if (!EditorApplication.isCompiling)
            {
                Debug.LogError($"{LOG_TAG} Entering play mode NOW");
            EditorApplication.isPlaying = true;
            }
            else
            {
                Debug.LogError($"{LOG_TAG} Unity is compiling, will wait before entering play mode");
                EditorApplication.update += WaitForCompilationAndEnterPlayMode;
            }
        }
        catch (Exception ex)
        {
            Debug.LogError($"{LOG_TAG} Error in RunTestOnCurrentScene: {ex.Message}\n{ex.StackTrace}");
        }
    }
    
    /// <summary>
    /// Run automated test on a specific scene by path
    /// </summary>
    public static void RunTestOnScene(string scenePath)
    {
        Debug.LogError($"{LOG_TAG} Opening scene: {scenePath}");
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
        Debug.LogError($"{LOG_TAG} Starting main scene test");
        
        // Ensure Position Accuracy Logger will be initialized when play mode starts
        EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
        
        RunTestOnScene("Assets/Scenes/MainScene.unity");
    }
    
    /// <summary>
    /// Called when play mode state changes
    /// </summary>
    private static void OnPlayModeStateChanged(PlayModeStateChange state)
    {
        if (state == PlayModeStateChange.EnteredPlayMode)
        {
            Debug.LogError($"{LOG_TAG} Entered play mode - ensuring Position Accuracy Logger is initialized");
            
            // Force initialization of the Position Accuracy Logger singleton
            try
            {
                var logger = PositionAccuracyLogger.Instance;
                if (logger != null)
                {
                    Debug.LogError($"{LOG_TAG} Position Accuracy Logger instance obtained successfully");
                }
                else
                {
                    Debug.LogError($"{LOG_TAG} WARNING: Position Accuracy Logger instance is null!");
                }
            }
            catch (Exception ex)
            {
                Debug.LogError($"{LOG_TAG} Error initializing Position Accuracy Logger: {ex.Message}");
            }
            
            // Unsubscribe after we're done
            EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
        }
    }
    
    // Method to wait for compilation to finish then enter play mode
    private static void WaitForCompilationAndEnterPlayMode()
    {
        if (!EditorApplication.isCompiling)
        {
            Debug.LogError($"{LOG_TAG} Compilation finished, now entering play mode");
            EditorApplication.update -= WaitForCompilationAndEnterPlayMode;
            EditorApplication.isPlaying = true;
        }
    }
} 