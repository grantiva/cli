# A `run` that fails on element-not-found or not-visible gives no `Run grantiva hierarchy …` hint, unlike the MCP tools

Severity: contract
Component: cli
Platforms: both (iOS confirmed here; the Android X-019 half also lacks the hint, and its selector-less message is tracked in C02)
Rows: B-C21.1, X-019 (ios); original brief C21 (~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/C21-remediation-names-real-commands.md)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Brief C21 criterion 1: "element-not-found says `Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to
inspect the tree.`". Matrix X-019: the same failure line structure and remediation on both platforms. The MCP tools
already print that sentence (N-13, MCP-025).

## Actual
X-019/ios-02-exact-negative.err (iOS 26.0, `run --flow .maestro/coverage/02-exact-negative.yaml`, exit 1):
```
    ✗ assertVisible: text="Golden Gate.*", exact=true (12.6s)
      ╰─ Element not visible: text='Golden Gate.*' (cause: … closest on-screen texts: …)
Failure screenshot: …
Error: Runner failed (exit 1); see the runner output above.
```
The same for element-not-found (N-05 flows: `Element not found: text='No Such' …`, then the generic `Runner failed`
line). No remediation is printed. `simulatorNotRunning` and the doctor clauses of C21 were not reachable on this host
and are not part of this brief.

## Repro
Flow (`ios/.maestro/coverage/02-exact-negative.yaml`):
```
appId: com.kylebrowning.Landmarks
---
- launchApp
- assertVisible: "Golden Gate.*"
- assertVisible:
    text: "Golden Gate.*"
    exact: true
```
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k93
unset GRANTIVA_API_KEY
rm -rf /tmp/k93 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k93 && cd /tmp/k93/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k93 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/02-exact-negative.yaml 2>&1 | tail -4
printf 'appId: com.kylebrowning.Landmarks\n---\n- launchApp\n- tapOn: "No Such"\n' > /tmp/k93/nosuch.yaml
grantiva run --no-build --simulator "$UDID" --flow /tmp/k93/nosuch.yaml 2>&1 | tail -4
grantiva simulator teardown --session-id fix-k93
```
Today: neither tail shows `Run grantiva hierarchy`.

## Evidence
- findings/evidence/cov-ios/X-019/commands.txt, ios-02-exact-negative.err
- findings/evidence/cov-ios/FLOWS-26/02-exact-negative.err, findings/evidence/cov-ios/N-05/flow1.err
- MCP side for comparison: findings/evidence/cov-ios/N-13/run/transcript.txt, findings/evidence/cov-ios/MCP-025/
- Android half: cov-android results X-019 (after merge: findings/evidence/cov-android/X-019/)

## Suspected cause
- The hint exists only in `GrantivaError.elementNotFound` (`Sources/GrantivaCore/GrantivaError.swift:35`), which only
  the MCP/WDA client path throws.
- A `run` failure goes through `RunnerSession.failureMessage(reason:stderr:)`
  (`Sources/GrantivaCore/Runner/RunnerSession.swift:17-22`), called at :503-521 with
  `Runner failed (exit N)`; it does not look at the failed step's error type, which report.json records
  (`element_not_found` / `assertion` from the runner's `classifyError`). `RunnerFailureReport` already reads
  report.json on failure and is the natural place to add it.

## Acceptance criteria
- Re-running the repro: after the runner's failure line, both runs print
  `Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree.` once (for keep-alive runs it may
  say to run `grantiva hierarchy` in another terminal while the session is held). Exit 1 unchanged.
- The hint appears only for element-not-found / not-visible failures, not for crashes, timeouts or build errors.
- Android prints the same hint (X-019 android).
- GrantivaCoreTests/RunnerSessionReportTests (or RemediationCommandTests in GrantivaCLITests): a failed report whose
  failing command has `error.type` `element_not_found` or `assertion` with a not-visible message yields the hint;
  `app_crash` does not.
