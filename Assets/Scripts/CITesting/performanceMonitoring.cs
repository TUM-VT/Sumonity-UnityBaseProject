using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;
using tumvt.sumounity;
using System.Linq;

public class performanceMonitoring : MonoBehaviour
{
    [Header("Performance Monitoring Settings")]
    [Tooltip("How often to record position differences (in seconds)")]
    [SerializeField] private float recordInterval = 0.5f;
    [SerializeField] private string outputFileName = "vehicle_position_comparison.csv";
    [SerializeField] private bool logToConsole = true;
    [Tooltip("How many samples to use for calculating rolling average errors")]
    [SerializeField] private int averageSampleCount = 10;

    [Header("References")]
    [Tooltip("Reference to the SumoSocketClient component")]
    [SerializeField] private SumoSocketClient sumoClient;

    // Private variables
    private float timer = 0f;
    private Dictionary<string, VehiclePositionData> positionDataDict = new Dictionary<string, VehiclePositionData>();
    private Dictionary<string, GameObject> trackedVehicles = new Dictionary<string, GameObject>();
    private Dictionary<string, List<float>> historicalErrors = new Dictionary<string, List<float>>();
    private StreamWriter writer;

    // Public properties for external access
    public float AveragePositionError { get; private set; }
    public int TrackedVehicleCount => trackedVehicles.Count;
    public Dictionary<string, float> VehicleAverageErrors { get; private set; } = new Dictionary<string, float>();

    // Class to store position data for comparison
    private class VehiclePositionData
    {
        public Vector3 sumoPosition; // Position from SUMO
        public Vector3 unityPosition; // Actual position in Unity
        public float positionDifference; // Calculated difference

        public VehiclePositionData(Vector3 sumoPos, Vector3 unityPos)
        {
            sumoPosition = sumoPos;
            unityPosition = unityPos;
            positionDifference = Vector3.Distance(
                new Vector3(sumoPos.x, 0, sumoPos.z), 
                new Vector3(unityPos.x, 0, unityPos.z));
        }
    }

    // Start is called before the first frame update
    void Start()
    {
        // Auto-find SumoSocketClient if not assigned
        if (sumoClient == null)
        {
            sumoClient = FindObjectOfType<SumoSocketClient>();
            if (sumoClient == null)
            {
                Debug.LogError("SumoSocketClient not found! Position monitoring will not work.");
                this.enabled = false;
                return;
            }
        }

        // Setup CSV file for logging
        string filePath = Path.Combine(Application.dataPath, "..", outputFileName);
        try
        {
            writer = new StreamWriter(filePath, false);
            writer.WriteLine("Timestamp,VehicleID,VehicleType,SUMO_X,SUMO_Y,Unity_X,Unity_Y,PositionDifference,AverageError");
            Debug.Log($"Performance monitoring initialized. Writing to {filePath}");
        }
        catch (System.Exception e)
        {
            Debug.LogError($"Failed to open output file: {e.Message}");
            this.enabled = false;
        }
    }

    // Update is called once per frame
    void Update()
    {
        timer += Time.deltaTime;
        
        // Record data at specified intervals
        if (timer >= recordInterval)
        {
            UpdateTrackedVehicles();
            RecordPositionDifferences();
            CalculateAverageErrors();
            timer = 0f;
        }
    }

    private void UpdateTrackedVehicles()
    {
        // Clear the dictionary to refresh vehicle references
        trackedVehicles.Clear();
        
        // Find all vehicles in the scene by searching for GameObjects with vehicle IDs in their names
        if (sumoClient != null && sumoClient.StepInfo != null && sumoClient.StepInfo.vehicleList != null)
        {
            // Find potential vehicle GameObjects
            GameObject[] allVehicles = GameObject.FindGameObjectsWithTag("Vehicle");
            if (allVehicles.Length == 0)
            {
                // If no "Vehicle" tag found, try to find all possible vehicles (less efficient)
                allVehicles = GameObject.FindObjectsOfType<GameObject>();
            }
            
            // Match vehicles by ID in their name
            foreach (SerializableVehicle sumoVehicle in sumoClient.StepInfo.vehicleList)
            {
                foreach (GameObject obj in allVehicles)
                {
                    // Check if the vehicle ID is in the GameObject name
                    if (obj.name.Contains(sumoVehicle.id))
                    {
                        trackedVehicles[sumoVehicle.id] = obj;
                        break;
                    }
                }
            }
        }
    }

    private void RecordPositionDifferences()
    {
        // Check if SumoSocketClient is available
        if (sumoClient == null || sumoClient.StepInfo == null || sumoClient.StepInfo.vehicleList == null)
            return;

        positionDataDict.Clear();
        
        // Loop through all SUMO vehicles
        foreach (SerializableVehicle sumoVehicle in sumoClient.StepInfo.vehicleList)
        {
            // Find corresponding Unity vehicle
            if (!trackedVehicles.TryGetValue(sumoVehicle.id, out GameObject unityVehicle))
                continue;

            // Get positions from both sources
            Vector3 sumoPos = new Vector3(sumoVehicle.positionX, 0, sumoVehicle.positionY);
            Vector3 unityPos = unityVehicle.transform.position;
            
            // Store position data
            var posData = new VehiclePositionData(sumoPos, unityPos);
            positionDataDict[sumoVehicle.id] = posData;
            
            // Add to historical data
            if (!historicalErrors.ContainsKey(sumoVehicle.id))
            {
                historicalErrors[sumoVehicle.id] = new List<float>();
            }
            
            // Add current error, maintaining the maximum sample count
            var errorList = historicalErrors[sumoVehicle.id];
            errorList.Add(posData.positionDifference);
            if (errorList.Count > averageSampleCount)
            {
                errorList.RemoveAt(0);
            }
            
            // Calculate average error for this vehicle
            float avgError = errorList.Count > 0 ? errorList.Average() : 0;
            VehicleAverageErrors[sumoVehicle.id] = avgError;
            
            // Log to console if enabled
            if (logToConsole)
            {
                Debug.Log($"Vehicle {sumoVehicle.id} ({sumoVehicle.vehicleType}): " +
                          $"Difference = {posData.positionDifference:F3} m, " +
                          $"Avg = {avgError:F3} m");
            }
            
            // Write to CSV
            writer.WriteLine($"{Time.time.ToString("F3", System.Globalization.CultureInfo.InvariantCulture)},{sumoVehicle.id},{sumoVehicle.vehicleType}," +
                            $"{sumoPos.x.ToString("F3", System.Globalization.CultureInfo.InvariantCulture)},{sumoPos.z.ToString("F3", System.Globalization.CultureInfo.InvariantCulture)},{unityPos.x.ToString("F3", System.Globalization.CultureInfo.InvariantCulture)},{unityPos.z.ToString("F3", System.Globalization.CultureInfo.InvariantCulture)}," +
                            $"{posData.positionDifference.ToString("F3", System.Globalization.CultureInfo.InvariantCulture)},{avgError.ToString("F3", System.Globalization.CultureInfo.InvariantCulture)}");
            
            // Log error if passenger vehicle has average error above 2 meters
            if (sumoVehicle.vehicleType.ToLower().Contains("passenger") && avgError > 2.0f)
            {
                Debug.LogError($"High position error for passenger vehicle {sumoVehicle.id}: Average error = {avgError:F3} meters");
            }
        }
        
        // Flush to ensure data is written
        writer.Flush();
    }

    private void CalculateAverageErrors()
    {
        // Calculate overall average error across all vehicles
        float totalError = 0f;
        int count = 0;
        
        foreach (var kvp in positionDataDict)
        {
            totalError += kvp.Value.positionDifference;
            count++;
        }
        
        AveragePositionError = count > 0 ? totalError / count : 0f;
    }

    // Public method to get average error for a specific vehicle
    public float GetVehicleAverageError(string vehicleId)
    {
        return VehicleAverageErrors.TryGetValue(vehicleId, out float error) ? error : 0f;
    }

    // Public method to get all current position differences
    public Dictionary<string, float> GetAllPositionDifferences()
    {
        var result = new Dictionary<string, float>();
        foreach (var kvp in positionDataDict)
        {
            result[kvp.Key] = kvp.Value.positionDifference;
        }
        return result;
    }

    void OnApplicationQuit()
    {
        // Close the file writer if it exists
        if (writer != null)
        {
            writer.Close();
            Debug.Log("Position comparison data saved to file");
        }
    }
}
