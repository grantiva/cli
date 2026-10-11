# `--snapshot trailing` trims only the `captures/trace/` copy; the report directory still keeps before and after shots of every step

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; the trimming code is shared with Android, not tested there)
Rows: IOS-066 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

Triage note: the cluster map's slug and summary say `--snapshot failure`; the row (matrix IOS-066) and its evidence
are `--snapshot trailing`. This brief is about `trailing`.

## Expected
README:95: "`--snapshot failure|trailing|full` — How many screenshots the runner keeps. … `trailing` keeps the last
good step plus the failing one, `full` captures every step." Matrix IOS-066: last-good plus failing step.

## Actual
snap-trailing.out (`run --flow 02-exact-negative.yaml --snapshot trailing --report-dir …`; the flow fails at step 2):
```
allure-results/0432c175…-attachment.png      (6 attachments in all)
assets/flow-000/cmd-000-after.png
assets/flow-000/cmd-000-before.png
assets/flow-000/cmd-001-after.png
assets/flow-000/cmd-001-before.png
assets/flow-000/cmd-002-after.png
assets/flow-000/cmd-002-before.png
captures/failure-1791704426.png
captures/trace/02-exact-negative-cmd-001-after.png
captures/trace/02-exact-negative-cmd-002-after.png
captures/trace/02-exact-negative-cmd-002-before.png
```
`captures/trace/` holds the trailing set, but `assets/flow-000/` and `allure-results/` hold before and after for
every step, the same set `--snapshot full` writes.

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
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k81
unset GRANTIVA_API_KEY
rm -rf /tmp/k81 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k81 && cd /tmp/k81/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k81 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/02-exact-negative.yaml --snapshot trailing --report-dir /tmp/k81/out
find /tmp/k81/out -name '*.png' | sed 's|/tmp/k81/out/||' | sort
grantiva simulator teardown --session-id fix-k81
```
Today: six `assets/flow-000/cmd-00N-{before,after}.png` and six allure attachments besides the trimmed trace.

## Evidence
- findings/evidence/cov-ios/IOS-066/commands.txt, snap-trailing.out
- Comparison: findings/evidence/cov-ios/IOS-067/snap-full.out (`full`: same assets set)

## Suspected cause
- `Sources/GrantivaCore/Runner/RunnerSession.swift:619-630` (`runnerArtifactMode`): `trailing` maps to the runner's
  `--artifacts always`, so the runner writes every step's before/after into `assets/` and allure.
- :632-720 (`exportTraceArtifacts`): the trailing filter is applied only while copying into `<outputDir>/trace`; the
  report directory's `assets/` and `allure-results/` are left untrimmed. With `--report-dir` that directory is the
  user's artifact home, so the full set is what they keep.

## Acceptance criteria
- Re-running the repro: the report directory holds, besides `captures/failure-*.png`, only the last good step's
  `after` and the failing step's shots (in `assets/flow-000/` and wherever else the report references them), and
  report.json / allure references no deleted file.
- `--snapshot full` still keeps every step; `--snapshot failure` keeps only the failure shot.
- Without `--report-dir` the visible result (`captures/trace/`) is unchanged.
- GrantivaCoreTests/RunnerTraceExportTests: a fixture report dir with before/after for steps 0-2 and a failure at
  step 2, trimmed in `trailing` mode, leaves `cmd-001-after`, `cmd-002-before`, `cmd-002-after` in `assets/` and
  updates or drops the report references to the removed files.
