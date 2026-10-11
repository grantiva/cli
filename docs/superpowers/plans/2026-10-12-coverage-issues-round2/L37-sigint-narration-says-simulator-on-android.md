# On Android an interrupted foreground `runner start` announces "releasing simulator"

Severity: ux
Component: cli
Platforms: android (3 of 3 SIGINT endings: plain, `--quiet`, `--json`; logical). The keep-alive `run` path says `emulator` correctly (X-004 [android]).
Rows: AND2-OBS-04 [android] (seen in N2-15 [android])
Regresses/extends: extends K04 (runner #17) and K11 (#193, runner #19): Android output labelled with iOS terms.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
The interrupt notice names the device kind being released: `releasing emulator` on Android, as
`grantiva run --keep-alive` prints (findings/evidence/cov2-android/X-004/r-int.err:30):
```
[grantiva] received SIGINT — releasing emulator and reaping child processes
```

## Actual
findings/evidence/cov2-android/N2-15/fg-int.err:28, fg-quiet.err:2, fg-json.err:2 (foreground `runner start --device
emulator-5554`, then `kill -INT`):
```
[grantiva] received SIGINT — releasing simulator and reaping child processes
```
It is printed even with `--quiet` and `--json` (stderr), so every Android foreground session that is interrupted says
`simulator`.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l37
unset GRANTIVA_API_KEY
rm -rf /tmp/l37 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l37 && cd /tmp/l37/android
sed -i '' 's/^emulator: .*/emulator: fix-l37/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l37)
grantiva build install --device "$SERIAL" --no-launch
grantiva runner start --device "$SERIAL" > /tmp/l37/fg.out 2> /tmp/l37/fg.err &
FG=$!
until grantiva runner dump-hierarchy --format json > /dev/null 2>&1; do sleep 0.5; done
kill -INT $FG; wait $FG; echo "exit $?"
grep -a 'received SIGINT' /tmp/l37/fg.err      # expected: releasing emulator
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l37
```

## Evidence
- findings/evidence/cov2-android/N2-15/fg-int.err, fg-quiet.err, fg-json.err, commands.txt
- findings/evidence/cov2-android/X-004/r-int.err (the `run` path, correct)

## Suspected cause
- `Sources/GrantivaCore/Runner/SignalRelay.swift:38` defaults the noun to `"simulator"`; `:44-47` documents it as
  "Set by whoever starts the runner"; the notice is built at `:49-50` and written at `:173`.
- Only `RunnerExecution.swift:106` sets it (`request.platform == .android ? "emulator" : "simulator"`), on the `run`
  path.
- The `runner start` paths in `Sources/GrantivaCLI/DriverCommand.swift` register with the relay (`:434`
  `track(group:)`, `:435` `onTermination`, `:509` in `holdForeground`) but never set `deviceNoun`; `startDetached`
  (`:332`) has the same gap if it is interrupted during start-up.

## Acceptance criteria
- The repro prints `[grantiva] received SIGINT — releasing emulator and reaping child processes` on Android (plain,
  `--quiet`, `--json`); iOS still prints `simulator`.
- Every entry point that registers with `SignalRelay` sets the noun from its platform (or the relay takes the noun with
  `track`/`onTermination`, so no caller can forget it); grep shows no caller of `SignalRelay.shared.track` without it.
- Test in GrantivaCoreTests/SignalRelayTests.swift: `announcement` for Android says `emulator`; and in
  GrantivaCLITests/RunnerLifecycleCommandTests.swift: the foreground `runner start` set-up for an Android launch
  leaves `SignalRelay.shared.deviceNoun == "emulator"` (reset it in tearDown).
