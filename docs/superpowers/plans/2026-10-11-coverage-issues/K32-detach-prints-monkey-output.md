# Launching an app that is not installed fails with monkey's raw argument dump as the error text

Severity: contract
Component: cli
Platforms: android (Android-only)
Rows: AND-OBS-04 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: the row attributes the `data=...` lines to `runner start --detach`, but the evidence does not support
that. In AND-010/02 the command was `build install --device emulator-5556 --no-build --app-file <apk> 2>&1 | tail -3;
runner start --detach --device emulator-5556`, so the first three lines of 02.out are the last three lines of
`build install`, not runner output. `runner start --detach` sends the runner's stdout and stderr to its log file
(Sources/GrantivaCLI/DriverCommand.swift:287-305), and grantiva's own adb calls capture both streams
(Sources/GrantivaCore/Shell.swift:15-19), so neither can print monkey output directly. The likely chain: `--no-build`
made `build install` skip the install (K25) on a fresh AVD, the launch then ran `monkey` for a package that was not
installed, monkey failed, and grantiva printed monkey's stderr as its `Error:` message; `tail -3` kept its last three
lines. The brief is rewritten around that defect; the orchestrator may instead close AND-OBS-04 as a misattribution.
Not reproduced on device by this writer.

## Expected
When `build install` (or any grantiva launch) cannot start the app, the error says so in one line, e.g.
`com.kylebrowning.landmarks is not installed on cov-android-2 (emulator-5556); install it first or drop --no-launch`,
and stdout carries only the command's result. `runner start --detach` prints only its own result block on stdout.

## Actual
AND-010/02.out (stdout of the pipeline above; the stderr of `runner start` is 02.err, `Starting runner...`):
```
data="android.intent.category.LAUNCHER"
arg="--pct-syskeys" mCurArgData="null" mNextArg=5 argwas="--pct-syskeys" nextarg="0"
data="0"
Runner started (detached)
  UIAutomator2 port: 53095
  PID:      27331
```
These are lines of `monkey`'s argument trace (`adb shell monkey -p <id> -c android.intent.category.LAUNCHER
--pct-syskeys 0 1`). The `Error:` line that should precede them was cut off by `tail -3`. 1 of 1 runs.

## Repro
Separate the two commands so their output cannot mix:
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k32
unset GRANTIVA_API_KEY
rm -rf /tmp/k32 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k32 && cd /tmp/k32/android
SERIAL=$(grantiva emulator ensure --name fix-k32)             # fresh AVD: app not installed
# 1. launch of an uninstalled app (K25 makes --no-build skip the install)
grantiva build install --device "$SERIAL" --no-build > /tmp/k32/bi.out 2> /tmp/k32/bi.err; echo "build install exit $?"
echo "--- stdout"; cat /tmp/k32/bi.out; echo "--- stderr"; cat /tmp/k32/bi.err
# 2. runner start on its own
grantiva runner start --detach --device "$SERIAL" > /tmp/k32/rs.out 2> /tmp/k32/rs.err
grep -c 'data=\|arg=' /tmp/k32/rs.out /tmp/k32/rs.err     # expected 0 and 0
grantiva runner stop; grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k32
```
Expected today (hypothesis): step 1 exits 1 with an `Error:` whose text is monkey's argument trace; step 2 prints no
monkey lines.

## Evidence
- findings/evidence/cov-android/AND-010/02.out, 02.err, commands.txt (entry [02] shows the piped `build install`)
- Row pointer: findings/evidence/cov-android/AND-OBS-04/commands.txt
- Related: K25 (`--no-build` skips the install that `--app-file` asked for)

## Suspected cause
- `Sources/GrantivaCore/Android/ADB.swift:83-85` (`launch`) runs `shell monkey -p '<id>' -c
  android.intent.category.LAUNCHER --pct-syskeys 0 1` and does no pre-check that the package is installed.
- `Sources/GrantivaCore/Shell.swift:38-44`: on a non-zero exit the thrown `commandFailed` message is the child's whole
  stderr (or stdout), i.e. monkey's multi-line argument trace, with no summary.
- Callers: `BuildCommand.swift:178-181` (`completeInstall` → `device.launch`), and any other launch path.

## Acceptance criteria
- Step 1 of the repro exits 1 with a single-sentence error naming the application ID and the device and saying it is
  not installed (detected via `pm path <id>` or monkey's "No activities found"), and no `data=`/`arg=` lines on either
  stream. (Once K25 is fixed, reproduce with `build install --no-build` on a device without the app.)
- Step 2 prints nothing from monkey; stdout is only the `Runner started (detached)` block.
- A launch that fails for another reason shows at most the last meaningful monkey line, not the argument trace.
- GrantivaCoreTests (ADBTests): `launch` with a fake executor that fails with monkey's trace throws an error whose
  message names the package and contains no `arg=` text.
