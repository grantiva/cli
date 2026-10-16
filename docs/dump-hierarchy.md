# Dumping the UI Hierarchy

Grantiva exposes the live UI accessibility tree of a running simulator or emulator so agents and developers can inspect state, find selectors, and diagnose failed assertions — without touching the app.

There are two ways to read the hierarchy, depending on how you started the session.

## Primary: `grantiva hierarchy`

Pairs with `grantiva run --keep-alive`. Recommended for agent-driven flows.

```bash
# Terminal 1 (or CI background):
grantiva run --keep-alive --flow flows/onboarding.yaml

# Terminal 2 (while the session is held):
grantiva hierarchy > state.xml
# or
grantiva hierarchy --format json > state.json
```

`grantiva hierarchy` finds the session that `--keep-alive` published, opens an HTTP read against the running GrantivaAgent on its allocated port, and prints the XCUI accessibility tree. The session lives in `/tmp/grantiva-sessions/`: grantiva-runner writes `<pid>-<timestamp>.grantiva` (port and session ID) when it starts holding the session, and grantiva writes `<pid>.owner.json` next to it the moment the runner is spawned, recording which simulator UDID (or adb serial) that runner owns, plus `projectDirectory` (the directory the run started in, absolute, with symlinks resolved as realpath(3) resolves them: a run started in `/tmp/x` records `/private/tmp/x`), `platform` (`ios` or `android`), and `detached` (`true` only for `runner start --detach`). The MCP server uses a keep-alive session only when both match its own project directory and platform; both sides are canonicalised the same way, so `/tmp/x` and `/private/tmp/x` match (sidecars written by 2.1.0 with the `/tmp` spelling still match), while other differences, including case, do not. Both files are removed when the run ends; a file whose runner `pid` is no longer running is ignored, and so is a `run --keep-alive` session whose grantiva process is gone, so a crashed or `kill -9`'d run never masquerades as a live session. Its runner does not outlive it either: grantiva binds the runner's process group to its own lifetime, so when the grantiva process dies, however it dies, the runner is interrupted and releases the device within seconds. A `runner start --detach` session is the exception by design: it outlives the command that started it until `grantiva runner stop`.

With `--ready-file`, the ready file is written only after the runner's session file is on disk, so a waiter that polls the ready file and then immediately calls `grantiva hierarchy` never races the session. It does **not** create a session, launch the app, or otherwise touch the app's state. The app stays exactly where the flow left it.

If no keep-alive session is live, the command fails fast with an actionable error — it will not start a new session behind your back (which would relaunch and destroy the state you wanted to inspect).

### Output formats

- **XML (default)** — Apple's `debugDescription` format from XCUI, unwrapped from WDA's `{"value": "…"}` envelope. Full element tree with types, labels, identifiers, frames, traits.
- **JSON** — the element tree parsed from that XML, never WDA's `{"value", "sessionId"}` envelope, the same shape `grantiva runner dump-hierarchy --format json` and the MCP `grantiva_a11y_tree` tool print for the same screen. Each element has `type` and `children`; `enabled` and `visible` are booleans; `frame` is `{x, y, width, height}` with numbers (whole points as integers, fractional ones as decimals). `label`, `name`, `identifier`, `value` and `placeholderValue` appear only when the element has a non-empty one, and `frame` only when all four values are present. On Android it is the UIAutomator2 tree with `type`, `platform` and `children`, and its `frame` values are numbers too (whole dp).

### Flags

| Flag | Description |
|------|-------------|
| `--udid` | Target a specific simulator's (UDID) or emulator's (adb serial) session, resolved through grantiva's `<pid>.owner.json` sidecar (defaults to the newest live keep-alive session). |
| `--format` | `xml` (default) or `json`. |
| `--json` | Same as `--format json`. Combining it with `--format xml` is a usage error. |
| `--timeout` | Seconds to wait for GrantivaAgent's page-source response (default 60). |

## Alternative: `grantiva runner dump-hierarchy`

For the standalone `grantiva runner start` / `grantiva runner stop` workflow (used by the MCP server and interactive tooling):

```bash
grantiva runner start --bundle-id com.example.myapp
grantiva runner dump-hierarchy --format json
grantiva runner stop
```

`runner dump-hierarchy` takes `--format tree|json|xml` (default `tree`); `--json` is the same as `--format json`.

This path is preserved for backward compatibility and MCP integration. New flows should prefer `grantiva run --keep-alive` + `grantiva hierarchy`, which integrate natively with flow execution.

`runner start` holds the session with the runner's `--keep-alive` until `runner stop`. The first start on an iOS runtime the runner tarball has no prebuilt GrantivaAgent for (it ships 26.0, 26.2, 26.4, and 27.0) builds the agent from source, which takes several minutes; `runner start` waits up to ten minutes for that build and reports "WebDriverAgent failed to build" with the log path if it fails. Later starts on that runtime reuse the cached build.

`grantiva runner dump-hierarchy` and the MCP server's hierarchy tool share the same discovery as `grantiva hierarchy`: when no `grantiva runner start` session is active in the project, both fall back to a live `--keep-alive` session: one started from this project directory first, even one still starting, else the newest live one (`dump-hierarchy --udid <UDID or adb serial>` selects a specific simulator or emulator). A `--udid` that no live session holds fails, in `runner dump-hierarchy` and `grantiva hierarchy` alike, with `No keep-alive session for udid <udid>. Live sessions: <udids>` when other sessions are live. With neither, all three fail with the same message (exit 1): ``Error: No active runner session. Start one with `grantiva runner start` or `grantiva run --keep-alive`, or pass --port.`` from `runner dump-hierarchy`; `grantiva hierarchy`, which has no `--port`, omits ", or pass --port"; the MCP tools also name the project's `.grantiva/session.json` and directory. While a session is still starting, they say so and to retry instead; [mcp.md](mcp.md#a-session-that-is-starting) gives the texts and which command prints which. An unknown `--format` is a usage error (exit 64) before any session is looked up.

Without `--detach`, `runner start` stays in the foreground, streams the runner's output to stderr, and holds the session until Ctrl-C (exit 130) or `grantiva runner stop` from another shell (exit 0, `Runner stopped (pid N); the session has ended.`); either way it stops the runner, removes `.grantiva/session.json` and the session files, and releases the device. `runner stop` also releases every `grantiva run --keep-alive` session started from the current directory, by sending that grantiva process SIGINT as Ctrl-C would. A run whose flows had already finished keeps the ready file it wrote (`passed` or `failed`; the ready file is written once), and `runner stop --json`'s `stopped` result is the record of the release. `grantiva simulator teardown` and `grantiva emulator teardown` stop any runner session on the device they tear down; a foreground `runner start` ended that way exits 0 too, with `Runner stopped by teardown (pid N); the session has ended.`

## Agent integration

Both paths enable agent workflows like:

1. **Authoring flows** — dump the hierarchy of the screen you're writing a flow for, hand it to the agent, have it emit `tapOn`/`assertVisible` with correct identifiers.
2. **Self-healing tests** — when a flow step fails, dump the hierarchy at failure time, diff against the expected state, and propose a corrected selector.
3. **Smoke regression** — snapshot the hierarchy at known-good states, compare against future runs, flag structural drift.

## Technical details

The hierarchy comes from GrantivaAgent, a WebDriverAgent running as an `XCUITest` test runner on the simulator. The `/source` endpoint invokes `XCUIApplication.debugDescription` under the hood, which returns the current app's accessibility tree as seen by iOS's UI automation stack.

See the [full commands reference](https://docs.grantiva.io/cli/commands) for details on `grantiva run` flags, including `--keep-alive`, `--logs`, and `--flow`.
