# README's `doctor --json` jq filter selects `status == "fail"`, a value doctor never emits

Severity: docs
Component: docs
Platforms: n/a
Rows: CLI-011 (cli), AND-092 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
The documented pipeline `grantiva doctor --json | jq '.[] | select(.status == "fail")'` (README:380; repeated in the
Output.swift doc comment) prints the failing checks.

## Actual
doctor's status values are `ok`, `warning`, `error`. iOS project with `DEVELOPER_DIR=/nonexistent` (Xcode checks fail,
exit 1), findings/evidence/cov-cli/CLI-011/jq_on_failing_doctor.out:
```
jq_rc=0
["error","ok","warning"]
```
The filter printed nothing. Android, `JAVA_HOME=/nonexistent` (findings/evidence/cov-android/AND-092): the JDK check is
`"status": "error"` and the README filter again selects nothing.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k62 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k62 && cd /tmp/k62/ios
DEVELOPER_DIR=/nonexistent grantiva doctor --json | jq '.[] | select(.status == "fail")'      # prints nothing
DEVELOPER_DIR=/nonexistent grantiva doctor --json | jq -c '[.[].status] | unique'              # ["error","ok","warning"]
DEVELOPER_DIR=/nonexistent grantiva doctor --json | jq -c '.[] | select(.status == "error") | .name'
```

## Evidence
- findings/evidence/cov-cli/CLI-011/commands.txt, jq.out, jq_on_failing_doctor.out
- findings/evidence/cov-android/AND-092/commands.txt, 01.out

## Suspected cause
- README.md:380 and Sources/GrantivaCore/Output/Output.swift:11 (doc comment) use `"fail"`.
- Sources/GrantivaCore/Doctor/DoctorCheck.swift:10-14: `enum Status { case ok, warning, error }`.

## Acceptance criteria
- README:380 and Output.swift:11 use `select(.status == "error")`; the README states the three status values and that
  only `error` changes the exit code.
- No other file in README.md, docs/ or Sources/ uses `status == "fail"` for doctor (grep).
- GrantivaCoreTests/DoctorTests (or JSONOutputTests): the encoded statuses are exactly `ok`, `warning`, `error`, so a
  rename breaks a test and prompts a README update.
