# `run --flow <missing file>` boots, builds and installs before noticing the file does not exist

Severity: wrong-result
Component: cli
Platforms: both (shared code; seen on iOS)
Rows: CLI-133 (cli); confirmed by CLI-153 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`run --flow missing.yaml` fails at once with an error naming the missing path, non-zero, before any device work
(matrix CLI-133; help run.txt `--flow`).

## Actual
With an unresolvable simulator the run gets as far as the boot (findings/evidence/cov-cli/CLI-133/missing.err):
```
Resolved: scheme=Landmarks (UI Testing) simulator=qa-ios-1 screens=0 flows=1
Preparing runner...
Runner ready
Booting simulator: qa-ios-1
Error: Invalid argument: Simulator not found: "qa-ios-1"
```
With a resolvable simulator (Quick Start sequence, findings/evidence/cov-cli/CLI-153/run_flow.err), 53 s:
```
Simulator booted: iPhone 18 Pro (FE441EE5-BBFC-4981-B68A-59C0DBCE26D6)
Building Landmarks...
Build finished: success=true duration=21.8s
Installing com.kylebrowning.Landmarks...
Running 1 flow(s)...
Failure screenshot: .grantiva/captures/failure-1791698870.png
Error: The file “onboarding.yaml” couldn’t be opened because there is no such file.
```
Same with `--no-build` (missing_nobuild.err). A failure screenshot is taken for a file error.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k44
rm -rf /tmp/k44 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k44 && cd /tmp/k44/ios
UDID=$(grantiva simulator ensure --name "fix-k44 iPhone 17")
time grantiva run --simulator "$UDID" --flow missing.yaml; echo "exit $?"
grantiva run --simulator "$UDID" --no-build --flow missing.yaml; echo "exit $?"
grantiva simulator teardown --session-id fix-k44
```
Today: build and install happen, then the file error; expected an immediate error.

## Evidence
- findings/evidence/cov-cli/CLI-133/commands.txt, missing.err, missing_nobuild.err
- findings/evidence/cov-cli/CLI-153/commands.txt, run_flow.err (53.2 s elapsed)

## Suspected cause
- Sources/GrantivaCLI/RunCommand.swift:257-273: `--flow` replaces the resolved flows without an existence check;
  `flowBundleId` (:503-508) reads the file with `try?`, so a missing file is ignored there too.
- The file is first opened in Sources/GrantivaCore/Runner/RunnerSession.swift:365 while staging flows, after boot,
  build and install (RunCommand.swift:282-300 and later).
- RunCommand.swift:130-147 (`wantsFailureScreenshot`) takes a screenshot for this error.

## Acceptance criteria
- Re-running the repro: both commands exit 1 within a second with `Error: Invalid argument: Flow file not found:
  missing.yaml` (wording free, must name the path), and nothing is booted, built or installed (no `Booting` line).
- `--flow` naming a directory, or an unreadable file, fails the same way.
- Configured flows in grantiva.yml that do not exist fail the same way before boot (check whether config loading
  already covers it; if not, include it).
- No failure screenshot for this error.
- GrantivaCLITests/RunCommandTests: `run --flow <missing>` with a fake device platform throws before `bootDevice` is
  called (assert the fake recorded no boot).
