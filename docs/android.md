# Grantiva for Android

Grantiva runs the same commands against an Android emulator that it runs against an iOS
simulator. The Android project gets its own config file, `grantiva-android.yml`, beside
`grantiva.yml`.

## Setup

Run `scripts/android-env.sh` once (see `docs/android-environment.md`), export `JAVA_HOME`
and `ANDROID_HOME` as it prints, then in your project:

    grantiva init --platform android     # writes grantiva-android.yml
    grantiva doctor

`init` picks the platform from the directory: a `settings.gradle` or `settings.gradle.kts`
means Android, an `.xcodeproj` or `.xcworkspace` means iOS. With both, pass `--platform`.

## Config

    platform: android
    module: app                      # Gradle module; default app
    variant: debug                   # assembleDebug; freeDebug -> assembleFreeDebug
    application_id: com.example.app  # optional; used only with --no-build (see below)
    emulator: Pixel_8_API_35         # AVD to use or boot
    system_image: "system-images;android-35;google_apis;arm64-v8a"
    build_args: ["-PsomeFlag=1"]
    screens: [...]                   # same shape as iOS
    flows: [...]
    diff: {...}

## Devices

`emulator:` (or `--emulator`) names the AVD: it is used if running, booted otherwise.
With no `emulator:`, the order is: the one running emulator, else the one emulator still
booting (waited on), else the only existing AVD (booted); otherwise the command fails and
lists the AVDs. `--device <serial>` targets any attached device, including
a physical one. On a physical device the demo-mode and animation settings are skipped
unless `--allow-device-settings` is given. `--headless` boots without a window.

The application ID a run installs and tests is the app's own: the Gradle output metadata's
`applicationId` for a built variant, or the APK's (read with `apkanalyzer`) for `--app-file`.
`application_id` in the config is used only when there is no app to read it from
(`--no-build`); when it disagrees with the app, the app wins and a warning names both.
`--application-id` overrides everything, with a warning when it disagrees with the app.

Flags: `--module`, `--variant`, `--application-id`, `--emulator`, `--device`,
`--allow-device-settings`, `--headless`, `--logs-tag`. iOS flags such as `--scheme` are
rejected on Android, and vice versa. `GRANTIVA_PLATFORM=android` or `--platform android`
forces the platform when both config files exist.

## Launch environment

Android has no launch-time process environment, so `--env KEY=VALUE`, a flow header's
`env:` block, and a `launchApp: environment:` map are delivered as string intent extras:
Grantiva writes them into the staged flow's `launchApp: arguments:` (merging with any
`arguments:` the step already has), which the runner passes to the launch intent. Read
them with `intent.getStringExtra("KEY")`. `--env` wins over a value the step sets, which
wins over the header `env:`.

## Captures and baselines

Android captures go to `.grantiva/captures/android/` and baselines to
`.grantiva/baselines/android/`. Baselines are local only for now: `ci run` and remote
baselines refuse Android with "Android baselines are local only until the Grantiva backend
supports platforms; use local baselines". `diff capture`, `diff compare`, and
`diff approve` work locally.

Before each capture Grantiva enables System UI demo mode (clock 09:41, full battery,
no notifications), sets the three animation scales to 0, and pins portrait. The previous
values are saved to `.grantiva/android-settings-<serial>.json` and restored afterwards. If
a run is interrupted, the next run restores them first.

## Logs

`grantiva run --logs` streams `logcat` filtered to the app's uid, starting at the device's
current time (the logcat buffer is not cleared). `--logs-tag <tag>` keeps one tag.
`--logs-level` maps to a minimum logcat priority, for the tag or for every tag:

| `--logs-level`      | logcat filter |
|---------------------|---------------|
| (none) or `default` | `*:I`         |
| `info`              | `*:I`         |
| `debug`             | `*:D`         |

Any other value is rejected. `--logs-predicate` is iOS-only.

## CI

GitHub-hosted macOS runners cannot boot the emulator. Use a self-hosted Mac or a developer
machine. `GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS` (default 180) bounds the boot wait.

## Hierarchy and keep-alive

    grantiva run --keep-alive            # terminal 1, holds the UIAutomator2 session
    grantiva hierarchy                   # terminal 2: the UIAutomator2 page source (XML)
    grantiva hierarchy --format json     # the same tree as JSON, frames in dp

The runner does not proxy UIAutomator2, so Grantiva forwards a local port to the
emulator's port 6790 (`adb forward tcp:0 tcp:6790`) for the duration of the command and
reads the session the runner holds. `--udid <serial>` picks a session when several are
live. `runner dump-hierarchy` reads the same tree and prints it as a tree, JSON, or XML.

## Recording

    grantiva record --duration 5 --frames-at 0,1000,3000

Records with `screenrecord` to `.grantiva/recordings/recording.mp4` and extracts frames
as PNGs. Android caps a recording at 180 seconds; longer durations are refused.
`--device <serial>` or `--emulator <AVD>` pick the target; the config's `emulator` is the
default.

## Runner sessions and the MCP server

    grantiva runner start --detach       # boots the emulator, holds a UIAutomator2 session
    grantiva runner dump-hierarchy --format tree
    grantiva mcp                         # in another terminal, or from an agent config
    grantiva runner stop

`runner start` records the forwarded local port in `.grantiva/session.json`; `runner stop`
kills the runner, stops the UIAutomator2 server, and removes the serial's forwards. The MCP
server resolves the platform like every command (a directory with only
`grantiva-android.yml` is Android; `grantiva mcp --platform ios|android` chooses when both
config files exist) and drives the emulator through the same tools as iOS:
`grantiva_tap` takes `x`/`y` in dp, the same unit the hierarchy reports,
`grantiva_a11y_check` uses 48 dp as the minimum tap target and checks the node TalkBack
focuses (a non-clickable widget inside a labelled clickable parent, such as the empty
`android.widget.Button` Compose places beside a button's text, is not checked on its own), and
`grantiva_emulator_list|boot|ensure|delete` mirror the `grantiva_sim_*` tools.
`grantiva_test` is iOS-only.

The MCP server starts without a runner session and without a config file, so an agent can
list tools and provision a device first. Only the device tools (`grantiva_tap`,
`grantiva_swipe`, `grantiva_type`, `grantiva_screenshot`, `grantiva_a11y_tree`,
`grantiva_a11y_check`, `grantiva_script`) need a session: until one exists they return an
error naming `grantiva runner start` and `grantiva run --keep-alive`, and they pick up a
session on the next call once it starts. Tools that need a config file say which file is
missing.

The server attaches to a live `grantiva runner start` session in the project's
`.grantiva/session.json`, or else to a `grantiva run --keep-alive` (or `runner start`)
session that was started from the same project directory for the same platform. A
keep-alive session started from another directory, for the other platform, or by an earlier
Grantiva (which did not record the directory) is never used. `grantiva_context`
reports the session's simulator or emulator; without a session it reports the configured
one.

## Emulator subcommand

    grantiva emulator ensure --name Pixel_8_API_35          # create if missing, boot, print the serial
    grantiva emulator ensure --name Pixel_8_API_35 --no-boot
    grantiva emulator sessions                              # emulators Grantiva started
    grantiva emulator teardown --serial emulator-5554       # only emulators Grantiva started; --force for others
    grantiva emulator teardown --all
    grantiva emulator delete --name Pixel_8_API_35          # only AVDs Grantiva created; --force for others

`ensure` installs the system image with `sdkmanager` when it is missing and creates the AVD
with `avdmanager create avd -d pixel_8`. The system image comes from `--system-image`, then
`system_image` in the config, then `system-images;android-35;google_apis;arm64-v8a`.
An emulator is recorded only while the process Grantiva spawned is alive and owns the
serial's console port: a boot whose process exits, even if another emulator answers on that
serial, leaves no record, and a port whose console is already bound is skipped. A record
whose pid is gone is dropped by `sessions` and `teardown`; `teardown` then refuses the
serial without `--force`, whatever AVD it runs, so `teardown --all` never kills an emulator
someone else started. `delete` refuses while a running emulator's AVD name cannot be read.
