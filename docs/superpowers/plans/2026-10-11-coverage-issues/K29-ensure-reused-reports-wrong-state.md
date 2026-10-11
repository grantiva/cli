# `emulator ensure --name X --no-boot` reports "Reused X — Shutdown" while X is running

Severity: wrong-result
Component: cli
Platforms: android (Android-only)
Rows: AND-110 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/android.md:167 (`grantiva emulator ensure --name Pixel_8_API_35 --no-boot`, "create if missing" without booting):
for an AVD that exists and is already running, the result reports its real state (`Booted`) and serial; `--no-boot`
only means "do not boot it".

## Actual
With `cov-android` running as emulator-5554 (AND-110/01.out, 01.err; `emulator sessions` in 02 shows it running):
```
cov-android
rc=0
Reused cov-android — Shutdown
```
stdout is the AVD name rather than the serial, and the stderr state is wrong. The other documented lines (:166, 168,
169, 171) behaved as their comments say; :170 (`--all`) was blocked by the campaign's constraints.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=fix-k29; unset GRANTIVA_API_KEY
cd /tmp
SERIAL=$(grantiva emulator ensure --name fix-k29); echo "$SERIAL"
grantiva emulator ensure --name fix-k29 --no-boot            # today: stdout "fix-k29", stderr "Reused fix-k29 — Shutdown"
grantiva emulator ensure --name fix-k29 --no-boot --json     # today: state "Shutdown", no serial
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k29
```

## Evidence
- findings/evidence/cov-android/AND-110/01.out, 01.err (`ensure --no-boot`), 02.out (`sessions`: running), commands.txt

## Suspected cause
- `Sources/GrantivaCore/Android/EmulatorManager.swift:369-371` (`ensure`): `guard boot else { return
  EmulatorProvisionResult(name: avd, serial: nil, created: created, state: "Shutdown") }`: with `--no-boot` the state is
  a constant; the running device is never looked up.
- `Sources/GrantivaCLI/EmulatorCommand.swift:40-44` (`render`) prints `result.serial ?? result.name` on stdout and the
  state on stderr, so the missing serial also changes stdout. (The map's "EmulatorCommand.swift:43" is the render; the
  wrong value originates in EmulatorManager.)

## Acceptance criteria
- `ensure --name X --no-boot` when X is running prints the serial on stdout and `Reused X (emulator-5554) — Booted` on
  stderr; `--json` has `state: "Booted"` and `serial`.
- When X exists and is not running: unchanged (`X`, `Reused X — Shutdown`), and nothing is booted.
- When X does not exist: created, `Created X — Shutdown`, unchanged.
- GrantivaCoreTests (EmulatorManagerTests): with a fake adb listing a running emulator whose AVD name is X,
  `ensure(avd: X, boot: false)` returns `Booted` with that serial and does not spawn the emulator.
