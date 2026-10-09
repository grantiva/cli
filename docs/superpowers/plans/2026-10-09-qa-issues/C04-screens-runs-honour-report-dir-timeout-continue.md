# Honour --report-dir, --timeout, and --continue-on-failure for screens runs

Severity: wrong-result
Platforms: cli, ios, android
Found by: CLI-F08 (matrix rows CLI-027)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`--report-dir` writes the runner's report.json and assets to that directory, surviving cleanup; `--timeout` bounds the
runner; `--continue-on-failure` keeps going past a failed screen. Source: help: run (`--report-dir`: "Write the runner's
report.json + assets to this directory ... Survives grantiva's cleanup so CI can upload it", `--timeout`, `--continue-on-failure`).

## Actual
For `screens:` (including a Maestro-format `grantiva.yml` or `.maestro/`, both of which become screens), `out/` holds only
the failure capture, and the runner reports into a temp dir that is deleted on return:
```
$ grantiva run --no-build --simulator qa-cli-1 --report-dir out --timeout 60; ls -R out
captures

out/captures:
failure-1791578775.png
```
```
  ✓ Report directory: /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-report-0D8ADC3B-B88E-4537-848C-5EEC37109175
```
Only `flows:` entries and `--flow` honour the three flags.

## Repro
1. Boot a simulator: `udid=$(grantiva simulator ensure --name "iPhone 17 Pro")`.
2. `cp -R fixtures/detect/maestro-dir /tmp/c04 && cd /tmp/c04` (on branch qa/cli; any `screens:` config works, e.g. one
   screen `path: launch` with `bundle_id: com.apple.Preferences`).
3. Run and inspect:
   ```
   grantiva run --no-build --simulator "$udid" --bundle-id com.apple.Preferences --report-dir out --timeout 60
   find out
   ```
   No `out/report.json`.

## Evidence
- findings/evidence/cli/detect/maestro-detect.txt
- findings/evidence/cli/flows/swipe-diagonal.txt (temp "Report directory" on a screens run)

## Suspected cause
Sources/GrantivaCLI/RunCommand.swift:275-289: the `runScreens` closure calls `RunnerSession.run(screens:…)` without
`reportDir`, `timeoutSeconds` or `failFast`; only `runFlows` (:291-308) passes them. `RunnerSession.run(screens:)`
(Sources/GrantivaCore/Runner/RunnerSession.swift:17) always uses a temp report dir that it deletes (:55-61) and a fixed
300 s timeout (:90).

## Acceptance criteria
- Re-running the repro leaves `out/report.json` (and assets) after exit; the ready file's `reportDir` matches.
- `--timeout 30` on a screens run that hangs is killed after about 30 s; `--continue-on-failure` runs every screen.
- GrantivaCLITests/RunCommandTests: with an injected screens runner, assert the closure receives `reportDir`,
  `timeoutSeconds` and `failFast` from the flags.
- GrantivaCoreTests/RunnerSessionCleanupTests: assert a supplied report dir is not deleted after `run(screens:)`.

## Android detail (AND-F06)
With both `screens:` and `flows:`, any failed screen makes the run exit before a single flow starts, even with
`--continue-on-failure`. On Android the stock landmarks config (5 screens + 12 flows) therefore never runs its flows:
screens fail at `tap: "Lakes"` (see A13), then
```
Running 13 flow(s)...
Failure screenshot: .../AND-042/report/captures/failure-1791579560.png
Error: Runner failed (exit 1):
 exited with code 1
```
and `--report-dir` gets only `captures/`.

Repro:
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva run --device emulator-5554 --continue-on-failure --report-dir /tmp/c04-android; echo "exit $?"
ls /tmp/c04-android              # captures only; no report.json, no flow results
```
Evidence: findings/evidence/AND-042/{stdout.txt,stderr.txt,report/}.
Cause: Sources/GrantivaCLI/RunCommand.swift:404-410 (`runSuite`) throws `ExitCode.failure` after any failed screen step
when flows exist, without consulting `--continue-on-failure`.

Extra acceptance criterion: with `--continue-on-failure`, a failed screen is reported and every configured flow still
runs and is reported (exit non-zero at the end); without it, the current fail-fast stays. RunCommandTests: `runSuite`
with a failing screens closure and `continueOnFailure: true` still calls `runFlows`.
