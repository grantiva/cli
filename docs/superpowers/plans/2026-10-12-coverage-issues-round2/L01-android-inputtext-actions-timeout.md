# Android inputText fails on the fixed 10 s HTTP timeout of the key-actions request even though the text was typed

Severity: wrong-result
Component: runner
Platforms: android (Android-only: UIAutomator2 key-actions path; iOS 03-edit passes in 1.0 s)
Rows: round2-A1-03edit, round2b-A1-03edit, round2b-AB (runner .9 vs .10); also blocks round2-A1 / round2b-A1 (04-12 skipped)
Binary: grantiva 2.1.0 (main 5eab55d), grantiva-runner 1.1.28-grantiva.10

## Expected
`inputText: " Renamed"` (no selector, after tapping the Name field holding "Golden Gate Bridge") types the eight
characters and passes, then 03-edit asserts "Golden Gate Bridge Renamed". Typing finishes within the step's own timeout
on any supported API 35 AVD, including the software-rendered one `grantiva emulator ensure` creates. If one transport
request outlives its deadline, the runner checks whether the field already holds the text before failing the step, and
the request deadline comes from the step timeout, not a fixed 10 s.

## Actual
3 of 3 alone on the quiet-host AVD (13.8 / 13.6 / 13.7 s), 3 of 3 on the loaded round2 AVD (12.3-13.7 s), and every
stock run (2/12 flows, 04-12 skipped). Round 1 (runner .9, another AVD): 2.8 s pass. Runner .9 driven directly on the
same AVD fails the same way (15.6 s; .10: 13.2 s), so this is a latent defect, not a .10 regression.
round2b-A1-03edit/run-1.txt:36-38 and run-1-client.log:29-31:
```
    ✓ tapOn: text="Name" (926ms)
    ✗ inputText: " Renamed" (13.8s)
      ╰─ Failed to input text: send request: Post "http://localhost/session/536d37ba-.../actions": context deadline exceeded (Client.Timeout exceeded while awaiting headers) (cause: <same text>)
GET  /session/536d37ba-.../element/active [2.288403792s] OK
GET  /session/536d37ba-.../element/00000000-0000-0029-0000-00cd00000004/text [712.082167ms] OK
POST /session/536d37ba-.../actions [10.002600125s] ERROR: ... context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```
The other two runs time out at 10.0025 s and 10.0014 s. The failure screenshot of the loaded run
(round2-A1/failure-03-edit.png) shows the field reading "Golden Gate Bridge Renamed" with the cursor at the end: the
step's effect completed, the transport timeout failed it. A single-character `inputText "X"` (04-discard) passes in 7.1 s.
The AVD renders in software: config.ini `hw.gpu.enabled=no`, resolved to `hw.gpu.mode = lavapipe`, SurfaceFlinger GLES
"ANGLE (... SwiftShader Device ...)" (round2b-A0/ensure.txt:10-28).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l01
unset GRANTIVA_API_KEY
rm -rf /tmp/l01 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l01 && cd /tmp/l01/android
SERIAL=$(grantiva emulator ensure --name fix-l01)          # default AVD: hw.gpu.enabled=no -> lavapipe
grep hw.gpu ~/.android/avd/fix-l01.avd/config.ini           # expect hw.gpu.enabled=no
grantiva build install --device "$SERIAL"
for i in 1 2 3; do
  grantiva run --device "$SERIAL" --no-build --flow .maestro/03-edit.yaml --report-dir /tmp/l01/r$i > /tmp/l01/r$i.txt 2>&1; echo "run $i exit $?"
  grep -E 'inputText' /tmp/l01/r$i.txt | head -2; grep '/actions' /tmp/l01/r$i/client.log
done
grantiva emulator teardown --serial "$SERIAL"; avdmanager delete avd -n fix-l01
```
Runner-only A/B (no grantiva): `~/.grantiva-qa/runner/versions/1.1.28-grantiva.<v>+android-drivers-2/grantiva-runner
--platform android --device "$SERIAL" test --output /tmp/l01/ab<v> .maestro/03-edit.yaml` for v = 9 and 10.

## Evidence
- findings/evidence/round2-smoke/round2b-A1-03edit/run-1..3.txt, run-<i>-client.log (lines 29-31), run-<i>-maestro-runner.log (step 5)
- findings/evidence/round2-smoke/round2-A1-03edit/run-1..3.txt, run-1-client.log, summary.txt
- findings/evidence/round2-smoke/round2-A1/failure-03-edit.png (text fully typed), run.txt, run-attempt1-parallel-with-ios.txt
- findings/evidence/round2-smoke/round2b-AB-runner/03-edit-runner-9.txt:31, 03-edit-runner-10.txt:31
- findings/evidence/round2-smoke/round2b-A0/ensure.txt (GPU facts); round2b-A1/run.txt (stock set 2/12)

## Suspected cause
Runner (release-round2, 56224e1).
- Fixed client timeout: `pkg/uiautomator2/client.go:50` (unix socket) and `:63` (TCP) set `http.Client{Timeout: 10 * time.Second}`
  for every request. `pkg/uiautomator2/transport.go:146` builds the request with `http.NewRequest` (no context) and `:192`
  sends it with `c.http.Do`, so the step timeout never reaches the request; a long but healthy call is cut at 10 s.
- All characters go in one request: `pkg/uiautomator2/device.go:41-65` (`SendKeyActionsWithDelay`) posts every keyDown/keyUp
  pair in a single `POST /actions`, and the server answers only after it has injected them all. Injection is slow on
  this AVD (the same AVD's 20-step drag `/actions` take 4.0-7.3 s, see L03; a 1-character `inputText` took 7.1 s), so
  16 key events exceed 10 s. Not measured per event.
- No completion check after a failed send: `pkg/driver/uiautomator2/commands.go:447-449` returns
  `Failed to input text: ...` as soon as `SendKeyActions` errors; the `waitForFieldChange` check at `:457` (defined `:565`)
  that could see the field already holds `before + text` is only reached on success.
- `connectionFailure` classifies `Client.Timeout exceeded` as not a lost connection, so `doWithRetry`
  (transport.go:156-163) returns it at once; correct (the request is not replayable), but it means nothing else recovers it.

## Acceptance criteria
- On a software-rendered API 35 AVD (`emulator ensure` defaults, `hw.gpu.mode` resolving to lavapipe), 03-edit passes 3 of
  3 runs alone and inside the stock set (12/12 with 10-seed-many per L03), and `inputText " Renamed"` finishes within the
  step timeout.
- A request that is still in progress when a fixed transport deadline would have expired is governed by the step's
  deadline instead (context from the step, or a per-request timeout at least the remaining step time); no UIAutomator2
  call is cut at a hard-coded 10 s while its step still has time.
- If the key-actions request does time out, the runner reads the focused field; when it holds the expected
  `before + text`, the step passes (optionally with a note that the server answered late); otherwise it fails naming
  UIAutomator2 and the timeout, without repeating the cause.
- Typing does not grow linearly into the timeout: either chunk long text into several `/actions` requests or size the
  deadline from the character count; an 8-character append on the slow AVD takes well under the step timeout.
- Runner tests: pkg/uiautomator2 — a fake server that answers `/actions` after 12 s with a 30 s step context succeeds,
  and one that never answers fails at the step deadline, not at 10 s. pkg/driver/uiautomator2 (next to
  input_append_test.go) — `SendKeyActions` returns a timeout error but the fake field then reads
  "Golden Gate Bridge Renamed": `inputText` succeeds; the field still reads "Golden Gate Bridge": it fails.
