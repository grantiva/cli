# Grantiva CLI

The command-line tool for [Grantiva](https://grantiva.io) — the all-in-one platform for iOS and Android developers.

Currently features visual regression testing and agent-native UI automation. Captures screenshots of your app's screens, diffs them against approved baselines, and posts the results as GitHub Check Runs. Also streams UI hierarchy and app logs so AI agents can read, diagnose, and self-heal broken flows. Catch visual regressions before they ship — and let your agents fix them.

Android: `init`, `doctor`, `build`, `run`, `diff`, `hierarchy`, `record`, `runner start/stop`, `emulator`, and the MCP server (`grantiva mcp`) work against an Android emulator. See `docs/android.md`.

## Install

### Homebrew

```bash
brew install grantiva/tap/grantiva
```

### From source

```bash
git clone https://github.com/grantiva/cli.git
cd cli
swift build -c release
cp .build/release/grantiva /usr/local/bin/grantiva
```

**Requirements:** macOS 15+, Xcode 16+, Swift 6.1+

## Quick Start

```bash
# Check your environment
grantiva doctor

# Generate config
grantiva init

# Extract the embedded runner (once per install)
grantiva runner install

# Run Maestro flows against your simulator
grantiva run --flow flows/onboarding.yaml

# Authenticate with Grantiva for baseline storage + CI integration
grantiva auth login

# Run the full visual regression pipeline
grantiva ci run
```

## How It Works

1. **Boot** — boots the configured simulator
2. **Build** — builds the app with `xcodebuild` (or skip with `--app-file` / `--no-build`)
3. **Install** — installs the app on the selected simulator
4. **Launch** — the flow controls first launch via `launchApp`
5. **Navigate** — taps and swipes to each screen defined in `grantiva.yml`
6. **Capture** — screenshots each screen via GrantivaAgent
7. **Diff** — compares against baselines (pixel + CIE76 perceptual color distance)
8. **Upload** — sends results to [Grantiva](https://grantiva.io)
9. **Check Run** — posts a GitHub Check Run with before/after diffs

All UI automation runs through **GrantivaAgent** — a WebDriverAgent embedded in the CLI. No Accessibility permission needed, no Appium server, no Maestro install. Works headless on CI out of the box.

## Agent-Native Features

Grantiva is designed so AI agents can read, drive, and heal flows programmatically — not just by firing commands blind.

```bash
# Run a flow, keep the WDA session alive past completion, and stream app logs:
grantiva run --flow flows/onboarding.yaml --keep-alive --logs

# From another terminal (or a background task on CI), dump the live hierarchy:
grantiva hierarchy > state.xml
```

- **`--keep-alive`** — Holds the GrantivaAgent session open after flows complete. The app stays frozen in whatever state the flow left it. Ctrl-C (or `kill -INT` on a backgrounded run) releases it, reaping grantiva-runner, WebDriverAgent, and any diagnostics they started.
- **`--ready-file <path>`** — Writes that file once, atomically, when the run reaches a terminal state. With `--keep-alive` the session deliberately outlives the flows, so process exit is not a completion signal and `report.json` is rewritten incrementally; wait on this file instead:

  ```bash
  grantiva run --flow flows/advertise.yaml --keep-alive --ready-file /tmp/advertise.ready &
  while [ ! -f /tmp/advertise.ready ]; do sleep 0.2; done
  jq -r .status /tmp/advertise.ready   # passed | failed | interrupted
  ```

  Two guarantees make that loop safe. The file is **deleted at startup**, before any project, build, or simulator work, so a file left by a previous run can never be read as this one's verdict — and an unwritable path fails immediately rather than at the end of a long suite. And it is **always written**: a failure before the runner starts (no project, bad scheme, build failure, no simulator) records `failed` rather than leaving the loop, which has no timeout, spinning until CI's global limit.

  Missing parent directories of the path are created (`--ready-file out/ci/x.ready` creates `out/ci/`), so a typo in the directory part makes a new directory rather than failing; only an uncreatable or unwritable location is an error.
- **`--env KEY=VALUE`** — Sets an environment variable for the app under test (repeatable). Forwarded through the flow's `launchApp` (`environment:` on iOS, `arguments:` intent extras on Android), so an ephemeral port or test fixture can be passed in per run.
- **`grantiva hierarchy`** — Reads the current UI accessibility tree of the running app via the held session. Pure read, no relaunch, no state loss. XML (default) or JSON. Finds the newest live `--keep-alive` session in `/tmp/grantiva-sessions/`, or a specific simulator's with `--udid <UDID>`; sessions whose runner has exited are ignored. See [docs/dump-hierarchy.md](docs/dump-hierarchy.md).
- **Concurrent runs** — Runs on different simulator UDIDs execute in parallel. A second run targeting an already-owned simulator fails immediately with guidance to provision a unique simulator, protecting the active WDA session from cross-run teardown.
- **`--logs`** — Streams simulator app logs (`xcrun simctl spawn log stream`) prefixed with `[log]` interleaved with the flow output. Auto-scopes the predicate to your app's bundle ID.
- **`--logs-predicate '<NSPredicate>'`** — Custom log filter for narrowing to specific subsystems, categories, or processes.
- **`--snapshot failure|trailing|full`** — How many screenshots the runner keeps. `failure` (default) takes one shot after a failing step, `trailing` keeps the last good step plus the failing one, `full` captures every step. Applies to both `screens:` and flow-file runs.
- **`--continue-on-failure`** — Keep running the remaining flows after one fails. The default is fail-fast: the suite stops at the first broken flow, which matches CI semantics.
- **`--timeout <seconds>`** — Maximum time to wait for the runner before it is killed with SIGTERM. Default 600, **minimum 30** (a smaller value exits 64 with `--timeout must be at least 30 seconds.`). The timeout itself is ignored under `--keep-alive`, where the session is held until you release it, but the 30 s minimum is still validated.

  `--continue-on-failure` and `--timeout` apply to flow files (`flows:` in the config, or `--flow`). A suite that runs only the configured `screens:` does not read these two flags: it uses a fixed 300 s timeout.
- **`--flow <path>`** — Override configured flows to run a single YAML file. Useful for iterating on one test at a time.
- **`--report-dir <path>`** — Writes the runner's `report.json`, assets, failure screenshots, and trace artifacts under that directory, for `screens:` as well as `flows:`. When both run, the screens session's report goes to `<path>/screens/`. Flow paths in `report.json`, `flows/*.json`, `junit-report.xml`, and `maestro-runner.log` are the paths you passed. Nothing is written to `./.grantiva/captures` when it is given. `--timeout` and `--continue-on-failure` also apply to `screens:`; with `--continue-on-failure` a failed screens session is reported and the configured flows still run. Screens run as one flow, so a failed screen stops the remaining screens; the flag lets the configured flows run afterwards.

## Configuration

Create a `grantiva.yml` in your project root (or run `grantiva init`):

```yaml
scheme: MyApp
simulator: iPhone 16
bundle_id: com.example.myapp

screens:
  - name: Home
    path: launch
  - name: Settings
    path:
      - tap: "Profile"
      - tap: "Settings"

diff:
  threshold: 0.02
  perceptual_threshold: 5.0
```

`diff.threshold` and `diff.perceptual_threshold` are two separate checks, and a screen passes only when **both** hold:

- `threshold` is a 0-1 fraction of pixels that differ (`0.02` = 2 %; the messages print percent). `1.0` means any share of changed pixels is fine.
- `perceptual_threshold` is the mean CIE76 color distance (delta E) over the differing pixels only, not over the whole image. It is 0 when the images are identical and about 2.3 is a just-noticeable difference. A handful of strongly changed pixels therefore fails a screen no matter how high `threshold` is.

To loosen a flaky screen, raise both. Raising only `threshold` still fails the screen on `perceptual_threshold` (for example `pixel=7.97% perceptual=6.4` against a limit of 5).

### Screens

Each screen has a `name` and a `path`. The path describes how to navigate there:

- `launch` — screenshot immediately after app launch
- `- tap: "Label"` — tap a button or element by accessibility label
- `- swipe: up` — swipe in a direction (`up`, `down`, `left`, `right`, any case); any other value is a config error
- `- type: "text"` — type text into the focused field
- `- wait: 2` — wait N seconds (always the full N seconds, even if the screen is already still)
- `- assert_visible: "Label"` — verify an element is visible (fails if not)
- `- assert_not_visible: "Label"` — verify an element is hidden
- `- run_flow: "path/to/flow.yaml"` — include steps from another YAML file

A label matches any element whose text *contains* it, case-insensitively, so `tap: "Landmarks"` can hit a
`landmarks://…` link before the tab called "Landmarks". `tap`, `assert_visible`, and `assert_not_visible` also take
`{text: "Landmarks", exact: true}` to require the element's full text to equal the label.

Grantiva navigates to each screen in order, captures a screenshot, then moves to the next. After every `tap`, `swipe`,
and `type`, and before every screenshot, it waits (up to 5 s) for the screen to stop changing, so a capture never shows
the screen it is leaving. Unknown keys in the config file are reported as warnings with their line number.

### Maestro Compatibility

Grantiva can read [Maestro](https://maestro.mobile.dev) flow files as a drop-in replacement. If you have existing Maestro flows, Grantiva will auto-detect and parse them — no rewrite needed.

Place your flows in a `.maestro/` directory, or write `grantiva.yml` in Maestro format:

```yaml
appId: com.example.myapp
---
- launchApp
- tapOn: "Sign In"
- inputText: "user@example.com"
- takeScreenshot: "Login"
- tapOn: "Submit"
- assertVisible: "Welcome"
- takeScreenshot: "Welcome"
```

Each `takeScreenshot` becomes a named screen capture point. Commands between screenshots become navigation steps. Supported Maestro commands: `tapOn`, `doubleTapOn`, `longPressOn`, `inputText`, `assertVisible`, `assertNotVisible`, `swipe` (`direction:`, optionally with `from:`, or `start:`/`end:` as `"x%, y%"`, plus `duration:`), `scroll`, `scrollUntilVisible`, `runFlow`, `extendedWaitUntil` (`visible:` or `notVisible:`), `waitForAnimationToEnd`, `launchApp`, `stopApp`, `killApp`, and `takeScreenshot`. Selectors accept a string or `{text: ...}` (matches text) or `{id: ...}` (matches the accessibility identifier). Any other command (`back`, scripting, permissions, etc.) is rejected before the run starts, with an error naming the file and line: `grantiva.yml:5: unsupported Maestro command 'back'`. Flows run with `grantiva run --flow` go to the runner as written and are not limited to this list.

The app a `run --flow` run launches is chosen in this order: `--bundle-id` / `--application-id`, then `bundle_id` / `application_id` in the config file, then the ID read from `--app-file`, then the flow's own `appId:` header (ignored when it is a `${VARIABLE}` reference), then project detection.

A flow header `env:` block defines `${VAR}` values and is also passed to the app at launch, like `--env`: the runner gets it in every `launchApp` step's `environment:` (iOS) or `arguments:` (Android). `--env` wins over a value the step sets, which wins over the header.

### Environment variables

| Variable | Effect |
| --- | --- |
| `GRANTIVA_API_KEY` | API key for the Grantiva dashboard and remote baselines. |
| `GRANTIVA_PLATFORM` | `ios` or `android`, like `--platform`. |
| `GRANTIVA_SESSION_ID` | Durable owner for simulator capacity slots (see below). |
| `GRANTIVA_MAX_SIMULATORS`, `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS` | Simulator capacity policy. |
| `GRANTIVA_RUNNER_HOME` | Runner directory, default `~/.grantiva/runner`. It holds simulator `locks/`, the WebDriverAgent build `cache/`, and one runner install per version under `versions/<stamp>/`. A relative path is resolved against the current directory. |

## CI Integration

Add to your GitHub Actions workflow:

```yaml
# .github/workflows/visual-regression.yml
name: Visual Regression
on: pull_request

jobs:
  visual-regression:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Install Grantiva CLI
        run: brew install grantiva/tap/grantiva
      - name: Run visual regression
        env:
          GRANTIVA_API_KEY: ${{ secrets.GRANTIVA_API_KEY }}
        run: grantiva ci run
```

### Pre-built binaries

Grantiva can consume pre-built `.app` bundles or `.ipa` archives, decoupling the build from the test:

```bash
# Use a pre-built .app bundle (skips xcodebuild, still installs)
grantiva ci run --app-file ./build/MyApp.app

# Use an .ipa from a CI artifact
grantiva ci run --app-file ./artifacts/MyApp.ipa

# App is already installed on the simulator (skip build and install)
grantiva ci run --no-build
```

When `--app-file` is provided, `scheme` is not required in `grantiva.yml` — the bundle ID is derived from the binary's `Info.plist`. The binary is validated to be a simulator build before install.

### Prepare fixtures before first launch

Use `grantiva build install --no-launch` when a test harness needs to seed the
installed app's data container or defaults before the application starts:

```bash
install_result="$(grantiva build install \
  --scheme "My App" \
  --simulator "$UDID" \
  --bundle-id com.example.myapp \
  --derived-data-path "/private/tmp/grantiva-$UDID/Derived Data" \
  --no-launch \
  --json)"

data_container="$(jq -r '.dataContainerPath' <<<"$install_result")"
# Seed files or defaults beneath "$data_container" here.

grantiva run \
  --no-build \
  --flow .grantiva/flows/seeded-state.yaml \
  --simulator "$UDID" \
  --bundle-id com.example.myapp
```

The JSON result includes `status`, `scheme`, `bundleId`, `appPath`,
`dataContainerPath`, and the selected simulator's `name` and `udid`.
`--derived-data-path` isolates Xcode products and intermediates for the run and
supports absolute or relative paths, including paths containing spaces. It is
available on every Grantiva command that builds the app and overrides a
`-derivedDataPath` value in `build_settings` when both are supplied.
`--no-build` assumes the app is already installed; the flow launches it with
`launchApp` after fixture preparation.
`diff capture --no-build` drives the simulator named by `--simulator`, else
`simulator:` in grantiva.yml, else the live runner session's device, else the one
booted simulator. With several booted and none of those set, it fails and names
them rather than guessing.

This enables split build/test workflows in CI:

```yaml
jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: |
          xcodebuild build -scheme MyApp \
            -destination 'generic/platform=iOS Simulator' \
            -derivedDataPath build/
      - uses: actions/upload-artifact@v4
        with:
          name: app-binary
          path: build/Build/Products/Debug-iphonesimulator/MyApp.app

  visual-regression:
    needs: build
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: app-binary
          path: ./app
      - name: Install Grantiva CLI
        run: brew install grantiva/tap/grantiva
      - name: Visual regression
        env:
          GRANTIVA_API_KEY: ${{ secrets.GRANTIVA_API_KEY }}
        run: |
          grantiva ci run --app-file ./app/MyApp.app
```

Results upload to the [Grantiva](https://grantiva.io) dashboard and post as GitHub Check Runs on your PRs.

## Commands

```
grantiva run                Run Maestro flows against a simulator or emulator (supports --keep-alive, --logs, --flow)
grantiva record             Record a simulator or emulator and extract PNG frames at requested timestamps
grantiva hierarchy          Dump the live UI hierarchy of a keep-alive session
grantiva build              Build the app for a simulator (xcodebuild) or emulator (Gradle)
grantiva build install      Build and install the app; use --no-launch to stop before launch
grantiva ci run             Run full CI pipeline (build -> capture -> diff -> upload)
grantiva diff capture       Capture screenshots for all configured screens
grantiva diff compare       Diff captures against baselines
grantiva diff approve       Promote captures to baselines
grantiva simulator ensure   Create or reuse a named simulator and boot it (--name is enough)
grantiva simulator delete   Explicitly delete a named simulator
grantiva simulator sessions List Grantiva-managed simulator capacity slots
grantiva simulator teardown End a session, or reclaim one simulator with --udid <UDID> --force
grantiva simulator cleanup  Delete Grantiva-created simulators that are shut down and not part of an active session
grantiva emulator ensure    Create the AVD if missing and boot it; prints the serial
grantiva emulator delete    Delete an AVD Grantiva created (--force for others)
grantiva emulator sessions  List the emulators Grantiva started
grantiva emulator teardown  Kill emulators Grantiva started (one by --serial, or --all)
grantiva console            Manage your Grantiva dashboard from the terminal (see `grantiva console --help`)
grantiva auth login         Authenticate with Grantiva
grantiva auth status        Show current authentication
grantiva auth logout        Remove stored credentials
grantiva doctor             Check environment and dependencies (non-zero exit if a required check fails)
grantiva runner install     Extract the embedded GrantivaAgent runner
grantiva runner version     Show the embedded runner version
grantiva runner start       Start an interactive GrantivaAgent session
grantiva runner stop        Stop a running interactive session
grantiva runner dump-hierarchy  Dump the view hierarchy from a running app for agent inspection
grantiva mcp                Start the MCP server for AI agent integration (tool list: docs/mcp.md)
grantiva init               Generate grantiva.yml
```

### Dashboard commands

`grantiva console` brings the Grantiva dashboard into scripts and terminal
workflows. Its command groups cover feature flags and environments, attestation
analytics and devices, apps and claims, visual regression review, release notes,
feedback and support, webhooks and alerts, API keys, team administration, the
audit log, organization settings and billing, and opening dashboard pages.

```bash
# Explore the complete command tree and the options for one area
grantiva console --help
grantiva console flags --help

# Examples: inspect analytics, review VRT runs, and manage webhooks
grantiva console analytics overview --days 30
grantiva console vrt runs
grantiva console webhooks list
```

Commands that advertise `--json` emit structured output. Consult
`grantiva <command> --help` for the output modes supported by a specific command;
for example, `hierarchy` emits XML by default, while runner lifecycle commands
do not have a JSON result.

### stdout is the result, stderr is the commentary

Everything a caller captures or parses — a `--json` payload, the `ensure` UDID,
a result table, a dumped hierarchy — goes to **stdout**, undecorated. Progress
narration, warnings, and errors go to **stderr**. So both of these work, and
neither sees the other's output:

```bash
udid=$(grantiva simulator ensure --name "iPhone 17 Pro")
grantiva doctor --json | jq '.[] | select(.status == "fail")'
```

Two flags adjust the stderr side only; neither changes stdout:

- **`--verbose`** — adds debug-level detail, with timestamps and labels, including every subprocess Grantiva runs and its exit status.
- **`--quiet`** — silences progress narration. Warnings and errors still print,
  and the command's result on stdout is untouched, so
  `grantiva doctor --json --quiet | jq` is still valid JSON.

`--json` already suppresses narration on its own: asking for a machine-readable
result does not ask for a running commentary.

Grantiva admits at most four Grantiva-booted simulators at once. A fifth boot
waits for up to ten minutes and reports the sessions occupying capacity. Set
`GRANTIVA_SESSION_ID` to a ticket identifier so separate CLI commands share one
durable owner, and release it when the ticket completes:

```bash
export GRANTIVA_SESSION_ID=APP-652
grantiva simulator ensure --name "APP-652 iPhone 17 Pro"
# build, install, and run as needed
grantiva simulator teardown --session-id APP-652
```

`ensure` prints the UDID on stdout and nothing else, so it can be captured
directly:

```bash
udid=$(grantiva simulator ensure --name "iPhone 17 Pro")
grantiva run --simulator "$udid" --flow flows/login.yaml
```

The human-readable line (`Reused iPhone 17 Pro (…) — Booted`) goes to stderr, so
a terminal still shows it while a command substitution ignores it. `--json`
emits the full record, including display geometry.

`ensure` needs only `--name`: it reads the device type out of the name, picks the
newest installed runtime, reuses an existing simulator with that name, and boots
it. Pass `--device-type` / `--runtime` to pin them exactly, and `--no-boot` to
create without booting. `--json` reports the UDID and display geometry.

### Reclaiming a simulator

A run that was killed outright — rather than interrupted — can leave
grantiva-runner, WebDriverAgent's `xcodebuild`, or a `simctl diagnose` still
owning a simulator, with nothing in the session ledger to tear down. Reclaim it
by UDID:

```bash
grantiva simulator teardown --udid "$UDID" --force
```

This kills whatever is holding that simulator, releases the lease, and clears any
stale capacity record. `--session-id` and `--udid` are mutually exclusive.

Override the host policy with `GRANTIVA_MAX_SIMULATORS` and
`GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS`. Only simulators Grantiva boots count
toward the limit; manually booted Xcode simulators are never shut down by
Grantiva teardown.

## Local Workflow

You can use Grantiva locally without a Grantiva account:

```bash
# Capture screenshots of all configured screens
grantiva diff capture

# Compare against local baselines
grantiva diff compare

# Approve current screenshots as the new baseline
grantiva diff approve
```

Local baselines are stored in `.grantiva/baselines/`. Connect to [Grantiva](https://grantiva.io) to store baselines remotely and enable CI across machines.

## License

MIT
