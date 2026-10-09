# Report each flow's own steps and duration in the run summary when basenames collide

Severity: ux
Platforms: ios
Found by: IOS-F35 (matrix row IOS-072)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
Each flow runs once (it does) and is reported once with its own numbers. Source: README §Configuration (`flows:` list);
RunnerSession.swift:301-303 stages same-named flows separately so "smoke/login.yaml and regression/login.yaml must not
overwrite each other".

## Actual
`flows: [qa/a/same.yaml, qa/b/same.yaml]` (8 and 6 steps):
```
  Flow                           Status   Steps   Pass   Fail   Skip   Duration  Device
  same                           ✓ PASS       8      8      0      0       8.0s  qa-ios-1 (ios 26.0 Simulator)
  same                           ✓ PASS       8      8      0      0       8.0s  qa-ios-1 (ios 26.0 Simulator)
  TOTAL                             2/2      14     14      0      0      12.9s
```
report.json has the real values (`duration` 5117 and 4953 ms); the rows cannot be told apart and the second is wrong.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
mkdir -p qa/a qa/b && cp .maestro/01-browse.yaml qa/a/same.yaml && cp .maestro/05-category.yaml qa/b/same.yaml
printf 'scheme: "Landmarks (UI Testing)"\nsimulator: qa-ios-1\nbundle_id: com.kylebrowning.Landmarks\nflows:\n  - qa/a/same.yaml\n  - qa/b/same.yaml\n' > grantiva.yml
grantiva run --no-build --simulator qa-ios-1 --report-dir out 2>&1 | grep -E "^  same|TOTAL"; grep '"duration"' out/report.json
```

## Evidence
- findings/evidence/triage/F35.err (summary table), F35/report.json (lines 35-78)
- findings/evidence/IOS-072/err.txt (lines 63-66), IOS-072/rep/report.json

## Suspected cause
The table is printed by the bundled runner (outside Sources/), which apparently keys per-flow results by flow name. Grantiva
stages both flows as `<tmp>/0/same.yaml` and `<tmp>/1/same.yaml`, keeping the basename
(Sources/GrantivaCore/Runner/RunnerSession.swift:304-307), so the runner sees two flows called `same`.

## Acceptance criteria
- Re-running the repro: the rows show their own flows' step counts and durations and are distinguishable (e.g.
  `qa/a/same`, `qa/b/same`).
- Fix the runner's keying (by flow id/index), or have Grantiva give colliding basenames a unique flow `name:` when
  staging, or print its own summary from report.json.
- Test: a runner-side test with two same-named flows, or a GrantivaCoreTests case asserting staging yields unique flow
  names for `a/same.yaml` and `b/same.yaml`.
