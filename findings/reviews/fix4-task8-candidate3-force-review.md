# Candidate 3 fresh final-force evidence review

**Specification verdict: APPROVED. Evidence-quality verdict: APPROVED.** The fresh `07-final-force-teardown-attempt2` satisfies the separately approved foreground force phase. No acceptance-blocking finding. Physical device cleanup remains pending; this is not the overall Task 8 gate verdict.

Reviewed raw invocation/start/result, executed helper and dependency copies, identity and ownership evidence, authenticated ready/pre-force records, retained generated flow and complete reports, hierarchy, force command/result/streams, foreground command/result/streams, final process inventory, acceptance and reclaim record. No live operations, builds, tests, or helper edits were performed.

## Provenance and ready fixture

- Invocation exits 0 after 41.670 seconds, uses only `--phase force-teardown --allow-force-reclaim-owned-ios`, isolated runner home, session `fix4-8-c3`, and unset API environment.
- Executed helper SHA-256 independently matches `a19d5447a70e60c4cac37d3e6435eda1d122194dab0352a2dd1f99a7ddff4c96`; executed lifecycle dependency matches `e5ece28eed78f72feb2e0ec7ef0e2da83bfc5b13dda56aeb788360ac907d13b8`.
- Candidate manifest hash independently matches `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`; ownership manifest matches `c870d5a2d02c112dca863a4cdfb4d5fe9810c789c21f0407e3af80d073a9b8e2`. Verified identity binds frozen CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, QA binary `1b6a973b…`, bundle `b0343304…`, runner source `ba9008f4…`, identical installed/packaged runner `9342b8a3…`, demo `84af7581…`, and app manifest `b9619e1d…`.
- Raw identity commands succeed and bind owned iOS `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E` / `smoke4-c3-ios` / iOS 26.0 and Android `emulator-5580` / `smoke4-c3-android` / API 35. Force targets only that owned iOS UDID.
- Foreground CLI PID `79528` owns runner PID `79556`; raw parent output, runner executable/argv, ready session, and exact lease all agree. Ready port is 8274 and app is `com.kylebrowning.Landmarks`. The lease records CLI owner, exact runner/device, and `keepAlive: true`.
- Retained report and flow detail are complete and passed, name the exact device and authenticated generated flow, and contain two passed completed commands (`launchApp`, `waitForAnimationToEnd`). Generated YAML names the correct app. Independently calculated report hash `8f97ecec50188f76a52d1432505b1169841f21ac4225e200e2dd8b84519cf508` equals pre-force proof.
- Raw hierarchy shows Landmarks and exits 0. The pre-force timestamp precedes force invocation and records live CLI, unchanged ready session, authenticated runner and complete retained report. No copy failure or failed acceptance artifact appears.

## Force result and exact cleanup

The raw command is exactly `simulator teardown --udid 33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E --force --json`. It exits 0 after 30.582 seconds without timing out. Its one-result JSON names that UDID, sets `runnerSessionStopped` and `reclaimed` true, includes both process arrays, removes the exact owned runner device home, and has no device-home failures. Empty process arrays are compatible with orderly runner-session stopping before reclamation.

Foreground PID `79528` exits 0 and emits the exact required `Runner stopped by teardown (pid 79556); the session has ended.` The approved executed helper reaches acceptance only after both exact PID-absence checks, project/global session cleanup, and exact lease absence. Independently inspecting the final raw process inventory finds neither PID. Final ownership, acceptance and `IOS-FORCE-RECLAIMED.json` agree; no fallback SIGINT or failed cleanup was needed.

## Retained warning and scope

`live-force.stderr` contains a warning that holder PID `79528` did not exit by the teardown deadline. This is explicitly retained, not an empty-stderr result. The helper waits for its foreground child only after the synchronous force command returns; frozen `RunnerSessionStopper` waits on `KeepAliveSessionStore.processIsAlive`, which uses `kill(pid, 0)`. An exited but unreaped child can therefore account for this warning and the approximately 30-second wait. That explanation is an inference: no contemporaneous process-state snapshot proves the child's state at the warning instant. The observed final exit 0, exact teardown notice, absent PIDs/session/lease, and successful force result nevertheless satisfy every approved force acceptance predicate; the warning supplies no evidence of a remaining resource or required manual intervention.

The original `07-final-force-teardown` remains a preserved pre-force helper failure and contributes no pass evidence here. This fresh result records `physicalDeviceDeleted: false` and `finalCleanupRequired: true`; neither smoke device's physical deletion is claimed or inferred from reclamation. Controller physical cleanup and its review remain required.
