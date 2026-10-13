# iOS 78b reaper side finding and Android S2-01 / D2-38 review

Candidate provenance: Grantiva CLI `8f2cff67`. This review is read-only and makes no product or device changes.

## iOS attempt 78b: real collateral-process defect in `--force` discovery

**Finding: product defect; attempt 78b is not valid completion evidence for the intended N3 helper lifecycle.** The helper was a legitimate Python orchestrator, not a process holding the simulator. Its executable was `python3`; the Grantiva binary path and owned UDID appeared only as positional arguments used to launch and observe the actual foreground runner. Nevertheless, `grantiva simulator teardown --udid … --force --json` sent SIGINT to the helper's process group. The preserved traceback ends in `KeyboardInterrupt` while Python was waiting for teardown, `helper.exit.txt` is 130, and the helper therefore never wrote teardown stdout/stderr or its later sidecar observations. The actual foreground command separately received teardown and printed `Runner stopped by teardown (pid 17051); the session has ended.`

Evidence:

- `cov3-ios/findings/evidence/cov3-ios-attempt78b/n3-helper.py` receives `<grantiva-path> <udid>` in `sys.argv`, starts the true foreground process in a separate session, then invokes force teardown.
- `cov3-ios/findings/evidence/cov3-ios-attempt78b/helper.err` is the Python `KeyboardInterrupt` in `subprocess.run(... capture_output=True)`; `helper.exit.txt` is `130`.
- `cov3-ios/findings/evidence/cov3-ios-attempt78b/foreground.err` shows the independent foreground runner's normal teardown notice.

The source mechanism is direct. [`SimulatorReaper.swift`](/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Simulator/SimulatorReaper.swift:118) lowercases the **whole command line**, requires only that it contain the UDID, and classifies it as `.grantiva` whenever any argument creates a `"grantiva "` substring. This differs from the same file's `isGrantivaProcess` at line 149, which parses the first executable token and accepts only basename `grantiva` or `grantiva-runner`. The public force help in [`SimulatorCommand.swift`](/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/SimulatorCommand.swift:113) limits live inspection to Grantiva runner/WDA/diagnose processes holding the simulator; README lines 604–615 likewise describes processes actually owning it. A Python harness which merely mentions both values is outside that scope.

Existing semantic tests do not cover this collision. [`SimulatorReaperTests.swift`](/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorReaperTests.swift:39) rejects an unrelated `sleep`, but its command contains neither trigger string; the positive Grantiva case uses an actual Grantiva executable.

A bounded regression test needs no simulator: feed `processes(owning:psOutput:)` a synthetic line such as `python3 helper.py /path/to/grantiva <UDID>` and assert it is excluded while `/opt/homebrew/bin/grantiva run … --simulator <UDID>` remains included. If runtime corroboration is desired, use only a row-owned harmless sleeping Python process with those two positional arguments and assert force discovery does not signal it. The source semantic test is sufficient to pin the faulty classifier and avoids another device action.

The parent's corrective 78c fixture, which removes the binary path and UDID from the helper argv and watches the actual runner PID, can establish the intended row behavior. It does not disprove this independently observed false-positive defect.

## Android S2-01: supported

`findings/evidence/cov3-android/S2-01-inputtext-three-runs-rerun1/` satisfies the row. All three exact standalone `.maestro/03-edit.yaml` invocations exited 0, retained reports assert pass, and their `inputText: " Renamed"` steps took 2.0, 1.9, and 2.1 seconds, with no 10-second HTTP timeout. The evidence records one-minute host loads of 6.78125, 6.5869140625, and 13.1455078125. The guest property read was empty, and the evidence discloses that limitation; the provenance-verified owned AVD `config.ini` supplies `hw.gpu.enabled=no`. The current Android pass row is supported.

## Android D2-38 and N3-04

The earlier `D2-38-N3-04-mcp-build-run-rerun1/` is only corroboration because it supplied explicit module/variant/emulator arguments rather than the matrix-required empty objects.

The completed `D2-38-N3-04-mcp-build-run-rerun2/` corrects that input. Its retained requests call `grantiva_build {}` and `grantiva_run {}`. Build returns success, module `app`, variant `freeDebug`, duration, warnings, errors, and APK product path; `adb devices -l` is byte-identical before and after build. Run returns `App built and launched.`, module/variant, application ID, owned device name/serial, and the same APK path. These artifacts support D2-38 `[android]`, MCP-030, MCP-035, and N3-04 `[android]` as currently graded. The iOS halves remain independent.

