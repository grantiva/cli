# Android development environment

Grantiva's Android support drives an emulator through `adb`. Install the toolchain with:

    scripts/android-env.sh

It installs OpenJDK 21 from Homebrew (`openjdk@21`, no sudo needed), the Android command-line
tools, platform-tools, the emulator, one API 35 arm64 system image, and creates an AVD named
`Pixel_8_API_35`. Then add to your shell profile:

    export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
    export ANDROID_HOME="$HOME/Library/Android/sdk"
    export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

Grantiva finds the SDK through `ANDROID_HOME`, then `ANDROID_SDK_ROOT`, then
`~/Library/Android/sdk`.

## CI

`grantiva ci run --platform android` is refused today, on any machine: Android baselines
are local only until the Grantiva backend supports platforms ("Android baselines are local
only until the Grantiva backend supports platforms; use local baselines"). Use the local
commands instead: `grantiva diff capture`, `grantiva diff compare`, and
`grantiva diff approve`.

Once `ci run` supports Android, note that GitHub-hosted macOS runners cannot boot the
Android emulator (no nested virtualization) and Grantiva does not run on Linux, so it will
need a self-hosted Mac runner or a developer machine.

See docs/android.md for using Grantiva with an Android project.
