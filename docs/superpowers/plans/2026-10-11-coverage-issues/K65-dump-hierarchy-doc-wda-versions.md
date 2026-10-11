# docs/dump-hierarchy.md lists prebuilt GrantivaAgent runtimes 26.2, 26.4, 27.0; the bundled tarball also ships 26.0

Severity: docs
Component: docs
Platforms: ios
Rows: EXTRA-01 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
The docs list the iOS runtimes the bundled runner tarball ships a prebuilt GrantivaAgent for, since a missing one
costs a multi-minute first-start build.

## Actual
docs/dump-hierarchy.md:55: "The first start on an iOS runtime the runner tarball has no prebuilt GrantivaAgent for (it
ships 26.2, 26.4, and 27.0) builds the agent from source". A fresh runner home after `runner install`
(findings/evidence/cov-cli/CLI-141/install.out):
```
rh/cache/wda-builds/sim-ios26.2-iphone-wda16.12.8-r1
rh/cache/wda-builds/sim-ios26.4-iphone-wda16.12.8-r1
rh/cache/wda-builds/sim-ios27.0-iphone-wda16.12.8-r1
rh/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8-r1
```
The 51c597a commit message also says 26.0 is included. IOS-117 confirms a cached 26.0 build was used on iOS 26.0.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k65 && GRANTIVA_RUNNER_HOME=/tmp/k65/rh grantiva runner install && ls /tmp/k65/rh/cache/wda-builds
sed -n 55p /Users/kyle/Developer/grantiva-cli/docs/dump-hierarchy.md
```

## Evidence
- findings/evidence/cov-cli/CLI-141/commands.txt, install.out
- findings/evidence/cov-ios/IOS-117/stock-26.err (`Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8-r1)`)

## Suspected cause
- docs/dump-hierarchy.md:55 was not updated when the 26.0 build was added to the tarball.

## Acceptance criteria
- docs/dump-hierarchy.md:55 lists 26.0, 26.2, 26.4 and 27.0 (iPhone), or points at a single source of truth (for
  example `ls <runner home>/cache/wda-builds`) instead of a list that drifts.
- Any other doc or help text listing prebuilt runtimes (grep `26.2`) matches.
