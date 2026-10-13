# Task 8 joint forward helper review

## Verdict

**NEEDS CORRECTION.** The helper has the right joint-case shape and preserves the two unrelated controls, but four load-bearing evidence gaps prevent its eventual `acceptance.json` from proving the full L82/L83/L84 contract or its claimed source identities. The script has not been run.

## Load-bearing findings

1. **CLI provenance is a caller-supplied label rather than a verified binary/source binding.** `--source` is copied directly into `candidate.json` as `cliSource`, while the script only hashes `--binary`. It neither validates the source string nor records an artifact-derived version/source identity that binds that binary to the forthcoming clean author build. A mistyped or unrelated SHA would still produce a passing acceptance record. Require and validate the exact clean source commit, and capture a binary identity/version output or build manifest that independently ties the hashed executable to that commit. Keep the result qualified as joint source validation rather than a packaged candidate.

2. **The source-runner override is hash-pinned but its native version identity is not captured.** The helper correctly selects the runner through the unchanged `.14+android-drivers-2` lookup path, pins SHA-256 `cb41a305...`, records source `6b3c206...`, and says it is an isolated test-only override rather than packaged `.15`. It never invokes the runner's version command, however, so the evidence cannot show the expected source-native `l83-check` version or distinguish the lookup stamp from the binary's own identity. Capture and assert the native version output, and retain the preparation `identity.json` in the generated candidate provenance.

3. **Absent-app and healthy-stock do not prove the required session/PID cleanup.** `absence()` checks only the project session and forward inventory unless a PID is supplied. The absent-app and healthy-stock calls omit a PID, so they do not inventory `/tmp/grantiva-sessions` or device-bound runner processes before and after those cases. The healthy subprocess returning proves only its direct process exited; it does not exclude a leaked child. Nevertheless `acceptance.json` can report `passed: true`, while L84 requires owned sessions and PIDs to disappear after every ending and L82 requires the absent-app control not to leave its owned attachment. Record case-scoped pre/post session and exact device-bound process inventories, identify any spawned PID where available, and assert that no new owned session/process survives.

4. **The SIGINT case does not assert the preserved platform notice.** The helper captures stderr and checks exit 130, owned-forward cleanup, controls, session, and PID, but never checks the exact Android SIGINT notice required by L82 acceptance bullet 2. A regression that silently exits 130 would pass this controller. Assert the exact expected notice in the captured interrupt stderr while retaining the current exit and cleanup checks.

## What is faithful

- Startup begins from an empty forward baseline for the owned serial, then creates two distinct unrelated controls: fixed local `tcp:6790` to remote `tcp:16790`, and an allocated local port to remote `tcp:16791`.
- Every ready inventory requires both controls, and every completed-case inventory requires exactly those controls. This proves the ready owned `tcp:<session port>` to `tcp:6790` attachment appeared and later disappeared without deleting either unrelated control.
- The foreground ready/SIGINT and normal-stop cases use the source CLI, confirm the ready session serial and runner PID, verify that PID's command names the exact overridden runner and device, and check immediate plus delayed cleanup.
- Normal stop is requested through the production CLI path, and healthy stock runs the pinned source-built runner directly. The absent-app case uses the source CLI and expects failure.
- The evidence qualification truthfully says this is joint source-repair validation with packaged-candidate work pending; it does not claim a packaged `.15` candidate.
- Final cleanup is serial-scoped and removes only recorded control and observed owned ports. No remove-all operation is present.

## Boundary

This was a bounded read-only review of `forward_joint_live.py`, the L82/L83/L84 binding briefs, the full-script review package, and `joint-source-preparation/identity.json`. I did not run the script, tests, builds, ADB, emulators, or devices, and I made no changes outside this review report.

## Scoped correction re-review

- **Spec: PASS.** All four prior findings are resolved. The source CLI is bound to pinned commit `a5875817…` through the clean release-build manifest, its referenced source-build identity, an independently checked clean checkout HEAD/status, the exact executable path and SHA-256, and matching live/manifest version output. The test-only runner remains under the unchanged `.14+android-drivers-2` lookup stamp while its pinned binary is required to report the exact first native version line `grantiva-runner 1.1.28-grantiva.14-l83-check`; full multiline output and the APFS-clone preparation identity are retained. Absent-app and healthy-stock now record and assert clean before/after project/global sessions, exact runner/device processes, observed PIDs, PID-prefixed session files, and immediate/delayed forward inventories. The interrupt case now asserts the exact Android notice using “emulator,” with exit 130 and existing cleanup proof retained.
- **Quality: PASS.** The correction is limited to the four reviewed evidence gaps and preserves the joint healthy/ready SIGINT/normal-stop/absent-app cases, both unrelated controls, exact owned-forward cleanup, serial-scoped final cleanup, and the truthful qualification that this is source-repair validation rather than a packaged `.15` candidate. No new load-bearing breakage was identified in `task8-joint-forward-helper-fix.diff`.

This follow-up was a read-only diff review against `task8-joint-forward-helper-fix-base`, with the provided release build manifest, source-build identity, and runner preparation identity inspected for consistency. The helper remains unexecuted; I did not run tests, builds, device commands, or the controller.
