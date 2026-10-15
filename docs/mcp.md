# MCP server

`grantiva mcp` starts a Model Context Protocol server on stdio so an AI agent can build, run, drive, and
visually test the app. It works against an iOS simulator or an Android emulator; the platform is resolved
like every other command (`grantiva.yml` is iOS, `grantiva-android.yml` is Android, and
`grantiva mcp --platform ios|android` chooses when both exist). See [android.md](android.md) for the
Android specifics.

The server exposes 22 tools. `tools/list` returns exactly this set; a test fails if the tool names on this page and
the registered tool names drift apart.

## Runner session

`grantiva mcp` starts without a runner session and without a config file, so an agent can list tools
and provision a device first. Only the tools marked **yes** in the **Session** column need a session:
until one exists they return an error (`isError`) naming `grantiva runner start` and
`grantiva run --keep-alive`, and they attach to it on the next call once it starts (and re-attach if it
is replaced).

Every tool, with or without a session, reports every failure as an `isError` result whose text starts
with `Error: ` exactly once, never as a JSON-RPC error: a missing simulator or AVD, a refused delete, a
failed build (`Error: Build FAILED`), a missing config file, a VRT command that fails, an unknown tool
name (`Error: Unknown tool: <name>`). JSON-RPC errors are left for protocol faults (an unknown method, a
malformed request). A `tools/call` cancelled with `notifications/cancelled` gets no response at all,
whether the cancel arrives while the tool runs or right behind the request; a build in progress is
stopped (its `xcodebuild` or Gradle process is terminated). A cancel for an unknown or finished request
changes nothing.

The texts read as follows. With no session, a session tool says
``Error: No active runner session at <project>/.grantiva/session.json. Start one with `grantiva runner start` or `grantiva run --keep-alive` in <project>.``
(adding how many keep-alive sessions from another directory or platform were ignored, when there
were any). A failure caused by an argument, such as a simulator or AVD that does not exist, an AVD
that is still running, or a required argument that is missing, carries the label `Invalid argument: `
after `Error: `, for example `Error: Invalid argument: Simulator not found: "no-such-sim"`,
``Error: Invalid argument: AVD "x" is running as emulator-5554. Run `grantiva emulator teardown --serial emulator-5554` first.``
or `Error: Invalid argument: 'name' is required.` A no-session text never carries the label (a session
tool reports the missing session before it looks at its arguments). The resource reads below report the
same conditions without that label.

### A session that is starting

While a session is starting, on either platform, the session tools return an error (`isError`) saying
so and to retry in a few seconds, never the "Start one with `grantiva runner start`" advice (following it would start a second runner on the device). A session
is starting from the moment `grantiva runner start` (with or without `--detach`) or `grantiva run
--keep-alive` in this project spawns its runner until the driver answers. Two texts cover that window:

- `Error: The runner session is starting (WDA has no session yet; its port is not known yet). Retry in a few seconds.`
  (`UIAutomator2` in place of `WDA` on Android) while the runner has not reported its driver port:
  `runner start` writes `.grantiva/session.json` with `"state": "starting"` and no port the moment it
  spawns the runner, and a `run --keep-alive` runner (or a `runner start` runner, whose session flow
  runs first) is starting until it publishes its keep-alive session, which it does once its flows have
  finished. The MCP tools and resources, `grantiva runner dump-hierarchy` and `grantiva hierarchy` all
  print this one, for a starting `session.json` and for a runner that has not published yet: they share
  one session lookup with `runner stop` and both teardowns, which find such a runner too.
- `Error: The runner session is starting (WDA on port <port> has no session yet). Retry in a few seconds.`
  once the port is known but the driver has no session yet. On iOS, `runner start` rewrites
  `.grantiva/session.json` with the port (still `"state": "starting"`) as soon as the runner reports
  WDA's port, while its launch flow is still running, and with `"state": "ready"` once WDA answers; the
  MCP tools and resources and `grantiva runner dump-hierarchy` print this text in that window
  (`grantiva hierarchy` reads keep-alive sessions, not `session.json`, and prints the first text until
  the runner publishes). The MCP tools and resources also print it once a session is ready but WebDriverAgent has
  not opened its session.

A call made once the driver is ready attaches as usual. `grantiva_screenshot` is the exception once
`--detach` has returned and the session records its device: it takes the screenshot with `simctl` or `adb`, not WDA, so it
succeeds in that last window.

## Default simulator

`grantiva_build`, `grantiva_run`, `grantiva_test` and `grantiva_sim_boot` called without a simulator
(no `simulator` or `name` argument, no `simulator:` in `grantiva.yml`) use the default name, the newest
installed iPhone type (for example `iPhone 18 Pro`). That is a stock name, so it may be a simulator you
created for something else: the default is used only when Grantiva created that simulator (it is in
Grantiva's created-simulator ledger, see the README). Otherwise the call boots nothing and returns
``Error: Invalid argument: Simulator "iPhone 18 Pro" (<udid>) was not created by Grantiva. It has the default simulator's name, and Grantiva does not take a simulator you created as its default. Pass simulator: "iPhone 18 Pro" to use it anyway, or set simulator: in grantiva.yml (create one with grantiva simulator ensure --name "Grantiva iPhone 18 Pro").``
(`grantiva_sim_boot` says `Pass name: "iPhone 18 Pro"`). `grantiva_vrt_capture` without a session
captures on the only booted simulator when the config names none, under the same rule: a sole booted
simulator Grantiva did not create is refused (`It is the only booted simulator, ...`). A simulator you name is used as named. Every
`grantiva_build`, `grantiva_run` and `grantiva_test` result on iOS names the simulator it used:
`Simulator: <name> (<udid>)` (`Device: <name> (<serial>)` for `grantiva_run` on Android; an Android
`grantiva_build` boots nothing). The CLI's `run`, `build`, `diff capture`, `ci` and `runner start`
follow the same rule for their default, naming `--simulator`.

Tools that need a config file (`grantiva_build`, `grantiva_run`, `grantiva_test`, `grantiva_vrt_capture`)
return an error naming the file and where it was looked for, for example
`grantiva.yml not found at /path/to/project/grantiva.yml. Create one with grantiva init.` A `scheme`
(iOS) or `module` (Android) argument stands in for the file for `grantiva_build` and `grantiva_run`.
A config file created after the server started is read on the next call.

The server uses a live `grantiva runner start` session in the project's `.grantiva/session.json`, or
else a `grantiva run --keep-alive` (or `runner start`) session started from the same project directory
(`--project-dir`, default the current directory) for the same platform. Sessions started from another
directory, for the other platform, or by an earlier Grantiva that did not record the directory are
never used. `grantiva_context` reports the session's simulator or emulator, or the configured one when
there is no session. With neither, its `[Simulator]` section says `No runner session and no simulator in
grantiva.yml.` and lists the booted simulators only as a hint: the UI tools act on none of them. Without
a config file its `[Config]` section names the file it looked for and where, for example
`grantiva.yml not found at /path/to/project/grantiva.yml. Create one with grantiva init.` (both
`grantiva.yml` and `grantiva-android.yml` when the platform was not set with `--platform` or
`GRANTIVA_PLATFORM`).

| Session | Meaning |
| --- | --- |
| yes | Drives the app through the held runner session. |
| no | Shells out to `xcodebuild`, Gradle, `simctl`, `adb`, or the diff pipeline; does not use the session. |
| when live | Uses the session when one is live, and works without one. |

## Tools

### UI

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_screenshot` | iOS, Android | yes | Take a screenshot of the device (iOS simulator or Android emulator). Returns a base64-encoded PNG image. |
| `grantiva_tap` | iOS, Android | yes | Tap on a UI element by accessibility label or by coordinates (`x`/`y` in points on iOS, dp on Android). Returns the updated accessibility tree. A `label` is matched in this order: the accessibility label first; on iOS, when no element has that label, the accessibility identifier (WDA's `identifier`, which for an SF Symbol image can be the symbol name), then a text field's placeholder (so `Name` reaches `TextField("Name", ...)`, as a flow's `tapOn: "Name"` does). A fallback match says so: `Tapped on "heart" (matched by identifier)`. Android matches the content description or the text. |
| `grantiva_swipe` | iOS, Android | yes | Swipe on the device screen. Returns the updated accessibility tree. |
| `grantiva_type` | iOS, Android | yes | Type text into the currently focused field. Returns the updated accessibility tree. With no focused field nothing is typed and the result is an error: `No focused text field: tap a field before typing "x".` |
| `grantiva_a11y_tree` | iOS, Android | yes | Get the current accessibility tree (view hierarchy) of the running app as a JSON tree. |
| `grantiva_a11y_check` | iOS, Android | yes | Run an accessibility audit on the current screen: missing labels on interactive elements and tap targets smaller than 44pt (iOS) or 48dp (Android). |
| `grantiva_script` | iOS, Android | yes | Execute a batch of UI actions sequentially (`tap`, `tap_xy`, `swipe`, `type`, `wait`; one action per step). A `tap` step matches its label as `grantiva_tap` does, and its step line names a fallback match: `Step 1: tapped "heart" (matched by identifier)`. Missing `steps` returns `Error: Invalid argument: 'steps' is required.` with `isError`; a wrong-type value is rejected as an array requirement, and an empty array returns the current hierarchy. Every step is validated first: if any is invalid, nothing runs and the result is an error naming each bad step. A step that fails while running (an element not found, nothing focused for `type`) stops the script; the error names the step (`Step 2 (type "x") failed: ...`) and lists the steps that ran. Returns the final accessibility tree. |

### Build and run

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_build` | iOS, Android | no | Build the project: xcodebuild on iOS (for a booted simulator destination), Gradle on Android (compile only, like `grantiva build build`: no emulator is booted). Returns success status, duration, warnings, errors, `Simulator: <name> (<udid>)` on iOS, and `Product: <path>`. Without a simulator it uses the default only when Grantiva created it (see Default simulator). |
| `grantiva_run` | iOS, Android | no | Build, install, and launch the app on the simulator or emulator (booting it if needed). Returns `App built and launched.`, the scheme (iOS) or module and variant (Android), the bundle or application ID, the device (`Simulator: <name> (<udid>)` or `Device: <name> (<serial>)`), and the same `Product: <path>` line as `grantiva_build`. Without a config file a `scheme` argument is enough on iOS: the bundle ID is read from the built app's `Info.plist` (`bundle_id` in `grantiva.yml` wins when present). |
| `grantiva_test` | iOS only | no | Run the project's test suite using `xcodebuild test`. Returns pass/fail counts, `Simulator: <name> (<udid>)`, and output. |
| `grantiva_context` | iOS, Android | no | Get current project context: config (with `source:` naming where it came from, `grantiva.yml` or `.maestro/ (no grantiva.yml)`; an Android-only directory never supplies an iOS config), the device the UI tools act on (the runner session's simulator or emulator; without a session, the configured one), Xcode or Android SDK, and runner session status (pid, driver port, app ID, device; `(unknown)` for a value an older Grantiva did not record, `(forwarded on attach)` for an Android keep-alive port). |

### Simulators (iOS)

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_sim_list` | iOS | no | List iOS simulators (other platforms' devices are left out) as `Name \| UDID \| State \| Runtime \| Available`: state as `simctl` reports it (`Booted`, `Shutdown`, `Booting`, ...), runtime as `iOS 26.0`, and `no` under Available when the simulator's runtime is not installed. `filter`: `all` (default), `booted`, or `shutdown`. |
| `grantiva_sim_boot` | iOS | no | Boot an iOS simulator by name or UDID. Without `name`, the default simulator, only when Grantiva created it (see Default simulator). Returns `Simulator booted: <name> (<udid>)` and `Runtime: iOS 26.0`. |
| `grantiva_sim_ensure` | iOS | no | Create or reuse an exact named simulator, optionally booting it to readiness. Only `name` is required. |
| `grantiva_sim_delete` | iOS | no | Explicitly delete one simulator by its exact name or UDID. |

### Emulators (Android)

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_emulator_list` | Android only | no | List Android Virtual Devices with the serial of each one that is running. |
| `grantiva_emulator_boot` | Android only | no | Boot an Android emulator by AVD name, or use it if it is already running. Defaults to `emulator` in `grantiva-android.yml`. Says which happened: `Emulator booted: <avd> (<serial>)` when it booted the AVD, `Emulator reused: <avd> (<serial>), already running` when it was running (nothing is booted). |
| `grantiva_emulator_ensure` | Android only | no | Create an AVD when missing (installing its system image first) and optionally boot it. Only `name` is required. |
| `grantiva_emulator_delete` | Android only | no | Delete an AVD Grantiva created. Pass `force: true` to delete one it did not create (the refusal says so). A running AVD is never deleted. |

### Visual regression

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_vrt_capture` | iOS, Android | when live | Capture screenshots for all configured screens. Without a session, equivalent to `grantiva diff capture --no-build --json`; assumes the app is installed on the device. With a live runner session it does not start another runner (the session's device lease would refuse it): it captures on the session's device, ignoring `simulator:` or `emulator:` in the config file, relaunches the app, runs each screen's steps through the session's driver, takes each screenshot through that driver as grantiva-runner does, and returns the same JSON as `diff capture --json`. Selectors follow the bundled grantiva-runner's rules. On both platforms `text` is a case-insensitive regex over the whole value (`Open` does not match `Talk · Open`; write `.*Open.*`) and `exact: true` is the whole value as written. iOS: `text` reads the label, value and placeholder; `id:` reads the accessibility identifier, ignoring case (on an agent that does not report identifiers, WDA's `name`). Android: `text` reads the text, content-desc and hint, and without `exact` also the error text; `id:` reads the resource id, whole or after its last `/`. Screens with `runFlow`, a swipe from an element, a swipe between points, or a swipe with a duration are refused before anything runs; stop the session with `grantiva runner stop` to capture those. Through a session a `type` step needs a focused field (tap one in an earlier step): with nothing focused the capture fails as `Screen "<name>", step <n> (Type "<text>"): No focused text field: ...` rather than typing nowhere and capturing a misleading baseline. |
| `grantiva_vrt_compare` | iOS, Android | no | Compare current captures against baselines. Equivalent to `grantiva diff compare --json`. Only the screens configured in the config file are compared; other files in the capture directory (an older `grantiva run`'s shots) are listed under `ignored` and left alone. A screen without a baseline is not a pass: the document has `"passed": false` and the screen's `status` is `new_screen` (with no baselines at all, every screen is); this verdict is a normal result, not an `isError` one. When the directory holds only files that are not configured screens, the error names the configured screens that have no capture. |
| `grantiva_vrt_approve` | iOS, Android | no | Promote current captures to baselines. Equivalent to `grantiva diff approve [screens] --json`; with no screens it approves every configured screen that has a capture, lists other files in the capture directory under `ignored` and approves none of them; named screens are approved as asked. |

The VRT tools run the serving Grantiva binary directly with an argument list (no shell), and every
VRT failure reads `Error: <message>`.

## Resources

| URI | Contents |
| --- | --- |
| `grantiva://hierarchy` | The current view hierarchy as a JSON tree (`application/json`), as `grantiva_a11y_tree` returns it. |
| `grantiva://screenshot` | The current screenshot as a PNG (`image/png`, base64 blob). |

Both read through the runner session. When there is no usable session (none, one still starting, a
driver that is not answering yet, or an app under test that is not running), `resources/read` answers
the JSON-RPC error code `-32002` whose message is the session tools' text, for example
`No active runner session ... Start one with ...` or `The runner session is starting ... Retry in a few
seconds.` Any other failure while reading (for example a page source that cannot be parsed) is
`-32603` with its own text. An unknown URI is `-32600`.

`resources/subscribe` to `grantiva://hierarchy` turns on `notifications/resources/updated` for it, and
`resources/unsubscribe` turns them off. A notification follows only a `grantiva_tap`, `grantiva_swipe`,
`grantiva_type` or `grantiva_script` call that may have changed the UI: a call that failed or was
rejected sends none (a script that ran at least one step before failing does send one). Nothing is
sent to a client that did not subscribe.

Concurrent requests may finish in any order. Each stdout line contains one complete JSON-RPC message, including responses larger than the pipe buffer; response and notification bytes never interleave.

## JSON date compatibility

Date-valued JSON fields use ISO 8601 UTC strings, such as
`1970-01-01T00:00:00Z`. This is the representation scripts should consume;
numeric Unix and Apple-reference timestamps are not output alternatives. The
fields are `timestamp` on screen captures, `detectedAt` on detected projects,
`startedAt` on runner sessions, simulator or emulator leases and provenance,
`acquiredAt` on simulator capacity records, `createdAt` on created-simulator
and keep-alive ownership records, and `finishedAt` in ready files. These are the
fields of `--json` output, MCP tool results, `--ready-file` files and the
project's `.grantiva/session.json`. Bookkeeping files under the runner home and
the runner's own `/tmp/grantiva-sessions/*.grantiva` records are internal; their
date encodings, and the numeric `runnerStartTime` process identity in ownership
records, are not part of this contract.

The iOS tap fallback order is **label → identifier → placeholder**. Runner
lifecycle and teardown JSON use the current camelCase keys, including
`"runnerSessionStopped"`, `"leftoverProcesses"`, and `"reapedProcesses"`;
each stopped-session object retains the app, device, runner PID, port, and
cleanup result described in the README.

## Malformed input

The server follows JSON-RPC 2.0 for input it cannot handle: a line that is not JSON is answered with
`-32700` and `"id": null`; a JSON object that is not a valid request but carries an `id` (for example
one without `"jsonrpc": "2.0"`) is answered with `-32600` echoing that id; a malformed message without
an `id`, and any response (a message with `result` or `error`), is not answered. An empty batch is
`-32600` with `"id": null`; in a batch each member is screened the same way: valid members are handled
and the malformed ones answered together in one array (a non-object member gets `"id": null`). Valid
traffic that follows is handled normally.
