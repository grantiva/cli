# CLI slice triage (independent confirmation)

Binary `~/.grantiva-qa/bin/grantiva` 2.0.1 (c8dc86d), `GRANTIVA_SESSION_ID=qa-cli`, no API key. Each repro was re-run once
in a fresh scratch directory. Device repros used a new qa-cli-1 (BC308750-…, iPhone 17, iOS 26.0, since torn down) and
`com.apple.Preferences` in place of Landmarks, so no app build was needed. Not re-run, by rule: CLI-F23 (runner install)
and CLI-F04 (emulator ledger); both were judged from evidence, source, and the live ledger. CLI-F21 was judged from source
and evidence: a machine-wide keep-alive session from this run would have been visible to the other agents' MCP servers.

Format: `ID | verdict | severity | title | duplicate-of | evidence from this re-run`

## CLI findings

CLI-F01 | CONFIRMED | docs | `run --continue-on-failure`, `--snapshot`, `--timeout` (30 s minimum) are documented only in help | - | grep finds 0 hits in README, docs/*.md, and CHANGELOG; `run --timeout 0` gives "--timeout must be at least 30 seconds." (exit 64), and help states no minimum.
CLI-F02 | CONFIRMED | contract | `runner stop` with no session prints narration on stdout | - | `runner stop 2>/dev/null` in an empty dir printed "No active session found." to stdout, exit 0.
CLI-F03 | CONFIRMED | ux | `auth logout` claims to remove credentials that never existed | - | With no ~/.grantiva/auth.json, it printed "Logged out. Credentials removed from ~/.grantiva/auth.json", exit 0.
CLI-F04 | CONFIRMED | wrong-result | Emulator ledger keeps a record for a user-started emulator, and `teardown --all` would kill it | - | Live started.json has emulator-5554/Pixel_8_API_35/pid 19482 (dead), and `emulator sessions` shows it; the real emulator-5554 is qemu pid 49817 (started Oct 7). The stale-record guard in EmulatorManager.teardown (:350-355) drops a record only when the AVD differs, and here it is the same AVD, so `teardown --all` would `adb emu kill` the user's emulator.
CLI-F05 | CONFIRMED | ux | `run` with no config says "No screens or flows configured in grantiva.yml", even on Android | - | gradle-only + `run --no-build --platform android` gave that exact message (exit 1). The CHANGELOG "naming the missing file" text only covers the other-config-exists case, but the message names the wrong file and the wrong cause.
CLI-F06 | CONFIRMED | ux | `doctor` with both an Xcode project and Gradle settings requires both toolchains | - | detect/both: doctor failed on JDK, "9 passed · 5 optional · 1 failed", exit 1. DoctorCommand.platformSelection marks every detected platform required.
CLI-F07 | CONFIRMED | ux | `init` in an empty directory silently writes placeholder `scheme: MyApp` / `simulator: iPhone 16` | - | exit 0, "Created grantiva.yml", file holds both placeholders with no warning.
CLI-F08 | CONFIRMED | wrong-result | `--report-dir` (and `--timeout`, `--continue-on-failure`) ignored for `screens:` runs | - | A `screens:` run with `--report-dir out` left only out/captures/*.png; report.json/junit went to /var/folders/…/grantiva-report-F056ABBE…, which no longer existed after exit. RunCommand.swift:275-289 passes no reportDir/timeout/failFast.
CLI-F09 | CONFIRMED | ux | Misspelled or unknown config keys are silently ignored | - | unknown-keys.yml (`schem:`, `screen:`) gave only "No screens or flows configured in grantiva.yml", with no key warning.
CLI-F10 | CONFIRMED | ux | `doctor` reports an unparsable config as "Found" | - | `doctor --platform android` showed "✓ grantiva-android.yml  Found"; `run` in the same dir failed with "could not be parsed: 5:3".
CLI-F11 | CONFIRMED | contract | Invalid `GRANTIVA_PLATFORM` is ignored by `doctor` and `init` | CLI-F06 | GRANTIVA_PLATFORM=windows: doctor exit 0, init exit 0 and wrote grantiva.yml; `run` rejected it with 'GRANTIVA_PLATFORM is "windows"; expected ios or android.'
CLI-F12 | CONFIRMED | contract | `init` accepts the other platform's flags silently | CLI-F06 | `init --platform android --scheme X` and `init --platform ios --application-id a.b` both exit 0 and write config; `run --platform ios --application-id a.b` rejects the flag by name.
CLI-F13 | CONFIRMED | ux | Error remediation names commands that do not exist (`grantiva sim boot`, `grantiva ui a11y`) | - | Both strings are in GrantivaError.swift:29/:33; `grantiva sim boot "iPhone 16"` and `grantiva ui a11y` each exit 64 ("unexpected arguments"); DoctorRunner.swift:98 suggests `simctl boot "iPhone 16"`.
CLI-F14 | CONFIRMED | contract | `record --frames-at a,b` records the full duration before rejecting the value | - | `--duration 5 --frames-at a,b` wrote a 4 MB video, then "--frames-at must contain non-negative integer milliseconds", exit 1 (not 64) after 8 s.
CLI-F15 | CONFIRMED | contract | `record` passes simctl's narration through to stdout | CLI-F02 | stdout began with "Recording completed. Writing to disk." and "Wrote video to: …" before Grantiva's own result lines. Also seen: both `--frames-at 500,1500` frames were reported as "-> 0ms" (not triaged further).
CLI-F16 | CONFIRMED | ux | `record --output` without an extension records, then fails with bare "Error: Cannot Open" | CLI-F14 | `--output $S/r16` wrote a 96 KB file, then printed "Error: Cannot Open", exit 1.
CLI-F17 | CONFIRMED | contract | `console webhooks create --event` names are not validated before the request | - | With a bogus key, `--event not.an.event` reached the server ("Not authenticated"); `analytics events --type bogus` was rejected locally (exit 64). validate() checks only blank events and the https URL.
CLI-F18 | CONFIRMED | contract | `grantiva mcp` fails to start without a config and a live runner session | - | With grantiva.yml but no session: exit 1 "No active runner session at …/.grantiva/session.json" and no initialize response; with no config: "No grantiva.yml or grantiva-android.yml found".
CLI-F19 | CONFIRMED | wrong-result | MCP VRT tools shell out to whatever `grantiva` is on PATH | - | Live `grantiva_vrt_compare` returned isError "Unknown option '--platform'" from /opt/homebrew/bin/grantiva 2.0.0; VRTTools.swift builds literal "grantiva diff …" strings.
CLI-F20 | CONFIRMED | wrong-result | MCP `grantiva_context` reports the first booted simulator, not the session's device | - | Live call: [Simulator] udid B27D7D31-… (iPhone 17 Pro) while [Runner Session] udid BC308750-… (qa-cli-1).
CLI-F21 | CONFIRMED | wrong-result | MCP server attaches to any keep-alive session on the machine | - | Not re-run live. MCPServer.loadActiveSession (:143-163) falls back to `KeepAliveSessionStore().locate()` (newest live session machine-wide) and checks no project, bundle, or platform; the evidence jsonl shows the other project's tree.
CLI-F22 | CONFIRMED | contract | MCP `grantiva_script` returns success when every step is invalid | - | Live call with [{"bogus":1},5]: isError absent, "Step 1: unknown action, skipped | Step 2: skipped (not an object)" plus the hierarchy.
CLI-F23 | CONFIRMED | crash | Runner re-extract deletes all of ~/.grantiva/runner (including live lease locks) before extracting, and traps if the resource bundle is missing | - | Not re-run. RunnerManager.swift:138 does `removeItem(atPath: baseDir)` (which holds locks/, reports/, the xcconfig) before `extract`; the evidence shows SIGTRAP rc=133 "unable to find bundle named grantiva_GrantivaCore" and no runner left afterward. The trap needs a binary without its bundle; the lock deletion happens on every re-extract.
CLI-F24 | CONFIRMED | contract | `swipe: diagonal` in `screens:` is accepted at parse time and fails only on device | - | On Settings the runner booted, launched, and then failed "Invalid swipe direction (cause: invalid direction: DIAGONAL)", exit 1.
CLI-F25 | CONFIRMED | ux | `simulator sessions --json` / `emulator sessions --json` timestamps are 2001-reference seconds | - | "acquiredAt" : 813129327.501302, "startedAt" : 813271244.347498.
CLI-F26 | CONFIRMED | ux | `doctor --platform android` with a bogus ANDROID_HOME silently reports a different SDK | - | `ANDROID_HOME=/nonexistent` gave "✓ Android SDK /Users/kyle/Library/Android/sdk" and no mention of ANDROID_HOME; the fallback is documented but the stale value is not reported.
CLI-F27 | CONFIRMED | wrong-result | Maestro parser rejects README-supported `swipe: {direction:}`, `extendedWaitUntil: {visible:}`, and bare `waitForAnimationToEnd` | - | All three fail before device work: 'grantiva.yml could not be parsed: invalidArgument("Unsupported Maestro command \'swipe\' at <input>:4")' (likewise for the other two); the Swift enum and `<input>` leak into the message.
CLI-F28 | CONFIRMED | wrong-result | Maestro `tapOn: {id:}` is parsed as a text tap | - | `tapOn: {id: "General"}` on Settings generated `tapOn: text="General"` and reported "Tap on \"General\"".
CLI-F29 | CONFIRMED | wrong-result | `wait: N` in `screens:` does not wait N seconds | - | `- wait: 3` became `waitForAnimationToEnd` and took 734 ms, though the summary line says "Wait 3.0s".
CLI-F30 | CONFIRMED | wrong-result | Under `run --flow`, bare Maestro `scroll` and header-appId `setPermissions` fail in the runner | - | On Settings: "✗ scroll — Invalid scroll direction (cause: invalid direction: )" and "✗ setPermissions — No app ID for permissions (cause: no appId specified)". Also seen: `--flow` with no config demands `--bundle-id` despite the flow's `appId:` header.

## Proposed issues (CLI), by severity

1. [crash] Install the runner without deleting live lease locks, and fail cleanly when the resource bundle is missing (CLI-F23)
2. [wrong-result] Never record, or later tear down, an emulator Grantiva did not boot itself (CLI-F04)
3. [wrong-result] Restrict the MCP server to its own project's runner session (CLI-F21)
4. [wrong-result] Honour --report-dir, --timeout, and --continue-on-failure for screens runs (CLI-F08)
5. [wrong-result] Run MCP VRT tools with the server's own executable (CLI-F19)
6. [wrong-result] Report the session's device in grantiva_context (CLI-F20)
7. [wrong-result] Accept the standard Maestro swipe, extendedWaitUntil, and waitForAnimationToEnd forms, and make README match unsupported-command handling (CLI-F27, CLI-DOCS-F04)
8. [wrong-result] Match Maestro tapOn id against the accessibility identifier, not label text (CLI-F28)
9. [wrong-result] Make `wait: N` wait N seconds (CLI-F29)
10. [wrong-result] Support bare `scroll` and header-appId `setPermissions` in `run --flow` (CLI-F30)
11. [contract] Start the MCP server without a live runner session or config file (CLI-F18)
12. [contract] Apply run's platform validation in doctor and init (ambiguous project, bad GRANTIVA_PLATFORM, other-platform flags) (CLI-F06, CLI-F11, CLI-F12)
13. [contract] Keep narration off stdout in runner stop and record (CLI-F02, CLI-F15)
14. [contract] Validate record arguments (--frames-at, --output extension) before recording (CLI-F14, CLI-F16)
15. [contract] Reject unknown swipe directions when parsing screens (CLI-F24)
16. [contract] Validate webhook event names locally and add `console webhooks events` (CLI-F17, CLI-DOCS-F07)
17. [contract] Return isError from grantiva_script when steps are invalid (CLI-F22)
18. [ux] Name the platform's missing config file when run has nothing to do (CLI-F05)
19. [ux] Warn about unknown keys in grantiva.yml (CLI-F09)
20. [ux] Flag an unparsable config in doctor (CLI-F10)
21. [ux] Point error remediation lines at commands that exist (CLI-F13)
22. [ux] Emit Unix or ISO 8601 timestamps in sessions --json (CLI-F25)
23. [ux] Report a stale ANDROID_HOME in doctor (CLI-F26)
24. [ux] Warn when init writes placeholder scheme and simulator values (CLI-F07)
25. [ux] Report "not logged in" from auth logout when there are no credentials (CLI-F03)
26. [docs] Document run's --continue-on-failure, --snapshot, and --timeout minimum (CLI-F01)

## Docs findings

CLI-DOCS-F01 | CONFIRMED | docs | README runs `grantiva run --device "$udid" flows/`; run takes no positional, and --device is Android-only | - | README.md:353 has that line; `run --help` gives "USAGE: grantiva run <options>" and lists --device as "(Android)".
CLI-DOCS-F02 | CONFIRMED | docs | README says runner lifecycle commands have no JSON result, but all of them list --json | - | README.md:310-312 says so; runner start/stop/install/version --help each list --json, and `runner stop --json` emits {"status":"not_running"}.
CLI-DOCS-F03 | CONFIRMED | docs | README §Commands omits `emulator`, `console`, and `runner dump-hierarchy` and describes record/build as iOS-only | - | README.md:263-288 has 0 matches for emulator/console/dump-hierarchy; all three appear in help.
CLI-DOCS-F04 | CONFIRMED | wrong-result | README says unsupported Maestro commands are silently skipped, but the parser rejects them | CLI-F27 | `.maestro/back.yaml` + `diff capture` failed: "Unsupported Maestro command 'back' at …/back.yaml:5", exit 1.
CLI-DOCS-F05 | CONFIRMED | docs | `simulator cleanup` is described differently in README and help | CLI-DOCS-F03 | README: "Delete unavailable and stale Grantiva-managed simulators"; help: "Delete Grantiva-created simulators that are shut down and not part of an active session."
CLI-DOCS-F06 | CONFIRMED | docs | `simulator delete` and `simulator sessions` have no help abstract | CLI-DOCS-F03 | Both have an empty description column in `simulator --help`.
CLI-DOCS-F07 | CONFIRMED | docs | CHANGELOG lists `console webhooks events`, which does not exist | CLI-F17 | `console webhooks --help` lists list…retry with no `events`; CHANGELOG.md:76 lists it.
CLI-DOCS-F08 | CONFIRMED | docs | 2.0.1 binary ships features CHANGELOG lists under Unreleased | - | `--version` prints 2.0.1; Android/emulator are under `## Unreleased`, above `## 2.0.1 — 2026-10-07`.
CLI-DOCS-F09 | CONFIRMED | docs | android-environment.md implies Android `ci run` works on a self-hosted Mac, but it always refuses | - | `ci run --platform android` gave "Android baselines are local only until the Grantiva backend supports platforms; use local baselines".
CLI-DOCS-F10 | CONFIRMED | docs | docs/android.md §Devices contradicts itself on booting an existing AVD | - | docs/android.md:33-35 says "Only running emulators are considered by default", then "else a single existing AVD is booted".
CLI-DOCS-F11 | CONFIRMED | docs | Help overviews still describe the tool as iOS-only | - | "The Grantiva CLI for iOS developers.", "Run Maestro flows against a simulator.", "Build the app for a simulator using xcodebuild."
CLI-DOCS-F12 | CONFIRMED | contract | `hierarchy --json` is advertised but ignored; only --format selects output | CLI-DOCS-F02 | HierarchyCommand.swift never reads options.json (only `format` at :80, :101, :120), so `--json` alone yields XML.
CLI-DOCS-F13 | CONFIRMED | docs | No doc says `--ready-file` creates a missing parent directory | - | ReadyFile.swift:73-81 calls createDirectory(withIntermediateDirectories: true); README and help are silent.
CLI-DOCS-F14 | CONFIRMED | docs | No CLI doc lists all 22 MCP tools | - | tools-list-ios.jsonl has 22 tools. The "19" comes from the internal QA spec, not product docs, so only the missing full list is a product issue.

## Proposed issues (docs), by severity

1. [contract] Make `hierarchy --json` select JSON (or drop it), and correct README's JSON-mode statement for runner commands (CLI-DOCS-F12, CLI-DOCS-F02)
2. [docs] Bring README §Commands in line with help: add emulator, console, and runner dump-hierarchy; fix the cleanup wording; add delete/sessions abstracts; drop the iOS-only wording (CLI-DOCS-F03, CLI-DOCS-F05, CLI-DOCS-F06)
3. [docs] Fix the README `run --device "$udid" flows/` example (CLI-DOCS-F01)
4. [docs] Update help overviews to cover Android (CLI-DOCS-F11)
5. [docs] Move shipped Unreleased entries under the version that contains them (CLI-DOCS-F08)
6. [docs] State in android-environment.md that `ci run` refuses Android (CLI-DOCS-F09)
7. [docs] Resolve the AVD-boot contradiction in docs/android.md §Devices (CLI-DOCS-F10)
8. [docs] Document that --ready-file creates missing parent directories (CLI-DOCS-F13)
9. [docs] Publish the full MCP tool list (CLI-DOCS-F14)
(CLI-DOCS-F04 is folded into CLI issue 7 and CLI-DOCS-F07 into CLI issue 16.)
