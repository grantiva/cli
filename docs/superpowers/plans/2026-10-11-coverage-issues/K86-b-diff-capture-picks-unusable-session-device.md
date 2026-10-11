# `diff capture --no-build` picks the live `runner start` session's simulator, then refuses to run on it

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; the selection code also serves Android, not tested there)
Rows: IOS-143 (ios); split from cluster C86 lease-rejects-runner-start-session (the refusal's wording is K86-a)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

Triage note: README:262-264 makes a promise the CLI cannot keep as built (a capture spawns its own runner, and the
session holds the device's lease). The fix is a product decision: capture through the live session, or drop the
"runner session" tier from the README and the selection.

## Expected
README:262-264: "`diff capture --no-build` drives the simulator named by `--simulator`, else `simulator:` in
grantiva.yml, else the live runner session's device, else the one booted simulator." Matrix IOS-143: with no
`--simulator`, no config `simulator:` and a live `runner start` session on cov-ios-1, the capture uses the session's
device.

## Actual
capture.err (grantiva.yml without its `simulator:` line; `runner start` pid 52144 live on cov-ios-1;
`diff capture --no-build`, 1.0 s, exit 1):
```
Error: Simulator A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF is already owned by another Grantiva run (pid 52144, started 124s ago, grantiva-runner pid 52144, --keep-alive). Release it with `grantiva simulator teardown --udid A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF --force`, or run against a different simulator via `grantiva simulator ensure --name <unique-name>`.
```
The session's simulator is resolved, as documented, and then the run is refused because the same session owns it.
So the third tier of the documented order can never succeed. (MCP `grantiva_vrt_capture` does capture through a live
session, MCP-063, so the capability exists elsewhere.)

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k86b
unset GRANTIVA_API_KEY
rm -rf /tmp/k86b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k86b && cd /tmp/k86b/ios   # 4e49dc4
sed -i '' '/^simulator:/d' grantiva.yml
UDID=$(grantiva simulator ensure --name "fix-k86b iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva runner start --bundle-id com.kylebrowning.Landmarks --simulator "$UDID" --detach
grantiva diff capture --no-build; echo "exit=$?"                 # today: exit 1, "already owned"
grantiva runner stop
grantiva simulator teardown --session-id fix-k86b
```

## Evidence
- findings/evidence/cov-ios/IOS-143/commands.txt, capture.err
- findings/evidence/cov-ios/MCP-063/ (vrt_capture through the live session: one runner, session UDID)

## Suspected cause
- `Sources/GrantivaCLI/DiffCommand.swift:122-133` and :200-216 (`noBuildDevice`): the session tier
  (`liveSessionUDID`, :220-225) only chooses the device; the capture then runs `RunnerSession.run(screens:…)`
  (:151-159), which starts a new runner and takes the simulator lease, which the session's hand-off claim refuses
  (`SimulatorLease.swift:99-106`).

## Acceptance criteria
- One of:
  - Capture through the session: re-running the repro, `diff capture --no-build` captures the 5 screens on the
    session's simulator through the live runner (as `grantiva_vrt_capture` does), exit 0, and the session is still
    usable afterwards (`grantiva runner dump-hierarchy` answers); or
  - Drop the tier: the session's device is no longer chosen implicitly; with several booted simulators the command
    fails naming them (README order without the session step), and with the session's device as the only booted one
    it fails up front with `grantiva runner stop` advice instead of resolving then refusing. README:262-264 updated.
- GrantivaCLITests/DiffCommandTests: with an injected live session and no flag/config simulator, `noBuildDevice` (or
  its replacement) either returns a session-backed target or throws the documented message before any runner spawn.
