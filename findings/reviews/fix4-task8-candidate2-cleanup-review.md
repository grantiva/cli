# Task 8 candidate 2 cleanup helper review

## Verdicts

- **Specification compliance: CHANGES REQUESTED.** Device, session, lease, forward, and protected-owner scopes are otherwise correct, but the Android PID fallback does not authenticate the current process occupying the provision-recorded PID before signaling it.
- **Code quality and destructive-action safety: CHANGES REQUESTED.** A stale earlier process classification is reused across a later PID lookup, creating a concrete PID-reuse race around `kill -TERM`.

## Blocking finding

**[P1] Re-authenticate the current emulator PID row before the fallback kill — `candidate2_cleanup.py:126-143`.** The first process inventory classifies the provision-recorded PID as `owned-emulator` only when its argv has the exact emulator/qemu executable shape, `-avd smoke4-android`, and `-port 5580`. Later, immediately before Android cleanup, the helper takes a fresh process inventory into `pid_row`, but computes `pid_ok` from whether the old `known` list contained that PID. If the owned emulator exits after the first snapshot and the OS reuses its PID, `pid_row` can now describe an unrelated process while `pid_ok` remains true. When the Android serial is absent, lines 142-143 then send TERM to that unrelated current process.

Apply the same exact executable/AVD/port predicate directly to the fresh `pid_row`. Permit the fallback PID kill only when that current row passes. If the PID is absent, continue with authenticated AVD deletion; if it is present with any other argv, record/refuse it and do not signal it. A focused synthetic/static check covering exact current row, absent row, and reused/mismatched row is sufficient; do not run devices for the correction.

## Accepted cleanup boundaries

- The helper requires the frozen candidate/ownership schemas, literal `fix4-8`, exact runner home and scratch, exact iOS name/runtime/create command, exact Android name/AVD/API/serial/create command, Java home, and one provision-recorded PID before destructive work.
- iOS physical deletion is independent of force-teardown claims and requires the manifest UUID to resolve to exactly the owned name and runtime. Shutdown and deletion target only that UUID.
- Android forward removal is serial-scoped and removes each exact listed local endpoint. Live serial cleanup requires the exact AVD identity; AVD deletion requires the exact owned name to be listed and its config to carry matching `AvdId` and display name. There is no kill-all, remove-all, global emulator/ADB teardown, default runner-home write, or broad simulator deletion.
- Candidate project/global sessions are inventoried with hashes. Unknown scratch sessions and marker-bearing processes are recorded as failures and are never added to deletion/signal targets. Only authenticated session files and the two exact device lease paths can be unlinked; ordinary install and registry locks remain untouched.
- Non-emulator signals are limited to parsed exact candidate runner, candidate CLI with a claimed PID, and WDA/log/simctl processes carrying owned markers. Each PID is waited out before session and lease removal continues.
- Final verification independently requires the owned simulator, Android serial/AVD, serial forwards, marked or claimed processes, scratch/global sessions, and exact leases to be absent. It compares both protected simulator records to the provisioning baseline while excluding only dynamic size fields, requires `Pixel_8_API_35` to remain listed, and checks its config hash against the provisioning baseline.
- Evidence output is isolated, every command records argv/environment/timing/result/stdout/stderr, failures accumulate, acceptance exits nonzero on any refusal or residual, and physical deletion is explicitly not inferred from force teardown.

This was a static, read-only review of `candidate2_cleanup.py`, its report, and full diff. Candidate 2 devices have not yet been provisioned. The helper and all device/process commands were not executed.

## Scoped P1 correction re-review

- **Final specification verdict: APPROVED.** The exact current emulator identity is now required before the Android fallback can proceed or signal the recorded PID.
- **Final quality and destructive-action-safety verdict: APPROVED.** The shared predicate removes the stale historical-classification dependency and is reused at the fallback signal site without weakening other cleanup gates.

**Prior P1 — ADDRESSED.** `exact_emulator_process()` requires the provision-recorded PID, an `emulator` or `qemu-*` executable, exact `-avd smoke4-android`, and exact `-port 5580`, while safely rejecting missing or truncated flags. The fresh `android-process-identity` inventory supplies the current PID row; an absent row is permitted because there is no process to signal, and any present mismatched/reused row makes `pid_ok` false, records a refusal, and prevents the entire Android action block. The fallback TERM additionally retains the exact predicate at its call site. The same predicate now classifies the initial process inventory, avoiding divergent identity rules.

The reported synthetic cases cover the exact owned row, absent row, reused PID with wrong executable/AVD/port, and malformed flag input. Helper SHA-256 `d4df8c93dc24126800bca2c1d1ffc466bc7adac0cf90cf6f68345cd6961d5d41` matches the correction submitted for this re-review. No new scoped defect was found. This follow-up remained static and read-only; no live process or device state was inspected or changed.
