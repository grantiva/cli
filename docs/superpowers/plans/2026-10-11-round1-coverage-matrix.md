# Round 1 coverage matrix: grantiva 2.1.0 (main 51c597a)

Built 2026-10-10 for Task 1 of `docs/superpowers/plans/2026-10-11-round1-coverage-pass.md` (spec:
`docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`). Slices consume it in Tasks 3-5; Task 6 triages
every non-pass row.

- **Binary:** `/Users/kyle/.grantiva-qa/bin/grantiva` with `grantiva_GrantivaCore.bundle` beside it, `--version`
  2.1.0, main 51c597a.
- **Runner:** bundled grantiva-runner `1.1.28-grantiva.9` (stamp `1.1.28-grantiva.9+android-drivers-2`), WDA caches
  `sim-ios{26.0,26.2,26.4,27.0}-iphone-wda16.12.8-r1`; runner home `GRANTIVA_RUNNER_HOME=$HOME/.grantiva-qa/runner`.
- **Devices:** iOS `cov-ios-1` (iPhone 17, iOS 26.0), `cov-ios-2` (iPhone 17, iOS 27.0), extra `cov-ios-3`/`-4` only
  inside a row; Android AVD `cov-android` (API 35), extra `cov-android-2` only inside a row. Never `iPhone 17 Pro`
  (B27D7D31-...) or `Pixel_8_API_35`: where a document's example names `Pixel_8_API_35`, run it with `cov-android`.
- **App:** landmarks-demo (`ios/`, `android/`), stock flows `.maestro/01`-`12`, `99-crash`; coverage flows and configs
  under `.maestro/coverage/` (added by Task 2, specified in `2026-10-11-round1-demo-flows.md`).

## Sources

`help: <file>` is `findings/help/<file>` (the 2.1.0 help corpus, 172 pages); `README:<line>` and `docs/<file>:<line>` are
those files at 51c597a; `brief <ID>` is an original brief (`~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/`)
or a regression brief R01-R05 (`docs/superpowers/plans/2026-10-10-regression-issues/`); `spec §<name>` is the campaign
spec; `plan N<nn>` is the plan's "New findings" list (plus N15-N18 from `findings/round1-smoke.md`); `obs` is the
regression report's §Observations; `src <file>:<line>` is the 51c597a source that produces an exact message (used only
where no document quotes the message); `2.0.1 <ID>` is the row this one replaces.

## Verdicts and slices

`result` is left empty here. Slices write exactly one of: `pass`; `fail` (with evidence; a doubtful or inconsistent
behaviour is `fail`); `blocked <reason>` (environment or a Global Constraint, e.g. `teardown --all`); `n/a <reason>`
(the row does not apply on that platform).

- **platform:** `cli` (no device), `ios`, `android`, `both` (one verdict per platform; the slice records each half).
- **slice:** `CLI` rows need no device and run in Task 3. A CLI-prefixed or B row that needs a device is assigned to
  `iOS` or `Android` explicitly; `iOS+Android` rows are run by both device slices (each records its platform's half).
  Device rows run on iOS 26.0 (`cov-ios-1`) unless the row names 27.0; Task 4 Step 2 repeats every flow-command row and
  the stock set on 27.0 (`cov-ios-2`).
- **flow:** `none` for device-free rows; a device row that drives no app names why in brackets (`none (build
  only)`, `none (device lifecycle only)`, `none (session only)`, `none (records the idle app)`, `none (host checks)`,
  `none (fails before device)`); otherwise a stock path (`.maestro/NN-*.yaml`), a coverage flow (`NEW:<name>` =
  `.maestro/coverage/<name>.yaml`), a coverage config (`NEW:cfg/<name>`), or `any` (any stock flow; the row tests
  the command, not the flow).
- **(changed)** marks a 2.0.1 row whose expectation changed for 2.1.0; unchanged 2.0.1 rows keep their ID and text.
  2.0.1 rows dropped: CLI-018, CLI-022, CLI-089, CLI-090, CLI-092 to CLI-096, CLI-115 (auth/console, out of scope per
  spec §Out of scope; C16/C25 survive as B rows), CLI-116 (CHANGELOG.md removed in #179), IOS-046 (flag never existed;
  folded into CLI-004).

MCP rows are driven with the stdio send script the regression's CLI slice used (`findings/evidence/cli/D09.txt`:
`send.sh <project-dir> <platform|-> <requests.jsonl>`, initialize + initialized + requests) or the iOS slice's
`findings/evidence/ios/inputs/mcp/client.py`. Rule for every MCP row: a tool failure is a `result` with
`"isError": true`, never a JSON-RPC `error` object (docs/mcp.md:21-22).

## CLI slice (device-free)

Work in scratch dirs (`$S=/private/tmp/.../scratchpad/cov-cli/<row>`), copies of the landmarks-demo projects where a
project is needed (`cp -c -R`), never in the landmarks-demo checkout. Exit codes: a usage error (`ValidationError`) is
64; a `GrantivaError` (`Error: Invalid argument: ...` and similar) is 1.

**Help surface**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-001 (changed) | `grantiva --help`, `--version` | none | Exit 0; `--version` prints `2.1.0`; OVERVIEW "The Grantiva CLI for iOS and Android developers."; lists build, run, record, simulator, emulator, hierarchy, ci, diff, auth, console, doctor, runner, init, mcp (help: grantiva.txt) | cli | CLI | none | |
| CLI-002 | `grantiva help <subcommand>` | `grantiva help run`, `grantiva help runner start`, `grantiva help console flags` | Same text as `<subcommand> --help`, exit 0 (help: grantiva.txt "See 'grantiva help <subcommand>'") | cli | CLI | none | |
| CLI-003 (changed) | every command and subcommand `--help` | regenerate all 172 pages into a scratch dir | Each exits 0 with OVERVIEW, USAGE, OPTIONS; byte-identical to `findings/help/*.txt` (help: all 172) | cli | CLI | none | |
| CLI-004 (changed) | `run --help` | none | Flags exactly as help: run.txt; every flag README:76-99 and docs/android.md:54-55 name is present; no `--auto-accept-alerts`, `--no-auto-accept-alerts`, `--wait-for-idle-timeout`; `run --wait-for-idle-timeout 5` is a usage error, exit 64 (help: run.txt; README:76-99) | cli | CLI | none | |
| CLI-005 | `build build --help`, `build install --help` | none | `build install` adds `--app-file`, `--no-build`, `--no-launch`; `build build` has none; `build` alone is `build build` ("build (default)") (help: build.txt, build_build.txt, build_install.txt) | cli | CLI | none | |
| CLI-006 | `diff capture/compare/approve --help` | none | `compare` adds `--capture` ("runs full lifecycle"); `approve` takes `[<screen-names> ...]` and `--platform` only (help: diff_*.txt) | cli | CLI | none | |
| CLI-007 | `simulator <sub> --help`, `emulator <sub> --help` | ensure, delete, sessions, teardown, cleanup | Each exits 0; `simulator ensure` shows `--boot/--no-boot (default: --boot)`; `emulator teardown` shows `--serial`, `--all`, `--force`; `emulator delete` `--name`, `--force` (help: simulator_*.txt, emulator_*.txt) | cli | CLI | none | |
| CLI-008 | `runner <sub> --help`, `hierarchy --help`, `record --help` | install, version, start, stop, dump-hierarchy | Each exits 0; `dump-hierarchy` shows `-p/--port`, `-f/--format` (tree, json, xml; default tree), `--udid`; `record` marks `--duration` required (help: runner_*.txt, hierarchy.txt, record.txt) | cli | CLI | none | |
| CLI-009 | `console --help` tree | all 17 groups | Lists flags (alias `featureflags`), envs, analytics, devices, apps, claims, vrt, releases, feedback, support, webhooks, alerts, keys, team, audit, org, open; `console featureflags --help` equals `console flags --help` (help: console.txt) | cli | CLI | none | |
| CLI-010 | any command | `run --bogus`, `doctor --bogus` | Usage error on stderr, exit 64, stdout empty (README:373-376) | cli | CLI | none | |
| CLI-123 | `runner start --help` vs README | none | Abstract names the Android driver too, as README:333 does ("with WDA (UIAutomator2 on Android)"); today help says "with WDA" only, which is N07 (help: runner_start.txt; README:333; plan N07) | cli | CLI | none | |
| CLI-124 | `mcp --help` | none | DISCUSSION says the server starts without a session or config; device tools listed need a session; `--project-dir`, `--platform` (help: mcp.txt; docs/mcp.md:14-22) | cli | CLI | none | |
| CLI-125 | `hierarchy --help` | none | Discussion describes `/tmp/grantiva-sessions`, newest session, `--udid` UDID or adb serial; `--timeout` default 60; `--format` xml or json, `--json` same as `--format json` (help: hierarchy.txt; docs/dump-hierarchy.md:36-39) | cli | CLI | none | |

**stdout / stderr contract**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-011 | `doctor --json` | none | stdout valid JSON array of checks with `status`; `doctor --json \| jq '.[] \| select(.status == "fail")'` works; no narration on stdout (README:380) | cli | CLI | none | |
| CLI-012 | `doctor --json --quiet` | none | stdout still valid JSON (README:391-393) | cli | CLI | none | |
| CLI-013 | `doctor --json --verbose` | none | stdout valid JSON; stderr gains timestamps, labels and every subprocess with its exit status (README:390) | cli | CLI | none | |
| CLI-014 | `doctor` | `> out.txt`; `NO_COLOR=1` on a TTY (`script -q`) | No ANSI escapes in redirected stdout; `NO_COLOR` suppresses colour (README:373-376) | cli | CLI | none | |
| CLI-015 | `simulator sessions --json` | plain, `--quiet`, `--verbose` | stdout valid JSON in all three; diagnostics only on stderr (README:373-376; help: simulator_sessions.txt) | cli | CLI | none | |
| CLI-016 | `emulator sessions --json` | plain, `--quiet`, `--verbose` | stdout valid JSON in all three (help: emulator_sessions.txt) | cli | CLI | none | |
| CLI-017 | `runner version` | with and without `--json` | Prints the embedded runner version; `--json` valid JSON (help: runner_version.txt; README:365-369) | cli | CLI | none | |
| CLI-019 (changed) | leaf commands with `--json` and a forced failure | `doctor --json` with `DEVELOPER_DIR=/nonexistent`; `simulator teardown --json`; `diff compare --json` with no captures; `run --json` in an empty dir | `Error:` on stderr, exit non-zero; stdout empty except `run --json`, which prints `{"allPassed": false, "screens": [], "error": "..."}` (README:383-386) | cli | CLI | none | |
| CLI-020 | any command | `--quiet` | Narration silenced; `Warning:` and `Error:` still on stderr; stdout unchanged (README:391-393) | cli | CLI | none | |
| CLI-021 | any command | `--verbose` | Debug detail with timestamps and labels on stderr; stdout unchanged (README:390) | cli | CLI | none | |
| CLI-126 | `runner install`, `runner stop` | `--json` | `runner install --json` and `runner stop --json` print a JSON result (README:367-369) | cli | CLI | none | |

**Project detection and platform**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-023 | `doctor`, `init` | dir with only an `.xcodeproj` | Resolves to iOS (docs/android.md:15-16) | cli | CLI | none | |
| CLI-024 | `doctor`, `init` | dir with only `settings.gradle.kts` | Resolves to Android (docs/android.md:15-16) | cli | CLI | none | |
| CLI-025 (changed) | `run`, `doctor` | `.xcodeproj` + `settings.gradle.kts`, no config | `run`: `Error: Invalid argument: Found both an Xcode project and Gradle settings. Pass --platform ios\|android or set GRANTIVA_PLATFORM.`, exit 1; `doctor` reports it and exits non-zero (brief C12; src PlatformResolver.swift:53) | cli | CLI | none | |
| CLI-026 | `doctor` | empty dir | Both toolchains as advice; missing project advisory, does not fail the exit code (README:330) | cli | CLI | none | |
| CLI-027 | `run`, `diff capture` | dir with only `.maestro/*.yaml` | Flows auto-detected from `.maestro/` with no `grantiva.yml` (README:158) | cli | CLI | none | |
| CLI-028 | `run`, `diff capture` | `grantiva.yml` absent, empty `.maestro/` | Clear error, non-zero; `run` says `No grantiva.yml here. Create one with grantiva init.` (brief C18) | cli | CLI | none | |
| CLI-029 | `diff capture` | `grantiva.yml` in Maestro format (`appId:` + `---`) | Parsed as Maestro: each `takeScreenshot` a screen, commands between its steps; fails only at device resolution (README:158-172) | cli | CLI | none | |
| CLI-030 (changed) | `run` | both config files, no flag | `Error: Invalid argument: Both grantiva.yml and grantiva-android.yml exist. Pass --platform ios\|android or set GRANTIVA_PLATFORM.` (docs/android.md:56-57; src PlatformResolver.swift:40) | cli | CLI | none | |
| CLI-031 | `run`, `doctor` | both config files plus `--platform android`, then `GRANTIVA_PLATFORM=ios` | Each selects the named platform's config (help: run.txt `--platform`; docs/android.md:56-57) | cli | CLI | none | |
| CLI-032 | `doctor` | `--platform ios` with `GRANTIVA_PLATFORM=android` | The flag wins (help: doctor.txt "GRANTIVA_PLATFORM also sets it") | cli | CLI | none | |
| CLI-033 (changed) | `doctor`, `run`, `init` | `GRANTIVA_PLATFORM=windows` | `GRANTIVA_PLATFORM is "windows"; expected ios or android.`, non-zero, no file written by init (brief C12) | cli | CLI | none | |
| CLI-034 (changed) | `run` | `--platform android` where only `grantiva.yml` exists | `--platform android was given but grantiva-android.yml does not exist here. Found grantiva.yml. Create grantiva-android.yml with grantiva init --platform android.` (brief C18; src Options.swift:170) | cli | CLI | none | |
| CLI-035 | `run` | `--platform macos` | Usage error listing ios, android; exit 64 (help: run.txt) | cli | CLI | none | |
| CLI-127 | `doctor` | `GRANTIVA_PLATFORM=" Android "`; `GRANTIVA_PLATFORM=""` | Trimmed and lower-cased to android; empty treated as unset (help: doctor.txt; src PlatformResolver.swift:66) | cli | CLI | none | |
| CLI-128 | `mcp` | `--platform windows` | Usage error naming ios, android; exit 64; no JSON-RPC on stdout (help: mcp.txt) | cli | CLI | none | |

**Config parsing and validation**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-036 | `run` | `grantiva.yml` with a YAML syntax error | Error naming the file and the YAML line/column (brief C20) | cli | CLI | none | |
| CLI-037 | `run --platform android` | `grantiva-android.yml` with a YAML syntax error | Error names `grantiva-android.yml` and line/column (brief C20) | cli | CLI | none | |
| CLI-038 (changed) | `run` | empty or comments-only `grantiva.yml` | `Error: Invalid argument: No screens or flows configured in grantiva.yml`, exit 1 (brief C18) | cli | CLI | none | |
| CLI-039 (changed) | `run`, `doctor` | `grantiva.yml` with `schem: Landmarks` at line 1, `screen:` at line 4 | stderr `grantiva.yml:1: unknown key "schem" (did you mean "scheme"?)` and line 4 for `screen`, as warnings; doctor shows a Project warning (README:150; brief C19) | cli | CLI | none | |
| CLI-040 | `run` | `grantiva.yml` containing `platform: android` | Error that the file declares the other platform (docs/android.md:20) | cli | CLI | none | |
| CLI-041 (changed) | `run` | Android project + `--scheme X` | `--scheme is an iOS option, but this is an Android project (resolved from --platform, GRANTIVA_PLATFORM, the config file, or the directory).`, before any build (docs/android.md:55-56; src TargetOptions.swift:66) | cli | CLI | none | |
| CLI-042 (changed) | `run` | iOS project + `--module app` | `--module is an Android option, but this is an iOS project (...)` (docs/android.md:55-56) | cli | CLI | none | |
| CLI-043 | `run` | Android + `--logs-predicate x`; iOS + `--logs-tag x` | Each rejected by name before any build (docs/android.md:95; help: run.txt) | cli | CLI | none | |
| CLI-044 (changed) | `run` | `flows: []`, no `screens`, `--report-dir out --ready-file out.ready` | Fails before any boot with `No screens or flows configured in grantiva.yml`; no `out/report.json` claiming a pass; `out.ready` has `"status": "failed"` (README:85; brief C18) | cli | CLI | none | |
| CLI-045 (changed) | `run` | Android project, `--device emulator-5554 --emulator cov-android` | `--device and --emulator are mutually exclusive; pass one.`, exit 1, before device work (src TargetOptions.swift:59) | cli | CLI | none | |
| CLI-046 (changed) | `diff capture` (parse) | `screens:` with `launch`, `tap`, `tap: {text: X, exact: true}`, `swipe` up/down/left/right/`UP`, `type`, `wait`, `assert_visible`, `assert_not_visible` (both forms), `run_flow` | All parse (any case for swipe); failure, if any, is at device resolution, not parsing (README:132-146) | cli | CLI | none | |
| CLI-047 (changed) | `diff capture` | screen `Diag` with `- swipe: diagonal` | Fails before boot: `grantiva.yml: screen "Diag": swipe direction "diagonal" is not one of up, down, left, right` (README:136; brief C15) | cli | CLI | none | |
| CLI-048 | `diff capture` | `- run_flow: "sub/flow.yaml"` relative; a missing path | Relative to the config's directory; missing file is an error naming the path (README:141) | cli | CLI | none | |
| CLI-049 | `diff capture` | `run_flow` cycle A->B->A | Error naming the cycle; no hang (README:141) | cli | CLI | none | |
| CLI-050 (changed) | `run` | `--env NOEQUALS`; `--env =v`; `--env 'A B=1'`; `--env 1A=x` | `Invalid --env "NOEQUALS": expected KEY=VALUE.`; `... the key before `=` is empty.`; `... the key must not contain whitespace.`; `... the key must start with a letter or `_` ...`; before device work (help: run.txt `--env`; src FlowEnvironment.swift:83-101) | cli | CLI | none | |
| CLI-051 | `run` | `--ready-file <existing directory>` | Rejected at startup (README:85) | cli | CLI | none | |
| CLI-052 | `run` | stale `x.ready` with `{"status":"passed"}`, no project | Deleted at startup, rewritten `failed` (README:85) | cli | CLI | none | |
| CLI-053 | `run` | `--ready-file x.ready`, no project | File exists after exit with `"status":"failed"`; exit non-zero (README:85) | cli | CLI | none | |
| CLI-054 | `run` | `--ready-file` in a `chmod 0500` directory | Fails immediately, non-zero, before project work (README:85) | cli | CLI | none | |
| CLI-055 | `run` | `--snapshot bogus` | Usage error naming failure, trailing, full; exit 64 (help: run.txt) | cli | CLI | none | |
| CLI-056 | `run` | `--timeout abc`, `--timeout -1` | Usage error, exit 64 (help: run.txt) | cli | CLI | none | |
| CLI-129 | `run` | `--timeout 5`; `--timeout 5 --ready-file r.ready` | Exit 64, `--timeout must be at least 30 seconds.`; `r.ready` has `"status": "failed"` and an `error` field (README:85, 97) | cli | CLI | none | |
| CLI-130 | `run` | `--timeout 5 --keep-alive` | Still exit 64 with the same message (README:97 "the 30 s minimum is still validated") | cli | CLI | none | |
| CLI-131 | `run` | `--logs-level warning` | Usage error naming default, info, debug; exit 64 (help: run.txt; docs/android.md:95; brief A08) | cli | CLI | none | |
| CLI-057 | `run --platform android` | `--application-id "not valid"` | Rejected as an invalid application ID before device work (help: run.txt) | cli | CLI | none | |
| CLI-058 | `simulator teardown` | `--udid "" --force` | Rejected, non-zero (help: simulator_teardown.txt) | cli | CLI | none | |
| CLI-059 | `simulator teardown` | `--udid not-a-udid-at-all --force`; `--session-id ""` | Both rejected (help: simulator_teardown.txt) | cli | CLI | none | |
| CLI-060 (changed) | `simulator teardown` | `--session-id X --udid <valid UDID>` | `--session-id and --udid are mutually exclusive; pass one.`, exit 64 (README:447) | cli | CLI | none | |
| CLI-061 | `diff capture` (parse) | Maestro flow `- tapOn: "Mount \"Denali\" 🏔️"` | Parses; the staged flow carries the label byte for byte (README:172) | cli | CLI | none | |
| CLI-062 (changed) | `simulator teardown` | no `--session-id`, no `--udid` | `Pass --session-id <id> or --udid <UDID>.`, exit 64 (help: simulator_teardown.txt; src SimulatorCommand.swift:118) | cli | CLI | none | |
| CLI-132 | `run` | iOS project + `--device emulator-5554` | Rejected by name as an Android option (docs/android.md:55-56) | cli | CLI | none | |
| CLI-133 | `run` | `--flow missing.yaml` | Error naming the missing path, non-zero, before device work (help: run.txt `--flow`) | cli | CLI | none | |
| CLI-134 | other-platform flags on every build-option command | iOS project: `build build --variant x`, `ci run --device emulator-5554`, `runner start --application-id a.b`; Android project: `build install --bundle-id x`, `diff capture --scheme X`, `runner start --simulator X` | Each rejected by name before any build or boot (docs/android.md:55-56) | cli | CLI | none | |

**Maestro format (parse only)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-063 (changed) | `diff capture` (parse) | Maestro `grantiva.yml`, one fixture per supported command: `tapOn`, `doubleTapOn`, `longPressOn`, `inputText`, `assertVisible`, `assertNotVisible`, `swipe` (`direction:`, `from:`, `start:`/`end:`, `duration:`), `scroll`, `scrollUntilVisible`, `runFlow`, `extendedWaitUntil` (`visible:`, `notVisible:`), `waitForAnimationToEnd`, `launchApp`, `stopApp`, `killApp`, `takeScreenshot` | Each parses; failure only at device resolution (README:172) | cli | CLI | none | |
| CLI-064 (changed) | `diff capture` (parse) | `tapOn: {text: X}`, `tapOn: {id: X}` | Text selector and id selector; the staged flow carries `id: X` (README:172; brief C08) | cli | CLI | none | |
| CLI-065 (changed) | `diff capture` (parse) | Maestro `grantiva.yml` with `- back` at line 5; also `setPermissions`, `evalScript`, `pressKey`, `openLink` | Rejected before the run: `grantiva.yml:5: unsupported Maestro command 'back'` (file and line, no enum text) (README:172; brief C07) | cli | CLI | none | |
| CLI-066 | `diff capture` (parse) | `- scroll`, `- scroll: {direction: up}` | Mapped to a swipe in the opposite finger direction (README:172) | cli | CLI | none | |
| CLI-067 | `diff capture` (parse) | two `takeScreenshot` points | Two named screens (README:172) | cli | CLI | none | |
| CLI-068 | `diff capture` (parse) | `runFlow: sub.yaml`, `runFlow: {file: sub.yaml}` | Both include the sub-flow's steps (README:172) | cli | CLI | none | |
| CLI-135 | `diff capture` (parse) | `swipe: {direction: UP}`, `extendedWaitUntil: {visible: X}`, bare `waitForAnimationToEnd` | All three standard forms parse (brief C07) | cli | CLI | none | |

**init**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-069 | `init` | Xcode-only dir (copy of landmarks-demo/ios without grantiva.yml) | Writes `grantiva.yml` with the detected scheme; exit 0 (help: init.txt; README:35) | cli | CLI | none | |
| CLI-070 | `init` | Gradle-only dir | Writes `grantiva-android.yml` (docs/android.md:12) | cli | CLI | none | |
| CLI-071 (changed) | `init` | both Xcode and Gradle, no flag | `Found both an Xcode project and Gradle settings. Pass --platform ios\|android or set GRANTIVA_PLATFORM.`, no file (docs/android.md:16; src InitCommand.swift:81) | cli | CLI | none | |
| CLI-072 (changed) | `init` | empty dir | Writes `grantiva.yml` and warns on stderr `No Xcode project found; scheme "MyApp" is a placeholder. Edit grantiva.yml or pass --scheme.`; simulator default is an installed iPhone type or warned as a placeholder (brief C24) | cli | CLI | none | |
| CLI-073 | `init` | `--scheme Landmarks --bundle-id com.kylebrowning.Landmarks` | Config has exactly those values (help: init.txt) | cli | CLI | none | |
| CLI-074 | `init --platform android` | `--application-id com.kylebrowning.landmarks` | Writes `grantiva-android.yml` with `application_id` (docs/android.md:12) | cli | CLI | none | |
| CLI-075 | `init` | twice in one dir | Second refuses, file unchanged, message on stderr (help: init.txt) | cli | CLI | none | |
| CLI-076 (changed) | `init` | `--platform android --scheme X`; `--platform ios --application-id a.b` | Each fails naming the flag; no file written (brief C12) | cli | CLI | none | |
| CLI-077 | `init` | `--json` | Usage error, exit 64 (help: init.txt has no `--json`) | cli | CLI | none | |
| CLI-136 | `init` | `--scheme X` in an empty dir | No placeholder warning for the scheme (brief C24) | cli | CLI | none | |

**doctor**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-078 | `doctor --platform ios` | healthy host | Exit 0 when every required check passes (README:330) | cli | CLI | none | |
| CLI-079 | `doctor --platform android` | toolchain per docs/android-environment.md | Checks Android SDK, adb, emulator, JDK, AVDs (docs/android.md:13) | cli | CLI | none | |
| CLI-080 | `doctor --platform android` | `ANDROID_HOME` unset | Falls back to `ANDROID_SDK_ROOT`, then `~/Library/Android/sdk` (docs/android-environment.md:15-16) | cli | CLI | none | |
| CLI-081 | `doctor` | `DEVELOPER_DIR=/nonexistent` | Xcode check fails with a fix line; exit non-zero in text and `--json` (README:330) | cli | CLI | none | |
| CLI-082 (changed) | `doctor --platform android` | `ANDROID_HOME=/nonexistent` with the default SDK present; then `ANDROID_SDK_ROOT=/nonexistent` | SDK check is a warning naming the variable: `... (ANDROID_HOME=/nonexistent has no platform-tools/adb; unset or fix it)`; same for `ANDROID_SDK_ROOT` (brief C23) | cli | CLI | none | |
| CLI-083 | `doctor` | no config, not authenticated, no booted simulator | Optional checks advisory; exit code unaffected (README:330) | cli | CLI | none | |
| CLI-137 | `doctor` | malformed `grantiva-android.yml` (error at 5:3) | `✗ grantiva-android.yml could not be parsed: 5:3: ...` with a fix line (brief C20) | cli | CLI | none | |
| CLI-138 | `doctor` | run from `android/` subdirectory of a git work tree | `✓ Git Repository Detected` (brief A12) | cli | CLI | none | |

**runner (no session)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-084 | `runner install` | twice | Both exit 0; idempotent (README:38) | cli | CLI | none | |
| CLI-085 (changed) | `runner version` | none | Prints `grantiva-runner 1.1.28-grantiva.9`; exit 0 (help: runner_version.txt) | cli | CLI | none | |
| CLI-086 (changed) | `runner stop` | no session | `runner stop 2>/dev/null` prints nothing; message on stderr; `--json` prints `{"status":"not_running"}` (brief C13) | cli | CLI | none | |
| CLI-087 (changed) | `runner dump-hierarchy` | no session | `No active runner session. Start one with 'grantiva runner start' or `grantiva run --keep-alive`, or pass --port.`, non-zero (docs/dump-hierarchy.md:57; src DriverCommand.swift:736) | cli | CLI | none | |
| CLI-088 | `hierarchy` | no keep-alive session | Fails with a clear message, non-zero, stdout empty (help: hierarchy.txt; docs/dump-hierarchy.md:25) | cli | CLI | none | |
| CLI-139 | `hierarchy` | `--timeout 0`; `--json --format xml`; `--format yaml` | `--timeout must be greater than zero` (64); `--json and --format xml conflict; pass one.` (64); usage error naming xml, json (docs/dump-hierarchy.md:37-39; src HierarchyCommand.swift:58,62) | cli | CLI | none | |
| CLI-140 | `runner dump-hierarchy` | `--json --format tree`; `--format bogus` | `--json and --format tree conflict; pass one.` (64); usage error naming tree, json, xml (docs/dump-hierarchy.md:51; src DriverCommand.swift:718) | cli | CLI | none | |
| CLI-141 | `runner install` | relative `GRANTIVA_RUNNER_HOME=rh` from a scratch dir | Installs under `<scratch>/rh/versions/<stamp>/` (README:186 "A relative path is resolved against the current directory") | cli | CLI | none | |
| CLI-142 | `runner install` | copy of the binary beside a resource bundle from another release (blocked if none is available) | Fails naming both versions and the bundle; existing install untouched (README:186) | cli | CLI | none | |

**ci, record, simulator, emulator, diff validation (no device)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-091 | `ci run` | iOS project, no credentials | `Error: Not authenticated. Run: grantiva auth login`, non-zero, stdout empty (README:47; src GrantivaError.swift) | cli | CLI | none | |
| CLI-108 | `ci run --platform android` | Android project | Refuses with "Android baselines are local only until the Grantiva backend supports platforms; use local baselines" (docs/android.md:71-73) | cli | CLI | none | |
| CLI-101 (changed) | `record --platform android` | `--duration 200` | `Android recordings are capped at 180 seconds per file (screenrecord --time-limit); --duration 200.0 is too long.` before recording (docs/android.md:118) | cli | CLI | none | |
| CLI-102 (changed) | `record` | `--duration 2 --frames-at a,b` | Exit 64 in under a second: `--frames-at must contain non-negative integer milliseconds, e.g. 0,150,300; got a,b`; no video (brief C14) | cli | CLI | none | |
| CLI-103 | `record` | no `--duration` | Usage error, exit 64 (help: record.txt) | cli | CLI | none | |
| CLI-143 | `record` | `--duration 0` | `Error: Invalid argument: --duration must be greater than zero` (src RecordCommand.swift:113) | cli | CLI | none | |
| CLI-144 | `record` | iOS project `--output a.mp4`; Android project `--output a.mov`; extensionless `--output a` | Exit 64: `--output must end in .mov on iOS (simctl records QuickTime); got a.mp4. Try a.mov.` and the `.mp4` / Android counterpart, before recording (help: record.txt `--output`; brief C14) | cli | CLI | none | |
| CLI-145 | `record` | iOS project `--emulator X`, `--device X`; Android project `--simulator X`, `--device a --emulator b` | `--emulator is an Android option, but this is an iOS project.`; `--device ...`; `--simulator is an iOS option, but this is an Android project.`; `--device and --emulator are mutually exclusive; pass one.` (help: record.txt; src RecordCommand.swift:85-94) | cli | CLI | none | |
| CLI-146 | `record` | iOS project without `simulator:` and no `--simulator` | `No simulator named. Pass --simulator or set simulator in grantiva.yml.` (help: record.txt) | cli | CLI | none | |
| CLI-104 (changed) | `emulator teardown` | neither `--serial` nor `--all` | `Pass --serial <serial> or --all.`, exit 64 (help: emulator_teardown.txt) | cli | CLI | none | |
| CLI-147 | `emulator teardown` | `--serial emulator-5554 --all`; `--serial <a simulator UDID>` | `--serial and --all are mutually exclusive; pass one.` (64); `--serial <udid> is a simulator UDID, not an emulator serial. Use `grantiva simulator teardown` for simulators.` (src EmulatorCommand.swift:146,154) | cli | CLI | none | |
| CLI-148 | `emulator ensure` | no `--name`, no config | `No AVD named. Pass --name or set emulator in grantiva-android.yml.` (help: emulator_ensure.txt) | cli | CLI | none | |
| CLI-149 | `emulator delete`, `simulator delete` | no `--name` | Usage error, exit 64 (help: emulator_delete.txt, simulator_delete.txt) | cli | CLI | none | |
| CLI-105 | `simulator ensure` | no `--name` | Usage error, exit 64 (help: simulator_ensure.txt) | cli | CLI | none | |
| CLI-106 (changed) | `diff approve`, `diff compare` | no captures | `No captures found in <dir>. Run: grantiva diff capture`, non-zero (help: diff_approve.txt) | cli | CLI | none | |
| CLI-150 | `diff approve` | a fake `.grantiva/captures/Home.png`; `diff approve NoSuchScreen` | `No capture found for "NoSuchScreen"`, non-zero; Home untouched (help: diff_approve.txt) | cli | CLI | none | |
| CLI-151 | `diff capture` | config without `screens:` | `No screens configured in grantiva.yml` (brief R04 criterion 3; src DiffCommand.swift:663) | cli | CLI | none | |
| CLI-107 (changed) | `build build --platform android` | `--derived-data-path x` | `--derived-data-path is an iOS option, but this is an Android project (...)` (docs/android.md:55-56) | cli | CLI | none | |

**MCP (device-free start-up)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-097 (changed) | `mcp` | `--project-dir <empty dir>` | Server starts, answers `initialize` and `tools/list` (22 tools); stdout carries only JSON-RPC (docs/mcp.md:9, 14) | cli | CLI | none | |
| CLI-098 | `mcp` | `--project-dir /nonexistent` | Error that the directory does not exist; non-zero (help: mcp.txt) | cli | CLI | none | |
| CLI-099 (changed) | `mcp` | config present, no session | Starts; session tools return isError naming `grantiva runner start` and `grantiva run --keep-alive` (docs/mcp.md:14-17) | cli | CLI | none | |
| CLI-100 | `mcp` | both config files, no `--platform`; then `--platform ios` | Without the flag: an error (startup or per tool) asking for `--platform`; with it, iOS (docs/mcp.md:5-6) | cli | CLI | none | |

**README and docs examples (device-free ones; device examples are iOS/Android rows)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-152 | install examples | README:14, README:20-23 | Not run: Global Constraints forbid installing or building another grantiva; row records `n/a` with that reason (README:14-23) | cli | CLI | none | |
| CLI-153 | Quick Start, device-free lines | `grantiva doctor`, `grantiva init` (Xcode copy), `grantiva runner install`, `grantiva ci run` as written | Each runs as written; `ci run` ends with the auth error of CLI-091; `auth login` (README:44) is out of scope, `n/a` (README:32-47) | cli | CLI | none | |
| CLI-154 | README config example | README:105-121 saved as `grantiva.yml` in an Xcode copy; `doctor` | Loads with no unknown-key warning and no parse error (README:105-121, 150) | cli | CLI | none | |
| CLI-155 | README Maestro-format example | README:160-170 saved as `grantiva.yml`; `diff capture --no-build` | Parses into screens `Login` and `Welcome`; fails only at device resolution (README:158-172) | cli | CLI | none | |
| CLI-156 | README pre-built examples | README:217, 220, 223, 300 (`ci run --app-file ...`, `--no-build`) | Parse as written; each ends with the auth error (no credentials) (README:211-226) | cli | CLI | none | |
| CLI-157 | README stdout examples, device-free half | README:380 `grantiva doctor --json \| jq '.[] \| select(.status == "fail")'` | jq exits 0 (README:378-381) | cli | CLI | none | |
| CLI-158 | dashboard examples | README:356-357 `console --help`, `console flags --help` | Exit 0; README:360-362 need credentials, `n/a` out of scope (README:354-363) | cli | CLI | none | |
| CLI-159 | docs/android.md setup | docs/android.md:12-13 `init --platform android`, `doctor` in a Gradle copy | Writes `grantiva-android.yml`; doctor runs Android checks (docs/android.md:12-13) | cli | CLI | none | |
| CLI-160 | docs/android-environment.md | :5 `scripts/android-env.sh`; :11-13 exports | Script not run (host already provisioned; `n/a`); the three exports are the slices' shell preamble and work as written (docs/android-environment.md:5-13) | cli | CLI | none | |

**Cross-source consistency (read sources; Task 3 Step 3)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| CLI-109 (changed) | README run example | README:414-415 | `grantiva run --simulator "$udid" --flow flows/login.yaml` parses (no usage error) (brief D03) | cli | CLI | none | |
| CLI-110 (changed) | runner `--json` | README:365-369 vs help: runner_*.txt | Sources agree: every runner lifecycle help page lists `--json` (brief D01) | cli | CLI | none | |
| CLI-111 (changed) | README Commands list | README:305-338 vs help corpus | Every line matches its help abstract (incl. 311, 312, 314, 337 flagged in obs) and every leaf except console subgroups is listed (brief D02; obs README-vs-help) | cli | CLI | none | |
| CLI-112 (changed) | Maestro unsupported commands | README:172 vs CLI-065 behaviour | README's rejection wording matches the actual error (README:172; brief C07) | cli | CLI | none | |
| CLI-113 (changed) | `simulator cleanup` wording | README:321 vs help: simulator_cleanup.txt vs SIMULATOR-LIFECYCLE.md | Agree (brief D02) | cli | CLI | none | |
| CLI-114 (changed) | `simulator delete`/`sessions` abstracts | help: simulator.txt vs README:318-319 | Agree; both non-empty (brief D02) | cli | CLI | none | |
| CLI-117 (changed) | Android `ci run` | docs/android-environment.md:20-24 vs docs/android.md:71-73 | Agree: refused, use local diff commands (brief D06) | cli | CLI | none | |
| CLI-118 (changed) | emulator selection | docs/android.md:33-38 | One order: configured AVD (running, else booted); else one running, one booting, the only AVD; else error listing AVDs (brief D07) | cli | CLI | none | |
| CLI-119 (changed) | iOS-only wording | help overviews of grantiva, run, build build, record, hierarchy; README:3 | Name both platforms; `--no-build` says "device" (brief D04) | cli | CLI | none | |
| CLI-120 (changed) | `hierarchy --json` | help: hierarchy.txt vs docs/dump-hierarchy.md:38 vs README:367 | Agree: `--json` = `--format json` (brief D01) | cli | CLI | none | |
| CLI-121 (changed) | `--ready-file` parent dirs | README:87 vs help: run.txt | Both say missing parent directories are created (brief D08) | cli | CLI | none | |
| CLI-122 (changed) | MCP tool list | docs/mcp.md:9, 47-90 vs `tools/list` | 22 names, identical sets; `grantiva_test` iOS only, emulator tools Android only (brief D09) | cli | CLI | none | |
| CLI-161 | per-device runner home path | README:92 vs on-disk layout | README names `<runner home>/versions/<runner version>/devices/<udid>` (obs README:92) | cli | CLI | none | |
| CLI-162 | `--timeout`/`--continue-on-failure` for screens | README:95-99 | No contradiction; `grep -n "fixed 300 s timeout" README.md` is empty (brief R03) | cli | CLI | none | |
| CLI-163 | diff threshold docs | README:123-128 | States both checks must pass, `threshold` 0-1 fraction, `perceptual_threshold` mean CIE76 over differing pixels, raise both (brief I19) | cli | CLI | none | |
| CLI-164 | MCP session docs | docs/mcp.md:14-35 vs help: mcp.txt vs docs/android.md:148-162 | Agree on which tools need a session, the startup isError, config errors and session discovery (brief C11, R05) | cli | CLI | none | |

## iOS slice

`cov-ios-1` (26.0) unless stated; `GRANTIVA_SESSION_ID=cov-ios`; app built from the scratch copy of
landmarks-demo/ios (post-Task-2), scheme `Landmarks (UI Testing)`, bundle `com.kylebrowning.Landmarks`. Extra
simulators are named `cov-ios-3 iPhone 17` / `cov-ios-4 iPhone 17` and deleted inside the row.

**Stock set and cache**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-117 | `run --no-build` | stock set on `cov-ios-1` (26.0) | 12/12 flows pass, exit 0; the runner log shows `Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8-r1)` and no first-time build (plan Task 4 Step 1; README:62) | ios | iOS | .maestro/01-browse.yaml ... 12-quote-label.yaml | |
| IOS-118 | `run --no-build` | stock set on `cov-ios-2` (27.0) | 12/12 pass; cache line names `sim-ios27.0-iphone-wda16.12.8-r1` (plan Task 4 Step 1) | ios | iOS | .maestro/01-browse.yaml ... 12-quote-label.yaml | |
| IOS-119 | `run --flow` | `.maestro/99-crash.yaml` | Fails fast at the first wait with the app-not-running / crashed reason, exit 1, failure screenshot (brief A01 criterion 1; plan N14) | ios | iOS | .maestro/99-crash.yaml | |
| IOS-120 | `diff capture` | the five configured screens on 26.0 and 27.0 | 5/5 captured; Lakes and Detail are the right screens (README:457-470) | ios | iOS | grantiva.yml screens | |

**simulator ensure, capacity, teardown**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-001 | `simulator ensure` | `--name "cov-ios-3 iPhone 17"` (new) | Creates, boots, prints only the UDID on stdout; human line on stderr (README:410-420) | ios | iOS | none (device lifecycle only) | |
| IOS-002 | `simulator ensure` | same `--name` again | Same UDID; stderr `Reused iPhone 17 (…) — Booted` style line (README:418) | ios | iOS | none (device lifecycle only) | |
| IOS-003 | `simulator ensure` | `--name "cov-ios-4 Pin" --device-type "iPhone 17" --runtime latest` | Created with that type on the newest runtime (help: simulator_ensure.txt) | ios | iOS | none (device lifecycle only) | |
| IOS-004 | `simulator ensure` | `--runtime 26.0`; then `--runtime 99.9` | Uses 26.0; uninstalled runtime is a clear error, nothing created (help: simulator_ensure.txt) | ios | iOS | none (device lifecycle only) | |
| IOS-005 | `simulator ensure` | `--no-boot` | Created and left Shutdown; stdout is the UDID (README:427) | ios | iOS | none (device lifecycle only) | |
| IOS-006 (changed) | `simulator ensure --json` | new device; then bare `--name cov-ios-1 --json` reuse | Valid JSON with UDID and display geometry; the reuse reports the device's own type and `runtime: iOS 26.0` (README:419-428; brief I10) | ios | iOS | none (device lifecycle only) | |
| IOS-007 | `simulator ensure` | `--name "cov-thing"` (no model, no `--device-type`, not existing) | Rejected: `Could not infer a device type from the name ... Include a device model ... or pass --device-type.`; nothing created (help: simulator_ensure.txt) | ios | iOS | none (device lifecycle only) | |
| IOS-008 | `simulator ensure` | two concurrent calls, same new name | Exactly one device (`Created` + `Reused`) (SIMULATOR-LIFECYCLE.md) | ios | iOS | none (device lifecycle only) | |
| IOS-009 | `simulator ensure` | after creating | Recorded in `~/.grantiva/simulator-capacity/created.json` (SIMULATOR-LIFECYCLE.md) | ios | iOS | none (device lifecycle only) | |
| IOS-010 (changed) | `simulator sessions` | plain and `--json` | Lists only Grantiva-booted slots and owners; `acquiredAt` etc. ISO 8601 strings; a manually booted device (iPhone 17 Pro) is not listed (help: simulator_sessions.txt; brief C22, I08) | ios | iOS | none (device lifecycle only) | |
| IOS-011 (changed) | `simulator ensure` at capacity | `GRANTIVA_MAX_SIMULATORS=3`, cov-ios-1..3 Grantiva-booted, then ensure cov-ios-4 | Waits and logs `Warning: Waiting for simulator capacity (3/3): …` naming only Grantiva-booted occupants (README:398-399, 449-450) | ios | iOS | none (device lifecycle only) | |
| IOS-012 | `simulator ensure` | `GRANTIVA_MAX_SIMULATORS=1` with one slot used | Second boot waits (README:449-450) | ios | iOS | none (device lifecycle only) | |
| IOS-013 (changed) | `simulator ensure` | `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS=5` at capacity, new name | Gives up after about 5 s, non-zero; the device it created is deleted (brief I14; README:449-450) | ios | iOS | none (device lifecycle only) | |
| IOS-014 | `simulator ensure`, `build install` | `GRANTIVA_SESSION_ID=cov-ios` across commands | One durable owner; `sessions` shows one owner (README:399-408) | ios | iOS | none (device lifecycle only) | |
| IOS-015 | `simulator teardown` | `--session-id cov-ios-tmp --json` (a session made inside the row) | Deletes Grantiva-created sims, shuts down pre-existing ones it booted; `deleted` per session (README:404-407) | ios | iOS | none (device lifecycle only) | |
| IOS-016 (changed) | `simulator teardown` | `--udid <UDID> --force --json` after `kill -9` of a keep-alive run | Kills runner, WDA xcodebuild, `simctl diagnose`; `reclaimed: true`; named live records kept (`capacityRecordsKept`); device homes under every runner version removed (`deviceHomesRemoved`); exit 0 (README:430-447, 92) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-017 | `simulator teardown` | `--udid <free UDID> --force --json` | Exit 0, `reclaimed: false` (README:430-447) | ios | iOS | none (device lifecycle only) | |
| IOS-018 | `simulator cleanup` | one shut-down Grantiva-created sim, one in an active session, the user's devices | Deletes only the first; prunes missing devices from the ledger. Run only if `created.json` lists no device outside `cov-ios-*`; otherwise `blocked` (help: simulator_cleanup.txt) | ios | iOS | none (device lifecycle only) | |
| IOS-019 | `simulator delete` | `--name "cov-ios-4 Pin"`; then a missing name | Deletes; second is a clear error, non-zero (help: simulator_delete.txt) | ios | iOS | none (device lifecycle only) | |
| IOS-020 (changed) | `simulator teardown`, `sessions` | `cov-ios-3` booted with `xcrun simctl boot`, then a run on it, then `teardown --session-id` | Takes no slot; never shut down by teardown (README:450-453; brief I08) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-121 | `simulator teardown`, `simulator delete` | after a run on `cov-ios-3` | The device's home under `<runner home>/versions/*/devices/<udid>` is removed; teardown exits non-zero naming any home it could not remove (README:92) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-122 | `run` | `cov-ios-1` already booted, `GRANTIVA_SESSION_ID` unset | Takes no slot; without a session ID a run's slot lasts only while it runs (README:452-455) | ios | iOS | .maestro/01-browse.yaml | |

**build**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-021 | `build build` | `--scheme "Landmarks (UI Testing)" --simulator <UDID>` | Builds, exit 0 (README:311) | ios | iOS | none (build only) | |
| IOS-022 | `build install` | same | Builds, installs, launches (README:312) | ios | iOS | none (build only) | |
| IOS-023 | `build install` | `--no-launch --json` | JSON `status`, `scheme`, `bundleId`, `appPath`, `dataContainerPath`, `simulator.name`, `simulator.udid`; app not running (README:252-253) | ios | iOS | none (build only) | |
| IOS-024 | `build install` | `--derived-data-path "/private/tmp/.../cov ios/Derived Data"`, and a relative path | Products land there; spaces and relative paths work (README:256-259) | ios | iOS | none (build only) | |
| IOS-025 | `build build` | `build_settings: ["-derivedDataPath", "x"]` + `--derived-data-path y` | Flag wins; other settings kept (README:258-259) | ios | iOS | none (build only) | |
| IOS-026 | `build build` | `--scheme NoSuchScheme` | Clear scheme error, non-zero (help: build_build.txt) | ios | iOS | none (build only) | |
| IOS-027 (changed) | `build build` | no scheme configured, project has two schemes | Non-zero, "No scheme specified" listing `Found: Landmarks, Landmarks (UI Testing)` (or a stderr warning naming the chosen one) (brief I13) | ios | iOS | none (build only) | |
| IOS-028 | `build install` | `--simulator cov-ios-1` (name) vs UDID | Same simulator; destination `id=<UDID>` (help: build_install.txt) | ios | iOS | none (build only) | |
| IOS-123 | `build build` | `--bundle-id com.kylebrowning.Landmarks` | Accepted (iOS option) and used (help: build_build.txt) | ios | iOS | none (build only) | |
| IOS-124 | README fixture example | README:234-250 as written with `--scheme "Landmarks (UI Testing)"`, `$UDID` = cov-ios-1, flow `.maestro/01-browse.yaml` for `.grantiva/flows/seeded-state.yaml` | Install JSON parses with `jq -r .dataContainerPath`; the `run --no-build ... --simulator --bundle-id` passes (README:230-261) | ios | iOS | .maestro/01-browse.yaml | |

**run: suite, flows, ready file, env**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-029 | `run` | configured flows | Runs all; per-step pass/fail; exit 0 only when all pass (help: run.txt) | ios | iOS | grantiva.yml flows | |
| IOS-030 (changed) | `run --flow` | each stock flow, one at a time | Each of 01-12 passes; 99-crash fails (help: run.txt; README:98) | ios | iOS | .maestro/01-browse.yaml ... 99-crash.yaml | |
| IOS-031 | `run` | `flows: []`, no screens, `--report-dir out --ready-file out.ready` | Fails before boot/build; no success report; ready `failed` (README:85) | ios | iOS | none (fails before device) | |
| IOS-032 | `run` | stale `x.ready` | Deleted at startup; rewritten once with the run's status (README:77-85) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-033 | `run` | `--ready-file /nonexistent-cov/sub/x.ready` | Fails before build or boot, non-zero (README:85-87) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-034 (changed) | `run` | `--ready-file /private/tmp/.../cov-missing/x.ready` | Directory created; verdict written there (README:87) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-035 | `run` | `--env 'LANDMARKS_NOTE=a=b c'` | Deep Links shows `a=b c` (check `hierarchy` under `--keep-alive`, or the last `--snapshot full` shot) (help: run.txt `--env`) | ios | iOS | NEW:22-show-note | |
| IOS-036 | `run` | `--env LANDMARKS_NOTE=hello` | `hello` under the Deep Links title (README:90) | ios | iOS | NEW:22-show-note | |
| IOS-037 | `run` | `--env LANDMARKS_SEED=many --env LANDMARKS_NOTE=x` | Both reach the app: the flow passes (Landmark 70 reached) and the note `x` is in `hierarchy` on Deep Links (run with `--keep-alive`) (help: run.txt "Repeatable") | ios | iOS | NEW:08-scroll | |
| IOS-038 | `run` | `--env LANDMARKS_SEED=empty` | `No landmarks yet` (help: run.txt) | ios | iOS | .maestro/09-seed-empty.yaml | |
| IOS-039 | `run` | `--env LANDMARKS_CRASH_ON_LAUNCH=1 --ready-file r` | Fails, exit non-zero, failure screenshot, ready `failed` (help: run.txt) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-040 | `run` | `--app-file Landmarks.app` | Skips build, installs; bundle ID from Info.plist; no scheme needed (README:226) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-041 | `run` | flow 12 (`Mount "Denali"`) | Tap succeeds, detail opens (README:172) | ios | iOS | .maestro/12-quote-label.yaml | |
| IOS-042 | `run` | `--app-file Landmarks.ipa` | Extracts, validates, installs, runs (README:213-226) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-043 | `run` | `--app-file` of an iphoneos build | Rejected as not a simulator build (README:226) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-044 (changed) | `run --no-build` | app installed; then after `simctl uninstall` | First passes; second fails before the runner with `com.kylebrowning.Landmarks is not installed on cov-ios-1. Drop --no-build or run grantiva build install.` (brief I15) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-045 | `run` | `tapOn: "Mountains → Yosemite Valley"` | Tap succeeds, label unmangled (README:172) | ios | iOS | NEW:01-selectors | |
| IOS-125 | `run --flow` | no config, no `--bundle-id`, flow `appId:` header | Uses the flow's `appId` (README:174; brief C10) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-126 | `run --flow` | `--bundle-id com.kylebrowning.Landmarks` with config `bundle_id`, flow appId `${APP_ID}` | Order: flag > config > `--app-file` > flow appId (ignored for `${VAR}`) > detection (README:174) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-127 | `run` | header `env:` + step `environment:`; then `--env` | Step wins over header; `--env` wins over both (README:176) | ios | iOS | NEW:11-launch-environment, NEW:12-env-precedence-cli | |
| IOS-128 | `run --derived-data-path` | `run` and `diff capture` with `--derived-data-path` | Products land there (README:258 "available on every Grantiva command that builds") | ios | iOS | .maestro/01-browse.yaml | |

**run: keep-alive, hierarchy**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-047 | `run --keep-alive` | `--flow <flow>` | Session held after flows; app frozen; exits only on Ctrl-C (README:76) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-048 | `hierarchy` | during keep-alive | XML on stdout, app not relaunched (docs/dump-hierarchy.md:29) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-049 | `hierarchy` | `--format json` | Valid JSON (docs/dump-hierarchy.md:30) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-050 (changed) | `hierarchy` | `--json` | JSON, as `--format json` (docs/dump-hierarchy.md:38; brief D01) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-051 | `hierarchy` | `--udid <UDID>` | That simulator's tree via `<pid>.owner.json` (docs/dump-hierarchy.md:36) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-052 | `hierarchy` | two keep-alive sessions (cov-ios-1, cov-ios-2), no `--udid` | Newest session (README:91) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-053 | `hierarchy` | two sessions, `--udid` of the older | Older session's tree (docs/dump-hierarchy.md:36) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-054 | `hierarchy` | after `kill -9` of the keep-alive run | Dead session ignored; fails fast if none (docs/dump-hierarchy.md:21) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-055 (changed) | `hierarchy` | `--timeout 0.01` | One line, e.g. `Error: GrantivaAgent on port <p> did not answer within 0.01s (--timeout). Is the run still alive?` (brief I15) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-056 | `run --keep-alive --ready-file r`, `hierarchy` | `hierarchy` as soon as `r` exists | No race (docs/dump-hierarchy.md:23) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-057 | `run --keep-alive`, Ctrl-C | none | Runner, WDA, `simctl diagnose` reaped; session and owner files removed; lease released (README:76) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-058 (changed) | `run --keep-alive &`, `kill -INT <pid>` | `--ready-file r` | Same cleanup as Ctrl-C; `r` has `interrupted`, no flow `running` (README:76, 89; brief A06) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-059 (changed) | `run` | two concurrent runs, cov-ios-1 and cov-ios-2 | Both exit 0; distinct WDA ports and sessions; per-UDID homes (README:92; brief I01) | ios | iOS | .maestro/01-browse.yaml, .maestro/05-category.yaml | |
| IOS-060 | `run` | second run on a UDID owned by a live run | Fails immediately with "already owned by another Grantiva run", owner pid and the freeing command (README:92) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-129 | README agent example | README:70 `run --flow ... --keep-alive --logs`, README:73 `hierarchy > state.xml` | Both as written (flow path substituted); `state.xml` non-empty XML (README:68-74) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-130 | README ready-file loop | README:80-82 as written (flow substituted) | Loop ends; `jq -r .status` prints `passed` (README:79-83) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-131 | docs/dump-hierarchy.md examples | :13, :16, :18 | Run as written; XML and JSON files non-empty (docs/dump-hierarchy.md:11-19) | ios | iOS | .maestro/01-browse.yaml | |

**run: logs, snapshot, report, timeout, json**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-061 (changed) | `run --logs` | default predicate | `[log]` app lines (hundreds for flow 08), no `getpwuid_r`/"Filtering the log data" banners (README:93; brief I07) | ios | iOS | .maestro/08-caching.yaml | |
| IOS-062 | `run` | `--logs-predicate 'subsystem == "com.kylebrowning.Landmarks"'` | Implies `--logs`; only matching lines (README:94) | ios | iOS | .maestro/08-caching.yaml | |
| IOS-063 | `run` | `--logs --logs-level debug`, then `info`, then `default` | Passed to `log stream --level`; debug >= info >= default line counts (help: run.txt) | ios | iOS | .maestro/08-caching.yaml | |
| IOS-064 | `run --logs` | success, failure, Ctrl-C | No orphan `log stream` (help: run.txt) | ios | iOS | .maestro/08-caching.yaml, .maestro/99-crash.yaml | |
| IOS-065 | `run` | `--snapshot failure` (default) | One screenshot after the failing step (README:95) | ios | iOS | NEW:02-exact-negative | |
| IOS-066 | `run` | `--snapshot trailing` | Last-good plus failing step (README:95) | ios | iOS | NEW:02-exact-negative | |
| IOS-067 | `run` | `--snapshot full` | A screenshot per step (README:95) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-068 | `run` | `--continue-on-failure`, crash flow first | Remaining flows run; exit non-zero (README:96) | ios | iOS | .maestro/99-crash.yaml + grantiva.yml flows | |
| IOS-069 | `run` | crash flow first, no flag | Suite stops after the first broken flow (README:96) | ios | iOS | .maestro/99-crash.yaml + grantiva.yml flows | |
| IOS-070 | `run` | `--report-dir out` (relative) | `out/report.json`, assets, screenshots; no `./.grantiva/captures` (README:99) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-071 (changed) | `run` | `--report-dir out`, failing flow | No `/var/folders` path in `out/`; `sourceFile` and junit `file` are the paths as passed (README:99; brief I11) | ios | iOS | NEW:02-exact-negative | |
| IOS-072 | `run` | two flows named `same.yaml` in different dirs | Each runs once (README:99) | ios | iOS | NEW:14-runflow (copied to a/ and b/ as same.yaml) | |
| IOS-073 (changed) | `run` | `--timeout 30 --ready-file r` | Killed with SIGTERM at about 30 s; ready `failed`, no flow `running`; message ends without a stray colon (README:89, 97; brief A06; obs) | ios | iOS | NEW:18-long-wait | |
| IOS-074 (changed) | `run --json` | failing flow; passing flow | stdout only JSON; failing: `"allPassed": false`, failed step and message, `error`, `reportDir` with `--report-dir`; exit 1 (README:383-386; brief I12) | ios | iOS | NEW:02-exact-negative, .maestro/01-browse.yaml | |
| IOS-075 | `run` | `- stopApp` before any launch | Does not fail (README:172) | ios | iOS | NEW:10-lifecycle | |
| IOS-076 | `run` | `launchApp: {clearState: true}` | Works without `--app-file` (README:172) | ios | iOS | NEW:10-lifecycle | |
| IOS-077 | `run` | `launchApp: {arguments: {"--flag": true}}` | App receives `--flag` (README:172) | ios | iOS | NEW:10-lifecycle | |
| IOS-078 (changed) | `run` | `assertVisible: {text: "Lake", exact: true}` vs `Lake Tahoe` | Fails; without `exact` the regex `Lake` also fails (whole-value match) and `.*Lake.*` passes (README:143-146) | ios | iOS | NEW:02-exact-negative, NEW:01-selectors | |
| IOS-132 | `run` screens | `--snapshot full` with screens config | Applies to screens too (README:95) | ios | iOS | grantiva.yml screens | |
| IOS-133 | `run` screens+flows | `--report-dir out` with screens and flows | Screens report under `out/screens/` (README:99) | ios | iOS | grantiva.yml screens + flows | |
| IOS-134 | `run` screens | `--continue-on-failure` with a failing screen | Failed screens session reported; configured flows still run (README:99) | ios | iOS | NEW:cfg/screens-fail | |
| IOS-135 | `run` screens | `--timeout 30` with a screen that waits 45 s | Killed at about 30 s (README:99; brief R03, C04) | ios | iOS | NEW:cfg/screens-slow | |

**record**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-079 | `record` | `--simulator <UDID> --duration 3` | `.grantiva/recordings/recording.mov`; exit 0 (help: record.txt) | ios | iOS | none (records the idle app) | |
| IOS-080 | `record` | `--output "/private/tmp/.../cov rec/a.mov"` | Written there (help: record.txt) | ios | iOS | none (records the idle app) | |
| IOS-081 | `record` | `--frames-at 0,150,300,2900` | Four PNGs (README:340) | ios | iOS | none (records the idle app) | |
| IOS-082 | `record` | `--duration 2 --frames-at 5000` | Clear error for a timestamp past the duration (help: record.txt) | ios | iOS | none (records the idle app) | |
| IOS-083 (changed) | `record --json` | `--duration 3 --frames-at 0,1000` | Valid JSON with video path, per-frame `requestedMilliseconds`/`actualMilliseconds`, `simulator`/`udid` (README:340-341) | ios | iOS | none (records the idle app) | |
| IOS-136 | `record` | `--frames-at 500,1500` while flow 10 scrolls in another shell | `actualMilliseconds` near 500 and 1500, not `0` (brief A05 iOS note) | ios | iOS | .maestro/10-seed-many.yaml | |
| IOS-137 | `record` | `2>/dev/null` | stdout starts with `Recording:`; no recorder noise (brief C13) | ios | iOS | none (records the idle app) | |

**runner start / stop / dump-hierarchy**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-084 | `runner start` | `--bundle-id com.kylebrowning.Landmarks --simulator <UDID> --detach` | Prints the log path; `.grantiva/session.json`; lease kept (help: runner_start.txt) | ios | iOS | none (session only) | |
| IOS-085 | `runner dump-hierarchy` | `--format tree`, `json`, `xml`; `-f`, `-p <port>` | Each format prints (docs/dump-hierarchy.md:51) | ios | iOS | none (session only) | |
| IOS-086 | `runner dump-hierarchy` | no runner start, live keep-alive run, `--udid` | Falls back to the keep-alive session (docs/dump-hierarchy.md:57) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-087 | `runner stop` | after `runner start` | Kills runner, removes owner sidecar, releases the lease (help: runner_stop.txt) | ios | iOS | none (session only) | |
| IOS-088 | `runner start` | stale `.grantiva/session.json` (dead pid) | New session starts cleanly (docs/dump-hierarchy.md:21) | ios | iOS | none (session only) | |
| IOS-089 | `runner start`, then `run` | same simulator | `run` fails fast as owned; session intact (README:92) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-138 | `runner start --json`, `runner stop --json` | none | Each prints a JSON result (README:367-369) | ios | iOS | none (session only) | |
| IOS-139 | `runner start` | foreground (no `--detach`), then Ctrl-C | Holds until Ctrl-C; then same cleanup as `runner stop` (help: runner_start.txt) | ios | iOS | none (session only) | |
| IOS-140 | docs/dump-hierarchy.md alternative | :46-48 as written | start, `dump-hierarchy --format json`, stop all succeed (docs/dump-hierarchy.md:43-49) | ios | iOS | none (session only) | |

**diff (local)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-090 (changed) | `diff capture --no-build` | config `simulator: cov-ios-1`, cov-ios-2 also booted | `Device: cov-ios-1`; cov-ios-2 untouched; files `Deep Links.png` (plain names) (README:262-265; brief I02, I16) | ios | iOS | grantiva.yml screens | |
| IOS-091 | `diff compare` | no baselines | Each screen new/missing baseline, not a pass (README:466) | ios | iOS | grantiva.yml screens | |
| IOS-092 | `diff approve` | after capture | Baselines in `.grantiva/baselines/` (README:472) | ios | iOS | grantiva.yml screens | |
| IOS-093 | `diff compare` | unchanged UI | All pass (README:466) | ios | iOS | grantiva.yml screens | |
| IOS-094 (changed) | `diff compare` | screen with a pixel change; `threshold` raised alone, then both raised | Fails on `perceptual_threshold` when only `threshold` is raised; passes when both are (README:123-128) | ios | iOS | NEW:cfg/screens-steps (Caching screen clock) | |
| IOS-095 | `diff compare` | `perceptual_threshold: 5.0` vs a subtle colour change | Below passes, above fails (README:126) | ios | iOS | NEW:cfg/screens-steps | |
| IOS-096 | `diff compare --json` | none | Valid JSON with per-screen pixel and perceptual metrics (help: diff_compare.txt) | ios | iOS | grantiva.yml screens | |
| IOS-097 | `diff compare --capture` | none | Captures then compares (help: diff_compare.txt) | ios | iOS | grantiva.yml screens | |
| IOS-098 | `diff approve Home` | one name | Only Home replaced (help: diff_approve.txt) | ios | iOS | grantiva.yml screens | |
| IOS-141 | `diff capture` | `NEW:cfg/screens-steps` (every path step) | Every step executes; captures per screen (README:132-149) | ios | iOS | NEW:cfg/screens-steps | |
| IOS-142 | `diff capture` | Maestro-format grantiva.yml | One capture per `takeScreenshot` (README:158-172) | ios | iOS | NEW:cfg/maestro-format | |
| IOS-143 | `diff capture --no-build` | no `--simulator`, no config `simulator:`, live `runner start` session on cov-ios-1 | Uses the session's device (README:262-264) | ios | iOS | grantiva.yml screens | |
| IOS-144 | `diff capture --no-build` | no simulator configured, no session, cov-ios-1 and cov-ios-2 booted (plus the user's device) | Fails and names the booted simulators rather than guessing; commands none of them (README:264-265) | ios | iOS | grantiva.yml screens | |
| IOS-145 | README local workflow | README:463-469 as written | capture, compare, approve succeed (README:459-472) | ios | iOS | grantiva.yml screens | |
| IOS-146 | `diff capture` after a failure | capture succeeds, then a failing capture, then `diff compare` | compare non-zero, says captures missing or stale (brief I03) | ios | iOS | NEW:cfg/screens-fail | |

**README device examples, alerts, sessions**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-147 | README ensure example | README:379 and README:414-415 (name `cov-ios-3 iPhone 17`, flow substituted) | `udid` captured; the run passes (README:378-416) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-148 | README session example | README:404-407 with `GRANTIVA_SESSION_ID=cov-ios-tmp`, name `cov-ios-3 iPhone 17` | ensure then teardown; device gone (README:403-408) | ios | iOS | none (device lifecycle only) | |
| IOS-149 | README reclaim example | README:438 after a `kill -9`'d run | Reclaims as IOS-016 (README:432-447) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-150 | app alerts | flow 04 x10 | 10/10 pass: the app's "Discard Changes?" alert left for the flow (README:156; brief I04) | ios | iOS | .maestro/04-discard.yaml | |
| IOS-151 | system alerts | Maps flow | System location prompt auto-accepted (`accepted system alert ...` in the runner log); flow passes (README:156) | ios | iOS | NEW:21-system-alert-maps | |

## Android slice

AVD `cov-android` (API 35, serial recorded at boot); `GRANTIVA_SESSION_ID=cov-android`; the scratch copy of
landmarks-demo/android has `emulator: cov-android` in `grantiva-android.yml` (the stock file names `Pixel_8_API_35`,
which no row may touch); variant `freeDebug`, application ID `com.kylebrowning.landmarks`. `cov-android-2` exists only
inside a row. Shell preamble per the plan's Global Constraints.

**Stock set**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-106 | `run --no-build` | stock set | 12/12 pass incl. 02-favorite (swipe reveals Remove) and 03-edit (append), exit 0 (brief R01, R02; plan Task 5 Step 1) | android | Android | .maestro/01-browse.yaml ... 12-quote-label.yaml | |
| AND-107 | `run --flow` | `.maestro/99-crash.yaml` | Fails fast at `launchApp` with `crashed on launch: java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH`; record time to failure (brief R01 criterion 3) | android | Android | .maestro/99-crash.yaml | |
| AND-108 | `diff capture` | five configured screens | 5/5; Lakes and Detail are the right screens (docs/android.md:68-76) | android | Android | grantiva-android.yml screens | |

**emulator subcommand**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-001 | `emulator ensure` | `--name cov-android` (AVD missing, image installed) | Creates (`avdmanager create avd -d pixel_8`), boots, prints only the serial (docs/android.md:166, 173-175) | android | Android | none (device lifecycle only) | |
| AND-002 | `emulator ensure` | `--name cov-android-2 --system-image <an image not installed>` | Installs it with `sdkmanager`, then creates and boots; `blocked` if no small uninstalled image is available (docs/android.md:173) | android | Android | none (device lifecycle only) | |
| AND-003 | `emulator ensure` | same name again | Reuses; same serial (help: emulator_ensure.txt) | android | Android | none (device lifecycle only) | |
| AND-004 | `emulator ensure` | `--name cov-android-2 --no-boot` | Created, not booted; stdout is the AVD name (docs/android.md:167) | android | Android | none (device lifecycle only) | |
| AND-005 | `emulator ensure` | `--headless` | No window (`-no-window`) (help: emulator_ensure.txt) | android | Android | none (device lifecycle only) | |
| AND-006 | `emulator ensure` | no `--name`, config `emulator: cov-android` | Uses the configured AVD (help: emulator_ensure.txt) | android | Android | none (device lifecycle only) | |
| AND-007 | `emulator ensure` | no `--system-image`, no config value | `system-images;android-35;google_apis;arm64-v8a` (docs/android.md:174-175) | android | Android | none (device lifecycle only) | |
| AND-008 | `emulator ensure --json` | none | Valid JSON record (help: emulator_ensure.txt) | android | Android | none (device lifecycle only) | |
| AND-009 | `emulator sessions` | `--json` | Lists the emulators Grantiva started (docs/android.md:168) | android | Android | none (device lifecycle only) | |
| AND-010 | `emulator teardown` | `--serial <cov-android-2 serial>` | Stops UIAutomator2, removes that serial's forwards, kills it (help: emulator_teardown.txt) | android | Android | none (device lifecycle only) | |
| AND-011 | `emulator teardown` | serial of `cov-android-2` booted with `emulator -avd` by hand; then `--force` | Refuses without `--force`; kills with it (docs/android.md:169) | android | Android | none (device lifecycle only) | |
| AND-012 | `emulator teardown --all` | none | Kills every emulator Grantiva started, leaves others. `blocked`: Global Constraints forbid `teardown --all` (docs/android.md:170) | android | Android | none (device lifecycle only) | |
| AND-013 (changed) | `emulator teardown` | ledger record whose pid is dead or reused | Record dropped by `sessions`/`teardown`; teardown refuses that serial without `--force`, whatever AVD runs there (docs/android.md:176-183; brief C02) | android | Android | none (device lifecycle only) | |
| AND-014 | `emulator delete` | `--name cov-android-2` (Grantiva-created, stopped) | Deleted (help: emulator_delete.txt) | android | Android | none (device lifecycle only) | |
| AND-015 (changed) | `emulator delete` | `--name cov-android-2` created with `avdmanager` by hand | Refuses without `--force`; deletes with it (docs/android.md:171) | android | Android | none (device lifecycle only) | |
| AND-016 | `emulator delete` | `--name <running AVD> --force` | Refuses: a running AVD is never deleted (help: emulator_delete.txt) | android | Android | none (device lifecycle only) | |
| AND-017 | `emulator ensure` | `GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS=5`, cold boot of cov-android-2 | Gives up after about 5 s with a clear error (docs/android.md:100) | android | Android | none (device lifecycle only) | |
| AND-018 (changed) | `emulator ensure`, `run` | emulator started outside Grantiva | Never recorded in `started.json`; never killed by run cleanup (docs/android.md:176-183; brief C02) | android | Android | .maestro/01-browse.yaml | |
| AND-109 | `emulator sessions`, `ensure`, `delete`, `teardown` | `avdmanager delete avd -n cov-android-2` after `ensure` created it | `created-avds.json` drops the name on the next call (docs/android.md:184-186) | android | Android | none (device lifecycle only) | |
| AND-110 | docs/android.md emulator examples | :166-171 with `cov-android` for `Pixel_8_API_35` and the started serial | Each as written behaves as its comment says; `--all` line `blocked` (docs/android.md:164-171) | android | Android | none (device lifecycle only) | |

**build and target selection**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-019 | `build build` | default from config | `assembleFreeDebug`; exit 0 (docs/android.md:22) | android | Android | none (build only) | |
| AND-020 | `build install` | default | Builds, installs, launches (help: build_install.txt) | android | Android | none (build only) | |
| AND-021 (changed) | `build install --no-launch --json` | none | JSON `status`, `applicationId`, `appPath`, `device.name`, `device.serial`; app not running (README:254-255) | android | Android | none (build only) | |
| AND-022 | `build build` | `--variant freeRelease` | Runs `assembleFreeRelease`; unsigned-release behaviour reported clearly (help: build_build.txt) | android | Android | none (build only) | |
| AND-023 | `build build` | `--variant paidDebug` | `assemblePaidDebug` (docs/android.md:22) | android | Android | none (build only) | |
| AND-024 (changed) | `build build` | `--variant noSuchVariant` | Text and `--json` `errors` include Gradle's What-went-wrong block ("Cannot locate tasks that match ..."); non-zero (brief A09) | android | Android | none (build only) | |
| AND-025 (changed) | `build build` | `--module app`; `--module nosuch` | First builds; second shows Gradle's reason (brief A09) | android | Android | none (build only) | |
| AND-111 | `build build` | no `--device`, config `emulator: cov-android` shut down | Compiles only; boots nothing; `adb devices` unchanged (docs/android.md:40-41; obs build-build boot) | android | Android | none (build only) | |
| AND-112 | `build build` | `--device emulator-5999` (not attached) | Fails naming the attached devices (docs/android.md:42-43) | android | Android | none (build only) | |
| AND-113 | `build install` | cov-android shut down | Boots it and logs `Booting AVD cov-android as <serial>` (docs/android.md:44-45) | android | Android | none (build only) | |
| AND-026 (changed) | `run` | built variant, config `application_id` differs (`.paid`) | The app's own ID (output metadata) is tested; a warning names both IDs (docs/android.md:47-50; brief A03) | android | Android | .maestro/01-browse.yaml | |
| AND-027 (changed) | `run` | `--application-id com.kylebrowning.landmarks.debug` | Overrides the test target with a warning that it disagrees with the app; APK installed under its own ID (docs/android.md:51-52) | android | Android | .maestro/01-browse.yaml | |
| AND-028 (changed) | `run` | `--app-file app-free-debug.apk` | Skips the build; ID read with `apkanalyzer` (docs/android.md:48) | android | Android | .maestro/01-browse.yaml | |
| AND-029 | `run` | `--emulator cov-android` (not running) | Boots it, then runs (docs/android.md:33) | android | Android | .maestro/01-browse.yaml | |
| AND-030 | `run` | `--device <serial>` | Targets that serial (docs/android.md:36-37) | android | Android | .maestro/01-browse.yaml | |
| AND-031 | `run` | `flows: []`, no screens, `--report-dir out --ready-file out.ready` | Fails before boot/build; ready `failed` (README:85) | android | Android | none (fails before device) | |
| AND-032 | `run` | `--headless --emulator cov-android` | Boots without a window (docs/android.md:38) | android | Android | .maestro/01-browse.yaml | |
| AND-033 | `run` | `--ready-file /nonexistent-cov/sub/x.ready` | Fails before Gradle or boot (README:85-87) | android | Android | .maestro/01-browse.yaml | |
| AND-034 | `run` | stale `x.ready` | Deleted at startup; rewritten (README:85) | android | Android | .maestro/01-browse.yaml | |
| AND-035 (changed) | `run` | `--env 'LANDMARKS_NOTE=a=b c'` | Delivered as an intent extra; Deep Links shows `a=b c`; logcat `extras=[LANDMARKS_NOTE=a=b c]` (docs/android.md:59-66; brief A01) | android | Android | NEW:22-show-note | |
| AND-036 | `run` | no `emulator:`, exactly one emulator running | Uses it (docs/android.md:34) | android | Android | .maestro/01-browse.yaml | |
| AND-037 (changed) | `run` | `--env LANDMARKS_NOTE=hello` | `hello` under Deep Links (docs/android.md:61-65) | android | Android | NEW:22-show-note | |
| AND-038 (changed) | `run` | `--env LANDMARKS_SEED=many --env LANDMARKS_NOTE=x` | Both reach the app (help: run.txt "Repeatable") | android | Android | NEW:08-scroll | |
| AND-039 (changed) | `run` | `--env LANDMARKS_SEED=empty`; and header `env:` (flow 09) without `--env` | `No landmarks yet` both ways (docs/android.md:61-62; brief A01) | android | Android | .maestro/09-seed-empty.yaml | |
| AND-040 (changed) | `run` | `--env LANDMARKS_CRASH_ON_LAUNCH=1 --ready-file r` | Fails at launchApp with the crash, non-zero, failure screenshot, ready `failed` (brief A01) | android | Android | .maestro/01-browse.yaml | |
| AND-041 | `run` | flow 12 | `Mount "Denali"` tap succeeds (README:172) | android | Android | .maestro/12-quote-label.yaml | |
| AND-042 (changed) | `run` | configured flows | 12/12 pass; exit 0 (help: run.txt; brief R01) | android | Android | grantiva-android.yml flows | |
| AND-043 | `run --flow` | each stock flow | Only that flow runs; 01-12 pass (help: run.txt) | android | Android | .maestro/01-browse.yaml ... 12-quote-label.yaml | |
| AND-044 | `run` | `tapOn: "Mountains → Yosemite Valley"` | Tap succeeds (README:172) | android | Android | NEW:01-selectors | |
| AND-045 | `run --no-build` | APK installed | No Gradle (help: run.txt) | android | Android | .maestro/01-browse.yaml | |
| AND-046 | `run` | `--continue-on-failure`, crash flow first | Remaining flows run; non-zero (README:96) | android | Android | .maestro/99-crash.yaml + grantiva-android.yml flows | |
| AND-047 | `run` | `--snapshot failure`, `trailing`, `full` | One after failure; last-good + failure; every step (README:95) | android | Android | NEW:02-exact-negative, .maestro/01-browse.yaml | |
| AND-048 | `run` | `--report-dir out` | `out/report.json` etc.; `.grantiva/captures` untouched (README:99) | android | Android | .maestro/01-browse.yaml | |
| AND-049 (changed) | `run` | `--timeout 30 --ready-file r` | Killed at about 30 s; ready `failed`, no `running` flow; no stray colon after the kill message (README:89, 97; obs) | android | Android | NEW:18-long-wait | |
| AND-050 | `run --json` | passing and failing flow | stdout valid JSON only; failing as IOS-074 (README:383-386) | android | Android | .maestro/01-browse.yaml, NEW:02-exact-negative | |
| AND-114 | `run` | no `emulator:` in config, no emulator running | Fails and lists the AVDs; boots nothing (docs/android.md:34-36) | android | Android | .maestro/01-browse.yaml | |
| AND-115 | `run` | no `emulator:`, cov-android still booting | Waits for it and runs (docs/android.md:35) | android | Android | .maestro/01-browse.yaml | |
| AND-116 | `run` | `launchApp` with both `arguments:` and `environment:` | Merged into the intent extras (docs/android.md:61-64) | android | Android | NEW:13-android-arguments-merge | |
| AND-117 | `run` | header `env:` + step `environment:`; then `--env` | Step wins over header; `--env` wins over both (docs/android.md:65-66) | android | Android | NEW:11-launch-environment, NEW:12-env-precedence-cli | |
| AND-118 | `run` | narration with no device configured or passed | `Resolved: ... device=` and `Booting emulator:` never print an empty serial (obs; #186) | android | Android | .maestro/01-browse.yaml | |
| AND-119 | `run` screens | `--continue-on-failure` failing screen; `--timeout 30` slow screen | As IOS-134 and IOS-135 (README:99) | android | Android | NEW:cfg/screens-fail, NEW:cfg/screens-slow | |
| AND-120 | `run` screens+flows | `--report-dir out`, `--snapshot full` | Screens report under `out/screens/`; snapshot applies (README:95, 99) | android | Android | grantiva-android.yml screens + flows | |
| AND-121 | `run --flow` | runner-only command `back` | Passes through to the runner and executes (README:172 "not limited to this list") | android | Android | NEW:17-back | |

**keep-alive and hierarchy**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-051 | `run --keep-alive` | `--flow <flow>` | Holds the UIAutomator2 session until Ctrl-C (docs/android.md:104) | android | Android | .maestro/01-browse.yaml | |
| AND-052 | `hierarchy` | two sessions (cov-android, cov-android-2), no `--udid` | Newest (README:91) | android | Android | .maestro/01-browse.yaml | |
| AND-053 | `hierarchy` | default | UIAutomator2 page source XML; app untouched (docs/android.md:105) | android | Android | .maestro/01-browse.yaml | |
| AND-054 | `hierarchy` | `--format json` | Same tree as JSON, frames in dp (docs/android.md:106) | android | Android | .maestro/01-browse.yaml | |
| AND-055 (changed) | `hierarchy` | `--json` | JSON (docs/dump-hierarchy.md:38; brief D01) | android | Android | .maestro/01-browse.yaml | |
| AND-056 | `hierarchy` | `--udid <serial>` with two sessions | That serial's session (docs/android.md:110-111) | android | Android | .maestro/01-browse.yaml | |
| AND-057 | `hierarchy` | `adb forward --list` before/after | A local port to 6790 only for the command (docs/android.md:108-110) | android | Android | .maestro/01-browse.yaml | |
| AND-058 | `hierarchy` | after `kill -9` of the run | Dead session ignored; fails fast (docs/dump-hierarchy.md:21) | android | Android | .maestro/01-browse.yaml | |
| AND-059 (changed) | `run --keep-alive`, Ctrl-C | passing flow | Session, owner sidecar, UIAutomator2 server and forwards cleaned; demo mode and animation scales restored; no `failure-<ts>.png` written (obs; #186) | android | Android | .maestro/01-browse.yaml | |
| AND-060 (changed) | `run --keep-alive &`, `kill -INT` | `--ready-file r` | Same cleanup; `r` says `interrupted`, no flow `running` (README:76, 89; brief A06) | android | Android | .maestro/01-browse.yaml | |
| AND-061 | `run --keep-alive --ready-file r`, `hierarchy` | as soon as `r` exists | No race (docs/dump-hierarchy.md:23) | android | Android | .maestro/01-browse.yaml | |
| AND-062 | `run` | two concurrent runs, cov-android and cov-android-2 | Both pass without interfering (README:92) | android | Android | .maestro/01-browse.yaml, .maestro/05-category.yaml | |
| AND-063 (changed) | `run` | second run on a serial owned by a live run | Fails fast: `Emulator <serial> ...` naming the owner; suggests `grantiva emulator teardown --serial <serial> --force` / `grantiva emulator ensure --name <unique-name>`; no ` exited with code 1`; no failure screenshot (brief A10) | android | Android | .maestro/01-browse.yaml | |
| AND-064 | `run` | orphan forwards for another serial | Cleanup removes only this serial's forwards (docs/android.md:137) | android | Android | .maestro/01-browse.yaml | |
| AND-122 | docs/android.md keep-alive examples | :104-106 as written | Each prints as its comment says (docs/android.md:102-111) | android | Android | .maestro/01-browse.yaml | |

**demo mode and settings**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-065 | `run`, `diff capture` | default | Demo mode (09:41, full battery, no notifications), animation scales 0, portrait (docs/android.md:78-79) | android | Android | grantiva-android.yml screens | |
| AND-066 | `run` | during run | Previous values in `.grantiva/android-settings-<serial>.json` (docs/android.md:79-80) | android | Android | .maestro/11-slow.yaml | |
| AND-067 | `run` | after normal exit | Restored (docs/android.md:80) | android | Android | .maestro/01-browse.yaml | |
| AND-068 | `run` | `kill -9` mid-run, then another run | Next run restores them first (docs/android.md:80-81) | android | Android | .maestro/11-slow.yaml | |
| AND-069 | `run` | `--device <physical serial>` | `n/a`: no physical device (spec §Out of scope) (docs/android.md:37-38) | android | Android | .maestro/01-browse.yaml | |
| AND-070 | `run` | `--device <physical serial> --allow-device-settings` | `n/a`: no physical device (spec §Out of scope) (docs/android.md:37-38) | android | Android | .maestro/01-browse.yaml | |

**logs**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-071 | `run --logs` | none | `[log]` logcat lines from the app's uid (docs/android.md:85) | android | Android | .maestro/08-caching.yaml | |
| AND-072 | `run` | `--logs-tag Landmarks` | Implies `--logs`; only that tag (docs/android.md:86) | android | Android | .maestro/08-caching.yaml | |
| AND-073 (changed) | `run` | `--logs` with no level, `default`, `info`, `debug` | logcat `*:I`, `*:I`, `*:I`, `*:D`; default and info give the same set, debug adds D (docs/android.md:87-95; brief A08) | android | Android | .maestro/08-caching.yaml | |
| AND-074 | `run` | `--logs-predicate x` | Rejected by name (docs/android.md:95) | android | Android | none (fails before device) | |
| AND-075 (changed) | `run --logs` | exit by success, failure, Ctrl-C (exit 130) | No `adb ... logcat` process remains (brief A07) | android | Android | .maestro/08-caching.yaml, .maestro/99-crash.yaml | |
| AND-123 | `run --logs` | lines logged before the run | Not shown: starts at the device's current time; buffer not cleared (docs/android.md:85-86; brief A08) | android | Android | .maestro/08-caching.yaml | |

**record**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-076 (changed) | `record` | `--duration 5 --frames-at 0,1000,3000` on a static screen | Exit 0; `.grantiva/recordings/recording.mp4` of about 5 s; three PNGs; `actualMilliseconds` the held frame (docs/android.md:115-121; brief A05) | android | Android | none (records the idle app) | |
| AND-077 | `record` | `--duration 181` | Refused before recording (docs/android.md:118) | android | Android | none (records the idle app) | |
| AND-078 | `record` | `--device <serial>`; `--emulator cov-android` | Each targets that; config `emulator` default (docs/android.md:124-125) | android | Android | none (records the idle app) | |
| AND-079 (changed) | `record --json` | `--output "/private/tmp/.../cov rec/a.mp4"` | Written there; JSON names `emulator` and `serial` (plus `simulator`/`udid` with the same values) (docs/android.md:125-127) | android | Android | none (records the idle app) | |
| AND-124 | `record` | static screen, `--duration 4` | stderr note that most of the recording was held (docs/android.md:121-123; README:342-344) | android | Android | none (records the idle app) | |
| AND-125 | docs/android.md record example | :115 as written | Video plus three PNGs (docs/android.md:115-118) | android | Android | none (records the idle app) | |

**runner start / stop**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-080 | `runner start --detach` | none | Boots emulator if needed, holds UIAutomator2, port in `.grantiva/session.json` (docs/android.md:131, 136) | android | Android | none (session only) | |
| AND-081 | `runner dump-hierarchy` | `--format tree`, `json`, `xml` | Same tree in each (docs/android.md:111) | android | Android | none (session only) | |
| AND-082 | `runner stop` | after start | Kills runner, stops UIAutomator2, removes the serial's forwards (docs/android.md:136-137) | android | Android | none (session only) | |
| AND-083 | `runner start` | `--application-id x.y --emulator cov-android` | Flags win over config (help: runner_start.txt) | android | Android | none (session only) | |
| AND-084 | `runner start` | stale session.json (dead pid) | Starts cleanly (docs/dump-hierarchy.md:21) | android | Android | none (session only) | |
| AND-126 | `runner start --json`, `stop --json`; `--device <serial>`; `--headless` | none | JSON results; flags honoured (README:367-369; help: runner_start.txt) | android | Android | none (session only) | |
| AND-127 | docs/android.md session example | :131-134 as written (mcp: send tools/list) | Each step works (docs/android.md:129-134) | android | Android | none (session only) | |

**diff and baselines**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-085 (changed) | `diff capture` | first capture | `.grantiva/captures/android/`; prints `Emulator: cov-android (<serial>)`; `--json` has an `emulator` object next to `simulator` (docs/android.md:70-76) | android | Android | grantiva-android.yml screens | |
| AND-086 | `diff approve` | after capture | `.grantiva/baselines/android/`; iOS paths untouched (docs/android.md:70-71) | android | Android | grantiva-android.yml screens | |
| AND-087 | `diff compare` | unchanged; changed pixel; `--json` | Pass; fail per both thresholds; valid JSON (README:123-128) | android | Android | grantiva-android.yml screens | |
| AND-088 | `diff compare` | logged in | `blocked`: no credentials in the campaign (spec §Out of scope) (docs/android.md:71-73) | android | Android | grantiva-android.yml screens | |
| AND-089 | `ci run` | Android project | Refuses with the local-only message (docs/android.md:71-73) | android | Android | none (fails before device) | |
| AND-128 | `diff capture` | `NEW:cfg/screens-steps` and Maestro-format config | Every step executes; a capture per screen (README:132-172) | android | Android | NEW:cfg/screens-steps, NEW:cfg/maestro-format | |

**doctor**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-090 | `doctor --platform android` | toolchain present, cov-android running | SDK, adb, emulator, JDK, AVDs pass; exit 0 (docs/android.md:13) | android | Android | none (host checks) | |
| AND-091 | `doctor --platform android` | `ANDROID_HOME` unset | Falls back (docs/android-environment.md:15-16) | android | Android | none (host checks) | |
| AND-092 | `doctor --platform android --json` | `JAVA_HOME=/nonexistent` | JDK check fails; non-zero; JSON valid (README:330) | android | Android | none (host checks) | |

## Flow-command rows

Every Maestro-format command and selector form README:143-146 and README:172 list, once per platform (iOS rows are
repeated on 27.0 in Task 4 Step 2). Hooks H1/H2 are specified in the demo-flows doc.

**iOS**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-201 | `run --flow` tapOn (string) | `tapOn: "Golden Gate Bridge"` | Taps; detail opens (README:172) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-202 | `run --flow` tapOn {text:} | `tapOn: {text: "Lake Tahoe"}` | Taps the element whose text matches (README:172) | ios | iOS | NEW:01-selectors | |
| IOS-203 | `run --flow` tapOn {id:} | `tapOn: {id: "clock"}`, `assertVisible: {id: "clock"}` on Caching Demo | Matches the accessibility identifier (iOS) / resource id (Android), not text (README:172; docs/mcp.md:88; brief C08) | ios | iOS | NEW:01-selectors | |
| IOS-204 | `run --flow` selector regex | `tapOn: "Golden Gate.*"`; `assertVisible: ".*Lake.*"` | Case-insensitive regex over the whole text: matches; `assertVisible: "Lake"` alone does not match `Lake Tahoe` (README:143-145) | ios | iOS | NEW:01-selectors | |
| IOS-205 | `run --flow` selector exact | `tapOn: {text: "Lake Tahoe", exact: true}` | Taps the element whose text equals the label as written; no `"exact" is not supported` warning (README:145-146; obs exact on Android) | ios | iOS | NEW:01-selectors | |
| IOS-206 | `run --flow` selector exact (negative) | `assertVisible: {text: "Lake", exact: true}` on Lakes | Step fails `Element not visible` naming `Lake`; run exit 1 (README:145-146) | ios | iOS | NEW:02-exact-negative | |
| IOS-207 | `run --flow` selector index | `tapOn: {text: "(Lake .*\|.* Lake)", index: 1}` on Lakes | Taps the second match (Mono Lake); `assertNotVisible: "Lake Tahoe"` on its detail passes (Maestro selector `index`; plan Task 1 Step 3) | ios | iOS | NEW:01-selectors | |
| IOS-208 | `run --flow` tapOn point % | `tapOn: {point: "50%,50%"}` on Gesture Lab; hook H1 | Lands at the screen centre: `Last tap: center`, `Taps: 1` (plan Task 1 Step 3) | ios | iOS | NEW:04-point-taps | |
| IOS-209 | `run --flow` tapOn point 100% | `tapOn: {point: "100%,100%"}`, `{point: "0%,0%"}`; hook H1 | Step passes (no out-of-bounds error); lands on screen (plan N11) | ios | iOS | NEW:04-point-taps | |
| IOS-210 | `run --flow` doubleTapOn | `doubleTapOn: {id: "gesture-pad"}`; hook H1 | `Double taps: 1`, `Taps: 0` (README:172) | ios | iOS | NEW:03-gesture-lab-taps | |
| IOS-211 | `run --flow` longPressOn | `longPressOn: {id: "gesture-pad"}`; hook H1 | `Long presses: 1` (README:172) | ios | iOS | NEW:03-gesture-lab-taps | |
| IOS-212 | `run --flow` inputText append | flow 03: `tapOn: "Name"`, `inputText: " Renamed"` | `Golden Gate Bridge Renamed` visible; no `warning` in report.json (README:172; brief R01) | ios | iOS | .maestro/03-edit.yaml | |
| IOS-213 | `run --flow` inputText unicode | `inputText: "Pier 39 · Ünïcødé ✓"` into Location | Text appears unmangled (README:172) | ios | iOS | NEW:15-input-unicode | |
| IOS-214 | `run --flow` assertVisible | string, `{text:}`, regex, `{id:}` | Each passes on a visible element (README:172) | ios | iOS | .maestro/01-browse.yaml, NEW:01-selectors | |
| IOS-215 | `run --flow` assertNotVisible | `assertNotVisible: "Golden Gate Bridge"` on Lakes | Passes (README:172) | ios | iOS | .maestro/05-category.yaml | |
| IOS-216 | `run --flow` swipe direction | `swipe: {direction: LEFT/RIGHT/UP/DOWN}` on Gesture Lab; hook H1 | `Last swipe: left/right/up/down` after each (README:172) | ios | iOS | NEW:05-swipe-forms | |
| IOS-217 | `run --flow` swipe from: element | flow 02 `swipe: {direction: LEFT, from: "Lake Tahoe"}` | Row opens; `Remove` tapped; empty state (README:172; brief A02, R02) | ios | iOS | .maestro/02-favorite.yaml | |
| IOS-218 | `run --flow` swipe from: {id} | `swipe: {direction: UP, from: {id: "gesture-pad"}}`; hook H1 | `Last swipe: up` (README:172) | ios | iOS | NEW:05-swipe-forms | |
| IOS-219 | `run --flow` swipe from: missing (negative) | `swipe: {direction: LEFT, from: "No Such Row"}` | Fails at the swipe: `Element not found for swipe`, exit 1 (brief R02 criterion 3) | ios | iOS | NEW:07-swipe-from-missing | |
| IOS-220 | `run --flow` swipe start/end % | `swipe: {start: "80%, 50%", end: "20%, 50%"}`; hook H1 | `Last swipe: left` (README:172) | ios | iOS | NEW:05-swipe-forms | |
| IOS-221 | `run --flow` swipe start/end absolute | `swipe: {start: "300, 600", end: "60, 600"}`; hook H1 | Read as pixels (Android) / points (iOS), on screen: `Last swipe: left`; never `✓` for an off-screen gesture (brief R02 criterion 4) | ios | iOS | NEW:06-swipe-absolute | |
| IOS-222 | `run --flow` swipe duration | `swipe: {direction: LEFT, duration: 1500}`; hook H1 | Slow swipe still registers `Last swipe: left`; takes about 1.5 s (README:172) | ios | iOS | NEW:05-swipe-forms | |
| IOS-223 | `run --flow` scroll | bare `scroll` x4 with seed many | Scrolls down; `Landmark 30` visible (README:172; brief C10; plan N03) | ios | iOS | .maestro/10-seed-many.yaml | |
| IOS-224 | `run --flow` scrollUntilVisible | `scrollUntilVisible: {element: "Landmark 70", direction: DOWN}`, then `{element: "Golden Gate Bridge", direction: UP}` | Both found (README:172) | ios | iOS | NEW:08-scroll | |
| IOS-225 | `run --flow` runFlow file | `runFlow: 14-runflow-sub.yaml`, `runFlow: {file: 14-runflow-sub.yaml}` | Sub-flow steps run each time (README:172) | ios | iOS | NEW:14-runflow | |
| IOS-226 | `run --flow` runFlow inline | `runFlow: {commands: [...]}` | Inline commands run (README:172 `runFlow`) | ios | iOS | NEW:14-runflow | |
| IOS-227 | `run --flow` extendedWaitUntil visible | flow 11 | `Loaded after delay` within 10 s (README:172) | ios | iOS | .maestro/11-slow.yaml | |
| IOS-228 | `run --flow` extendedWaitUntil notVisible | `extendedWaitUntil: {notVisible: "Loading…", timeout: 10000}` | Passes once loading ends (README:172) | ios | iOS | NEW:09-waits | |
| IOS-229 | `run --flow` waitForAnimationToEnd | bare and `{timeout: 2000}` | Both pass (README:172; brief C07) | ios | iOS | NEW:09-waits | |
| IOS-230 | `run --flow` launchApp | bare | Launches (README:172) | ios | iOS | .maestro/01-browse.yaml | |
| IOS-231 | `run --flow` launchApp clearState | `launchApp: {clearState: true}` | Fresh state; works without `--app-file` (README:172) | ios | iOS | NEW:10-lifecycle | |
| IOS-232 | `run --flow` launchApp environment | `launchApp: {environment: {LANDMARKS_NOTE: "from step"}}` | Note shown on Deep Links (README:176; docs/android.md:61-63) | ios | iOS | NEW:11-launch-environment | |
| IOS-233 | `run --flow` stopApp | `stopApp` before launch and after | Idempotent; app stopped (README:172) | ios | iOS | NEW:10-lifecycle | |
| IOS-234 | `run --flow` killApp | `killApp` then `launchApp` | App killed and relaunched (README:172) | ios | iOS | NEW:10-lifecycle | |
| IOS-235 | `run --flow` takeScreenshot | `takeScreenshot: "Deep Link Lakes"` (space in name) | PNG written with the plain name (README:172; brief I16) | ios | iOS | .maestro/07-deeplink.yaml | |
| IOS-236 | `run --flow` header env | flow header `env:` (flow 09) | Defines `${VAR}` and reaches the app at launch (README:176) | ios | iOS | .maestro/09-seed-empty.yaml | |
| IOS-237 | `run --flow` setPermissions (runner) | `setPermissions` with the header appId; bare `scroll` | Passes through to the runner and succeeds (README:172 last sentence; brief C10) | ios | iOS | NEW:16-setpermissions | |
| IOS-238 | `run --flow` launchApp arguments | `launchApp: {arguments: {"--flag": true}}` | App receives `--flag` (README:172) | ios | iOS | NEW:10-lifecycle | |
| IOS-239 | `run --flow` system alert | Maps location prompt | Auto-accepted by the runner (README:156) | ios | iOS | NEW:21-system-alert-maps | |

**Android**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-201 | `run --flow` tapOn (string) | `tapOn: "Golden Gate Bridge"` | Taps; detail opens (README:172) | android | Android | .maestro/01-browse.yaml | |
| AND-202 | `run --flow` tapOn {text:} | `tapOn: {text: "Lake Tahoe"}` | Taps the element whose text matches (README:172) | android | Android | NEW:01-selectors | |
| AND-203 | `run --flow` tapOn {id:} | `tapOn: {id: "clock"}`, `assertVisible: {id: "clock"}` on Caching Demo; android needs hook H2 (testTag as resource id) | Matches the accessibility identifier (iOS) / resource id (Android), not text (README:172; docs/mcp.md:88; brief C08) | android | Android | NEW:01-selectors | |
| AND-204 | `run --flow` selector regex | `tapOn: "Golden Gate.*"`; `assertVisible: ".*Lake.*"` | Case-insensitive regex over the whole text: matches; `assertVisible: "Lake"` alone does not match `Lake Tahoe` (README:143-145) | android | Android | NEW:01-selectors | |
| AND-205 | `run --flow` selector exact | `tapOn: {text: "Lake Tahoe", exact: true}` | Taps the element whose text equals the label as written; no `"exact" is not supported` warning (README:145-146; obs exact on Android) | android | Android | NEW:01-selectors | |
| AND-206 | `run --flow` selector exact (negative) | `assertVisible: {text: "Lake", exact: true}` on Lakes | Step fails `Element not visible` naming `Lake`; run exit 1 (README:145-146) | android | Android | NEW:02-exact-negative | |
| AND-207 | `run --flow` selector index | `tapOn: {text: "(Lake .*\|.* Lake)", index: 1}` on Lakes | Taps the second match (Mono Lake); `assertNotVisible: "Lake Tahoe"` on its detail passes (Maestro selector `index`; plan Task 1 Step 3) | android | Android | NEW:01-selectors | |
| AND-208 | `run --flow` tapOn point % | `tapOn: {point: "50%,50%"}` on Gesture Lab; hook H1 | Lands at the screen centre: `Last tap: center`, `Taps: 1` (plan Task 1 Step 3) | android | Android | NEW:04-point-taps | |
| AND-209 | `run --flow` tapOn point 100% | `tapOn: {point: "100%,100%"}`, `{point: "0%,0%"}`; hook H1 | Step passes (no out-of-bounds error); lands on screen (plan N11) | android | Android | NEW:04-point-taps | |
| AND-210 | `run --flow` doubleTapOn | `doubleTapOn: {id: "gesture-pad"}`; hook H1 | `Double taps: 1`, `Taps: 0` (README:172) | android | Android | NEW:03-gesture-lab-taps | |
| AND-211 | `run --flow` longPressOn | `longPressOn: {id: "gesture-pad"}`; hook H1 | `Long presses: 1` (README:172) | android | Android | NEW:03-gesture-lab-taps | |
| AND-212 | `run --flow` inputText append | flow 03: `tapOn: "Name"`, `inputText: " Renamed"` | `Golden Gate Bridge Renamed` visible; no `warning` in report.json (README:172; brief R01) | android | Android | .maestro/03-edit.yaml | |
| AND-213 | `run --flow` inputText unicode | `inputText: "Pier 39 · Ünïcødé ✓"` into Location | Text appears unmangled (README:172) | android | Android | NEW:15-input-unicode | |
| AND-214 | `run --flow` assertVisible | string, `{text:}`, regex, `{id:}` | Each passes on a visible element (README:172) | android | Android | .maestro/01-browse.yaml, NEW:01-selectors | |
| AND-215 | `run --flow` assertNotVisible | `assertNotVisible: "Golden Gate Bridge"` on Lakes | Passes (README:172) | android | Android | .maestro/05-category.yaml | |
| AND-216 | `run --flow` swipe direction | `swipe: {direction: LEFT/RIGHT/UP/DOWN}` on Gesture Lab; hook H1 | `Last swipe: left/right/up/down` after each (README:172) | android | Android | NEW:05-swipe-forms | |
| AND-217 | `run --flow` swipe from: element | flow 02 `swipe: {direction: LEFT, from: "Lake Tahoe"}` | Row opens; `Remove` tapped; empty state (README:172; brief A02, R02) | android | Android | .maestro/02-favorite.yaml | |
| AND-218 | `run --flow` swipe from: {id} | `swipe: {direction: UP, from: {id: "gesture-pad"}}`; hook H1 | `Last swipe: up` (README:172) | android | Android | NEW:05-swipe-forms | |
| AND-219 | `run --flow` swipe from: missing (negative) | `swipe: {direction: LEFT, from: "No Such Row"}` | Fails at the swipe: `Element not found for swipe`, exit 1 (brief R02 criterion 3) | android | Android | NEW:07-swipe-from-missing | |
| AND-220 | `run --flow` swipe start/end % | `swipe: {start: "80%, 50%", end: "20%, 50%"}`; hook H1 | `Last swipe: left` (README:172) | android | Android | NEW:05-swipe-forms | |
| AND-221 | `run --flow` swipe start/end absolute | `swipe: {start: "300, 600", end: "60, 600"}`; hook H1 | Read as pixels (Android) / points (iOS), on screen: `Last swipe: left`; never `✓` for an off-screen gesture (brief R02 criterion 4) | android | Android | NEW:06-swipe-absolute | |
| AND-222 | `run --flow` swipe duration | `swipe: {direction: LEFT, duration: 1500}`; hook H1 | Slow swipe still registers `Last swipe: left`; takes about 1.5 s (README:172) | android | Android | NEW:05-swipe-forms | |
| AND-223 | `run --flow` scroll | bare `scroll` x4 with seed many | Scrolls down; `Landmark 30` visible (README:172; brief C10; plan N03) | android | Android | .maestro/10-seed-many.yaml | |
| AND-224 | `run --flow` scrollUntilVisible | `scrollUntilVisible: {element: "Landmark 70", direction: DOWN}`, then `{element: "Golden Gate Bridge", direction: UP}` | Both found (README:172) | android | Android | NEW:08-scroll | |
| AND-225 | `run --flow` runFlow file | `runFlow: 14-runflow-sub.yaml`, `runFlow: {file: 14-runflow-sub.yaml}` | Sub-flow steps run each time (README:172) | android | Android | NEW:14-runflow | |
| AND-226 | `run --flow` runFlow inline | `runFlow: {commands: [...]}` | Inline commands run (README:172 `runFlow`) | android | Android | NEW:14-runflow | |
| AND-227 | `run --flow` extendedWaitUntil visible | flow 11 | `Loaded after delay` within 10 s (README:172) | android | Android | .maestro/11-slow.yaml | |
| AND-228 | `run --flow` extendedWaitUntil notVisible | `extendedWaitUntil: {notVisible: "Loading…", timeout: 10000}` | Passes once loading ends (README:172) | android | Android | NEW:09-waits | |
| AND-229 | `run --flow` waitForAnimationToEnd | bare and `{timeout: 2000}` | Both pass (README:172; brief C07) | android | Android | NEW:09-waits | |
| AND-230 | `run --flow` launchApp | bare | Launches (README:172) | android | Android | .maestro/01-browse.yaml | |
| AND-231 | `run --flow` launchApp clearState | `launchApp: {clearState: true}` | Fresh state; works without `--app-file` (README:172) | android | Android | NEW:10-lifecycle | |
| AND-232 | `run --flow` launchApp environment | `launchApp: {environment: {LANDMARKS_NOTE: "from step"}}` | Note shown on Deep Links (README:176; docs/android.md:61-63) | android | Android | NEW:11-launch-environment | |
| AND-233 | `run --flow` stopApp | `stopApp` before launch and after | Idempotent; app stopped (README:172) | android | Android | NEW:10-lifecycle | |
| AND-234 | `run --flow` killApp | `killApp` then `launchApp` | App killed and relaunched (README:172) | android | Android | NEW:10-lifecycle | |
| AND-235 | `run --flow` takeScreenshot | `takeScreenshot: "Deep Link Lakes"` (space in name) | PNG written with the plain name (README:172; brief I16) | android | Android | .maestro/07-deeplink.yaml | |
| AND-236 | `run --flow` header env | flow header `env:` (flow 09) | Defines `${VAR}` and reaches the app at launch (README:176) | android | Android | .maestro/09-seed-empty.yaml | |
| AND-237 | `run --flow` setPermissions (runner) | `setPermissions` with the header appId; bare `scroll` | Passes through to the runner and succeeds (README:172 last sentence; brief C10) | android | Android | NEW:16-setpermissions | |
| AND-238 | `run --flow` launchApp arguments | `launchApp: {arguments: {LANDMARKS_SEED: empty}, environment: {LANDMARKS_NOTE: merged}}` | Both delivered as extras (docs/android.md:61-64) | android | Android | NEW:13-android-arguments-merge | |
| AND-239 | `run --flow` back | `back` from Caching Demo | Returns to Deep Links (README:172 last sentence) | android | Android | NEW:17-back | |

## MCP rows

Every tool in docs/mcp.md (22) against a live session per platform, without a session, and without a config file;
plus the error shape, N12 and N13 (N rows). The 2.0.1 MCP rows keep their IOS/AND IDs. Live-session rows start the
session from the scratch project directory (`runner start --detach`, or `run --keep-alive` with the named flow) and
the server with `--project-dir` set to that same directory spelling.

**2.0.1 MCP rows (iOS)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| IOS-099 (changed) | `mcp` tools/list | before and after `runner start` | 22 tools both times; required args: `grantiva_sim_ensure` name, `grantiva_swipe` direction, `grantiva_type` text, `grantiva_script` steps (docs/mcp.md:9) | ios | iOS | none (session only) | |
| IOS-100 | `mcp` stdout | any call | Only JSON-RPC on stdout; subprocesses do not consume stdin (docs/mcp.md:3) | ios | iOS | none (session only) | |
| IOS-101 (changed) | `grantiva_context` | live session on cov-ios-1, cov-ios-2 and the user's device also booted | `[Config]` `platform: ios`; `[Simulator]` udid = session udid (docs/mcp.md:64; brief C06) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| IOS-102 (changed) | `grantiva_tap` | `label: "Favorites"`; `label: "heart"`; `x`/`y` in points | Favorites tab tapped, Favorites tree returned; `heart` does not match the tab (label, not symbol name); points tap (docs/mcp.md:50; brief I05) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| IOS-103 | `grantiva_tap` | no `label`, no `x`/`y` | isError; server stays up (docs/mcp.md:21-22) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| IOS-104 (changed) | `grantiva_type` | `text: "Yosemite"` in the Name field (focused by the flow) | Field contains the text; tree returned (docs/mcp.md:52; brief I06) | ios | iOS | NEW:19-park-edit | |
| IOS-105 | `grantiva_swipe` | `up`; `sideways` | Swipes; validation isError (docs/mcp.md:51) | ios | iOS | NEW:20-park-deeplinks | |
| IOS-106 | `grantiva_screenshot` | default; `format: file` | Base64 PNG; file path returned (docs/mcp.md:49) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| IOS-107 (changed) | `grantiva_script` | `[{tap: "Favorites"}, {wait: 1}, {tap_xy: {x, y}}]` | In order; `tap_xy` in points (docs/mcp.md:55) | ios | iOS | NEW:20-park-deeplinks | |
| IOS-108 | resources | `grantiva://hierarchy`, `grantiva://screenshot` | JSON tree, base64 PNG (help: mcp.txt) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| IOS-109 | `grantiva_a11y_tree`, `grantiva_a11y_check` | Landmarks list | Tree; check flags missing labels, targets under 44 pt (docs/mcp.md:53-54) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| IOS-110 | `grantiva_sim_list/boot/ensure/delete` | ensure `{name: "cov-ios-3 iPhone 17"}` then delete | Only `name` for ensure; delete removes it (docs/mcp.md:70-73) | ios | iOS | none (device lifecycle only) | |
| IOS-111 | `grantiva_build`, `grantiva_run` | `scheme: "Landmarks (UI Testing)"` | `Product:` with the app path; run installs and launches (docs/mcp.md:61-62) | ios | iOS | none (build only) | |
| IOS-112 (changed) | `grantiva_test` | `scheme: "Landmarks (UI Testing)"` | isError including xcodebuild's reason (no test action) (brief I17) | ios | iOS | none (build only) | |
| IOS-113 (changed) | `grantiva_vrt_capture/compare/approve` | approve `screens: ["Home"]` | Equivalent to `diff capture --no-build --json`, `diff compare --json`, `diff approve Home --json`, run with the server's own executable (docs/mcp.md:88-90; brief C05) | ios | iOS | grantiva.yml screens | |
| IOS-114 | `grantiva_vrt_approve` | `screens: ["Home; touch /tmp/pwn"]` | Shell-quoted; no file created (docs/mcp.md:90) | ios | iOS | grantiva.yml screens | |
| IOS-115 | required-argument tools | `grantiva_sim_ensure {}`, `grantiva_type {}`, `grantiva_swipe {}`, `grantiva_script {}`, `grantiva_emulator_ensure {}`, unknown tool | Error result naming the missing argument or unknown tool; server answers the next request (docs/mcp.md:21-22) | ios | iOS | NEW:20-park-deeplinks | |
| IOS-116 | `mcp --platform ios` | both config files | Starts on iOS and drives the simulator (docs/mcp.md:5-6) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |

**2.0.1 MCP rows (Android)**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| AND-093 | `mcp` tools/list | only `grantiva-android.yml`, after `runner start` | Android; same 22 tools (docs/android.md:138-140) | android | Android | none (session only) | |
| AND-094 (changed) | `grantiva_context` | live session | `platform: android` under `[Config]`; `[Emulator]` = session serial; Android SDK (docs/mcp.md:64; brief C06) | android | Android | .maestro/01-browse.yaml (keep-alive) | |
| AND-095 | `grantiva_tap` | `x`/`y` in dp from `hierarchy --format json` | Hits the element (docs/android.md:141) | android | Android | NEW:20-park-deeplinks | |
| AND-096 | `grantiva_tap`, `grantiva_type`, `grantiva_swipe` | label tap, text entry, swipe up | Each acts and returns the tree (docs/mcp.md:50-52) | android | Android | NEW:19-park-edit | |
| AND-097 | `grantiva_screenshot` | default, `format: file` | Base64 PNG; file path (docs/mcp.md:49) | android | Android | .maestro/01-browse.yaml (keep-alive) | |
| AND-098 | `grantiva_script` | `tap_xy` in dp | Executes in dp (docs/mcp.md:55) | android | Android | NEW:20-park-deeplinks | |
| AND-099 (changed) | `grantiva_a11y_check` | Landmarks list, Deep Links | 48 dp minimum; no `missing_label` for Compose buttons labelled by merged text (docs/android.md:142-144; brief A11) | android | Android | .maestro/07-deeplink.yaml (keep-alive) | |
| AND-100 | `grantiva_emulator_list/boot/ensure/delete` | ensure `{name: "cov-android-2"}` then delete | Mirror the sim tools; ensure needs only `name` (docs/android.md:145) | android | Android | none (device lifecycle only) | |
| AND-101 | `grantiva_build`, `grantiva_run` | `module`, `variant`, `emulator: cov-android` | Accepted; `Product:` with the APK path (docs/mcp.md:61-62) | android | Android | none (build only) | |
| AND-102 | `grantiva_test` | any | Refused as iOS-only (docs/android.md:146) | android | Android | none (session only) | |
| AND-103 (changed) | `grantiva_vrt_capture/compare/approve` | Android | Use `.grantiva/captures/android/` and `baselines/android/` (docs/android.md:70-71; brief C05) | android | Android | grantiva-android.yml screens | |
| AND-104 | `mcp` | JSON-RPC while adb runs | Every request answered (docs/mcp.md:3) | android | Android | none (session only) | |
| AND-105 | `mcp --platform android` | both config files | Starts on Android (docs/mcp.md:5-6) | android | Android | .maestro/01-browse.yaml (keep-alive) | |

**Full tool grid**

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| MCP-001 | `grantiva_screenshot` | {}; then `{format: "file"}` (live session iOS: `runner start --detach` or `run --keep-alive` from the project dir) | base64 PNG image; `file` writes a PNG and returns its path (docs/mcp.md:49) | ios | iOS | NEW:20-park-deeplinks | |
| MCP-002 | `grantiva_screenshot` | {}; then `{format: "file"}` (live session Android) | base64 PNG image; `file` writes a PNG and returns its path (docs/mcp.md:49) | android | Android | NEW:20-park-deeplinks | |
| MCP-003 | `grantiva_screenshot` | no session, config present; `--platform ios` and `--platform android` | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-004 | `grantiva_screenshot` | no session, no config (empty dir) | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-005 | `grantiva_tap` | `{label: "Gesture Lab"}` from Deep Links; then `{x, y}` of the pad centre taken from `hierarchy --format json` (live session iOS: `runner start --detach` or `run --keep-alive` from the project dir) | label tap opens the screen and returns the updated tree; x/y in points (iOS) / dp (Android) increments `Taps: 1` (docs/mcp.md:50) | ios | iOS | NEW:20-park-deeplinks | |
| MCP-006 | `grantiva_tap` | `{label: "Gesture Lab"}` from Deep Links; then `{x, y}` of the pad centre taken from `hierarchy --format json` (live session Android) | label tap opens the screen and returns the updated tree; x/y in points (iOS) / dp (Android) increments `Taps: 1` (docs/mcp.md:50) | android | Android | NEW:20-park-deeplinks | |
| MCP-007 | `grantiva_tap` | no session, config present; `--platform ios` and `--platform android` | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-008 | `grantiva_tap` | no session, no config (empty dir) | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-009 | `grantiva_swipe` | `grantiva_tap {label: "Gesture Lab"}`, then `{direction: "left"}` on the pad; then `{direction: "sideways"}` (live session iOS: `runner start --detach` or `run --keep-alive` from the project dir) | `Last swipe: left` in the returned tree; `sideways` is an isError validation result (docs/mcp.md:51) | ios | iOS | NEW:20-park-deeplinks | |
| MCP-010 | `grantiva_swipe` | `grantiva_tap {label: "Gesture Lab"}`, then `{direction: "left"}` on the pad; then `{direction: "sideways"}` (live session Android) | `Last swipe: left` in the returned tree; `sideways` is an isError validation result (docs/mcp.md:51) | android | Android | NEW:20-park-deeplinks | |
| MCP-011 | `grantiva_swipe` | no session, config present; `--platform ios` and `--platform android` | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-012 | `grantiva_swipe` | no session, no config (empty dir) | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-013 | `grantiva_type` | `{text: " Renamed"}` with the Name field focused (live session iOS: `runner start --detach` or `run --keep-alive` from the project dir) | Field reads `Golden Gate Bridge Renamed` in the returned tree (appends) (docs/mcp.md:52; brief I06, R01) | ios | iOS | NEW:19-park-edit | |
| MCP-014 | `grantiva_type` | `{text: " Renamed"}` with the Name field focused (live session Android) | Field reads `Golden Gate Bridge Renamed` in the returned tree (appends) (docs/mcp.md:52; brief I06, R01) | android | Android | NEW:19-park-edit | |
| MCP-015 | `grantiva_type` | no session, config present; `--platform ios` and `--platform android` | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-016 | `grantiva_type` | no session, no config (empty dir) | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-017 | `grantiva_a11y_tree` | {} (live session iOS: `runner start --detach` or `run --keep-alive` from the project dir) | JSON tree of the current screen with labels, types, frames (docs/mcp.md:53) | ios | iOS | .maestro/01-browse.yaml | |
| MCP-018 | `grantiva_a11y_tree` | {} (live session Android) | JSON tree of the current screen with labels, types, frames (docs/mcp.md:53) | android | Android | .maestro/01-browse.yaml | |
| MCP-019 | `grantiva_a11y_tree` | no session, config present; `--platform ios` and `--platform android` | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-020 | `grantiva_a11y_tree` | no session, no config (empty dir) | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-021 | `grantiva_a11y_check` | {} on the Landmarks list and on Deep Links (live session iOS: `runner start --detach` or `run --keep-alive` from the project dir) | Flags missing labels and targets under 44 pt (iOS) / 48 dp (Android); Compose buttons labelled by merged text are not `missing_label` (docs/mcp.md:54; docs/android.md:142-144; brief A11) | ios | iOS | .maestro/01-browse.yaml | |
| MCP-022 | `grantiva_a11y_check` | {} on the Landmarks list and on Deep Links (live session Android) | Flags missing labels and targets under 44 pt (iOS) / 48 dp (Android); Compose buttons labelled by merged text are not `missing_label` (docs/mcp.md:54; docs/android.md:142-144; brief A11) | android | Android | .maestro/01-browse.yaml | |
| MCP-023 | `grantiva_a11y_check` | no session, config present; `--platform ios` and `--platform android` | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-024 | `grantiva_a11y_check` | no session, no config (empty dir) | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-025 | `grantiva_script` | `steps: [{tap: "Gesture Lab"}, {wait: 1}, {tap_xy: {x, y}}, {swipe: "up"}, {type: "x"}]`; then `steps: [{bogus: 1}, 5]` (live session iOS: `runner start --detach` or `run --keep-alive` from the project dir) | Runs in order, returns the final tree (`Taps: 1`, `Last swipe: up`); the invalid script runs nothing and is isError naming steps 1 and 2 (docs/mcp.md:55; brief C17) | ios | iOS | NEW:20-park-deeplinks | |
| MCP-026 | `grantiva_script` | `steps: [{tap: "Gesture Lab"}, {wait: 1}, {tap_xy: {x, y}}, {swipe: "up"}, {type: "x"}]`; then `steps: [{bogus: 1}, 5]` (live session Android) | Runs in order, returns the final tree (`Taps: 1`, `Last swipe: up`); the invalid script runs nothing and is isError naming steps 1 and 2 (docs/mcp.md:55; brief C17) | android | Android | NEW:20-park-deeplinks | |
| MCP-027 | `grantiva_script` | no session, config present; `--platform ios` and `--platform android` | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-028 | `grantiva_script` | no session, no config (empty dir) | isError (never a JSON-RPC error) naming `grantiva runner start` and `grantiva run --keep-alive`: `No active runner session at <dir>/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive` in <dir>.`; server keeps answering (docs/mcp.md:14-17, 21-22; src MCPServer.swift:188) | both | CLI | none | |
| MCP-029 | `grantiva_build` | {} with the landmarks config | success status, duration, warnings, errors; `Product:` line with the app path (docs/mcp.md:61-62) | ios | iOS | none (build only) | |
| MCP-030 | `grantiva_build` | {} with the landmarks config | success status, duration, warnings, errors on Android (`module`/`variant`/`emulator` honoured) (docs/mcp.md:61-62) | android | Android | none (build only) | |
| MCP-031 | `grantiva_build` | `{scheme: "Landmarks (UI Testing)"}` in a dir without config | The argument stands in for the file; success status, duration, warnings, errors (docs/mcp.md:26-27) | ios | iOS | none (build only) | |
| MCP-032 | `grantiva_build` | `{module: "app", variant: "freeDebug"}` in a copy without config | The argument stands in for the file (docs/mcp.md:26-27) | android | Android | none (build only) | |
| MCP-033 | `grantiva_build` | {} in an empty dir, `--platform ios` and `--platform android` | isError naming the file and where it was looked for: `grantiva.yml not found at <dir>/grantiva.yml. Create one with grantiva init.` (Android: `grantiva-android.yml ... grantiva init --platform android`) (docs/mcp.md:24-26; brief R04) | both | CLI | none | |
| MCP-034 | `grantiva_run` | {} with the landmarks config | builds, installs and launches the app; `Product:` line with the app path (docs/mcp.md:61-62) | ios | iOS | none (build only) | |
| MCP-035 | `grantiva_run` | {} with the landmarks config | builds, installs and launches the app on Android (`module`/`variant`/`emulator` honoured) (docs/mcp.md:61-62) | android | Android | none (build only) | |
| MCP-036 | `grantiva_run` | `{scheme: "Landmarks (UI Testing)"}` in a dir without config | The argument stands in for the file; builds, installs and launches the app (docs/mcp.md:26-27) | ios | iOS | none (build only) | |
| MCP-037 | `grantiva_run` | `{module: "app", variant: "freeDebug"}` in a copy without config | The argument stands in for the file (docs/mcp.md:26-27) | android | Android | none (build only) | |
| MCP-038 | `grantiva_run` | {} in an empty dir, `--platform ios` and `--platform android` | isError naming the file and where it was looked for: `grantiva.yml not found at <dir>/grantiva.yml. Create one with grantiva init.` (Android: `grantiva-android.yml ... grantiva init --platform android`) (docs/mcp.md:24-26; brief R04) | both | CLI | none | |
| MCP-039 | `grantiva_test` | {} with config | Runs xcodebuild test; the app has no test action, so isError text includes xcodebuild's reason (`... is not currently configured for the test action`) (docs/mcp.md:63; brief I17) | ios | iOS | none (build only) | |
| MCP-040 | `grantiva_test` | {} on an Android project | isError: iOS only (docs/mcp.md:63; docs/android.md:146) | android | Android | none (build only) | |
| MCP-041 | `grantiva_test` | {} in an empty dir | isError naming the file and where it was looked for: `grantiva.yml not found at <dir>/grantiva.yml. Create one with grantiva init.` (Android: `grantiva-android.yml ... grantiva init --platform android`) (docs/mcp.md:24-26; brief R04) | cli | CLI | none | |
| MCP-042 | `grantiva_context` | {} with a live session | `[Config]` with `platform: ios`; `[Simulator]` udid equals the session's; Xcode; session status (docs/mcp.md:34-35, 64; brief C06) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| MCP-043 | `grantiva_context` | {} with a live session | `platform: android`; `[Emulator]` names the session's serial; Android SDK (docs/mcp.md:64; brief C06) | android | Android | .maestro/01-browse.yaml (keep-alive) | |
| MCP-044 | `grantiva_context` | {} without a session | Reports the configured simulator (booted or not) and says there is no runner session; never an arbitrary booted device such as the user's iPhone 17 Pro (docs/mcp.md:34-35; brief C06) | ios | iOS | none (no session; configured device) | |
| MCP-045 | `grantiva_context` | {} without a session | Reports the configured emulator and no runner session (docs/android.md:160-162) | android | Android | none (no session; configured device) | |
| MCP-046 | `grantiva_context` | {} in an empty dir | Works (no isError); says no config (docs/mcp.md:14-15; brief R04 criterion 2) | both | CLI | none | |
| MCP-047 | `grantiva_sim_list` | `{filter: "booted"}`, `{filter: "all"}` with config | Lists name, UDID, state, runtime, availability (docs/mcp.md:70) | ios | iOS | none (device lifecycle only) | |
| MCP-048 | `grantiva_sim_list` | `{filter: "booted"}`, `{filter: "all"}` in an empty dir | Lists name, UDID, state, runtime, availability (docs/mcp.md:70); works without config (brief C11, R04 criterion 2) | ios | iOS | none (device lifecycle only) | |
| MCP-049 | `grantiva_sim_boot` | `{name: "cov-ios-3 iPhone 17"}` (created in the row) with config | Boots it and returns its info (docs/mcp.md:71) | ios | iOS | none (device lifecycle only) | |
| MCP-050 | `grantiva_sim_boot` | `{name: "cov-ios-3 iPhone 17"}` (created in the row) in an empty dir | Boots it and returns its info (docs/mcp.md:71); works without config (brief C11, R04 criterion 2) | ios | iOS | none (device lifecycle only) | |
| MCP-051 | `grantiva_sim_ensure` | `{name: "cov-ios-4 iPhone 17"}` only with config | Creates or reuses; only `name` required (docs/mcp.md:72) | ios | iOS | none (device lifecycle only) | |
| MCP-052 | `grantiva_sim_ensure` | `{name: "cov-ios-4 iPhone 17"}` only in an empty dir | Creates or reuses; only `name` required (docs/mcp.md:72); works without config (brief C11, R04 criterion 2) | ios | iOS | none (device lifecycle only) | |
| MCP-053 | `grantiva_sim_delete` | `{name: "cov-ios-4 iPhone 17"}` with config | Deletes exactly that device (docs/mcp.md:73) | ios | iOS | none (device lifecycle only) | |
| MCP-054 | `grantiva_sim_delete` | `{name: "cov-ios-4 iPhone 17"}` in an empty dir | Deletes exactly that device (docs/mcp.md:73); works without config (brief C11, R04 criterion 2) | ios | iOS | none (device lifecycle only) | |
| MCP-055 | `grantiva_emulator_list` | {} with config | AVDs with the serial of each running one (docs/mcp.md:79) | android | Android | none (device lifecycle only) | |
| MCP-056 | `grantiva_emulator_list` | {} in an empty dir | AVDs with the serial of each running one (docs/mcp.md:79); works without config (brief C11) | android | Android | none (device lifecycle only) | |
| MCP-057 | `grantiva_emulator_boot` | `{name: "cov-android"}`; then {} with config `emulator: cov-android` with config | Boots or reuses; defaults to config `emulator` (docs/mcp.md:80) | android | Android | none (device lifecycle only) | |
| MCP-058 | `grantiva_emulator_boot` | `{name: "cov-android"}`; then {} with config `emulator: cov-android` in an empty dir | Boots or reuses; defaults to config `emulator` (docs/mcp.md:80); works without config (brief C11) | android | Android | none (device lifecycle only) | |
| MCP-059 | `grantiva_emulator_ensure` | `{name: "cov-android-2"}` only with config | Creates when missing; only `name` required (docs/mcp.md:81) | android | Android | none (device lifecycle only) | |
| MCP-060 | `grantiva_emulator_ensure` | `{name: "cov-android-2"}` only in an empty dir | Creates when missing; only `name` required (docs/mcp.md:81); works without config (brief C11) | android | Android | none (device lifecycle only) | |
| MCP-061 | `grantiva_emulator_delete` | `{name: "cov-android-2"}`; then a hand-made AVD without and with `force` with config | Deletes Grantiva-created; refuses others without `force`; never a running AVD (docs/mcp.md:82) | android | Android | none (device lifecycle only) | |
| MCP-062 | `grantiva_emulator_delete` | `{name: "cov-android-2"}`; then a hand-made AVD without and with `force` in an empty dir | Deletes Grantiva-created; refuses others without `force`; never a running AVD (docs/mcp.md:82); works without config (brief C11) | android | Android | none (device lifecycle only) | |
| MCP-063 | `grantiva_vrt_capture` | {} with a live `runner start` session | Captures on the session's device without a second runner; relaunches the app; same JSON as `diff capture --json`; paths relative to the project (docs/mcp.md:88; plan N12) | ios | iOS | grantiva.yml screens | |
| MCP-064 | `grantiva_vrt_capture` | {} with a live session | As iOS; Android selectors: text/content-desc/hint, `id:` resource id whole or after `/` (docs/mcp.md:88) | android | Android | grantiva-android.yml screens | |
| MCP-065 | `grantiva_vrt_capture` | {} with no session, app installed | Equivalent to `diff capture --no-build --json`; config `simulator:` honoured (docs/mcp.md:88; brief I02) | ios | iOS | grantiva.yml screens | |
| MCP-066 | `grantiva_vrt_capture` | {} with no session | Equivalent to `diff capture --no-build --json` on Android (docs/mcp.md:88) | android | Android | grantiva-android.yml screens | |
| MCP-067 | `grantiva_vrt_capture` | {} in an empty dir; then a config without screens | isError naming the file and where it was looked for: `grantiva.yml not found at <dir>/grantiva.yml. Create one with grantiva init.` (Android: `grantiva-android.yml ... grantiva init --platform android`) (docs/mcp.md:24-26; brief R04); without screens: `No screens configured in grantiva.yml` | both | CLI | none | |
| MCP-068 | `grantiva_vrt_capture` | live session, config whose screens use `run_flow`, a swipe from an element, a swipe between points, or a swipe with a duration | Refused before anything runs, naming `grantiva runner stop` (docs/mcp.md:88) | ios | iOS | NEW:cfg/screens-steps | |
| MCP-069 | `grantiva_vrt_capture` | same as the previous row | Refused before anything runs (docs/mcp.md:88) | android | Android | NEW:cfg/screens-steps | |
| MCP-070 | `grantiva_vrt_compare` | after a capture | Per-screen pixel and perceptual metrics, as `diff compare --json` (docs/mcp.md:89) | ios | iOS | grantiva.yml screens | |
| MCP-071 | `grantiva_vrt_compare` | after a capture | Per-screen pixel and perceptual metrics, as `diff compare --json`; Android paths `captures/android`, `baselines/android` (docs/mcp.md:89; docs/android.md:70-71) | android | Android | grantiva-android.yml screens | |
| MCP-072 | `grantiva_vrt_compare` | empty dir, no captures | isError naming the missing config or captures, never a JSON-RPC error (docs/mcp.md:89; docs/mcp.md:21-22) | both | CLI | none | |
| MCP-073 | `grantiva_vrt_approve` | after a capture | `{screens: ["Home"]}` approves only Home; {} approves all, as `diff approve --json` (docs/mcp.md:90) | ios | iOS | grantiva.yml screens | |
| MCP-074 | `grantiva_vrt_approve` | after a capture | `{screens: ["Home"]}` approves only Home; {} approves all, as `diff approve --json`; Android paths `captures/android`, `baselines/android` (docs/mcp.md:90; docs/android.md:70-71) | android | Android | grantiva-android.yml screens | |
| MCP-075 | `grantiva_vrt_approve` | empty dir, no captures | isError naming the missing config or captures, never a JSON-RPC error (docs/mcp.md:90; docs/mcp.md:21-22) | both | CLI | none | |
| MCP-076 | `resources/read` | `grantiva://hierarchy`, `grantiva://screenshot` with a live session | JSON tree and base64 PNG (help: mcp.txt; tool registry) | both | iOS+Android | .maestro/01-browse.yaml (keep-alive) | |
| MCP-077 | `tools/call (error shape)` | unknown tool name; `grantiva_sim_ensure {}`; `grantiva_type {}`; `grantiva_swipe {}`; `grantiva_script {}`; `grantiva_emulator_ensure {}` | Each an isError result (or a JSON-RPC invalid-params error only for an unknown tool, if that is the documented shape) naming the problem; server answers the next request (docs/mcp.md:21-22) | both | CLI | none | |
| MCP-078 | `tools/call (error shape)` | every session tool against a session whose app was killed (`simctl terminate` / `am force-stop`) and against a missing label | isError (`Element not found: ...` for the label), never JSON-RPC error (docs/mcp.md:21-22; brief R05 criterion 2-3) | both | iOS+Android | NEW:20-park-deeplinks | |
| MCP-079 | `mcp session discovery` | keep-alive session started from another directory, and one for the other platform | Never used; session tools return the no-session isError (docs/mcp.md:30-34; brief C03) | both | iOS+Android | .maestro/01-browse.yaml (keep-alive) | |
| MCP-080 | `mcp session discovery` | server started first; then `runner start --detach`; then the session replaced by a new `runner start` | Session tools attach on the next call and re-attach after replacement (docs/mcp.md:16-18; brief C11) | both | iOS+Android | none (session only) | |
| MCP-081 | `mcp config pickup` | server started in an empty dir; then `grantiva.yml` written; call `grantiva_build` | The new config is read on the next call (docs/mcp.md:28) | ios | iOS | none (build only) | |
| MCP-082 | `mcp stdin` | JSON-RPC while `adb shell`/`simctl` subprocesses run | Every request answered; subprocesses never consume stdin (spec §Constraints; 2.0.1 IOS-100/AND-104) | both | iOS+Android | none (session only) | |

## Brief rows (B)

One row per acceptance criterion of the 67 original briefs and R01-R05, the criterion quoted as the expected text
(long criteria trimmed with …; the brief has the full text). Criteria that ask for unit tests are checked in the CLI
slice by locating the test in `Tests/` at 51c597a (no `swift build`); criteria that ask for a CHANGELOG entry are
checked against README/docs/release notes, since CHANGELOG.md was removed in #179. A criterion whose fix chose the
other allowed alternative passes when the chosen alternative holds.

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| B-A01.1 | brief A01 criterion 1 | per brief A01 Repro | Re-running the repro: logcat shows `extras=[LANDMARKS_NOTE=a=b c]` and qa-note passes; 09-seed-empty and 10-seed-many pass; 99-crash fails at `launchApp` with the app's `RuntimeException`. (brief A01) | android | Android | .maestro/09-seed-empty.yaml, .maestro/10-seed-many.yaml, .maestro/99-crash.yaml, NEW:11-launch-environment | |
| B-A01.2 | brief A01 criterion 2 | per brief A01 Repro | On Android, `--env` is delivered as string intent extras … Pick one and say which in CHANGELOG and docs/android.md. (brief A01) | cli | CLI | none (docs check (CHANGELOG.md was removed in #179; release notes, README or docs/ carry the note); docs/android.md:59-66) | |
| B-A01.3 | brief A01 criterion 3 | per brief A01 Repro | Decide flow-header `env:`: deliver it the same way or document that it is only for `${VAR}` substitution on Android. (brief A01) | android | Android | .maestro/09-seed-empty.yaml | |
| B-A01.4 | brief A01 criterion 4 | per brief A01 Repro | GrantivaCoreTests/FlowEnvironmentTests: an Android-platform injection into bare, scalar and mapping `launchApp` forms yields `arguments:` entries …; FlowGeneratorTests: same for the screens flow. (brief A01) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A02.1 | brief A02 criterion 1 | per brief A02 Repro | Re-running the repro: the runner log shows an element lookup for "Lake Tahoe" and a swipe starting inside its bounds; cmd-008-after.png shows the revealed swipe action. With `from: "No Such Row"` the step fails with "Element not found". (brief A02) | android | Android | .maestro/02-favorite.yaml, NEW:07-swipe-from-missing | |
| B-A02.2 | brief A02 criterion 2 | per brief A02 Repro | The bundled runner maps `from:` to the swipe selector (Maestro semantics: start at the element centre); bump the bundled runner and CHANGELOG. (brief A02) | both | iOS+Android | .maestro/02-favorite.yaml | |
| B-A02.3 | brief A02 criterion 3 | per brief A02 Repro | Runner test: parsing `swipe: {direction: LEFT, from: X}` yields a non-empty selector …; GrantivaCoreTests: … a MaestroFlowParser test that `from:` is kept. (brief A02) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A03.1 | brief A03 criterion 1 | per brief A03 Repro | Re-running the repro: either the run uses `com.kylebrowning.landmarks.paid` …, or it fails before installing with an error naming both IDs …. `--application-id` given explicitly may still override, but with a warning when it disagrees with the APK. (brief A03) | android | Android | .maestro/01-browse.yaml | |
| B-A03.2 | brief A03 criterion 2 | per brief A03 Repro | The same rule applies to `--variant` builds (output-metadata applicationId vs config) and to `build install`. (brief A03) | android | Android | .maestro/01-browse.yaml | |
| B-A03.3 | brief A03 criterion 3 | per brief A03 Repro | GrantivaCLITests/TargetOptionsTests: `resolveAndroid` with config `application_id` A and APK ID B yields B …; a RunCommandTests case covers the built-variant path. (brief A03) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A04.1 | brief A04 criterion 1 | per brief A04 Repro | Re-running the repro 10 times: Deep Links hash never equals Home's. (brief A04) | both | iOS+Android | grantiva.yml screens | |
| B-A04.2 | brief A04 criterion 2 | per brief A04 Repro | FlowGenerator emits a settle step … after every `tap`/`swipe`/`type` and before each `takeScreenshot` …. Note any added latency in CHANGELOG. (brief A04) | cli | CLI | none (README:148-150; docs check (CHANGELOG.md was removed in #179; release notes, README or docs/ carry the note)) | |
| B-A04.3 | brief A04 criterion 3 | per brief A04 Repro | GrantivaCoreTests/FlowGeneratorTests: a screen with `path: [tap: "X"]` generates a settle step between `tapOn` and `takeScreenshot`. (brief A04) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A05.1 | brief A05 criterion 1 | per brief A05 Repro | Re-running the repro: exit 0, a PNG at 1000 ms, `actualMilliseconds` reported as the frame actually shown (the held frame), and the mp4's duration is ~2 s. (brief A05) | android | Android | none (records the idle app) | |
| B-A05.2 | brief A05 criterion 2 | per brief A05 Repro | On iOS the current strict check is kept unless the same VFR behaviour applies. Note: iOS `record --frames-at 500,1500` also reported `-> 0ms` … (brief A05) | ios | iOS | .maestro/10-seed-many.yaml (recorded while it runs) | |
| B-A05.3 | brief A05 criterion 3 | per brief A05 Repro | GrantivaCLITests/RecordCommandTests: a fixture mp4 with one frame at 0 and requested duration 2 s returns a frame for 1000 ms …; `requestedMilliseconds` beyond the requested duration still throws. (brief A05) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A06.1 | brief A06 criterion 1 | per brief A06 Repro | Re-running the repro: the first ready file has `"status": "interrupted"` and no flow left `running`; a `--timeout` kill writes `failed` with no `running` flow; the second ready file has no `reportDir` key … unless `--report-dir` was given. (brief A06) | both | iOS+Android | NEW:18-long-wait, .maestro/01-browse.yaml | |
| B-A06.2 | brief A06 criterion 2 | per brief A06 Repro | Interruption is recorded before the group is terminated. (brief A06) | both | iOS+Android | NEW:18-long-wait | |
| B-A06.3 | brief A06 criterion 3 | per brief A06 Repro | GrantivaCoreTests/ReadyFileTests and RunnerExecutionTests: a simulated SIGINT during a running flow yields `interrupted`; RunnerSessionCleanupTests: an ephemeral report dir is not written to the ready file. (brief A06) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A07.1 | brief A07 criterion 1 | per brief A07 Repro | Re-running the repro: no `adb ... logcat` process remains after exit 130. (brief A07) | android | Android | .maestro/11-slow.yaml | |
| B-A07.2 | brief A07 criterion 2 | per brief A07 Repro | LogStreamer registers its own `SignalRelay.onTermination` cleanup on `start` (removed on `stop`), or its process is tracked as a group. (brief A07) | cli | CLI | none (source check: src LogStreamer) | |
| B-A07.3 | brief A07 criterion 3 | per brief A07 Repro | GrantivaCoreTests/LogStreamerTests (or SignalRelayTests): starting a streamer on a long-running dummy executable and firing the termination cleanups leaves the child dead. (brief A07) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A08.1 | brief A08 criterion 1 | per brief A08 Repro | Re-running the repro: no flag and `default` both give the same set …; `debug` adds D; `info` gives I and above; `warning` exits 64 naming the valid values. (brief A08) | android | Android | .maestro/08-caching.yaml | |
| B-A08.2 | brief A08 criterion 2 | per brief A08 Repro | `--logs-level` becomes a validated enum shared by iOS and Android, with an explicit Android mapping table … documented in docs/android.md. (brief A08) | cli | CLI | none (help: run.txt; docs/android.md:87-95) | |
| B-A08.3 | brief A08 criterion 3 | per brief A08 Repro | Drop `logcat -c`; start at the current time instead (`-T 1` or `-T '<now>'`). (brief A08) | android | Android | .maestro/08-caching.yaml | |
| B-A08.4 | brief A08 criterion 4 | per brief A08 Repro | GrantivaCoreTests/AndroidPlatformTests: `logStream(level:)` … never `logcat -c`; GrantivaCLITests/RunCommandTests: `--logs-level warning` fails validation. (brief A08) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A09.1 | brief A09 criterion 1 | per brief A09 Repro | Re-running the repro: text output and the `--json` `errors` array include the "Cannot locate tasks that match ':app:assembleNoSuchVariant'..." line (the whole What-went-wrong block, up to `* Try:`). (brief A09) | android | Android | none (build only) | |
| B-A09.2 | brief A09 criterion 2 | per brief A09 Repro | Ideally, for an unknown variant/module, also list the available ones. (brief A09) | android | Android | none (build only; record whether listed) | |
| B-A09.3 | brief A09 criterion 3 | per brief A09 Repro | GrantivaCoreTests/GradleBuildRunnerTests: parsing a captured Gradle failure log yields the What-went-wrong text in `errors`. (brief A09) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A10.1 | brief A10 criterion 1 | per brief A10 Repro | Re-running the repro on Android: the refusal says `Emulator emulator-5554 ...` and suggests `grantiva emulator teardown --serial emulator-5554 --force` / `grantiva emulator ensure --name <unique-name>`; no ` exited with code 1` suffix; no failure screenshot of a device the run never owned. (brief A10) | android | Android | .maestro/01-browse.yaml | |
| B-A10.2 | brief A10 criterion 2 | per brief A10 Repro | `build install --json` on Android emits `applicationId` and `device: {name, serial}` …. `run` narrates `Resolved: module=app variant=freeDebug device=emulator-5554 ...`; Android build failures print no `Scheme:` line. (brief A10) | android | Android | none (build only) | |
| B-A10.3 | brief A10 criterion 3 | per brief A10 Repro | `.commandFailed` gains a message-only form (or the suffix is only added for real subprocess names). (brief A10) | cli | CLI | none (source check: src GrantivaError.swift) | |
| B-A10.4 | brief A10 criterion 4 | per brief A10 Repro | Tests: SimulatorLeaseTests asserts the Android message names `grantiva emulator`; InstallCommandTests asserts the Android JSON keys; TableFormatterTests asserts no `Scheme:` for a failed Android build. (brief A10) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A11.1 | brief A11 criterion 1 | per brief A11 Repro | Re-running the repro: no `missing_label` on the Deep Links buttons; `small_tap_target` may stay. (brief A11) | android | Android | .maestro/07-deeplink.yaml (keep-alive) | |
| B-A11.2 | brief A11 criterion 2 | per brief A11 Repro | On Android, a widget-class node that is not clickable/focusable is skipped when a clickable ancestor carries a label …. (brief A11) | android | Android | .maestro/07-deeplink.yaml (keep-alive) | |
| B-A11.3 | brief A11 criterion 3 | per brief A11 Repro | A genuinely unlabelled clickable Button (no text anywhere in its focus group) is still flagged. (brief A11) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign): UIToolsTests ImageButton case) | |
| B-A11.4 | brief A11 criterion 4 | per brief A11 Repro | GrantivaMCPTests (new UIToolsTests): the Deep Links XML fragment above yields no `missing_label`; a clickable `android.widget.ImageButton` with empty `content-desc` and no descendants yields one. (brief A11) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A12.1 | brief A12 criterion 1 | per brief A12 Repro | Re-running the repro: `✓ Git Repository  Detected` (optionally showing the top-level path). (brief A12) | cli | CLI | none (doctor from android/ of a git work tree) | |
| B-A12.2 | brief A12 criterion 2 | per brief A12 Repro | The check walks up from the cwd for a `.git` entry (directory or file) or runs `git rev-parse --is-inside-work-tree`. (brief A12) | cli | CLI | none (doctor in a worktree, where `.git` is a file) | |
| B-A12.3 | brief A12 criterion 3 | per brief A12 Repro | GrantivaCoreTests/DoctorTests: a temp dir `root/.git/` with cwd `root/android` passes; a dir with no ancestor `.git` still warns. (brief A12) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-A13.1 | brief A13 criterion 1 | per brief A13 Repro | `tap:` (and `assert_visible`/`assert_not_visible`) accept a mapping form `{text: "Landmarks", exact: true}` that FlowGenerator emits as `tapOn: {text: ..., exact: true}` … (brief A13) | both | iOS+Android | NEW:cfg/screens-steps | |
| B-A13.2 | brief A13 criterion 2 | per brief A13 Repro | With either change, the stock landmarks `screens:` config captures Lakes and Detail on Android. (brief A13) | android | Android | grantiva-android.yml screens | |
| B-A13.3 | brief A13 criterion 3 | per brief A13 Repro | GrantivaCoreTests: GrantivaConfig decoding of the mapping form, and a FlowGeneratorTests case emitting `exact: true`. (brief A13) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C01.1 | brief C01 criterion 1 | per brief C01 Repro | Re-running the repro exits non-zero with a `GrantivaError` naming the missing resource bundle, no SIGTRAP, and leaves `~/.grantiva/runner` exactly as it was. (brief C01) | cli | CLI | none (binary copied to a scratch dir without its bundle; scratch GRANTIVA_RUNNER_HOME) | |
| B-C01.2 | brief C01 criterion 2 | per brief C01 Repro | With the bundle present, a re-extract replaces only the runner binary, `version` and `drivers/`; files in `locks/` and `reports/` and `grantiva-wda.xcconfig` keep their contents. (brief C01) | ios | iOS | .maestro/11-slow.yaml (lease held while `runner install` runs) | |
| B-C01.3 | brief C01 criterion 3 | per brief C01 Repro | GrantivaCoreTests/RunnerManagerTests: … the lock survives `installIfNeeded`, and … a throwing `extract` asserts the previous install is intact. (brief C01) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C01.4 | brief C01 criterion 4 | per brief C01 Repro | Resolve resources with `Bundle(url:)`/a lookup that returns nil instead of `Bundle.module`, so a missing bundle throws. (brief C01) | cli | CLI | none (covered by B-C01.1) | |
| B-C02.1 | brief C02 criterion 1 | per brief C02 Repro | Re-running the repro leaves no record for emulator-5554, and `emulator teardown --all` does not kill it. (brief C02) | android | Android | none (device lifecycle only; the `--all` half is blocked by Global Constraints) | |
| B-C02.2 | brief C02 criterion 2 | per brief C02 Repro | `choosePort` also skips ports whose console port is bound; the record is written only once the spawned pid is the process answering on the serial …. (brief C02) | android | Android | none (device lifecycle only) | |
| B-C02.3 | brief C02 criterion 3 | per brief C02 Repro | `teardown` refuses a record whose pid is dead without `--force`, regardless of AVD name. (brief C02) | android | Android | none (device lifecycle only) | |
| B-C02.4 | brief C02 criterion 4 | per brief C02 Repro | GrantivaCoreTests/EmulatorManagerTests: a fake adb answering `boot_completed=1` … asserts `boot` throws and `started.json` has no record; a teardown test asserts a dead-pid record is not killed. (brief C02) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C03.1 | brief C03 criterion 1 | per brief C03 Repro | Re-running the repro: the server for B does not touch A's simulator (it refuses or starts with no session; see C11). (brief C03) | ios | iOS | .maestro/01-browse.yaml (keep-alive in project A) | |
| B-C03.2 | brief C03 criterion 2 | per brief C03 Repro | A keep-alive session is used only when it was started from the same project directory and platform …. (brief C03) | both | iOS+Android | .maestro/01-browse.yaml (keep-alive) | |
| B-C03.3 | brief C03 criterion 3 | per brief C03 Repro | GrantivaMCPTests/MCPServerTests: `loadActiveSession` with a fake store holding a session for another project directory (and one for another platform) asserts it is not returned. (brief C03) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C03.4 | brief C03 criterion 4 | per brief C03 Repro | docs/android.md §Runner sessions and the MCP server states which sessions the server attaches to. (brief C03) | cli | CLI | none (docs/android.md:156-162) | |
| B-C04.1 | brief C04 criterion 1 | per brief C04 Repro | Re-running the repro leaves `out/report.json` (and assets) after exit; the ready file's `reportDir` matches. (brief C04) | both | iOS+Android | grantiva.yml screens | |
| B-C04.2 | brief C04 criterion 2 | per brief C04 Repro | `--timeout 30` on a screens run that hangs is killed after about 30 s; `--continue-on-failure` runs every screen. (brief C04) | both | iOS+Android | NEW:cfg/screens-slow, NEW:cfg/screens-fail | |
| B-C04.3 | brief C04 criterion 3 | per brief C04 Repro | GrantivaCLITests/RunCommandTests: … assert the closure receives `reportDir`, `timeoutSeconds` and `failFast` from the flags. (brief C04) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C04.4 | brief C04 criterion 4 | per brief C04 Repro | GrantivaCoreTests/RunnerSessionCleanupTests: assert a supplied report dir is not deleted after `run(screens:)`. (brief C04) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C05.1 | brief C05 criterion 1 | per brief C05 Repro | Re-running the repro calls the server's own binary …, and the stub is never invoked. (brief C05) | cli | CLI | none (a `grantiva` stub first on PATH; MCP vrt tools in a config dir) | |
| B-C05.2 | brief C05 criterion 2 | per brief C05 Repro | Prefer spawning the executable with an argument array instead of a shell string. (brief C05) | cli | CLI | none (source check: src VRTTools.swift) | |
| B-C05.3 | brief C05 criterion 3 | per brief C05 Repro | GrantivaMCPTests/VRTToolsTests: assert `captureCommand`/`compareCommand`/`approveCommand` start with the running executable's absolute path …. (brief C05) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C06.1 | brief C06 criterion 1 | per brief C06 Repro | Re-running the repro: `[Simulator] udid` equals `[Runner Session] udid`. With no session, it says so rather than picking an arbitrary booted simulator. (brief C06) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| B-C06.2 | brief C06 criterion 2 | per brief C06 Repro | Android: `[Emulator]` likewise names the session's serial. (brief C06) | android | Android | .maestro/01-browse.yaml (keep-alive) | |
| B-C06.3 | brief C06 criterion 3 | per brief C06 Repro | GrantivaMCPTests/ContextToolTests: … assert the output's `[Simulator]` udid is the session's. (brief C06) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C07.1 | brief C07 criterion 1 | per brief C07 Repro | Re-running the repro, the three standard forms parse and the run proceeds to the device. (brief C07) | ios | iOS | NEW:cfg/maestro-format | |
| B-C07.2 | brief C07 criterion 2 | per brief C07 Repro | Decide one behavior for unsupported commands … and make README.md say exactly that; also list `doubleTapOn`, `longPressOn`, `scrollUntilVisible`, `launchApp`, `stopApp`, `killApp`. (brief C07) | cli | CLI | none (README:172) | |
| B-C07.3 | brief C07 criterion 3 | per brief C07 Repro | Errors read `grantiva.yml:4: unsupported Maestro command 'back'` (file name, no enum text). (brief C07) | cli | CLI | none | |
| B-C07.4 | brief C07 criterion 4 | per brief C07 Repro | GrantivaCoreTests: a MaestroFlowParser test per form … and one asserting the error message format. (brief C07) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C08.1 | brief C08 criterion 1 | per brief C08 Repro | Re-running the repro, the generated flow contains `tapOn: id: "General"` (and the step label says id). (brief C08) | ios | iOS | NEW:cfg/maestro-format (`tapOn: {id: clock}`) | |
| B-C08.2 | brief C08 criterion 2 | per brief C08 Repro | Step gains an id-selector form … carried through FlowGenerator for tap, assertVisible, assertNotVisible, scrollUntilVisible and extendedWaitUntil. (brief C08) | both | iOS+Android | NEW:cfg/maestro-format | |
| B-C08.3 | brief C08 criterion 3 | per brief C08 Repro | GrantivaCoreTests: a MaestroFlowParser test asserts `tapOn: {id: X}` yields an id selector, and a FlowGeneratorTests case asserts it is emitted as `id:`. (brief C08) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C09.1 | brief C09 criterion 1 | per brief C09 Repro | Re-running the repro, the step takes at least 3 s. (brief C09) | both | iOS+Android | NEW:cfg/screens-steps (`wait: 3`) | |
| B-C09.2 | brief C09 criterion 2 | per brief C09 Repro | Emit a construct that sleeps unconditionally …, and keep a Maestro `waitForAnimationToEnd` mapped to a settle-wait, not to `wait`. (brief C09) | both | iOS+Android | NEW:cfg/screens-steps | |
| B-C09.3 | brief C09 criterion 3 | per brief C09 Repro | GrantivaCoreTests/FlowGeneratorTests: assert `wait: 3` generates the sleep construct with 3000 ms, not `waitForAnimationToEnd`. (brief C09) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C10.1 | brief C10 criterion 1 | per brief C10 Repro | Re-running the repro, both steps pass (`scroll` scrolls down; permissions are set for the header's app). (brief C10) | both | iOS+Android | NEW:16-setpermissions | |
| B-C10.2 | brief C10 criterion 2 | per brief C10 Repro | `run --flow` with no config and no `--bundle-id` uses the flow's `appId:` header. (brief C10) | both | iOS+Android | NEW:16-setpermissions (scratch dir without config) | |
| B-C10.3 | brief C10 criterion 3 | per brief C10 Repro | A runner-side test (or a GrantivaCoreTests case on the flow normaliser) asserts bare `scroll` gets direction DOWN and `setPermissions` gets the header appId. (brief C10) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C11.1 | brief C11 criterion 1 | per brief C11 Repro | Re-running the repro, both servers answer `initialize` and list all tools. (brief C11) | cli | CLI | none | |
| B-C11.2 | brief C11 criterion 2 | per brief C11 Repro | Session-dependent tools … return `isError` with the "No active runner session ... Start one with ..." text; the driver attaches lazily on first use, and re-checks after a session starts. (brief C11) | both | iOS+Android | none (session only) | |
| B-C11.3 | brief C11 criterion 3 | per brief C11 Repro | Without a config, config-dependent tools return `isError` naming the missing file; `grantiva_sim_*`/`grantiva_emulator_*` work. (brief C11) | both | iOS+Android | none (device lifecycle only) | |
| B-C11.4 | brief C11 criterion 4 | per brief C11 Repro | GrantivaMCPTests/MCPServerTests: start the server with no session over an in-memory transport and assert `tools/list` succeeds and `grantiva_tap` returns `isError`. (brief C11) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C11.5 | brief C11 criterion 5 | per brief C11 Repro | Update help: mcp and docs/android.md §Runner sessions to say the session is needed only for device tools. (brief C11) | cli | CLI | none (help: mcp.txt; docs/android.md:148-154) | |
| B-C12.1 | brief C12 criterion 1 | per brief C12 Repro | Re-running the repro: `doctor` in both/ exits non-zero with "Found both ... Pass --platform ios\|android or set GRANTIVA_PLATFORM." …; both `windows` cases fail with the `run` message; both `init` flag cases fail naming the flag, and write no file. (brief C12) | cli | CLI | none | |
| B-C12.2 | brief C12 criterion 2 | per brief C12 Repro | GrantivaCLITests/DoctorSelectionTests: invalid env throws; both detected without flag throws (or required=false). (brief C12) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C12.3 | brief C12 criterion 3 | per brief C12 Repro | GrantivaCLITests/InitAndroidTests: `--scheme` with `--platform android` and `--application-id` with iOS throw. (brief C12) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C13.1 | brief C13 criterion 1 | per brief C13 Repro | Re-running the repro: `runner stop 2>/dev/null` prints nothing …; `record ... 2>/dev/null` stdout starts with `Recording:`. (brief C13) | ios | iOS | none (records the idle app) | |
| B-C13.2 | brief C13 criterion 2 | per brief C13 Repro | Set the recorder's `standardOutput` to the same log file (or `/dev/null`). (brief C13) | cli | CLI | none (source check: src IOSPlatform) | |
| B-C13.3 | brief C13 criterion 3 | per brief C13 Repro | GrantivaCLITests/OutputStreamContractTests: assert `runner stop` with no session writes nothing to stdout. (brief C13) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C13.4 | brief C13 criterion 4 | per brief C13 Repro | GrantivaCoreTests/IOSPlatformTests: assert the recordVideo process has a non-inherited `standardOutput`. (brief C13) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C14.1 | brief C14 criterion 1 | per brief C14 Repro | Re-running the repro: the first command fails in under a second with exit 64 and no video written; the second either succeeds … or fails before recording with "--output must end in .mov or .mp4". (brief C14) | cli | CLI | none | |
| B-C14.2 | brief C14 criterion 2 | per brief C14 Repro | Move `--frames-at` parsing into `validate()`. (brief C14) | cli | CLI | none (covered by CLI-102 timing) | |
| B-C14.3 | brief C14 criterion 3 | per brief C14 Repro | GrantivaCLITests/RecordCommandTests: `--frames-at a,b` fails parsing … and the injected device's `recordVideo` is never called; an extensionless `--output` is accepted or rejected before `recordVideo`. (brief C14) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C14.4 | brief C14 criterion 4 | per brief C14 Repro | `.mp4` is acceptable only if the written file is actually an MPEG-4 container …. (brief C14) | ios | iOS | none (`record --output a.mp4` on iOS is rejected; `.mov` file is QuickTime per `file`) | |
| B-C14.5 | brief C14 criterion 5 | per brief C14 Repro | Update help: record `--output` to state the accepted extensions. (brief C14) | cli | CLI | none (help: record.txt) | |
| B-C15.1 | brief C15 criterion 1 | per brief C15 Repro | Re-running the repro fails before booting with an error naming the file, the screen and the value, e.g. `grantiva.yml: screen "Diag": swipe direction "diagonal" is not one of up, down, left, right`. (brief C15) | cli | CLI | none | |
| B-C15.2 | brief C15 criterion 2 | per brief C15 Repro | Directions are case-insensitive (`UP` still works). (brief C15) | both | iOS+Android | NEW:cfg/screens-steps | |
| B-C15.3 | brief C15 criterion 3 | per brief C15 Repro | GrantivaCoreTests: a GrantivaConfig decoding test asserts `swipe: diagonal` throws and `swipe: Up` decodes. (brief C15) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C16.1 | brief C16 criterion 1 | per brief C16 Repro | Re-running the repro: create and update with `not.an.event` exit 64 before any request, listing the valid events; `console webhooks events` prints the subscribable types (`--json` supported). (brief C16) | cli | CLI | none (regression found server-side validation instead; record which holds) | |
| B-C16.2 | brief C16 criterion 2 | per brief C16 Repro | The valid list comes from one place …. (brief C16) | cli | CLI | none (source check) | |
| B-C16.3 | brief C16 criterion 3 | per brief C16 Repro | GrantivaCLITests/ConsoleOrgAdminCommandTests: parsing `create https://x --event not.an.event` throws a ValidationError; `events` is a registered subcommand. (brief C16) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C16.4 | brief C16 criterion 4 | per brief C16 Repro | If `events` is not added, remove it from CHANGELOG.md:76 instead. (brief C16) | cli | CLI | none (help: console_webhooks.txt; CHANGELOG.md removed) | |
| B-C17.1 | brief C17 criterion 1 | per brief C17 Repro | Re-running the repro returns `isError: true` with text naming steps 1 and 2 and why. Decide whether invalid steps are rejected before any step runs (preferred) …; document it in the tool description. (brief C17) | both | iOS+Android | NEW:20-park-deeplinks | |
| B-C17.2 | brief C17 criterion 2 | per brief C17 Repro | GrantivaMCPTests/ScriptToolsTests: `steps: [{"bogus":1}, 5]` yields `isError == true`; a valid script still yields no `isError`. (brief C17) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C18.1 | brief C18 criterion 1 | per brief C18 Repro | Re-running the repro: Android says `No grantiva-android.yml here. Create one with grantiva init --platform android.`; iOS … `grantiva.yml` / `grantiva init`; a file with nothing in it says `No screens or flows configured in <resolved file name>`. (brief C18) | cli | CLI | none | |
| B-C18.2 | brief C18 criterion 2 | per brief C18 Repro | GrantivaCLITests/RunCommandTests: no-config Android and empty-config cases assert the respective messages. (brief C18) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C19.1 | brief C19 criterion 1 | per brief C19 Repro | Re-running the repro prints, on stderr, `grantiva.yml:1: unknown key "schem" (did you mean "scheme"?)` and `grantiva.yml:4: unknown key "screen" (did you mean "screens"?)` …; `doctor` reports the same as a Project warning. (brief C19) | cli | CLI | none | |
| B-C19.2 | brief C19 criterion 2 | per brief C19 Repro | Maestro-format files are not affected. (brief C19) | cli | CLI | none (CLI-155 fixture: no unknown-key warning) | |
| B-C19.3 | brief C19 criterion 3 | per brief C19 Repro | GrantivaCoreTests/GrantivaConfigPlatformTests: loading the fixture yields two unknown-key diagnostics with line numbers. (brief C19) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C20.1 | brief C20 criterion 1 | per brief C20 Repro | Re-running the repro, doctor shows `✗ grantiva-android.yml  could not be parsed: 5:3: ...` with status error … and fix text pointing at the file. (brief C20) | cli | CLI | none | |
| B-C20.2 | brief C20 criterion 2 | per brief C20 Repro | `checkConfig` loads the file through the same `GrantivaConfig.load` path `run` uses. (brief C20) | cli | CLI | none (same message from `run` and `doctor`) | |
| B-C20.3 | brief C20 criterion 3 | per brief C20 Repro | GrantivaCoreTests/DoctorTests: a malformed file in a temp dir yields a non-ok status containing "5:3". (brief C20) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C21.1 | brief C21 criterion 1 | per brief C21 Repro | `simulatorNotRunning` says `Run: grantiva simulator ensure --name "<device>"`; element-not-found says `Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree.`; doctor names an installed device type …. (brief C21) | ios | iOS | NEW:20-park-deeplinks (`grantiva_tap {label: "No Such"}`), doctor | |
| B-C21.2 | brief C21 criterion 2 | per brief C21 Repro | Note `grantiva_tap` returned this as a JSON-RPC internal error (rpc-error), not an `isError` result; return `isError`. (brief C21) | both | iOS+Android | NEW:20-park-deeplinks | |
| B-C21.3 | brief C21 criterion 3 | per brief C21 Repro | GrantivaCoreTests: a test parses every "Run: grantiva …" string in GrantivaError and asserts the subcommand path exists …. (brief C21) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C22.1 | brief C22 criterion 1 | per brief C22 Repro | Re-running the repro prints `"acquiredAt" : "2026-10-09T13:15:27Z"`-style strings. (brief C22) | ios | iOS | none (device lifecycle only) | |
| B-C22.2 | brief C22 criterion 2 | per brief C22 Repro | Set `.iso8601` on `JSONOutput.encoder`; check other `--json` outputs with dates …. (brief C22) | both | iOS+Android | none (`emulator sessions --json`, `simulator teardown --json`) | |
| B-C22.3 | brief C22 criterion 3 | per brief C22 Repro | GrantivaCoreTests/JSONOutputTests: encoding `Date(timeIntervalSince1970: 0)` yields `"1970-01-01T00:00:00Z"`. (brief C22) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C23.1 | brief C23 criterion 1 | per brief C23 Repro | Re-running the repro shows the SDK check as a warning: `/Users/kyle/Library/Android/sdk (ANDROID_HOME=/nonexistent has no platform-tools/adb; unset or fix it)`. Same for a stale `ANDROID_SDK_ROOT`. (brief C23) | cli | CLI | none | |
| B-C23.2 | brief C23 criterion 2 | per brief C23 Repro | GrantivaCoreTests/AndroidSDKTests or DoctorTests: `ANDROID_HOME=/nonexistent` plus a valid home SDK yields status `.warning` with a message naming `ANDROID_HOME`. (brief C23) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C24.1 | brief C24 criterion 1 | per brief C24 Repro | Re-running the repro prints on stderr, e.g., `No Xcode project found; scheme "MyApp" is a placeholder. Edit grantiva.yml or pass --scheme.` …. (brief C24) | cli | CLI | none | |
| B-C24.2 | brief C24 criterion 2 | per brief C24 Repro | The simulator default is a device type installed on the host …, or is marked as a placeholder. (brief C24) | cli | CLI | none | |
| B-C24.3 | brief C24 criterion 3 | per brief C24 Repro | GrantivaCLITests: an init test in an empty temp dir asserts the placeholder warning, and one with `--scheme X` asserts none. (brief C24) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C25.1 | brief C25 criterion 1 | per brief C25 Repro | Re-running the repro prints `Not logged in; no credentials at ~/.grantiva/auth.json.` and exits 0; `--json` emits `{"success": true, "message": "No stored credentials"}` (or a `removed: false` field). (brief C25) | cli | CLI | none (scratch HOME so the owner's auth.json is untouched) | |
| B-C25.2 | brief C25 criterion 2 | per brief C25 Repro | `AuthStore.delete` reports whether a file was removed. (brief C25) | cli | CLI | none (source check) | |
| B-C25.3 | brief C25 criterion 3 | per brief C25 Repro | GrantivaCLITests/AuthCommandTests: with a fake store reporting no file, assert the not-logged-in message. (brief C25) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-C26.1 | brief C26 criterion 1 | per brief C26 Repro | README §Agent-Native Features describes `--snapshot failure\|trailing\|full`, `--continue-on-failure` (fail-fast is the default), and `--timeout` (default 600, minimum 30, ignored under `--keep-alive`). (brief C26) | cli | CLI | none (README:95-97) | |
| B-C26.2 | brief C26 criterion 2 | per brief C26 Repro | `run --help` for `--timeout` says "Minimum 30." (brief C26) | cli | CLI | none (help: run.txt) | |
| B-C26.3 | brief C26 criterion 3 | per brief C26 Repro | Note that until C04 is fixed, these flags apply only to `flows:`/`--flow`; say so, or drop the note once C04 lands. (brief C26) | cli | CLI | none (README:99; brief R03) | |
| B-D01.1 | brief D01 criterion 1 | per brief D01 Repro | `hierarchy --json` and `runner dump-hierarchy --json` print JSON (as if `--format json`); `--json` with `--format xml` is a usage error. (brief D01) | both | iOS+Android | .maestro/01-browse.yaml (keep-alive) | |
| B-D01.2 | brief D01 criterion 2 | per brief D01 Repro | README.md states that runner lifecycle commands support `--json`; docs/dump-hierarchy.md lists `--json`. (brief D01) | cli | CLI | none (README:365-369; docs/dump-hierarchy.md:38, 51) | |
| B-D01.3 | brief D01 criterion 3 | per brief D01 Repro | GrantivaCLITests/HierarchyCommandTests and DumpHierarchyCommandTests: parsing `--json` alone resolves to JSON output. (brief D01) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-D02.1 | brief D02 criterion 1 | per brief D02 Repro | README §Commands lists `emulator ensure\|delete\|sessions\|teardown`, `console` …, and `runner dump-hierarchy`; `run`/`record`/`build` lines say "simulator or emulator". (brief D02) | cli | CLI | none (README:305-338) | |
| B-D02.2 | brief D02 criterion 2 | per brief D02 Repro | `simulator cleanup` wording matches help. (brief D02) | cli | CLI | none (README:321; help: simulator_cleanup.txt) | |
| B-D02.3 | brief D02 criterion 3 | per brief D02 Repro | `Delete` and `Sessions` get abstracts …; GrantivaCLITests/SimulatorCommandTests asserts every simulator subcommand has a non-empty abstract. (brief D02) | cli | CLI | none (help: simulator.txt; source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-D03.1 | brief D03 criterion 1 | per brief D03 Repro | README shows a command that runs as written, e.g. `grantiva run --simulator "$udid" --flow flows/login.yaml`. (brief D03) | cli | CLI | none (README:415) | |
| B-D03.2 | brief D03 criterion 2 | per brief D03 Repro | The fixed snippet is copied into a scratch iOS project and parses (no usage error). (brief D03) | cli | CLI | none | |
| B-D04.1 | brief D04 criterion 1 | per brief D04 Repro | Overviews read e.g. "The Grantiva CLI for iOS and Android developers.", "Run Maestro flows against a simulator or emulator.", "Build the app for a simulator (xcodebuild) or emulator (Gradle).", and `--no-build` says "device". (brief D04) | cli | CLI | none (help corpus) | |
| B-D04.2 | brief D04 criterion 2 | per brief D04 Repro | README.md:3 tagline updated to match. (brief D04) | cli | CLI | none (README:3) | |
| B-D04.3 | brief D04 criterion 3 | per brief D04 Repro | GrantivaCLITests: a test asserts no command abstract contains "simulator" without "emulator" for commands whose platform options include Android. (brief D04) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-D05.1 | brief D05 criterion 1 | per brief D05 Repro | Either bump the version … or move the entries under the release that ships them; `grantiva --version` and the CHANGELOG heading agree. (brief D05) | cli | CLI | none (CHANGELOG.md removed in #179; check no file claims another version than 2.1.0) | |
| B-D05.2 | brief D05 criterion 2 | per brief D05 Repro | Release checklist (or the release workflow) checks that `## Unreleased` is empty when a tag is cut. (brief D05) | cli | CLI | none (n/a if CHANGELOG.md is gone; record what the release workflow does) | |
| B-D06.1 | brief D06 criterion 1 | per brief D06 Repro | docs/android-environment.md §CI says `ci run` refuses Android today, points to local `diff capture\|compare\|approve`, and keeps the self-hosted-Mac note. (brief D06) | cli | CLI | none (docs/android-environment.md:18-28) | |
| B-D07.1 | brief D07 criterion 1 | per brief D07 Repro | docs/android.md §Devices drops "Only running emulators are considered by default" and states the order …. (brief D07) | cli | CLI | none (docs/android.md:31-38) | |
| B-D07.2 | brief D07 criterion 2 | per brief D07 Repro | The doc comment at EmulatorManager.swift:136 is reworded the same way. (brief D07) | cli | CLI | none (source check) | |
| B-D08.1 | brief D08 criterion 1 | per brief D08 Repro | README §Agent-Native Features and the `--ready-file` help say "Missing parent directories are created." …. (brief D08) | cli | CLI | none (README:87; help: run.txt) | |
| B-D08.2 | brief D08 criterion 2 | per brief D08 Repro | GrantivaCoreTests/ReadyFileTests already covers creation; add an assertion if the behavior changes. (brief D08) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-D09.1 | brief D09 criterion 1 | per brief D09 Repro | A doc (README §MCP or docs/mcp.md) lists all 22 tools with one line each, notes `grantiva_test` is iOS-only and `grantiva_emulator_*` Android-only, and states which need a runner session. (brief D09) | cli | CLI | none (docs/mcp.md:43-90) | |
| B-D09.2 | brief D09 criterion 2 | per brief D09 Repro | GrantivaMCPTests/ToolRegistrationTests: a test asserts the documented list equals the registered tool names. (brief D09) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I01.1 | brief I01 criterion 1 | per brief I01 Repro | Re-running the repro 5 times: every pair exits 0/0. (brief I01) | ios | iOS | .maestro/01-browse.yaml, .maestro/05-category.yaml (cov-ios-1 + cov-ios-2) | |
| B-I01.2 | brief I01 criterion 2 | per brief I01 Repro | Each concurrent WDA uses a per-UDID derived data / result-bundle path …. Document the chosen behaviour in README §Agent-Native Features (Concurrent runs). (brief I01) | ios | iOS | .maestro/01-browse.yaml (README:92; `versions/*/devices/<udid>` listing) | |
| B-I01.3 | brief I01 criterion 3 | per brief I01 Repro | Test: a GrantivaCoreTests case asserting that runner arguments/environment for two different UDIDs yield distinct WDA derived-data paths …, plus a runner-side regression test. (brief I01) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I02.1 | brief I02 criterion 1 | per brief I02 Repro | Re-running the repro: `Device: qa-ios-1` (here cov-ios-1), capture succeeds; the other simulator is untouched. (brief I02) | ios | iOS | grantiva.yml screens | |
| B-I02.2 | brief I02 criterion 2 | per brief I02 Repro | `--no-build` resolves the device as flag > config `simulator:` > the runner session's UDID > (only if exactly one simulator is booted) that one; with several booted and nothing configured it fails naming them. (brief I02) | ios | iOS | grantiva.yml screens | |
| B-I02.3 | brief I02 criterion 3 | per brief I02 Repro | MCP `grantiva_vrt_capture` targets the same device (config or session UDID). (brief I02) | ios | iOS | grantiva.yml screens | |
| B-I02.4 | brief I02 criterion 4 | per brief I02 Repro | GrantivaCLITests/DiffCommandTests: with a fake platform reporting two booted devices and config `simulator: B`, the `--no-build` path boots/uses B. (brief I02) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I03.1 | brief I03 criterion 1 | per brief I03 Repro | Re-running the repro: after the failed capture, `diff compare` exits non-zero and says the captures are missing or stale (no screen reported `passed`). (brief I03) | ios | iOS | NEW:cfg/screens-fail | |
| B-I03.2 | brief I03 criterion 2 | per brief I03 Repro | Capture writes into a fresh temp dir and swaps it in only on success, or … a capture manifest … that compare checks. (brief I03) | ios | iOS | NEW:cfg/screens-fail | |
| B-I03.3 | brief I03 criterion 3 | per brief I03 Repro | GrantivaCoreTests/RunnerSessionTests: a fake runner exiting 1 leaves no pre-existing capture that compare would accept. (brief I03) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I04.1 | brief I04 criterion 1 | per brief I04 Repro | Re-running the repro 10 times: 10/10 pass. (brief I04) | ios | iOS | .maestro/04-discard.yaml | |
| B-I04.2 | brief I04 criterion 2 | per brief I04 Repro | Auto-accept is limited to SpringBoard (system) alerts such as permission prompts …; app-owned alerts are never dismissed implicitly. (brief I04) | ios | iOS | NEW:21-system-alert-maps, .maestro/04-discard.yaml | |
| B-I04.3 | brief I04 criterion 3 | per brief I04 Repro | Runner-side test: an app alert … is still present after an element lookup; a GrantivaCoreTests case asserts the runner arguments carry the chosen alert policy. (brief I04) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I05.1 | brief I05 criterion 1 | per brief I05 Repro | Re-running the repro: `{"label":"Favorites"}` taps the tab and returns the Favorites tree; `{"label":"heart"}` no longer matches (or matches only as a fallback). (brief I05) | ios | iOS | .maestro/01-browse.yaml (keep-alive) | |
| B-I05.2 | brief I05 criterion 2 | per brief I05 Repro | Use a predicate/class-chain locator on `label == $label` (escaping quotes), falling back to name; the same for script `tap`. (brief I05) | ios | iOS | NEW:20-park-deeplinks (`grantiva_script {tap: ...}`; a label with a quote: `Mount "Denali"`) | |
| B-I05.3 | brief I05 criterion 3 | per brief I05 Repro | GrantivaCoreTests/WDAClientTests: … assert the find request uses a label-based strategy and escapes `"` in the label. (brief I05) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I06.1 | brief I06 criterion 1 | per brief I06 Repro | Re-running the repro: `grantiva_type` returns the updated tree and the field contains the typed text. (brief I06) | ios | iOS | NEW:19-park-edit | |
| B-I06.2 | brief I06 criterion 2 | per brief I06 Repro | typeText posts `{"value": [chars]}` to `/session/{id}/wda/keys` …. (brief I06) | ios | iOS | NEW:19-park-edit (runner log) | |
| B-I06.3 | brief I06 criterion 3 | per brief I06 Repro | GrantivaCoreTests/WDAClientTests: a stub server records the path and asserts `/wda/keys`; a non-200 error message names the HTTP status …. (brief I06) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I07.1 | brief I07 criterion 1 | per brief I07 Repro | Re-running the repro: the default `--logs` run streams the app's lines (hundreds for flow 08), and no `getpwuid_r`/"Filtering the log data" banner lines are prefixed `[log]`. (brief I07) | ios | iOS | .maestro/08-caching.yaml | |
| B-I07.2 | brief I07 criterion 2 | per brief I07 Repro | The default predicate also matches the app's executable …. Update the help text to say what it matches. (brief I07) | ios | iOS | .maestro/08-caching.yaml (`--verbose` shows the predicate; help: run.txt) | |
| B-I07.3 | brief I07 criterion 3 | per brief I07 Repro | GrantivaCoreTests/LogStreamerTests: `defaultLogPredicate(forBundleID:executable:)` includes the executable clause, and the simctl banner lines are filtered out. (brief I07) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I08.1 | brief I08 criterion 1 | per brief I08 Repro | Re-running the repro: the manual device is never listed by `simulator sessions`, `teardown` leaves it Booted, and a session-less record disappears once its owner pid is dead. (brief I08) | ios | iOS | .maestro/01-browse.yaml | |
| B-I08.2 | brief I08 criterion 2 | per brief I08 Repro | `boot()` records whether Grantiva booted the device …; a pre-booted device takes no slot … and teardown never shuts it down. Active records whose owner pid is dead and which have no session ID are pruned. (brief I08) | ios | iOS | .maestro/01-browse.yaml | |
| B-I08.3 | brief I08 criterion 3 | per brief I08 Repro | GrantivaCoreTests/SimulatorCapacityTests: `prune` drops an active `simulator:<udid>` record with a dead pid; a SimulatorManager test … asserts no `simctl shutdown` for a device that was already booted. (brief I08) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I09.1 | brief I09 criterion 1 | per brief I09 Repro | Re-running the repro: `capacityRecordsCleared` is 0 for a record whose session is still active elsewhere …, `simulator sessions` still lists the device under its session, and `/tmp/grantiva-sessions` has no files of the killed run. No `simctl diagnose` for the UDID survives. (brief I09) | ios | iOS | .maestro/01-browse.yaml | |
| B-I09.2 | brief I09 criterion 2 | per brief I09 Repro | Only records whose owner pid is dead …, or `pending` records, are cleared; the JSON says which records were kept and why. (brief I09) | ios | iOS | .maestro/01-browse.yaml | |
| B-I09.3 | brief I09 criterion 3 | per brief I09 Repro | GrantivaCoreTests/SimulatorReaperTests: … force teardown keeps it; … the killed runner's `.grantiva` and `.owner.json` files are removed. (brief I09) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I10.1 | brief I10 criterion 1 | per brief I10 Repro | Re-running the repro: the bare `ensure --name cov-ios-1` reuses the device (exit 0, UDID on stdout); the `--json` reuse reports `runtime: iOS 26.0` and the device's real type. (brief I10) | ios | iOS | none (device lifecycle only) | |
| B-I10.2 | brief I10 criterion 2 | per brief I10 Repro | Look up by name first; infer type/runtime only when creating. A new name without a model still fails with today's message. Help and README say a model in the name, or `--device-type`, is required to create …. (brief I10) | ios | iOS | none (help: simulator_ensure.txt; README:422-428) | |
| B-I10.3 | brief I10 criterion 3 | per brief I10 Repro | GrantivaCoreTests/SimulatorManagerTests: … bare ensure returns its UDID and its own runtime/type; a bare ensure of an unknown model-less name throws. (brief I10) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I11.1 | brief I11 criterion 1 | per brief I11 Repro | Re-running the repro: no `/var/folders` path in `out/`; `sourceFile` and the junit `file` property are `.maestro/09-seed-empty.yaml` (the path as passed). (brief I11) | ios | iOS | .maestro/09-seed-empty.yaml | |
| B-I11.2 | brief I11 criterion 2 | per brief I11 Repro | After the runner exits (pass or fail, including timeout), rewrite those files … (brief I11) | ios | iOS | NEW:18-long-wait (`--timeout 30 --report-dir out`) | |
| B-I11.3 | brief I11 criterion 3 | per brief I11 Repro | GrantivaCoreTests/RunnerSessionTests (or a RunnerReportRewriter unit): … the rewritten files contain only the user paths and stay valid JSON/XML. (brief I11) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I12.1 | brief I12 criterion 1 | per brief I12 Repro | Re-running the repro: `fail.json` parses and has `"allPassed": false`, the failing flow/step and its message …, and the report dir path when preserved; exit stays 1. (brief I12) | ios | iOS | NEW:02-exact-negative | |
| B-I12.2 | brief I12 criterion 2 | per brief I12 Repro | Setup failures under `--json` (no device, bad flag after validation) also print `{"allPassed": false, "error": "..."}`. (brief I12) | cli | CLI | none | |
| B-I12.3 | brief I12 criterion 3 | per brief I12 Repro | GrantivaCLITests/RunCommandTests: with a fake runner exiting 1 and a fixture report.json, stdout is valid JSON with `allPassed == false` and the failed step. (brief I12) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I13.1 | brief I13 criterion 1 | per brief I13 Repro | Re-running the repro: exit non-zero with the "No scheme specified" message listing the schemes found (e.g. `Found: Landmarks, Landmarks (UI Testing)`) …. With exactly one scheme, auto-detection still works silently. (brief I13) | ios | iOS | none (build only) | |
| B-I13.2 | brief I13 criterion 2 | per brief I13 Repro | A cached detection never overrides a missing scheme when the project has several. (brief I13) | ios | iOS | none (build only; run twice) | |
| B-I13.3 | brief I13 criterion 3 | per brief I13 Repro | GrantivaCoreTests/ProjectDetectorTests (or ProjectResolverTests): … two schemes and no configured scheme yields the error …; with one scheme it resolves to it. (brief I13) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I14.1 | brief I14 criterion 1 | per brief I14 Repro | Re-running the repro: after the timeout, the device does not exist and its provenance entry is gone; a pre-existing device with that name is left untouched. (brief I14) | ios | iOS | none (device lifecycle only) | |
| B-I14.2 | brief I14 criterion 2 | per brief I14 Repro | Prefer reserving capacity before `simctl create`, or wrap the boot in a do/catch that deletes a device with `created == true`. (brief I14) | ios | iOS | none (device lifecycle only) | |
| B-I14.3 | brief I14 criterion 3 | per brief I14 Repro | GrantivaCoreTests/SimulatorManagerTests: … `ensure` issues `simctl delete <udid>` for a device it created and not for a reused one. (brief I14) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I15.1 | brief I15 criterion 1 | per brief I15 Repro | Re-running the repro: hierarchy prints one line, e.g. `Error: GrantivaAgent on port 8129 did not answer within 0.01s (--timeout). Is the run still alive?`; the `--no-build` run fails before the runner starts with `com.kylebrowning.Landmarks is not installed on cov-ios-1. Drop --no-build or run grantiva build install.` (brief I15) | ios | iOS | .maestro/01-browse.yaml | |
| B-I15.2 | brief I15 criterion 2 | per brief I15 Repro | Map URLError (`.timedOut`, `.cannotConnectToHost`) to GrantivaError messages with the port and remediation. (brief I15) | ios | iOS | .maestro/01-browse.yaml (hierarchy after the agent died) | |
| B-I15.3 | brief I15 criterion 3 | per brief I15 Repro | Tests: HierarchyCommandTests maps a URLError.timedOut …; RunCommandTests with a fake `get_app_container` failure asserts the not-installed error …. (brief I15) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I16.1 | brief I16 criterion 1 | per brief I16 Repro | Re-running the repro: files are `Deep Links.png` and `diffs/Deep Links_diff.png`; JSON paths match. (brief I16) | both | iOS+Android | grantiva.yml screens | |
| B-I16.2 | brief I16 criterion 2 | per brief I16 Repro | Encode only what cannot appear in one path component …, and have the baseline loader accept existing `%20` files, migrating them on `diff approve`. (brief I16) | ios | iOS | grantiva.yml screens (a legacy `Deep%20Links.png` baseline) | |
| B-I16.3 | brief I16 criterion 3 | per brief I16 Repro | GrantivaCoreTests/ScreenArtifactTests: `fileName(for: "Deep Links") == "Deep Links.png"` … a legacy `Deep%20Links.png` baseline is still found. (brief I16) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I17.1 | brief I17 criterion 1 | per brief I17 Repro | Re-running the repro: the result text includes the xcodebuild error line(s) … and, for test failures, the failing test names. (brief I17) | ios | iOS | none (build only) | |
| B-I17.2 | brief I17 criterion 2 | per brief I17 Repro | On failure, append the `error:` lines and the last ~40 lines of `output` (bounded, e.g. 4 KB); keep success output short. (brief I17) | ios | iOS | none (build only) | |
| B-I17.3 | brief I17 criterion 3 | per brief I17 Repro | GrantivaMCPTests/BuildToolsTests: a fake runner returning `TestResult(success: false, …)` yields text containing that error and `isError: true`. (brief I17) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I18.1 | brief I18 criterion 1 | per brief I18 Repro | Re-running the repro: the rows show their own flows' step counts and durations and are distinguishable (e.g. `qa/a/same`, `qa/b/same`). (brief I18) | ios | iOS | NEW:14-runflow (copied to a/ and b/ as same.yaml) | |
| B-I18.2 | brief I18 criterion 2 | per brief I18 Repro | Fix the runner's keying …, or give colliding basenames a unique flow `name:` when staging, or print its own summary from report.json. (brief I18) | ios | iOS | NEW:14-runflow (a/ and b/) | |
| B-I18.3 | brief I18 criterion 3 | per brief I18 Repro | Test: a runner-side test with two same-named flows, or a GrantivaCoreTests case asserting staging yields unique flow names. (brief I18) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-I19.1 | brief I19 criterion 1 | per brief I19 Repro | README §Configuration … states: both checks must pass; `threshold` is a 0-1 fraction …; `perceptual_threshold` is the mean CIE76 ΔE over differing pixels only …, with a sentence on loosening a screen by raising both. (brief I19) | cli | CLI | none (README:123-128) | |
| B-I19.2 | brief I19 criterion 2 | per brief I19 Repro | If the averaging is changed instead …, note it and update ImageDifferTests. (brief I19) | cli | CLI | none (source check; n/a if unchanged) | |
| B-I19.3 | brief I19 criterion 3 | per brief I19 Repro | Doc-only change needs no unit test; if code changes, add ImageDifferTests …. (brief I19) | cli | CLI | none (n/a if doc-only) | |
| B-R01.1 | brief R01 criterion 1 | per brief R01 Repro | Re-running the repro: exit 0; `assertVisible "Golden Gate Bridge Renamed"` passes; with `--snapshot full` the capture after `inputText` shows `Golden Gate Bridge Renamed` in the Name field. (brief R01) | android | Android | .maestro/03-edit.yaml | |
| B-R01.2 | brief R01 criterion 2 | per brief R01 Repro | `tapOn: "Done"` in flow 03 clicks the sheet's toolbar button (client.log click y well above the keyboard area …), and the sheet closes. (brief R01) | android | Android | .maestro/03-edit.yaml | |
| B-R01.3 | brief R01 criterion 3 | per brief R01 Repro | The full Android flow set … passes 12/12, and 99-crash still fails at `launchApp` with `LANDMARKS_CRASH_ON_LAUNCH`. (brief R01) | android | Android | .maestro/01-browse.yaml ... 12-quote-label.yaml, .maestro/99-crash.yaml | |
| B-R01.4 | brief R01 criterion 4 | per brief R01 Repro | If the runner changes: the iOS flow set still passes 12/12 on iOS 26.0 and 27.0. (brief R01) | ios | iOS | .maestro/01-browse.yaml ... 12-quote-label.yaml | |
| B-R01.5 | brief R01 criterion 5 | per brief R01 Repro | Runner test: `inputText` with no selector into a focused field that already holds `abc` leaves `abc<typed>` …; a typed value that silently replaced non-hint existing text is reported, not marked `✓`. (brief R01) | cli | CLI | none (source check in the runner repo, ~/Developer/maestro-runner at ae48e34) | |
| B-R01.6 | brief R01 criterion 6 | per brief R01 Repro | The bundled runner version is bumped in this repo and the release notes say what changed. (brief R01) | cli | CLI | none (`runner version`; commit 51c597a message) | |
| B-R02.1 | brief R02 criterion 1 | per brief R02 Repro | Re-running the repro: `c-direction-left-from.yaml` passes, and its After capture shows the row opened …; the overlay trace runs most of the row's width. (brief R02) | android | Android | .maestro/02-favorite.yaml (`--snapshot full`) | |
| B-R02.2 | brief R02 criterion 2 | per brief R02 Repro | Flow 02's `cmd-008-after.png` (with `--snapshot full`) shows the revealed swipe action, as A02 required. (brief R02) | android | Android | .maestro/02-favorite.yaml | |
| B-R02.3 | brief R02 criterion 3 | per brief R02 Repro | `from: "No Such Row"` still fails at the swipe with `Element not found for swipe`, exit 1, and the lookup … still appears in client.log. (brief R02) | android | Android | NEW:07-swipe-from-missing | |
| B-R02.4 | brief R02 criterion 4 | per brief R02 Repro | `c2-abs-px-row.yaml` either swipes from (900,520) to (100,520) in pixels and opens the row, or fails before the swipe …. It must not report `✓ swipe` for a gesture that lands off screen. (brief R02) | android | Android | NEW:06-swipe-absolute | |
| B-R02.5 | brief R02 criterion 5 | per brief R02 Repro | Runner tests: an element swipe LEFT from an element centred at x=155 on a 1080 px screen travels at least the distance a coordinate swipe of `60%`→`5%` covers …; parsing `900, 520` does not yield 9.0 / 5.2. (brief R02) | cli | CLI | none (source check in the runner repo) | |
| B-R02.6 | brief R02 criterion 6 | per brief R02 Repro | The Android flow set still passes 12/12, and the iOS flow set (02-favorite in particular) still passes on iOS 26.0 and 27.0 …. (brief R02) | both | iOS+Android | .maestro/02-favorite.yaml + stock set | |
| B-R03.1 | brief R03 criterion 1 | per brief R03 Repro | `grep -n "fixed 300 s timeout" README.md` finds nothing, and README:99's paragraph is removed or rewritten to agree with README:101. (brief R03) | cli | CLI | none (README:95-99) | |
| B-R03.2 | brief R03 criterion 2 | per brief R03 Repro | Before choosing the wording, confirm the behaviour on one device: a `screens:`-only run with `--timeout 30` … is killed at about 30 s …, and with `--continue-on-failure` a failed screens session is reported and the configured flows still run. (brief R03) | ios | iOS | NEW:cfg/screens-slow, NEW:cfg/screens-fail | |
| B-R03.3 | brief R03 criterion 3 | per brief R03 Repro | README:95-97 and `run --help` keep their current `--snapshot`, `--continue-on-failure` and `--timeout` text. (brief R03) | cli | CLI | none (README:95-97; help: run.txt) | |
| B-R04.1 | brief R04 criterion 1 | per brief R04 Repro | Re-running the repro in an empty directory: `grantiva_build` and `grantiva_vrt_capture` return `isError: true` with text naming the missing file …. (brief R04) | cli | CLI | none | |
| B-R04.2 | brief R04 criterion 2 | per brief R04 Repro | The same holds for every other tool that reads the config; `grantiva_sim_*`, `grantiva_emulator_*` and `grantiva_context` keep working as now. (brief R04) | cli | CLI | none (`grantiva_run`, `grantiva_test`; `grantiva_sim_list`, `grantiva_emulator_list`, `grantiva_context`) | |
| B-R04.3 | brief R04 criterion 3 | per brief R04 Repro | With a config that exists but has no `screens:`, `grantiva_vrt_capture` keeps saying `No screens configured in grantiva.yml`. (brief R04) | cli | CLI | none | |
| B-R04.4 | brief R04 criterion 4 | per brief R04 Repro | GrantivaMCPTests: with no config file, `grantiva_build` returns isError whose text contains `grantiva.yml` and says it was not found. (brief R04) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |
| B-R05.1 | brief R05 criterion 1 | per brief R05 Repro | Re-running the repro: a session tool called in the window between `runner start --detach` returning and WDA having a session returns a `result` with `"isError": true`, never a JSON-RPC `error` …, for example `The runner session is starting (WDA on port 8581 has no session yet). Retry in a few seconds.` (brief R05) | ios | iOS | none (session only) | |
| B-R05.2 | brief R05 criterion 2 | per brief R05 Repro | The same holds for every session tool …, and for other driver errors those tools hit. (brief R05) | both | iOS+Android | none (session only) | |
| B-R05.3 | brief R05 criterion 3 | per brief R05 Repro | Lazy attach still works: on the same server, the call made once WDA is ready returns the hierarchy without a restart, and a missing label still gives `Element not found: ...` as isError. (brief R05) | both | iOS+Android | none (session only) | |
| B-R05.4 | brief R05 criterion 4 | per brief R05 Repro | GrantivaMCPTests: with a session file present and a WDA stub whose `/status` has no `sessionId`, a session tool returns isError … no error is thrown out of `ToolRegistry.call`. (brief R05) | cli | CLI | none (source check: test present under Tests/ at 51c597a (grep; no swift build in the campaign)) | |

## Carried findings (N)

N01-N14 from the plan's "New findings" list; N15-N18 from the round-1 smoke (`findings/round1-smoke.md`).

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| N-01 | `runner stop` | `run --keep-alive` session live (no `runner start`), then `runner stop` from the same project dir | Either stops the keep-alive session (runner exits, lease released, ready file `interrupted`) or says plainly that it only stops `runner start` sessions and names Ctrl-C/`kill -INT` as the way; never prints "stopped" while the session survives (plan N01; help: runner_stop.txt "Stop the running runner session") | both | iOS+Android | .maestro/01-browse.yaml (keep-alive) | |
| N-02 | MCP `grantiva_build` | Android config `emulator: cov-android` shut down; `grantiva_build {}` | Compiles only and boots nothing, like `build build` (docs/android.md:40-41); `adb devices` unchanged (plan N02) | android | Android | none (build only) | |
| N-03 | `run --flow` | `.maestro/10-seed-many.yaml` on a freshly created AVD (`cov-android-2`) and on `cov-android` | `Landmark 30` visible after four bare `scroll`s; record the last landmark reached on each (plan N03; README:172 `scroll`) | android | Android | .maestro/10-seed-many.yaml | |
| N-04 | `diff capture` | right after an MCP `grantiva_vrt_capture` through a session on the same simulator, then `runner stop` | Detail screen captured ("Golden Gate Bridge" found); 5/5; repeat 3 times (plan N04) | ios | iOS | grantiva.yml screens | |
| N-05 | `run --flow` | tap on a missing label as the first step right after WDA reports ready (`runner start --detach` then MCP `grantiva_tap {label: "No Such"}`; and a flow whose first step after `launchApp` taps a missing label), 5 times | Always `Element not found: "No Such" ...`, never `Network error (400)` (plan N05; brief C21) | ios | iOS | NEW:20-park-deeplinks | |
| N-06 | `diff capture` | first `diff capture` on a freshly booted `cov-android-2`, 3 fresh boots | UIAutomator2 connects on the first attempt each time; if it drops, the run retries or fails with a message naming the driver, not a raw connection error (plan N06) | android | Android | grantiva-android.yml screens | |
| N-07 | `runner start --help` | none | Abstract names UIAutomator2 on Android, matching README:333 (plan N07; help: runner_start.txt) | cli | CLI | none | |
| N-08 | any device command | `ls ~/.maestro-runner/bin` before and after the iOS and Android stock sets; `PATH` without it | `grantiva` never reads or writes `~/.maestro-runner`; runs pass with it absent from PATH (plan N08) | both | iOS+Android | .maestro/01-browse.yaml | |
| N-09 | `run`, `simulator teardown` | `find $GRANTIVA_RUNNER_HOME -name 'dlrun-*'` after the iOS stock set and after teardown | None present (plan N09) | ios | iOS | .maestro/01-browse.yaml ... 12-quote-label.yaml | |
| N-10 | `run --verbose` | iOS stock flow 02 | Runner log shows the WDA driver (not `devicelab_ios_legacy`); swipe `start`/`end` therefore never take the legacy percentage path (plan N10) | ios | iOS | .maestro/02-favorite.yaml | |
| N-11 | `run --flow` | `tapOn: {point: "100%,100%"}` (and `0%,0%`) | Step passes and lands on screen on both platforms (plan N11) | both | iOS+Android | NEW:04-point-taps | |
| N-12 | MCP `grantiva_vrt_capture` vs `diff capture` | one session capture per screen, then `diff capture` of the same screens, then `diff compare` session-vs-CLI captures (baseline = one, current = other) | Every screen passes the configured thresholds; placeholder/hint text matched; `simulator:` ignored with a live session (session's device used); screenshots from the driver (plan N12; docs/mcp.md:88) | both | iOS+Android | grantiva.yml screens / grantiva-android.yml screens | |
| N-13 | MCP session tools during WDA startup | `runner start --detach`, then immediately each of the 7 session tools in one server, repeated until ready | Each returns a `result` (isError `The runner session is starting (WDA on port <p> has no session yet). Retry in a few seconds.`, or success; `grantiva_screenshot` may succeed); never a JSON-RPC `error`; the first call after ready attaches (plan N13; docs/mcp.md:18-22; brief R05) | both | iOS+Android | none (session only) | |
| N-14 | report.json | `--report-dir out` for `.maestro/03-edit.yaml` (append) and for `.maestro/99-crash.yaml` | 03-edit: no `warning` on the inputText command (it appended); 99-crash: the failed wait's `error.type` is `app_crash` (plan N14) | both | iOS+Android | .maestro/03-edit.yaml, .maestro/99-crash.yaml | |
| N-15 | `run` narration (Android) | stock set | Names the Android driver (UIAutomator2), not "Running N flow(s) in one GrantivaAgent session" (plan N15; round-1 smoke; docs/android.md:3-4) | android | Android | .maestro/01-browse.yaml ... 12-quote-label.yaml | |
| N-16 | `run` narration (Android) | config with 5 screens and 12 flows | Flow count printed once and right ("Running 12 flow(s)", screens counted separately), not "Running 13 flow(s)…" then "Running 12 flow(s)…" (plan N16; round-1 smoke) | android | Android | grantiva-android.yml screens + flows | |
| N-17 | `run` step durations | `--report-dir out`, any flow | Live-line durations equal the summary block's and report.json's for the same step (e.g. launchApp, assertVisible) (plan N17; round-1 smoke) | both | iOS+Android | .maestro/01-browse.yaml | |
| N-18 | `run` narration (iOS cache hit) | stock flow with the `-r1` cache present | Says "using cached build" without "Building GrantivaAgent..." / "GrantivaAgent built" around the cache-hit line (plan N18; round-1 smoke; README:92 "without rebuilding WDA") | ios | iOS | .maestro/01-browse.yaml | |

## Cross-platform shape (X)

Each row runs the same command on iOS (`cov-ios-1`) and Android (`cov-android`); each device slice records its half
(raw stdout, stderr, `--json`), and Task 6 diffs them. Expected: text and `--json` differ only where the platform
demands (device naming and the keys docs/android.md documents); same top-level keys, same status vocabulary, same
exit codes.

| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |
|---|---|---|---|---|---|---|---|
| X-001 | `run` (text) | passing flow | Same narration structure (Resolved line, flow count, per-step lines, summary); only device naming differs; Android narration never says GrantivaAgent (README:308; plan N15) | both | iOS+Android | .maestro/01-browse.yaml | |
| X-002 | `run --json` | passing and failing flow | Same keys (`allPassed`, `screens`, flows/steps, `error`, `reportDir`) and types on both (README:383-386) | both | iOS+Android | .maestro/01-browse.yaml, NEW:02-exact-negative | |
| X-003 | `run --report-dir` | passing flow | Same `report.json` schema, `flows/*.json`, `junit-report.xml` names; flow paths as passed (README:99) | both | iOS+Android | .maestro/01-browse.yaml | |
| X-004 | `run --ready-file` | passed; failed; interrupted | Same JSON keys and status vocabulary (passed / failed / interrupted) (README:82, 89) | both | iOS+Android | .maestro/01-browse.yaml, NEW:02-exact-negative | |
| X-005 | `build build --json` | default | Same top-level keys except the platform's product fields (help: build_build.txt) | both | iOS+Android | none (build only) | |
| X-006 | `build install --no-launch --json` | default | iOS `status, scheme, bundleId, appPath, dataContainerPath, simulator{name,udid}`; Android `status, applicationId, appPath, device{name,serial}` (README:252-255) | both | iOS+Android | none (build only) | |
| X-007 | `diff capture` text and `--json` | five screens | iOS `Simulator: <name> (<udid>)`; Android `Emulator: <AVD> (<serial>)`; Android JSON adds `emulator` next to `simulator`; otherwise identical shapes (docs/android.md:74-76) | both | iOS+Android | grantiva.yml screens / grantiva-android.yml screens | |
| X-008 | `diff compare` text and `--json` | after approve | Same per-screen fields and status words (help: diff_compare.txt) | both | iOS+Android | grantiva.yml screens / grantiva-android.yml screens | |
| X-009 | `diff approve --json` | all; one screen | Same shape; paths under `baselines/` vs `baselines/android/` (docs/android.md:70-71) | both | iOS+Android | grantiva.yml screens / grantiva-android.yml screens | |
| X-010 | `record --json` | `--duration 3 --frames-at 0,1000` | Same frame fields; Android adds `emulator`, `serial` with `simulator`/`udid` kept (docs/android.md:125-127) | both | iOS+Android | none (records the idle app) | |
| X-011 | `hierarchy` (xml and `--format json`) | keep-alive on the Landmarks list | XML root and JSON structure documented per platform; frames points vs dp (docs/dump-hierarchy.md:27-30; docs/android.md:105-106) | both | iOS+Android | .maestro/01-browse.yaml (keep-alive) | |
| X-012 | `runner dump-hierarchy` tree/json/xml | `runner start --detach` | Same three formats on both, same tree conventions (docs/android.md:111) | both | iOS+Android | none (session only) | |
| X-013 | `runner start`/`stop` text and `--json` | none | Same messages and JSON keys apart from device naming (README:367-369) | both | iOS+Android | none (session only) | |
| X-014 | `simulator ensure` vs `emulator ensure` (stdout, `--json`) | new and reused device | stdout is only the UDID / serial; `--json` records comparable; stderr human line on both (README:373-375; docs/android.md:166) | both | iOS+Android | none (device lifecycle only) | |
| X-015 | `simulator sessions` vs `emulator sessions --json` | one Grantiva device each | Comparable records; timestamps ISO 8601 on both (brief C22) | both | iOS+Android | none (device lifecycle only) | |
| X-016 | `simulator teardown --json` vs `emulator teardown --json` | own device | Comparable result keys (help: simulator_teardown.txt, emulator_teardown.txt) | both | iOS+Android | none (device lifecycle only) | |
| X-017 | `doctor` and `doctor --json` | `--platform ios`, `--platform android` | Same check record keys and status words (README:380) | both | iOS+Android | none (host checks) | |
| X-018 | ownership refusal | second run on an owned device | Same message structure; iOS names `grantiva simulator ...`, Android `grantiva emulator ...` (brief A10) | both | iOS+Android | .maestro/01-browse.yaml | |
| X-019 | failure output | element not found (NEW:02-exact-negative) | Same failure line structure and remediation (`Run grantiva hierarchy ...`) (brief C21) | both | iOS+Android | NEW:02-exact-negative | |
| X-020 | MCP `grantiva_context` | live session | Same sections; `[Simulator]` vs `[Emulator]`, Xcode vs Android SDK (docs/mcp.md:64) | both | iOS+Android | .maestro/01-browse.yaml (keep-alive) | |
| X-021 | MCP UI tools results | tap, swipe, type, a11y_tree | Same result shape (tree JSON) on both (docs/mcp.md:49-55) | both | iOS+Android | NEW:20-park-deeplinks | |
| X-022 | MCP `grantiva_vrt_capture` | live session and no session | Same JSON as `diff capture --json` on each platform (docs/mcp.md:88) | both | iOS+Android | grantiva.yml screens / grantiva-android.yml screens | |
| X-023 | `--timeout` kill message | NEW:18-long-wait `--timeout 30` | Same message on both; no stray colon (obs) | both | iOS+Android | NEW:18-long-wait | |
| X-024 | `--logs` prefix | flow 08 | `[log]` prefix and interleaving identical in form (README:93) | both | iOS+Android | .maestro/08-caching.yaml | |

## Counts (self-check)

| section | CLI | iOS | Android | iOS+Android | total |
|---|---|---|---|---|---|
| CLI rows (CLI-) | 153 | 0 | 0 | 0 | 153 |
| iOS rows (IOS-001..151, incl. 2.0.1 MCP rows IOS-099..116) | 0 | 150 | 0 | 0 | 150 |
| Android rows (AND-001..128, incl. 2.0.1 MCP rows AND-093..105) | 0 | 0 | 128 | 0 | 128 |
| Flow-command rows, iOS (IOS-201..239) | 0 | 39 | 0 | 0 | 39 |
| Flow-command rows, Android (AND-201..239) | 0 | 0 | 39 | 0 | 39 |
| MCP grid (MCP-) | 22 | 28 | 27 | 5 | 82 |
| Brief rows (B-) | 131 | 48 | 27 | 24 | 230 |
| Carried findings (N-) | 1 | 5 | 5 | 7 | 18 |
| Cross-platform (X-) | 0 | 0 | 0 | 24 | 24 |
| **all** | 307 | 270 | 226 | 60 | 863 |

MCP-related rows: 82 grid rows plus the 31 kept 2.0.1 MCP rows (IOS-099..116, AND-093..105) = 113. 2.0.1 rows: 343 in the
2.0.1 file (the plan's 374 and the spec's 405 do not match the file); 331 kept (of them 105 marked `(changed)`), 12 dropped
(listed under Verdicts and slices).

Checks run on this file: every row has 8 cells, a non-empty expected text with a source, an empty result; every
non-CLI row names a flow (or `none (<reason>)`); IDs unique; every `NEW:` flow and `NEW:cfg/` config is specified in
`2026-10-11-round1-demo-flows.md`.
