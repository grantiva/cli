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
cp -R .build/release/grantiva .build/release/grantiva_GrantivaCore.bundle /usr/local/bin/
```

Copy `grantiva_GrantivaCore.bundle` together with the binary and keep the two side by side: the bundle carries the
embedded runner, and `grantiva runner install` (and every command that needs a device) extracts it from beside the
`grantiva` executable. A binary copied on its own fails with `The grantiva_GrantivaCore.bundle resource bundle was not
found next to the grantiva executable`. To install into a prefix instead, copy both into one directory and link the
binary onto your `PATH`.

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

  Two guarantees make that loop safe. The file is **deleted at startup**, before any project, build, or simulator work, so a file left by a previous run can never be read as this one's verdict — and an unwritable path fails immediately rather than at the end of a long suite. And it is **always written**: a failure before the runner starts (no project, bad scheme, build failure, no simulator) records `failed` rather than leaving the loop, which has no timeout, spinning until CI's global limit; a usage error such as `--timeout 5` records `failed` with an `error` field.

  Missing parent directories of the path are created (`--ready-file out/ci/x.ready` creates `out/ci/`), so a typo in the directory part makes a new directory rather than failing; only an uncreatable or unwritable location is an error.

  `status` is `interrupted` after Ctrl-C (or `kill -INT`/`-TERM`) and `failed` after a `--timeout` kill; either way a flow the run never finished is listed as `interrupted` or `failed`, never `running`. `reportDir` is present whenever `--report-dir` was given and the directory exists, pass or fail: the default report directory is deleted when the run exits. When a run has both `screens:` and `flows:`, `flows` lists the screens session as `screens` ahead of the flows.
- **`--env KEY=VALUE`** — Sets an environment variable for the app under test (repeatable). Forwarded through the flow's `launchApp` (`environment:` on iOS, `arguments:` intent extras on Android), so an ephemeral port or test fixture can be passed in per run.
- **`grantiva hierarchy`** — Reads the current UI accessibility tree of the running app via the held session. Pure read, no relaunch, no state loss. XML (default) or JSON. Finds the newest live `--keep-alive` session in `/tmp/grantiva-sessions/`, or a specific device's with `--udid <UDID or adb serial>`; sessions whose runner has exited are ignored. See [docs/dump-hierarchy.md](docs/dump-hierarchy.md).
- **Concurrent runs** — Runs on different simulator UDIDs execute in parallel. Each simulator launches WebDriverAgent from its own runner home (`<runner home>/versions/<stamp>/devices/<udid>`, where the runner home is `GRANTIVA_RUNNER_HOME` or `~/.grantiva/runner` and `<stamp>` is the installed runner's stamp: the runner version plus the bundled Android driver tag, such as `1.1.28-grantiva.11+android-drivers-2`), which holds an APFS clone of the cached WDA build, so every run gets its own xctestrun, port, and DerivedData without rebuilding WDA. `simulator teardown` (with or without `--force`) and `simulator delete` remove the device's home under every installed `versions/<stamp>/`, and teardown exits non-zero naming any home it could not remove; homes of simulators that no longer exist are pruned on the next run. A second run targeting an already-owned simulator fails immediately with guidance to provision a unique simulator, protecting the active WDA session from cross-run teardown; when the owner is a `grantiva runner start` session the message says so and names `grantiva runner stop`. A run's lease file (`<runner home>/locks/<udid>.lock`) is removed when the run ends, and a deleted simulator's when it is deleted.
- **`--logs`** — Streams app logs from the simulator or emulator, prefixed with `[log]` and interleaved with the flow output. On iOS (`xcrun simctl spawn log stream`) the predicate is scoped to your app: subsystems starting with its bundle ID, plus every line from its process (the installed app's `CFBundleExecutable`); override it with `--logs-predicate`. On Android `logcat` is filtered to the app's uid; `--logs-tag <tag>` keeps one tag and implies `--logs`. `--logs-level default|info|debug` sets the level on both (see [docs/android.md](docs/android.md#logs)).
- **`--logs-predicate '<NSPredicate>'`** — Custom log filter (iOS) for narrowing to specific subsystems, categories, or processes. Implies `--logs`.
- **`--snapshot failure|trailing|full`** — How many screenshots the runner keeps. `failure` (default) takes one shot after a failing step, `trailing` keeps the last good step plus the failing one, `full` captures every step. Applies to both `screens:` and flow-file runs. Without `--report-dir`, `run` writes its `takeScreenshot` shots and the failure screenshot (`failure-<timestamp>.png`) to `.grantiva/run-captures/` (`.grantiva/run-captures/android/` on Android), never to `.grantiva/captures/`, so `diff approve` and `diff compare` never take a run artefact for a screen. With `--report-dir`, `trailing` also trims the report directory's `assets/` and `allure-results/` to that set. Step shots go to `captures/trace/`; only `takeScreenshot` captures are listed as screenshots.
- **`--continue-on-failure`** — Keep running the remaining flows after one fails. The default is fail-fast: the suite stops at the first broken flow, which matches CI semantics.
- **`--timeout <seconds>`** — Maximum time to wait for the runner before it is killed with SIGTERM. Default 600, **minimum 30** (a smaller value exits 64 with `--timeout must be at least 30 seconds.`). The timeout itself is ignored under `--keep-alive`, where the session is held until you release it, but the 30 s minimum is still validated.
- **`--flow <path>`** — Override configured flows to run a single YAML file. Useful for iterating on one test at a time.
- **`--report-dir <path>`** — Writes the runner's `report.json`, assets, failure screenshots, and trace artifacts under that directory, for `screens:` as well as `flows:`. When both run, the screens session's report goes to `<path>/screens/`. Flow paths in `report.json`, `flows/*.json`, `junit-report.xml`, and `maestro-runner.log` are the paths you passed. Nothing is written to `./.grantiva/run-captures` when it is given. `--timeout` and `--continue-on-failure` also apply to `screens:`; with `--continue-on-failure` a failed screens session is reported and the configured flows still run. Screens run as one flow, so a failed screen stops the remaining screens; the flag lets the configured flows run afterwards.

## Configuration

Create a `grantiva.yml` in your project root (or run `grantiva init`):

```yaml
scheme: MyApp
simulator: iPhone 17 Pro   # optional; defaults to the newest installed iPhone type
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

A label is a case-insensitive regular expression matched against an element's whole text, on iOS and Android alike:
`tap: "Open"` matches an element whose text is "Open" or "open", not "Talk · Open" (write `.*Open.*` to match part of
the text). `tap`, `assert_visible`, and `assert_not_visible` also take `{text: "Landmarks", exact: true}` to require
the element's text to equal the label exactly as written.

Grantiva navigates to each screen in order, captures a screenshot, then moves to the next. After every `tap`, `swipe`, `type`,
and `run_flow`, and before every screenshot, it waits (up to 5 s) for the screen to stop changing, so a capture never shows
the screen it is leaving. Unknown keys in the config file are reported as warnings with their line number.

### Maestro Compatibility

Grantiva can read [Maestro](https://maestro.mobile.dev) flow files as a drop-in replacement. If you have existing Maestro flows, Grantiva will auto-detect and parse them — no rewrite needed.

Alerts on iOS: a `launchApp` pre-grants the app's permissions on the simulator, and GrantivaAgent auto-accepts only system alerts that appear during the flow (notifications, tracking, local network, Bluetooth and other prompts the simulator cannot pre-grant), so they don't block it. Your app's own alerts ("Discard changes?") are left alone: they stay up until a flow step answers them, including in `runFlow` subflows.

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

Each `takeScreenshot` becomes a named screen capture point. Commands between screenshots become navigation steps. Supported Maestro commands: `tapOn`, `doubleTapOn`, `longPressOn`, `inputText`, `assertVisible`, `assertNotVisible`, `swipe` (`direction:`, optionally with `from:`, or `start:`/`end:` as `"x%, y%"`, plus `duration:`), `scroll`, `scrollUntilVisible` (kept as a scroll, with its `direction:` and `timeout:`), `runFlow` (a file, `{file: ...}`, or inline `{commands: [...]}`; a `takeScreenshot` inside a sub-flow is a screen like one in the parent), `extendedWaitUntil` (`visible:` or `notVisible:`, with its `timeout:` kept), `waitForAnimationToEnd`, `launchApp`, `stopApp`, `killApp`, and `takeScreenshot`. `grantiva-android.yml` may be written in the same Maestro format; its `appId:` is the application ID. Selectors accept a string or `{text: ...}` (matches text) or `{id: ...}` (matches the accessibility identifier). Any other command (`back`, scripting, permissions, etc.) is rejected before the run starts, with an error naming the file and line: `grantiva.yml:5: unsupported Maestro command 'back'`. Flows run with `grantiva run --flow` go to the runner as written and are not limited to this list.

The app a `run --flow` run launches is chosen in this order: `--bundle-id` / `--application-id`, then `bundle_id` / `application_id` in the config file, then the ID read from `--app-file`, then the flow's own `appId:` header (ignored when it is a `${VARIABLE}` reference), then project detection (iOS). Project detection runs only when building: with `--no-build` it is skipped, so pass `--bundle-id` or give the flow a literal `appId:`.

A flow header `env:` block defines `${VAR}` values and is also passed to the app at launch, like `--env`: the runner gets it in every `launchApp` step's `environment:` (iOS) or `arguments:` (Android). `--env` wins over a value the step sets, which wins over the header.

### Environment variables

| Variable | Effect |
| --- | --- |
| `GRANTIVA_API_KEY` | API key for the Grantiva dashboard and remote baselines. |
| `GRANTIVA_PLATFORM` | `ios` or `android`, like `--platform`. |
| `GRANTIVA_SESSION_ID` | Durable owner for simulator capacity slots (see below). |
| `GRANTIVA_MAX_SIMULATORS`, `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS` | Simulator capacity policy. |
| `GRANTIVA_RUNNER_HOME` | Runner directory, default `~/.grantiva/runner`. It holds simulator `locks/`, the WebDriverAgent build `cache/`, and one runner install per version under `versions/<stamp>/`; a home other than the default also holds its own `simulator-capacity/` (see Simulators Grantiva created). When an install is needed (no install of this version yet), grantiva first checks the `grantiva_GrantivaCore.bundle` beside the binary: a bundle from another release fails the install, names the bundle and either both runner versions or the tarball it lacks, leaves any existing install untouched, and leaves no empty `versions/<stamp>/` directory. An existing install of the current version is used as it is, without reading the bundle; `grantiva runner install` then warns when the bundle does not carry that runner. A relative path is resolved against the current directory. |


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
`dataContainerPath`, and `simulator` with the selected simulator's `name` and `udid`. On Android
it includes `status`, `applicationId`, `appPath`, and `device` with the
emulator's `name` and adb `serial`. `status` is `installed` (installed, not
launched), `launched`, or `skipped` (`--no-build --no-launch`: nothing was
installed or launched). Every key is present in every document; `appPath` is `null` when
nothing was installed (`--no-build` without `--app-file`), and `scheme` and
`dataContainerPath` are `null` when there is none.
`--derived-data-path` isolates Xcode products and intermediates for the run and
supports absolute or relative paths, including paths containing spaces. It is
available on every Grantiva command that builds the app and overrides a
`-derivedDataPath` value in `build_settings` when both are supplied.
`--no-build` assumes the app is already installed; the flow launches it with
`launchApp` after fixture preparation. With `--app-file` as well, that file is
installed and only the build is skipped (`build install`, `run`, `diff capture`,
`ci run` alike).
`diff capture --no-build` drives the simulator named by `--simulator`, else
`simulator:` in grantiva.yml, else the live runner session's device, else the one
booted simulator, which is used only if Grantiva created it (a simulator you
created is refused, named, with `--simulator` as the remedy). With several booted
and none of those set, it fails and names them rather than guessing. `diff capture --no-build --app-file <file>` instead
boots the resolved device and installs the file, as a capture without
`--no-build` does.
When the device it drives is the one a live
`grantiva runner start` session (started from the same directory) holds, the
screens are captured through that session instead of a second runner, and the
session stays up; a screen step only the runner can run (`runFlow`, a swipe from
an element or between points) fails and asks you to `grantiva runner stop` first.

When neither a flag nor `simulator:` names one, every command (`run`,
`diff capture`, `runner start`, the MCP tools) uses the newest iPhone type an
installed iOS runtime can run, the same name `grantiva init` writes. If no
simulator has that name yet, create it with `grantiva simulator ensure --name
"<that name>"`. `init` warns when a simulator with that name already exists that
Grantiva did not create, since runs would boot and drive it.

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
grantiva run                Run Maestro flows against a simulator or emulator. No visual regression: reports step pass/fail and captures a screenshot on failure (see --keep-alive, --logs, --flow)
grantiva record             Record a simulator or emulator and extract PNG frames at exact requested timestamps
grantiva hierarchy          Dump the UI hierarchy of a booted simulator or emulator without relaunching the app (reads a `run --keep-alive` session)
grantiva build build        Build the app for a simulator (xcodebuild) or emulator (Gradle); `grantiva build` alone runs this
grantiva build install      Build and install the app on a simulator or emulator, then optionally launch it (--no-launch to skip)
grantiva ci run             Run full CI pipeline: capture screenshots, compare against baselines, upload results
grantiva diff capture       Navigate to configured screens and capture screenshots
grantiva diff compare       Diff current captures against baselines
grantiva diff approve       Promote current captures to baselines
grantiva simulator ensure   Create or reuse a named simulator and boot it (--name alone reuses an existing one)
grantiva simulator delete   Explicitly delete a named simulator
grantiva simulator sessions List Grantiva-managed simulator capacity slots
grantiva simulator teardown End a managed session, or reclaim one simulator by UDID when no ledger entry exists (--udid <UDID> --force)
grantiva simulator cleanup  Delete Grantiva-created simulators that are shut down and not part of an active session
grantiva emulator ensure    Create the AVD when missing (installing its system image first) and boot it; stdout is the serial, or with --no-boot the AVD name (the serial when it is already running)
grantiva emulator delete    Delete an AVD Grantiva created; others need --force; a running AVD is never deleted
grantiva emulator sessions  List the emulators Grantiva started
grantiva emulator teardown  Kill emulators Grantiva started: one by --serial, or --all
grantiva console            Manage your Grantiva dashboard from the terminal (see `grantiva console --help`)
grantiva auth login         Authenticate with Grantiva API
grantiva auth status        Show current authentication status
grantiva auth logout        Remove saved authentication credentials
grantiva doctor             Check environment and dependencies (non-zero exit if a required check fails)
grantiva runner install     Extract or update the embedded runner binary
grantiva runner version     Show the embedded runner version
grantiva runner start       Start the runner with WDA (UIAutomator2 on Android) and keep it alive for interactive use
grantiva runner stop        Stop the running runner session
grantiva runner dump-hierarchy  Dump the view hierarchy from a running app for agent inspection
grantiva mcp                Start the Grantiva MCP server for AI agent integration (tool list: docs/mcp.md)
grantiva init               Generate grantiva.yml (iOS) or grantiva-android.yml (Android) in the current directory
```

`grantiva record --duration <s> --frames-at <ms,...>` writes the video and one PNG per
timestamp, with a JSON report of the frame actually shown at each. On Android,
`screenrecord` writes frames only when the screen changes, so Grantiva holds the last
frame to `--duration` (and trims a recording that ran past it); if the last frame was on screen for more than half the recording, it
prints a note on stderr, since a device that disconnected mid-recording looks the same as an
idle screen. `--verbose` prints the numbers behind it (frames, last frame, held span, threshold).
A `--frames-at` value past `--duration` is refused (exit 64) before anything is recorded. Paths in
the output and the JSON report follow `--output`: relative to the current directory when it is
relative, absolute when it is absolute.

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
grantiva console vrt runs list my-project
grantiva console webhooks list
```

Commands that advertise `--json` emit structured output. Consult
`grantiva <command> --help` for the output modes supported by a specific command;
for example, `hierarchy` emits XML by default and JSON with `--json` (the same
as `--format json`), and the runner lifecycle commands (`runner start`, `stop`,
`install`, `version`) print a JSON result with `--json`.

`runner start --json` and `runner stop --json` share one shape: `status`
(`started`, `already_running`, `stopped`, `exited`, `not_running`), `pid` and
`port` as numbers, `platform`, and the platform's own names for the app and the
device: `bundleId` and `udid` on iOS, `applicationId` and `serial` on Android
(`log` with `--detach`). For `runner stop`, `runnerPid` is the stable field: it
is always the runner's pid, while `pid` is the grantiva process that was
holding a released `run --keep-alive` session. A stop that found the runner
already gone is still `stopped`, with `"alreadyExited": true`; one that released
several keep-alive sessions lists them all under `sessions`. `reaped` lists the
device helpers the stopped runner left running that `runner stop` then ended
(`kind`, `pid`, `processGroup`, `command`, and `killed`, true once it was
signalled; on iOS, the `simctl diagnose` that
WebDriverAgent's xcodebuild starts when it is interrupted), and is `[]` when
there were none. Only processes the runner started are ended: they name the
device and descend from the runner, or write into its run directory under the
runner home. `bundle_id`, and
`udid` on Android, are the 2.1 names, kept for one release and deprecated.

`runner stop` releases a `run --keep-alive` session started from the current
directory as Ctrl-C would. If that run's flows had already finished, its
`--ready-file` keeps the `passed` or `failed` it wrote (the ready file is
written once); the `stopped` result of `runner stop` is the record of the release.

```json
{"pid": 64253, "platform": "ios", "port": 8235, "status": "started",
 "bundleId": "com.example.app", "udid": "A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF"}
```

`runner install --json` reports `"extracted": false` when the installed runner
was already current (the text output then says `Runner already installed at …`).

### stdout is the result, stderr is the commentary

Everything a caller captures or parses — a `--json` payload, the `ensure` UDID,
a result table, a dumped hierarchy — goes to **stdout**, undecorated. Progress
narration, warnings, and errors go to **stderr**. So both of these work, and
neither sees the other's output:

```bash
udid=$(grantiva simulator ensure --name "iPhone 17 Pro")
grantiva doctor --json | jq '.[] | select(.status == "error")'
```

Each doctor check's `status` is `ok`, `warning` or `error`. Only `error` makes `grantiva doctor` exit non-zero;
a `warning` (an advisory check such as no booted simulator) never does.

Every `--json` document, and the `--ready-file` file, uses camelCase keys.

Some documents used snake_case keys before. For one deprecation period they
write each of those values twice, under the camelCase key and under the old
snake_case key beside it; read the camelCase key, as the snake_case one will be
removed in a later release. The keys still written in both spellings:

- `screen_name` → `screenName` (diff capture, diff compare)
- `size_bytes` → `sizeBytes` (diff capture)
- `point_dimensions` → `pointDimensions` (diff capture, simulator ensure)
- `pixel_dimensions` → `pixelDimensions` (diff capture, simulator ensure)
- `display_scale` → `displayScale` (diff capture, simulator ensure)
- `device_type` → `deviceType` (simulator ensure)
- `pixel_diff_percent` → `pixelDiffPercent` (diff compare)
- `perceptual_distance` → `perceptualDistance` (diff compare)
- `pixel_threshold` → `pixelThreshold` (diff compare)
- `perceptual_threshold` → `perceptualThreshold` (diff compare)
- `baseline_path` → `baselinePath` (diff compare)
- `capture_path` → `capturePath` (diff compare)
- `diff_image_path` → `diffImagePath` (diff compare)
- `approved_screens` → `approvedScreens` (diff approve)
- `baseline_directory` → `baselineDirectory` (diff approve)
- `bundle_id` → `bundleId` (runner start, runner stop; `applicationId` on Android)

`run --json` has the same shape whether the run passed or failed. `screens`
holds one entry per configured screen (`"kind": "screen"`) and one per flow
(`"kind": "flow"`); each entry has `name`, `kind`, `passed`, `steps` (the
runner's commands with `action`, `status`, `duration` in seconds — `null`
when the runner measured none — and, on failure, `message`) and `screenshots`
(`name` and `path` of each `takeScreenshot` capture; the path is relative to
the working directory when the file is under it, absolute otherwise). The
same `duration` rule holds for `diff capture --json` steps. `reportDir` is present whenever `--report-dir` was
given and the directory exists; `error` appears only on failure:

```json
{"allPassed": true, "reportDir": "/ci/out", "screens": [
  {"name": "01-browse", "kind": "flow", "passed": true,
   "steps": [{"action": "launchApp", "status": "passed", "duration": 1.9}],
   "screenshots": [{"name": "01-browse-cmd-003-Home", "path": ".grantiva/run-captures/01-browse-cmd-003-Home.png"}]}]}
{"allPassed": false, "reportDir": "/ci/out", "error": "Runner failed (exit 1): 02-exact-negative: assertVisible: ...", "screens": [
  {"name": "02-exact-negative", "kind": "flow", "passed": false,
   "steps": [{"action": "assertVisible: ...", "status": "failed", "duration": 12.6, "message": "Element not visible: ..."}],
   "screenshots": []}]}
```

The `error` names the failed step and its message, so it stands on its own
under `--json`. A failure before any flow ran prints
`{"allPassed": false, "screens": [], "error": "..."}`. The exit status stays non-zero.

Two flags adjust the stderr side only; neither changes stdout:

- **`--verbose`** — adds debug-level detail, with timestamps and labels, including every subprocess Grantiva runs and its exit status.
- **`--quiet`** — silences progress narration, including the runner's own
  output (banner, step lines, summary, report paths). Warnings and errors still
  print — a failing run's `Error:` line names the failed step — and the
  command's result on stdout is untouched, so
  `grantiva doctor --json --quiet | jq` is still valid JSON.

`--json` already suppresses narration on its own, the runner's included: asking
for a machine-readable result does not ask for a running commentary. `--verbose`
shows the runner's output again.

Without `--report-dir` the runner's report goes to a temporary directory that
is deleted when the command exits, so its paths are not printed; the run says
`Report not kept; pass --report-dir <dir> to keep report.json, JUnit and Allure.`

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

`ensure --name` alone reuses an existing simulator with that name, whatever it is
called, and boots it; `--json` reports that device's own type and runtime. To
create a new one, the name must contain a device model (`"APP-652 iPhone 17 Pro"`)
or you pass `--device-type`; the newest installed runtime is used unless you pass
`--runtime`. `--device-type` / `--runtime` are checked against an existing device
only when given. `--no-boot` creates without booting. `--json` reports the UDID
and display geometry.

### Reclaiming a simulator

A run that was killed outright — rather than interrupted — can leave
grantiva-runner, WebDriverAgent's `xcodebuild`, or a `simctl diagnose` still
owning a simulator, with nothing in the session ledger to tear down. Reclaim it
by UDID:

```bash
grantiva simulator teardown --udid "$UDID" --force
```

This kills whatever is holding that simulator (including a `simctl diagnose` the
dying runner starts), releases the lease, removes the killed runner's keep-alive
session files and the killed run's temp directories (its staged flows and, without
`--report-dir`, its report directory; `--json` lists them under
`temporaryDirectoriesRemoved`, and a `--report-dir` is never touched), and clears
any stale capacity record: a pending reservation, or a record with no session ID
whose owner process is dead. A named session's record is kept while the simulator
is booted, so `teardown --session-id` still finds the device; `--json` lists it
under `capacityRecordsKept` with the reason. `--session-id` and `--udid` are
mutually exclusive.

`reclaimed` in the `--json` result is true only when something was taken back: a
process was killed, a held lease was broken (`leaseReleased`: a live run held it,
or a `runner start` session's runner was still alive), or a stale capacity record
was cleared. On a simulator nothing held, `--force` exits 0 with
`"reclaimed": false` and prints `No processes were holding <udid>.`

Without `--force`, `teardown --udid` ends the Grantiva session that owns the
simulator. On a simulator no session owns (booted with Xcode or `simctl`, then
used by a run), it removes the device's runner homes while no run is using it,
leaves the simulator itself alone, and reports the homes in an entry with `udid`
and `deviceHomesRemoved` but no `session`.

A simulator held by a `grantiva runner start` session is released with
`grantiva runner stop`, from the directory that started it. `simulator teardown`
(with or without `--force`) also stops a runner session it finds on a simulator
it tears down, a `runner start` or a `run --keep-alive` one, before tearing the
simulator down, removes that session's files, and reports it as
`runnerSessionStopped` in `--json`. Without `--force`, a process still holding
the simulator that teardown did not start (a runner, WebDriverAgent's
xcodebuild, a `simctl diagnose`, a `grantiva run`) is not killed: teardown
names its pid and command in a warning on stderr and in `leftoverProcesses` in
`--json`, and goes on; `--force` reclaims such processes. Each
`leftoverProcesses` entry has `kind` (`runner`, `webDriverAgent`, `diagnose` or
`grantiva`), `pid`, `processGroup`, `command`, and `killed` (always `false`
here). Only devices the teardown deletes or shuts down are checked: a `--udid`
with no session record deletes nothing and warns about nothing.

### Simulators Grantiva created

Every simulator `simulator ensure` creates is recorded in
`~/.grantiva/simulator-capacity/created.json`. Simulators you created yourself are
never recorded and never deleted by Grantiva, and never used as the default: when
nothing names a simulator (no `--simulator`, no `simulator:` in `grantiva.yml`),
`run`, `build`, `diff capture`, `ci`, `runner start` and the MCP tools use the
default name (the newest installed iPhone type) only if Grantiva created that
simulator, and otherwise stop with an error naming it and `--simulator`, before
preparing anything. `diff capture --no-build` applies the same rule to its
fallback, the only booted simulator.

The ledger and the capacity records beside it (`sessions.json`) belong to the
runner home. With the default home (`~/.grantiva/runner`) they stay in
`~/.grantiva/simulator-capacity`, as in earlier releases. With any other
`GRANTIVA_RUNNER_HOME` they live in `<runner home>/simulator-capacity`, so a second
home (a QA or CI home) neither counts, tears down, nor treats as its own the
simulators another home recorded, and `GRANTIVA_MAX_SIMULATORS` applies per home.
Records an earlier release wrote while such a home was set stay in
`~/.grantiva/simulator-capacity`, with the default home. `simulator teardown --session-id`
deletes the Grantiva-created simulators of that session and only shuts down the
ones it booted but did not create (`deleted` in `--json`). `grantiva simulator
cleanup` deletes every Grantiva-created simulator that is shut down and not part
of an active session, and drops ledger entries for simulators that no longer
exist; it is safe to run at any time, for example from a scheduled job. Concurrent
`ensure` calls for the same new name create one simulator, not two.

Override the host policy with `GRANTIVA_MAX_SIMULATORS` and
`GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS`. Only simulators Grantiva boots count
toward the limit; manually booted Xcode simulators are never shut down by
Grantiva teardown. A run against an already-booted simulator that no Grantiva
session owns takes no slot, and teardown shuts down only simulators Grantiva
itself booted. Without `GRANTIVA_SESSION_ID`, a slot taken by a run lasts only
while that run's process is alive; one taken by `simulator ensure` lasts until
the simulator is shut down.

A simulator booted under a named `GRANTIVA_SESSION_ID` is reserved for that
session until it ends: a run with another session ID, or with none, is refused
with `Simulator <name> (<udid>) belongs to Grantiva session <id>.` To use it
anyway, run with the same `GRANTIVA_SESSION_ID=<id>`, or end the session with
`grantiva simulator teardown --session-id <id>`.

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

`diff capture` writes `.grantiva/captures/<screen>.png` for each configured screen. `diff approve` (with no names) and
`diff compare` work on the screens configured in `grantiva.yml`; any other file in `.grantiva/captures/` (for example a
shot an older `grantiva run` left there) is listed in a note (and under `ignored` in `--json`) and left alone. A failing screen's line names the check it
failed and its limit, for example `Failed: perceptual=63.6 exceeds perceptual_threshold 5.0 (pixel=0.03%, threshold 2.00%)`.

`diff compare` exits 0 only when every screen has a baseline and passes. It exits 1 when a screen fails or errors,
and also when a screen has no baseline: with no baselines at all it prints `? No baselines: <n> new screens. Run:
grantiva diff approve`, and when only some are missing `? Visual diff incomplete: …`; `--json` has `"passed": false`
in both cases. (`ci run` keeps reporting a new screen as `new_screen` without failing the run.)

Local baselines are stored in `.grantiva/baselines/`. Connect to [Grantiva](https://grantiva.io) to store baselines remotely and enable CI across machines.

## License

MIT
