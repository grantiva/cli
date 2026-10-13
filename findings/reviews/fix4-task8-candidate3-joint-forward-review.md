# Task 8 candidate 3 joint-forward review

**Specification verdict: APPROVED for the complete candidate-3 joint L82/L83/L84 forward-ownership phase.** The retained raw evidence proves the four required endings, preserves both unrelated controls through each cleanup boundary, removes only the case-owned forwards, and leaves no case-owned runner process or session.

**Evidence-quality verdict: APPROVED.** Command records, raw streams, forward inventories, process/session inventories, and frozen-candidate metadata agree. No blocking, important, or minor finding was identified. This verdict covers `03b-joint-forward` only; it does not assess the separately running lifecycle phase or declare overall Task 8 complete.

## Frozen identity and execution boundary

- The phase binds candidate manifest SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`, clean CLI source `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, and QA binary SHA-256 `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`.
- It binds runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`; the packaged and installed native runner hashes both equal `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`. Native version output identifies `1.1.28-grantiva.15`, commit `ba9008f`, and the install stamp is `1.1.28-grantiva.15+android-drivers-2`.
- The owned device is `emulator-5580`; the independent AVD identity command returns `smoke4-c3-android`. Every captured command records session `fix4-8-c3`, the isolated runner home, and an unset API environment.

## Forward controls and four endings

The initial `adb forward --list` baseline is empty. The controller then creates two unrelated controls on the owned serial: fixed `tcp:6790 -> tcp:16790` and allocated `tcp:58721 -> tcp:16791`.

| Case | Result | Owned activity observed | Immediate and +1 second result |
|---|---:|---|---|
| Ready foreground interrupt | 130 | exact runner PID `66850`; owned UIA socket and allocated `tcp:58867 -> tcp:6790`; exact Android SIGINT notice retained | both controls remain; owned forwards absent; PID absent; exact-executable/device process inventory empty; project and global sessions empty |
| Normal foreground stop | 0 | exact runner PID `66941`; owned UIA socket and allocated `tcp:59046 -> tcp:6790`; JSON stop response identifies that PID, serial, and port | both controls remain; owned forwards absent; PID absent; exact-executable/device process inventory empty; project and global sessions empty |
| Absent application | 1 | expected launch-flow failure; observed runner process inventory retained | both controls remain; observed PIDs absent; exact-executable/device process inventory empty; project and global sessions empty |
| Healthy stock | 0 | eight steps pass against the stock app; runner PID `67098` retained | both controls remain; PID absent; exact-executable/device process inventory empty; project and global sessions empty |

The interrupt and normal-stop ready inventories distinguish the two controls from the exact case-owned socket and allocated TCP endpoints. Each subsequent immediate and delayed inventory contains exactly the two controls. The absent-app and healthy cases also retain their direct raw failure/pass output and PID/process/session evidence rather than relying on process exit alone.

## Final state

Before controller cleanup, the forward inventory contains exactly the two unrelated controls. The controller removes those two exact local endpoints, after which `adb forward --list` is empty. This proves preservation during product cleanup and explicit controller-owned removal afterward; there is no evidence of a device-wide forward purge or unrelated endpoint deletion.

This was a read-only review of retained raw evidence. I did not rerun tests, invoke the CLI or runner, build an artifact, or perform a device operation.
