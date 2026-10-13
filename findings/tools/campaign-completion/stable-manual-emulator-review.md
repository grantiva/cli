# Stable manual-emulator fixture

The inert fixture launches only reserved `cov4-android-2` with the exact SDK emulator argv, stdin at `/dev/null`, exclusive stdout/stderr files, closed inherited descriptors, and a new session. Before its parent exits it persists PID, PGID, session ID, full `ps` identity, argv, serial, AVD, and host start time.

Readiness is bounded and requires all three signals together: adb state `device`, exact live AVD name `cov4-android-2`, and `sys.boot_completed=1`. A separate later `verify` invocation compares the same PID's full start/argv identity, PGID, and session and repeats all readiness checks. The fixture performs no teardown, deletion, ledger mutation, or other device action.

Proposed later calls, only inside a new root-granted window:

```text
python3 findings/evidence/cov4-android/tools/stable-manual-emulator.py launch <new-exclusive-evidence-dir>
python3 findings/evidence/cov4-android/tools/stable-manual-emulator.py verify <same-evidence-dir>
```

The script has not been executed against an emulator while preparing this review.

## Fix round 1

The original reviewed helper is preserved by its recorded SHA-256 `3b9fa26659b448bb762e7a53fbfa3a5315e40c5792f8704884c4f568e460267a`. The revised helper addresses all four review findings:

- Process identity is parsed into fields. PPID remains an observation while stable comparison uses PID, start time, PGID, session, executable, and command. The command must bind `qemu-system`, `-avd cov4-android-2`, and `-port 5556`.
- Launch argv now contains literal `-port 5556`. Preflight requires `emulator-5556` absent from `adb devices` and a successful exclusive bind of local TCP port 5556 before spawn.
- Every `ps` and adb probe receives the remaining overall deadline as its subprocess timeout. Launch and verify reject nonpositive bounds and preserve argv, exit, timeout, and captured streams in structured evidence.
- `launch-pending.json` is exclusively created before spawn and `launch-pid.json` immediately after `Popen` returns. Startup and verification always write exclusive terminal records. Repeated verification creates a new numbered artifact and cannot replace an earlier result.

No emulator or adb command was run during this fix. Static compilation passed. The first inert fake test found an incorrect test assertion that expected independently timestamped verification documents to be byte-identical; its empty stdout capture is preserved. The corrected rerun passed reparenting, hung-probe timeout, immediate-exit PID journaling, and immutable duplicate-verification checks:

```text
python3 -m py_compile findings/evidence/cov4-android/tools/stable-manual-emulator.py findings/evidence/cov4-android/tools/test-stable-manual-emulator.py
python3 findings/evidence/cov4-android/tools/test-stable-manual-emulator.py
PASS reparenting hung-probe immediate-exit immutable-duplicate-verification
```

Revised artifacts:

- helper SHA-256: `bd919f9a8d5250ebe394bf9d1c8563842e288fc28ed36e5f62524f9481b5f1c6`
- fake-check SHA-256: `561b941efc58aad69d5a6a818acaf802192f3d67a85b4d07a317603342ef78e1`
- passing output SHA-256: `4f8737a9f17b4e4b7c5ba769f32694354a69793ec0aa8ee7eb49e43dc4c040fd`

## Fix round 2

The exact fix1 helper, test, and passing output were first copied to immutable snapshot files with their reviewed hashes. The scoped fix2 changes are:

- Readiness adb calls retain ordinary nonzero exits as observations. Polling continues only while the journaled process lives and the overall deadline remains. Readiness requires all three exits to be zero plus the exact state, AVD, and boot-completed values.
- The initial process identity is explicitly provisional. Its PID/start/PGID/session tuple anchors the handoff loop; wrapper executable/argv may transition in place. Ownership freezes only after that same tuple exposes exact qemu, AVD, and port identity at readiness.
- Timeout partial streams are normalized to lossless base64 objects. Both launch and numbered verification terminal paths were exercised with a fake probe that writes to stdout and stderr before hanging; both produced parseable JSON whose decoded bytes matched exactly.

Validation commands used only Python fake processes and temporary files:

```text
python3 -m py_compile findings/evidence/cov4-android/tools/stable-manual-emulator.py findings/evidence/cov4-android/tools/test-stable-manual-emulator.py findings/evidence/cov4-android/tools/test-stable-manual-emulator-fix2.py
python3 findings/evidence/cov4-android/tools/test-stable-manual-emulator.py
python3 findings/evidence/cov4-android/tools/test-stable-manual-emulator-fix2.py
```

Final outputs:

```text
PASS reparenting hung-probe immediate-exit immutable-duplicate-verification
PASS adb-nonzero-polls wrapper-qemu-handoff timeout-stream-terminal
```

The first focused run used a 0.1-second timeout; scheduling occasionally expired before the fake shell emitted its partial streams, so its empty output artifact is preserved. The rerun raised only the fake emitter window to 0.5 seconds, still below its two-second sleep, and passed. No live adb, emulator, device, build, network, cleanup, or coverage command ran.
