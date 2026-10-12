# On Android the first `tapOn` after `launchApp` takes 3.7-4.2 s: four clickable-only lookups miss before the plain text lookup answers

Severity: ux
Component: runner
Platforms: android (3 of 3, default `emulator ensure` AVD, software rendering, load 11.4-13.8). The flow passes.
Rows: round3-smoke A1-03edit (findings/evidence/round3-smoke/A1-03edit/)
Regresses/extends: L05 (first find after launchApp; acceptance "03-edit `tapOn \"Deep Links\"` under ~3 s, 3 of 3"). Round-3 runner #22 moved the 5-10 s server hold into launchApp's first-frame wait; the first lookup now costs 0.7-1.5 s, not 5-10 s. Not the L57 cause: L57 is the launch window and crash masking; this is the tap's selector fallback order. They share launchApp's preamble (L57), which makes `launchApp` itself 10.9-13.7 s here.
Binary: grantiva 2.1.0 (main dc965716), grantiva-runner 1.1.28-grantiva.12

## Expected
L05 acceptance: on the default AVD the first find after `launchApp` completes in under 2 s when the element is
present, and 03-edit's `tapOn "Deep Links"` takes under ~3 s, 3 of 3.

## Actual
`✓ tapOn: text="Deep Links"` 3.7 / 4.2 / 3.9 s (A1-03edit/run-1..3.txt). run-1-client.log, after
`launch_app` at 18:18:22.14 and `✓ launchApp (10.9s)` at 18:18:30.60:
```
18:18:31.552051 POST .../element [726.165833ms] ERR:404 body={"strategy":"-android uiautomator","selector":"new UiSelector().text(\"Deep Links\").clickable(true)...
18:18:32.031440 POST .../element [479.136041ms] ERR:404 body=... description(\"Deep Links\").clickabl...
18:18:32.478826 POST .../element [447.131167ms] ERR:404 body=... textMatches(\"(?ims)(?:Deep Links)\"...
18:18:32.710342 POST .../element [231.181375ms] ERR:404 body=... descriptionMatches(\"(?ims)(?:Deep L...
18:18:33.022434 POST .../element [311.71575ms] OK body=... new UiSelector().text(\"Deep Links\")"}
18:18:33.366553 GET .../source [250.918041ms] OK
18:18:33.884735 POST .../appium/gestures/click [455.033375ms] OK body={"offset":{"x":907,"y":2232}}
```
| run | 4 clickable misses | plain lookup | `GET /source` | click | step |
|---|---|---|---|---|---|
| 1 | 1.88 s (726 + 479 + 447 + 231 ms) | 0.31 s | 0.25 s | 0.46 s | 3.7 s |
| 2 | 2.89 s (1472 + 757 + 326 + 331 ms) | 0.13 s | 0.26 s | 0.37 s | 4.2 s |
| 3 | 1.99 s (740 + 856 + 196 + 196 ms) | 0.18 s | 0.32 s | 0.71 s | 3.9 s |

The rest of each step (~0.6 s) is before the first request and after the click. The first request of each flow is
still 2-5x slower than the later ones (0.73-1.47 s vs 0.2-0.48 s), a residual of L05's hold.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l58
unset GRANTIVA_API_KEY
rm -rf /tmp/l58 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l58 && cd /tmp/l58/android
SERIAL=$(grantiva emulator ensure --name fix-l58)
grantiva build install --device "$SERIAL" --no-launch
for i in 1 2 3; do
  grantiva run --device "$SERIAL" --no-build --flow .maestro/03-edit.yaml --report-dir /tmp/l58/r$i > /tmp/l58/r$i.txt 2>&1
  grep -a 'tapOn: text="Deep Links"' /tmp/l58/r$i.txt | head -1
  grep -E 'launch_app|/element |/source|gestures/click' /tmp/l58/r$i/client.log | head -8 | cut -c1-150
done
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l58
```

## Evidence
- findings/evidence/round3-smoke/A1-03edit/commands.txt, run-1..3.txt, run-1..3-client.log,
  run-1..3-maestro-runner.log, run-1..3-flow-000.json
- findings/evidence/round3-smoke/A1/rerun-1.txt (stock set alone at load 12: 12/12 pass)

## Suspected cause
Runner, grantiva/main 2d1b625. Confirmed from the code and the request log.
- `tapOn` with text goes to `findElementForTapWithContext` (`pkg/driver/uiautomator2/driver.go:548-578`, :582-652):
  Step 1 tries every clickable-only strategy (`buildClickableOnlyStrategies`, :662-679: exact text, exact
  description, text regex, description regex, each with `.clickable(true)`), one `POST /element` each; Step 2 checks
  that the text exists (`buildSelectors`); Step 3 reads `GET /source` and resolves the clickable parent. "Deep Links"
  is a Compose text whose clickable node is its parent row, so Step 1 always misses four times before Steps 2-3 find
  it. The misses are paid on every tap on non-clickable text, not only the first; after launch they are slowest
  because the first request still carries part of L05's hold.
- launchApp's 10.9-13.7 s: 2.5-5.2 s of it is the pre-launch preamble (`applyPermissions` with `all: allow`, 27
  `pm grant` shells; see L57) before `launch_app` (client.log: step 0 at 18:18:19.69, `launch_app` 18:18:22.14), and
  8.5-8.6 s the first-frame wait until `Displayed`.

## Acceptance criteria
- 03-edit on the default `emulator ensure` AVD at load 10-15: `tapOn "Deep Links"` under 2 s, 3 of 3 (L05's "under
  ~3 s" is the floor); the flow still passes 3 of 3 and the stock set stays 12/12.
- A tap on text whose node is not clickable costs at most two server requests before the click (for example one
  `GET /source` with the clickable-parent lookup, or the plain lookup followed by the parent resolution), on every tap,
  not only the first; a tap on a clickable text still resolves with one `POST /element`. The order chosen keeps
  today's preference for the clickable match when two nodes carry the same text.
- launchApp's preamble bounded as in L57's acceptance.
- Runner tests in `pkg/driver/uiautomator2` (next to the findElementForTap tests): a fake server where the text node
  is not clickable and its parent is gets at most two requests before the tap and taps the parent's centre; where two
  nodes match and one is clickable, the clickable one is tapped.
