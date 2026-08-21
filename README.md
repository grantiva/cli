# Grantiva CLI

The command-line tool for [Grantiva](https://grantiva.io) — the all-in-one platform for iOS developers.

Currently features visual regression testing and agent-native UI automation. Captures screenshots of your app's screens, diffs them against approved baselines, and posts the results as GitHub Check Runs. Also streams UI hierarchy and app logs so AI agents can read, diagnose, and self-heal broken flows. Catch visual regressions before they ship — and let your agents fix them.

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

- **`--keep-alive`** — Holds the GrantivaAgent session open after flows complete. The app stays frozen in whatever state the flow left it. Ctrl-C to release.
- **`grantiva hierarchy`** — Reads the current UI accessibility tree of the running app via the held session. Pure read, no relaunch, no state loss. XML (default) or JSON.
- **Concurrent runs** — Runs on different simulator UDIDs execute in parallel. A second run targeting an already-owned simulator fails immediately with guidance to provision a unique simulator, protecting the active WDA session from cross-run teardown.
- **`--logs`** — Streams simulator app logs (`xcrun simctl spawn log stream`) prefixed with `[log]` interleaved with the flow output. Auto-scopes the predicate to your app's bundle ID.
- **`--logs-predicate '<NSPredicate>'`** — Custom log filter for narrowing to specific subsystems, categories, or processes.
- **`--flow <path>`** — Override configured flows to run a single YAML file. Useful for iterating on one test at a time.

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

### Screens

Each screen has a `name` and a `path`. The path describes how to navigate there:

- `launch` — screenshot immediately after app launch
- `- tap: "Label"` — tap a button or element by accessibility label
- `- swipe: up` — swipe in a direction (`up`, `down`, `left`, `right`)
- `- type: "text"` — type text into the focused field
- `- wait: 2` — wait N seconds
- `- assert_visible: "Label"` — verify an element is visible (fails if not)
- `- assert_not_visible: "Label"` — verify an element is hidden
- `- run_flow: "path/to/flow.yaml"` — include steps from another YAML file

Grantiva navigates to each screen in order, captures a screenshot, then moves to the next.

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

Each `takeScreenshot` becomes a named screen capture point. Commands between screenshots become navigation steps. Supported Maestro commands: `tapOn`, `inputText`, `assertVisible`, `assertNotVisible`, `swipe`, `scroll`, `runFlow`, `extendedWaitUntil`, `waitForAnimationToEnd`, and `takeScreenshot`. Unsupported commands (scripting, permissions, etc.) are silently skipped.

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
grantiva run                Run Maestro flows against a simulator (supports --keep-alive, --logs, --flow)
grantiva hierarchy          Dump the live UI hierarchy of a keep-alive session
grantiva build              Build the app via xcodebuild for a simulator
grantiva build install      Build and install the app; use --no-launch to stop before launch
grantiva ci run             Run full CI pipeline (build -> capture -> diff -> upload)
grantiva diff capture       Capture screenshots for all configured screens
grantiva diff compare       Diff captures against baselines
grantiva diff approve       Promote captures to baselines
grantiva simulator ensure   Create or reuse an exact named simulator
grantiva simulator delete   Explicitly delete a named simulator
grantiva simulator sessions List Grantiva-managed simulator capacity slots
grantiva simulator teardown Shut down every simulator owned by a ticket/session
grantiva auth login         Authenticate with Grantiva
grantiva auth status        Show current authentication
grantiva auth logout        Remove stored credentials
grantiva doctor             Check environment and dependencies
grantiva runner install     Extract the embedded GrantivaAgent runner
grantiva runner version     Show the embedded runner version
grantiva runner start       Start an interactive GrantivaAgent session
grantiva runner stop        Stop a running interactive session
grantiva mcp                Start the MCP server for AI agent integration
grantiva init               Generate grantiva.yml
```

All commands support `--json` for structured output.

Grantiva admits at most four Grantiva-booted simulators at once. A fifth boot
waits for up to ten minutes and reports the sessions occupying capacity. Set
`GRANTIVA_SESSION_ID` to a ticket identifier so separate CLI commands share one
durable owner, and release it when the ticket completes:

```bash
export GRANTIVA_SESSION_ID=APP-652
grantiva simulator ensure --name "APP-652 iPhone" --device-type "iPhone 17 Pro" --runtime latest --boot
# build, install, and run as needed
grantiva simulator teardown --session-id APP-652
```

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
