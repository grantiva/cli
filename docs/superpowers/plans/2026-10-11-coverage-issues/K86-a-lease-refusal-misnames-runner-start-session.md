# A simulator held by `runner start` is refused as "another Grantiva run … --keep-alive" and the advice omits `grantiva runner stop`

Severity: ux
Component: cli
Platforms: ios (seen on iOS; the Android emulator message comes from the same function)
Rows: IOS-089, IOS-143 (ios); split from cluster C86 lease-rejects-runner-start-session (diff capture choosing the session's device is K86-b)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix IOS-089 (README:92): `run` on the `runner start` simulator fails fast as owned and the session stays intact,
which it does. The refusal should describe the owner correctly: a `runner start` session, released with
`grantiva runner stop` (help: runner_stop.txt), not a keep-alive `run` that needs `teardown --force`.

## Actual
run-owned.err (IOS-089, `run --no-build --simulator <cov-ios-1> --flow .maestro/01-browse.yaml` while
`runner start` pid 52144 holds cov-ios-1; 1.5 s, exit 1):
```
Error: Simulator A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF is already owned by another Grantiva run (pid 52144, started 58s ago, grantiva-runner pid 52144, --keep-alive). Release it with `grantiva simulator teardown --udid A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF --force`, or run against a different simulator via `grantiva simulator ensure --name <unique-name>`.
```
The "grantiva" pid and the runner pid are the same process (the runner itself), and the user is steered to a forced
reclaim of a healthy session. IOS-143's `diff capture --no-build` refusal is identical (capture.err).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k86a
unset GRANTIVA_API_KEY
rm -rf /tmp/k86a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k86a && cd /tmp/k86a/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k86a iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva runner start --bundle-id com.kylebrowning.Landmarks --simulator "$UDID" --detach
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml; echo "exit=$?"
grantiva runner stop
grantiva simulator teardown --session-id fix-k86a
```

## Evidence
- findings/evidence/cov-ios/IOS-089/commands.txt, run-owned.err
- findings/evidence/cov-ios/IOS-143/commands.txt, capture.err

## Suspected cause
- `Sources/GrantivaCore/Runner/SimulatorLease.swift:176-189` (`handOff(to:)`): `runner start` rewrites the claim as
  `pid: runnerPID, runnerPID: runnerPID, keepAlive: true`, the same shape a `run --keep-alive` claim has apart from
  the pids.
- :127-150 (`ownershipMessage`): renders every `keepAlive` holder as "another Grantiva run … --keep-alive" and always
  offers `teardown --udid … --force` / `ensure --name`. It cannot tell a hand-off (pid == runnerPID, or a flag on the
  claim) from a keep-alive run.

## Acceptance criteria
- Re-running the repro: exit 1 fast, session intact, and the message names the owner as a `runner start` session,
  for example `Simulator <udid> is held by a `grantiva runner start` session (grantiva-runner pid 52144, started 58s
  ago). Stop it with `grantiva runner stop` (from <project dir>), or use another simulator via
  `grantiva simulator ensure --name <unique-name>`.`
- A `run --keep-alive` owner keeps today's wording, and a dead owner still suggests `teardown --force`.
- The Android emulator variant gets the same distinction.
- GrantivaCoreTests/SimulatorLeaseTests: `ownershipMessage` for a handed-off claim mentions `grantiva runner stop`
  and not `--keep-alive`; for a keep-alive run claim it is unchanged.
