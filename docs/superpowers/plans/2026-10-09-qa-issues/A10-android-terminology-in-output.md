# Use Android terminology in Android output, JSON keys and ownership remediation, and drop the stray " exited with code 1" suffix

Severity: ux
Platforms: ios, android
Found by: AND-F21, AND-F09 (matrix rows AND-021, AND-031, AND-024, AND-063)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
Android output names emulators, serials and application IDs, and remediation names `grantiva emulator ...` commands.
Source: docs/android.md (terminology, §Emulator subcommand); README §Agent-Native Features, Concurrent runs ("with guidance
to provision a unique simulator").

## Actual
A second run on a serial owned by a `--keep-alive` run (exit 1 after 1 s, after printing `Emulator booted: ...`):
```
Error: Simulator emulator-5554 is already owned by another Grantiva run (pid 30332, started 60s ago, grantiva-runner pid
30364, --keep-alive). Release it with `grantiva simulator teardown --udid emulator-5554 --force`, or run against a
different simulator via `grantiva simulator ensure --name <unique-name>`. exited with code 1
```
`build install --no-launch --json`:
```
{ "appPath" : ".../app-free-debug.apk", "bundleId" : "com.kylebrowning.landmarks",
  "simulator" : { "name" : "Pixel_8_API_35", "udid" : "emulator-5554" }, "status" : "installed" }
```
`run` prints `Resolved: scheme=(none) simulator=emulator-5554 screens=0 flows=1`; a failed build prints `Scheme: (none)`
(also in MCP `grantiva_build`); record and boot-timeout errors end in ` exited with code 1`.
Out of scope here: `No screens or flows configured in grantiva.yml` (C18) and help overviews (D04).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva build install --no-launch --json
grantiva run --no-build --flow .maestro/05-category.yaml --device emulator-5554 --keep-alive --ready-file /tmp/a10.ready & pid=$!
while [ ! -f /tmp/a10.ready ]; do sleep 0.2; done
grantiva run --no-build --flow .maestro/05-category.yaml --device emulator-5554 2>&1 | tail -2
kill -INT $pid; wait $pid
grantiva build build --variant noSuchVariant | grep Scheme
```

## Evidence
- findings/evidence/AND-063/{log.txt,settings-after-refused-run.txt}, AND-021/stdout.json, AND-031/log.txt
- findings/evidence/AND-024/nosuch.txt, AND-013/log.txt, AND-017/log.txt, AND-079/log.txt

## Suspected cause
- Sources/GrantivaCore/Runner/SimulatorLease.swift:118-133 (`ownershipMessage`) is platform-blind.
- Sources/GrantivaCLI/BuildCommand.swift:228-243 (`InstallResult`: `bundleId`, `simulator {name, udid}`).
- Sources/GrantivaCLI/RunCommand.swift:161 (`Resolved: scheme=... simulator=...`).
- Sources/GrantivaCore/Output/TableOutput.swift:41-45 prints `Scheme:` whenever `productPath` is nil (all failures).
- Sources/GrantivaCore/GrantivaError.swift:44-45 renders every `.commandFailed(msg, code)` as `"\(msg) exited with code"`,
  including messages that are full sentences (record, ownership, boot timeout).
- The refused run also wrote a failure screenshot of the other run's device into `.grantiva/captures/android/`.

## Acceptance criteria
- Re-running the repro on Android: the refusal says `Emulator emulator-5554 ...` and suggests
  `grantiva emulator teardown --serial emulator-5554 --force` / `grantiva emulator ensure --name <unique-name>`; no
  ` exited with code 1` suffix; no failure screenshot of a device the run never owned.
- `build install --json` on Android emits `applicationId` and `device: {name, serial}` (keep iOS keys unchanged; note the
  JSON change in CHANGELOG). `run` narrates `Resolved: module=app variant=freeDebug device=emulator-5554 ...`; Android
  build failures print no `Scheme:` line.
- `.commandFailed` gains a message-only form (or the suffix is only added for real subprocess names).
- Tests: SimulatorLeaseTests asserts the Android message names `grantiva emulator`; InstallCommandTests asserts the
  Android JSON keys; TableFormatterTests asserts no `Scheme:` for a failed Android build.

## iOS detail (IOS-F13, IOS-F36)
The stray " exited with code 1" suffix is not Android-specific. On iOS it follows capacity timeouts, runner failures,
the ownership error and record errors:
```
Error: Timed out after 5s waiting for a Grantiva simulator slot (limit 2). Active: ... Release one with
`grantiva simulator teardown --session-id <id>`. exited with code 1
Error: Runner failed (exit 1):
 exited with code 1
Error: ... requested frame 5000ms exited with code 1
```
Repro:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
GRANTIVA_MAX_SIMULATORS=1 GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS=5 \
  grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0 2>&1 | tail -1
grantiva record --simulator qa-ios-1 --duration 2 --output /tmp/a10.mov --frames-at 5000 2>&1 | tail -1
grantiva simulator delete --name qa-ios-2
```
Evidence (qa-ios worktree): findings/evidence/triage/F13.err, F36-cap.err; IOS-012/err.txt, IOS-029/err.txt,
IOS-060/err.txt, IOS-082/err.txt. Cause: Sources/GrantivaCore/GrantivaError.swift:44-45 (shared by both platforms).
The "Runner failed" case comes from RunnerSession.swift:116-124, where the runner's stderr suffix is often empty.
Extra acceptance criteria: no iOS error ends in ` exited with code N` unless it names a subprocess; an empty runner
stderr yields "Runner failed (exit 1); see the runner output above." GrantivaErrorTests covers a sentence message.
