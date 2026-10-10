# MCP server

`grantiva mcp` starts a Model Context Protocol server on stdio so an AI agent can build, run, drive, and
visually test the app. It works against an iOS simulator or an Android emulator; the platform is resolved
like every other command (`grantiva.yml` is iOS, `grantiva-android.yml` is Android, and
`grantiva mcp --platform ios|android` chooses when both exist). See [android.md](android.md) for the
Android specifics.

The server exposes 22 tools. `tools/list` returns exactly this set; a test fails if the tool names on this page and
the registered tool names drift apart.

## Runner session

Today `grantiva mcp` loads the active runner session from `.grantiva/session.json` before it starts
serving, so start one first with `grantiva runner start` or `grantiva run --keep-alive` and run the
server from the same project directory (or pass `--project-dir`). The **Session** column below says
which tools drive the held session (the UI tools) and which do not use it.

| Session | Meaning |
| --- | --- |
| yes | Drives the app through the held runner session. |
| no | Shells out to `xcodebuild`, Gradle, `simctl`, `adb`, or the diff pipeline; does not use the session. |

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
| `grantiva_script` | iOS, Android | yes | Execute a batch of UI actions sequentially (`tap`, `tap_xy`, `swipe`, `type`, `wait`). Returns the final accessibility tree. |

### Build and run

| Tool | Platform | Session | Description |
| --- | --- | --- | --- |
| `grantiva_build` | iOS, Android | no | Build the project: xcodebuild on iOS, Gradle on Android. Returns success status, duration, warnings, and errors. |
| `grantiva_run` | iOS, Android | no | Build, install, and launch the app on the simulator or emulator. |
| `grantiva_test` | iOS only | no | Run the project's test suite using `xcodebuild test`. Returns pass/fail counts and output. |
| `grantiva_context` | iOS, Android | no | Get current project context: config, booted simulator or running emulator, Xcode or Android SDK, and runner session status. |

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
| `grantiva_vrt_capture` | iOS, Android | no | Capture screenshots for all configured screens. Equivalent to `grantiva diff capture --no-build --json`; assumes the app is already running on the device. |
| `grantiva_vrt_compare` | iOS, Android | no | Compare current captures against baselines. Equivalent to `grantiva diff compare --json`. |
| `grantiva_vrt_approve` | iOS, Android | no | Promote current captures to baselines. Equivalent to `grantiva diff approve [screens] --json`; approves all screens if none are specified. |
