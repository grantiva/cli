# Changelog

## 2.1.0

### Changed

- JSON output encodes dates as ISO 8601 UTC strings, for example `2026-10-14T15:43:12Z`, rather than numeric timestamps.
- Android `build install --json` identifies the installed `applicationId` and the target `device` by `name` and `serial`.
- Native screen steps accept `{text: "…", exact: true}` mappings for `tap`, `assert_visible`, and `assert_not_visible`.
- The bundled runner is now `1.1.28-grantiva.19`; indexed iOS taps select distinct actionable targets, Android Unicode input recovers focus, and a step whose selector uses an undefined `${VAR}` fails naming the variable instead of matching any element. Android focused input appends text and reports unexpected replacement instead of silently marking it successful.
- On Android, `--env`, flow-header `env:`, and `launchApp: environment:` values are merged into the staged `launchApp.arguments` map and delivered to the app as string intent extras.
- Screen capture waits for the UI to settle after every tap, swipe, type, and nested flow, and before every screenshot. Each settle wait is bounded at five seconds, which can add up to five seconds of latency per wait.

### Fixed

- The MCP server re-reads `grantiva.yml` on every call, so a config written or edited after the server started is used.
- `grantiva_script` tap steps say `(matched by identifier)` when the label matched an identifier, like `grantiva_tap`.
- Staged flows run `doubleTapOn`, `longPressOn`, `launchApp`, `stopApp` and `killApp` as written instead of turning them into taps or dropping them.
- A Maestro-format `env:` header in `grantiva.yml` reaches the app and defines `${VAR}` in steps, including captures through a `runner start` session.
- The screens cycle error names the project's actual config file, such as `grantiva-android.yml`.
- `--device` or `--emulator` with no other platform hint selects Android, so `record --device <serial>` accepts `.mp4`.
- A runner failure prints one `Error:` line instead of a bare `Runner failed (exit 1):` line followed by the runner's own error.
- `appPath` reports the resolved `/private/tmp/...` spelling of a path given as `/tmp/...`.
- Android captures restore touch mode first, so a row focused by earlier key input is not highlighted in the screenshot.
- `simulator teardown` leaves alone a simulator that was rebooted outside Grantiva after its session was recorded; session records now include `bootedAt`.
- The ownership refusal reports the holder's real age instead of `started 0s ago`.
- `runner stop` reaps a `simctl diagnose` that WebDriverAgent's xcodebuild starts after it is interrupted, for both live and killed runners.
- The "session is starting" message, the starting `session.json` and `runner start`'s `already_running` result name the WDA port as soon as it is known.
- Concurrent detached runner starts now use independent diagnostic logs instead of sharing a second-based temporary filename.
- Android emulator selection waits for the operating system to finish booting when ADB already reports the emulator as connected.
- A missing required option is reported like every other usage error: an `Error:` line, then `Usage:` and `See '… --help'`, exit 64, without a `Help:` line.
- `scrollUntilVisible` is faster on slow devices. On Android each drag injects far fewer touch events and skips lookups the current screen already rules out. On iOS each swipe covers more of a tall list.
