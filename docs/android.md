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
    application_id: com.example.app  # optional; read from the build output when absent
    emulator: Pixel_8_API_35         # AVD to use or boot
    system_image: "system-images;android-35;google_apis;arm64-v8a"
    build_args: ["-PsomeFlag=1"]
    screens: [...]                   # same shape as iOS
    flows: [...]
    diff: {...}

## Devices

Only running emulators are considered by default. `emulator:` names the AVD; it is used if
running, booted otherwise. With no `emulator:`, a single running emulator is used, else a
single existing AVD is booted. `--device <serial>` targets any attached device, including
a physical one. On a physical device the demo-mode and animation settings are skipped
unless `--allow-device-settings` is given. `--headless` boots without a window.

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

`grantiva run --logs` streams `logcat` filtered to the app's uid. `--logs-tag <tag>` keeps
one tag. `--logs-predicate` is iOS-only.

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
`teardown` checks a recorded emulator whose pid is gone by its AVD name before killing
anything, and `delete` refuses while a running emulator's AVD name cannot be read.
