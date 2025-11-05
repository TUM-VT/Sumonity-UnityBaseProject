/*
 * PositionAccuracyUI.cs - UI display for position tracking accuracy
 * 
 * Provides real-time on-screen display of position tracking statistics
 */

using UnityEngine;
using tum_car_controller;

public class PositionAccuracyUI : MonoBehaviour
{
    [Header("UI Settings")]
    [Tooltip("Enable on-screen statistics display")]
    public bool showUI = true;

    [Tooltip("UI position on screen")]
    public Vector2 uiPosition = new Vector2(10, 10);

    [Tooltip("Update frequency in seconds")]
    public float updateInterval = 0.5f;

    private float lastUpdateTime = 0f;
    private string cachedStatsString = "";

    void OnGUI()
    {
        if (!showUI) return;

        // Update cached string at specified interval
        if (Time.time - lastUpdateTime > updateInterval)
        {
            cachedStatsString = PositionAccuracyLogger.Instance.GetStatisticsString();
            lastUpdateTime = Time.time;
        }

        // Create GUI style
        GUIStyle style = new GUIStyle(GUI.skin.box);
        style.alignment = TextAnchor.UpperLeft;
        style.fontSize = 14;
        style.normal.textColor = Color.white;
        style.padding = new RectOffset(10, 10, 10, 10);

        // Display statistics
        string displayText = "=== Position Accuracy Logger ===\n" + cachedStatsString;
        
        Vector2 size = style.CalcSize(new GUIContent(displayText));
        GUI.Box(new Rect(uiPosition.x, uiPosition.y, size.x + 20, size.y + 20), displayText, style);
    }
}
