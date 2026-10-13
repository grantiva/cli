# Android bare stopApp reports success while the app remains foreground

Severity: wrong-result
Component: runner Android app lifecycle
Rows: B3-L49 [android]
Candidate: runner `fd9d8e8` bundled by CLI `8f2cff676b3c12e951478920fa20e600cdca4e29`.
Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.

## Expected

In a flow whose header supplies `appId`, the standard bare `stopApp` form inherits that app ID, terminates the application, and reports success only after the stop has taken effect. A following `assertNotVisible` may then treat the deliberately stopped app as absent rather than as a crash.

## Actual

The exact flow launches `com.kylebrowning.landmarks` with cleared state, executes bare `stopApp`, then asserts that `Landmarks` is not visible. The report records launch and stop as passed, but the assertion polls the still-visible `Landmarks` element for five seconds and fails. Its failure screenshot shows the Landmarks detail UI rather than the launcher. The UIAutomator2 client log contains the launch and subsequent element queries; the runner log records `stopApp` as successful in 30 ms, but preserves no termination verification.

This is not a launcher-text ambiguity: the matched node and screenshot are from the application itself. It is also not invalid syntax: the parser accepts bare `stopApp`, the executor injects the flow header's effective app ID, and the report identifies the step as `stopApp` with passed status.

## Evidence

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L49-L50-crash-waits-rerun1/input/intentional-stop.yaml`
- `runs/intentional-stop/report/flows/flow-000.json` preserves the passed launch/stop steps and failed still-visible assertion.
- `runs/intentional-stop/report/maestro-runner.log` preserves the 30 ms successful stop result and the five-second wait failure.
- `runs/intentional-stop/report/client.log` preserves the app launch and repeated application-element matches.
- `runs/intentional-stop/report/captures/failure-*.png` preserves the foreground Landmarks screen after the reported stop.
- `summary.json` preserves the bounded batch and the independent L49 crash/live controls.

## Cause boundary

Exact runner source resolves a missing stopApp ID from `flow.Config.EffectiveAppID()` in `pkg/executor/flow_runner.go:507-512`, then dispatches the populated step. Android `pkg/driver/uiautomator2/commands.go:2416-2430` runs `am force-stop <appID>` but treats any zero shell exit as success and does not verify that the package stopped or left the foreground. The evidence establishes the false success and the lack of postcondition verification; it does not by itself distinguish an ineffective shell execution from an immediate application relaunch.

## Acceptance criteria

- On Android, the header-appId flow `launchApp: {clearState: true}` → bare `stopApp` leaves the application stopped and a following `assertNotVisible: "Landmarks"` passes.
- `stopApp` must not report success while the target package remains running or foreground. If termination does not take effect, return a clear lifecycle error naming the application ID.
- Preserve explicit `stopApp: <appId>` and mapping-form behavior as well as bare-form inheritance from the flow header.
- Add focused runner semantic assertions for the inherited-ID path and for an ineffective/failed force-stop, including the observable postcondition rather than only a zero shell exit.
- Preserve intentional-stop crash-watch semantics: a successful stop followed by a not-visible wait is absence, not `app_crash`.
