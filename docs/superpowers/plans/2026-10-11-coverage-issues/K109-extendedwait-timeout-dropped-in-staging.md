# A Maestro-format `grantiva.yml` loses `extendedWaitUntil`'s `timeout`: the step is staged as a plain `assertVisible`

Severity: wrong-result
Component: cli
Platforms: both (MaestroFlowParser and FlowGenerator serve `diff capture` on both platforms; observed on iOS)
Rows: IOS-142 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:158-172: `grantiva.yml` may be written in Maestro format, and `extendedWaitUntil` (`visible:` or
`notVisible:`) is a supported command. In Maestro, and in the bundled runner when it receives the command as
written, `timeout` sets how long the wait lasts. So `extendedWaitUntil: {visible: "Cache Policy", timeout: 5000}`
should wait up to 5 s for the element, whether the screens are captured from a Maestro-format config or run with
`grantiva run --flow`. If a field cannot be carried over, it should be refused with a message the way unsupported
commands are, not dropped without a word.

## Actual
`findings/evidence/cov-ios/IOS-142/capture.err:40-53` (`diff capture --no-build --simulator $U1 --verbose`), for
the config below:
```
  [1/1] flow (flow.yaml)
    ✓ launchApp (2.0s)
    …
    ✓ tapOn: text="Caching Demo" (965ms)
    ✓ waitForAnimationToEnd (770ms)
    ✓ assertVisible: text="Cache Policy" (356ms)
    ✓ tapOn: id="clock" (886ms)
```
The `extendedWaitUntil` step reaches the runner as `assertVisible: "Cache Policy"`. The runner's default
required-element wait (12 s on WDA, pkg/driver/wda/driver.go:210) then applies instead of the 5000 ms the user set.
A longer `timeout` (e.g. 30000 for a slow network screen) is cut to 12 s and the capture fails; a shorter one is
stretched. The captures themselves were right (IOS-142's main check passed).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k109
unset GRANTIVA_API_KEY
rm -rf /tmp/k109 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k109 && cd /tmp/k109/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k109 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
cp .maestro/coverage/cfg/maestro-format.grantiva.yml grantiva.yml
grantiva diff capture --no-build --simulator "$UDID" --verbose 2>&1 | grep -E 'Cache Policy'
# timing check: an element that never appears, with a 2 s timeout
sed -i '' 's/visible: "Cache Policy"/visible: "No Such Element"/; s/timeout: 5000/timeout: 2000/' grantiva.yml
time grantiva diff capture --no-build --simulator "$UDID" --verbose 2>&1 | grep -E 'No Such Element'
grantiva simulator teardown --session-id fix-k109; grantiva simulator delete --name "fix-k109 iPhone 17"
```
The config (`.maestro/coverage/cfg/maestro-format.grantiva.yml` in the clone):
```
appId: com.kylebrowning.Landmarks
---
- launchApp
- swipe:
    direction: UP
- waitForAnimationToEnd
- takeScreenshot: "Home Swiped"
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- extendedWaitUntil:
    visible: "Cache Policy"
    timeout: 5000
- tapOn:
    id: "clock"
- assertVisible:
    id: "clock"
- takeScreenshot: "Caching Maestro"
```
Today: the first capture logs `assertVisible: text="Cache Policy"`. The second fails at
`assertVisible: text="No Such Element"` after about 12 s rather than about 2 s.

## Evidence
- findings/evidence/cov-ios/IOS-142/capture.err lines 40-53, capture.out line 9 (`Assert visible "Cache Policy"`), commands.txt
- findings/cov-ios-results.md rows IOS-142, B-C07.1

## Suspected cause
- Sources/GrantivaCore/Config/MaestroFlowParser.swift:360-372: `extendedWaitUntil` with `visible`/`notVisible`
  (and the older `{text: X}` form) becomes `.init(assertVisible:…)` / `.init(assertNotVisible:…)`. `val["timeout"]`
  is never read, though the `waitForAnimationToEnd` branch just above (:354-357) does read its `timeout`.
- `GrantivaConfig.Screen.Step` (Sources/GrantivaCore/Config/GrantivaConfig.swift:28-70) has no field for a wait
  timeout, and `FlowGenerator` emits `assertVisible`/`assertNotVisible` through `appendSelector`
  (Sources/GrantivaCore/Runner/FlowGenerator.swift:74-80, :134-147), so there is nowhere to carry it.
- The existing test enshrines the drop: Tests/GrantivaCoreTests/MaestroStandardFormsTests.swift:94-111
  (`testExtendedWaitUntilVisibleBecomesAssertVisible`) parses `timeout: 5000` and asserts only the label.
- Related and not tested this round: `scrollUntilVisible` is also mapped to a plain `assertVisible`
  (MaestroFlowParser.swift:344-349), which drops its scrolling and its own `timeout`.

Fix direction: add an optional wait timeout to `Step` (Maestro-parser only, like `assertVisibleById`) and have
`FlowGenerator` emit `extendedWaitUntil: {visible|notVisible: <selector>, timeout: <ms>}` when it is set.

## Acceptance criteria
- In the repro the step is logged as `extendedWaitUntil` (or the runner's equivalent) with the 5000 ms timeout, and
  the "No Such Element" variant fails after about 2 s.
- `notVisible` with `timeout` behaves the same way; `id:` and `{text, exact}` selectors are kept.
- Without `timeout` the generated step is unchanged.
- Unit tests in `GrantivaCoreTests`: update `MaestroStandardFormsTests.testExtendedWaitUntilVisibleBecomesAssertVisible`
  to assert the 5000 ms is kept, and add a FlowGenerator test asserting the emitted YAML contains
  `extendedWaitUntil:` with `timeout: 5000` for that step.
