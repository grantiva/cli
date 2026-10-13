# Candidate 3 Task 8 bounded smoke harness

This separate preparation copy never imports candidate 2 phase acceptance as a grade and writes only to a fresh `round4-smoke-candidate3` evidence root. Candidate 3 requires a newly merged clean CLI HEAD and newly built/frozen release binary and bundle. The runner remains exactly `ba9008f4b2cd2c7320a9c46e04faed612b0958a2` / `1.1.28-grantiva.15`; the demo remains exactly `84af7581b75134b0e417b254e4317d565f7b73c6`. Every phase, including both MCP transports and cleanup, runs again.

This directory is preparation only. `run_phase.py` validates a phase unless the controller deliberately adds `--execute`. The example manifest is intentionally non-runnable until every absolute path and newly owned smoke device is filled in after Task 7 merges.

## Required sequence

1. Copy `manifest.example.json` outside this directory as the execution manifest. Bind it to the merged CLI SHA, packaged runner SHA, exactly one release binary and bundle, a fresh APFS-cloned runner home, new `smoke4` device IDs, and a new evidence root.
   Freeze `candidate.example.json` and `ownership.example.json` with real values. `candidate_identity.py` verifies both before any executable phase begins; placeholder or merely declared identities do not qualify.
2. The Android runner and both MCP commands are already rebound to task-specific helpers in this directory. Supply every manifest parameter. Replace the remaining candidate-upgrade, docs/output, and cleanup placeholders after Task 7; lifecycle is prepared separately. Never call the retained fix4 scripts directly: they contain old UUIDs, serials, homes, PIDs, sessions, projects, and output paths.
3. Run each phase first without `--execute`, then with it, in numeric order:

   `env -u GRANTIVA_API_KEY ./run_phase.py --manifest /absolute/execution-manifest.json --phase 01-candidate-upgrade`

   `env -u GRANTIVA_API_KEY ./run_phase.py --manifest /absolute/execution-manifest.json --phase 01-candidate-upgrade --execute`

4. Review each phase evidence before continuing. A failure stops the phase. Reopen the owning task for any failed criterion; do not qualify the failure or proceed to Task 9.

## Requirement to harness mapping

| Phase | Binding criteria | Reviewed logic to rebind | Required assertion/evidence |
|---|---|---|---|
| `01-candidate-upgrade` | One final release candidate; source/binary/bundle/runner identity; fresh APFS clone upgrade; pre-existing plus iOS 26.0/26.2/26.4/27.0 WDA caches remain valid | Task 8 brief/controller notes; no retained live harness is sufficient | Before/after manifests and cache inventories, hashes/versions, exact build/copy/upgrade argv, raw streams, exit records |
| `02-runner-android` | Healthy stock; crash 5/5 within accepted fatal bound; all four L51 forms; favorite removal 5/5; L77 literal `clearState`, bare `stopApp`, Landmarks absent; optional/required miss semantics; subdirectory cycle | Executable `android_runner_smoke.py`, rebound from `findings/evidence/fix4-1/run-device.py`, `fix4-2/run-l51-live.py`, and retained fix4-2/fix4-3 inputs | Per-run command/start/exit/stdout/stderr/raw report/provenance; exact repetition counts; final optional warning in text and JSON; report/ready/exit agreement; neutral Settings and package-state proof for L77; circular diagnostic |
| `03-lifecycle` | Starting-state interrupts; ready control; detach immediate app readiness; force teardown JSON; absent install; log-child cleanup; circular flow controls | `fix4-4/live/android_lifecycle2.py`, `ios_lifecycle6.py`, `ios_startup6.py`, `cycle_controls5.py`; associated absent-install/log/teardown retained evidence logic | Explicit state/PID/device timing, exit 130 where specified, no false timeout, immediate hierarchy, `runnerSessionStopped:true`, session/lease/forward/log-PID absence, exact cycle diagnostic |
| `04-mcp-ios` | L65 missing steps and no-session precedence; full L66 selector contract; 10 mixed >65,536-byte response pairs; small responses and notifications | Executable `mcp_smoke.py` and `mcp_client.py`, rebound from `fix4-5/mcp_client.py`, `final_selector_acceptance.py`, and `ios_final2_transport_acceptance.py` | JSONL requests, raw stdout/stderr, unique IDs, exactly 20 large replies, 10 small replies and 10 notifications, label/identifier/placeholder/script/quoted/back-button/coordinate assertions, and exact L65 strings/envelopes |
| `05-mcp-android` | L65 on Android and the same 10-pair transport contract | Executable `mcp_smoke.py` and `mcp_client.py`, rebound from `fix4-5/mcp_client.py` and `android_acceptance.py` | Same transport evidence; exact L65 error and no-session precedence; empty/wrong-type semantics retained |
| `06-docs-output` | Ambiguous doctor text/JSON; public migration notes; regenerate every help page from final candidate; corpus tests | Retained help-corpus script (locate after Task 7 merge) | Exact candidate argv, text/JSON/exit, generated help inventory and diff, migration-note inspection, test logs |
| `07-final-force-teardown` | With both owned targets still live for constructor validation, exercise live owned iOS force teardown JSON, exact runner/session cleanup, and owned iOS removal | Executable isolated `lifecycle_smoke.py --phase force-teardown --allow-destroy-owned-ios` | `acceptance.json` status is `passed` and `IOS-DEVICE-RECREATE-REQUIRED.json` exists |
| `08-final-cleanup` | Confirm iOS is already absent after force teardown, remove owned Android and residual sessions/locks/forwards/PIDs, and preserve protected inventory | Device-specific cleanup helper remains controller work; no global teardown | Ownership manifest, before/after protected inventory, targeted commands, PID identity before signal, iOS and Android absence checks |

The controller must preserve literal inputs for L77 and must foreground Settings before that flow. The Android APK must be rehashed as `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a` and recorded with source `1552ae983a27528eff4c1f8145aa075698b47f71`. Protected targets are iPhone 17 Pro `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`, iPhone 18 Pro `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`, and AVD `Pixel_8_API_35`.

Every rebound helper writes its own `acceptance.json` only after checking its criteria. The manifest checks `/passed` as real JSON content. The phase runner captures the top-level command, timestamps, exit, raw stdout/stderr, candidate provenance, and declared raw reports. Helpers record each nested command and copy transient runner reports before cleanup.
