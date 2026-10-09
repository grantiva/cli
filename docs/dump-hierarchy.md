# Dumping the UI Hierarchy

Grantiva exposes the live UI accessibility tree of a running simulator so agents and developers can inspect state, find selectors, and diagnose failed assertions — without touching the app.

There are two ways to read the hierarchy, depending on how you started the session.

## Primary: `grantiva hierarchy` (v1.1.0+)

Pairs with `grantiva run --keep-alive`. Recommended for agent-driven flows.

```bash
# Terminal 1 (or CI background):
grantiva run --keep-alive --flow flows/onboarding.yaml

# Terminal 2 (while the session is held):
grantiva hierarchy > state.xml
# or
grantiva hierarchy --format json > state.json
```

`grantiva hierarchy` finds the session that `--keep-alive` published, opens an HTTP read against the running GrantivaAgent on its allocated port, and prints the XCUI accessibility tree. The session lives in `/tmp/grantiva-sessions/`: grantiva-runner writes `<pid>-<timestamp>.grantiva` (port and session ID) when it starts holding the session, and grantiva writes `<pid>.owner.json` next to it the moment the runner is spawned, recording which simulator UDID that runner owns. Both files are removed when the run ends; a file whose `pid` is no longer running is ignored, so a crashed or `kill -9`'d run never masquerades as a live session.

With `--ready-file`, the ready file is written only after the runner's session file is on disk, so a waiter that polls the ready file and then immediately calls `grantiva hierarchy` never races the session. It does **not** create a session, launch the app, or otherwise touch the app's state. The app stays exactly where the flow left it.

If no keep-alive session is live, the command fails fast with an actionable error — it will not start a new session behind your back (which would relaunch and destroy the state you wanted to inspect).

### Output formats

- **XML (default)** — Apple's `debugDescription` format from XCUI, unwrapped from WDA's `{"value": "…"}` envelope. Full element tree with types, labels, identifiers, frames, traits.
- **JSON** — structured JSON from GrantivaAgent's `/source` endpoint.

### Flags

| Flag | Description |
|------|-------------|
| `--udid` | Target a specific simulator's session, resolved through grantiva's `<pid>.owner.json` sidecar (defaults to the newest live keep-alive session). |
| `--format` | `xml` (default) or `json`. |

## Alternative: `grantiva runner dump-hierarchy`

For the standalone `grantiva runner start` / `grantiva runner stop` workflow (used by the MCP server and interactive tooling):

```bash
grantiva runner start --bundle-id com.example.myapp
grantiva runner dump-hierarchy --format json
grantiva runner stop
```

This path is preserved for backward compatibility and MCP integration. New flows should prefer `grantiva run --keep-alive` + `grantiva hierarchy`, which integrate natively with flow execution.

`runner start` holds the session with the runner's `--keep-alive` until `runner stop`. The first start on an iOS runtime the runner tarball has no prebuilt GrantivaAgent for (it ships 26.2, 26.4, and 27.0) builds the agent from source, which takes several minutes; `runner start` waits up to ten minutes for that build and reports "WebDriverAgent failed to build" with the log path if it fails. Later starts on that runtime reuse the cached build.

`grantiva runner dump-hierarchy` and the MCP server's hierarchy tool share the same discovery as `grantiva hierarchy`: when no `grantiva runner start` session is active in the project, both fall back to the newest live `--keep-alive` session (`dump-hierarchy --udid <UDID>` selects a specific simulator).

## Agent integration

Both paths enable agent workflows like:

1. **Authoring flows** — dump the hierarchy of the screen you're writing a flow for, hand it to the agent, have it emit `tapOn`/`assertVisible` with correct identifiers.
2. **Self-healing tests** — when a flow step fails, dump the hierarchy at failure time, diff against the expected state, and propose a corrected selector.
3. **Smoke regression** — snapshot the hierarchy at known-good states, compare against future runs, flag structural drift.

## Technical details

The hierarchy comes from GrantivaAgent, a WebDriverAgent running as an `XCUITest` test runner on the simulator. The `/source` endpoint invokes `XCUIApplication.debugDescription` under the hood, which returns the current app's accessibility tree as seen by iOS's UI automation stack.

See the [full commands reference](https://docs.grantiva.io/cli/commands) for details on `grantiva run` flags, including `--keep-alive`, `--logs`, and `--flow`.
