# Changelog

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
