# On iOS `record --duration 3` of an idle screen writes a video that ffprobe reads as 0.067 s (one frame), with no hold, trim or note, while Android gives exactly 3.000 s

Severity: wrong-result
Component: cli (Grantiva records iOS itself with `simctl io recordVideo`; the runner is not involved)
Platforms: ios (3 of 3, load 15.4-15.9). Android passes (A-record: video and format `duration=3.000000` by ffprobe, 3 of 3, with the idle-screen hold note).
Rows: round3-smoke REC-ios (findings/evidence/round3-smoke/I-record/)
Regresses/extends: K111 and L25 (the Android last-frame hold and trim, MP4LastFrameHold); round-3 CLI #202 (Android record 3.000 s x10). README:372-377 documents the hold for Android only, so part of this is an expectation the docs never stated; the contract below states it for both platforms.
Binary: grantiva 2.1.0 (main dc965716), grantiva-runner 1.1.28-grantiva.12

## Expected
A `record --duration N` recording is N seconds long on both platforms, by any reader (ffprobe and AVFoundation agree),
whether or not the screen changed: a static screen's last frame is held to N, and a recording that ran past N is
trimmed to N. `--frames-at` values map to real times in that video: each frame entry names the requested time and
the presentation time of the frame on screen then (at or before the requested time), computed the same way on both
platforms, and the report carries `lastFrameMilliseconds` / `recordedMilliseconds` on iOS as it does on Android. When
the last frame was held for more than half the recording, iOS prints the same stderr note as Android.

## Actual
I-record/record-1..3.txt (`record --simulator <udid> --duration 3 --output …/ios-<i>.mov --frames-at 0,1500,2900`),
exit 0, wall 4.5-4.7 s:
```
Recording: …/ios-1.mov
Frame report: …/ios-1.json
  0ms -> 0ms: …/ios-1-frames/000000ms.png
  1500ms -> 0ms: …/ios-1-frames/001500ms.png
  2900ms -> 0ms: …/ios-1-frames/002900ms.png
```
I-record/ffprobe-1..3.txt, 3 of 3:
```
stream|codec_type=video|duration=0.066667
format|duration=0.066667
```
No hold note on stderr; `frame-report-1.json` has no `lastFrameMilliseconds` / `recordedMilliseconds`. Checked by the
brief writer on the smoke's `ios-1.mov` (scratch copy, not in the evidence): ffprobe sees one video sample
(`nb_frames=1`, `duration_ts=40` at time base 1/600), while AVFoundation (`AVURLAsset.load(.duration)` and the video
track's `timeRange`) reads 3.045 s. So the container's headers claim 3.045 s (45 ms past the request, untrimmed) and
its only sample lasts 66.7 ms. QuickTime-based readers (and the frame extraction) see 3.045 s; ffmpeg-based readers,
browsers and most upload pipelines see 0.07 s. Android's file of the same idle screen is 3.000 s in both
(A-record/ffprobe-1..3.txt; its report has `lastFrameMilliseconds: 0`, `recordedMilliseconds: 0` and the note
"held to the requested 3.0s").

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l60
unset GRANTIVA_API_KEY
rm -rf /tmp/l60 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l60 && cd /tmp/l60/ios
UDID=$(grantiva simulator ensure --name fix-l60 --device-type "iPhone 17" --runtime "iOS 26.0")
grantiva build install --simulator "$UDID"                       # leaves the app idle on Home
for i in 1 2 3; do
  grantiva record --simulator "$UDID" --duration 3 --output /tmp/l60/ios-$i.mov --frames-at 0,1500,2900
  ffprobe -v error -show_entries format=duration:stream=codec_type,duration,nb_frames -of compact /tmp/l60/ios-$i.mov
done
# a changing screen for comparison: start `grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml`
# in the background and record during it; expect 3.000 s and frames at their real times.
grantiva simulator teardown --udid "$UDID"
```

## Evidence
- findings/evidence/round3-smoke/I-record/commands.txt, record-1..3.txt, ffprobe-1..3.txt, frame-report-1.json
- findings/evidence/round3-smoke/A-record/ (Android comparison: ffprobe 3.000000, frame report with hold fields)

## Suspected cause
CLI, main dc965716. Confirmed from the code; the container detail is from the probe above.
- iOS recording: `IOSPlatform.recordVideo` (Sources/GrantivaCore/Platform/IOSPlatform.swift:193-199, 216-245) runs
  `simctl io <udid> recordVideo --codec=h264 <path>`, sleeps `--duration` after the file appears, and stops it with
  SIGINT. Like `screenrecord`, simctl writes a frame only when the screen changes, so an idle screen gives one sample;
  the movie and track headers then say 3.045 s (about the time simctl ran, not trimmed) while the lone sample
  has a 40/600 s delta.
- The hold and trim run for Android only: `RecordCommand` (Sources/GrantivaCLI/RecordCommand.swift:228-239) calls
  `MP4LastFrameHold.holdFile` under `if platform == .android`; on iOS `heldTiming` stays nil, so the report omits
  `lastFrameMilliseconds` / `recordedMilliseconds` (:255-256) and no note prints.
- Frame extraction (`extractFrames`, :271-325) reads AVFoundation's 3.045 s, so its guard (:283-290) passes and every
  requested time maps to the one sample at 0 ms. Those mappings are true for the file AVFoundation sees; the file
  ffprobe sees has no 1500 or 2900 ms at all.
- `MP4LastFrameHold` (Sources/GrantivaCore/Android/MP4LastFrameHold.swift) rewrites the last `stts` delta and the
  `mdhd`/`tkhd`/`mvhd`/`elst` durations without re-encoding; a QuickTime `.mov` from simctl uses the same boxes, so
  the same rewrite likely applies (to be checked on simctl's files: edit lists, time scale 600).

## Acceptance criteria
- The repro gives `duration=3.000000` for the video stream and the format by ffprobe, and 3.000 s by AVFoundation,
  3 of 3, on an idle screen; also on a changing screen (the `01-browse` comparison), where a recording that ran past 3 s
  is trimmed to 3.000 s.
- The iOS frame report carries `lastFrameMilliseconds` and `recordedMilliseconds` as Android's does; the idle-screen
  note prints on stderr under the same rule (last frame on screen for more than half the recording), with wording that
  does not mention `screenrecord` or a disconnected device on iOS.
- Each `--frames-at` entry's `actualMilliseconds` is the presentation time of the frame shown at the requested time
  in the final file, at or before it, on both platforms (idle screen: 0 ms for all three, as now; changing screen:
  distinct times close to the requested ones).
- README:372-377 states the hold, trim and note for both platforms (`.mov` on iOS, `.mp4` on Android).
- Tests: GrantivaCoreTests next to the MP4LastFrameHold tests: a one-sample `.mov` fixture with simctl's layout
  (time scale 600, sample delta 40, movie duration 1827) is held to 3.000 s and reads 3.000 s back through the same
  parser; a fixture whose movie runs to 3.045 s is trimmed to 3.000 s. GrantivaCLITests: `record` on iOS calls the
  hold (fake platform) and writes the timing fields.
