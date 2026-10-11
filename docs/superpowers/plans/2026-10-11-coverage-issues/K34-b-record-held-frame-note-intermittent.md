# Android `record` on an idle screen sometimes prints no held-frame note

Severity: wrong-result
Component: cli
Platforms: android (Android-only)
Rows: AND-124 (android); AND-139 run 2 (android, passed row, same symptom); split from cluster C34 record-held-frame-note-unreliable (the wrong-time half is K34-a)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: possibly not a defect. docs/android.md:121-123 prints the note only "when more than half of the requested duration was held"; a late screen change (status-bar clock tick, a blinking caret, a notification) gives a recording that legitimately needs no note. The slice did not keep frame data for the silent run, so the brief asks first for the diagnostics that tell the two apart.

## Expected
On a static screen, `record --duration 4` prints the held-frame note on stderr every time (matrix AND-124; docs/android.md:119-123;
README:342-344). If the screen did change late in the recording, the output should make that visible rather than
silently print nothing.

## Actual
`record --duration 4` with the landmarks app idle on its home screen, 5 runs (findings/evidence/cov-android/AND-124):
```
# [01] $GRANTIVA record --duration 4 >/dev/null; echo rc=$?; ffprobe ... format=duration
rc=0
4.000000                       <- 01.err is empty: no note
# [02] 4 more runs
run 1 rc=0 note=1 frames=1
run 2 rc=0 note=1 frames=1
run 3 rc=0 note=1 frames=1
run 4 rc=0 note=1 frames=1
```
1 of 5 silent. AND-139 (04): 1 of 3 `--quiet` runs printed no `Warning:` either. Frame count of the silent runs was
not captured.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k34b
rm -rf /tmp/k34b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k34b && cd /tmp/k34b/android
SERIAL=$(grantiva emulator ensure --name qa-fix-k34 | tail -1)
grantiva build install --device "$SERIAL"
for i in $(seq 1 10); do
  grantiva record --device "$SERIAL" --duration 4 --output /tmp/k34b/r$i.mp4 >/dev/null 2>/tmp/k34b/r$i.err
  echo "run $i note=$(grep -c held /tmp/k34b/r$i.err) frames=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 /tmp/k34b/r$i.mp4) last=$(ffprobe -v error -select_streams v:0 -show_entries frame=pts_time -of csv=p=0 /tmp/k34b/r$i.mp4 | tail -1)"
done
# control: freeze the status bar and repeat the loop
adb -s "$SERIAL" shell settings put global sysui_demo_allowed 1
adb -s "$SERIAL" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200
grantiva emulator teardown --serial "$SERIAL"
```
Read the loop: a silent run with `frames=1` (or a last pts under 2 s) is the defect; a silent run whose last frame is
past 2 s is the documented behaviour, and should vanish with the status bar frozen.

## Evidence
- findings/evidence/cov-android/AND-124/commands.txt, 01.out, 01.err (empty), 02.out
- findings/evidence/cov-android/AND-139/commands.txt, 04.out (quiet run without warning)

## Suspected cause
Not located; nothing in the code makes the note random for identical input.
- Sources/GrantivaCLI/RecordCommand.swift:143-149: the note is printed only when `MP4LastFrameHold.holdFile` returns a
  value and `heldRecordingNote` passes its threshold.
- Sources/GrantivaCore/Android/MP4LastFrameHold.swift: `holdFile` returns nil (no note, file untouched) when the track
  already lasts the requested length (:90, `guard current < mediaTarget`), when the file has no `moov`/`stts` it
  understands (:37-43, :80-87), or on arithmetic guards. A silent run with a 4.000 s file fits both "screen changed
  late" and "screenrecord already wrote a 4 s track"; it also fits a malformed or not-yet-finalized MP4 that the
  parser rejects silently (the file is then left at screenrecord's own length, which `ffprobe` would show).
- Sources/GrantivaCLI/RecordCommand.swift:103-104: threshold `requested - recorded > requested / 2`.

## Acceptance criteria
- Diagnose first: the repro loop above, with and without the frozen status bar, records frame count and last pts for
  every silent run, and the brief's fixer states which case it is.
- If silent runs have one frame or a last frame before half the duration: the note prints in 10 of 10 runs; the cause
  (for example an MP4 shape `hold` does not parse, or the file read before screenrecord finished writing it) is fixed
  and `hold` never returns nil silently for a file it could not parse: it logs a debug line naming why.
- If silent runs have a late frame: no code change to the threshold; the JSON report (`--json` and the sidecar
  `.json`) gains the recorded length before the hold (for example `recordedMilliseconds`) so a caller can see why no
  note was printed, and docs/android.md says a late screen change (clock, caret) suppresses the note.
- GrantivaCoreTests/MP4LastFrameHoldTests: a file `hold` cannot parse returns a reason, not a bare nil (or the CLI
  logs it); GrantivaCLITests/RecordCommandTests covers the threshold boundary (held exactly half: no note; more: note).
