# `--verbose` logs short shell commands but never the long-running subprocesses: the runner, `adb logcat`, `log stream`, `simctl io recordVideo`

Severity: ux
Component: cli
Platforms: both (Android AND-OBS-07; iOS IOS-154, and the `--verbose` half of IOS-152/IOS-153)
Rows: AND-OBS-07 (android); IOS-154 (ios); verbose half of IOS-152, IOS-153 (ios; rows placed in C19)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:390: "`--verbose` — adds debug-level detail, with timestamps and labels, including every subprocess Grantiva runs
and its exit status." Matrix AND-137/138, IOS-152/153/154: `--verbose` stderr shows every subprocess with its exit
status.

## Actual
Short commands are logged (`[debug] ... $ xcrun simctl list devices --json` / `exit 0: ...`), but processes grantiva
keeps running are not:
- Android `run --logs --verbose` (AND-073/01.out): grepping the verbose stderr for `logcat` finds nothing, while `ps`
  during the run shows the stream grantiva started (AND-073/05.out):
  ```
  /Users/kyle/Library/Android/sdk/platform-tools/adb -s emulator-5554 logcat --uid=10207 -v time -T 1791703206.000 -s *:I
  ```
- iOS `record --duration 2 --json --verbose` (IOS-154/verbose.err): 14 debug lines, all `simctl list devices --json`
  and `simctl getenv`; no `simctl io <udid> recordVideo` line.
- iOS `run --flow 08-caching.yaml --logs --verbose` (B-I07.2/verbose.err): 24 debug lines (simctl list/getenv/
  get_app_container/status_bar, plutil); no grantiva-runner launch and no `simctl spawn <udid> log stream`.
- IOS-152/IOS-153 and AND-137/AND-138: the runner launch is never listed with its arguments or exit status.
(Frame extraction in `record` is in-process, AVAssetImageGenerator at Sources/GrantivaCLI/RecordCommand.swift:201, so it
is not a subprocess; IOS-154's mention of it is out of scope.)

## Repro
iOS:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k33
unset GRANTIVA_API_KEY
rm -rf /tmp/k33 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k33 && cd /tmp/k33/ios
UDID=$(grantiva simulator ensure --name "fix-k33 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva record --simulator "$UDID" --duration 2 --json --verbose 2>&1 >/dev/null | grep -c 'recordVideo'                 # today 0
grantiva run --simulator "$UDID" --no-build --flow .maestro/08-caching.yaml --logs --verbose 2>&1 >/dev/null \
  | grep '^\[debug\]' | grep -c 'grantiva-runner\|log stream'                                                            # today 0
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k33 iPhone 17"
```
Android: Android prelude (see K01), then
`grantiva run --device "$SERIAL" --no-build --flow .maestro/08-caching.yaml --logs --verbose 2>&1 >/dev/null | grep '^\[debug\]' | grep -c 'logcat\|grantiva-runner'` (today 0).

## Evidence
- findings/evidence/cov-android/AND-073/01.out (no `logcat` in verbose output), 05.out, 06.out (`ps` shows it), commands.txt
- findings/evidence/cov-ios/IOS-154/verbose.err, plain.err, quiet.err, commands.txt
- findings/evidence/cov-ios/B-I07.2/verbose.err (run --logs --verbose); IOS-152/verbose.err; IOS-153/verbose.err
- Row pointer: findings/evidence/cov-android/AND-OBS-07/commands.txt

## Suspected cause
The only subprocess logging is in `GrantivaCore.shell` (Sources/GrantivaCore/Shell.swift:24 `$ <command>` and :35
`exit N: <command>`). Long-lived processes are started elsewhere and bypass it:
- Runner: `ChildProcess.spawn` (Sources/GrantivaCore/Runner/ChildProcess.swift:38-...), called from
  `RunnerExecution.run` (Sources/GrantivaCore/Runner/RunnerExecution.swift, spawn before :66) and the detached/foreground
  `runner start` paths (Sources/GrantivaCLI/DriverCommand.swift:297-304 and the foreground equivalent).
- Log streams: `LogStreamer.start(executable:arguments:)` (Sources/GrantivaCore/Runner/LogStreamer.swift:115-154) runs a
  `Process` directly; it covers `adb logcat` and `simctl spawn ... log stream`.
- Recording: `IOSPlatform` builds the `simctl io <udid> recordVideo` `Process` at
  Sources/GrantivaCore/Platform/IOSPlatform.swift:179-189 (Android's `screenrecord` path should be checked the same way).

## Acceptance criteria
- Under `--verbose`, each long-running subprocess gets a `$ <executable> <args>` debug line when it starts and an
  `exit N: <executable>` (or `stopped by SIGINT`) line when it ends, in the same format as `shell`: the runner (with its
  arguments), `adb logcat`, `simctl spawn ... log stream`, `simctl io ... recordVideo`, Android `screenrecord`.
- Without `--verbose`, none of these lines print.
- Secrets in arguments or environment (API keys) are not logged.
- GrantivaCoreTests (LogStreamerTests, ChildProcessTests or RunnerExecutionTests): with a captured logger at debug level,
  starting and stopping a stub process emits the start and exit lines.
