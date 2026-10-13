# Task 8 harness preparation report

Status: preparation only. No candidate was built or frozen, no device was touched, no smoke command was executed, no QA/product file was changed, and no acceptance result is claimed.

## Prepared

- `task-8-harness/run_phase.py` is a bounded, manifest-driven phase runner. Validation is the default; execution requires `--execute`.
- `task-8-harness/manifest.example.json` divides execution into candidate/upgrade, Android runner, lifecycle, iOS MCP, Android MCP, docs/output, and cleanup phases. Its bundle basename is `grantiva_GrantivaCore.bundle` and its literal session is `fix4-8`.
- `android_runner_smoke.py` is an executable parameterized procedure for APK identity/install, healthy stock, crash5, all four L51 forms, favorite5, the exact L77 retained flow under neutral Settings, optional/required text and JSON, and the subdirectory cycle control. Each invocation retains command, timing, exit, streams, and raw runner report.
- `mcp_client.py` and `mcp_smoke.py` are executable parameterized procedures for inactive-session L65 precedence, active exact L65 semantics, the full retained iOS selector sequence including back-button/application exclusion and live point coordinates, and ten mixed large pairs with small replies and notifications on either platform.
- `task-8-harness/README.md` maps every Task 8 smoke requirement to an exact phase, reference harness logic, assertion set, and retained evidence.
- The runner requires absolute candidate binary, resource bundle, fresh runner home, evidence root, merged source SHA, packaged runner SHA, and explicit new iOS/Android identities. It rejects a set API key, unresolved parameters, protected targets, global shutdown, kill-pattern commands, missing commands, and evidence overwrite.
- Each eventual top-level invocation retains `command.json`, start/end/exit in `result.json`, `stdout.raw`, `stderr.raw`, declared raw reports, and candidate/device/home provenance. Cleanup is constrained to manifest ownership; helper scripts must verify an owned PID file before any PID cleanup.

## Existing harness assessment

The retained fix4 harnesses are sufficient as reviewed behavioral logic, but none is safe to execute unchanged. They embed old scratch paths, runner homes, project paths, session IDs, output directories, simulator UUIDs, Android serials, or PID handling. The strongest reusable sources are:

- Runner: `findings/evidence/fix4-1/run-device.py` and `fix4-2/run-l51-live.py`, with fix4-2 and fix4-3 retained inputs.
- Lifecycle: `fix4-4/live/android_lifecycle2.py`, `ios_lifecycle6.py`, `ios_startup6.py`, and `cycle_controls5.py`.
- MCP: `fix4-5/mcp_client.py`, `android_acceptance.py`, `final_selector_acceptance.py`, and `ios_final2_transport_acceptance.py`.

The Android and MCP logic has now been copied and rebound without historical paths or device IDs. Final values remain unbound because the packaged runner, CLI candidate, fresh APFS clone, active-session projects, and newly owned devices do not yet exist.

## Controller completion work

After Task 7 merges, the controller must create the release candidate and fresh clone, create and inventory new smoke4 devices, add the candidate-upgrade, docs/output, and cleanup helpers, integrate the separately prepared lifecycle helper, fill the manifest, validate every phase, and execute sequentially. The controller must also supply a final healthy flow, crash flow, and subdirectory cycle fixture and review their hashes before execution. The Android helper correlates epoch logcat with each report end time, enforces the accepted two-second fatal bound, and rejects a successful `launchApp` timestamp after the fatal event.

## Preparation verification

`run_phase.py` parsed successfully as Python, the example manifest parsed successfully as JSON, `git diff --check` reported no whitespace errors, and a validation-only dry run of phase `04-mcp-ios` returned `validated-only` without creating its evidence root. No device or candidate command ran.

## Fix round 1 static-review response

This remains preparation and has not passed live smoke. The preserved review snapshot is `task-8-harness-review.diff` and was not modified.

- Crash5 now joins the sole Landmarks fatal block to the matching `Start proc <PID>:com.kylebrowning.landmarks` event, brackets device/host clock offset before and after each run, and compares the corrected fatal time with the failed `launchApp` command decision time. It asserts `app_crash`, no successful launch, and the two-second bound.
- L51 runs the reviewed `uia2-source-snapshot-v2.py` sampler at the same step boundaries and the reviewed `analyze-l51-movement.py` analyzer. It requires app-only before/after movement with negative median travel and live W3C `/actions` plus `held drag` evidence for direction, element, and coordinates. The `engine: adb` leg proves real movement and no W3C actions; external ADB argv is explicitly recorded as not observed live. Exact one-`input swipe` routing remains the accepted production unit table at `pkg/executor/commands_test.go:3536-3560`, bound to the verified runner checkout and uncached four-package Task 7 proof.
- L77 now requires an empty exact-package `pidof`, Settings as the focused component, a retained Settings hierarchy excluding Landmarks, and a passed `stopApp` command without a crash error.
- L79 now runs optional text three times and optional JSON three times, plus required text/JSON controls. Each joins exit, CLI stdout surface, report summary, command detail, ready file, and JUnit; checks `element_not_found`; and proves the following assertion passes for optional and skips for required.
- L66 now includes the missing-selector error and the retained two-lookup delayed retry/error control through a temporary WDA proxy. Both platforms require a controller-provided deterministic large-hierarchy seed and verify resource and tool responses exceed 65,536 bytes before the ten-pair batch.
- `candidate_identity.py` validates the frozen candidate and ownership manifests before execution. It verifies merged CLI repository/SHA, binary hash/version, exact resource-bundle file manifest, runner source SHA, packaged and upgraded runner hashes/versions/install stamp, fixed demo SHA/APK, clean iOS app file manifest, literal session, and provisioned device identity. Helpers consume the validator rather than recording caller-supplied SHA strings.
- Android `--source-root` is used only for frozen git provenance. All runner and CLI smoke commands use the separate required `--project` task-owned scratch project; the cycle fixture retains its own explicit project.

Static checks performed after these edits: every Python file parsed with `ast`, all three example JSON files parsed, helper `--help` entry points returned successfully, and `git diff --check` returned no error. These checks establish syntax and interface shape only. Candidate-upgrade, docs/output, cleanup, final manifest population, and all live assertions remain controller work after Task 7.

## Fix round 2 static-review response

- Crash timing now retains each probe RTT and its offset interval `[device-hostAfter, device-hostBefore]`. The decision correction uses the conservative hull across both probes and requires the entire fatal-to-decision interval to fall within `0...2.0` seconds.
- Runner source provenance now requires `runner.repoPath` and verifies its Git HEAD equals `runner.sourceSHA`. The frozen manifest also hashes the Task 7 uncached proof start/result/stdout/stderr and four fresh-home inventories, then validates `go test -count=1`, matching heads, unset API environment, distinct empty homes, exit zero, and exactly the four expected package results.
- L51 keeps the controller-approved split: live exact-session movement and no-W3C evidence for `engine: adb`, paired with the production unit routing table from the same verified runner source and uncached proof. It explicitly says external ADB argv was not observed live.
- The manifest invokes the lifecycle helper with all required frozen bindings and five named non-destructive phases, asserting `acceptance.json /status == passed`. Phase 07 runs isolated force teardown while both owned targets are still live for the helper's unconditional constructor validation. Phase 08 then confirms iOS is already absent, removes Android and residual owned state, and verifies protected inventory.

## Fix round 3 static-review response

- Preserved the complete pre-fix helper and report state in `task-8-harness-fix2-snapshot/` before editing.
- Reordered only the final phases: `07-final-force-teardown` now runs before any device cleanup, so lifecycle construction can validate both live targets; `08-final-cleanup` expects the force-removed iOS target to be absent and then removes Android and residual state.
- No lifecycle source or acceptance logic changed.
- Android command records now retain host load averages at start and end for L61 timing context without converting load into a new acceptance rule.
