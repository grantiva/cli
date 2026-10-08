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

GitHub-hosted macOS runners cannot boot the Android emulator (no nested virtualization),
and Grantiva does not run on Linux. Android `ci run` needs a self-hosted Mac runner or a
developer machine.
