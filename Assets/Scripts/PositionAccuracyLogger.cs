/*
 * PositionAccuracyLogger.cs - Position tracking accuracy logging system
 * 
 * Logs the accuracy of vehicle position tracking by comparing:
 * - Unity physics-simulated positions vs SUMO ground truth positions
 * - Outputs CSV files with timestamped position errors for analysis
 */

using UnityEngine;
using System.Collections.Generic;
using System.IO;
using System;
using tumvt.sumounity;

namespace tum_car_controller
{
    /// <summary>
    /// Stores position accuracy data for a single vehicle at a specific timestamp
    /// </summary>
    [System.Serializable]
    public class PositionAccuracyEntry
    {
        public float timestamp;           // Simulation time
        public string vehicleId;          // SUMO vehicle ID
        public Vector3 unityPosition;     // Unity simulated position
        public Vector3 sumoPosition;      // SUMO ground truth position
        public float positionError;       // Euclidean distance error
        public float lateralError;        // Cross-track error (X axis)
        public float longitudinalError;   // Along-track error (Z axis)
        public float speed;               // Current vehicle speed
        public float steeringAngle;       // Current steering angle

        public PositionAccuracyEntry(float time, string id, Vector3 unityPos, Vector3 sumoPos, float speed, float steering)
        {
            timestamp = time;
            vehicleId = id;
            unityPosition = unityPos;
            sumoPosition = sumoPos;
            this.speed = speed;
            this.steeringAngle = steering;

            // Calculate errors
            Vector3 errorVector = unityPos - sumoPos;
            positionError = errorVector.magnitude;
            lateralError = errorVector.x;
            longitudinalError = errorVector.z;
        }

        /// <summary>
        /// Converts entry to CSV row format
        /// </summary>
        public string ToCSV()
        {
            return $"{timestamp:F4},{vehicleId}," +
                   $"{unityPosition.x:F4},{unityPosition.y:F4},{unityPosition.z:F4}," +
                   $"{sumoPosition.x:F4},{sumoPosition.y:F4},{sumoPosition.z:F4}," +
                   $"{positionError:F4},{lateralError:F4},{longitudinalError:F4}," +
                   $"{speed:F4},{steeringAngle:F4}";
        }
    }

    /// <summary>
    /// Manages position accuracy logging for all vehicles during simulation
    /// </summary>
    public class PositionAccuracyLogger : MonoBehaviour
    {
        private static PositionAccuracyLogger _instance;
        public static PositionAccuracyLogger Instance
        {
            get
            {
                if (_instance == null)
                {
                    GameObject go = new GameObject("PositionAccuracyLogger");
                    _instance = go.AddComponent<PositionAccuracyLogger>();
                    DontDestroyOnLoad(go);
                }
                return _instance;
            }
        }

        [Header("Logging Settings")]
        [Tooltip("Enable position accuracy logging")]
        public bool enableLogging = true;

        [Tooltip("Log interval in seconds (0 = every frame)")]
        public float logInterval = 0.1f;

        [Tooltip("Output directory for log files (relative to project root)")]
        public string outputDirectory = "Logs/PositionAccuracy";

        [Tooltip("Maximum entries before auto-save")]
        public int autoSaveThreshold = 1000;

        [Header("Statistics")]
        [SerializeField] private int totalEntriesLogged = 0;
        [SerializeField] private int activeVehicles = 0;
        [SerializeField] private float averagePositionError = 0f;
        [SerializeField] private float maxPositionError = 0f;

        // Internal data structures
        private Dictionary<string, List<PositionAccuracyEntry>> vehicleLogs = new Dictionary<string, List<PositionAccuracyEntry>>();
        private Dictionary<string, float> lastLogTime = new Dictionary<string, float>();
        private string currentLogFileName;
        private StreamWriter liveLogWriter;
        private bool isInitialized = false;

        void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            _instance = this;
            DontDestroyOnLoad(gameObject);
        }

        void Start()
        {
            InitializeLogging();
        }

        void OnApplicationQuit()
        {
            FinalizeLogging();
        }

        /// <summary>
        /// Initialize logging system and create output directory
        /// </summary>
        private void InitializeLogging()
        {
            if (!enableLogging || isInitialized) return;

            try
            {
                // Create output directory if it doesn't exist
                string fullPath = Path.Combine(Application.dataPath, "..", outputDirectory);
                Directory.CreateDirectory(fullPath);

                // Create timestamped log file
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
                currentLogFileName = Path.Combine(fullPath, $"position_accuracy_{timestamp}.csv");

                // Initialize live log writer for continuous writing
                liveLogWriter = new StreamWriter(currentLogFileName, false);
                WriteCSVHeader(liveLogWriter);

                isInitialized = true;
                Debug.Log($"[PositionAccuracyLogger] Initialized. Logging to: {currentLogFileName}");
            }
            catch (Exception e)
            {
                Debug.LogError($"[PositionAccuracyLogger] Failed to initialize: {e.Message}");
                enableLogging = false;
            }
        }

        /// <summary>
        /// Log position accuracy for a vehicle
        /// </summary>
        public void LogPositionAccuracy(string vehicleId, Vector3 unityPosition, Vector3 sumoPosition, float speed, float steeringAngle)
        {
            if (!enableLogging || !isInitialized) return;

            float currentTime = Time.time;

            // Check log interval
            if (lastLogTime.ContainsKey(vehicleId))
            {
                if (currentTime - lastLogTime[vehicleId] < logInterval)
                    return;
            }

            lastLogTime[vehicleId] = currentTime;

            // Create new entry
            PositionAccuracyEntry entry = new PositionAccuracyEntry(
                currentTime,
                vehicleId,
                unityPosition,
                sumoPosition,
                speed,
                steeringAngle
            );

            // Add to vehicle's log list
            if (!vehicleLogs.ContainsKey(vehicleId))
            {
                vehicleLogs[vehicleId] = new List<PositionAccuracyEntry>();
            }
            vehicleLogs[vehicleId].Add(entry);

            // Write to live log file immediately
            if (liveLogWriter != null)
            {
                liveLogWriter.WriteLine(entry.ToCSV());
            }

            // Update statistics
            totalEntriesLogged++;
            UpdateStatistics(entry);

            // Auto-save check
            if (totalEntriesLogged % autoSaveThreshold == 0)
            {
                liveLogWriter?.Flush();
                Debug.Log($"[PositionAccuracyLogger] Auto-flushed at {totalEntriesLogged} entries");
            }
        }

        /// <summary>
        /// Update running statistics
        /// </summary>
        private void UpdateStatistics(PositionAccuracyEntry entry)
        {
            // Update max error
            if (entry.positionError > maxPositionError)
            {
                maxPositionError = entry.positionError;
            }

            // Update average error (running average)
            averagePositionError = ((averagePositionError * (totalEntriesLogged - 1)) + entry.positionError) / totalEntriesLogged;

            // Update active vehicles count
            activeVehicles = vehicleLogs.Count;
        }

        /// <summary>
        /// Write CSV header
        /// </summary>
        private void WriteCSVHeader(StreamWriter writer)
        {
            writer.WriteLine("Timestamp,VehicleID," +
                           "UnityX,UnityY,UnityZ," +
                           "SumoX,SumoY,SumoZ," +
                           "PositionError,LateralError,LongitudinalError," +
                           "Speed,SteeringAngle");
        }

        /// <summary>
        /// Export all logs to CSV file (backup method)
        /// </summary>
        public void ExportToCSV(string filename = null)
        {
            if (vehicleLogs.Count == 0)
            {
                Debug.LogWarning("[PositionAccuracyLogger] No data to export.");
                return;
            }

            try
            {
                string fullPath = Path.Combine(Application.dataPath, "..", outputDirectory);
                Directory.CreateDirectory(fullPath);

                if (filename == null)
                {
                    string timestamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
                    filename = Path.Combine(fullPath, $"position_accuracy_backup_{timestamp}.csv");
                }

                using (StreamWriter writer = new StreamWriter(filename))
                {
                    WriteCSVHeader(writer);

                    // Write all entries sorted by timestamp
                    List<PositionAccuracyEntry> allEntries = new List<PositionAccuracyEntry>();
                    foreach (var vehicleLog in vehicleLogs.Values)
                    {
                        allEntries.AddRange(vehicleLog);
                    }
                    allEntries.Sort((a, b) => a.timestamp.CompareTo(b.timestamp));

                    foreach (var entry in allEntries)
                    {
                        writer.WriteLine(entry.ToCSV());
                    }
                }

                Debug.Log($"[PositionAccuracyLogger] Exported {totalEntriesLogged} entries to: {filename}");
            }
            catch (Exception e)
            {
                Debug.LogError($"[PositionAccuracyLogger] Export failed: {e.Message}");
            }
        }

        /// <summary>
        /// Export statistics summary to text file
        /// </summary>
        public void ExportStatisticsSummary()
        {
            try
            {
                string fullPath = Path.Combine(Application.dataPath, "..", outputDirectory);
                Directory.CreateDirectory(fullPath);

                string timestamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
                string filename = Path.Combine(fullPath, $"statistics_summary_{timestamp}.txt");

                using (StreamWriter writer = new StreamWriter(filename))
                {
                    writer.WriteLine("=== Position Accuracy Statistics Summary ===");
                    writer.WriteLine($"Generated: {DateTime.Now}");
                    writer.WriteLine();
                    writer.WriteLine($"Total Entries Logged: {totalEntriesLogged}");
                    writer.WriteLine($"Active Vehicles: {activeVehicles}");
                    writer.WriteLine($"Average Position Error: {averagePositionError:F4} m");
                    writer.WriteLine($"Maximum Position Error: {maxPositionError:F4} m");
                    writer.WriteLine();
                    writer.WriteLine("=== Per-Vehicle Statistics ===");

                    foreach (var kvp in vehicleLogs)
                    {
                        string vehicleId = kvp.Key;
                        List<PositionAccuracyEntry> entries = kvp.Value;

                        if (entries.Count == 0) continue;

                        float avgError = 0f;
                        float maxError = 0f;
                        float avgLateralError = 0f;
                        float avgLongitudinalError = 0f;

                        foreach (var entry in entries)
                        {
                            avgError += entry.positionError;
                            avgLateralError += Mathf.Abs(entry.lateralError);
                            avgLongitudinalError += Mathf.Abs(entry.longitudinalError);
                            if (entry.positionError > maxError)
                                maxError = entry.positionError;
                        }

                        avgError /= entries.Count;
                        avgLateralError /= entries.Count;
                        avgLongitudinalError /= entries.Count;

                        writer.WriteLine($"\nVehicle: {vehicleId}");
                        writer.WriteLine($"  Samples: {entries.Count}");
                        writer.WriteLine($"  Avg Error: {avgError:F4} m");
                        writer.WriteLine($"  Max Error: {maxError:F4} m");
                        writer.WriteLine($"  Avg Lateral Error: {avgLateralError:F4} m");
                        writer.WriteLine($"  Avg Longitudinal Error: {avgLongitudinalError:F4} m");
                    }
                }

                Debug.Log($"[PositionAccuracyLogger] Statistics summary exported to: {filename}");
            }
            catch (Exception e)
            {
                Debug.LogError($"[PositionAccuracyLogger] Statistics export failed: {e.Message}");
            }
        }

        /// <summary>
        /// Finalize logging and save all data
        /// </summary>
        private void FinalizeLogging()
        {
            if (!isInitialized) return;

            try
            {
                // Close live log writer
                if (liveLogWriter != null)
                {
                    liveLogWriter.Flush();
                    liveLogWriter.Close();
                    liveLogWriter = null;
                }

                // Export statistics summary
                ExportStatisticsSummary();

                Debug.Log($"[PositionAccuracyLogger] Finalized. Total entries: {totalEntriesLogged}");
            }
            catch (Exception e)
            {
                Debug.LogError($"[PositionAccuracyLogger] Finalization failed: {e.Message}");
            }
        }

        /// <summary>
        /// Clear all logged data (useful for runtime testing)
        /// </summary>
        public void ClearLogs()
        {
            vehicleLogs.Clear();
            lastLogTime.Clear();
            totalEntriesLogged = 0;
            averagePositionError = 0f;
            maxPositionError = 0f;
            activeVehicles = 0;
            Debug.Log("[PositionAccuracyLogger] Logs cleared.");
        }

        /// <summary>
        /// Get current statistics as a formatted string
        /// </summary>
        public string GetStatisticsString()
        {
            return $"Vehicles: {activeVehicles} | Entries: {totalEntriesLogged} | " +
                   $"Avg Error: {averagePositionError:F3}m | Max Error: {maxPositionError:F3}m";
        }
    }
}
