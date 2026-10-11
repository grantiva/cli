# The default simulator name differs by command, and init's default can take over a user's own simulator

Severity: contract
Component: cli
Platforms: ios
Rows: EXTRA-03, EXTRA-06 (cli); related CLI-072, CLI-081, CLI-097, CLI-153 (cli), MCP-031 (ios, placed in K53)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
One default simulator name, chosen in one place, used by every CLI command, every MCP schema and description, and
doctor's fix line; and a default that `init` writes does not silently adopt a simulator the user created for something
else. README Quick Start runs `grantiva init` then `grantiva run`, so whatever init writes is what the first run boots.

## Actual
- Hard-coded `"iPhone 16"` when no simulator is named: CLI `run`/`diff capture` project resolution and `runner start`;
  MCP `grantiva_build`, `grantiva_test`, `grantiva_sim_boot` (the MCP tool schemas say `default: 'iPhone 16'`,
  findings/evidence/cov-cli/CLI-097/empty_ios.out). On this host no "iPhone 16" exists, so MCP-031 fails with
  `Simulator not found: "iPhone 16"`.
- `init` writes the newest installed iPhone device type (`simulator: iPhone 18 Pro`, CLI-069/init.out, CLI-072).
- doctor's fix line falls back to `"iPhone 17 Pro"` (CLI-081/text.out); init's own placeholder is also `iPhone 17 Pro`.
- EXTRA-06: the user already had a simulator named `iPhone 18 Pro` (FE441EE5, created 2026-09-15). After `init`,
  `run --flow flows/onboarding.yaml` used it (findings/evidence/cov-cli/CLI-153/run_flow.err):
```
Resolved: scheme=Landmarks simulator=iPhone 18 Pro screens=0 flows=1
Booting simulator: iPhone 18 Pro
Simulator booted: iPhone 18 Pro (FE441EE5-BBFC-4981-B68A-59C0DBCE26D6)
Building Landmarks...
Installing com.kylebrowning.Landmarks...
```

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k37
rm -rf /tmp/k37 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k37 && cd /tmp/k37/ios
rm grantiva.yml && grantiva init && grep simulator: grantiva.yml       # newest iPhone type, e.g. "iPhone 18 Pro"
xcrun simctl list devices | grep "$(sed -n 's/^simulator: //p' grantiva.yml)"   # a user device with that name, if any
mkdir /tmp/k37/empty && cd /tmp/k37/empty
printf '%s\n' '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | (cat; sleep 3) | grantiva mcp --platform ios | grep -o "default: 'iPhone 16'" | sort | uniq -c
DEVELOPER_DIR=/nonexistent grantiva doctor | grep "simulator ensure"
```
Today: three different names (`iPhone 16`, the newest type, `iPhone 17 Pro`). Do not run `grantiva run` from the
init'd directory on a host whose user owns a simulator of that name; that is the EXTRA-06 takeover.

## Evidence
- findings/evidence/cov-cli/CLI-097/empty_ios.out (MCP schemas `default: 'iPhone 16'`)
- findings/evidence/cov-cli/CLI-069/init.out, CLI-072/init.out (init writes `iPhone 18 Pro`)
- findings/evidence/cov-cli/CLI-081/text.out (doctor `iPhone 17 Pro`)
- findings/evidence/cov-cli/CLI-153/commands.txt (note on FE441EE5), run_flow.err, cleanup_teardown.out
- findings/evidence/cov-ios/MCP-031/empty-dir/transcript.txt

## Suspected cause
Each site picks its own name:
- Sources/GrantivaCore/Config/ProjectResolver.swift:25 (`simulator: String = "iPhone 16"`) and :121
  (`flagSim ?? configSim ?? "iPhone 16"`).
- Sources/GrantivaCLI/DriverCommand.swift:211 (`runner start` target).
- Sources/GrantivaMCP/Tools/BuildTools.swift:107, :258; Sources/GrantivaMCP/Tools/SimTools.swift:108 (and the schema
  descriptions that state the default).
- Sources/GrantivaCLI/InitCommand.swift:92-109 (`iosTemplate`: newest installed iPhone type, else `iPhone 17 Pro`).
- Sources/GrantivaCore/Doctor/DoctorRunner.swift:101-107 (fix line, newest type else `iPhone 17 Pro`).
The takeover follows from `bootDevice(named:)` matching any existing device by name; init does not check whether a
device with the name it writes already exists, and the name it writes is a stock device-type name a user is likely to
have.

## Acceptance criteria
- One function in GrantivaCore returns the default simulator name; ProjectResolver, DriverCommand, BuildTools,
  SimTools (and their schema text), InitCommand and DoctorRunner all use it. grep for `"iPhone 1[0-9]` in Sources/ finds
  only that function and help examples.
- `init` writes a Grantiva-specific name (for example `Grantiva <newest iPhone type>`) that `simulator ensure`/`run`
  creates on first use, or, if it writes a stock name, warns when a simulator of that name already exists and was not
  created by Grantiva (provenance ledger), naming it.
- MCP `grantiva_build {scheme}` in a directory without config uses the same default; when it does not exist it is
  created or the isError names the default and how to override it (with K53's isError fix).
- GrantivaCLITests/InitIOSTests: `iosTemplate` writes the shared default; GrantivaMCPTests/ToolSchemaTests: schema
  defaults equal the shared default; GrantivaCoreTests/ProjectResolutionTests: no simulator flag/config resolves to it.
