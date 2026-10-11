# Shell preamble used for every CLI-slice command (round 2 coverage pass)
export GRANTIVA="$HOME/.grantiva-qa/bin/grantiva"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"
export GRANTIVA_SESSION_ID=cov2-cli
unset GRANTIVA_API_KEY
# Android tooling (doctor / emulator checks only; no device is booted by this slice)
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
