# `run --snapshot full` (and `trailing`) reports every per-step trace shot as a captured screen and copies it into `captures/`

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; the collector is shared with Android, not tested there)
Rows: IOS-067 (ios); split from cluster C82 run-artifacts-treated-as-screens (the shared `.grantiva/captures` half is K82-b)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:95: `--snapshot full` "captures every step" (a trace for debugging); README:172: "Each `takeScreenshot`
becomes a named screen capture point." Matrix IOS-067: a screenshot per step. The screen list on stdout and the
`captures/` directory contain the takeScreenshot points only; the step shots belong in `captures/trace/`.

## Actual
snap-full.out (`run --no-build --flow .maestro/01-browse.yaml --snapshot full --report-dir …`, exit 0):
```
  01-browse-cmd-000-after
    ✓ Run flow "01-browse"

  01-browse-cmd-000-before
    ✓ Run flow "01-browse"
  …
  01-browse-cmd-007-Landmark Detail
    ✓ Run flow "01-browse"
  …
  Screens: 18 total, 18 passed, 0 failed
```
Only `01-browse-cmd-003-Home` and `01-browse-cmd-007-Landmark Detail` are takeScreenshot points; the other 16 are
step trace shots, and all 18 are copied into `<report-dir>/captures/` next to the real captures (without
`--report-dir`, into `.grantiva/captures/`, where `diff` then treats them as screens: K82-b).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k82a
unset GRANTIVA_API_KEY
rm -rf /tmp/k82a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k82a && cd /tmp/k82a/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k82a iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml --snapshot full --report-dir /tmp/k82a/out | grep 'Screens:'
ls /tmp/k82a/out/captures/
grantiva simulator teardown --session-id fix-k82a
```
Today: `Screens: 18 total, 18 passed, 0 failed`; `captures/` lists the `-before`/`-after` files beside the two real
captures.

## Evidence
- findings/evidence/cov-ios/IOS-067/commands.txt, snap-full.out

## Suspected cause
`Sources/GrantivaCore/Runner/RunnerArtifactCollector.swift:28-92` (`collect`): every `.png` in each flow's
`assets/<flow-id>/` (:56-58) becomes a `ScreenCapture` and is copied to `outputDir`. With `--snapshot trailing|full`
the runner is asked for `--artifacts always` (`RunnerSession.swift:621-629`), so `assets/` also holds
`cmd-NNN-before.png` / `cmd-NNN-after.png` step shots, which the collector cannot tell from named screenshots
(`cmd-NNN-<name>.png`, `pkg/report/flow.go:190-205` in grantiva-runner).

## Acceptance criteria
- Re-running the repro: `Screens: 2 total, 2 passed, 0 failed`; `captures/` holds the two takeScreenshot captures
  (plus `trace/` with the step shots); no `-before`/`-after` file outside `trace/`.
- `--snapshot trailing` likewise lists only takeScreenshot points.
- The collector identifies named screenshots from report.json (the takeScreenshot command's artifact) rather than
  by globbing, or excludes the runner's `cmd-NNN-before|after.png` names.
- GrantivaCoreTests/RunnerArtifactCollectorTests: a fixture `assets/flow-000/` with `cmd-000-before.png`,
  `cmd-000-after.png` and `cmd-003-Home.png` yields exactly one capture, `01-browse-cmd-003-Home`.
