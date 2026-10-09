# Cross-platform QA campaign — design

Status: Approved in conversation. Date: 2026-10-09.

## Goal

Find real bugs in the Grantiva CLI by exercising every documented feature end to end on
iOS and Android against known-good demo apps, and leave behind demo apps and flows that
can be published as examples.

Target commit: `origin/main` at `c8dc86d` (Android support 3). Every finding is recorded
against one release binary built from that commit.

## Decisions already made

- iOS demo app: a copy of `kylebrowning/landmarks-app-complete`, adapted for UI testing.
- Android demo app: a Jetpack Compose port of the same app, same screens and data.
- Both live in a new repo, `grantiva/landmarks-demo`, private until Kyle publishes it.
- Scope is local only. No Grantiva account is used. `auth login`, uploads, and `console`
  mutations are out of scope; their unauthenticated behavior is in scope.
- One testing agent per platform (CLI, iOS, Android), each in its own worktree.
- Agents record findings; they do not file issues. Kyle's session triages, dedupes, and
  files one GitHub issue per bug on `grantiva/cli` with the label `qa-campaign`.
- Agents never edit CLI source. They may read it to root-cause a finding.

## Findings that shape the design

- `landmarks-app-complete` differs from the blog post: it has `.mock` services but no
  `UI_TESTING` compilation condition, no "Landmarks (UI Testing)" scheme, no shared
  schemes, and no reservation store. Its deployment target is iOS 26.2, which will not
  install on the iOS 26.0 simulator. The app has three tabs (Landmarks, Favorites, Deep
  Links); screens for detail, category, visit confirmation, edit landmark, and a caching
  services demo; favorites swipe-to-delete; an edit form with Cancel/Done and a discard
  alert; a cache-policy picker; and a deep-link result screen.
- `grantiva/grantiva-examples` already holds a Landmarks app with a `grantiva.yml`, but
  it is the SDK attestation demo with placeholder credentials. Not used as the app under
  test; it may serve as a second project for detection edge cases.
- Host: macOS with Xcode 27 (iOS 26.0 and 27.0 runtimes), one booted iPhone 17 Pro
  simulator that predates the campaign, Android SDK at `~/Library/Android/sdk` with
  `adb` not on `PATH`, one AVD `Pixel_8_API_35` running as `emulator-5554`, no
  `grantiva` login. Grantiva admits four Grantiva-booted simulators at once.
- CLI surface on the target commit: `run`, `record`, `hierarchy`, `build`,
  `build install`, `ci run`, `diff capture|compare|approve`, `simulator
  ensure|delete|sessions|teardown|cleanup`, `emulator ensure|delete|sessions|teardown`,
  `auth login|status|logout`, `doctor`, `runner install|version|start|stop`, `mcp`,
  `init`, and the `console` tree. 19 MCP tools. Two config dialects (`grantiva.yml`
  screens and Maestro flows), plus `grantiva-android.yml`.
- Documented contracts to test against: README, `docs/android.md`,
  `docs/android-environment.md`, `docs/dump-hierarchy.md`, `SIMULATOR-LIFECYCLE.md`,
  `CHANGELOG.md`, and each command's `--help`.

## 1. Demo repo: `grantiva/landmarks-demo`

```
landmarks-demo/
  README.md                 what the apps are, how to run the flows on each platform
  ios/
    Landmarks.xcodeproj     shared schemes committed
    Landmarks/
    grantiva.yml            screens config
    .maestro/               Maestro-format flows
  android/
    settings.gradle.kts, app/   single module, variants debug and release, plus a
                                product flavor pair (free/paid) to exercise --variant
    grantiva-android.yml
    .maestro/
  flows/README.md           flow-by-flow description shared by both platforms
```

### iOS changes to the copied app

- Add the `UI_TESTING` active compilation condition on a new shared scheme
  "Landmarks (UI Testing)"; `LandmarksApp` selects `.mock` services under it.
- Lower `IPHONEOS_DEPLOYMENT_TARGET` to 26.0. Bundle ID stays
  `com.kylebrowning.Landmarks`.
- Commit the default `Landmarks` scheme as shared too, so `--scheme` mistakes are testable.

### Android port

Kotlin, Jetpack Compose, Material 3, minSdk 26, targetSdk 35, application ID
`com.kylebrowning.landmarks`. Same three tabs and screens as iOS, same landmark JSON
bundled as an asset, an in-memory `LandmarkStore`. Accessibility labels (`contentDescription`
and text) match the iOS labels used in flows so the two flow sets differ only in `appId`.

### Bug bait, present in both apps

Each exists to make a specific CLI feature observable. Flows reference each one.

| Bait | Exercises |
|---|---|
| Edit Landmark text field | `inputText`, `type:`, keyboard handling |
| Favorites swipe to delete | `swipe`, `assertNotVisible` |
| Cache policy picker | picker interaction, hierarchy depth |
| Discard-changes destructive alert | alert buttons in hierarchy, `tapOn` on alert |
| Deep link `landmarks://landmark/<id>` | `--env`, launch arguments, deep-link result screen |
| Long landmark list (60+ rows) | `scroll`, `scrollUntilVisible`, hierarchy size |
| Slow screen: 3 s artificial delay behind a flag | `extendedWaitUntil`, `waitForAnimationToEnd`, `--wait-for-idle-timeout` |
| Visible clock on the services demo screen | diff thresholds, Android demo-mode clock pinning |
| `LANDMARKS_SEED` env (`default`, `empty`, `many`) | `--env` forwarding on both platforms |
| `LANDMARKS_CRASH_ON_LAUNCH=1` | failure screenshots, `--snapshot`, `--continue-on-failure`, logs |

### Flows

One flow per journey, written in Maestro format, duplicated per platform with only
`appId` differing: browse, detail, favorite and unfavorite, edit landmark, discard edit,
category filter, visit confirmation, deep link, services demo, seed-empty, seed-many,
slow-screen wait, crash-on-launch (expected to fail). Plus a `grantiva.yml` screens
list covering each tab for `diff capture`.

### Gate

Each app's non-failing flows pass on its device with the shared binary before Phase 1
starts. The crash-on-launch flow fails for the documented reason.

## 2. Feature matrix

`docs/superpowers/plans/2026-10-09-qa-feature-matrix.md` in the CLI repo. One row per
test case: ID (`CLI-###`, `IOS-###`, `AND-###`), command and flags, platform, expected
behavior with the source it comes from (README section, doc file, CHANGELOG entry, or
help text), and a result column agents fill in: `pass`, `fail <finding id>`, `blocked
<reason>`, or `host <reason>` for failures caused by this machine rather than the CLI.

Matrix coverage, by slice:

### CLI agent (device-free)

- `--help` for every command and subcommand: present, accurate, no stray flags, exit 0.
- stdout/stderr contract: for every command with `--json`, stdout is valid JSON with
  `--quiet`, `--verbose`, and neither; narration never reaches stdout; errors exit non-zero.
- Project detection: Xcode only, Gradle only, both, neither, `.maestro/` only, Maestro-format
  `grantiva.yml`, both config files, `--platform` and `GRANTIVA_PLATFORM` precedence,
  missing-config-for-named-platform error.
- Config parsing: malformed YAML names file and position; unknown keys; iOS flag on
  Android project and the reverse; every screen path step; `run_flow` resolution.
- `init` on each directory shape, with and without `--scheme`, `--bundle-id`,
  `--application-id`, `--platform`; refuses to overwrite.
- `doctor` with and without `--json`, per platform, with `ANDROID_HOME` unset, and exit
  code when a required check fails.
- `runner install` idempotence and `runner version`.
- `auth status` and `auth logout` when not logged in; `ci run` and every `console`
  read command without credentials: clear error, correct exit code, nothing on stdout.
- Maestro compatibility: a fixture flow per supported command and per unsupported
  command, checked through flow generation output (`--report-dir` or dry parse).
- MCP server: `initialize`, `tools/list` schema for all 19 tools, each tool's argument
  validation and error contract, `--project-dir`, `--platform`, behavior with no device.

### iOS agent

- `simulator ensure` by name only, with `--device-type`, `--runtime`, `--no-boot`,
  `--json`; reuse by name; stdout is only the UDID.
- Capacity: four slots, fifth waits and lists occupants, `GRANTIVA_MAX_SIMULATORS`,
  `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS`, `GRANTIVA_SESSION_ID` sharing, `sessions`,
  `teardown --session-id`, `teardown --udid --force`, `cleanup`, `delete`, and that a
  manually booted simulator is never shut down.
- `build` and `build install` with `--no-launch`, `--json` fields, `--derived-data-path`
  with spaces, wrong scheme error.
- `run`: configured flows, `--flow`, `--app-file` .app and .ipa, `--no-build`,
  `--keep-alive` then `hierarchy` xml and json and `--udid`, `--ready-file` semantics
  (deleted at startup, always written, unwritable path fails early, status values),
  `--env`, `--logs`, `--logs-predicate`, `--logs-level`, `--snapshot` values,
  `--continue-on-failure`, `--report-dir` contents and absence of `.grantiva/captures`,
  `--timeout`, `--wait-for-idle-timeout`, Ctrl-C and `kill -INT` cleanup of runner, WDA,
  session files and owner sidecar, two concurrent runs on different UDIDs, second run on
  an owned UDID fails fast.
- `record` with `--duration`, `--output`, `--frames-at`, `--json`.
- `runner start` and `runner stop`; stale session handling.
- `diff capture`, `compare`, `approve` locally: first capture, no-change compare, changed
  pixel compare against thresholds, `perceptual_threshold`, `--json` output, baseline
  directory layout.
- MCP tools against a live keep-alive session: `grantiva_context`, `grantiva_tap`,
  `grantiva_type`, `grantiva_swipe`, `grantiva_screenshot` path behavior,
  `grantiva_script`, `hierarchy`, `screenshot`, `grantiva_sim_*`, `grantiva_build`,
  `grantiva_run`, `grantiva_test`, `grantiva_vrt_*`.

### Android agent

The iOS list mapped to Android, plus:

- `emulator ensure` creating an AVD and installing its system image, `--no-boot`,
  `delete` protections, `sessions`, `teardown` by serial and all.
- `--module`, `--variant` across debug, release, and flavor variants, `--application-id`
  override, application ID read from `output-metadata.json` and from an APK via
  `--app-file`.
- `--emulator` by AVD name, `--device` by serial, `--headless`.
- Demo mode and animation settings saved to `.grantiva/android-settings-<serial>.json`,
  restored after a run, and restored at the start of the next run after a `kill -9`.
- `--logs`, `--logs-tag`, `--logs-level`; `--logs-predicate` rejected.
- Captures under `.grantiva/captures/android/`, baselines under
  `.grantiva/baselines/android/`; `ci run` refuses with the documented message.
- `hierarchy` through UIAutomator2 forward; session and forward cleanup on Ctrl-C.
- `doctor --platform android` with the toolchain present and with `ANDROID_HOME` unset.

## 3. Host coordination

- Build once: `swift build -c release` from `c8dc86d`, copy the binary to a shared path
  outside any worktree, and record `grantiva --version`. Every agent uses that path.
- Worktrees: `.worktrees/qa-cli`, `.worktrees/qa-ios`, `.worktrees/qa-android` off
  `main`, used only for the matrix, findings files, and fixtures. The demo repo is cloned
  once per agent into its worktree directory.
- Devices: iOS agent creates `qa-ios-1..3`; CLI agent may create `qa-cli-1`. Android
  agent uses `Pixel_8_API_35` and may create `qa-android-1`. Nobody uses the pre-existing
  iPhone 17 Pro, nobody kills a process it did not start, and nobody runs `simulator
  cleanup` or `emulator teardown` without a serial while another agent is active.
- Sessions: `GRANTIVA_SESSION_ID=qa-cli|qa-ios|qa-android`.
- Android environment: the agent exports `JAVA_HOME`, `ANDROID_HOME`, and `PATH` per
  `docs/android-environment.md` in every shell.
- Each agent records `xcrun simctl list devices booted` and `adb devices` before and
  after, and restores the host to what it found.

## 4. Findings

Each agent writes `findings/<slice>.md` in its worktree. One entry per finding:

```
### <SLICE>-F<nn>: <one-line title>
Matrix IDs: IOS-012, IOS-013
Severity: crash | wrong-result | contract | docs | ux
Command: <exact invocation>
Expected: <behavior> (source: README "Agent-Native Features")
Actual: <behavior>
Repro: <steps against landmarks-demo, including seed/env>
Evidence: <paths to logs, report.json, screenshots under findings/evidence/>
Suspected cause: <file:line in CLI source, optional>
```

Severity `docs` covers README, docs, CHANGELOG, and help disagreeing with each other or
with behavior. `host` results are not findings but are listed in a separate section.

## 5. Triage and output

After all three agents finish, Kyle's session merges the three findings files, dedupes
across platforms, confirms each repro once against the shared binary, and files one
issue per bug on `grantiva/cli` labelled `qa-campaign`, titled by behavior, body from the
finding entry, linking the demo repo flow. Then a summary report lists matrix coverage
per slice, counts by severity, and the issue links. The demo repo is pushed with a README
explaining the bait and how to run the flows.

## Error handling

- A blocked test records why and moves on; agents do not retry past three attempts.
- A host-caused failure (toolchain, Xcode, emulator) is recorded as `host`, not `fail`.
- If the demo app gate fails, the campaign waits; the app is fixed, not the matrix.
- If an agent's worktree binary or device state diverges from the shared setup, it stops
  and reports instead of improvising.

## Out of scope

Authenticated features, `console` mutations, physical devices, Linux, GitHub Check Runs,
and fixing CLI bugs. Fixes are separate work after triage.
