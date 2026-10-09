# CLI slice findings (device-free, Task 5)

Binary: `~/.grantiva-qa/bin/grantiva` 2.0.1 (commit c8dc86d). `GRANTIVA_SESSION_ID=qa-cli`, `GRANTIVA_API_KEY` unset,
no stored credentials. Fixtures are under `fixtures/`; every command ran in a fresh scratch copy of a fixture.
Evidence paths are relative to `findings/evidence/cli/`. Documentation-consistency findings (CLI-109 to CLI-122) are
in `findings/cli-docs.md` as CLI-DOCS-F01 to F14 and are not repeated here; the MCP tool count (22 registered, 22 in
`tools/list`, spec says 19) is CLI-DOCS-F14, now confirmed live in `mcp/tools-list-ios.jsonl`.

Severity order used in the summary: crash > wrong-result > contract > ux > docs.

### CLI-F01: `run --continue-on-failure`, `--snapshot`, `--timeout` (and its 30 s minimum) are documented only in `run --help`
Matrix IDs: CLI-004
Severity: docs
Command: grantiva run --help; grantiva run --timeout 0 --no-build
Expected: every `run` flag is described somewhere besides help (source: matrix CLI-004; README §Agent-Native Features, docs/android.md §Devices)
Actual: all README/android.md flags are present in help, but `--continue-on-failure`, `--snapshot`, and `--timeout` appear in no README/docs/CHANGELOG text. `--timeout` rejects values under 30 ("--timeout must be at least 30 seconds."), a limit that is not in help either.
Repro: `grep -- --snapshot README.md docs/*.md CHANGELOG.md` (no hits)
Evidence: detect/run-validation.txt
Suspected cause: —

### CLI-F02: `runner stop` with no session prints its narration on stdout
Matrix IDs: CLI-086
Severity: contract
Command: grantiva runner stop
Expected: clear message, documented exit code, nothing on stdout (source: help: runner stop; README §stdout is the result, stderr is the commentary)
Actual: exit 0 and `No active session found.` on stdout. `--json` prints `{"status":"not_running"}` (fine).
Repro: in any directory with no `.grantiva/session.json`, `grantiva runner stop 2>/dev/null`
Evidence: json/forced-failures.txt, detect/misc-validation.txt

### CLI-F03: `auth logout` when not logged in claims it removed credentials
Matrix IDs: CLI-090
Severity: ux
Command: grantiva auth logout
Expected: succeeds or reports nothing to remove (source: help: auth logout)
Actual: exit 0, stdout `Logged out. Credentials removed from ~/.grantiva/auth.json` although `~/.grantiva/auth.json` never existed.
Repro: with no `~/.grantiva/auth.json`, run `grantiva auth logout`
Evidence: auth-logout-and-bad-platform.txt

### CLI-F04: Emulator ledger records a pre-existing, user-started emulator as Grantiva-started (teardown --all would kill it)
Matrix IDs: CLI-016 (observed while scoring; the row itself passes)
Severity: wrong-result
Command: grantiva emulator sessions --json
Expected: only emulators Grantiva started are listed, so `emulator teardown --all` touches nothing else (source: CHANGELOG Unreleased "Emulators Grantiva boots are recorded in ~/.grantiva/android/started.json"; help: emulator teardown)
Actual: `started.json` holds `{"serial":"emulator-5554","avd":"Pixel_8_API_35","pid":19482}` written 13:43 today. The real emulator-5554 is qemu pid 49817, started Oct 7 outside Grantiva. `~/.grantiva/android/emulator-5554.log` (13:40) ends in `FATAL | Running multiple emulators with the same AVD is an experimental feature`: Grantiva spawned a second copy of the same AVD on port 5554, it died at once, and the record stayed, pointing at someone else's emulator. `emulator sessions` shows `pid 19482 exited, adb: device`.
Repro: with an AVD already running on 5554 that `adb devices` momentarily does not list (adb restart, or still offline), call `EmulatorManager.boot(avd:)` (e.g. `run --emulator Pixel_8_API_35`). Not reproduced deliberately: it would disturb the Android slice's emulator.
Evidence: json/emulator_sessions.out, ~/.grantiva/android/started.json and emulator-5554.log at 13:43 (quoted above)
Suspected cause: Sources/GrantivaCore/Android/EmulatorManager.swift:210-221 picks a port from `adb devices` alone and registers the record before boot; `waitForBoot` (:227-243) then sees `sys.boot_completed=1` on the *existing* emulator at that serial before it notices the spawned pid died, so the record is never removed. Port choice should also exclude ports in use (console port bind) and the record should be dropped when the spawned pid is not the emulator answering on the serial.

### CLI-F05: With no config file, `run` says "No screens or flows configured in grantiva.yml", even on Android
Matrix IDs: CLI-024, CLI-038 (observed; rows pass)
Severity: ux
Command: grantiva run --no-build --platform android (directory with only settings.gradle.kts)
Expected: an error naming the missing config file for the resolved platform and how to create it (`grantiva init --platform android`) (source: CHANGELOG Unreleased "an error naming the missing file")
Actual: `Error: Invalid argument: No screens or flows configured in grantiva.yml` for iOS and Android alike, whether or not any config exists.
Repro: `fixtures/detect/gradle-only`, `grantiva run --no-build --platform android`
Evidence: detect/detect.txt
Suspected cause: Sources/GrantivaCLI/RunCommand.swift:158 hardcodes `grantiva.yml` and does not distinguish "no file" from "file with nothing in it".

### CLI-F06: `doctor` in a directory with both an Xcode project and Gradle settings treats both toolchains as required
Matrix IDs: CLI-025
Severity: ux
Command: grantiva doctor (fixtures/detect/both)
Expected: like `run`/`init`, ask for `--platform ios|android` (or `GRANTIVA_PLATFORM`) rather than silently picking (source: CHANGELOG Unreleased Changed)
Actual: `run` and `init` refuse correctly. `doctor` lists Xcode and the Android SDK, adb, emulator, JDK, AVDs all under "Required" and exits 1 when any fails (here the JDK): `9 passed · 5 optional · 1 failed`. A KMP user who only wants iOS gets a failing doctor because of Android.
Repro: copy fixtures/detect/both, run `grantiva doctor; echo $?`
Evidence: detect/detect.txt

### CLI-F07: `init` in an empty directory silently writes a placeholder config
Matrix IDs: CLI-072
Severity: ux
Command: grantiva init (empty directory)
Expected: a clear error that no project was found, or a documented default; never a half-filled config written silently (source: help: init)
Actual: exit 0, stderr `Created grantiva.yml`, file contains `scheme: MyApp` and `simulator: iPhone 16` (a device this Xcode 27 host does not have), with no warning that both are placeholders.
Repro: `cd $(mktemp -d) && grantiva init && cat grantiva.yml`
Evidence: detect/detect.txt

### CLI-F08: `--report-dir`, `--timeout`, and `--continue-on-failure` are ignored when `run` executes screens
Matrix IDs: CLI-027 (observed), related IOS rows using `--report-dir`
Severity: wrong-result
Command: grantiva run --no-build --simulator qa-cli-1 --report-dir out --timeout 60 (in a directory whose flows come from `.maestro/`, a Maestro-format `grantiva.yml`, or `screens:`)
Expected: report.json, junit and assets are written to `out/` and survive cleanup; the runner is killed after `--timeout` (source: help: run `--report-dir`, `--timeout`)
Actual: `out/` contains only `captures/failure-*.png`. The runner prints `Reports: /var/folders/.../grantiva-report-<uuid>/report.json`, a directory that no longer exists when the command returns. Only `flows:` entries and `--flow` honour the three flags.
Repro: copy fixtures/detect/maestro-dir, `grantiva run --no-build --simulator <udid> --report-dir out; find out`
Evidence: detect/maestro-detect.txt
Suspected cause: Sources/GrantivaCLI/RunCommand.swift:269-283, the `runScreens` closure calls `RunnerSession.run(screens:…)` without `reportDir`, `timeoutSeconds`, or `failFast`; only `runFlows` (:285-304) passes them.

### CLI-F09: Misspelled or unknown config keys are silently ignored
Matrix IDs: CLI-039
Severity: ux
Command: grantiva run --no-build with `grantiva.yml` containing `schem: Landmarks` and `screen:` (fixtures/config/unknown-keys.yml)
Expected: unknown keys rejected or warned about (source: spec §2; matrix CLI-039 says a silent ignore of a misspelled required key is a ux finding)
Actual: no warning; the run fails with the unrelated `No screens or flows configured in grantiva.yml`.
Repro: as above
Evidence: detect/config.txt

### CLI-F10: `doctor` reports an unparsable config as "Found"
Matrix IDs: CLI-037 (observed; row passes for `run`)
Severity: ux
Command: grantiva doctor --platform android (fixtures/config/malformed-android.yml as grantiva-android.yml)
Expected: doctor flags a config that `run` will refuse ("an error naming the file and the YAML position") (source: CHANGELOG Unreleased Added)
Actual: `✓ grantiva-android.yml  Found`; `run` in the same directory fails with `grantiva-android.yml could not be parsed: 5:3: …`.
Repro: as above
Evidence: detect/config.txt

### CLI-F11: An invalid `GRANTIVA_PLATFORM` is ignored by `doctor` and `init`
Matrix IDs: CLI-033
Severity: contract
Command: GRANTIVA_PLATFORM=windows grantiva doctor; GRANTIVA_PLATFORM=windows grantiva init
Expected: error naming the bad value and the accepted values, non-zero exit (source: help: run "values: ios, android")
Actual: `doctor` exits 0 and checks both toolchains; `init` exits 0 and writes an iOS `grantiva.yml`. `run`, `build`, `diff capture`, and `mcp` correctly say `GRANTIVA_PLATFORM is "windows"; expected ios or android.`
Repro: in an empty dir run both commands with the variable set
Evidence: auth-logout-and-bad-platform.txt
Suspected cause: doctor and init resolve the platform through a path that does not call `PlatformResolver` validation of the environment value (Sources/GrantivaCLI/DoctorCommand.swift:32 and the init command).

### CLI-F12: `init` accepts the other platform's flags without complaint
Matrix IDs: CLI-076
Severity: contract
Command: grantiva init --platform android --scheme X; grantiva init --platform ios --application-id a.b
Expected: "A flag from the other platform is rejected by name." (source: CHANGELOG Unreleased Added)
Actual: both exit 0 and write the config; the stray flag is dropped silently. `run` rejects the same flags by name.
Repro: fixtures/detect/gradle-only and xcode-only
Evidence: detect/platform-flags.txt

### CLI-F13: Error messages tell users to run commands that do not exist (`grantiva sim boot`, `grantiva ui a11y`)
Matrix IDs: — (seen via MCP `grantiva_tap`; CLI surface)
Severity: ux
Command: MCP `grantiva_tap {"label":"No Such Label QA"}`; any path that throws `simulatorNotRunning`
Expected: remediation lines name real commands
Actual: `Element not found: "No Such Label QA". Run grantiva ui a11y to inspect the tree.` and `No simulator is running. Run: grantiva sim boot "iPhone 16"`. `grantiva sim boot "iPhone 16"` exits 64 (`3 unexpected arguments`). The doctor fix line also says `xcrun simctl boot "iPhone 16"`, a device type absent from Xcode 27 hosts.
Repro: as above
Evidence: mcp/calls-ios-summary.tsv (id 150)
Suspected cause: Sources/GrantivaCore/GrantivaError.swift:29 and :33; Sources/GrantivaCore/Doctor/DoctorRunner.swift:98.

### CLI-F14: `record --frames-at a,b` records the whole duration before rejecting the value
Matrix IDs: CLI-102
Severity: contract
Command: grantiva record --duration 2 --frames-at a,b --simulator qa-cli-1
Expected: usage error for non-numeric frame timestamps before recording (source: help: record `--frames-at`)
Actual: records for the full duration, writes the video, then `Error: Invalid argument: --frames-at must contain non-negative integer milliseconds`, exit 1 (not 64). With `--duration 180` that is three minutes wasted.
Repro: as above
Evidence: record/notes.txt

### CLI-F15: `record` prints simctl's own narration on stdout
Matrix IDs: CLI-102 (observed)
Severity: contract
Command: grantiva record --duration 2 --frames-at 500,1500 --simulator qa-cli-1 --output x.mp4 > out.txt
Expected: stdout carries only the result (source: README §stdout is the result, stderr is the commentary)
Actual: stdout begins with `Recording completed. Writing to disk.` and `Wrote video to: …` from `simctl io recordVideo`, before Grantiva's own result lines.
Repro: as above
Evidence: record/record-valid.stdout

### CLI-F16: `record --output` without an extension records, then fails with "Error: Cannot Open"
Matrix IDs: — (record, iOS)
Severity: ux
Command: grantiva record --duration 2 --frames-at 1,5 --simulator qa-cli-1 --output /tmp/rec
Expected: the path is accepted (help: "Output video path"), or rejected up front with a reason
Actual: the QuickTime file is written to `/tmp/rec`, then frame extraction fails with the bare `Error: Cannot Open`, exit 1.
Repro: as above
Evidence: record/notes.txt

### CLI-F17: `console webhooks create --event` names are not validated before the request
Matrix IDs: CLI-096
Severity: contract
Command: GRANTIVA_API_KEY=qa-invalid-key grantiva console webhooks create https://x --event not.an.event
Expected: "Event names are validated before the request." (source: CHANGELOG 1.9.0)
Actual: the request is sent (the bogus key comes back as `Error: Not authenticated`); `validate()` only checks for blank events and the https URL. Compare `console analytics events --type bogus`, which is rejected locally with the list of valid types.
Repro: as above
Evidence: console-unauth.txt
Suspected cause: Sources/GrantivaCLI/ConsoleOrgAdminCommands.swift:77-87 (`webhooks create`) and :134-140 (`update`).

### CLI-F18: `grantiva mcp` will not start (no `initialize`, no `tools/list`) without a config file and a live runner session
Matrix IDs: CLI-099
Severity: contract
Command: grantiva mcp --project-dir <dir with grantiva.yml, no session>
Expected: "starts the MCP server for AI agent integration" (source: README §Commands; help: mcp). An agent should be able to connect and use the tools that need no session (`grantiva_sim_list/boot/ensure/delete`, `grantiva_emulator_*`, `grantiva_build`, `grantiva_context`, the VRT tools) to get to a device.
Actual: exits 1 before reading stdin, with `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or 'grantiva run --keep-alive'.` Without a config file: `No grantiva.yml or grantiva-android.yml found`. An MCP client shows only "server failed to start". The device-provisioning tools are reachable only once a device is already provisioned.
Repro: fixtures/mcp/send.sh <dir> ios
Evidence: mcp/startup.txt; help/mcp-tools-probe.txt
Suspected cause: Sources/GrantivaMCP/MCPServer.swift:20-36, `resolveProjectDirectory`, `loadActiveSession` and `attachDriver` all run before `server.start`; the driver could be attached lazily on first use.

### CLI-F19: MCP VRT tools run whatever `grantiva` is on PATH, not the server's own binary
Matrix IDs: — (Step 5, MCP)
Severity: wrong-result
Command: MCP tools/call `grantiva_vrt_capture`, `grantiva_vrt_compare`, `grantiva_vrt_approve` from `~/.grantiva-qa/bin/grantiva mcp`
Expected: the tools are "Equivalent to 'grantiva diff capture --no-build --json'" for the running Grantiva
Actual: every call returns `isError` with `Error: Unknown option '--platform'`, because `/opt/homebrew/bin/grantiva` (2.0.0, no `--platform`) is the one on PATH. Any user whose MCP config points at a non-PATH build, or whose PATH holds an older Homebrew copy, gets a version mismatch, or no tool at all if `grantiva` is not on PATH.
Repro: put an older grantiva on PATH, start `mcp` from a newer binary, call `grantiva_vrt_compare`
Evidence: mcp/calls-ios-summary.tsv (ids 118-120, 138, 141-142, 159-160)
Suspected cause: Sources/GrantivaMCP/Tools/VRTTools.swift:55-66 builds `"grantiva diff …"` shell strings; should use the running executable's path.

### CLI-F20: MCP `grantiva_context` reports the first booted simulator on the machine, not the session's device
Matrix IDs: — (Step 5, MCP)
Severity: wrong-result
Command: MCP `grantiva_context` with a runner session on qa-cli-1 (D3E7E498-…)
Expected: the [Simulator] section describes the device the tools act on
Actual: `[Simulator] name: iPhone 17 Pro udid: B27D7D31-…` (another agent's simulator), while `[Runner Session] udid: D3E7E498-…`. An agent reading context will reason about the wrong device.
Repro: two booted simulators, runner session on the second one
Evidence: mcp/calls-ios.jsonl (id 116)
Suspected cause: Sources/GrantivaMCP/Tools/ContextTool.swift:60 uses `simManager.bootedDevice()` (first booted) instead of `session.udid`.

### CLI-F21: MCP server attaches to any keep-alive session on the machine, including another project's or another platform's
Matrix IDs: CLI-099, CLI-100 (observed)
Severity: wrong-result
Command: grantiva mcp --project-dir <unrelated iOS project, no .grantiva/session.json> while another project holds `grantiva run --keep-alive` on qa-cli-1
Expected: the server uses the project's own session, or refuses
Actual: it starts and drives the other project's simulator: `grantiva_a11y_tree` returns that app's tree (Settings on qa-cli-1) even though this project is configured for `iPhone 16e` / `com.example.other`, and `grantiva_context` says `[Runner Session] No active session.` An Android project in the same situation tries `adb` against the iOS UDID and exits (`adb: device 'D3E7E498-…' not found`). With several agents on one Mac, an MCP client can tap and type into someone else's device.
Repro: fixtures/mcp/client.py against a dir with only grantiva.yml while a `run --keep-alive` is live elsewhere
Evidence: mcp/keepalive-fallback-unrel-ios-*.jsonl, mcp/keepalive-fallback-unrel-android-*.jsonl, mcp/keepalive-run-tail.txt
Suspected cause: Sources/GrantivaMCP/MCPServer.swift:150-163 falls back to `KeepAliveSessionStore().locate()` (newest session machine-wide) with no check on project, bundle ID, configured simulator, or platform.

### CLI-F22: MCP `grantiva_script` reports success when every step is invalid
Matrix IDs: — (Step 5, MCP)
Severity: ux
Command: tools/call grantiva_script {"steps":[{"bogus":1},5]}
Expected: an `isError` result naming the bad steps
Actual: a normal result: `Step 1: unknown action, skipped / Step 2: skipped (not an object)` and the hierarchy. An agent checking `isError` thinks the script ran.
Repro: as above
Evidence: mcp/calls-ios.jsonl (id 137)

### CLI-F23: A runner re-extract deletes all of `~/.grantiva/runner` first, including live simulator lease locks, and has no rollback; with the resource bundle missing it crashes and leaves no runner
Matrix IDs: CLI-084 (Step 6 repair check; the row's idempotence passes)
Severity: crash
Command: printf garbage > ~/.grantiva/runner/version; ~/.grantiva-qa/bin/grantiva runner install
Expected: `runner install` repairs a damaged install (brief Step 6) and never breaks a working one
Actual: `Extracting runner...` then `GrantivaCore/resource_bundle_accessor.swift:44: Fatal error: unable to find bundle named grantiva_GrantivaCore`, SIGTRAP, exit 133. By then `~/.grantiva/runner` had been removed: the runner binary, `version`, `drivers/`, `locks/` (simulator lease files held by other running processes), `reports/`, and `grantiva-wda.xcconfig` were gone. Only `cache/` survived (moved aside). Every Grantiva process on the machine was without a runner until it was repaired with the identical build that has its bundle (`.build/out/Products/Release/grantiva runner install`). Even on a normal upgrade with the bundle present, deleting `locks/` lets a new process lease a simulator that a running process still holds.
Repro: as above, with any build that lacks `grantiva_GrantivaCore.bundle` next to the executable (the campaign's copied binary). The bundle-present path re-extracts correctly.
Evidence: runner/runner-install.txt
Suspected cause: Sources/GrantivaCore/Runner/RunnerManager.swift:138 `removeItem(atPath: baseDir)` before `extract` (:141). It should extract into a temp dir and swap only the binary, version and drivers, leaving `locks/`, `reports/` and the xcconfig alone. Also the embedded-resource lookup should fail with an error, not a trap. Note `HOME` is ignored (`HOME=/tmp/x grantiva runner install` still writes the real ~/.grantiva), so this cannot be tried in a sandbox.

### CLI-F24: `swipe: diagonal` in `screens:` is accepted at parse time and fails only on the device
Matrix IDs: CLI-047
Severity: contract
Command: grantiva run --no-build --simulator qa-cli-1 --bundle-id com.apple.Preferences (fixtures/config/swipe-diagonal.yml)
Expected: rejected at parse time; README lists only up, down, left, right (source: README §Screens)
Actual: the generated flow carries `swipe: direction: DIAGONAL`; the runner boots the simulator, launches the app, and fails the step with `Invalid swipe direction (cause: invalid direction: DIAGONAL)`.
Repro: as above
Evidence: flows/swipe-diagonal.txt
Suspected cause: Sources/GrantivaCore/Runner/FlowGenerator.swift:86-93 (`default: return direction.uppercased()`); no validation in GrantivaConfig.

### CLI-F25: `simulator sessions --json` and `emulator sessions --json` timestamps are seconds since 2001, not Unix time or ISO 8601
Matrix IDs: CLI-015, CLI-016 (observed; rows pass)
Severity: ux
Command: grantiva simulator sessions --json
Expected: a timestamp a script can read (`run --ready-file` uses ISO 8601 `finishedAt`)
Actual: `"acquiredAt" : 813129327.501302`, `"startedAt" : 813271244.347498`. These are Swift `Date` reference-date seconds (2001-01-01); read as Unix time they land in 1995.
Repro: as above
Evidence: json/simulator_sessions.out, json/emulator_sessions.out

### CLI-F26: `doctor --platform android` with a bogus `ANDROID_HOME` silently reports a different SDK
Matrix IDs: CLI-082
Severity: ux
Command: env -u ANDROID_SDK_ROOT ANDROID_HOME=/nonexistent grantiva doctor --platform android
Expected: the check fails, or at least warns that `ANDROID_HOME` points nowhere (source: CHANGELOG 1.8.0 Fixed; docs/android-environment.md)
Actual: `✓ Android SDK /Users/kyle/Library/Android/sdk`, no mention that `ANDROID_HOME` was set and ignored. The documented fallback order (ANDROID_HOME, ANDROID_SDK_ROOT, ~/Library/Android/sdk) explains it, but a user whose shell exports a stale `ANDROID_HOME` is not told. The row's own case (no SDK anywhere) could not be set up without hiding the shared SDK.
Repro: as above
Evidence: detect/doctor-init.txt
