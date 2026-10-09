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

## Not yet

`hierarchy`, `record`, `runner start`, the MCP server, and the `emulator` subcommand arrive
in the next release.
