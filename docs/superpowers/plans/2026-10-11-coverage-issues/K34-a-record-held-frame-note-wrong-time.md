# Android `record`'s held-frame note reports the end of the last frame as the time the last frame appears

Severity: wrong-result
Component: cli
Platforms: android (Android-only: the hold and its note exist only for `screenrecord` output)
Rows: AND-OBS-08 (android); split from cluster C34 record-held-frame-note-unreliable (the intermittent half is K34-b)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
When `record` holds the last frame, the note names the moment that last frame appears, the same value the JSON
report and the written MP4 give for it. docs/android.md:119-123: "Grantiva holds the last frame until `--duration`
... (`actualMilliseconds` is the frame on screen at that moment). When more than half of the requested duration was
held, `record` prints a note on stderr". The note text itself says "The recording's last frame is at <N>ms".

## Actual
`record --device emulator-5554 --duration 2 --frames-at 1000 --output a05.mp4 --json` on an idle screen
(findings/evidence/cov-android/B-A05.1/01.out, 01.err, 02.out):
```
Warning: The recording's last frame is at 100ms; it was held to the requested 2.0s. screenrecord writes frames only when the screen changes, ...
```
The written MP4 has two frames; `ffprobe -show_entries frame=pts_time,duration_time` gives:
```
0.000000,0.050200
0.050200,1.949800
```
and the JSON report says `"actualMilliseconds" : 50` for the frame shown at 1000 ms. The last frame starts at 50 ms;
100 ms is where it ended before the hold (its start plus its original sample delta).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k34a
rm -rf /tmp/k34a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k34a && cd /tmp/k34a/android
SERIAL=$(grantiva emulator ensure --name qa-fix-k34 | tail -1); echo "$SERIAL"
grantiva build install --device "$SERIAL"
grantiva record --device "$SERIAL" --duration 2 --frames-at 1000 --output /tmp/k34a/a.mp4 --json
ffprobe -v error -select_streams v:0 -show_entries frame=pts_time,duration_time -of csv=p=0 /tmp/k34a/a.mp4
# cleanup
grantiva emulator teardown --serial "$SERIAL"
```
Today: the note's millisecond value equals the last frame's `pts_time + duration_time` before the hold, not its
`pts_time` (and not the JSON's `actualMilliseconds`). Any recording with more than one frame shows it.

## Evidence
- findings/evidence/cov-android/B-A05.1/commands.txt, 01.out (JSON, `actualMilliseconds: 50`), 01.err (note "100ms"), 02.out (frame timings), a05.mp4
- findings/evidence/cov-android/AND-OBS-08/commands.txt (points at B-A05.1)

## Suspected cause
- Sources/GrantivaCore/Android/MP4LastFrameHold.swift:80-104 (`holdTrack`): `recordedSeconds` is the sum of all
  `stts` sample deltas (`current`, line 85-89, returned at :104), i.e. the end of the last sample, documented as "its
  last frame's end" (MP4LastFrameHold.swift:15).
- Sources/GrantivaCLI/RecordCommand.swift:103-108 (`heldRecordingNote`) prints that value as "The recording's last
  frame is at \(recordedMs)ms". Either the value or the wording is wrong. The half-duration threshold at :104 uses the
  same value, which is fine for the threshold (the hold starts where the last sample ended).
- Tests/GrantivaCoreTests/MP4LastFrameHoldTests.swift:52-55 pins `recordedSeconds == 0.1` for three 33 ms frames,
  whose last frame starts at about 67 ms, so the existing test encodes the end-of-track meaning.

## Acceptance criteria
- Re-running the repro: the note names the last frame's start time, and it equals the JSON `actualMilliseconds` of a
  frame requested after it (50 ms in the evidence); or the note is reworded to say what the number is ("the screen
  last changed at ..." with the start time, or "the recording ran for 100ms before the hold").
- `Held` exposes the last frame's start time (for example `lastFrameSeconds`) next to `recordedSeconds`, and
  `heldRecordingNote` uses the one its wording describes.
- GrantivaCoreTests/MP4LastFrameHoldTests: for `stts [(3, 3000)]` at timescale 90000, the last frame's start is
  0.0667 s and the track end is 0.1 s; for a single frame both are 0.
- GrantivaCLITests/RecordCommandTests: `heldRecordingNote` for a 2-frame recording (0 ms and 50 ms) held to 2 s names
  50 ms.
