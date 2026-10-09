# Hold the last frame to the requested duration in Android recordings so `--frames-at` works on static screens

Severity: wrong-result
Platforms: android
Found by: AND-F14 (matrix rows AND-076, AND-079)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
A video of the requested duration plus one PNG per requested timestamp. Source: help: record (`--duration`,
`--frames-at`); docs/android.md §Recording.

## Actual
Idle screen, `record --duration 2 --frames-at 1000 --json`, twice in a row:
```
Error: Grantiva recording ended at 0ms before requested frame 1000ms exited with code 1
```
`ffprobe -show_entries packet=pts_time` shows one packet at `0.000000`. In a 4 s static recording with one late change,
every frame came back at frame 0:
```
"actualMilliseconds" : 0, ... "requestedMilliseconds" : 500
"actualMilliseconds" : 0, ... "requestedMilliseconds" : 1500
"actualMilliseconds" : 0, ... "requestedMilliseconds" : 3500
```
With UI motion during the recording, frames are correct (978 ms for 1000).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
# leave the emulator on any idle screen
grantiva record --device emulator-5554 --duration 2 --frames-at 1000 --output /tmp/a05.mp4 --json; echo "exit $?"
ffprobe -v error -show_entries packet=pts_time -of csv /tmp/a05.mp4
```

## Evidence
- findings/evidence/AND-079/log.txt (static failures and ffprobe), AND-076/log.txt, AND-076/recording.json

## Suspected cause
`screenrecord` writes frames only when the screen changes (variable frame rate), so a static screen yields a single frame
at 0 ms. Sources/GrantivaCLI/RecordCommand.swift:139-149 treats the asset's duration as the recording's length and
throws; :160-162 asks AVAssetImageGenerator for each time with zero tolerance, which snaps to the only frame.
Sources/GrantivaCore/Android/AndroidPlatform.swift:261-271 records with plain `screenrecord --time-limit`.

## Acceptance criteria
- Re-running the repro: exit 0, a PNG at 1000 ms, `actualMilliseconds` reported as the frame actually shown (the held
  frame), and the mp4's duration is ~2 s (e.g. remux with the last frame held to the requested length, or treat a
  requested time past the last frame as "last frame" on Android).
- On iOS the current strict check is kept unless the same VFR behaviour applies.
- GrantivaCLITests/RecordCommandTests: a fixture mp4 with one frame at 0 and requested duration 2 s returns a frame for
  1000 ms instead of throwing; a test that `requestedMilliseconds` beyond the requested duration still throws.
