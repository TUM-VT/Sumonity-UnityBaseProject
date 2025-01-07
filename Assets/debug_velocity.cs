using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;

public class DebugLogger : MonoBehaviour
{
    public Text debugText; // Reference to the UI Text element
    private Queue<string> logMessages = new Queue<string>(); // Queue to hold log messages
    public int maxMessages = 15; // Max number of messages to display

    void OnEnable()
    {
        // Register the HandleLog function as a callback to be called whenever the application logs a message
        Application.logMessageReceived += HandleLog;
    }

    void OnDisable()
    {
        // Unregister the callback when the script is disabled
        Application.logMessageReceived -= HandleLog;
    }

    void HandleLog(string logString, string stackTrace, LogType type)
    {
        // Only process log messages of type Log
        if (type == LogType.Log)
        {
            // Add the log message to the queue
            logMessages.Enqueue(logString);

            // If the queue exceeds the max messages, dequeue the oldest message
            if (logMessages.Count > maxMessages)
            {
                logMessages.Dequeue();
            }

            // Update the debug text to display the messages
            debugText.text = string.Join("\n", logMessages.ToArray());
        }
    }

    void Start()
    {
        if (debugText == null)
        {
            Debug.LogError("DebugLogger: No UI Text component assigned.");
        }
    }

    void Update()
    {
        // Toggle the debug text on and off when the Tab key is pressed
        if (Input.GetKeyDown(KeyCode.Tab))
        {
            debugText.enabled = !debugText.enabled;
        }
    }
}
