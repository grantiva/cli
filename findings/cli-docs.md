# CLI slice: documentation consistency findings

These come from the Step 3 cross-source pass, done by reading the sources only. Each entry
backs one consistency row (CLI-109 to CLI-122) in
`docs/superpowers/plans/2026-10-09-qa-feature-matrix.md`. Help line numbers refer to the
dumps in `help/`.

### CLI-DOCS-F01: README runs `grantiva run --device "$udid" flows/`, but `run` takes no positional argument and `--device` is Android-only
Matrix IDs: CLI-109
Severity: docs
Command: grantiva run --device "$udid" flows/
Expected: Pass the iOS simulator UDID from `simulator ensure` to `run` and give it a flows directory (source: README §stdout is the result)
Actual: `run` has no positional arguments (`USAGE: grantiva run <options>`). `--device` is "adb serial of an attached emulator or physical device (Android)", and an iOS project rejects it by name. The iOS flag is `--simulator`, and a single flow is passed with `--flow` (source: help: run)
Repro: read both
Evidence: README.md:353; help/run.txt:4, help/run.txt:34

### CLI-DOCS-F02: README says runner lifecycle commands have no JSON result, but help lists `--json` on all of them
Matrix IDs: CLI-110
Severity: docs
Command: grantiva runner start|stop|install|version --help
Expected: "runner lifecycle commands do not have a JSON result" (source: README §Dashboard commands)
Actual: `runner start`, `runner stop`, `runner install`, and `runner version` each list `--json  Output as JSON` (source: help: runner_*)
Repro: read both
Evidence: README.md:310-312; help/runner_start.txt:6, help/runner_stop.txt:6, help/runner_install.txt:6, help/runner_version.txt:6

### CLI-DOCS-F03: README §Commands is missing `emulator`, `console`, and `runner dump-hierarchy`, and describes several commands as iOS-only
Matrix IDs: CLI-111
Severity: docs
Command: grantiva --help
Expected: The command list covers every top-level command and subcommand. `record` records "a simulator", and `build` builds "via xcodebuild for a simulator" (source: README §Commands)
Actual: Top-level help lists `emulator` ("Provision, inspect, and tear down Android emulators") and `console`, and `runner` has a `dump-hierarchy` subcommand; the README list has none of the three. `record` covers "a simulator or emulator", and README line 7 says `build` works on Android (source: help: grantiva, help: runner, help: record)
Repro: read both
Evidence: README.md:263-288; help/grantiva.txt (SUBCOMMANDS), help/runner.txt (dump-hierarchy), help/record.txt:1

### CLI-DOCS-F04: README says unsupported Maestro commands are silently skipped, but the flow parser rejects them
Matrix IDs: CLI-112, CLI-065
Severity: docs
Command: grantiva diff capture (with a Maestro flow containing `- back` or `- setPermissions: …`)
Expected: "Unsupported commands (scripting, permissions, etc.) are silently skipped." The supported list is `tapOn`, `inputText`, `assertVisible`, `assertNotVisible`, `swipe`, `scroll`, `runFlow`, `extendedWaitUntil`, `waitForAnimationToEnd`, and `takeScreenshot` (source: README §Maestro Compatibility)
Actual: `MaestroFlowParser.parse` and `loadDirectory` use `allowUnsupportedCommands: false` by default and throw "Unsupported Maestro command '<name>' at <file>:<line>". The parser also accepts `doubleTapOn`, `longPressOn`, `scrollUntilVisible`, `launchApp`, `stopApp`, and `killApp`, none of which the README lists (source: Sources/GrantivaCore/Config/MaestroFlowParser.swift)
Repro: read both; CLI-065 checks the behavior
Evidence: README.md:149; Sources/GrantivaCore/Config/MaestroFlowParser.swift:120-121, 195-197, 236-238, 375, 399

### CLI-DOCS-F05: `simulator cleanup` is described differently in README and in help
Matrix IDs: CLI-113
Severity: docs
Command: grantiva simulator cleanup --help
Expected: "Delete unavailable and stale Grantiva-managed simulators" (source: README §Commands)
Actual: "Delete Grantiva-created simulators that are shut down and not part of an active session." SIMULATOR-LIFECYCLE.md agrees with help and does not mention "unavailable" devices (source: help: simulator cleanup; SIMULATOR-LIFECYCLE.md)
Repro: read both
Evidence: README.md:277; help/simulator_cleanup.txt:1-2; SIMULATOR-LIFECYCLE.md:21

### CLI-DOCS-F06: `simulator delete` and `simulator sessions` have no help abstract
Matrix IDs: CLI-114, CLI-003
Severity: docs
Command: grantiva simulator --help
Expected: Every subcommand has a one-line description: "Explicitly delete a named simulator" and "List Grantiva-managed simulator capacity slots" (source: README §Commands)
Actual: In `grantiva simulator --help`, `delete` and `sessions` have an empty description column, and their own `--help` pages have no OVERVIEW line (source: help: simulator, simulator delete, simulator sessions)
Repro: read both
Evidence: README.md:274-275; help/simulator.txt:14-15; help/simulator_delete.txt:1, help/simulator_sessions.txt:1

### CLI-DOCS-F07: CHANGELOG lists `console webhooks events`, but no such subcommand exists
Matrix IDs: CLI-115
Severity: docs
Command: grantiva console webhooks --help
Expected: `console webhooks` includes "`events` (the subscribable event types)" (source: CHANGELOG 1.9.0)
Actual: The subcommands are list, get, create, enable, disable, update, delete, test, deliveries, and retry. There is no `events` (source: help: console webhooks)
Repro: read both
Evidence: CHANGELOG.md:76; help/console_webhooks.txt (SUBCOMMANDS)

### CLI-DOCS-F08: The binary reports 2.0.1 but contains features CHANGELOG lists under Unreleased
Matrix IDs: CLI-116
Severity: docs
Command: grantiva --version; grantiva emulator --help
Expected: 2.0.1 contains what the `2.0.1 — 2026-10-07` entry describes. Android support, `emulator`, and the Android MCP tools are listed under `## Unreleased` (source: CHANGELOG)
Actual: The 2.0.1 binary under test prints `2.0.1` and ships `emulator`, `--platform`, and the other Unreleased features. A user cannot tell from `--version` which CHANGELOG entry describes their build (source: help: grantiva, emulator)
Repro: read both
Evidence: CHANGELOG.md:3-38, CHANGELOG.md:40; help/emulator.txt; `~/.grantiva-qa/bin/grantiva --version`

### CLI-DOCS-F09: docs/android-environment.md implies Android `ci run` works on a self-hosted Mac, but docs/android.md says `ci run` refuses Android
Matrix IDs: CLI-117, CLI-108
Severity: docs
Command: grantiva ci run --platform android
Expected: "Android `ci run` needs a self-hosted Mac runner or a developer machine." (source: docs/android-environment.md §CI)
Actual: "`ci run` and remote baselines refuse Android with 'Android baselines are local only until the Grantiva backend supports platforms; use local baselines'." CHANGELOG Unreleased says the same (source: docs/android.md §Captures and baselines)
Repro: read both
Evidence: docs/android-environment.md:20-22; docs/android.md:46-50; CHANGELOG.md:22

### CLI-DOCS-F10: docs/android.md §Devices contradicts itself about booting an existing AVD
Matrix IDs: CLI-118
Severity: docs
Command: grantiva run --platform android (no `emulator:` configured)
Expected: "Only running emulators are considered by default." (source: docs/android.md §Devices, first sentence)
Actual: The same paragraph continues: "With no `emulator:`, a single running emulator is used, else a single existing AVD is booted." (source: docs/android.md §Devices, third sentence)
Repro: read both
Evidence: docs/android.md:33-35

### CLI-DOCS-F11: Help overviews still describe the tool as iOS-only
Matrix IDs: CLI-119
Severity: docs
Command: grantiva --help; grantiva run --help; grantiva build build --help
Expected: Commands that support Android say so. README line 7 says `build` and `run` work against an Android emulator (source: README; docs/android.md)
Actual: The top-level overview says "The Grantiva CLI for iOS developers." `run` says "Run Maestro flows against a simulator", and its `--no-build` says "assume the app is already on the simulator". `build build` says "Build the app for a simulator using xcodebuild." (source: help: grantiva, run, build build)
Repro: read both
Evidence: help/grantiva.txt:1; help/run.txt:1, help/run.txt (`--no-build`); help/build_build.txt:1; README.md:3, README.md:7

### CLI-DOCS-F12: `hierarchy` advertises both `--json` and `--format`, but the docs mention only `--format`
Matrix IDs: CLI-120, IOS-050, AND-055
Severity: docs
Command: grantiva hierarchy --json
Expected: The output format is chosen with `--format xml|json`, and XML is the default (source: docs/dump-hierarchy.md §Flags; README §Dashboard commands)
Actual: Help also lists `--json  Output as JSON`, with no stated precedence. In `HierarchyCommand`, only `format` selects the route and the rendering, so `--json` alone appears to still print XML (source: help: hierarchy; Sources/GrantivaCLI/HierarchyCommand.swift:41-42, 80, 101-120). `runner dump-hierarchy` has the same pair (`--json` and `-f/--format`)
Repro: read both; IOS-050 and AND-055 check the behavior
Evidence: help/hierarchy.txt:25, help/hierarchy.txt:35; docs/dump-hierarchy.md:32-37; README.md:309-312; help/runner_dump-hierarchy.txt

### CLI-DOCS-F13: No document says that `--ready-file` creates a missing parent directory
Matrix IDs: CLI-121, IOS-033, IOS-034, AND-033
Severity: docs
Command: grantiva run --ready-file /tmp/does-not-exist/x.ready
Expected: "an unwritable path fails immediately rather than at the end of a long suite". Neither README nor help mentions creating directories (source: README §Agent-Native Features; help: run)
Actual: `ReadyFile.prepare` runs `createDirectory(withIntermediateDirectories: true)` for a missing parent and fails only when that fails or the write probe fails. A typo in the directory part of the path silently creates a directory instead of failing (source: Sources/GrantivaCore/Runner/ReadyFile.swift)
Repro: read both; IOS-033 and IOS-034 check the behavior
Evidence: README.md:85; help/run.txt:71-78; Sources/GrantivaCore/Runner/ReadyFile.swift:73-81

### CLI-DOCS-F14: The MCP server has 22 tools, not the 19 the QA spec assumes, and no CLI doc gives the full list
Matrix IDs: CLI-122, IOS-099, AND-093
Severity: docs
Command: grantiva mcp (tools/list)
Expected: "`tools/list` schema for all 19 tools" (source: docs/superpowers/specs/2026-10-09-qa-campaign-design.md §2)
Actual: The source defines 22 tools: build, run, test, context, emulator_list/boot/ensure/delete, script, sim_list/boot/ensure/delete, screenshot, tap, swipe, type, a11y_tree, a11y_check, and vrt_capture/compare/approve. README and the docs name some of them but list none in full (source: help/mcp-tools-probe.txt; CHANGELOG Unreleased; docs/android.md §Runner sessions and the MCP server)
Repro: read both
Evidence: docs/superpowers/specs/2026-10-09-qa-campaign-design.md:144; help/mcp-tools-probe.txt; docs/android.md:96-102
