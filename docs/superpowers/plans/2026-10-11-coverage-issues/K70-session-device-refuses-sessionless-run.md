# A run with no `GRANTIVA_SESSION_ID` is refused on a simulator a named session owns; the README does not say so, and the message uses "Teardown" as a verb

Severity: docs
Component: docs
Platforms: ios (iOS-only: simulator capacity path; no Android twin expected)
Rows: IOS-122 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:449-455 (host policy) describes what a run does on an already-booted simulator: "A run against an
already-booted simulator takes no slot … Without `GRANTIVA_SESSION_ID`, a slot taken by a run lasts only while that
run's process is alive". Matrix row IOS-122 read this as: a session-less run on the booted cov-ios-1 takes no slot
and runs. If the refusal is the intended policy, the README should state it, and the refusal should read as an
instruction.

## Actual
cov-ios-1 was booted by `simulator ensure` under `GRANTIVA_SESSION_ID=cov-ios`. With the variable unset, the run is
refused before the runner starts (run.err, exit 1):
```
Booting simulator: A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF
Error: Simulator cov-ios-1 (A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF) belongs to Grantiva session cov-ios. Teardown that session or select another simulator.
```
On a simulator booted with `simctl` (cov-ios-3, no Grantiva record) the same session-less run passes and takes no
slot (run3.out), which matches the README. So the README sentence holds only for simulators Grantiva did not boot;
a device booted under a named session refuses every run that does not carry that session ID, and nothing in the
README says so. "Teardown that session" uses the noun as a verb and does not give the command
(`grantiva simulator teardown --session-id cov-ios`) or the alternative (`GRANTIVA_SESSION_ID=cov-ios`).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"
unset GRANTIVA_API_KEY
rm -rf /tmp/k70 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k70 && cd /tmp/k70/ios   # 4e49dc4
UDID=$(GRANTIVA_SESSION_ID=fix-k70 grantiva simulator ensure --name "fix-k70 iPhone 17" --runtime 26.0)
GRANTIVA_SESSION_ID=fix-k70 grantiva build install --simulator "$UDID" --no-launch
unset GRANTIVA_SESSION_ID
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml; echo "exit=$?"
GRANTIVA_SESSION_ID=fix-k70 grantiva simulator teardown --session-id fix-k70
```
Today: exit 1 with the `belongs to Grantiva session fix-k70. Teardown that session …` line.

## Evidence
- findings/evidence/cov-ios/IOS-122/commands.txt, run.err (refusal), run.out
- findings/evidence/cov-ios/IOS-122/create3.out, boot3.out, run3.out (simctl-booted device: run passes, no slot)

## Suspected cause
- Behaviour: `Sources/GrantivaCore/Simulator/SimulatorCapacity.swift:110-116` (`reserve`): an existing record for the
  UDID whose `sessionId` differs from the caller's owner (a session-less caller's owner is `simulator:<udid>`, :99)
  throws. `SimulatorManager.boot` (SimulatorManager.swift:101-106) skips `reserve` only when the booted device has no
  record, which is why simctl-booted devices are fine.
- Message: SimulatorCapacity.swift:113-114.
- Docs gap: README:449-455 and the matrix row's reading of it.

## Acceptance criteria
- README (host-policy paragraph, README:449-455) states that a simulator booted under a named
  `GRANTIVA_SESSION_ID` is reserved for that session: a run with another or no session ID is refused, and how to use
  it anyway (set the same `GRANTIVA_SESSION_ID`, or end the session with
  `grantiva simulator teardown --session-id <id>`).
- The refusal reads, for example: `Simulator cov-ios-1 (<udid>) belongs to Grantiva session cov-ios. Run with
  GRANTIVA_SESSION_ID=cov-ios, end that session with `grantiva simulator teardown --session-id cov-ios`, or select
  another simulator.` No "Teardown" as a verb.
- If the team decides instead that a session-less run may use such a device without taking a slot, the run in the
  repro passes and `simulator sessions --json` is unchanged; README states that.
- GrantivaCoreTests/SimulatorCapacityTests: the refusal text for a foreign-session record contains
  `grantiva simulator teardown --session-id <id>` and `GRANTIVA_SESSION_ID=<id>`.
