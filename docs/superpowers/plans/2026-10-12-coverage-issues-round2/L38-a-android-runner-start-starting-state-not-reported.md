# While an Android `runner start` is still bringing UIAutomator2 up, MCP reads answer "No active runner session … Start one with `grantiva runner start`" instead of saying the session is starting

Severity: contract
Component: cli and mcp
Platforms: android (1 of 1 start probe, 54 reads over 5.9 s; host load not recorded for the probe; logical). iOS passes the rows as written (they read right after `--detach` returns).
Rows: B2-K100.2 [android], D2-44 [android]
Regresses/extends: K100 (docs/superpowers/plans/2026-10-11-coverage-issues/K100-mcp-resource-read-no-session-internal-error.md) criterion 2 incomplete on Android; fixing PR #195. Split from L38-b (same cluster M32, different cause).
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11
Triage note: docs/mcp.md:18-20 promises the "starting" text only "in the seconds after `grantiva runner start --detach` returns, while WDA has no session yet". On Android that window does not exist (the session file is written only once UIAutomator2 holds a session, and reads succeed from then on), and on iOS reads made *before* `--detach` returns also say "No active runner session" (source read). The Android rows probed the earlier window. The owner should rule: either (1) the rows are corrected to "reads after `--detach` returns" (Android then passes; close this), or (2) a start in progress is reported as "starting" on both platforms, which is what the criteria below implement.

## Expected
K100 criterion 2: "A session that is still starting (WDA not yet answering) is reported the same way, with the 'retry in
a few seconds' text the session tools use (docs/mcp.md:19)." The matrix row D2-44 reads both resources "immediately
(starting)" after spawning `runner start --detach` and expects `-32002` with `The runner session is starting ... Retry in
a few seconds.`

## Actual
findings/evidence/cov2-android/D2-44/probe/transcript.txt: `runner start --detach` spawned at 0.01 s, exited at 7.90 s.
Every read from 0.03 s to 5.90 s (54 answers) is the no-session text; the first good read is at 6.73 s:
```
[0.01] spawned runner start --detach pid 56064
[0.03] >> resources/read {"uri": "grantiva://hierarchy"}
<< {"error": {"code": -32002, "message": "No active runner session at /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-android/android/.grantiva/session.json. Start one with `grantiva runner start` or `grantiva run --keep-alive` in /private
[6.73] >> resources/read {"uri": "grantiva://hierarchy"}
<< {"id": 56, "jsonrpc": "2.0", "result": {"contents": [{"mimeType": "application/json", "text": "{\n  \"children\" : [\n    {\n      \"children\" : [\n        {\n          \"children\" : [\n\n       
[7.90] runner start exited rc=0
```
`grep -c 'is starting'` over the transcript: 0. The advice "Start one with `grantiva runner start`" is wrong while one
is starting: following it starts a second runner on the same device.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l38a
unset GRANTIVA_API_KEY
rm -rf /tmp/l38a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l38a && cd /tmp/l38a/android
sed -i '' 's/^emulator: .*/emulator: fix-l38a/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l38a)
grantiva build install --device "$SERIAL" --no-launch
grantiva runner stop
python3 -I /Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/cov2-android/inputs/startprobe.py /tmp/l38a/android /tmp/l38a/probe
grep -c 'No active runner session' /tmp/l38a/probe/transcript.txt; grep -c 'is starting' /tmp/l38a/probe/transcript.txt
grantiva runner stop; grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l38a
```
`startprobe.py` needs `GRANTIVA` set to the binary (`export GRANTIVA=$(command -v grantiva)`). It runs `grantiva mcp
--project-dir <dir>`, sends `initialize` and `notifications/initialized`, spawns `grantiva runner start --detach` in the
project, then every ~0.3 s sends:
```
{"jsonrpc":"2.0","id":N,"method":"resources/read","params":{"uri":"grantiva://hierarchy"}}
{"jsonrpc":"2.0","id":N,"method":"resources/read","params":{"uri":"grantiva://screenshot"}}
{"jsonrpc":"2.0","id":N,"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}}}
```

## Evidence
- findings/evidence/cov2-android/D2-44/probe/transcript.txt, start.out, start.err, server.stderr; D2-44/commands.txt
- findings/evidence/cov2-android/B2-K100.2/commands.txt (pointer to D2-44)
- findings/evidence/cov2-android/inputs/startprobe.py
- iOS pass for comparison: findings/evidence/cov2-ios/B2-K57/session/

## Suspected cause
- The "starting" state exists only in the WDA client: `Sources/GrantivaCore/WDA/WDAClient.swift:352-364`
  (`resolveSessionId` → `sessionStartingMessage`, `:367-368`). It is reachable only once a session file names a port.
- `.grantiva/session.json` is written after readiness: `Sources/GrantivaCLI/DriverCommand.swift:376-383` (detached) and
  `:473-485` (foreground). On Android readiness is `waitForUIAutomator2Port` (`:302-309`, `:360`, `:452`), which needs a
  live UIAutomator2 session, so there is never a session file without a session.
- The MCP lookup `MCPServer.loadActiveSession` (`Sources/GrantivaMCP/MCPServer.swift:164-193`) checks session.json, then
  `KeepAliveSessionStore.liveSessions()` (`KeepAliveSessionStore.swift:230-260`), which needs the runner's own
  `/tmp/grantiva-sessions/<pid>-….grantiva` file; the runner writes that only when its keep-alive hold is armed
  (runner `pkg/cli/keepalive.go:182`). Otherwise it throws `noRunnerSession` (`GrantivaError.swift:107-118`).
- What does exist during the start: the owner sidecar `<runnerPid>.owner.json`, recorded before the wait
  (`DriverCommand.swift:356` detached, `:425` foreground) with `projectDirectory`, `platform` and a live `runnerPid`.

## Acceptance criteria
- If the owner rules option (2): while a `runner start` for this project and platform is in progress (owner sidecar
  present, runner pid alive, no session file yet), session tools and `resources/read` answer `-32002` (tools:
  `isError`) with `The runner session is starting … Retry in a few seconds.` on both platforms; never the "Start one
  with `grantiva runner start`" advice. On Android the text names UIAutomator2, not WDA.
- A sidecar whose runner pid is dead, or that belongs to another project or platform, still yields the no-session text.
- Once the session is ready, reads attach as today (D2-44's ready half keeps passing).
- docs/mcp.md:18-20 describes the window for both platforms.
- Test in GrantivaMCPTests/MCPServerTests.swift: `loadActiveSession` with a temp project, no session.json, and a
  `KeepAliveSessionStore` directory holding only a live owner sidecar for this project/platform throws the "starting"
  error (`GrantivaError.unavailable`), and with the sidecar's pid dead throws `noRunnerSession`.
- If the owner rules option (1): correct matrix rows B2-K100.2 [android] and D2-44 [android] to read after `--detach`
  returns, and record the ruling.
