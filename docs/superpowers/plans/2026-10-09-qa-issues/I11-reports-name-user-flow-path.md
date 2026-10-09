# Write the user's flow path into report.json, flows/*.json and junit-report.xml

Severity: contract
Platforms: ios
Found by: IOS-F20 (matrix rows IOS-071, IOS-070)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
"Flow failures are reported against the path the user passed, not the temporary staged copy grantiva hands the runner."
Source: CHANGELOG.md:144 (1.7.0). `--report-dir` exists so CI can upload these files (help: run).

## Actual
Terminal output is rewritten (`[1/1] 99-crash (.maestro/99-crash.yaml)`), but every file in `--report-dir` names the
staged copy, which is deleted when the run ends:
```
out/report.json:36:      "sourceFile": "/var/folders/jv/.../T/grantiva-62A09DE0-1EC8-4A6B-B6A7-AA34206893E5/0/99-crash.yaml",
out/junit-report.xml:6:  <property name="file" value="/var/folders/jv/.../T/grantiva-62A09DE0-.../0/99-crash.yaml"/>
```
`out/flows/flow-000.json` carries the same path.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
grantiva run --no-build --flow .maestro/09-seed-empty.yaml --simulator qa-ios-1 --report-dir out
grep -rn "sourceFile\|name=\"file\"\|/var/folders" out/report.json out/flows/*.json out/junit-report.xml
```

## Evidence
- findings/evidence/IOS-070/out-dir/report.json (line 36), IOS-070/out-dir/junit-report.xml (line 6)
- findings/evidence/triage/F35/report.json (lines 36, 65)

## Suspected cause
The runner writes these files with the staged paths it was given. Grantiva builds the staged→user map
(Sources/GrantivaCore/Runner/RunnerSession.swift:284-311) but applies it only to the relayed stream (RunnerExecution.swift:98-102)
and to stderr (RunnerSession.swift:390-392). Nothing rewrites `report.json`, `flows/*.json` or `junit-report.xml` in
`reportDir` before the run returns.

## Acceptance criteria
- Re-running the repro: no `/var/folders` path in `out/`; `sourceFile` and the junit `file` property are
  `.maestro/09-seed-empty.yaml` (the path as passed).
- After the runner exits (pass or fail, including timeout), rewrite those files using `stagedPathMap` (JSON-aware for
  report/flows, XML-escaped for junit), or pass the original path to the runner as a display name.
- GrantivaCoreTests/RunnerSessionTests (or a RunnerReportRewriter unit): given a fixture report.json and junit file with
  staged paths and a map, the rewritten files contain only the user paths and stay valid JSON/XML.
