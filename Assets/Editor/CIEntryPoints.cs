using System;
using System.Collections.Generic;
using System.Globalization;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Sumonity.EditorCI
{
    [InitializeOnLoad]
    public static class CIEntryPoints
    {
        private const string DefaultScenePath = "Assets/Scenes/MainScene.unity";
        private const double DefaultSimulationSeconds = 30d;
        private const double DefaultTimeoutSeconds = 300d;

        private const string RunActiveKey = "Sumonity.EditorCI.RunActive";
        private const string RunSuccessfulKey = "Sumonity.EditorCI.RunSuccessful";
    private const string SimulationRemainingKey = "Sumonity.EditorCI.SimulationRemaining";
    private const string TimeoutRemainingKey = "Sumonity.EditorCI.TimeoutRemaining";
        private const string ScenePathKey = "Sumonity.EditorCI.ScenePath";

        private static bool _runActive;
        private static bool _runSuccessful = true;
        private static double _simulationEndTime;
        private static double _timeoutAt;
        private static double _startTime;
        private static string _activeScenePath = DefaultScenePath;

        static CIEntryPoints()
        {
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
            EditorApplication.update += OnEditorUpdate;
            RestoreRunState();
        }

        public static void RunHeadlessSimulation()
        {
            if (_runActive)
            {
                Debug.LogWarning("[CI] Simulation already in progress.");
                return;
            }

            try
            {
                var args = ParseArgs();
                var scenePath = args.TryGetValue("scenePath", out var sceneArg) && !string.IsNullOrWhiteSpace(sceneArg)
                    ? sceneArg
                    : DefaultScenePath;

                var simulationSeconds = args.TryGetValue("simulationSeconds", out var durationArg) && TryParsePositive(durationArg, DefaultSimulationSeconds, out var parsedDuration)
                    ? parsedDuration
                    : DefaultSimulationSeconds;

                var timeoutSeconds = args.TryGetValue("timeoutSeconds", out var timeoutArg) && TryParsePositive(timeoutArg, DefaultTimeoutSeconds, out var parsedTimeout)
                    ? parsedTimeout
                    : DefaultTimeoutSeconds;

                Debug.Log($"[CI] Loading scene '{scenePath}' for {simulationSeconds:0.##}s (timeout {timeoutSeconds:0.##}s).");

                var scene = EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
                if (!scene.IsValid())
                {
                    throw new InvalidOperationException($"Scene '{scenePath}' failed to load.");
                }

                _startTime = EditorApplication.timeSinceStartup;
                _simulationEndTime = _startTime + simulationSeconds;
                _timeoutAt = _startTime + timeoutSeconds;
                _runActive = true;
                _runSuccessful = true;
                _activeScenePath = scenePath;

                PersistRunState();

                EditorApplication.isPlaying = true;
            }
            catch (Exception ex)
            {
                Debug.LogError($"[CI] Failed to start simulation: {ex}");
                ForceExit(1);
            }
        }

        private static void OnEditorUpdate()
        {
            if (!_runActive)
            {
                return;
            }

            var now = EditorApplication.timeSinceStartup;
            if (_timeoutAt > 0 && now >= _timeoutAt)
            {
                Debug.LogError("[CI] Simulation timed out. Exiting play mode.");
                _runSuccessful = false;
                PersistRunState();
                EditorApplication.isPlaying = false;
                return;
            }

            if (EditorApplication.isPlaying && now >= _simulationEndTime)
            {
                Debug.Log("[CI] Simulation duration elapsed. Exiting play mode.");
                EditorApplication.isPlaying = false;
                PersistRunState();
            }
        }

        private static void OnPlayModeStateChanged(PlayModeStateChange state)
        {
            if (!_runActive)
            {
                return;
            }

            if (state == PlayModeStateChange.EnteredPlayMode)
            {
                Debug.Log("[CI] Play mode entered.");
            }
            else if (state == PlayModeStateChange.ExitingPlayMode)
            {
                Debug.Log("[CI] Play mode exited.");
                PersistRunState();
                FinishRun();
            }
        }

        private static void FinishRun()
        {
            if (!_runActive)
            {
                return;
            }

            _runActive = false;

            var exitCode = _runSuccessful ? 0 : 1;
            var elapsed = EditorApplication.timeSinceStartup - _startTime;
            Debug.Log($"[CI] Simulation complete in {elapsed:0.##}s. Exit code {exitCode}.");

            ClearPersistedState();

            EditorApplication.delayCall += () =>
            {
                if (EditorApplication.isPlaying)
                {
                    EditorApplication.isPlaying = false;
                }

                EditorApplication.Exit(exitCode);
            };
        }

        private static Dictionary<string, string> ParseArgs()
        {
            var args = Environment.GetCommandLineArgs();
            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            for (var i = 0; i < args.Length; i++)
            {
                var arg = args[i];
                if (!arg.StartsWith("-", StringComparison.Ordinal))
                {
                    continue;
                }

                var key = arg.TrimStart('-');
                if (string.IsNullOrWhiteSpace(key))
                {
                    continue;
                }

                string value = null;
                if (i + 1 < args.Length && !args[i + 1].StartsWith("-", StringComparison.Ordinal))
                {
                    value = args[i + 1];
                    i++;
                }

                result[key] = value;
            }

            return result;
        }

        private static bool TryParsePositive(string text, double fallback, out double value)
        {
            value = fallback;
            if (string.IsNullOrWhiteSpace(text))
            {
                return false;
            }

            if (double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed) && parsed > 0)
            {
                value = parsed;
                return true;
            }

            Debug.LogWarning($"[CI] Could not parse value '{text}'. Using fallback {fallback}.");
            return false;
        }

        private static void PersistRunState()
        {
            SessionState.SetBool(RunActiveKey, _runActive);
            SessionState.SetBool(RunSuccessfulKey, _runSuccessful);
            var now = EditorApplication.timeSinceStartup;
            var remaining = Math.Max(0d, _simulationEndTime - now);
            var timeoutRemaining = _timeoutAt > 0d ? Math.Max(0d, _timeoutAt - now) : -1d;

            SessionState.SetString(SimulationRemainingKey, remaining.ToString("R", CultureInfo.InvariantCulture));
            SessionState.SetString(TimeoutRemainingKey, timeoutRemaining.ToString("R", CultureInfo.InvariantCulture));
            SessionState.SetString(ScenePathKey, _activeScenePath ?? string.Empty);
        }

        private static void RestoreRunState()
        {
            if (!SessionState.GetBool(RunActiveKey, false))
            {
                return;
            }

            var remaining = ParsePersistedDouble(SimulationRemainingKey, 0d);
            if (remaining <= 0d)
            {
                ClearPersistedState();
                return;
            }

            var timeoutRemaining = ParsePersistedDouble(TimeoutRemainingKey, -1d);
            _runActive = true;
            _runSuccessful = SessionState.GetBool(RunSuccessfulKey, true);
            _startTime = EditorApplication.timeSinceStartup;
            _simulationEndTime = _startTime + remaining;
            _timeoutAt = timeoutRemaining > 0d ? _startTime + timeoutRemaining : 0d;
            _activeScenePath = SessionState.GetString(ScenePathKey, DefaultScenePath);

            Debug.Log($"[CI] Restored simulation state for scene '{_activeScenePath}'.");
        }

        private static void ClearPersistedState()
        {
            SessionState.SetBool(RunActiveKey, false);
            SessionState.SetBool(RunSuccessfulKey, true);
            SessionState.SetString(SimulationRemainingKey, string.Empty);
            SessionState.SetString(TimeoutRemainingKey, string.Empty);
            SessionState.SetString(ScenePathKey, string.Empty);
        }

        private static double ParsePersistedDouble(string key, double fallback)
        {
            var text = SessionState.GetString(key, string.Empty);
            if (string.IsNullOrEmpty(text))
            {
                return fallback;
            }

            return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var value)
                ? value
                : fallback;
        }

        private static void ForceExit(int exitCode)
        {
            _runActive = false;
            _runSuccessful = exitCode == 0;
            ClearPersistedState();
            EditorApplication.delayCall += () =>
            {
                if (EditorApplication.isPlaying)
                {
                    EditorApplication.isPlaying = false;
                }

                EditorApplication.Exit(exitCode);
            };
        }
    }
}
