using UnityEngine;
using tum_car_controller;

/// <summary>
/// Simple runtime script to force Position Accuracy Logger initialization
/// This ensures the logger starts even in batch mode where Editor API doesn't work
/// </summary>
public class ForceLoggerInit : MonoBehaviour
{
    void Start()
    {
        Debug.Log("[ForceLoggerInit] Force-initializing Position Accuracy Logger...");
        
        try
        {
            // Access the singleton to trigger initialization
            var logger = PositionAccuracyLogger.Instance;
            
            if (logger != null)
            {
                Debug.Log("[ForceLoggerInit] Position Accuracy Logger accessed successfully");
                Debug.Log($"[ForceLoggerInit] Logger enabled: {logger.enableLogging}");
            }
            else
            {
                Debug.LogError("[ForceLoggerInit] Position Accuracy Logger instance is null!");
            }
        }
        catch (System.Exception ex)
        {
            Debug.LogError($"[ForceLoggerInit] Error accessing logger: {ex.Message}\n{ex.StackTrace}");
        }
    }
}
