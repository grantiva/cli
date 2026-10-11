# The teardown "runner home could not be removed" error ends with a doubled period (`…access it.. Delete it by hand.`)

Severity: ux
Component: cli
Platforms: ios (`simulator teardown`/`delete`; Android `emulator teardown` has no device home)
Rows: IOS-121 [ios]
Regresses/extends: K69 (teardown leaves device home), fixed by CLI #190. The behaviour holds. This extends K69's message.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
When teardown cannot remove a device's runner home, it exits 1, lists the home under `deviceHomeFailures` (`--json`), and
prints one clean sentence that names the home and the reason, followed by `Delete it by hand.`. No doubled punctuation.

## Actual
The behaviour is right: plain `teardown --udid` removed the home, and with a locked file inside the home it exits 1
naming the home in `deviceHomeFailures`. The message is not
(findings/evidence/cov2-ios/IOS-121/teardown-locked.err, exit 1 in 0.39 s):
```
Error: The simulator was released, but its runner home could not be removed: /Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.11+android-drivers-2/devices/E7A72E2F-ACE1-416B-9194-7DFC126FC6D3: “E7A72E2F-ACE1-416B-9194-7DFC126FC6D3” couldn’t be removed because you don’t have permission to access it.. Delete it by hand.
```
Foundation's description already ends with `.`, and the CLI appends `. Delete it by hand.`. The UDID also appears twice
(path, then Foundation's quoted last component). That is acceptable but noisy. Deterministic, 1 run.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l22
unset GRANTIVA_API_KEY
rm -rf /tmp/l22 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l22 && cd /tmp/l22/ios
UDID=$(grantiva simulator ensure --name fix-l22 --device-type "iPhone 17" --runtime 26.0 | tail -1)
grantiva build install --simulator "$UDID"
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml     # creates the device home
HOME_DIR=$(ls -d "$GRANTIVA_RUNNER_HOME"/versions/*/devices/"$UDID")
touch "$HOME_DIR/locked" && chflags uchg "$HOME_DIR/locked"
grantiva simulator teardown --udid "$UDID"; echo "exit=$?"     # bug: "…access it.. Delete it by hand."
chflags nouchg "$HOME_DIR/locked"; grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name fix-l22
```

## Evidence
- findings/evidence/cov2-ios/IOS-121/teardown-locked.err, teardown-locked.out, lock.out, commands.txt (load 101.19; irrelevant to a text defect)
- findings/evidence/cov2-ios/IOS-121/teardown.out, homes-after-teardown.out, delete.out (the passing halves)
- docs/superpowers/plans/2026-10-11-coverage-issues/K69-teardown-leaves-device-home.md

## Suspected cause
- Each failure is built as `"\(home): \(error.localizedDescription)"` (`Sources/GrantivaCore/Runner/WDADeviceHome.swift:183`).
  Foundation's `localizedDescription` ends with a period.
- `Sources/GrantivaCLI/SimulatorCommand.swift:301-307` (`Teardown.deviceHomeError`) joins the failures and appends
  `". Delete it by hand."`.
- The same pattern is in the warning at `Sources/GrantivaCore/Simulator/SimulatorManager.swift:296`
  (`"Could not remove the runner home \(failure). Delete it by hand."`, the `simulator delete` path).
- `testTeardownFailsWhenARunnerHomeCouldNotBeRemoved` (`Tests/GrantivaCLITests/SimulatorCommandTests.swift:246-252`)
  uses a failure string without a trailing period (`"…/U: denied"`), so it cannot see the doubling.

Fix: trim trailing `.` and whitespace from each failure (or from the joined string) before appending, in both places.
Optionally, drop Foundation's quoted last component, since the path is already named.

## Acceptance criteria
- The error reads `… could not be removed: <home>: <reason without trailing period>. Delete it by hand.`, with exactly
  one period before `Delete`, for one or several failures (`; `-joined).
- The `simulator delete` warning has the same shape.
- Exit code and `deviceHomeFailures` are unchanged.
- Tests: GrantivaCLITests/SimulatorCommandTests, `deviceHomeError(["/r/…/U: “U” couldn’t be removed because you don’t
  have permission to access it."])` produces a message that does not contain `..` and ends with `it. Delete it by
  hand.`. A GrantivaCoreTests case covers the SimulatorManager warning formatter, if it is extracted.
