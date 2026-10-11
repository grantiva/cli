# Android `record --duration 4` can write a 6.16 s video: a screenrecord overrun is never trimmed

Severity: wrong-result
Component: cli
Platforms: android (Android-only: the hold and the overrun exist only for `screenrecord` output)
Rows: found during the round-2 fix wave, Task 8 device check (K34-b loop, run 9); no matrix row
Binary: grantiva fix2/diff-record (PR #191, on top of main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/android.md (Recording): "Grantiva holds the last frame until `--duration`, so a static screen still yields a
video of the requested length"; README: "`grantiva record --duration <s>` writes the video and one PNG per
timestamp". A `record --duration 4` video lasts 4 s whatever the screen did, so a caller that reads the file length
(or seeks to its end) gets the requested length.

## Actual
`record --device emulator-5554 --duration 4 --output r9.mp4 --verbose` on the idle landmarks home screen (AVD
fix2-8-android, android-35 google_apis arm64), run 9 of the K34-b loop:
```
$ ffprobe -v error -select_streams v:0 -show_entries frame=pts_time,duration_time -of csv=p=0 r9.mp4
0.000000,3.078656
3.078656,3.078656
$ ffprobe -v error -show_entries format=duration -of csv=p=0 r9.mp4
6.157300
[debug] … Held frame: frames=2 lastFrame=3079ms trackEnd=6157ms requested=4000ms lastFrameOnScreen=921ms held=0ms noteThreshold=>2000ms note=not printed (the screen changed after the halfway point)
```
The screen changed once, at 3079 ms. screenrecord gave the last sample the previous sample's delta (3079 ms), so the
track ends at 6157 ms, 2157 ms past `--duration 4`. `MP4LastFrameHold` only lengthens a track
(`holdTrack` returns "not held" when the track already reaches the target), so the file stays 6.16 s long, and the
JSON report still says `requestedDurationSeconds: 4`. The other 19 runs of the loop ended at or before 4 s.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME=<scratch>/runner-home GRANTIVA_SESSION_ID=fix-k111; unset GRANTIVA_API_KEY
rm -rf /tmp/k111 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k111 && cd /tmp/k111/android   # 4e49dc4
sed -i '' 's/^emulator: .*/emulator: fix-k111-android/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-k111-android --headless | tail -1)
grantiva build install --device "$SERIAL"
for i in $(seq 1 20); do
  grantiva record --device "$SERIAL" --duration 4 --output /tmp/k111/r$i.mp4 --verbose >/dev/null 2>/tmp/k111/r$i.err
  echo "run $i length=$(ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/k111/r$i.mp4) $(grep -o 'trackEnd=[0-9]*ms' /tmp/k111/r$i.err)"
done
grantiva emulator teardown --serial "$SERIAL"; avdmanager delete avd -n fix-k111-android
```
Today: an occasional run (one change late in the recording) reports `length` above 4.0 and a `trackEnd` above
4000ms. A synthetic file reproduces it without a device: stts `[(1, 277_088), (1, 277_088)]` at timescale 90000
(frames at 0 and 3.079 s) passed to `MP4LastFrameHold.holdFile(atPath:toSeconds: 4)` returns `.unchanged` and the
file stays 6.157 s.

## Evidence
- Task 8 device check (fix2/diff-record, PR #191 body, "record --duration 4 on a static screen"), run 9:
  `findings/evidence/round2-fix-wave/K111/r9.mp4`, `r9.err`, `r9.json` (copied from the Task 8 scratch run; the ffprobe output above is from them), plus `dc-05-record-ios.txt`, `dc-07-k34b-loop.txt`, `dc-08-k34b-control.txt`
- Task 8 report (round-2 fix wave SDD workspace), Concerns item 4

## Suspected cause
- Sources/GrantivaCore/Android/MP4LastFrameHold.swift (`holdTrack`, after PR #191): `guard current < mediaTarget
  else { return .success(false) }`: a track already at or past the target is left as recorded; nothing shortens the
  last sample.
- screenrecord (MediaMuxer/MPEG4Writer) gives the last sample a delta equal to the previous one when it stops, so the
  track end is "last change + previous gap", which can overshoot `--time-limit` by up to the gap.

## Acceptance criteria
- A track whose end is past `--duration` has its last `stts` delta shortened so the track ends at `--duration`
  (never below the last frame's start; if the last frame starts after `--duration`, leave the file and say so in the
  `--verbose` "Held frame:" line); `mdhd`, `tkhd`, `mvhd` and `elst` durations follow.
- Re-running the repro: every `length` is 4.000 (±1 frame tick) and the JSON `recordedMilliseconds` still reports
  the pre-trim track end so the overrun stays visible.
- `--frames-at 4000` on a trimmed file resolves to the last frame, not an error.
- GrantivaCoreTests/MP4LastFrameHoldTests: stts `[(1, 277_088), (1, 277_088)]` at 90000 trimmed to 4 s gives
  `[(1, 277_088), (1, 82_912)]` and `mdhd` 360_000; a file already exactly 4 s is unchanged.
- GrantivaCLITests/MP4LastFrameHoldFixtureTests: an AVAssetWriter-written two-frame movie longer than the request
  still decodes after the trim and lasts the requested length.
