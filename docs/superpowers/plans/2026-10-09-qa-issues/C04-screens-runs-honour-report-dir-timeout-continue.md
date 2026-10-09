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
