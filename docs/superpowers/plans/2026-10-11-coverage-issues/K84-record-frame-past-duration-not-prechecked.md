# `record --frames-at` with a timestamp past `--duration` records the full duration and overwrites the previous video before failing

Severity: ux
Component: cli
Platforms: ios (seen on iOS; the check order is shared with Android, not tested there)
Rows: IOS-082 (ios); original brief C14 (~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/C14-validate-record-arguments-before-recording.md)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Brief C14: record arguments are validated before recording ("A bad `--frames-at` is a usage error (exit 64) before
any recording"). Matrix IOS-082: a clear error for a timestamp past the duration (help: record.txt). A request whose
largest `--frames-at` exceeds `--duration × 1000` can be rejected without touching the simulator.

## Actual
past.out / past.err (`record --simulator <cov-ios-1> --duration 2 --frames-at 5000`, 3.2 s):
```
exit=1
recording-frames
recording.json
recording.mov
Error: Grantiva recording ended at 2175ms before requested frame 5000ms
```
The message is clear, but it comes after a full 2 s recording that replaced `.grantiva/recordings/recording.mov`
(the previous recording is lost), and the exit status is 1, not the usage status 64.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k84
unset GRANTIVA_API_KEY
rm -rf /tmp/k84 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k84 && cd /tmp/k84/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k84 iPhone 17" --runtime 26.0)
grantiva record --simulator "$UDID" --duration 3 --frames-at 0; md5 .grantiva/recordings/recording.mov
time grantiva record --simulator "$UDID" --duration 2 --frames-at 5000; echo "exit=$?"
md5 .grantiva/recordings/recording.mov      # today: changed
grantiva simulator teardown --session-id fix-k84
```

## Evidence
- findings/evidence/cov-ios/IOS-082/commands.txt, past.out, past.err
- findings/help/record.txt (`--duration`, `--frames-at`)

## Suspected cause
- `Sources/GrantivaCLI/RecordCommand.swift:42-44` (`validate()`): parses `--frames-at` but does not compare it with
  `duration`.
- :111-139 (`run()`): boots the device, deletes the existing output (:137) and records (:139) before frames are
  checked; the past-the-end check is in `extractFrames` (:194-198), after the recording.

## Acceptance criteria
- Re-running the repro: the second command exits 64 in well under a second with a message such as
  `--frames-at 5000 is past --duration 2 (2000 ms).`; no recording is started and the previous `recording.mov` is
  unchanged.
- A timestamp equal to `duration × 1000` is accepted; a recording that ends slightly short of a valid timestamp still
  gets today's post-recording error.
- GrantivaCLITests/RecordCommandTests: `--duration 2 --frames-at 5000` fails `validate()` (or fails before the injected
  device's `recordVideo` is called), and `--duration 2 --frames-at 2000` passes validation.
