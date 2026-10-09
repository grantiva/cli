# QA feature matrix — Grantiva CLI 2.0.1

Built 2026-10-09 against `~/.grantiva-qa/bin/grantiva` (`--version` 2.0.1) for the cross-platform
QA campaign (spec: `docs/superpowers/specs/2026-10-09-qa-campaign-design.md` §2; plan:
`docs/superpowers/plans/2026-10-09-qa-campaign.md`).

Raw help for every command and subcommand (172 pages, including top-level `grantiva.txt`) is committed under `help/`, with the MCP
probe in `help/mcp-tools-probe.txt`. `grantiva mcp` will not answer `initialize` or `tools/list`
without a config file and a live runner session, so the tool list there was taken from
`Sources/GrantivaMCP/Tools/*.swift`. It has 22 tools, not the 19 the spec mentions.

**Result column.** Agents fill it in with `pass`, `fail <finding id>`, `blocked <reason>`, or `host <reason>`.
The only rows already filled are the cross-source consistency rows at the end of the CLI slice.
They were checked by reading the sources (Step 3) and each links to its entry in `findings/cli-docs.md`.

**Source labels.** `help: <cmd>` is `help/<cmd>.txt`. `README §X`, `docs/<file> §X`,
`SIMULATOR-LIFECYCLE.md`, and `CHANGELOG <version>` point at those documents in this worktree. `spec §2`
marks a row the spec asks for that no CLI document describes, so the expected behavior is the spec's.

**Review Focus IDs** (plan, fixed meanings): CLI-044 (`flows: []` and report.json), CLI-061 (tapOn label
with a double quote and an emoji, parsing path), IOS-031 (empty flows on device), IOS-033 and AND-033
(`--ready-file` inside a nonexistent directory fails before build), IOS-035 and AND-035
(`--env 'LANDMARKS_NOTE=a=b c'`), IOS-041 and AND-041 (quoted label tapOn on device), IOS-052 and AND-052
(`hierarchy` with two live keep-alive sessions and no `--udid` picks the newest).

The code creates a missing `--ready-file` parent directory when it can (`ReadyFile.prepare`).
IOS-033 and AND-033 therefore use a parent that cannot be created (`/nonexistent-qa/...`, under the
read-only root). IOS-034 records what happens with a parent that can be created. See CLI-DOCS-F13.

## CLI slice (device-free)

**Help surface**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-001 | `grantiva --help`, `grantiva --version` | none | Exit 0. `--version` prints `2.0.1`; help lists build, run, record, simulator, emulator, hierarchy, ci, diff, auth, console, doctor, runner, init, mcp. | help: grantiva | pass |
| CLI-002 | `grantiva help <subcommand>` | e.g. `grantiva help run`, `grantiva help console flags` | Prints the same text as `<subcommand> --help` and exits 0 ("See 'grantiva help <subcommand>' for detailed help"). | help: grantiva | pass |
| CLI-003 | every command and subcommand `--help` | all 172 pages under `help/` | Each exits 0 and prints OVERVIEW (where an abstract exists), USAGE and OPTIONS; output matches the committed `help/*.txt` dump byte for byte. | help: all | pass |
| CLI-004 | `run --help` | none | Lists exactly the flags in `help/run.txt`; every flag README §Agent-Native Features and docs/android.md §Devices name is present, and none is undocumented elsewhere. | help: run; README §Agent-Native Features; docs/android.md §Devices | fail CLI-F01 |
| CLI-005 | `build build --help`, `build install --help` | none | `build install` adds `--app-file`, `--no-build`, `--no-launch`; `build build` has none of the three. `build` with no subcommand defaults to `build build`. | help: build, build build, build install | pass |
| CLI-006 | `diff capture/compare/approve --help` | none | `compare` adds `--capture` ("runs full lifecycle"); `approve` takes `[<screen-names> ...]` and `--platform` only. | help: diff_* | pass |
| CLI-007 | `simulator <sub> --help`, `emulator <sub> --help` | ensure, delete, sessions, teardown, cleanup | Each exits 0 and documents its flags; `simulator ensure` shows `--boot/--no-boot (default: --boot)`; `emulator teardown` shows `--serial`, `--all`, `--force`. | help: simulator_*, emulator_* | pass |
| CLI-008 | `runner <sub> --help`, `hierarchy --help`, `record --help` | install, version, start, stop, dump-hierarchy | Each exits 0; `runner dump-hierarchy` shows `-p/--port`, `-f/--format` (tree, json, xml; default tree), `--udid`; `record` marks `--duration` required. | help: runner_*, hierarchy, record | pass |
| CLI-009 | `console --help` tree | all 17 groups | Lists flags (alias `featureflags`), envs, analytics, devices, apps, claims, vrt, releases, feedback, support, webhooks, alerts, keys, team, audit, org, open; `grantiva console featureflags --help` equals `console flags --help`. | help: console; CHANGELOG 1.9.0 | pass |
| CLI-010 | any command | unknown flag, e.g. `run --bogus` | Usage error on stderr, non-zero exit, stdout empty. | README §stdout is the result, stderr is the commentary | pass |

**stdout / stderr contract**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-011 | `doctor --json` | none | stdout is valid JSON (an array of checks with `status`), so `grantiva doctor --json \| jq '.[] \| select(.status == "fail")'` works; narration absent from stdout. | README §stdout is the result | pass |
| CLI-012 | `doctor --json --quiet` | none | "`grantiva doctor --json --quiet \| jq` is still valid JSON." | README §stdout is the result; CHANGELOG 1.8.0 | pass |
| CLI-013 | `doctor --json --verbose` | none | stdout valid JSON; stderr gains timestamps, labels and every subprocess (`$ xcrun …` plus exit status). | README §stdout is the result; CHANGELOG 1.8.0 Added | pass |
| CLI-014 | `doctor` | `> out.txt`, and with `NO_COLOR=1` | No ANSI escapes in redirected stdout; `NO_COLOR` suppresses colour on a TTY. | CHANGELOG 1.8.0 Fixed | pass |
| CLI-015 | `simulator sessions --json` | neither, `--quiet`, `--verbose` | stdout valid JSON in all three modes; only diagnostics on stderr. | README §stdout is the result; help: simulator sessions | pass |
| CLI-016 | `emulator sessions --json` | neither, `--quiet`, `--verbose` | stdout valid JSON in all three modes. | help: emulator sessions | pass |
| CLI-017 | `runner version` | with and without `--json` | Prints the embedded runner version; `--json` output is valid JSON. | help: runner version; README §Commands | pass |
| CLI-018 | `auth status --json` | not logged in, `GRANTIVA_API_KEY` unset | stdout is valid JSON or empty; any error goes to stderr with a non-zero exit. | README §stdout is the result; help: auth status | pass |
| CLI-019 | every leaf command with `--json` | a forced failure (e.g. run in an empty dir) | Error printed to stderr prefixed `Error:`, exit non-zero, stdout empty (no partial JSON). | README §stdout is the result; CHANGELOG 1.8.0 Changed | pass |
| CLI-020 | any command | `--quiet` | Progress narration silenced; warnings (`Warning:`) and errors (`Error:`) still print on stderr; stdout unchanged. | README §stdout is the result; help: `--quiet` | pass |
| CLI-021 | any command | `--verbose` | "adds debug-level detail, with timestamps and labels"; stdout unchanged. | README §stdout is the result | pass |
| CLI-022 | `console open --json` | `flags` | Prints the dashboard URL instead of opening a browser; exit 0; nothing launched. | help: console open; CHANGELOG 1.9.0 | pass |

**Project detection**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-023 | `doctor`, `init` | dir with only an `.xcodeproj` | Resolves to iOS ("an `.xcodeproj` or `.xcworkspace` means iOS"). | docs/android.md §Setup | pass |
| CLI-024 | `doctor`, `init` | dir with only `settings.gradle.kts` | Resolves to Android ("a `settings.gradle` or `settings.gradle.kts` means Android"). | docs/android.md §Setup | pass |
| CLI-025 | `run`, `doctor` | dir with both `.xcodeproj` and `settings.gradle.kts`, no config | Error asking for `--platform ios` (or `GRANTIVA_PLATFORM`); not silently iOS. | CHANGELOG Unreleased Changed | fail CLI-F06 |
| CLI-026 | `doctor` | empty dir (neither) | Reports both toolchains as advice; missing project is advisory and does not fail the exit code. | CHANGELOG Unreleased Added; CHANGELOG 1.8.0 Fixed | pass |
| CLI-027 | `run`, `diff capture` | dir with only `.maestro/*.yaml` | Flows are auto-detected from `.maestro/` with no `grantiva.yml`. | README §Maestro Compatibility | pass |
| CLI-028 | `run`, `diff capture` | dir with empty `.maestro/` | Clear error that no flow files were found; non-zero exit. | README §Maestro Compatibility | pass |
| CLI-029 | `diff capture` | `grantiva.yml` in Maestro format (`appId:` + `---`) | Parsed as Maestro: each `takeScreenshot` is a screen, commands between are its navigation steps. | README §Maestro Compatibility | pass |
| CLI-030 | `run` | both `grantiva.yml` and `grantiva-android.yml`, no flag | Error telling the user to pass `--platform ios\|android` or set `GRANTIVA_PLATFORM`. | docs/android.md §Devices; CHANGELOG Unreleased Added | pass |
| CLI-031 | `run`, `doctor` | both config files plus `--platform android`, then `GRANTIVA_PLATFORM=ios` | Each selects the named platform's config. | help: run (`--platform`); docs/android.md §Devices | pass |
| CLI-032 | `doctor` | `--platform ios` with `GRANTIVA_PLATFORM=android` | The flag wins over the environment variable. | help: run ("GRANTIVA_PLATFORM also sets it") | pass |
| CLI-033 | `doctor` | `GRANTIVA_PLATFORM=windows` | Error naming the bad value and the accepted values ios, android; non-zero exit. | help: run (`values: ios, android`) | fail CLI-F11 |
| CLI-034 | `run` | `--platform android` where only `grantiva.yml` exists | "an error naming the missing file" (`grantiva-android.yml`). | CHANGELOG Unreleased Added | pass |
| CLI-035 | `run` | `--platform macos` | Usage error listing values ios, android; non-zero exit. | help: run | pass |

**Config parsing**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-036 | `run` | `grantiva.yml` with a YAML syntax error | "an error naming the file and the YAML position", not silently ignored. | CHANGELOG Unreleased Added; CHANGELOG Unreleased Changed | pass |
| CLI-037 | `run --platform android` | `grantiva-android.yml` with a YAML syntax error | Error names `grantiva-android.yml` and the line/column. | CHANGELOG Unreleased Added | pass |
| CLI-038 | `run` | empty or comments-only `grantiva.yml` | "loads as defaults, as before" (then fails for missing scheme/flows, not for parsing). | CHANGELOG Unreleased Changed | pass |
| CLI-039 | `run` | `grantiva.yml` with an unknown key (e.g. `schem: Landmarks`) | Undocumented; record whether the key is rejected, warned about, or silently ignored. A silent ignore of a misspelled required key is a `ux` finding. | spec §2 Config parsing (no CLI doc) | fail CLI-F09 |
| CLI-040 | `run` | `grantiva.yml` containing `platform: android` | Error that the file declares the other platform; the `platform:` key belongs in `grantiva-android.yml`. | docs/android.md §Config | pass |
| CLI-041 | `run` | Android project plus `--scheme X` | "iOS flags such as `--scheme` are rejected on Android", by name, before any build. | docs/android.md §Devices; CHANGELOG Unreleased Added | pass |
| CLI-042 | `run` | iOS project plus `--module app` | "A flag from the other platform is rejected by name." | CHANGELOG Unreleased Added | pass |
| CLI-043 | `run` | Android project plus `--logs-predicate x`; iOS project plus `--logs-tag x` | Each rejected by name ("`--logs-predicate` is iOS-only"). | docs/android.md §Logs; help: run | pass |
| CLI-044 | `run` | `grantiva.yml` with `flows: []` and no `screens`, plus `--report-dir out --ready-file out.ready` | Fails before any boot or runner work with an error that nothing is configured; non-zero exit. No `report.json` claiming a pass, and the ready file says `failed` ("a failure before the runner starts … records `failed`"). | README §Agent-Native Features (`--ready-file`); help: run | pass |
| CLI-045 | `run` | `--device emulator-5554 --emulator Pixel_8_API_35` | "`--device` together with `--emulator` is rejected." | CHANGELOG Unreleased Changed | pass |
| CLI-046 | `diff capture` | `screens:` using every path step: `launch`, `tap`, `swipe` up/down/left/right, `type`, `wait`, `assert_visible`, `assert_not_visible`, `run_flow` | All steps parse; generated flow (inspect via `--report-dir` or staged flow) contains one step per entry in order. | README §Screens | pass |
| CLI-047 | `diff capture` | `- swipe: diagonal` | Rejected at parse time; README lists only `up`, `down`, `left`, `right`. | README §Screens | fail CLI-F24 |
| CLI-048 | `diff capture` | `- run_flow: "sub/flow.yaml"` relative path, and a missing path | Resolves relative to the config's directory; a missing file is an error naming the path. | README §Screens | pass |
| CLI-049 | `diff capture` | `run_flow` cycle (A includes B includes A) | Error naming the cycle; does not hang or recurse until crash. | README §Screens; spec §2 (`run_flow` resolution) | pass |
| CLI-050 | `run` | `--env NOEQUALS`, `--env =v`, `--env 'A B=1'` | "A malformed pair is rejected with a clear error" for each, before any device work. | CHANGELOG 1.7.0 Added; help: run (`--env`) | pass |
| CLI-051 | `run` | `--ready-file <existing directory>` | "An unwritable or non-file `--ready-file` path is now rejected at startup." | CHANGELOG 1.8.0 Fixed | pass |
| CLI-052 | `run` | pre-existing `x.ready` containing `{"status":"passed"}`, run in a dir with no project | The stale file is deleted at startup, then rewritten with `failed`. | README §Agent-Native Features; CHANGELOG 1.8.0 | pass |
| CLI-053 | `run` | `--ready-file x.ready` in a dir with no project | File exists after exit with `"status":"failed"`; exit non-zero. | README §Agent-Native Features ("it is always written") | pass |
| CLI-054 | `run` | `--ready-file` in a read-only directory (`chmod 0500`) | "an unwritable path fails immediately rather than at the end of a long suite"; exit non-zero before project work. | README §Agent-Native Features | pass |
| CLI-055 | `run` | `--snapshot bogus` | Usage error naming failure, trailing, full. | help: run (`--snapshot`) | pass |
| CLI-056 | `run` | `--timeout abc`, `--timeout -1` | Rejected as a usage error; non-zero exit. | help: run (`--timeout`) | pass |
| CLI-057 | `run --platform android` | `--application-id "not valid"` | Rejected as an invalid Android application ID before any device work. | help: run (`--application-id`) | pass |
| CLI-058 | `simulator teardown` | `--udid "" --force` | Rejected; must not print `No processes were holding .` and exit 0. | CHANGELOG 1.8.0 Fixed | pass |
| CLI-059 | `simulator teardown` | `--udid not-a-udid-at-all --force`; `--session-id ""` | Both rejected (UDID shape 8-4-4-4-12 hex; blank session id). | CHANGELOG 1.8.0 Fixed | pass |
| CLI-060 | `simulator teardown` | `--session-id X --udid <valid UDID>` | "`--session-id` and `--udid` are mutually exclusive." | README §Reclaiming a simulator; CHANGELOG 1.7.0 | pass |
| CLI-061 | `diff capture` (flow generation only) | Maestro flow with `- tapOn: "Mount \"Denali\" 🏔️"` (double quote and emoji), inspected via the staged flow or `--report-dir` | Parses without error and the generated flow carries the label byte-for-byte (quote escaped correctly, emoji intact); no YAML re-escaping corruption. | README §Maestro Compatibility (`tapOn`) | pass |
| CLI-062 | `simulator teardown` | neither `--session-id` nor `--udid` | Error that one of them is required; non-zero exit. | help: simulator teardown | pass |

**Maestro compatibility**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-063 | `diff capture` (parse) | one fixture per supported command: `tapOn`, `inputText`, `assertVisible`, `assertNotVisible`, `swipe`, `scroll`, `runFlow`, `extendedWaitUntil`, `waitForAnimationToEnd`, `takeScreenshot` | Each parses into a navigation step or capture point. | README §Maestro Compatibility | fail CLI-F27 |
| CLI-064 | `diff capture` (parse) | `tapOn: {text: …}` and `tapOn: {id: …}` | Both map to a tap step on that label or identifier. | README §Maestro Compatibility | fail CLI-F28 |
| CLI-065 | `diff capture` (parse) | one fixture per unsupported command: `back`, `setPermissions`, `evalScript`, `pressKey`, `openLink` | "Unsupported commands (scripting, permissions, etc.) are silently skipped." | README §Maestro Compatibility | fail CLI-DOCS-F04 |
| CLI-066 | `diff capture` (parse) | `- scroll` and `- scroll: {direction: up}` | Mapped to a swipe in the opposite finger direction (scroll down = swipe up). | README §Maestro Compatibility | pass |
| CLI-067 | `diff capture` (parse) | flow with two `takeScreenshot` points | Two named screens; commands before each become its path. | README §Maestro Compatibility | pass |
| CLI-068 | `diff capture` (parse) | `runFlow: sub.yaml` and `runFlow: {file: sub.yaml}` | Both include the sub-flow's steps. | README §Maestro Compatibility | pass |

**init**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-069 | `init` | Xcode-only dir | Writes `grantiva.yml` with the detected scheme; exit 0. | help: init; README §Quick Start | pass |
| CLI-070 | `init` | Gradle-only dir | Writes `grantiva-android.yml` ("or `init` in a Gradle project"). | CHANGELOG Unreleased Added; docs/android.md §Setup | pass |
| CLI-071 | `init` | dir with both Xcode and Gradle, no flag | Refuses and asks for `--platform` ("With both, pass `--platform`"). | docs/android.md §Setup | pass |
| CLI-072 | `init` | empty dir | Clear error that no project was found, or a documented default; record which. Never writes a half-filled config silently. | help: init | fail CLI-F07 |
| CLI-073 | `init` | `--scheme Landmarks --bundle-id com.kylebrowning.Landmarks` | Written config contains exactly those values. | help: init | pass |
| CLI-074 | `init --platform android` | `--application-id com.kylebrowning.landmarks` | Writes `grantiva-android.yml` with `application_id`. | help: init; docs/android.md §Setup | pass |
| CLI-075 | `init` | run twice in the same dir | Second run refuses to overwrite; file unchanged, message on stderr. | spec §2 init; help: init | pass |
| CLI-076 | `init` | `--platform android --scheme X`; `--platform ios --application-id a.b` | Other-platform flag rejected by name. | CHANGELOG Unreleased Added ("A flag from the other platform is rejected by name") | fail CLI-F12 |
| CLI-077 | `init` | `--json` | Usage error: `init` has no `--json`. | help: init | pass |

**doctor**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-078 | `doctor --platform ios` | healthy host | Checks Xcode and simulators; exit 0 when every required check passes. | help: doctor; README §Commands | pass |
| CLI-079 | `doctor --platform android` | toolchain per docs/android-environment.md | "checks the Android SDK, adb, emulator, JDK, and AVDs". | CHANGELOG Unreleased Added | pass |
| CLI-080 | `doctor --platform android` | `ANDROID_HOME` unset | Falls back to `ANDROID_SDK_ROOT`, then `~/Library/Android/sdk`; reports which SDK it found. | docs/android-environment.md | pass |
| CLI-081 | `doctor` | `DEVELOPER_DIR=/nonexistent` | Xcode check fails with a fix line and exit is non-zero, in both text and `--json` modes. | CHANGELOG 1.8.0 Fixed; README §Commands | pass |
| CLI-082 | `doctor --platform android` | `ANDROID_HOME=/nonexistent`, `ANDROID_SDK_ROOT` unset, no default SDK on `PATH` | Required SDK check fails; exit non-zero. | CHANGELOG 1.8.0 Fixed; docs/android-environment.md | blocked default SDK at ~/Library/Android/sdk cannot be hidden without breaking the Android slice; see CLI-F26 |
| CLI-083 | `doctor` | no `grantiva.yml`, not authenticated, no booted simulator | Optional checks "stay advisory and do not affect the exit code". | CHANGELOG 1.8.0 Fixed | pass |

**runner**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-084 | `runner install` | run twice | Idempotent: both exit 0, second reports already installed or re-extracts harmlessly. | README §Quick Start; help: runner install | pass |
| CLI-085 | `runner version` | none | Prints the embedded runner version (1.1.18-grantiva.N line) and exits 0. | help: runner version; CHANGELOG 1.0.0 | pass |
| CLI-086 | `runner stop` | no session running | Clear message, documented exit code, nothing on stdout. | help: runner stop | fail CLI-F02 |
| CLI-087 | `runner dump-hierarchy` | no session running | Fails with a message naming `grantiva runner start` or `grantiva run --keep-alive`; non-zero exit. | docs/dump-hierarchy.md §Alternative | pass |
| CLI-088 | `hierarchy` | no keep-alive session | "fails with a clear message rather than trying to start one"; non-zero exit; stdout empty. | help: hierarchy; docs/dump-hierarchy.md | pass |

**auth, ci, console without credentials**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-089 | `auth status` | not logged in | Reports not authenticated; exit code recorded; nothing suggests a valid session. | help: auth status | pass |
| CLI-090 | `auth logout` | not logged in | Succeeds or reports nothing to remove; does not error noisily. | help: auth logout | fail CLI-F03 |
| CLI-091 | `ci run` | no credentials, iOS project | Clear authentication error, non-zero exit, nothing on stdout. | spec §2; README §CI Integration | pass |
| CLI-092 | `console <group> list` (each read command) | flags list, envs list, analytics overview, devices list, apps list, claims list, vrt runs list, releases list, feedback list, support list, webhooks list, alerts rules list, keys list, team members, audit list, org usage | Each: clear auth error, non-zero exit, stdout empty. | spec §2; README §Dashboard commands | pass |
| CLI-093 | `console flags delete x` | non-TTY stdin, no `--yes` | "destructive verbs prompt on a TTY and require `--yes` otherwise": refuses before any request. | CHANGELOG 1.9.0 | pass |
| CLI-094 | `console claims test` | `--data '='`, `--data '=value'` | Both rejected with a validation error; no trap. | CHANGELOG 2.0.0 Fixed | pass |
| CLI-095 | `console analytics risk` | `--range 2d` | "Windows and event types the server would silently ignore are rejected up front." | CHANGELOG 1.9.0 | pass |
| CLI-096 | `console webhooks create https://x` | `--event not.an.event` | "Event names are validated before the request." | CHANGELOG 1.9.0 | fail CLI-F17 |

**MCP (device-free)**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-097 | `mcp` | `--project-dir /tmp` (no config) | Error naming the directory and the missing config file; exit non-zero; stdout carries no JSON-RPC garbage. | help: mcp (`--project-dir`) | pass |
| CLI-098 | `mcp` | `--project-dir /nonexistent` | Error that the directory does not exist; non-zero exit. | help: mcp | pass |
| CLI-099 | `mcp` | config present, no runner session, no device | Record behavior: currently refuses to start with "No active runner session … Start one with 'grantiva runner start'". Expected per spec: a clear error, no hang, non-zero exit. | help: mcp; docs/dump-hierarchy.md §Alternative; spec §2 | fail CLI-F18 |
| CLI-100 | `mcp` | both config files, no `--platform`; then `--platform ios` | Without the flag: error asking for `--platform`; with it, proceeds to session lookup. | docs/android.md §Runner sessions and the MCP server | pass |

**record and device-command validation (no device needed)**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-101 | `record --platform android` | `--duration 200` | "Android caps a recording at 180 seconds; longer durations are refused", before any recording starts. | docs/android.md §Recording; help: record | pass |
| CLI-102 | `record` | `--duration 2 --frames-at a,b` | Usage error for non-numeric frame timestamps. | help: record (`--frames-at`) | fail CLI-F14 |
| CLI-103 | `record` | no `--duration` | Usage error: missing required `--duration`. | help: record | pass |
| CLI-104 | `emulator teardown` | neither `--serial` nor `--all` | Error that one is required; non-zero exit. | help: emulator teardown | pass |
| CLI-105 | `simulator ensure` | no `--name` | Usage error: missing `--name`. | help: simulator ensure | pass |
| CLI-106 | `diff approve` | no captures present | Clear error that there is nothing to approve; non-zero exit. | help: diff approve | pass |
| CLI-107 | `build build --platform android` | `--derived-data-path x` | Rejected as an iOS option. | help: build build; docs/android.md §Devices | pass |
| CLI-108 | `ci run --platform android` | any Android project | Refuses with "Android baselines are local only until the Grantiva backend supports platforms; use local baselines". | docs/android.md §Captures and baselines; CHANGELOG Unreleased Changed | pass |

**Cross-source consistency (Step 3; each row checked by reading sources)**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| CLI-109 | consistency: `run` positional args | README `grantiva run --device "$udid" flows/` | Sources agree. | README §stdout is the result; help: run | fail CLI-DOCS-F01 |
| CLI-110 | consistency: runner `--json` | README "runner lifecycle commands do not have a JSON result" vs help | Sources agree. | README §Dashboard commands; help: runner start/stop/install/version | fail CLI-DOCS-F02 |
| CLI-111 | consistency: README Commands list | README §Commands vs `grantiva --help` | Sources agree. | README §Commands; help: grantiva | fail CLI-DOCS-F03 |
| CLI-112 | consistency: Maestro unsupported commands | README "silently skipped" vs parser behavior | Sources agree. | README §Maestro Compatibility; Sources/GrantivaCore/Config/MaestroFlowParser.swift | fail CLI-DOCS-F04 |
| CLI-113 | consistency: `simulator cleanup` description | README vs help vs SIMULATOR-LIFECYCLE.md | Sources agree. | README §Commands; help: simulator cleanup; SIMULATOR-LIFECYCLE.md | fail CLI-DOCS-F05 |
| CLI-114 | consistency: `simulator delete`/`sessions` abstracts | help: simulator vs README §Commands | Sources agree. | help: simulator; README §Commands | fail CLI-DOCS-F06 |
| CLI-115 | consistency: `console webhooks events` | CHANGELOG 1.9.0 vs help: console webhooks | Sources agree. | CHANGELOG 1.9.0; help: console webhooks | fail CLI-DOCS-F07 |
| CLI-116 | consistency: version vs CHANGELOG | `grantiva --version` 2.0.1 vs CHANGELOG `## Unreleased` | Sources agree. | CHANGELOG; help: grantiva | fail CLI-DOCS-F08 |
| CLI-117 | consistency: Android `ci run` | docs/android-environment.md §CI vs docs/android.md §Captures and baselines | Sources agree. | docs/android-environment.md; docs/android.md | fail CLI-DOCS-F09 |
| CLI-118 | consistency: emulator selection | docs/android.md §Devices (two sentences) | Sources agree. | docs/android.md §Devices | fail CLI-DOCS-F10 |
| CLI-119 | consistency: iOS-only wording | help: grantiva, run, build build overviews vs Android support | Sources agree. | help: grantiva, run, build build; README line 3; docs/android.md | fail CLI-DOCS-F11 |
| CLI-120 | consistency: `hierarchy --json` vs `--format` | help: hierarchy vs docs/dump-hierarchy.md §Flags | Sources agree. | help: hierarchy; docs/dump-hierarchy.md; README §Dashboard commands | fail CLI-DOCS-F12 |
| CLI-121 | consistency: `--ready-file` missing directory | README "unwritable path fails immediately" vs help and code that create the directory | Sources agree. | README §Agent-Native Features; help: run; Sources/GrantivaCore/Runner/ReadyFile.swift | fail CLI-DOCS-F13 |
| CLI-122 | consistency: MCP tool count | spec §2 "all 19 tools" vs CHANGELOG / docs/android.md tool lists | Sources agree. | CHANGELOG 1.6.0, 1.7.0, Unreleased; docs/android.md; help/mcp-tools-probe.txt | fail CLI-DOCS-F14 |

## iOS slice

**simulator ensure, capacity, teardown**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-001 | `simulator ensure` | `--name "QA iPhone 17 Pro"` (new) | Creates, boots, and prints only the UDID on stdout; the human line goes to stderr. | README §stdout is the result; CHANGELOG 1.7.2 |  |
| IOS-002 | `simulator ensure` | same `--name` again | Reuses the same UDID; stderr reads `Reused iPhone 17 Pro (…) — Booted`. | README §stdout is the result; CHANGELOG 1.6.0 |  |
| IOS-003 | `simulator ensure` | `--name "QA Pin" --device-type "iPhone 17 Pro" --runtime latest` | Created with that device type on the newest runtime. | help: simulator ensure; README |  |
| IOS-004 | `simulator ensure` | `--runtime <installed version, e.g. 26.4>` | Uses that runtime; an uninstalled runtime is a clear error. | help: simulator ensure (`--runtime`) |  |
| IOS-005 | `simulator ensure` | `--no-boot` | Created and left Shutdown; stdout is the UDID. | help: simulator ensure; README |  |
| IOS-006 | `simulator ensure` | `--json` | Full record on stdout including UDID and point/pixel display geometry; valid JSON. | README §stdout is the result; CHANGELOG 1.6.0 |  |
| IOS-007 | `simulator ensure` | `--name "QA Thing"` (no model in the name, no `--device-type`) | Rejected as incompatible or ambiguous; nothing created. | CHANGELOG 1.6.0 ("rejects incompatible or ambiguous names") |  |
| IOS-008 | `simulator ensure` | two concurrent calls, same brand-new name | Exactly one device results (`Created` + `Reused`). | SIMULATOR-LIFECYCLE.md; CHANGELOG 1.6.5 |  |
| IOS-009 | `simulator ensure` | after creating | Device recorded in `~/.grantiva/simulator-capacity/created.json`. | SIMULATOR-LIFECYCLE.md |  |
| IOS-010 | `simulator sessions` | with and without `--json` | Lists Grantiva-managed capacity slots and owners; JSON valid. | README §Commands; help: simulator sessions |  |
| IOS-011 | `simulator ensure` x5 | four Grantiva-booted sims live, fifth ensure | Fifth waits and logs `Warning: Waiting for simulator capacity (4/4): …` naming the occupants. | README; CHANGELOG 1.8.0 Changed |  |
| IOS-012 | `simulator ensure` | `GRANTIVA_MAX_SIMULATORS=1` with one slot used | Second boot waits for capacity. | README; CHANGELOG 1.6.4 |  |
| IOS-013 | `simulator ensure` | `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS=5` at capacity | Gives up after about 5 s with a clear error; non-zero exit. | README; CHANGELOG 1.6.4 |  |
| IOS-014 | `simulator ensure`, `build install` | `GRANTIVA_SESSION_ID=qa-ios` across separate commands | Commands share one durable owner; `sessions` shows one owner for the ticket. | README; CHANGELOG 1.6.4 |  |
| IOS-015 | `simulator teardown` | `--session-id qa-ios` (with `--json`) | Deletes Grantiva-created sims, only shuts down pre-existing ones it booted; JSON has `deleted` per session. | SIMULATOR-LIFECYCLE.md; CHANGELOG 1.6.5 |  |
| IOS-016 | `simulator teardown` | `--udid <UDID> --force --json` after `kill -9` of a keep-alive run | Kills runner, WDA `xcodebuild`, `simctl diagnose` for that UDID, breaks the lease; JSON `reclaimed: true`; exit 0. | README §Reclaiming a simulator; CHANGELOG 1.8.0 |  |
| IOS-017 | `simulator teardown` | `--udid <free UDID> --force --json` | Exit 0, `reclaimed: false`. | CHANGELOG 1.8.0 Changed |  |
| IOS-018 | `simulator cleanup` | one shut-down Grantiva-created sim, one in an active session, one user-created | Deletes only the first; prunes ledger entries for missing devices. | help: simulator cleanup; SIMULATOR-LIFECYCLE.md |  |
| IOS-019 | `simulator delete` | `--name "QA Pin"`; then a name that does not exist | First deletes; second is a clear error, non-zero exit. | README §Commands; help: simulator delete |  |
| IOS-020 | `simulator teardown`, `cleanup` | a simulator booted manually with `xcrun simctl boot` | "manually booted Xcode simulators are never shut down by Grantiva teardown." | README |  |

**build**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-021 | `build build` | `--scheme Landmarks --simulator <UDID>` | Builds with xcodebuild, exit 0. | help: build build; README §Commands |  |
| IOS-022 | `build install` | `--scheme Landmarks --simulator <UDID>` | Builds, installs, and launches (launch is the default). | CHANGELOG 1.5.4 Changed |  |
| IOS-023 | `build install` | `--no-launch --json` | JSON has `status`, `scheme`, `bundleId`, `appPath`, `dataContainerPath`, simulator `name` and `udid`; app not running. | README §Prepare fixtures before first launch |  |
| IOS-024 | `build install` | `--derived-data-path "/private/tmp/qa ios/Derived Data"`, and a relative path | Products land in that directory; spaces and relative paths work. | README §Prepare fixtures; CHANGELOG 1.5.5 |  |
| IOS-025 | `build build` | `build_settings: ["-derivedDataPath", "x"]` in config plus `--derived-data-path y` | The flag wins; other `build_settings` preserved. | README; CHANGELOG 1.5.5 Fixed |  |
| IOS-026 | `build build` | `--scheme NoSuchScheme` | Clear xcodebuild/scheme error; non-zero exit. | spec §2; help: build build |  |
| IOS-027 | `build build` | no scheme in config, no `--scheme` | "No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file …" | README §Pre-built binaries |  |
| IOS-028 | `build install` | `--simulator "QA iPhone 17 Pro"` (name) vs UDID | Both select the same simulator; xcodebuild destination uses `id=<UDID>`. | help: build install; CHANGELOG 0.8.10 |  |

**run: suite, flows, ready file, env**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-029 | `run` | configured flows from `grantiva.yml` | Runs all flows; per-step pass/fail; exit 0 only when all pass; screenshot on failure. | help: run |  |
| IOS-030 | `run` | `--flow .maestro/<each shared flow>.yaml` | Runs only that file, skipping configured screens. | help: run; README §Agent-Native Features |  |
| IOS-031 | `run` | landmarks-demo `grantiva.yml` with `flows: []` and no screens, `--report-dir out --ready-file out.ready`, simulator available | Fails before boot/build with an error that nothing is configured; non-zero exit; no `report.json` reporting success; ready file `failed`. | README §Agent-Native Features; help: run |  |
| IOS-032 | `run` | `--ready-file x.ready` with a stale `x.ready` present | Stale file deleted at startup; rewritten once, atomically, with `passed`, `failed`, or `interrupted` matching the run. | README §Agent-Native Features; CHANGELOG 1.8.0 |  |
| IOS-033 | `run` | `--ready-file /nonexistent-qa/sub/x.ready` (parent cannot be created) | Fails before any build or boot ("an unwritable path fails immediately rather than at the end of a long suite"); non-zero exit. | README §Agent-Native Features; CHANGELOG 1.8.0 |  |
| IOS-034 | `run` | `--ready-file /tmp/qa-missing-dir/x.ready` (parent creatable) | Undocumented: record whether the directory is created (code does) and the verdict written there at the end. | help: run; see CLI-DOCS-F13 |  |
| IOS-035 | `run` | `--env 'LANDMARKS_NOTE=a=b c'` | Value split on the first `=`; Deep Links screen shows `a=b c` verbatim (assert via `hierarchy`). | help: run (`--env`); README §Agent-Native Features |  |
| IOS-036 | `run` | `--env LANDMARKS_NOTE=hello` | `hello` visible under the Deep Links title. | README §Agent-Native Features ("Forwarded through the flow's `launchApp` environment") |  |
| IOS-037 | `run` | `--env LANDMARKS_SEED=many --env LANDMARKS_NOTE=x` (repeated) | Both reach the app: `Landmark 70` reachable and note shown. | help: run ("Repeatable") |  |
| IOS-038 | `run` | `--env LANDMARKS_SEED=empty` | List shows `No landmarks yet`. | help: run (`--env`) |  |
| IOS-039 | `run` | `--env LANDMARKS_CRASH_ON_LAUNCH=1` | Flow fails, run exits non-zero, failure screenshot captured, ready file `failed`. | help: run (`--snapshot` failure default) |  |
| IOS-040 | `run` | `--app-file Landmarks.app` (simulator build) | Skips build, installs; bundle ID from `Info.plist`; no `scheme` needed. | README §Pre-built binaries |  |
| IOS-041 | `run` | flow 12 tapping `Mount "Denali"` (seed default) | Tap on the quoted label succeeds through WDA (selector escaping correct) and the detail screen opens. | README §Maestro Compatibility (`tapOn`) |  |
| IOS-042 | `run` | `--app-file Landmarks.ipa` | Extracts, validates, installs, runs. | README §Pre-built binaries |  |
| IOS-043 | `run` | `--app-file` of a device (iphoneos) build | Rejected: "The binary is validated to be a simulator build before install." | README §Pre-built binaries |  |
| IOS-044 | `run` | `--no-build` with app installed; then after uninstall | First runs flows; second fails with a clear launch/install error. | help: run (`--no-build`); README |  |
| IOS-045 | `run` | `tapOn: "Mountains → Yosemite Valley"` (non-ASCII arrow) | Tap succeeds; label passed through unmangled. | README §Maestro Compatibility |  |
| IOS-046 | `run` | `--wait-for-idle-timeout 5` | Not in help: run; expect a usage error (record the result, since spec §2 lists it). | help: run; spec §2 |  |

**run: keep-alive, hierarchy**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-047 | `run` | `--keep-alive --flow <flow>` | Session held after flows; app frozen in place; process does not exit until Ctrl-C. | README §Agent-Native Features |  |
| IOS-048 | `hierarchy` | during keep-alive, default | XML on stdout (debugDescription unwrapped from `{"value": …}`); app not relaunched. | docs/dump-hierarchy.md §Output formats |  |
| IOS-049 | `hierarchy` | `--format json` | Structured JSON from `/source?format=json`; valid JSON. | docs/dump-hierarchy.md; help: hierarchy |  |
| IOS-050 | `hierarchy` | `--json` (without `--format`) | help says "Output as JSON"; record whether JSON or XML is printed. | help: hierarchy; see CLI-DOCS-F12 |  |
| IOS-051 | `hierarchy` | `--udid <UDID>` with one live session | Resolves through `<pid>.owner.json`; prints that sim's tree. | docs/dump-hierarchy.md §Flags; CHANGELOG 2.0.1 |  |
| IOS-052 | `hierarchy` | two live keep-alive sessions on two UDIDs, no `--udid` | Picks the newest live session ("Finds the newest live `--keep-alive` session"). | README §Agent-Native Features; help: hierarchy |  |
| IOS-053 | `hierarchy` | two live sessions, `--udid` of the older | Prints the older session's tree. | help: hierarchy; docs/dump-hierarchy.md |  |
| IOS-054 | `hierarchy` | after the keep-alive run was `kill -9`'d | Dead session ignored ("a file whose `pid` is no longer running is ignored"); fails fast if none live. | docs/dump-hierarchy.md |  |
| IOS-055 | `hierarchy` | `--timeout 1` against a busy agent | Gives up after about 1 s with a clear error. | help: hierarchy (`--timeout`) |  |
| IOS-056 | `run` | `--keep-alive --ready-file r` then `hierarchy` immediately after `r` appears | Never races: ready file written only after the session file exists (hold capped at 10 s). | docs/dump-hierarchy.md; CHANGELOG 2.0.1 |  |
| IOS-057 | `run` | `--keep-alive`, then Ctrl-C | Runner, WDA, `simctl diagnose` reaped; session file and `<pid>.owner.json` removed; lease released; status-bar override cleared. | README §Agent-Native Features; CHANGELOG 1.7.0, Unreleased Fixed |  |
| IOS-058 | `run` | `--keep-alive` backgrounded with `&`, then `kill -INT <pid>` | Same cleanup as Ctrl-C despite the inherited `SIG_IGN`; ready file `interrupted`. | SIMULATOR-LIFECYCLE.md §Runner ownership; CHANGELOG 1.7.0 |  |
| IOS-059 | `run` | two concurrent runs on different UDIDs | Both execute in parallel and do not share a generated flow file. | README §Agent-Native Features; CHANGELOG 2.0.0 |  |
| IOS-060 | `run` | second run on a UDID owned by a live run | Fails immediately with "already owned by another Grantiva run", naming the owner pid and the freeing command. | README; CHANGELOG 1.7.0 |  |

**run: logs, snapshot, report, timeout**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-061 | `run` | `--logs` | `[log]` lines interleaved with flow output, scoped to the bundle ID. | README §Agent-Native Features; help: run |  |
| IOS-062 | `run` | `--logs-predicate 'subsystem == "com.kylebrowning.Landmarks"'` | Implies `--logs`; only matching lines. | help: run; CHANGELOG 1.2.0 |  |
| IOS-063 | `run` | `--logs --logs-level debug`, then `info` | Passed through to `simctl`; debug shows more lines than default. | help: run; CHANGELOG 1.2.0 |  |
| IOS-064 | `run` | `--logs` then failure, success, and Ctrl-C | Log stream stops on every exit path; no orphan `log stream` process. | CHANGELOG 1.2.0 |  |
| IOS-065 | `run` | `--snapshot failure` (default) | One screenshot after the failing step. | help: run (`--snapshot`) |  |
| IOS-066 | `run` | `--snapshot trailing` | Last-good step plus failure step captured. | help: run |  |
| IOS-067 | `run` | `--snapshot full` | A screenshot for every step. | help: run |  |
| IOS-068 | `run` | `--continue-on-failure` with the crash flow first | Remaining flows still run; exit non-zero. | help: run |  |
| IOS-069 | `run` | crash flow first, no `--continue-on-failure` | Fail-fast: suite stops after the first broken flow. | help: run |  |
| IOS-070 | `run` | `--report-dir out` (relative) | `out/report.json`, assets, failure screenshots, traces present; `./.grantiva/captures` not created. | README §Agent-Native Features; CHANGELOG 1.7.0 |  |
| IOS-071 | `run` | `--report-dir out` with a failing flow | Failure reported against the user's flow path, not the staged temp copy. | CHANGELOG 1.7.0 Changed |  |
| IOS-072 | `run` | two flows with the same basename in different dirs | Staged separately; each runs once. | CHANGELOG 2.0.0 Fixed |  |
| IOS-073 | `run` | `--timeout 5` with the Slow Screen flow | Runner killed with SIGTERM after 5 s; run fails. | help: run (`--timeout`) |  |
| IOS-074 | `run` | `--json` | stdout is valid JSON result only; narration on stderr. | README §stdout is the result |  |
| IOS-075 | `run` | flow starting with `- stopApp` before any launch | Does not fail (stopApp idempotent). | CHANGELOG 0.9.0 Fixed |  |
| IOS-076 | `run` | flow using `clearState` | Works without `--app-file` (built `.app` forwarded automatically). | CHANGELOG 0.8.11 |  |
| IOS-077 | `run` | `launchApp` with `arguments: { "--flag": true }` | App receives `--flag`, not `---flag`. | CHANGELOG 1.7.0 Fixed in the bundled runner |  |
| IOS-078 | `run` | `assertVisible: {text: "Lake", exact: true}` against `Lake Tahoe` | Fails (exact full-string match); without `exact` passes. | CHANGELOG 1.7.0 |  |

**record**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-079 | `record` | `--simulator <UDID> --duration 3` | Writes `.grantiva/recordings/recording.mov`; exit 0. | help: record |  |
| IOS-080 | `record` | `--duration 3 --output /tmp/qa rec/a.mov` | Writes to the given path (spaces ok). | help: record (`--output`) |  |
| IOS-081 | `record` | `--duration 3 --frames-at 0,150,300,2900` | PNG frames at those timestamps. | help: record; README §Commands |  |
| IOS-082 | `record` | `--duration 2 --frames-at 5000` | Clear error for a timestamp past the duration. | help: record |  |
| IOS-083 | `record` | `--json` | Valid JSON listing video and frame paths. | help: record |  |

**runner start / stop**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-084 | `runner start` | `--bundle-id com.kylebrowning.Landmarks --simulator <UDID> --detach` | Prints the log path; session held; `.grantiva/session.json` written; lease kept. | help: runner start; CHANGELOG 2.0.0, Unreleased Fixed |  |
| IOS-085 | `runner dump-hierarchy` | `--format tree`, `json`, `xml` | Prints the tree in each format. | help: runner dump-hierarchy; docs/dump-hierarchy.md |  |
| IOS-086 | `runner dump-hierarchy` | no runner start session, live keep-alive run, `--udid` | Falls back to the keep-alive session. | docs/dump-hierarchy.md; CHANGELOG 2.0.1 |  |
| IOS-087 | `runner stop` | after `runner start` | Kills the runner, removes the owner sidecar, releases the lease. | help: runner stop; CHANGELOG Unreleased Fixed |  |
| IOS-088 | `runner start` | stale `.grantiva/session.json` whose pid is dead | Treated as no session; a new one starts cleanly. | spec §2 (stale session handling); docs/dump-hierarchy.md |  |
| IOS-089 | `runner start` | then `run` on the same simulator | `run` fails fast as owned; the interactive session is not torn down. | CHANGELOG 2.0.0 Fixed |  |

**diff (local)**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-090 | `diff capture` | landmarks screens, first capture | Screenshots in `.grantiva/captures/`; reports simulator and point/pixel size. | README §Local Workflow; CHANGELOG 1.6.2 |  |
| IOS-091 | `diff compare` | no baselines yet | Each screen reported as new/missing baseline, not as a pass. | README §Local Workflow |  |
| IOS-092 | `diff approve` | after first capture | Baselines written under `.grantiva/baselines/`. | README §Local Workflow |  |
| IOS-093 | `diff compare` | unchanged UI | All screens pass. | README §Local Workflow |  |
| IOS-094 | `diff compare` | clock pixel change (Caching Demo) vs `threshold: 0.02` | Fails or passes according to the pixel threshold. | README §Configuration (`diff.threshold`) |  |
| IOS-095 | `diff compare` | `perceptual_threshold: 5.0` vs a subtle colour change | CIE76 distance below 5 passes, above fails. | README §How It Works; §Configuration |  |
| IOS-096 | `diff compare` | `--json` | Valid JSON with per-screen pixel and perceptual metrics. | help: diff compare |  |
| IOS-097 | `diff compare` | `--capture` | Captures first ("runs full lifecycle"), then compares. | help: diff compare |  |
| IOS-098 | `diff approve` | `Home` (one screen name) | Only that screen's baseline replaced. | help: diff approve |  |

**MCP against a live keep-alive session**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| IOS-099 | `mcp` tools/list | after `runner start` | 22 tools, schemas as in `help/mcp-tools-probe.txt`; required args: `grantiva_sim_ensure` name, `grantiva_swipe` direction, `grantiva_type` text, `grantiva_script` steps. | CHANGELOG 1.6.0, 1.7.0; docs/android.md §Runner sessions |  |
| IOS-100 | `mcp` stdout | any call | stdout carries only JSON-RPC; no narration on stdout; subprocesses do not consume stdin. | CHANGELOG Unreleased Fixed (stdin `/dev/null`) |  |
| IOS-101 | `grantiva_context` | none | Shows config with a `platform:` line under `[Config]`, booted sim, Xcode, session status. | CHANGELOG Unreleased Changed |  |
| IOS-102 | `grantiva_tap` | `label: "Lake Tahoe"`; then `x`/`y` in points | Taps and returns the updated tree. | CHANGELOG Unreleased Added (points on iOS) |  |
| IOS-103 | `grantiva_tap` | no `label`, no `x`/`y` | Clear tool error, server stays up. | spec §2 (argument validation) |  |
| IOS-104 | `grantiva_type` | `text: "Yosemite"` in the Name field | Types into the focused field; returns updated tree. | help: mcp; tool schema |  |
| IOS-105 | `grantiva_swipe` | `direction: up`; then `direction: sideways` | First swipes; second is a validation error. | tool schema |  |
| IOS-106 | `grantiva_screenshot` | default; `format: file` | Base64 PNG by default; `file` writes a PNG and returns its path. Record the path: the code comment says `.grantiva/mcp-screenshot.png`, the code uses a temp `grantiva-mcp-<uuid>.png`. | tool schema (UITools.swift) |  |
| IOS-107 | `grantiva_script` | `steps: [{tap: "Favorites"}, {wait: 1}, {tap_xy: {x:…, y:…}}]` | Executes in order; `tap_xy` in points. | CHANGELOG Unreleased Added |  |
| IOS-108 | `hierarchy` resource, `screenshot` resource | `resources/read grantiva://hierarchy`, `grantiva://screenshot` | JSON tree and base64 PNG. | tool registry (ToolRegistry.swift) |  |
| IOS-109 | `grantiva_a11y_tree`, `grantiva_a11y_check` | on Landmarks list | Tree returned; check flags missing labels and targets under 44 pt. | tool schema |  |
| IOS-110 | `grantiva_sim_list`, `grantiva_sim_boot`, `grantiva_sim_ensure`, `grantiva_sim_delete` | `ensure {name: "QA MCP iPhone 17"}` then delete | Only `name` required for ensure; delete removes it. | CHANGELOG 1.6.0, 1.7.0 |  |
| IOS-111 | `grantiva_build`, `grantiva_run` | `scheme: Landmarks` | Build prints `Product:` with the app path; run installs and launches. | CHANGELOG Unreleased Changed |  |
| IOS-112 | `grantiva_test` | `scheme: Landmarks` | Runs xcodebuild test; returns pass/fail counts. | docs/android.md (iOS-only tool); tool schema |  |
| IOS-113 | `grantiva_vrt_capture`, `grantiva_vrt_compare`, `grantiva_vrt_approve` | approve `screens: ["Home"]` | Equivalent to `diff capture --no-build --json`, `diff compare --json`, `diff approve Home --json`. | tool schema (VRTTools.swift) |  |
| IOS-114 | `grantiva_vrt_approve` | `screens: ["Home; touch /tmp/pwn"]` | Screen name shell-quoted; no file created. | CHANGELOG 2.0.0 Fixed |  |
| IOS-115 | each tool with a required argument | `grantiva_sim_ensure {}`, `grantiva_type {}`, `grantiva_swipe {}`, `grantiva_script {}`, `grantiva_emulator_ensure {}`, unknown tool name | Each returns an MCP error result naming the missing argument (or unknown tool); the server keeps running and answers the next request. | tool schemas (`required`); spec §2 (error contract) |  |
| IOS-116 | `mcp` | both config files, `--platform ios` | Starts and drives the simulator. | docs/android.md §Runner sessions |  |

## Android slice

**emulator subcommand**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-001 | `emulator ensure` | `--name QA_Pixel_API_35` (AVD missing, image installed) | Creates the AVD (`avdmanager create avd -d pixel_8`), boots it, prints only the serial on stdout. | help: emulator ensure; docs/android.md §Emulator subcommand |  |
| AND-002 | `emulator ensure` | `--name QA_Pixel_New --system-image "system-images;android-35;google_apis;arm64-v8a"` with image absent | Installs the image with `sdkmanager` first, then creates and boots. | docs/android.md §Emulator subcommand; CHANGELOG Unreleased Added |  |
| AND-003 | `emulator ensure` | same name again | Reuses the AVD; boots or reuses the running emulator; same serial. | help: emulator ensure |  |
| AND-004 | `emulator ensure` | `--no-boot` | Creates without booting; stdout is the AVD name. | help: emulator ensure ("the AVD name with --no-boot") |  |
| AND-005 | `emulator ensure` | `--headless` | Boots with no window (`-no-window`). | help: emulator ensure; CHANGELOG Unreleased Added |  |
| AND-006 | `emulator ensure` | no `--name`, config has `emulator: Pixel_8_API_35` | Uses the configured AVD. | help: emulator ensure (`--name` default) |  |
| AND-007 | `emulator ensure` | no `--system-image`, no config value | Falls back to `system-images;android-35;google_apis;arm64-v8a`. | docs/android.md §Emulator subcommand |  |
| AND-008 | `emulator ensure` | `--json` | Valid JSON record on stdout. | help: emulator ensure |  |
| AND-009 | `emulator sessions` | with `--json` | Lists emulators Grantiva started (from `~/.grantiva/android/started.json`). | help: emulator sessions; CHANGELOG Unreleased Added |  |
| AND-010 | `emulator teardown` | `--serial <serial Grantiva started>` | Stops UIAutomator2, removes that serial's adb forwards, kills the emulator. | help: emulator teardown |  |
| AND-011 | `emulator teardown` | `--serial <serial Grantiva did not start>`; then with `--force` | Refuses without `--force`; kills with it. | docs/android.md §Emulator subcommand |  |
| AND-012 | `emulator teardown` | `--all` | Kills every emulator Grantiva started; leaves others running. | help: emulator teardown |  |
| AND-013 | `emulator teardown` | recorded emulator whose pid is gone | Checks the AVD name before killing anything; does not kill an unrelated emulator reusing the serial. | docs/android.md §Emulator subcommand |  |
| AND-014 | `emulator delete` | `--name QA_Pixel_New` (created by Grantiva, stopped) | Deletes the AVD. | help: emulator delete |  |
| AND-015 | `emulator delete` | `--name Pixel_8_API_35` (not created by Grantiva) | Refuses without `--force`. | help: emulator delete; docs/android.md |  |
| AND-016 | `emulator delete` | `--name <running AVD> --force` | Refuses: "A running AVD is never deleted." | help: emulator delete |  |
| AND-017 | `emulator ensure` | `GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS=5` on a cold boot | Boot wait gives up after about 5 s with a clear error. | docs/android.md §CI |  |
| AND-018 | `emulator ensure`, `run` | manual emulator started outside Grantiva | Never killed by `teardown --all` or run cleanup. | help: emulator teardown ("emulators Grantiva started") |  |

**build and target selection**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-019 | `build build` | default (`module: app`, `variant: debug`) | Runs `assembleDebug`; exit 0. | docs/android.md §Config; help: build build |  |
| AND-020 | `build install` | default | Builds, installs, launches by default. | help: build install |  |
| AND-021 | `build install` | `--no-launch --json` | JSON with application ID and APK path; app not running. | help: build install |  |
| AND-022 | `build build` | `--variant release` | Runs `assembleRelease`; unsigned-release behavior reported clearly. | help: build build (`--variant`) |  |
| AND-023 | `build build` | `--variant freeDebug` (flavor) | Runs `assembleFreeDebug` ("freeDebug -> assembleFreeDebug"). | docs/android.md §Config |  |
| AND-024 | `build build` | `--variant noSuchVariant` | Clear Gradle task error; non-zero exit. | help: build build |  |
| AND-025 | `build build` | `--module app`; `--module nosuch` | First builds; second clear error. | help: build build (`--module`) |  |
| AND-026 | `run` | no `application_id`, no flag | Application ID read from the build's `output-metadata.json`. | docs/android.md §Config; help: run |  |
| AND-027 | `run` | `--application-id com.kylebrowning.landmarks.debug` override | Flag wins over config and build output. | help: run |  |
| AND-028 | `run` | `--app-file app-debug.apk` | Skips the build; application ID read with `apkanalyzer`. | CHANGELOG Unreleased Changed |  |
| AND-029 | `run` | `--emulator Pixel_8_API_35` (not running) | Boots that AVD (`-no-snapshot-save -no-boot-anim`) then runs. | help: run; CHANGELOG Unreleased Added |  |
| AND-030 | `run` | `--device emulator-5554` | Targets that attached serial. | help: run; docs/android.md §Devices |  |
| AND-031 | `run` | `grantiva-android.yml` with `flows: []` and no screens, `--report-dir out --ready-file out.ready` | Fails before boot/build with an error that nothing is configured; non-zero exit; no success `report.json`; ready file `failed`. | README §Agent-Native Features; help: run |  |
| AND-032 | `run` | `--headless --emulator <AVD>` | Boots without a window. | help: run |  |
| AND-033 | `run` | `--ready-file /nonexistent-qa/sub/x.ready` (parent cannot be created) | Fails before any Gradle build or emulator boot; non-zero exit. | README §Agent-Native Features; CHANGELOG 1.8.0 |  |
| AND-034 | `run` | `--ready-file x.ready` with a stale file present | Deleted at startup; rewritten with `passed`, `failed`, or `interrupted`. | README §Agent-Native Features; help: run |  |
| AND-035 | `run` | `--env 'LANDMARKS_NOTE=a=b c'` | Delivered as an intent extra; Deep Links screen shows `a=b c` verbatim (assert via `hierarchy`). | help: run (`--env`); README §Agent-Native Features |  |
| AND-036 | `run` | no `emulator:`, exactly one emulator running | Uses the running emulator. | docs/android.md §Devices |  |
| AND-037 | `run` | `--env LANDMARKS_NOTE=hello` | `hello` visible under the Deep Links title. | help: run (`--env`) |  |
| AND-038 | `run` | `--env LANDMARKS_SEED=many --env LANDMARKS_NOTE=x` | Both values reach the app. | help: run ("Repeatable") |  |
| AND-039 | `run` | `--env LANDMARKS_SEED=empty` | `No landmarks yet` shown. | help: run |  |
| AND-040 | `run` | `--env LANDMARKS_CRASH_ON_LAUNCH=1` | Flow fails, non-zero exit, failure screenshot, ready file `failed`. | help: run |  |
| AND-041 | `run` | flow 12 tapping `Mount "Denali"` (seed default) | Tap on the quoted label succeeds through UIAutomator2 (selector escaping correct); detail screen opens. | README §Maestro Compatibility (`tapOn`) |  |
| AND-042 | `run` | configured flows | All flows run; per-step pass/fail; exit 0 only when all pass. | help: run; docs/android.md |  |
| AND-043 | `run` | `--flow .maestro/<each shared flow>.yaml` | Only that flow runs. | help: run |  |
| AND-044 | `run` | `tapOn: "Mountains → Yosemite Valley"` | Tap succeeds; label unmangled. | README §Maestro Compatibility |  |
| AND-045 | `run` | `--no-build` with APK installed | Runs flows without Gradle. | help: run (`--no-build`) |  |
| AND-046 | `run` | `--continue-on-failure` with crash flow first | Remaining flows run; non-zero exit. | help: run |  |
| AND-047 | `run` | `--snapshot failure`, `trailing`, `full` | One shot after failure; last-good plus failure; every step. | help: run (`--snapshot`) |  |
| AND-048 | `run` | `--report-dir out` | `report.json`, assets, failure screenshots under `out/`; `.grantiva/captures` untouched. | README §Agent-Native Features |  |
| AND-049 | `run` | `--timeout 5` with Slow Screen flow | Runner killed after 5 s; run fails. | help: run (`--timeout`) |  |
| AND-050 | `run` | `--json` | stdout valid JSON only. | README §stdout is the result |  |

**keep-alive and hierarchy**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-051 | `run` | `--keep-alive --flow <flow>` | Holds the UIAutomator2 session after flows; app stays in place until Ctrl-C. | docs/android.md §Hierarchy and keep-alive |  |
| AND-052 | `hierarchy` | two live keep-alive sessions on two serials, no `--udid` | Picks the newest live session. | README §Agent-Native Features; help: hierarchy |  |
| AND-053 | `hierarchy` | during keep-alive, default | UIAutomator2 page source as XML on stdout; app untouched. | docs/android.md §Hierarchy and keep-alive; help: hierarchy |  |
| AND-054 | `hierarchy` | `--format json` | Same tree as JSON, frames in dp. | docs/android.md; CHANGELOG Unreleased Added |  |
| AND-055 | `hierarchy` | `--json` | help says "Output as JSON"; record which format is printed. | help: hierarchy; see CLI-DOCS-F12 |  |
| AND-056 | `hierarchy` | `--udid <serial>` with two sessions | Picks that serial's session. | docs/android.md ("`--udid <serial>` picks a session when several are live") |  |
| AND-057 | `hierarchy` | before/after, `adb forward --list` | A local port forwarded to device 6790 for the command only; forward removed afterwards. | docs/android.md §Hierarchy and keep-alive |  |
| AND-058 | `hierarchy` | after the keep-alive run was `kill -9`'d | Dead session ignored; fails fast with a clear message. | help: hierarchy; docs/dump-hierarchy.md |  |
| AND-059 | `run` | `--keep-alive`, then Ctrl-C | Session, owner sidecar, UIAutomator2 server and serial forwards cleaned; demo mode and animation scales restored. | CHANGELOG Unreleased Fixed; docs/android.md |  |
| AND-060 | `run` | `--keep-alive &`, then `kill -INT <pid>` | Same cleanup as Ctrl-C; ready file `interrupted`. | README §Agent-Native Features |  |
| AND-061 | `run` | `--keep-alive --ready-file r`, then `hierarchy` as soon as `r` exists | No race: session file exists before the ready file. | docs/dump-hierarchy.md; CHANGELOG 2.0.1 |  |
| AND-062 | `run` | two concurrent runs on different serials | Run in parallel without interfering. | README §Agent-Native Features |  |
| AND-063 | `run` | second run on a serial owned by a live run | Fails fast as already owned, naming the owner. | README §Agent-Native Features |  |
| AND-064 | `run` | orphan forwards for another serial present | Cleanup removes only this serial's forwards (no `adb forward --remove-all`). | CHANGELOG Unreleased Changed |  |

**demo mode and settings**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-065 | `run` | default, before and during capture | Demo mode on (clock 09:41, full battery, no notifications), animation scales 0, portrait pinned. | docs/android.md §Captures and baselines |  |
| AND-066 | `run` | during run | Previous values saved to `.grantiva/android-settings-<serial>.json`. | docs/android.md; CHANGELOG Unreleased Added |  |
| AND-067 | `run` | after a normal exit | Settings restored to the saved values. | docs/android.md |  |
| AND-068 | `run` | `kill -9` mid-run, then another `run` | "If a run is interrupted, the next run restores them first." | docs/android.md §Captures and baselines |  |
| AND-069 | `run` | `--device <physical serial>` without `--allow-device-settings` | Demo mode and animation settings skipped. | docs/android.md §Devices |  |
| AND-070 | `run` | `--device <physical serial> --allow-device-settings` | Settings applied and restored. | docs/android.md §Devices; help: run |  |

**logs**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-071 | `run` | `--logs` | `logcat` lines from the app's uid, prefixed `[log]`. | docs/android.md §Logs; help: run |  |
| AND-072 | `run` | `--logs-tag LandmarksApp` | Implies `--logs`; only that tag. | help: run (`--logs-tag`) |  |
| AND-073 | `run` | `--logs-level debug`, then `info` | Priority filter applied; without `--logs-tag` "filters every tag at that priority". | CHANGELOG Unreleased Added |  |
| AND-074 | `run` | `--logs-predicate x` | Rejected by name before any build ("`--logs-predicate` is iOS-only"). | docs/android.md §Logs |  |
| AND-075 | `run` | `--logs` and exit by success, failure, Ctrl-C | No orphan `logcat` process. | help: run (`--logs`) |  |

**record**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-076 | `record` | `--duration 5 --frames-at 0,1000,3000` | `.grantiva/recordings/recording.mp4` plus three PNGs. | docs/android.md §Recording |  |
| AND-077 | `record` | `--duration 181` | Refused before recording. | docs/android.md §Recording; help: record |  |
| AND-078 | `record` | `--device <serial>`; `--emulator <AVD>` | Each picks that target; config `emulator` is the default. | docs/android.md §Recording |  |
| AND-079 | `record` | `--output /tmp/qa rec/a.mp4 --json` | Writes there; JSON lists video and frames. | help: record |  |

**runner start / stop**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-080 | `runner start` | `--detach` | Boots emulator, holds a UIAutomator2 session, records forwarded port in `.grantiva/session.json`. | docs/android.md §Runner sessions |  |
| AND-081 | `runner dump-hierarchy` | `--format tree`, `json`, `xml` | Same tree in each format. | docs/android.md; help: runner dump-hierarchy |  |
| AND-082 | `runner stop` | after start | Kills the runner, stops UIAutomator2, removes the serial's forwards. | docs/android.md §Runner sessions |  |
| AND-083 | `runner start` | `--application-id x.y --emulator <AVD>` | Uses those values over config. | help: runner start |  |
| AND-084 | `runner start` | stale `.grantiva/session.json` with a dead pid | Treated as no session; starts cleanly. | spec §2 (stale session handling) |  |

**diff and baselines**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-085 | `diff capture` | first capture | Screenshots in `.grantiva/captures/android/`. | docs/android.md §Captures and baselines |  |
| AND-086 | `diff approve` | after capture | Baselines in `.grantiva/baselines/android/`; iOS paths untouched. | docs/android.md; CHANGELOG Unreleased Changed |  |
| AND-087 | `diff compare` | unchanged UI; changed pixel; `--json` | Pass; fail per `threshold`/`perceptual_threshold`; valid JSON metrics. | docs/android.md; README §Configuration |  |
| AND-088 | `diff compare` | while logged in | Uses the local store and prints the local-only line once. | CHANGELOG Unreleased Changed |  |
| AND-089 | `ci run` | Android project | Refuses with "Android baselines are local only until the Grantiva backend supports platforms; use local baselines". | docs/android.md §Captures and baselines |  |

**doctor**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-090 | `doctor --platform android` | toolchain present | SDK, adb, emulator, JDK, AVDs pass; exit 0. | CHANGELOG Unreleased Added; docs/android-environment.md |  |
| AND-091 | `doctor --platform android` | `ANDROID_HOME` unset | Falls back to `ANDROID_SDK_ROOT`, then `~/Library/Android/sdk`. | docs/android-environment.md |  |
| AND-092 | `doctor --platform android --json` | `JAVA_HOME` unset or wrong | JDK check fails; exit non-zero; JSON valid. | CHANGELOG 1.8.0 Fixed; CHANGELOG Unreleased Added |  |

**MCP on Android**

| ID | Command | Flags/inputs | Expected | Source | Result |
|---|---|---|---|---|---|
| AND-093 | `mcp` tools/list | dir with only `grantiva-android.yml`, after `runner start` | Resolves Android; lists the same 22 tools. | docs/android.md §Runner sessions and the MCP server |  |
| AND-094 | `grantiva_context` | none | `platform: android` under `[Config]`, running emulator, Android SDK. | CHANGELOG Unreleased Changed |  |
| AND-095 | `grantiva_tap` | `x`/`y` in dp taken from `hierarchy --format json` | Hits the element (dp, same unit as the hierarchy). | docs/android.md; CHANGELOG Unreleased Added |  |
| AND-096 | `grantiva_tap`, `grantiva_type`, `grantiva_swipe` | label tap, text entry, swipe up | Each acts and returns the updated tree. | tool schema |  |
| AND-097 | `grantiva_screenshot` | default and `format: file` | Base64 PNG; file path returned. | tool schema |  |
| AND-098 | `grantiva_script` | `tap_xy` in dp | Executes in dp. | CHANGELOG Unreleased Added |  |
| AND-099 | `grantiva_a11y_check` | on Landmarks list | Keys on `class`, `content-desc`, `clickable`; 48 dp minimum. | docs/android.md; CHANGELOG Unreleased Added |  |
| AND-100 | `grantiva_emulator_list`, `_boot`, `_ensure`, `_delete` | ensure `{name: "QA_MCP"}` then delete | Mirror the `grantiva_sim_*` tools; `ensure` needs only `name`. | docs/android.md; CHANGELOG Unreleased Added |  |
| AND-101 | `grantiva_build`, `grantiva_run` | `module`, `variant`, `emulator` | Accepted on Android; `Product:` line with APK path. | CHANGELOG Unreleased Added/Changed |  |
| AND-102 | `grantiva_test` | any | Refused as iOS-only. | docs/android.md §Runner sessions |  |
| AND-103 | `grantiva_vrt_capture`, `_compare`, `_approve` | on Android | Use `.grantiva/captures/android/` and `baselines/android/`. | docs/android.md; tool schema |  |
| AND-104 | `mcp` | stdin JSON-RPC while adb runs | `adb shell` does not consume requests (stdin is `/dev/null`); every request answered. | CHANGELOG Unreleased Fixed |  |
| AND-105 | `mcp` | both config files, `--platform android` | Starts on Android. | docs/android.md |  |
