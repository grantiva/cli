# Android `inputText` replaces the focused field's text instead of appending to it

Severity: wrong-result
Blocking: yes
Platforms: android
Found by: Android slice, flow table row `03-edit` (findings/android-results.md); no original brief. `03-edit` is a stock landmarks-demo flow, and the QA spec (`specs/2026-10-09-qa-campaign-design.md` §Gate (last round's files are on branch `qa-campaign`, commit 8084069; exported copy at `~/.grantiva-qa/briefs/docs/superpowers/`)) requires each app's non-failing flows to pass on its device with the shared binary.
Binary: grantiva 2.1.0 at a278b77, grantiva-runner 1.1.28-grantiva.8, emulator-5554 (AVD `qa-reg-android`, API 35 google_apis arm64, 1080x2400)

## Expected
`.maestro/03-edit.yaml` passes on Android, as it does on iOS 26.0 and 27.0 in this pass (findings/ios-results.md, Step 2)
and as it did on Android in the previous round (grantiva 2.0.1, grantiva-runner 1.1.18-grantiva.7):
```
- tapOn: "Name"
- inputText: " Renamed"
- tapOn: "Done"
- assertVisible: "Golden Gate Bridge Renamed"
```
`inputText` with no selector types into the focused field after its existing text, so the Name field reads
`Golden Gate Bridge Renamed`. README:173, the README's list of supported flow commands, includes `inputText`. The
landmarks-demo spec lists the Edit Landmark text field as the bait for `inputText` and keyboard handling.

## Actual
The flow failed in 4 of 4 runs (run-attempt2-03edit-fail.txt, run.txt, run-continue-on-failure.txt, flow03-rerun.txt). Every
step up to the assert reports success, then the assert times out (flow03-rerun.txt:36-40; the other three runs show the same steps with different timings, e.g. run.txt:159-161 has `inputText` 1.5s and the assert 17.7s):
```
    ✓ tapOn: text="Name" (426ms)
    ✓ inputText: " Renamed" (2.0s)
    ✓ tapOn: text="Done" (394ms)
    ✗ assertVisible: text="Golden Gate Bridge Renamed" (17.3s)
      ╰─ Element not visible: context deadline exceeded: no such element: An element could not be located on the page using the given search parameters
```
grantiva-runner now types with element send-keys on the focused element (flow03-client.log:29-31):
```
14:31:14.135435 GET /session/5b41287a-.../element/active [586.885625ms] OK body=
14:31:14.689930 GET /session/5b41287a-.../element/00000000-0000-0034-0000-00ca00000004/text [554.424333ms] OK body=
14:31:14.763345 POST /session/5b41287a-.../element/00000000-0000-0034-0000-00ca00000004/value [73.353625ms] OK body={"text":"<redacted>"}
```
The failure screenshot (captures/failure-1791667964.png) shows the Edit Landmark sheet still open with the Name field
holding only ` Renamed`: the original `Golden Gate Bridge` is gone.

The previous round, against the same app, typed with W3C key actions and passed (flow03-prior-round-comparison.txt; line 23 of that round's client.log):
```
14:07:59.543073 POST /session/64f5cd03-.../actions [770.134791ms] OK body={"actions":[{"actions":[{"type":"keyDown","value":" "},{"type":"keyUp","value":" "},{"type":"keyDow
report.json statuses: ["passed","passed"]
```

Secondary observation in the same flow: `tapOn: "Done"` clicks `(994,2196)` (flow03-client.log:42, a click
request with offset `{"x":994,"y":2196}`). The keyboard was up at that moment, and
y=2196 lies in the keyboard area near the bottom of the 2400 px screen; the slice reads it as the keyboard's Done
key. The toolbar `Done` button sits at the top right of the sheet (about y=348 in the failure screenshot), and the
sheet stays open. So even with the text appended correctly, the flow would likely not save.

Flow 04-discard also uses `inputText` (`"X"`) and passes, but it never asserts the field's value.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-r01
unset GRANTIVA_API_KEY
rm -rf /tmp/r01 && mkdir -p /tmp/r01 && cp -R /Users/kyle/Developer/landmarks-demo/android /tmp/r01/android && cd /tmp/r01/android
SERIAL=$(grantiva emulator ensure --name qa-fix-r01 | grep -o 'emulator-[0-9]*' | tail -1); echo "$SERIAL"
grantiva build install --device "$SERIAL"
grantiva run --device "$SERIAL" --no-build --flow .maestro/03-edit.yaml --snapshot full --report-dir /tmp/r01/out; echo "exit $?"
grep -n '/value\|/actions\|gestures/click' /tmp/r01/out/client.log | grep -v ERR | cut -c1-200
open /tmp/r01/out/captures/failure-*.png        # Name field holds " Renamed"; sheet still open
# cleanup
grantiva emulator teardown --serial "$SERIAL" && avdmanager delete avd -n qa-fix-r01
```
Today: exit 1 at `assertVisible "Golden Gate Bridge Renamed"`; client.log shows `POST /element/<id>/value` for the
inputText step and a `gestures/click` at y≈2196 for `tapOn "Done"`. If `emulator-5554` is already running before
`ensure`, check that it is not the user's `Pixel_8_API_35` before tearing anything down.

## Evidence
- findings/evidence/android/flow03-rerun.txt (single-flow run with `--snapshot full`), flow03-commands.txt
- findings/evidence/android/flow03-client.log lines 29-31 (`/element/active`, `/text`, `/value`) and 42 (Done click at 994,2196)
- findings/evidence/android/flow03-prior-round-comparison.txt (previous round's `/actions` key events and `passed`)
- findings/evidence/android/captures/failure-1791667964.png, captures-attempt2/failure-1791667837.png,
  captures-continue-on-failure/failure-1791668058.png
- findings/evidence/android/run.txt, run-attempt2-03edit-fail.txt, run-continue-on-failure.txt (lines 159-161)
- findings/ios-results.md Step 2: 03-edit passes on iOS 26.0 and 27.0 with the same binary

## Suspected cause
Bundled grantiva-runner, not this repo. Read from the grantiva-runner source (grantiva/runner main 2f2ee31); not
confirmed on device beyond the client log above.
- `pkg/driver/uiautomator2/commands.go:387-460` (`inputText`): with no selector, the step now calls
  `ActiveElement()` and `SendKeys` on it (`POST /element/{id}/value`), falling back to key actions only when nothing
  has focus. The comment there assumes "the UiAutomator2 server appends rather than replaces". Hypothesis: on this
  Jetpack Compose text field the server's set-text path replaces the value, so the existing text is lost. The
  previous runner sent `POST /actions` key events, which insert at the cursor.
- `core.ConfirmTypedText` (pkg/core, called at the end of `inputText`) does not catch this. Hypothesis: a field whose
  value equals the typed text is classed like a replaced hint, so no warning or retype happens and the step reports `✓`.
- `tapOn "Done"`: hypothesis: with `enableMultiWindows: true` (set at session start, flow03-client.log:2) the
  `text("Done")` lookup also sees the IME window, and the keyboard's action key is matched before the toolbar button.

## Acceptance criteria
- Re-running the repro: exit 0; `assertVisible "Golden Gate Bridge Renamed"` passes; with `--snapshot full` the
  capture after `inputText` shows `Golden Gate Bridge Renamed` in the Name field.
- `tapOn: "Done"` in flow 03 clicks the sheet's toolbar button (client.log click y well above the keyboard area,
  about y=348 on a 1080x2400 screen), and the sheet closes.
- The full Android flow set (`grantiva run --device <serial> --no-build`) passes 12/12, and 99-crash still fails at
  `launchApp` with `LANDMARKS_CRASH_ON_LAUNCH`.
- If the runner changes: the iOS flow set still passes 12/12 on iOS 26.0 and 27.0.
- Runner test: `inputText` with no selector into a focused field that already holds `abc` leaves `abc<typed>` (a fake
  server whose set-value replaces must not pass the test); a typed value that silently replaced non-hint existing text
  is reported, not marked `✓`.
- The bundled runner version is bumped in this repo and the release notes say what changed.
