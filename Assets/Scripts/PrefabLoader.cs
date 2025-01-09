using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;

public class PrefabLoader : EditorWindow
{
    private const string MODEL_PATH = "Assets/3d_model/tum_main_campus.fbx";
    
    private static readonly Vector3 MODEL_POSITION = new Vector3(479.78f, -0.01f, 500.87f);
    private static readonly Quaternion MODEL_ROTATION = Quaternion.Euler(0f, 180f, 0f);
    private static readonly Vector3 MODEL_SCALE = Vector3.one;

    [MenuItem("Tools/Load TUM Campus Model")]
    static void LoadModelMenuItem()
    {
        if (!Application.isPlaying)
        {
            LoadModelFromFbx();
        }
    }

    [InitializeOnLoadMethod]
    static void Initialize()
    {
        EditorSceneManager.sceneOpened += OnSceneOpened;
        if (!Application.isPlaying)
        {
            EditorApplication.delayCall += LoadModelFromFbx;
        }
    }

    private static void OnSceneOpened(UnityEngine.SceneManagement.Scene scene, OpenSceneMode mode)
    {
        if (!Application.isPlaying)
        {
            EditorApplication.delayCall += LoadModelFromFbx;
        }
    }

    private static void LoadModelFromFbx()
    {
        // Early return if in play mode
        if (Application.isPlaying)
        {
            return;
        }

        UnityEngine.Object fbxModel = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(MODEL_PATH);
        
        if (fbxModel != null)
        {
            GameObject container = GameObject.Find("TUM_Campus_Container");
            if (container == null)
            {
                container = new GameObject("TUM_Campus_Container");
                Undo.RegisterCreatedObjectUndo(container, "Create TUM Campus Container");
            }
            else
            {
                for (int i = container.transform.childCount - 1; i >= 0; i--)
                {
                    Undo.DestroyObjectImmediate(container.transform.GetChild(i).gameObject);
                }
            }

            container.transform.position = MODEL_POSITION;
            container.transform.rotation = MODEL_ROTATION;
            container.transform.localScale = MODEL_SCALE;

            GameObject instance = PrefabUtility.InstantiatePrefab(fbxModel) as GameObject;
            if (instance != null)
            {
                Undo.RegisterCreatedObjectUndo(instance, "Create TUM Campus Model");
                instance.transform.SetParent(container.transform, false);
                
                Transform roads = container.transform
                    .Find("tum_main_campus/Tile_0_0Node/RoadsNode");

                if (roads != null)
                {
                    if (!roads.GetComponent<MeshCollider>())
                    {
                        MeshCollider collider = Undo.AddComponent<MeshCollider>(roads.gameObject);
                        Debug.Log("Successfully added MeshCollider to RoadsNode");
                    }
                }
                else
                {
                    Debug.LogError("Could not find path: tum_main_campus/Tile_0_0Node/RoadsNode");
                }

                Debug.Log($"Successfully loaded model from {MODEL_PATH}");
                
                if (!Application.isPlaying)
                {
                    EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());
                }
            }
            else
            {
                Debug.LogError($"Failed to instantiate model from {MODEL_PATH}");
            }
        }
        else
        {
            Debug.LogError($"Could not load model at path: {MODEL_PATH}");
        }
    }
} 