# "No grantiva.yml" is worded differently by `run` and `diff capture`, and `run` reports a scheme error first

Severity: ux
Component: cli
Platforms: both (`grantiva.yml` and `grantiva-android.yml`)
Rows: none directly; raised by CLI-028 (cli), whose own expectation is corrected (cluster map, Expectation corrections)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
The same condition (no config file and no `.maestro/` flows) gives the same sentence from `run` and `diff capture`,
naming the file, where it was looked for and the init command; `run` reports it rather than a scheme error that hides
it. Brief C18 (cited by matrix CLI-028) set the `run` text `No grantiva.yml here. Create one with grantiva init.`;
docs/mcp.md:24-26 documents the other form (`grantiva.yml not found at /path/to/project/grantiva.yml. Create one with
grantiva init.`).

## Actual
Same empty directory (findings/evidence/cov-cli/CLI-028):
```
run --no-build --platform ios           Error: Invalid argument: No grantiva.yml here. Create one with grantiva init.
diff capture --no-build --platform ios  Error: grantiva.yml not found at <dir>/grantiva.yml. Create one with grantiva init.
```
Xcode project with two schemes, no config, no `.maestro/`, plain `run` (run_no_maestro_dir.err):
```
Error: Invalid argument: No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary. Found: Landmarks, Landmarks (UI Testing).
```
Android, no config (run_android_no_config.err): `No grantiva-android.yml here. Create one with grantiva init --platform android.`
With an empty `.maestro/` both commands say `No flow files found in <dir>/.maestro`, which is right (README:158 allows
flows in `.maestro/` without a config; this is the CLI-028 expectation correction).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k52 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k52
mkdir /tmp/k52/empty && cd /tmp/k52/empty
grantiva run --no-build --platform ios; grantiva diff capture --no-build --platform ios
cd /tmp/k52/ios && rm grantiva.yml && mv .maestro ../maestro-aside
grantiva run; grantiva run --no-build
```
All fail in under 2 s without touching a device.

## Evidence
- findings/evidence/cov-cli/CLI-028/commands.txt, run_nobuild_emptydir.err, diffcapture_nobuild_emptydir.err,
  run_no_maestro_dir.err, run_nobuild_no_maestro_dir.err, run_android_no_config.err, run.err, diffcapture.err

## Suspected cause
- Two message builders: Sources/GrantivaCLI/RunCommand.swift:174-180 (`nothingToRunMessage`, "No <file> here ...",
  thrown as `invalidArgument`, hence the `Invalid argument:` prefix) and
  Sources/GrantivaCore/Config/GrantivaConfig.swift:256-260 (`missingFileMessage`, used by `diff capture` and MCP).
- Order in `run`: `target.resolve(...)` (RunCommand.swift:254-256 → Sources/GrantivaCore/Config/ProjectResolver.swift:103-114)
  throws the scheme error before the nothing-to-run check at RunCommand.swift:276-278, so without `--no-build` a
  missing config is never reported.

## Acceptance criteria
- With no config and no `.maestro/`, `run` (with and without `--no-build`) and `diff capture` print the same sentence,
  from `GrantivaConfig.missingFileMessage` (path and init command, `--platform android` on Android), with the same
  prefix (no `Invalid argument:` on one only); exit 1; no boot.
- The missing-config check runs before scheme resolution in `run`; a project that has a config but several schemes
  still gets the scheme error.
- An empty `.maestro/` still gives `No flow files found in <dir>/.maestro` for both commands.
- GrantivaCLITests/RunCommandTests: run in a temp Xcode project with two schemes and no config throws the
  missing-config message; DiffCommandTests: capture gives the identical string.
