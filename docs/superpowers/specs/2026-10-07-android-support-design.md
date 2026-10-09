# Android support — design

Status: Proposed. Date: 2026-10-07. Revised after review the same day.

## Goal

Grantiva works for Android apps with the same feature set it offers iOS apps: build,
install and launch on an emulator, run flows, capture screenshots for visual regression,
dump the UI hierarchy, hold a keep-alive session, manage emulators, and drive the same
MCP tools. An Android project gets its own config file, and the CLI tells iOS and
Android projects apart on its own when no config exists.

## Decisions already made

- Full parity with iOS in the first release, including an `emulator` subcommand.
- Android has its own config file, `grantiva-android.yml`, beside `grantiva.yml`.
- The embedded Go runner (grantiva/runner, derived from devicelab-dev/maestro-runner)
  stays. Its UIAutomator2 path is reused. The Swift-native runner plan in
  `docs/plans/v2-swift-native-runner.md` is shelved.
- Emulators are the default device. Physical devices are used only when named
  explicitly with `--device <serial>`.
- Android CI runs on self-hosted Macs or developer machines. GitHub-hosted macOS runners
  cannot boot an emulator (no nested virtualization) and Linux is out of scope. The docs
  say so.
- Android baselines are local only until the backend keys baselines by platform. Remote
  baseline operations for Android fail with a clear error until then. The backend change
  is a separate plan.

## Findings that shape the design

- grantiva/runner contains the Android driver code and ships the APKs under
  `drivers/android` in source. The CLI's embedded tarball packages only `drivers/ios`.
  The runner globs `<runner home>/drivers/android/appium-uiautomator2-server-v*.apk` and
  `appium-uiautomator2-server-debug-androidTest.apk` (`pkg/device/uiautomator.go:302`,
  `pkg/config/home.go:35`). Only those two APKs are needed.
- The runner accepts `--platform android --device <serial>`; UIAutomator2 is its default
  driver. Report.json and artifact collection are platform-independent.
- Whether the runner's `--keep-alive` session and `/source` endpoint work for
  UIAutomator2 is unverified. The help text calls it a "GrantivaAgent session", which is
  the iOS agent. This gates hierarchy, keep-alive, and the MCP UI tools, so it is the
  first spike of the plan (section 8).
- On the Swift side there is no device abstraction. simctl, xcodebuild, and WDA calls
  are spread across RunCommand, CICommand, DiffCommand, BuildCommand, RecordCommand,
  DriverCommand, HierarchyCommand, SimulatorCommand, DoctorCommand, RunnerSession,
  SimulatorManager, and the MCP BuildTools, UITools, SimTools, ScriptTools, ContextTool,
  and VRTTools.
- `SimulatorUDID.validate` only accepts the 8-4-4-4-12 shape and runs in
  HierarchyCommand, MCPServer, and DriverCommand. adb serials such as `emulator-5554`
  would be rejected.
- Every command loads config with `try?`, so a malformed file silently falls through.
- The development Mac has no Android SDK, adb, emulator, or JDK.

## 1. Config and detection

### Files

`grantiva.yml` is the iOS file and is unchanged. `grantiva-android.yml` is the Android
file:

```yaml
platform: android          # optional; implied by the filename
module: app                # Gradle module; default "app"
variant: debug             # Gradle variant, e.g. debug, release, freeDebug; default "debug"
application_id: com.example.app   # optional; read from the build output when absent
emulator: Pixel_8_API_35   # AVD name; counterpart of `simulator`
system_image: "system-images;android-35;google_apis;arm64-v8a"  # for `emulator ensure`
build_args: ["-PsomeFlag=1"]
screens: [...]             # same shape as iOS
flows: [...]
diff: {...}
a11y: {...}
```

`screens`, `flows`, `diff`, and `a11y` are one shared Swift type. `GrantivaConfig`
becomes a platform-neutral core plus a `project` enum: `.ios(iOSProject)` with scheme,
workspace, project, simulator, bundle_id, build_settings; or `.android(AndroidProject)`
with module, variant, application_id, emulator, system_image, build_args.

A config file that exists but fails to parse is an error, printed with the YAML
diagnostic. The `try?` loads become `try`.

### Resolution order

Every device-touching command, and the MCP server, resolves a platform once:

1. `--platform ios|android`, if given.
2. `GRANTIVA_PLATFORM` environment variable, if set.
3. Exactly one of `grantiva.yml` and `grantiva-android.yml` exists: that platform.
4. Both exist: error asking for the flag or the variable. `init` is exempt.
5. Neither exists. A `.maestro/` directory or a Maestro-format `grantiva.yml` loads
   as it does today, and the platform is detected from the directory: `*.xcworkspace`
   or `*.xcodeproj` means iOS; `settings.gradle` or `settings.gradle.kts` means
   Android. Both present requires the flag.
6. Nothing found: the existing "no project found" error, mentioning both platforms.

### Android project values

There is no Gradle file parsing and no detection cache. Module and variant come from
config or defaults. The application ID comes from config when set, otherwise from
`output-metadata.json` after a build (section 3), otherwise from the APK given by
`--app-file`. Flow generation needs the ID before the runner starts, so `run` without a
build and without `application_id` requires `--app-file` or `--application-id`.

### Android CLI flags

`run`, `ci run`, `build`, `diff capture`, and `record` gain `--module`, `--variant`,
`--application-id`, `--emulator <AVD>`, and `--device <serial>`. They override config.
Passing an iOS flag such as `--scheme` with the Android platform is an error naming the
flag, and the reverse likewise.

### init

`grantiva init` runs directory detection and writes the matching file with defaults. If
both an Xcode container and Gradle settings are present it asks for `--platform`.

## 2. Platform abstraction

### Protocol

`DevicePlatform` in GrantivaCore owns every operation that today calls simctl,
xcodebuild, or WDA. Methods take a device id (simulator UDID or adb serial, stored in
the existing `udid` fields and JSON keys) and return platform-neutral types.

| Method | iOS | Android |
|---|---|---|
| `build(config)` | XcodeBuildRunner | GradleBuildRunner |
| `resolveBinary(path)` | AppBinaryResolver, `.app`/`.ipa` | `.apk`; ID via `apkanalyzer manifest application-id` |
| `ensureDevice(name)` | SimulatorManager ensure and boot | AVD lookup or create, `emulator -avd`, boot wait |
| `listDevices()` | simctl list | `adb devices -l`, emulators only |
| `install`, `launch`, `terminate`, `uninstall` | simctl | adb (section 3) |
| `prepareForCapture`, `restoreAfterCapture` | simctl status_bar override and clear | demo mode and animation scales (section 3) |
| `displayGeometry` | simctl getenv | `wm size`, `wm density` |
| `screenshot` | simctl io screenshot | `screencap -p` |
| `recordVideo` | simctl io recordVideo | `screenrecord`, 180 s cap per file |
| `streamLogs` | simctl log stream | `logcat --uid` |
| `runnerArguments(device, appPath)` | `--platform ios --device <udid> --no-app-install --app-file` | `--platform android --device <serial> --no-app-install --app-file` |
| `runTests(config)` | `xcodebuild test` | `./gradlew :<module>:connectedAndroidTest` |
| `cleanupOrphans(device)` | SimulatorReaper | force-stop the UIA2 server, remove adb forwards |
| `lease(device)` | SimulatorLease | same mechanism keyed by serial |
| `doctorChecks()` | Xcode checks | SDK, adb, emulator, JDK, AVD |

`--wait-for-idle-timeout 0` stays iOS-only. Android uses the runner default; turning
idle waits off on UIAutomator2 is a known flakiness source.

Unchanged and shared: RunnerExecution, RunnerManager, FlowGenerator,
FlowReferenceResolver, FlowEnvironment, MaestroFlowParser, OutputRewriter, ReadyFile,
RunnerArtifactCollector, RunnerReportWorkspace, KeepAliveSessionStore, ImageDiffer,
BaselineStore.

### Wiring

Commands resolve the platform as in section 1 and hold a `DevicePlatform` value. All
`platform=iOS Simulator,id=` destination strings (RunCommand, BuildCommand,
DiffCommand, CICommand, MCP BuildTools) and all direct SimulatorManager and
XcodeBuildRunner calls move behind that value. DriverCommand's `runner start`, `stop`,
and `dump-hierarchy` drop their hardcoded `--platform ios` and go through the same
value. DoctorCommand runs the platform's checks and only fails on the missing toolchain
for the detected platform; when no project is detected it reports both as informational.
MCP VRTTools, which shell out to `grantiva diff`, pass `--platform` through.

`BuildResult.scheme` and `destination` become optional and are nil for Android.
`BuildResult.productPath` is the APK. MCP `grantiva_sim_*` tools keep their names for
iOS and gain `grantiva_emulator_*` twins backed by the same platform methods.

`SimulatorUDID.validate` becomes `DeviceID.validate`, accepting a simulator UDID or an
adb serial (`emulator-NNNN`, a hardware serial, or `host:port`).

### Testing seam

Both implementations are constructed from a `Shell` closure, like
`XcodeBuildRunner(execute:)`, so tests assert on exact command lines. The MCP tests
inject a fake platform instead of `SimulatorManager.live`.

## 3. Android build and device layer

### Environment

Tool roots are searched in order: `ANDROID_HOME`, `ANDROID_SDK_ROOT`,
`~/Library/Android/sdk`. `adb`, `emulator`, `avdmanager`, `sdkmanager`, and
`apkanalyzer` are found under that root. A JDK is required for Gradle and `avdmanager`;
`JAVA_HOME`, then `/usr/libexec/java_home`. Nothing is installed automatically.

### Build

`GradleBuildRunner` runs `./gradlew :<module>:assemble<Variant>` from the project root,
capitalizing each variant component (`freeDebug` becomes `assembleFreeDebug`). It uses the
repo's wrapper when present and `gradle` on PATH otherwise, and parses warnings and
errors as XcodeBuildRunner does.

After the build it reads `<module>/build/outputs/apk/**/output-metadata.json` for the
built variant. That file lists each output APK with its ABI filters and the
`applicationId`. The APK chosen is the universal one, or the one whose ABI matches the
target device (`getprop ro.product.cpu.abi`). A custom build directory is read from
`-PbuildDir` in `build_args` when present; otherwise the default path is used.

### Device selection

Default selection considers only running emulators. The AVD name of each
`emulator-NNNN` serial is read with `adb -s <serial> emu avd name` and matched against
the configured `emulator`. When `emulator` is unset: one running emulator is used; else
one existing AVD is booted; else an error lists the AVDs. Devices in `offline` or
`unauthorized` state are reported and skipped.

A physical device is used only with `--device <serial>`. On a physical device,
`prepareForCapture` is skipped unless `--allow-device-settings` is passed, and the
output says so.

### Emulator lifecycle

`ensureDevice(name)` boots the AVD when it is not running:
`emulator -avd <name> -port <N> -no-snapshot-save -no-boot-anim`, with `-no-window`
when `--headless` is given or stdout is not a terminal. The port is chosen from the free
even ports in 5554 to 5584 so the serial `emulator-<N>` is known before boot and can be
leased. The process is spawned in its own session so SignalRelay's group kill does not
take it down. Boot is complete when `sys.boot_completed` is 1, `pm path android`
succeeds, and the keyguard is dismissed with `wm dismiss-keyguard`.

An AVD cannot run twice at once, so the capacity model is one run per AVD. A second run
wanting the same AVD waits on the lease like a second iOS run on one simulator.

Emulators Grantiva started are recorded in the provenance file. `emulator teardown`
and the post-run shutdown kill only those, with `adb emu kill`.

### `emulator` subcommand

`emulator ensure` creates the AVD when missing, with
`sdkmanager "<system_image>"` and `avdmanager create avd -n <name> -k <system_image>
-d pixel_8`, then boots it. `emulator delete` removes only AVDs recorded in the
provenance file, and refuses others unless `--force`. `emulator sessions` and
`emulator teardown` mirror their simulator counterparts.

### Install and launch

Install: `adb -s <serial> install -r -t -d <apk>`. On
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` the package is uninstalled and the install
retried once. Launch:
`monkey -p <applicationId> -c android.intent.category.LAUNCHER --pct-syskeys 0 1`, so no activity
name is needed. Terminate: `am force-stop`. Uninstall: `pm uninstall`.

### Stable captures

`prepareForCapture` reads and saves the current values of `sysui_demo_allowed`,
`window_animation_scale`, `transition_animation_scale`, and
`animator_duration_scale` into `.grantiva/android-settings-<serial>.json`, then sets
demo mode on with clock 0941, battery 100 unplugged, notifications hidden, wifi and
signal full, and the three scales to 0. `restoreAfterCapture` writes the saved values
back, exits demo mode, and deletes the file. If the file exists at the start of a run,
the previous run crashed, and the values are restored before anything else.

### Geometry and logs

`wm size` is parsed for `Override size` first, then `Physical size`. The emulator is
pinned to portrait for the run with `settings put system user_rotation 0` and
`accelerometer_rotation 0`, restored afterwards, so captured pixels match the reported
size. `wm density` gives dpi.

Logs come from `logcat --uid=<uid>` where the uid is read once from
`pm list packages -U <applicationId>`, after `logcat -c`. The uid survives
`launchApp` and `clearState` restarts. `--logs-predicate` is iOS-only; Android gets
`--logs-tag <tag>` as the equivalent filter.

### Orphans

`cleanupOrphans(serial)` runs `am force-stop io.appium.uiautomator2.server` and
`io.appium.uiautomator2.server.test` and removes every `adb forward` for the serial.
It runs after every run and from `emulator teardown`.

## 4. Runner packaging and arguments

The CLI's runner tarball adds `drivers/android/appium-uiautomator2-server-v*.apk` and
`appium-uiautomator2-server-debug-androidTest.apk` beside `drivers/ios`, roughly
5 MB. RunnerManager extraction is unchanged and the installed layout matches the
runner's glob. `runnerVersion` is bumped so existing installs re-extract.

Android runner arguments: `--platform android --device <serial> --no-app-install
--app-file <apk>` followed by the `test` subcommand with the shared output, artifacts,
and flow arguments. `--driver` is not passed. Emulator start stays on the CLI side;
`--auto-start-emulator` is never passed.

## 5. VRT and baselines

iOS baselines and captures stay where they are: `.grantiva/baselines/<screen>.png`
and `.grantiva/captures/<screen>.png`. Android uses `.grantiva/baselines/android/` and
`.grantiva/captures/android/`. BaselineStore's listing already ignores subdirectories,
so nothing moves and nothing migrates. `diff compare` and `approve` resolve the platform
like every other command and read from the matching directory.

Remote baselines are keyed by repository and branch with no platform, so Android would
collide with iOS. Until the backend adds platform to the baseline key and the capture
target, Android `ci run`, Android `diff` with remote baselines, and Android `approve`
to the API fail before doing anything, with the message "Android baselines are local
only until the Grantiva backend supports platforms; use local baselines". Local Android
`diff capture`, `compare`, and `approve` work fully. ImageDiffer and thresholds are
untouched. `CaptureSimulatorTarget` and its `simulator` JSON key are unchanged.

## 6. Hierarchy, MCP, and keep-alive

These depend on the spike in section 8. Assuming the runner serves `/source` and
WebDriver verbs for UIAutomator2 under keep-alive:

`grantiva hierarchy` and `runner dump-hierarchy` accept adb serials and parse the
UIAutomator2 tree, where nodes carry `text`, `content-desc`, `resource-id`, `class`,
and `bounds="[x1,y1][x2,y2]"` instead of `label`, `type`, and `x/y/width/height`. Both
trees map onto the existing hierarchy output type, with `label` populated from
`content-desc` then `text`.

The MCP server resolves a platform like the commands and accepts a project with only
`grantiva-android.yml`. Build, run, test, screenshot, record, logs, device list and
ensure go through `DevicePlatform`. WDAClient becomes a `DriverClient` protocol with
`WDAClient` and `UIAutomator2Client` implementations. The Android client locates
elements by `accessibility id` and XPath instead of `link text`, takes coordinates in
pixels, and parses the Android tree. `grantiva_a11y_check` rules keyed on XCUIElement
types get Android twins keyed on `class` and `content-desc`.

If the spike shows the runner does not proxy UIAutomator2 under keep-alive, the Android
client forwards the UIAutomator2 server's port itself (`adb forward tcp:<local>
tcp:6790`) and speaks to it directly, and `hierarchy` reads
`/wd/hub/session/<id>/source` from it.

## 7. Testing and verification

Unit tests:

- Exact gradle, adb, emulator, avdmanager, and sdkmanager command lines through the
  Shell seam.
- Platform resolution for every combination of flag, variable, config files, and
  directory contents, including malformed config.
- `output-metadata.json` parsing with universal, ABI-split, and flavored outputs.
- Runner argument construction for both platforms.
- Saved-settings restore after a simulated crash.
- Android hierarchy parsing and the a11y rules.
- The existing iOS suite passes unchanged.

Environment setup, first task in the plan: Temurin JDK, Android command-line tools,
platform-tools, one API 35 arm64 system image, one Pixel AVD. An `examples/android`
app with a `grantiva-android.yml` and three screens, parallel to the Landmarks iOS
example.

Acceptance, all on the emulator: `grantiva init`, `emulator ensure`, `build`, `run`,
`diff capture` then `diff compare` with a deliberate diff, `hierarchy` under
keep-alive, `record`, and the MCP tap and screenshot tools. Then `ci run` to confirm
the local-only error message. Then the full iOS suite and an iOS `run` to confirm no
regression.

## 8. Spike, first in the plan

Before the Swift work: with the SDK installed and an emulator booted, run the current
runner binary by hand with the two APKs in place, `--platform android --device
emulator-5554 --keep-alive`, and check whether a session file appears in
`/tmp/grantiva-sessions`, whether `GET /source` answers, and whether tap and type
verbs work against that port. The result picks between the two section 6 designs and
is recorded at the top of the plan.

## Out of scope

- Linux CI runners and GitHub-hosted macOS runners for Android.
- The DeviceLab and Appium drivers.
- The backend change for platform-keyed baselines; separate plan.
- Multiple emulators per AVD, and emulator capacity limits beyond one run per AVD.
- Android attestation or SDK features; those live in grantiva/android-sdk.
