# Changelog

## v1.9.0 — 2026-09-02

### Added
- **`grantiva console analytics`** — the analytics dashboard from the terminal. `overview [--days]` (totals, success rate, unique devices, average risk, latest events), `events` (the paginated event log with `--page`, `--per-page`, `--from`/`--to`, `--device`, `--type`), `risk [--range 1d|7d|30d|90d]` (risk distribution, critical-risk devices, recent suspicious activity), `compliance [--period] [--all]` (compliance rate, violation counts, non-compliant devices), and `export --data devices|events [--period] [--out]` (CSV, to stdout or a file). Windows and event types the server would silently ignore are rejected up front. Needs a key with `analytics:read`; export needs `analytics:export`.
- **`grantiva console apps`** — register and manage the apps attesting under the org: `list`, `get`, `register <bundle-id> --team-id`, `update`, `delete`, `activate`, `deactivate`, `set-primary`. Apps are addressable by bundle ID or UUID. Bundle and Team ID are fixed at registration; the primary app and the last app cannot be deleted, and deleting an app removes its devices, flags and history, so `delete` prompts (or needs `--yes`).
- **`grantiva console claims`** — the custom claims minted into device JWTs: `list`, `get`, `create <key> --type static|conditional|dynamic|external`, `update`, `delete`, `reorder <key...>`, and two evaluators: `test` (an unsaved definition) and `preview` (a saved claim), both against a simulated device (`--country`, `--risk-score`, `--jailbroken`, `--device-model`, `--os-version`, `--data k=v`, …). Rule and configuration JSON is passed inline or as `@file.json`. Claims are addressable by key or UUID.
- **`grantiva console vrt`** — close the loop a pipeline opens with `grantiva ci run`: `runs list|get`, `screen accept|flag|reset <project> <run> <screen...>`, `approve <project> <run> [--accept-all]` (accepted screens become the branch baselines; flagged ones keep the old baseline), and `reject`. Run detail now shows each screen's review state and how many still await review. Needs `vrt:read` / `vrt:write`.
- **`grantiva console releases`** — author What's New release notes from a release pipeline: `list [--app]`, `get`, `create <app> <version> --title --body|@file.md [--publish]`, `update`, `publish`, `unpublish`, `delete`. Needs a key with the new `release_notes:read` / `release_notes:write` scopes.
- **`grantiva console feedback`** — triage feature requests as the team: `list` (`--status`, `--app`, `--search`, `--sort votes|newest|oldest`, paging), `get` (the full comment thread), `set-status <id> <status>`, and `comment <id> --body|@file` (devices following the thread get a push). Needs `feedback:read`, and the new `feedback:manage` scope for the staff actions.
- **`grantiva console support`** — work tickets: `list` (`--status`, `--priority`, `--app`, `--search`, paging), `get` (the conversation), `reply <id> --body|@file` (moves the ticket to awaiting_reply and emails the submitter), `set-status`, and `set-priority`, which the dashboard could not do.
- **`grantiva console webhooks`** — `list`, `create <url> --event …` (the signing secret is shown once), `enable`, `disable`, `update`, `delete`, `test` (exits 1 when the endpoint fails), `deliveries`, `retry`, and `events` (the subscribable event types). Event names are validated before the request.
- **`grantiva console alerts`** — `rules list|create|update|delete|deliveries` for risk alert rules, `failure-rate get|set|history` for the attestation failure-rate alert, and `notifications get|set name=on|off …` for which events email the org admin.
- **`grantiva console keys`** — `list`, `create <name> --scope …` (raw key shown once), `rotate [--grace-days]`, `revoke`. A key can only create keys with scopes it holds itself; the server's refusal is shown verbatim.
- **`grantiva console team`** — `members`, `invites`, `invite <email> [--role]`, `revoke-invite`, `remove`. Keys cannot remove admins or the owner.
- **`grantiva console audit list`** and **`grantiva console org settings get|set-name`, `org usage`, `org billing show`**. Team mutation, the audit log, and billing need the Enterprise-only `admin:*` scopes on a key.
- **`grantiva console open [area]`** — open the dashboard in the browser at an area (`flags`, `devices`, `keys`, …), on dev or production to match the API the CLI is signed in to. `--json` prints the URL instead.
- **`grantiva console devices`** — `list` with server-side filters (`--risk-min/--risk-max`, `--jailbroken/--no-jailbroken`, `--app`, `--search`, paging) and `get <key-id>` for a device's profile and recent events. Needs a key with `devices:read`.
- **`grantiva console`** — the dashboard from the terminal, starting with feature flags. `console flags` (alias `featureflags`) covers `list`, `get`, `create`, `update`, `on`/`off` (per-environment with `--env`), `delete`, targeting `rules list|add|update|delete|reorder`, per-device `overrides list|add|delete`, `history`, `watch` (live SSE config stream), and `eval` — a dry-run of a flag against a simulated device (`--os-version`, `--risk-score`, `--country`, `--custom key=value`, …) that renders the full rule trace: every rule in priority order with per-condition expected vs actual. `console envs` manages flag environments (`list|create|update|delete|reorder`). Flags are addressable by `flag_key` everywhere; UUIDs also work. All commands take `--json`; destructive verbs prompt on a TTY and require `--yes` otherwise. Rule conditions are given as repeated `--when attribute:op:value` or a `--conditions-json` array.
- The org-scoped flag endpoints (`/api/v1/org/flags`, `/api/v1/org/flag-environments`) require an API key carrying the `flags:read` / `flags:write` scopes; a 403 names the missing scope.

### Fixed
- A 403 from the flags API is no longer always reported as a missing scope. The backend uses 403 for plan limits too — `console flags rules add` on the Free tier (zero rules per flag) told you to mint a key with `flags:write`, which you already had. The server's own message ("Targeting rule limit reached (0 per flag for Free tier)…") is shown instead; the scope hint remains for a genuine scope failure.
- `~/.grantiva/auth.json` is now written with mode 0600. It holds a plaintext API key and was previously created with default permissions.

## v1.8.0 — 2026-08-29

### Fixed
- **`--ready-file` was unusable as documented.** The prescribed waiter — `while [ ! -f "$f" ]; do sleep 0.2; done` — was broken from both ends. A file left by a previous run was never cleared, so the waiter returned instantly and read the *previous* run's verdict: CI proceeding on a stale `passed` against a run that never started. And a failure before the runner started (no project, bad scheme, build failure, no simulator) wrote no file at all, so the same loop — which has no timeout — wedged the job until CI's global limit. The file is now deleted at startup, before any project, build, or simulator work, so its existence always means *this* run reached a terminal state; and a terminal status is written on every exit path, with a setup failure recording `failed`. An unwritable or non-file `--ready-file` path is now rejected at startup rather than at the end of a long suite, when the verdict has nowhere to go.
- **`grantiva simulator teardown --udid "" --force` reported success.** This is the unset-shell-variable case: `--udid "$UDID"` with `UDID` unset. An empty string is non-nil, so it satisfied the "pass one of `--session-id`/`--udid`" check, matched no process, released no lease, and exited 0 printing `No processes were holding .` — the script concluded it had reclaimed the device and the real failure surfaced much later. `--udid` is now checked for the 8-4-4-4-12 hex form simctl issues (`--udid not-a-udid-at-all` was equally accepted before), and a blank `--session-id` is rejected the same way. Validation is shape-only and deliberately does not require the device to still exist: reclaiming an already-deleted simulator — killing what it stranded, breaking its lease — is what `--force` is for.
- **`grantiva doctor` always exited 0, and reported a broken toolchain as passing.** There was no exit-code path at all, so `grantiva doctor || exit 1` as a CI preflight could never fire; a failing required check now exits non-zero, in both output modes. Optional checks (no booted simulator, no `grantiva.yml`, not authenticated) stay advisory and do not affect the exit code. The Xcode check also echoed `$DEVELOPER_DIR` back without verifying it — `DEVELOPER_DIR=/nonexistent grantiva doctor` printed `✓ Xcode /nonexistent` — and the version check passed on empty output. Both now fail, with a fix line.
- **`grantiva doctor` wrote ANSI escapes into redirected output.** `grantiva doctor > log.txt` produced a file full of raw SGR sequences. Colour is now emitted only when stdout is a terminal, and `NO_COLOR` suppresses it.

### Changed
- **Diagnostics and program output are now on separate streams throughout the CLI.** Every command used to write both through `print`, so progress narration, warnings, and results all landed on stdout together — the arrangement that produced the 1.7.2 `simulator ensure` bug, where `udid=$(grantiva simulator ensure …)` captured a sentence instead of an identifier. The split is now structural rather than per-command: results go to stdout via a dedicated emitter, and everything else goes through Swift Logging to stderr. `grantiva doctor --json | jq` and `$(grantiva simulator ensure …)` see only the result; a terminal still shows the narration.
- Log lines are rendered for a terminal rather than for a log store. At the default level a diagnostic is the bare message, exactly as it read before — no timestamp, level, or label. Warnings are prefixed `Warning:` and errors `Error:`; timestamps, labels, and metadata appear only under `--verbose`.
- The "Waiting for simulator capacity" line is now logged as a warning rather than as narration, so it reads `Warning: Waiting for simulator capacity (4/4): …`. It is the only explanation for a stall that runs to `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS` — ten minutes by default, and `--quiet` would otherwise have made a host at its simulator limit indistinguishable from a hang.
- `grantiva simulator teardown --force --json` now reports `reclaimed`, distinguishing a teardown that killed a stranded runner or broke a lease from one that found the device already free. Both remain exit 0.

### Added
- **`--verbose`** raises diagnostics to debug level, with timestamps, the logger label, and metadata. Every subprocess Grantiva runs is logged there — `$ xcrun simctl list devices --json` and its exit status — which is the first thing anyone asks for when simctl or xcodebuild misbehaves.
- **`--quiet`** silences progress narration on stderr; warnings and errors still print. Neither flag touches stdout, so `grantiva doctor --json --quiet | jq` is still valid JSON.

## v1.7.2 — 2026-08-29

### Fixed
- **`grantiva simulator ensure` printed prose where a UDID was expected.** stdout carried `Created iPhone 17 (UDID) — Booted`, so `udid=$(grantiva simulator ensure --name "iPhone 17")` captured a sentence rather than an identifier — and the failure surfaced later, as an unusable `--device` argument. Being captured that way is the reason the command exists: it replaces a `simctl list -j` + `create` + `bootstatus` shell function whose output was a UDID. stdout is now the UDID alone; the human-readable line moved to stderr, where a terminal shows it and a command substitution ignores it. `--json` is unchanged.

## v1.7.1 — 2026-08-29

### Added
- **A prebuilt GrantivaAgent build for iOS 27 simulators.** The embedded caches covered iOS 26.2 and 26.4 only, so a first run against an iOS 27 simulator rebuilt WebDriverAgent from scratch — several minutes, and repeated on every fresh CI machine. iOS 27.0 is now cached alongside them. Bundles grantiva-runner 1.1.18-grantiva.7 (same runner code as grantiva.6; the version differs so upgrading clients re-extract and pick up the new cache).

## v1.7.0 — 2026-08-29

### Fixed in packaging
- **The Homebrew formula declared a non-SemVer version.** The release workflow copied the git tag verbatim into the formula's `version` field, publishing `version "v1.6.5"` while `grantiva --version` printed `1.6.5`. SemVer 2.0.0 sanctions the `v` prefix for version-control tags only, not for version strings. The tag and the release asset keep the prefix; the formula's `version` no longer has it. The release now also refuses to publish when the tag disagrees with the version compiled into the binary.

Bundles grantiva-runner 1.1.18-grantiva.6, which fixes three bugs that made flows **pass while asserting nothing**. If you have flows using `launchApp` `arguments:`, a `visible:` selector with both `id:` and `text:`, or a `text:` match that could collide with a longer label, re-read them: they may have been green for the wrong reason.

### Fixed in the bundled runner
- **Launch-argument keys got an extra leading dash.** `arguments: { "--auto-advertise": true }` reached the app as `---auto-advertise`, so the flag was never seen and the flow passed anyway. A key that already starts with `-` is now passed through verbatim. The list form (`arguments: ["--auto-advertise"]`) is accepted too.
- **`visible:` combined `id:` and `text:` with OR, not AND.** A selector naming both matched an element satisfying *either*, so a bogus `id:` alongside a matching `text:` passed. The WDA fast path now ANDs them, matching what the page-source path always did.
- **`text:` matching is case-insensitive and unanchored**, so `text: "Advertising"` matched the label "Not advertising". The default is unchanged — every existing flow keeps working — but `exact: true` on a selector now matches the full string, case-sensitively.
- **Intermittent "Failed to create session for app"** right after a previous session was killed. The WDA session request now retries with a status probe and backoff, rejects a response carrying no session id, and reports the underlying cause.
- **An element below the fold reported "Element not found".** The failure now distinguishes a selector that matched nothing from one that matched an off-screen element, and points at `scrollUntilVisible`.
- Skipped flows were never written to the report index and stayed `pending` in `report.json` forever.
- The run summary table printed twice on a single-device run.

### Added
- `grantiva simulator teardown --udid <UDID> --force` reclaims a simulator by live process inspection instead of the session ledger. It kills the `grantiva-runner`, WebDriverAgent `xcodebuild test-without-building`, and `simctl diagnose` processes holding that device, breaks the simulator lease, and clears any stale capacity record — the case `--session-id` could never serve, because a stranded run leaves `sessions.json` empty while the device is still owned. `--session-id` and `--udid` are mutually exclusive.
- `grantiva run --ready-file <path>` writes a single file, atomically, once every flow has reached a terminal state, with the run's terminal status inside it. A waiter can be `while [ ! -f "$f" ]; do sleep 0.2; done` instead of polling the incrementally rewritten `report.json`. Useful with `--keep-alive`, where the session deliberately outlives the flows.
- `grantiva run --env KEY=VALUE` (repeatable) sets environment variables for the app under test, forwarded through the flow's existing `launchApp` `environment:` field. A malformed pair is rejected with a clear error.
- The simulator lease now records who owns it — grantiva's pid, the runner's pid, and whether the run is `--keep-alive`. "Simulator … is already owned by another Grantiva run" now names that process and the command that frees it.

### Changed
- `grantiva simulator ensure` needs only `--name`. The device type is inferred from the name (`--name "iPhone 17"`), the runtime defaults to the newest installed one, and the simulator is booted by default (`--no-boot` opts out). `--device-type` and `--runtime` remain as optional overrides; when neither is given, an existing simulator with that name is reused as-is. The `grantiva_sim_ensure` MCP tool requires only `name` for the same reason.
- grantiva-runner is spawned into its own process group, and SIGINT/SIGTERM are forwarded to that whole group. Interrupting a run — including `kill -INT` against a backgrounded `--keep-alive` run, which a shell starts with SIGINT ignored and which therefore used to be uninterruptible — now reaps grantiva-runner, WebDriverAgent, and any `simctl diagnose` it started, then releases the lease.
- With `--report-dir`, failure screenshots and trace artifacts are written under that directory only; nothing is written to `./.grantiva/captures`.
- Flow failures are reported against the path the user passed, not the temporary staged copy grantiva hands the runner.

## v1.6.5 — 2026-08-22

### Added
- Grantiva records every simulator it creates in a durable provenance ledger, and the new `grantiva simulator cleanup` deletes created simulators that are shut down and no longer part of an active managed session.

### Changed
- `grantiva simulator teardown --session-id` now deletes Grantiva-created simulators outright and only shuts down pre-existing devices the session booted. JSON output reports a `deleted` flag per session.

### Fixed
- Concurrent `grantiva simulator ensure` runs for the same new name no longer race into creating duplicate same-name simulators; the look-up/create pair is serialized across processes.

## v1.6.4 — 2026-08-21

### Added
- Host-wide admission control limits Grantiva-managed booted simulators to four by default and queues additional boots with a configurable timeout.
- `grantiva simulator sessions` reports active capacity owners, and `grantiva simulator teardown --session-id` shuts down only simulators owned by that ticket/session.
- `GRANTIVA_SESSION_ID`, `GRANTIVA_MAX_SIMULATORS`, and `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS` configure durable ticket ownership and host capacity.

### Changed
- Grantiva diagnostics now use Swift Logging while structured command results remain on stdout.

## v1.6.2 — 2026-08-20

### Fixed
- `diff capture` now repairs the runner's exact one-column trailing crop when the captured height matches the selected simulator target. Capture output reports the selected simulator and its point/pixel dimensions.

## v1.6.1 — 2026-08-20

### Fixed
- Simulator display environment width and height are now interpreted as pixels and divided by display scale when reporting point dimensions.

## v1.6.0 — 2026-08-20

### Added
- `grantiva simulator ensure` and `grantiva simulator delete`, with matching `grantiva_sim_ensure` and `grantiva_sim_delete` MCP operations. Named provisioning is idempotent, rejects incompatible or ambiguous names, waits for boot readiness, and reports point/pixel display geometry.

## v1.5.5 — 2026-08-20

### Added
- `--derived-data-path <path>` isolates Xcode products and intermediates for `build build`, `build install`, `run`, `ci run`, and visual-diff build workflows.

### Fixed
- Product-path discovery now uses the same build settings as the preceding build, ensuring Grantiva installs the `.app` from the requested DerivedData directory.
- A command-line DerivedData path overrides a conflicting `-derivedDataPath` in `grantiva.yml` while preserving all other `build_settings`.

## v1.5.4 — 2026-08-20

### Added
- `grantiva build install --no-launch` builds and installs an app without launching it, enabling deterministic fixture and defaults seeding before first launch.
- `grantiva build install --json` now reports the scheme, bundle ID, app path, simulator name and UDID, and installed data-container path.

### Changed
- The existing `grantiva build install` behavior remains launch-by-default when `--no-launch` is omitted.

## v1.2.0 — 2026-04-22

### Added
- `grantiva run --logs` streams simulator app logs (`xcrun simctl spawn log stream`) interleaved with flow output, prefixed with `[log]`. Default predicate is auto-derived from the resolved bundle ID.
- `--logs-predicate '<NSPredicate>'` overrides the default predicate for custom log filters.
- `--logs-level default|info|debug` passes through to `simctl`.
- Log streaming lifecycle is deferred — starts after simulator boot, stops on any exit path (success, failure, SIGINT, keep-alive release).

## v1.1.0 — 2026-04-22

### Added
- `grantiva run --keep-alive` holds the GrantivaAgent session open after flows complete. Writes a session file to `~/.grantiva/runner/sessions/<udid>.json` with port + session ID and blocks on Ctrl-C. The app stays frozen where the flow left it.
- `grantiva hierarchy` reads the keep-alive session file and dumps the live UI accessibility tree over HTTP (`/session/<id>/source`). Pure read, no relaunch. Supports `--format xml|json` and `--udid <UDID>` for multi-sim setups. Fails fast if no session is live rather than starting one behind the user's back.

### Notes
- Keep-alive + hierarchy together unblock agent-driven flows: run a flow, hold state, read hierarchy, synthesize a corrected selector, re-run.
- Runner rev bumped to `1.1.12-grantiva.3`.

## v1.0.0 — 2026-04-22

### Added
- **GrantivaAgent** — the WebDriverAgent embedded in the CLI now identifies as `GrantivaAgent` on the simulator home screen and in every runner log line. `CFBundleDisplayName` injected post-build into the test runner `.app`.
- Runner binary version now reports `1.1.12-grantiva.N` via `--version` so Grantiva-side rebuilds on the same upstream tag are distinguishable.
- `GRANTIVA_REV` env var in `scripts/build-runner.sh` lets us cut successive runner revisions without bumping upstream.

### Changed
- Runner log output — "WDA", "WebDriverAgent" replaced with "GrantivaAgent" in every user-visible string (`Starting…`, `Building…`, `already installed`, etc.). Internal identifiers (xctest scheme, bundle ID, derived data paths) unchanged so xcodebuild integration remains working.

## v0.9.1 — 2026-04-22

### Fixed
- `RunnerManager.runnerVersion` bumped to force re-extraction of the embedded runner tarball on upgrade. v0.9.0 shipped the new tarball but kept the old version string, so upgrading users silently kept running the old runner.

### Added
- CI guard that extracts the embedded tarball in `.github/workflows/ci.yml`, reads the binary's `--version`, and fails the build if it doesn't match `RunnerManager.runnerVersion`. Prevents future version-mismatch regressions.

## v0.9.0 — 2026-04-22

### Changed
- Embedded runner upgraded from `maestro-runner v1.0.9` to `v1.1.12`. 61 upstream commits inherited, including iOS WDA session lifecycle fixes, swipe coordinate fixes, `assertNotVisible` polling, `clearKeychain`, and `xcrun devicectl` install timeouts.

### Fixed
- `stopApp` and `killApp` are now idempotent — swallow `TerminateApp` errors when the app isn't running, matching upstream Maestro semantics. Flows starting with `- stopApp` no longer fail if the app hasn't been launched yet.

### Removed
- HTML, JUnit, and Allure report generation. Grantiva only consumes `report.json`; the other formats were cluttering user project directories with unused artifacts.
- Banner/footer output referencing upstream branding.
- Update check to `open.devicelab.dev`.

## v0.8.12 — 2026-04-22

### Fixed
- `grantiva run` no longer pre-launches the app before handing control to the flow. Flows own app lifecycle via `launchApp` / `clearState` / `stopApp`. The pre-launch was creating a process WDA had no handle on, causing any flow starting with `stopApp` to fail instantly with `Failed to stop app: <bundleId>`.

## v0.8.11 — 2026-04-22

### Fixed
- The built `.app` path is now forwarded to the runner as `--app-file` automatically. Flows using `clearState` (which uninstalls + reinstalls on iOS) no longer fail with `clearState on iOS requires --app-file to reinstall the app after uninstalling` when the user didn't pass `--app-file` on the CLI.

## v0.8.10 — 2026-04-22

### Fixed
- `xcodebuild -destination` now uses `id=<UDID>` instead of `name=<simulator name>`. On machines with multiple simulators sharing a name (or where the name-matched simulator's runtime doesn't satisfy the scheme's deployment target), xcodebuild no longer fails with `Unable to find a device matching the provided destination specifier` despite `simctl` having just booted the right simulator.
- Dropped the misleading hardcoded `name=iPhone 16` default argument on `XcodeBuildRunner.build` / `.test`.
