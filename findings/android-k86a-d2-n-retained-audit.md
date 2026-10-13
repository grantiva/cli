# Android B2-K86-a and retained D2/N audit

Reviewed against the round-3 matrix and CLI candidate `8f2cff67`.

## B2-K86-a [Android] — PASS

`B2-K86-a-handedoff-refusal-rerun2` closes the prior live-runtime gap:

- `start.json` records the detached Android runner, pid 97787 on emulator-5554, and `readiness/1.out` is a successful exact hierarchy dump showing the Landmarks UI. This proves a usable handed-off owner rather than merely a published starting descriptor.
- The exact no-build `01-browse` run refuses in 0.132 s. `refused.err` identifies a ``grantiva runner start`` session, gives the exact pid and project directory, advises `grantiva runner stop`, and does not use the old keep-alive-owner wording.
- `assertions.json` confirms no report was created, the pid and lease stayed live, and the session remained byte-identical. The matching before/after SHA-256 values are both `284b701d...`.
- `stop.json` then stops the exact pid successfully.

The retained keep-alive-owner and dead-owner controls cover their distinct wording branches. Candidate `SimulatorLeaseTests` semantic assertions cover handed-off versus keep-alive classification. This is a full Android half; it does not rely on merely seeing a session file.

## Requested retained-evidence audit

| Row | Disposition | Exact current evidence or smallest gap |
|---|---|---|
| D2-07 [Android] | Fully supported | `B3-L39-install-json-rerun2` contains launched, installed, skipped, and app-file no-launch JSON. The first three are the exact matrix modes; each document has `applicationId`, `appPath` (null for skipped), and device name/serial. Grade from the decoded audit and raw JSON. |
| D2-29 | Partial | The `B2-K15-live-teardown-accepted-rerun3` JSON proves `runnerSessionStopped:true`, session removal, and cleanup. Current AND-146/B2-K30 evidence proves pretty delete JSON. No current-round raw was found for the exact unknown `emulator-5598 --force` success plus pruning a missing recorded AVD even when teardown is refused. Those two K28 branches remain the minimal complement; cov2 cannot be imported. |
| D2-39 [Android] | Fully supported | `B2-K56-X011-MCP076-context-resources-rerun4` supplies the live Android keep-alive context with config source, pid, app ID, serial and `driver_port: (forwarded on attach)`. `D239-X011-MCP076-context-resources-rerun2` retains the platform/config-source complements. Grade the Android half from those exact responses and source audit. |
| N3-04 [Android] | Already fully supported | `D2-38-N3-04-mcp-build-run-rerun2` has exact empty-argument MCP build and run: build leaves adb inventory byte-identical and names module/variant only; run names `Device: cov3-android (emulator-5554)`. The Android ledger already records this pass. |
| N3-05 [Android] | Already fully supported | `N3-05-cli-emulator-reuse-rerun1` gives exact CLI stdout serial plus stderr `Reused cov3-android (emulator-5554) — Booted`; `MCP056-057-emulator-list-boot-rerun1` gives exact MCP `Emulator reused ... already running`. Device inventory is unchanged. The Android ledger already records this pass. |

## Evidence roots

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K86-a-handedoff-refusal-rerun2/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L39-install-json-rerun2/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K56-X011-MCP076-context-resources-rerun4/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/D239-X011-MCP076-context-resources-rerun2/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/D2-38-N3-04-mcp-build-run-rerun2/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/N3-05-cli-emulator-reuse-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/MCP056-057-emulator-list-boot-rerun1/`
