# Android support — design

Status: Proposed. Date: 2026-10-07.

## Goal

Grantiva works for Android apps with the same feature set it offers iOS apps: build,
install and launch on an emulator or device, run flows, capture screenshots for visual
regression, dump the UI hierarchy, hold a keep-alive session, and drive the same MCP
tools. An Android project gets its own config file, and the CLI tells iOS and Android
projects apart on its own when no config exists.

## Decisions already made

- Full parity with iOS in the first release, not a subset.
- Android has its own config file, `grantiva-android.yml`, beside `grantiva.yml`.
- The embedded Go runner (grantiva/runner, derived from devicelab-dev/maestro-runner)
  stays. Its Android path (UIAutomator2) is reused. The Swift-native runner plan in
  `docs/plans/v2-swift-native-runner.md` is shelved.
- Emulators first. Physical devices work through the same adb serial path but are not
  part of the acceptance run.
- Linux CI runners are out of scope. The package stays macOS-only.

## Findings that shape the design

- grantiva/runner already contains the Android driver code and ships the APKs under
  `drivers/android` in source. The CLI's embedded tarball packages only `drivers/ios`.
- The runner accepts `--platform android --device <serial> --driver uiautomator2`,
  `--start-emulator <AVD>`, and `--auto-start-emulator`. Keep-alive, `/source`, and
  report.json are platform-independent.
- On the Swift side there is no device abstraction. simctl, xcodebuild, and WDA calls
  are spread across RunCommand, CICommand, DiffCommand, BuildCommand, RecordCommand,
  RunnerSession, SimulatorManager, and the MCP BuildTools and UITools. The destination
  string `platform=iOS Simulator,id=<udid>` appears in ten places.
- Baselines are keyed by screen name only, so iOS and Android would collide.
- The development Mac has no Android SDK, adb, emulator, or JDK.

## 1. Config and detection

### Files

`grantiva.yml` is the iOS file and is unchanged. `grantiva-android.yml` is the Android
file:

```yaml
platform: android          # optional; implied by the filename
module: app                # Gradle module; default "app"
variant: debug             # Gradle build variant; default "debug"
application_id: com.example.app
emulator: Pixel_8_API_35   # AVD name; counterpart of `simulator`
build_args: ["-PsomeFlag=1"]
screens: [...]             # same shape as iOS
flows: [...]
diff: {...}
a11y: {...}
```

`screens`, `flows`, `diff`, and `a11y` are one shared Swift type. `GrantivaConfig`
becomes a platform-neutral core plus a `project` enum: `.ios(iOSProject)` with scheme,
workspace, project, simulator, bundle_id, build_settings; or `.android(AndroidProject)`
with module, variant, application_id, emulator, build_args.

### Resolution order

Every device-touching command resolves a platform once, in this order:

1. `--platform ios|android`, if given.
2. Exactly one of the two config files exists: that platform.
3. Both exist: error asking for `--platform`. `init` is exempt.
4. Neither exists: detect from the working directory. `*.xcworkspace` or `*.xcodeproj`
   means iOS; `settings.gradle` or `settings.gradle.kts` means Android. Both present
   requires the flag.
5. Nothing found: the existing "no project found" error, mentioning both platforms.

### Android detection

`GradleProjectDetector` mirrors `ProjectDetector`: find the settings file, list the
included modules, pick the one whose build file applies `com.android.application`, read
`applicationId` and the default variant from it. The result is cached in
`.grantiva/config.json` with the same mtime invalidation, keyed by the settings and
module build files.

### init

`grantiva init` runs detection and writes the matching file with defaults, so an Android
user never learns the key names by hand.

## 2. Platform abstraction

### Protocol

`DevicePlatform` in GrantivaCore owns every operation that today calls simctl,
xcodebuild, or WDA. Methods take a `DeviceID` (simulator UDID or adb serial) and return
platform-neutral types.

| Method | iOS | Android |
|---|---|---|
| `detectProject()` | ProjectDetector | GradleProjectDetector |
| `build(config)` | XcodeBuildRunner | GradleBuildRunner; productPath is the APK |
| `ensureDevice(name)` | SimulatorManager ensure and boot | avdmanager list, `emulator -avd`, wait for `sys.boot_completed` |
| `install`, `launch`, `terminate`, `uninstall` | simctl | `adb install -r`, `am start`, `am force-stop`, `pm uninstall` |
| `freezeStatusBar`, `restoreStatusBar` | simctl status_bar | demo mode broadcasts |
| `displayGeometry` | simctl getenv | `wm size`, `wm density` |
| `screenshot` | simctl io screenshot | `screencap -p` |
| `streamLogs` | simctl log stream | `logcat --pid` |
| `runnerArguments(device, appPath)` | `--platform ios --device <udid>` | `--platform android --device <serial> --driver uiautomator2` |
| `lease(device)` | SimulatorLease | same mechanism keyed by serial |

Unchanged and shared: RunnerExecution, RunnerManager, FlowGenerator,
FlowReferenceResolver, FlowEnvironment, MaestroFlowParser, OutputRewriter, ReadyFile,
RunnerArtifactCollector, RunnerReportWorkspace, KeepAliveSessionStore, ImageDiffer,
BaselineStore.

### Wiring

Commands resolve the platform as in section 1 and hold a `DevicePlatform` value. All
hardcoded destination strings and direct SimulatorManager calls in RunCommand,
CICommand, DiffCommand, BuildCommand, RecordCommand, and the MCP BuildTools move
behind that value. This is a pure extraction of existing iOS behavior, pinned by the
existing tests.

### Naming

`udid` becomes `deviceID` in RunnerSessionInfo, the keep-alive owner sidecar, and
SimulatorLease. The old JSON keys are still read. The `simulator` subcommand keeps its
name; an `emulator` subcommand with `ensure`, `delete`, and `sessions` is added for
Android.

### Testing seam

Both implementations are constructed from a `Shell` closure, like
`XcodeBuildRunner(execute:)`, so tests assert on exact command lines. The MCP tests
inject a fake platform instead of `SimulatorManager.live`.

## 3. Android build and device layer

### Environment

Tool roots are searched in order: `ANDROID_HOME`, `ANDROID_SDK_ROOT`,
`~/Library/Android/sdk`. `grantiva doctor` checks the SDK root, adb, emulator, a JDK,
and at least one AVD, with install hints. Nothing is installed automatically.

### Build

`GradleBuildRunner` runs `./gradlew :<module>:assemble<Variant>` from the project root,
using the repo's wrapper when present and `gradle` on PATH otherwise. Warnings and
errors are parsed from output as XcodeBuildRunner does. The APK is resolved by listing
`<module>/build/outputs/apk/<variant>/*.apk`, newest first. `BuildResult` keeps its
shape. `--app-file` accepts `.apk`; AppBinaryResolver reads the application ID with
`aapt2 dump badging`.

### Device lifecycle

`ensureDevice(name)` looks for a running emulator whose AVD name matches via
`adb -s <serial> emu avd name`. If none, it launches
`emulator -avd <name> -no-snapshot-save -no-boot-anim`, adding `-no-window` when
headless is requested, and polls `getprop sys.boot_completed` under the same capacity
and timeout rules as SimulatorManager. Emulators Grantiva started are recorded in the
provenance file so `emulator teardown` kills only those.

### Stable captures

Before a run: `settings put global sysui_demo_allowed 1`, then demo-mode broadcasts for
clock 0941, battery 100 unplugged, notifications hidden, wifi and signal full. The three
animation scales (`window_animation_scale`, `transition_animation_scale`,
`animator_duration_scale`) are set to 0. All are restored after the run, in the same
place RunnerSession clears the iOS status bar.

### Geometry and logs

`wm size` and `wm density` supply physical pixels and dpi; ScreenshotNormalizer is
unchanged. Logs come from `logcat --pid=$(pidof <applicationId>)` after `logcat -c`.

## 4. Runner packaging and arguments

The release build of the runner tarball adds `drivers/android/*.apk` beside
`drivers/ios`, about 10 MB. RunnerManager extraction is unchanged; the installed layout
is `~/.grantiva/runner/drivers/{ios,android}`. `runnerVersion` is bumped so existing
installs re-extract. The runner's `findAPK` reads a directory; the exact lookup path is
confirmed on the first Android run and the tarball layout adjusted if needed.

Arguments are owned by the platform. iOS is unchanged. Android sends
`--platform android --device <serial> --driver uiautomator2 --no-app-install --app-file <apk>`.
The CLI installs the APK itself, as on iOS. Emulator start stays on the CLI side;
`--auto-start-emulator` is never passed, so lease and provenance rules hold. Keep-alive
is unchanged.

## 5. VRT and baselines

Baselines gain a platform segment: `.grantiva/baselines/ios/<screen>.png` and
`.grantiva/baselines/android/<screen>.png`. Existing flat files are read as iOS and
moved on first write.

The API upload sends `platform` with the capture target. `CaptureSimulatorTarget`
becomes `CaptureDeviceTarget` with device name, device id, dimensions, scale or density,
and platform. This needs a grantiva/backend change. Until it lands, Android uploads are
rejected client-side with a clear message; local baselines work fully. ImageDiffer and
thresholds are untouched.

## 6. Hierarchy, MCP, and keep-alive

`grantiva hierarchy` already reads `/source` from the runner session and works for
Android unchanged.

The MCP server resolves a platform like the commands and builds its tools from it:
build, run, test, screenshot, logs, device list and ensure go through `DevicePlatform`.
Tap, swipe, type, and the accessibility tree currently call WDAClient directly. WDAClient
becomes `DriverClient`, keyed by the session port. The design assumes the runner's
keep-alive session proxies the same WebDriver verbs for UIAutomator2 as it does for WDA.
That is unverified; the plan's first Android spike confirms it, and if it is false the
Android DriverClient talks to the UIAutomator2 server port directly through an adb
forward instead. `grantiva_a11y_check` rules keyed on
XCUIElement types get Android equivalents keyed on `content-desc` and class names.

## 7. Testing and verification

Unit tests:

- Exact gradle, adb, and emulator command lines through the Shell seam.
- Config resolution for every combination of flag, config files, and directory contents.
- Baseline path migration from flat to per-platform.
- Runner argument construction for both platforms.
- The existing iOS suite passes unchanged.

Environment setup, first task in the plan: Temurin JDK, Android command-line tools,
platform-tools, one API 35 system image, one Pixel AVD. An `examples/android` app with a
`grantiva-android.yml` and three screens, parallel to the Landmarks iOS example.

Acceptance, all on the emulator: `grantiva init`, `build`, `run`, `ci run` with a
deliberate diff, `hierarchy` under keep-alive, and the MCP tap and screenshot tools.

## Out of scope

- Linux CI runners.
- The DeviceLab and Appium drivers; UIAutomator2 only.
- Physical-device provisioning beyond what adb gives for free.
- Android attestation or SDK features; those live in grantiva/android-sdk.
