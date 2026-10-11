# After `kill -9` of a keep-alive `grantiva run`, its runner lives on and `hierarchy` keeps serving the dead run's session

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; the session store and liveness check are shared with Android, which was not tested for this)
Rows: IOS-054 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/dump-hierarchy.md:21: "a file whose `pid` is no longer running is ignored, so a crashed or `kill -9`'d run never
masquerades as a live session", and "If no keep-alive session is live, the command fails fast with an actionable
error" (:25). Matrix row IOS-054: after `kill -9` of the keep-alive run, the dead session is ignored and `hierarchy`
fails fast if there is no other.

## Actual
The keep-alive run (grantiva pid 4163, runner pid 4267) was killed with `kill -9 4163`. The runner was not killed
(it is in its own process group) and its session files stay (hier-plain.out):
```
4267-1791703708426695000.grantiva
4267.owner.json
{"createdAt":"2026-10-11T07:28:18Z","grantivaPid":4163,"platform":"ios","projectDirectory":"\/tmp\/…\/cov-ios\/ios","runnerPid":4267,"udid":"A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF"}
<?xml version="1.0" encoding="UTF-8"?>
<XCUIElementTypeApplication type="XCUIElementTypeApplication" name="Landmarks" …
```
`hierarchy` and `hierarchy --udid <cov-ios-1>` both exit 0 with the tree (hier-udid.out). Only after
`simulator teardown --udid … --force` (IOS-149) does `hierarchy` fail fast
(`No keep-alive session found. Start one with `grantiva run --keep-alive` first.`, hier-after-reclaim.err).
The owner sidecar records the dead `grantivaPid: 4163`, but nothing reads it.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k79
unset GRANTIVA_API_KEY
rm -rf /tmp/k79 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k79 && cd /tmp/k79/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k79 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/k79/ready &
P=$!; while [ ! -f /tmp/k79/ready ]; do sleep 0.5; done
kill -9 $P; sleep 2
ls /tmp/grantiva-sessions/; cat /tmp/grantiva-sessions/*.owner.json
grantiva hierarchy --timeout 10 | head -c 200; echo " exit=$?"         # today: the tree, exit 0
grantiva simulator teardown --udid "$UDID" --force
grantiva simulator teardown --session-id fix-k79
```

## Evidence
- findings/evidence/cov-ios/IOS-054/commands.txt, hier-plain.out (session files + owner + tree), hier-udid.out,
  hier-after-reclaim.err
- findings/evidence/cov-ios/IOS-047/commands.txt (the keep-alive run), IOS-149/ (the reclaim that ended it)

## Suspected cause
- `Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:171-203` (`liveSessions`): a session is live when the
  runner pid in `<pid>-<ts>.grantiva` is alive (:187). The owner sidecar's `grantivaPid` (:43, written by
  `recordOwner`, :108-136) is never consulted, so a runner orphaned by a killed `grantiva run` counts as live.
- The runner is spawned in its own process group (`Sources/GrantivaCore/Runner/ChildProcess.swift:52-57`,
  `POSIX_SPAWN_SETPGROUP`), so `kill -9` of grantiva does not reach it, and nothing ties its lifetime to the parent.
- Caution for the fix: `runner start` also records an owner (`Sources/GrantivaCLI/DriverCommand.swift:278`) whose
  grantiva process exits right after start (`--detach`, and today also the foreground form, K88). Its session must
  stay live, so the check needs to distinguish a `run --keep-alive` owner from a `runner start` hand-off.

## Acceptance criteria
- Re-running the repro: after `kill -9` of the `grantiva run` pid, `grantiva hierarchy` exits non-zero within a
  second with the no-session error (or names the orphaned runner and the reclaim command
  `grantiva simulator teardown --udid <udid> --force`); it never prints the tree.
- Either the orphaned runner exits on its own when its parent dies (and removes its session file), or every reader
  (`hierarchy`, `runner dump-hierarchy`, MCP session lookup) ignores a `run --keep-alive` session whose owning
  grantiva pid is dead.
- `runner start --detach` sessions keep working after the starting process exits (`hierarchy`, `runner dump-hierarchy`
  and MCP tools still attach).
- docs/dump-hierarchy.md:21 matches the behaviour.
- GrantivaCoreTests/KeepAliveSessionStoreTests: a runner file with a live runner pid and an owner whose
  `grantivaPid` is dead (and which is not a `runner start` owner) is excluded from `liveSessions()`; a `runner start`
  owner with a dead starter pid is included.
