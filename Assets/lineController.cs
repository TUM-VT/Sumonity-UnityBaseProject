using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class lineController : MonoBehaviour
{
    // Public variable to assign the cube GameObject
    public GameObject cube;
    public GameObject Simulator;

    // Public variable to determine if the transport should occur

    private float pathShiftValue = -10f;
    private bool pathShifted = false;
    private bool finalShift = false;

    void GetPathShiftValueFromCommandLine()
    {
        var args = Environment.GetCommandLineArgs();
        string text = "";

        for (int i = 0; i < args.Length; i++)
        {
            if(args[i] == "--pathShift" && i<args.Length-1)
            {
                int payload = int.Parse(args[i+1]);
                pathShiftValue = (float)payload; // in meters
            }
        }

        return;
    }

    void Start()
    {
        GetPathShiftValueFromCommandLine();
    }

    void Update()
    {

        // Check if the Simulator GameObject is assigned
        if (Simulator != null)
        {
            // Print the transform of the Simulator GameObject
            // Debug.Log("Simulator transform: " + Simulator.transform.position.ToString());
            // Check if the bicycle is closer than 5 meters to the specified position
            float distanceCheckpoint_1 = Vector3.Distance(Simulator.transform.position, new Vector3(534f, Simulator.transform.position.y, 500f));
            float distanceCheckpoint_2 = Vector3.Distance(Simulator.transform.position, new Vector3(573f, Simulator.transform.position.y, 588f));
            // Debug.Log("Distance: " + distance);
            if (distanceCheckpoint_1 < 5f && !pathShifted && !finalShift)
            {
                MoveCube(-pathShiftValue); // move left
                pathShifted = true;
            }
            if (distanceCheckpoint_2 < 5f && pathShifted && !finalShift)
            {
                MoveCube(pathShiftValue); // move right
                pathShifted = true;
                finalShift = true;
            }
        }
        else
        {
            Debug.LogWarning("Simulator GameObject is not assigned.");
        }

    }




    void MoveCube(float moveVal)
    {
        // Ensure the cube GameObject is assigned
        if (cube != null)
        {
            // Shift the cube's position by -2 meters on the x-axis
            cube.transform.position += new Vector3(moveVal, 0f, 0f);
        }
        else
        {
            Debug.LogWarning("Cube GameObject is not assigned.");
        }
    }
}
