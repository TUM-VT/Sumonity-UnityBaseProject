/*
 * PositionAccuracyExample.cs - Example usage of the Position Accuracy Logger
 * 
 * This script demonstrates how to:
 * - Control the logger at runtime
 * - Export data programmatically
 * - Access statistics
 */

using UnityEngine;
using tum_car_controller;

public class PositionAccuracyExample : MonoBehaviour
{
    [Header("Example Controls")]
    [Tooltip("Press to export CSV backup")]
    public KeyCode exportKey = KeyCode.E;

    [Tooltip("Press to export statistics summary")]
    public KeyCode statsKey = KeyCode.S;

    [Tooltip("Press to clear all logs")]
    public KeyCode clearKey = KeyCode.C;

    [Tooltip("Press to toggle logging on/off")]
    public KeyCode toggleKey = KeyCode.L;

    [Header("Auto Export")]
    [Tooltip("Automatically export logs every N seconds (0 = disabled)")]
    public float autoExportInterval = 60f;

    private float lastAutoExport = 0f;

    void Start()
    {
        // Example: Configure logger at runtime
        ConfigureLogger();

        // Example: Display logger info
        Debug.Log("[PositionAccuracyExample] Logger initialized and configured.");
    }

    void Update()
    {
        // Handle keyboard shortcuts
        HandleKeyboardInput();

        // Handle auto-export
        HandleAutoExport();

        // Example: Log statistics periodically
        if (Time.frameCount % 300 == 0) // Every ~5 seconds at 60 FPS
        {
            LogCurrentStatistics();
        }
    }

    /// <summary>
    /// Configure the logger with desired settings
    /// </summary>
    private void ConfigureLogger()
    {
        var logger = PositionAccuracyLogger.Instance;

        // Enable logging
        logger.enableLogging = true;

        // Set log interval (0.1 seconds = 10 Hz sampling)
        logger.logInterval = 0.1f;

        // Set output directory
        logger.outputDirectory = "Logs/PositionAccuracy";

        // Set auto-save threshold
        logger.autoSaveThreshold = 1000;

        Debug.Log("[PositionAccuracyExample] Logger configured.");
    }

    /// <summary>
    /// Handle keyboard shortcuts for manual control
    /// </summary>
    private void HandleKeyboardInput()
    {
        // Export CSV backup
        if (Input.GetKeyDown(exportKey))
        {
            Debug.Log("[PositionAccuracyExample] Exporting CSV backup...");
            PositionAccuracyLogger.Instance.ExportToCSV();
        }

        // Export statistics summary
        if (Input.GetKeyDown(statsKey))
        {
            Debug.Log("[PositionAccuracyExample] Exporting statistics summary...");
            PositionAccuracyLogger.Instance.ExportStatisticsSummary();
        }

        // Clear logs
        if (Input.GetKeyDown(clearKey))
        {
            Debug.Log("[PositionAccuracyExample] Clearing all logs...");
            PositionAccuracyLogger.Instance.ClearLogs();
        }

        // Toggle logging
        if (Input.GetKeyDown(toggleKey))
        {
            PositionAccuracyLogger.Instance.enableLogging = 
                !PositionAccuracyLogger.Instance.enableLogging;
            Debug.Log($"[PositionAccuracyExample] Logging {(PositionAccuracyLogger.Instance.enableLogging ? "enabled" : "disabled")}");
        }
    }

    /// <summary>
    /// Handle automatic export at intervals
    /// </summary>
    private void HandleAutoExport()
    {
        if (autoExportInterval <= 0) return;

        if (Time.time - lastAutoExport >= autoExportInterval)
        {
            Debug.Log("[PositionAccuracyExample] Auto-exporting statistics...");
            PositionAccuracyLogger.Instance.ExportStatisticsSummary();
            lastAutoExport = Time.time;
        }
    }

    /// <summary>
    /// Log current statistics to console
    /// </summary>
    private void LogCurrentStatistics()
    {
        string stats = PositionAccuracyLogger.Instance.GetStatisticsString();
        Debug.Log($"[PositionAccuracyExample] {stats}");
    }

    /// <summary>
    /// Example: Custom analysis of logged data
    /// </summary>
    public void AnalyzeSpecificVehicle(string vehicleId)
    {
        // In a real implementation, you would access the logger's internal data
        // For now, this is a placeholder showing the concept
        Debug.Log($"[PositionAccuracyExample] Analyzing vehicle: {vehicleId}");
        
        // Example: You could export data and then analyze it
        PositionAccuracyLogger.Instance.ExportToCSV();
        Debug.Log("[PositionAccuracyExample] Data exported for analysis.");
    }

    void OnGUI()
    {
        // Display keyboard shortcuts
        GUIStyle style = new GUIStyle(GUI.skin.box);
        style.alignment = TextAnchor.UpperLeft;
        style.fontSize = 12;
        style.normal.textColor = Color.yellow;
        style.padding = new RectOffset(10, 10, 10, 10);

        string helpText = "=== Position Accuracy Logger Controls ===\n" +
                         $"[{exportKey}] Export CSV Backup\n" +
                         $"[{statsKey}] Export Statistics Summary\n" +
                         $"[{clearKey}] Clear All Logs\n" +
                         $"[{toggleKey}] Toggle Logging On/Off\n" +
                         $"Auto-Export: {(autoExportInterval > 0 ? $"Every {autoExportInterval}s" : "Disabled")}";

        Vector2 size = style.CalcSize(new GUIContent(helpText));
        GUI.Box(new Rect(10, Screen.height - size.y - 30, size.x + 20, size.y + 20), 
                helpText, style);
    }

    void OnApplicationQuit()
    {
        // Example: Final export when application closes
        Debug.Log("[PositionAccuracyExample] Application quitting - exporting final data...");
        PositionAccuracyLogger.Instance.ExportStatisticsSummary();
    }
}
