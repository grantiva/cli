# iOS attempt 71b lifecycle review

Read-only review of current-round retained evidence against the binding matrix and CLI candidate `8f2cff67`. No device/build/test action was run.

## Fully supported rows

### IOS-014

Supported. `ensure-pre` acquires the directly created simulator under `GRANTIVA_SESSION_ID=cov3-ios-a71`; `build install --no-build --app-file ... --no-launch` under the same ID succeeds on that simulator. The subsequent session inventory has exactly one durable capacity record for that simulator/session, so the second command neither creates a duplicate owner nor changes ownership.

### IOS-015

Supported. Session teardown returns two entries: the pre-existing row-created simulator has `deleted: false` and is left present but Shutdown; the Grantiva-created simulator has `deleted: true` and is absent afterward. Both entries name session `cov3-ios-a71`. The EXIT cleanup manifests subsequently prove both disposable row clones absent without affecting campaign simulators.

### D2-22

Supported. Against the reserved pre-existing clone, a run under `GRANTIVA_SESSION_ID=other` and a run with the variable unset both exit 1 with the exact ownership refusal and remediation. The same flow under `cov3-ios-a71` exits 0. The refusal correctly uses the command `grantiva simulator teardown --session-id cov3-ios-a71` rather than “Teardown” as an imperative.

### B2-K70

Supported. Attempt 71b supplies all three runtime branches required by the brief: foreign and unset IDs refuse, matching ID passes. Exact-head `README.md:699-704` documents reservation and both remedies, `Sources/GrantivaCore/Simulator/SimulatorCapacity.swift:121-123` builds that exact text, and `Tests/GrantivaCoreTests/SimulatorCapacityTests.swift` semantically asserts the named-session refusal. This is not based on the test name alone.

## Partial rows

### D2-21: behavior supported, direct ledger capture missing

The concurrent ensures both exit 0, print the same new UUID, and device inventory proves exactly one simulator with the requested name. One result is `created: true`, the other `created: false`. Session teardown later deletes that simulator as Grantiva-created and only shuts down the pre-existing clone. These behaviors strongly prove provenance was recorded.

However, D2-21 explicitly requires reading the QA home's `simulator-capacity/created.json`. Attempt 71b does not preserve that file or an exact excerpt. Keep D2-21 partial until a retained read proves the UUID/name ledger entry directly; the teardown inference should not silently replace the named input.

### B2-K67: one valid iteration, not 5/5

The single concurrent pair is valid: both calls exit 0 with one shared UUID, one `created: true` and one `created: false`; inventory contains one device; the second call's eventual message says another Grantiva PID is booting that exact device. Earlier `Waiting for simulator capacity (4/4)` lines are truthful because the campaign was actually at the configured limit. The parent-provided capacity-recovery step made a slot available without touching an owner simulator, after which both calls completed.

B2-K67 nevertheless requires 5 of 5 iterations plus exact semantic source assertions for the boot-race and capacity wait distinction. Attempt 71b contains one iteration and no preserved source package for those assertions. It is additive evidence, not a whole-row pass.

## Related evidence integrity

- The directly created pre-existing clone and the Grantiva-created clone have distinct UUIDs and exact name/UUID validation before any cleanup.
- `after-teardown.json` proves only the created clone was deleted and the pre-existing clone was Shutdown.
- `cleanup-before.json` then still contains the pre-existing clone and no created clone; `cleanup-after.json` contains neither. The cleanup error `Invalid device: <created UUID>` is expected from the trap's defensive second delete of an already absent created clone and does not contradict the successful session teardown.
- `post-exit-files.sha256` is a regenerated relative-path manifest, not byte-comparable text to the earlier absolute-path manifest. Artifact hashes shown for shared files are unchanged; the added cleanup files explain the inventory growth.

## L72 steady-state control

iOS attempt 70c completes the pending control: all three plain/quiet/JSON foreground starts reach `state: ready`, expose numeric port 8511, answer hierarchy, then exit 130 with the correct simulator notice and no session remaining. This confines L72's false WDA-timeout behavior to SIGINT during the startup wait. The controller brief has been updated accordingly.

## Evidence

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt71b/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt70c/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Simulator/SimulatorCapacity.swift`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorCapacityTests.swift`
