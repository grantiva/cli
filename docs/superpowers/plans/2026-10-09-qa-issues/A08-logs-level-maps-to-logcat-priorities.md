# Map `--logs-level` values to the documented logcat priorities and reject unknown levels

Severity: contract
Platforms: android
Found by: AND-F12 (matrix rows AND-071, AND-073)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
`--logs-level` accepts `default`, `info`, `debug`, defaulting to `default` (warnings/errors/default). Source: help: run
(`--logs-level  Log level for --logs: default, info, debug. Defaults to \`default\` (warnings/errors/default).`); CHANGELOG
Unreleased (without `--logs-tag` the level "filters every tag at that priority").

## Actual
Counts of `[log]` priority letters in 01-browse runs:
```
no --logs-level        V 5  D 6  I 7  W 14     (no filter: more than debug)
--logs-level default        D 6  I 7  W 14     (same as debug)
--logs-level info                I 7  W 14
--logs-level debug          D 7  I 7  W 14
--logs-level warning                  W 14     (undocumented value, exit 0)
```
The stream also starts with `adb logcat -c`, which clears the whole device buffer for every other consumer.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
count() { grep '\[log\]' | awk '{print substr($4,1,1)}' | sort | uniq -c | tr '\n' ' '; echo; }
grantiva run --no-build --flow .maestro/01-browse.yaml --device emulator-5554 --logs 2>&1 | count
grantiva run --no-build --flow .maestro/01-browse.yaml --device emulator-5554 --logs --logs-level default 2>&1 | count
grantiva run --no-build --flow .maestro/01-browse.yaml --device emulator-5554 --logs --logs-level debug 2>&1 | count
grantiva run --no-build --flow .maestro/01-browse.yaml --device emulator-5554 --logs --logs-level warning; echo "exit $?"
```

## Evidence
- findings/evidence/AND-071/stderr.txt, AND-073/{info,debug,explicit-default,warning,tag-debug}.stderr

## Suspected cause
Sources/GrantivaCore/Android/AndroidPlatform.swift:183-190 uses `level.first` as the priority letter, so `default` -> `D`
and `warning` -> `W`; a nil level adds no filter at all. :175 runs `logcat -c`. Sources/GrantivaCLI/RunCommand.swift:32-33
declares `logsLevel` as a free `String?` with no validation.

## Acceptance criteria
- Re-running the repro: no flag and `default` both give the same set (I and above, or W and above, whichever the help
  is changed to state precisely); `debug` adds D; `info` gives I and above; `warning` exits 64 naming the valid values.
- `--logs-level` becomes a validated enum shared by iOS and Android, with an explicit Android mapping table
  (default -> `*:I` or `*:W`, info -> `*:I`, debug -> `*:D`) documented in docs/android.md.
- Drop `logcat -c`; start at the current time instead (`-T 1` or `-T '<now>'`).
- GrantivaCoreTests/AndroidPlatformTests: `logStream(level:)` for nil/default/info/debug yields the mapped `-s *:X`
  arguments and never `logcat -c`; GrantivaCLITests/RunCommandTests: `--logs-level warning` fails validation.
