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
is replaced). In the seconds after `grantiva runner start --detach` returns, while WDA has no session yet,
they return an error (`isError`) saying the session is starting and to retry in a few seconds; a call
made once WDA is ready attaches as usual. `grantiva_screenshot` is the exception when the session records
its device: it takes the screenshot with `simctl` or `adb`, not WDA, so it succeeds during that window. Session tools report every failure as an `isError` result,
never as a JSON-RPC error.

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
there is no session.

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
| `grantiva_tap` | iOS, Android | yes | Tap on a UI element by accessibility label or by coordinates (`x`/`y` in points on iOS, dp on Android). Returns the updated accessibility tree. |
| `grantiva_swipe` | iOS, Android | yes | Swipe on the device screen. Returns the updated accessibility tree. |
| `grantiva_type` | iOS, Android | yes | Type text into the currently focused field. Returns the updated accessibility tree. |
| `grantiva_a11y_tree` | iOS, Android | yes | Get the current accessibility tree (view hierarchy) of the running app as a JSON tree. |
| `grantiva_a11y_check` | iOS, Android | yes | Run an accessibility audit on the current screen: missing labels on interactive elements and tap targets smaller than 44pt (iOS) or 48dp (Android). |
| `grantiva_script` | iOS, Android | yes | Execute a batch of UI actions sequentially (`tap`, `tap_xy`, `swipe`, `type`, `wait`; one action per step). Every step is validated first: if any is invalid, nothing runs and the result is an error naming each bad step. Returns the final accessibility tree. |

### Build and run

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_build` | iOS, Android | no | Build the project: xcodebuild on iOS, Gradle on Android. Returns success status, duration, warnings, and errors. |
| `grantiva_run` | iOS, Android | no | Build, install, and launch the app on the simulator or emulator. |
| `grantiva_test` | iOS only | no | Run the project's test suite using `xcodebuild test`. Returns pass/fail counts and output. |
| `grantiva_context` | iOS, Android | no | Get current project context: config, the device the UI tools act on (the runner session's simulator or emulator; without a session, the configured one), Xcode or Android SDK, and runner session status. |

### Simulators (iOS)

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_sim_list` | iOS | no | List available iOS simulators with name, UDID, state, runtime, and availability. |
| `grantiva_sim_boot` | iOS | no | Boot an iOS simulator by name or UDID. |
| `grantiva_sim_ensure` | iOS | no | Create or reuse an exact named simulator, optionally booting it to readiness. Only `name` is required. |
| `grantiva_sim_delete` | iOS | no | Explicitly delete one simulator by its exact name or UDID. |

### Emulators (Android)

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_emulator_list` | Android only | no | List Android Virtual Devices with the serial of each one that is running. |
| `grantiva_emulator_boot` | Android only | no | Boot an Android emulator by AVD name, or use it if it is already running. Defaults to `emulator` in `grantiva-android.yml`. |
| `grantiva_emulator_ensure` | Android only | no | Create an AVD when missing (installing its system image first) and optionally boot it. Only `name` is required. |
| `grantiva_emulator_delete` | Android only | no | Delete an AVD Grantiva created. Pass `force` to delete one it did not create. A running AVD is never deleted. |

### Visual regression

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_vrt_capture` | iOS, Android | when live | Capture screenshots for all configured screens. Without a session, equivalent to `grantiva diff capture --no-build --json`; assumes the app is installed on the device. With a live runner session it does not start another runner (the session's device lease would refuse it): it captures on the session's device, ignoring `simulator:` or `emulator:` in the config file, relaunches the app, runs each screen's steps through the session's driver, takes each screenshot through that driver as grantiva-runner does, and returns the same JSON as `diff capture --json`. Selectors follow the bundled grantiva-runner (1.1.28-grantiva.9). On both platforms `text` is a case-insensitive regex over the whole value (`Open` does not match `Talk · Open`; write `.*Open.*`) and `exact: true` is the whole value as written. iOS: `text` reads the label, value and placeholder; `id:` reads the accessibility identifier, ignoring case (on an agent that does not report identifiers, WDA's `name`). Android: `text` reads the text, content-desc and hint, and without `exact` also the error text; `id:` reads the resource id, whole or after its last `/`. Screens with `runFlow`, a swipe from an element, a swipe between points, or a swipe with a duration are refused before anything runs; stop the session with `grantiva runner stop` to capture those. |
| `grantiva_vrt_compare` | iOS, Android | no | Compare current captures against baselines. Equivalent to `grantiva diff compare --json`. |
| `grantiva_vrt_approve` | iOS, Android | no | Promote current captures to baselines. Equivalent to `grantiva diff approve [screens] --json`; approves all screens if none are specified. |
