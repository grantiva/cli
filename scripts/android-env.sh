#!/bin/zsh
# scripts/android-env.sh — install the Android toolchain Grantiva needs for
# Android development on this Mac. Idempotent; re-run freely.
set -euo pipefail

SDK="$HOME/Library/Android/sdk"
AVD_NAME="Pixel_8_API_35"
IMAGE="system-images;android-35;google_apis;arm64-v8a"

# Never let these installs trigger Homebrew's automatic cache pruning.
export HOMEBREW_NO_INSTALL_CLEANUP=1

brew list openjdk@21 >/dev/null 2>&1 || brew install openjdk@21
brew list --cask android-commandlinetools >/dev/null 2>&1 || brew install --cask android-commandlinetools

mkdir -p "$SDK"
export ANDROID_HOME="$SDK"
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"

# Homebrew puts cmdline-tools under its own prefix; sdkmanager needs --sdk_root
# to populate ~/Library/Android/sdk, which is where Grantiva looks.
SDKMANAGER="$(brew --prefix)/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"
# `yes` dies of SIGPIPE when sdkmanager exits, which pipefail would treat as failure.
yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null || true
"$SDKMANAGER" --sdk_root="$SDK" "platform-tools" "emulator" "cmdline-tools;latest" "build-tools;35.0.0" "platforms;android-35" "$IMAGE"

AVDMANAGER="$SDK/cmdline-tools/latest/bin/avdmanager"
if ! "$AVDMANAGER" list avd | grep -q "Name: $AVD_NAME"; then
  echo no | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "$IMAGE" -d pixel_8
fi

echo
echo "Add to your shell profile:"
echo "  export JAVA_HOME=\"$JAVA_HOME\""
echo "  export ANDROID_HOME=\"$SDK\""
echo "  export PATH=\"\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH\""
echo
"$SDK/platform-tools/adb" version | head -1
"$SDK/emulator/emulator" -version | head -1
"$AVDMANAGER" list avd | grep "Name:"
