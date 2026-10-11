# A passing step that took 5 s or longer is drawn with the warning glyph `⚠` and no reason, so it reads as a warned step

Severity: ux
Component: runner
Platforms: both (the marker code is driver-independent; seen on iOS 26.0 and 27.0; the Android rows AND-224/AND-228 did not judge the marker)
Rows: IOS-224, IOS-224@27.0, IOS-228 (ios); split from cluster C76 unexplained-warning-marker (the scrollUntilVisible slowness is K76-b); IOS-239, IOS-239@27.0 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`⚠` on a step line means the step passed with a warning, and a `╰─ warning: <reason>` line follows (that is what the
runner prints for a warned step, e.g. inputText's typed-text check). A step whose report.json status is `passed` and
which carries no warning is drawn `✓`. Matrix rows IOS-224 and IOS-228 expect the steps to pass (README:172).

## Actual
FLOWS-26/08-scroll.err:54-56 and :65-67 (live and summary blocks), report.json says `"status": "passed"`:
```
    ⚠ scrollUntilVisible: text="Landmark 70" (32.4s)
    ⚠ scrollUntilVisible: text="Golden Gate Bridge" (34.9s)
    ⚠ scrollUntilVisible (32.4s)
    ⚠ scrollUntilVisible (34.9s)
```
FLOWS-26/09-waits.err:56 and :68: `⚠ extendedWaitUntil: notVisible text="Loading…" (5.2s)` /
`⚠ extendedWaitUntil (5.2s)`. On 27.0 (FLOWS-27/08-scroll.err:36-49) the same with 33.8 s and 36.0 s. No warning
line follows any of them. A 5.2 s wait for a screen that loads after 3 s is normal for that step.


**Absorbed from the iOS fix round.** Also seen on an optional `tapOn` that did not find its element: `⚠ tapOn: id="MapsTrayHeaderSearchField" (7.7s)` in the system-alert Maps flow (evidence `findings/evidence/cov-ios/IOS-151/maps.err`, `findings/evidence/cov-ios/FLOWS-27/21-system-alert-maps.err`).

Result rows (`findings/cov-ios-results.md`):

> | IOS-239 | fail | IOS-151/runner-log-alert-lines.txt, IOS-151/ | Maps prompt auto-accepted, flow passes (as expected), but the optional `tapOn: id="MapsTrayHeaderSearchField"` prints an unexplained `⚠ tapOn: … (7.6-8.1s)` (FLOWS-27/21-system-alert-maps.err, IOS-151/maps.err, IOS-151/maps-noconf.err); same class as IOS-224/IOS-228 |
> | IOS-239@27.0 | fail | FLOWS-27/21-system-alert-maps.*, IOS-151/ | 27.0: Maps prompt auto-accepted, flow passes (as expected), but the optional `tapOn: id="MapsTrayHeaderSearchField"` prints an unexplained `⚠ tapOn: … (7.6-8.1s)` (FLOWS-27/21-system-alert-maps.err, IOS-151/maps.err, IOS-151/maps-noconf.err); same class as IOS-224/IOS-228 |

## Repro
Flows (`ios/.maestro/coverage/09-waits.yaml`, `08-scroll.yaml`):
```
appId: com.kylebrowning.Landmarks
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Slow Screen"
- assertVisible: "Loading…"
- extendedWaitUntil:
    notVisible: "Loading…"
    timeout: 10000
- assertVisible: "Loaded after delay"
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k76a
unset GRANTIVA_API_KEY
rm -rf /tmp/k76a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k76a && cd /tmp/k76a/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k76a iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/09-waits.yaml --report-dir /tmp/k76a/out 2>&1 | grep -A1 'extendedWaitUntil'
python3 -c "import json;d=json.load(open('/tmp/k76a/out/report.json'));print(d['status'])"     # passed
grantiva simulator teardown --session-id fix-k76a
```
Today: `⚠ extendedWaitUntil …` with no `╰─ warning:` line; report `passed`.

## Evidence
- findings/evidence/cov-ios/FLOWS-26/08-scroll.err (54-67), 09-waits.err (56, 68), commands.txt
- findings/evidence/cov-ios/FLOWS-27/08-scroll.err (36-49)

## Suspected cause
grantiva-runner: `⚠` doubles as the "slow step" marker. `pkg/cli/test.go:1676` sets `slowThresholdMs = 5000`;
`pkg/cli/test.go:1769-1779` (live step line) and `pkg/cli/test_unified_output.go:159-170` (summary block) replace `✓`
with `⚠` when a passed step took 5 s or more (`isSlow`), and only colour the duration yellow. The same glyph is set
again at test.go:1782-1784 / test_unified_output.go:172-175 for a real warning (`cmd.Warning`), which is the only
case that prints the `╰─ warning:` explanation. Without colour (CI logs, piped output) the two cases are
indistinguishable. Nested steps do the same (test.go:1811-1823).

## Acceptance criteria
- Re-running the repro: the wait step prints `✓ extendedWaitUntil: notVisible text="Loading…" (5.2s)` (duration may
  stay yellow); the summary block likewise.
- A slow passed step never prints `⚠` unless it also carries a warning; if a slow marker is kept, it is a different
  token that says what it means (for example `✓ … (32.4s, slow)`), in colour and without colour.
- A warned step (e.g. an inputText whose typed value was replaced) still prints `⚠` followed by
  `╰─ warning: <reason>`.
- Runner tests (pkg/cli): rendering a passed command with `Duration >= slowThresholdMs` and empty `Warning` produces
  `✓`; with a non-empty `Warning` produces `⚠` plus the warning line; both for the live, summary and nested paths.
- Bundled runner version bumped in this repo.
