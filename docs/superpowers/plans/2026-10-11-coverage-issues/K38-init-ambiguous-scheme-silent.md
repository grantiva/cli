# `init` picks a scheme silently from the project name when the project has several shared schemes

Severity: ux
Component: cli
Platforms: ios
Rows: CLI-069 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`init` in an Xcode project with more than one shared scheme either asks, or writes one and warns naming the others,
consistent with `run`, which refuses the same project without a scheme: `No scheme specified. Pass --scheme ...
Found: Landmarks, Landmarks (UI Testing).` (README:35 for init; ProjectResolver's rule "Detection only picks a scheme
when there is exactly one").

## Actual
In a copy of landmarks-demo/ios without grantiva.yml (shared schemes `Landmarks` and `Landmarks (UI Testing)`),
findings/evidence/cov-cli/CLI-069/init.err and init.out:
```
Created grantiva.yml
rc=0
2:scheme: Landmarks
4:simulator: iPhone 18 Pro
```
No warning. `run` in the same directory without config (findings/evidence/cov-cli/CLI-028/run_no_maestro_dir.err):
```
Error: Invalid argument: No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary. Found: Landmarks, Landmarks (UI Testing).
```
landmarks-demo's own grantiva.yml uses `Landmarks (UI Testing)`, so init's guess is the wrong one for this project.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k38
rm -rf /tmp/k38 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k38 && cd /tmp/k38/ios
rm grantiva.yml; mv .maestro /tmp/k38/maestro-aside
grantiva init; echo "exit $?"; grep -n scheme: grantiva.yml
rm grantiva.yml; grantiva run; echo "exit $?"
xcodebuild -list -project Landmarks.xcodeproj | sed -n '/Schemes:/,$p'
```
`grantiva run` fails before any device work. Today: init writes `scheme: Landmarks`
with no warning; run refuses and lists both schemes.

## Evidence
- findings/evidence/cov-cli/CLI-069/commands.txt, init.err, init.out
- findings/evidence/cov-cli/CLI-028/run_no_maestro_dir.err (run's refusal in the same project)

## Suspected cause
- Sources/GrantivaCLI/InitCommand.swift:193-204 (`detectScheme`): returns the `.xcworkspace` or `.xcodeproj` file name
  as the scheme; it never lists schemes.
- Sources/GrantivaCore/Config/ProjectResolver.swift:103-110: `run` uses the detected scheme list and throws when it has
  more than one.

## Acceptance criteria
- Re-running the repro: init either writes no scheme guess and warns `Several schemes found: Landmarks, Landmarks (UI
  Testing). Set scheme in grantiva.yml or pass --scheme.` (exit 0, file written with a placeholder comment), or writes
  the first and warns naming the others; `grantiva init --scheme "Landmarks (UI Testing)"` writes that scheme silently.
- With exactly one shared scheme, init writes it with no warning.
- init uses the same scheme detection as ProjectResolver (one shared function), so `init` then `run` never disagree.
- GrantivaCLITests/InitIOSTests: `iosTemplate` (or the new detection seam) with two detected schemes produces the
  warning; with one, none.
