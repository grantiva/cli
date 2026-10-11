# Android runs narrate a "GrantivaAgent session" and "releasing simulator" although Android uses UIAutomator2 on an emulator

Severity: ux
Component: cli (plus three runner strings)
Platforms: android (Android-only: iOS X-001 passed, GrantivaAgent is correct there)
Rows: N-15, X-001 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix N-15 (plan N15; round-1 smoke; docs/android.md:3-4 says Grantiva runs the same commands against an Android
emulator) and X-001 (README:308): Android narration names the Android driver (UIAutomator2) and the emulator, never
"GrantivaAgent" (the iOS agent) or "simulator".

## Actual
Stock Android run (AND-106/02.err:102):
```
Running 12 flow(s) in one GrantivaAgent session: .maestro/01-browse.yaml, .maestro/02-favorite.yaml, ...
```
`run --keep-alive` and its release on Android (AND-051/ka.err:8, :78, :82, :84):
```
Running 1 flow(s) in one GrantivaAgent session: .maestro/01-browse.yaml
  GrantivaAgent keep-alive: session=79748-1791702867086124000
[grantiva] received SIGINT — releasing simulator and reaping child processes
  Releasing GrantivaAgent session...
```
`run --help` describes `--keep-alive` as "Keep GrantivaAgent session alive" for both platforms.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k11
unset GRANTIVA_API_KEY
rm -rf /tmp/k11 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k11 && cd /tmp/k11/android
SERIAL=$(grantiva emulator ensure --name fix-k11)
grantiva build install --device "$SERIAL" --no-launch
grantiva run --device "$SERIAL" --no-build --flow .maestro/01-browse.yaml 2>&1 | grep -n 'GrantivaAgent\|simulator'
grantiva run --device "$SERIAL" --no-build --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/k11/ready > /tmp/k11/ka.out 2> /tmp/k11/ka.err &
KA=$!; while [ ! -f /tmp/k11/ready ]; do sleep 1; done; sleep 2; kill -INT $KA; wait $KA
grep -n 'GrantivaAgent\|simulator' /tmp/k11/ka.err
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k11
```
Today: four matching lines (`... GrantivaAgent session`, `GrantivaAgent keep-alive`, `releasing simulator`,
`Releasing GrantivaAgent session...`).

## Evidence
- findings/evidence/cov-android/AND-106/02.err line 102
- findings/evidence/cov-android/AND-051/ka.err lines 8, 78, 82, 84; AND-059/ (keep-alive release)
- findings/evidence/cov-android/AND-030/01.err (X-001 Android half)
- Row pointers: findings/evidence/cov-android/N-15/commands.txt, X-001/commands.txt

## Suspected cause
- CLI: `Sources/GrantivaCLI/RunCommand.swift:426` logs `"Running N flow(s) in one GrantivaAgent session: ..."` with no
  platform check (the `deviceNoun` used at :290-292 is in scope); `RunCommand.swift:20` is the `--keep-alive` help.
- CLI: `Sources/GrantivaCore/Runner/SignalRelay.swift:162` writes `releasing simulator and reaping child processes` for
  every platform.
- Runner (release-round1, ae48e34): `pkg/cli/keepalive.go:147`, `:149` (`GrantivaAgent keep-alive: ...`) and `:159`
  (`Releasing GrantivaAgent session...`) are platform-blind.

## Acceptance criteria
- An Android run prints `Running 12 flow(s) in one UIAutomator2 session: ...`; the keep-alive banner and release lines
  name UIAutomator2 (or a neutral "runner session"); the signal line says `releasing emulator` on Android and
  `releasing simulator` on iOS.
- `grep -c GrantivaAgent` over the Android repro's stderr is 0; the iOS repro still says GrantivaAgent.
- `run --help` words `--keep-alive` for both platforms (e.g. "Keep the runner session (GrantivaAgent on iOS,
  UIAutomator2 on Android) alive ...").
- Tests: GrantivaCLITests asserts the session narration for `.android` and `.ios`; a runner test in pkg/cli asserts
  the keep-alive banner names UIAutomator2 for the Android platform.
