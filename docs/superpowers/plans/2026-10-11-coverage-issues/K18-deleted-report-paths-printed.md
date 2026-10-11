# Runs without `--report-dir` print report paths in a temp directory that grantiva deletes before it exits

Severity: ux
Component: cli
Platforms: both (Android AND-OBS-03; the same lines appear on iOS in IOS-152's output)
Rows: AND-OBS-03 (android); seen also in IOS-152 (ios, row placed in C19); IOS-OBS-05 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Output never points the user at files that will not exist when the command returns. Without `--report-dir` the report
directory is ephemeral by design (Sources/GrantivaCore/Runner/RunnerSession.swift:66-67: "otherwise reports go to a
temp dir wiped on return"), so either no report paths are printed, or one line says the report was not kept and how to
keep it (`--report-dir <dir>`). With `--report-dir` the paths are printed as today (IOS-070 passed).

## Actual
`diff capture` without `--report-dir` (AND-108/01.err:83-92), same for `run` (AND-018) and on iOS (IOS-152/plain.err:60):
```
  Reports: /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-report-A2764A0B-03C8-4A23-B1B9-A726AFB9CDCA
    ├── report.json
    ├── junit-report.xml
    └── allure-results/

  Paths:
    JSON:   /var/folders/.../grantiva-report-A2764A0B-.../report.json
    JUnit:  /var/folders/.../grantiva-report-A2764A0B-.../junit-report.xml
    Allure: /var/folders/.../grantiva-report-A2764A0B-.../allure-results
```
The directory is gone once the command exits.


**Absorbed from the iOS fix round.** Confirmed on iOS as IOS-OBS-05: every run without `--report-dir` prints a `Reports: /var/folders/…` path that is deleted on exit (evidence `findings/evidence/cov-ios/IOS-OBS-05/reports-path.txt`).

Result rows (`findings/cov-ios-results.md`):

> | IOS-OBS-05 | fail | IOS-OBS-05/reports-path.txt | every run without `--report-dir` prints `Reports: /var/folders/…/grantiva-report-…` and JSON/JUnit/Allure paths under it, and the directory is deleted on exit (each printed path: No such file or directory afterwards). Referenced by X-001. |

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k18
unset GRANTIVA_API_KEY
rm -rf /tmp/k18 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k18 && cd /tmp/k18/android
SERIAL=$(grantiva emulator ensure --name fix-k18)
grantiva build install --device "$SERIAL" --no-launch
grantiva run --device "$SERIAL" --no-build --flow .maestro/01-browse.yaml 2> /tmp/k18/err.txt
DIR=$(grep -o '/[^ ]*grantiva-report-[A-F0-9-]*' /tmp/k18/err.txt | head -1); echo "$DIR"; ls "$DIR"   # No such file or directory
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k18
```
iOS: the iOS prelude (see K05) and `grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml` show the same.

## Evidence
- findings/evidence/cov-android/AND-108/01.err lines 83-92; findings/evidence/cov-android/AND-018/
- findings/evidence/cov-ios/IOS-152/plain.err line 60, quiet-fail.err line 53
- Row pointer: findings/evidence/cov-android/AND-OBS-03/commands.txt

## Suspected cause
- The runner prints the block unconditionally at the end of a run: runner pkg/cli/test.go:1155-1165 (`Reports:` tree and
  `Paths:` list from `cfg.OutputDir`).
- The CLI passes a temp `--output` dir (`Sources/GrantivaCore/Runner/RunnerSession.swift:70-81` for screens, `:402-415`
  for flows) and removes it in a `defer` (:91-95 and :427-430) when `--report-dir` was not given, but relays the runner's output
  untouched (RunnerExecution.swift:111-129; the `OutputRewriter` there only maps staged flow paths).

## Acceptance criteria
- Without `--report-dir`, no `/var/folders/.../grantiva-report-*` path appears in stderr for `run`, `diff capture` or
  `ci run`; optionally one line: `Report not kept; pass --report-dir <dir> to keep report.json, JUnit and Allure.`
- With `--report-dir out`, the block is printed and every listed path exists after exit.
- Either fix is acceptable: the CLI drops the runner's Reports/Paths block when the dir is ephemeral, or the runner
  gets a flag to omit it and the CLI passes it.
- GrantivaCoreTests (OutputRewriterTests or RunnerExecutionTests): given runner output containing the Reports/Paths
  block for an ephemeral dir, the relayed text omits it; for a preserved dir, it is kept.
