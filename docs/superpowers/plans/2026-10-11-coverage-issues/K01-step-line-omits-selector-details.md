# Step lines drop the `index`, `point` and `start`/`end` a tap or swipe used, so the output cannot say what was tapped

Severity: ux
Component: runner
Platforms: both (Android AND-207/208/220; iOS confirmed for point taps on 26.0 and 27.0, IOS-208; IOS-207/IOS-220 passed on behaviour and their step lines were not judged)
Rows: AND-207, AND-208, AND-220 (android); IOS-208, IOS-208@27.0 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
The live step line, the summary block and the runner log name the selector the step actually used, including its
`index`, a `point:` tap's coordinates and a `start:`/`end:` swipe's endpoints. Sources: matrix AND-207 ("the step line
shows the selector used"), AND-208 and AND-220 (reclassified into the same class in fix round 1); README:172 lists
`swipe` with `start:`/`end:` and the selector forms. A direction swipe already prints its direction and a
`[swipe] Using screen coords` line, and a text tap prints `text="..."`, so the other forms are the odd ones out.

## Actual
Behaviour is right in every row (Mono Lake opens, `Last tap: center`, `Last swipe: left`); only the narration is wrong.

`tapOn {text: "(Lake .*|.* Lake)", index: 1}` (AND-044/01.err:44, live line) prints no index:
```
    ✓ tapOn: text="(Lake .*|.* Lake)" (731ms)
```
`tapOn {point: "50%,50%"}` prints an empty target, on Android (CF-04-point-taps/out-cf-04-point-taps.stderr:34-38) and
on iOS 26.0 (FLOWS-26/04-point-taps.err:55) and 27.0 (FLOWS-27/04-point-taps.err:37):
```
    ✓ tapOn:  (31ms)
    ✓ tapOn:  (145ms)
    ✓ tapOn:  (63ms)
```
`swipe {start: "80%, 50%", end: "20%, 50%"}` is a bare `swipe`, with no coordinates line, while its neighbours have one
(CF-05-swipe-forms/out-cf-05-swipe-forms.stderr:43-47):
```
[swipe] Using screen coords: (540,480) → (540,2160)
    ✓ swipe: DOWN (327ms)
    ✓ assertVisible: text="Last swipe: down" (53ms)
    ✓ swipe (324ms)
```
The summary block names only the command type for every step (`✓ tapOn (731ms)`, AND-044/01.err:61-83), so it
cannot disambiguate either.

## Repro
Android:
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k01
unset GRANTIVA_API_KEY
rm -rf /tmp/k01 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k01 && cd /tmp/k01/android   # main 4e49dc4
SERIAL=$(grantiva emulator ensure --name fix-k01); echo "$SERIAL"
grantiva build install --device "$SERIAL" --no-launch
for f in 01-selectors 04-point-taps 05-swipe-forms; do
  grantiva run --device "$SERIAL" --no-build --flow .maestro/coverage/$f.yaml 2>&1 | grep -E '^\s+[✓✗] (tapOn|swipe)|\[swipe\]'
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k01
```
iOS (same flows under `ios/.maestro/coverage/`):
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k01
rm -rf /tmp/k01 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k01 && cd /tmp/k01/ios
UDID=$(grantiva simulator ensure --name "fix-k01 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva run --simulator "$UDID" --no-build --flow .maestro/coverage/04-point-taps.yaml 2>&1 | grep 'tapOn'
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k01 iPhone 17"
```
The flows involved (android copy; the iOS copy differs only in `appId`):
```
# 04-point-taps.yaml
- tapOn: "Deep Links"
- tapOn: "Gesture Lab"
- tapOn:
    point: "50%,50%"
- assertVisible: "Last tap: center"
# 01-selectors.yaml (excerpt)
- tapOn: "Lakes"
- tapOn:
    text: "(Lake .*|.* Lake)"
    index: 1
- assertVisible: "Lee Vining, CA"
# 05-swipe-forms.yaml (excerpt)
- swipe:
    start: "80%, 50%"
    end: "20%, 50%"
- assertVisible: "Last swipe: left"
```

## Evidence
- findings/evidence/cov-android/AND-044/01.err lines 44 (live) and 73 (summary): index form
- findings/evidence/cov-android/CF-04-point-taps/out-cf-04-point-taps.stderr lines 34-38, 47-51: point taps
- findings/evidence/cov-android/CF-05-swipe-forms/out-cf-05-swipe-forms.stderr lines 34-50: start/end swipe
- findings/evidence/cov-ios/FLOWS-26/04-point-taps.err lines 55-59, 68-72; findings/evidence/cov-ios/FLOWS-27/04-point-taps.err lines 37-41
- Row pointers: findings/evidence/cov-android/AND-207/, AND-208/, AND-220/ (commands.txt)

## Suspected cause
Shared flow package in the runner (release-round1, ae48e34), so both drivers print the same lines:
- `pkg/flow/step.go:1056-1058` `TapOnStep.Describe` returns `"tapOn: " + s.Selector.DescribeQuoted()` and ignores
  `Point` (field at step.go:178). With only a point set, `DescribeQuoted()` returns `""`, hence `tapOn:  `.
  `DoubleTapOnStep`/`LongPressOnStep` (:1062-1069) share the gap.
- `pkg/flow/selector.go:296-352` `describeParts` renders text/id/css/... and `exact=true` but never `Index`
  (selector.go:37), so `index: 1` vanishes.
- `pkg/flow/step.go:1138-1143` `SwipeStep.Describe` returns `"swipe"` when `Direction` is empty, dropping
  `Start`/`End` (step.go:246-247). The `[swipe] Using screen coords` line is printed only by
  `swipeWithMaestroCoordinates` (pkg/driver/uiautomator2/commands.go:1226), not by the `start:`/`end:` path
  (`swipeWithCoordinates`, :1233).
- Summary block: `pkg/cli/test_unified_output.go:144-151` prints `cmd.Label`, falling back to `cmd.Type`; the label is
  empty for these commands, so the summary shows `tapOn` only.

## Acceptance criteria
- Live line, summary block and runner log for the repro read (wording may differ, content may not):
  `tapOn: text="(Lake .*|.* Lake)", index=1`, `tapOn: point="50%,50%"`, `swipe: start="80%, 50%" end="20%, 50%"`.
  Same for `doubleTapOn`/`longPressOn` with `point:`, and for `swipe` with absolute `start`/`end`.
- No step line ends in `tapOn:` followed by blanks.
- iOS 26.0/27.0 and Android print identical descriptions for the same flow.
- Runner unit tests (pkg/flow): `Describe()` for a point tap, an index selector and a start/end swipe returns
  the strings above; a selector with only `index` set is not described as empty.
