# `build install --no-build --app-file <apk>` installs nothing and still prints "Done — ... installed"

Severity: wrong-result
Component: cli
Platforms: android (seen on Android; the same branch order is platform-independent, so iOS `--no-build --app-file <.app>` should be checked too)
Rows: AND-OBS-01 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`build install --app-file <apk>` installs that APK (help: `--app-file` "Path to a pre-built ... Skips the build step");
`--no-build` means "Skip building and installing — assume the app is already on the device". Combined, either the APK
is installed (an explicit file wins over "assume installed"), or the combination is rejected
(`--no-build and --app-file conflict: --app-file already skips the build`). In no case does it report an install that
did not happen.

## Actual
AND-115/02 (`build install --device emulator-5554 --no-launch --no-build --app-file app/build/outputs/apk/free/debug/app-free-debug.apk`):
```
[grantiva] Skipping build and install (--no-build)        (stderr)
[grantiva] Done — com.kylebrowning.landmarks installed on cov-android (not launched)        (stdout)
```
The package was not installed (the slice found it missing after a cold boot; AND-115 note). Without `--no-launch`, the
command goes on to launch a package that may not be there (see K32 for what that prints).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k25
unset GRANTIVA_API_KEY
rm -rf /tmp/k25 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k25 && cd /tmp/k25/android
grantiva build build                                      # app/build/outputs/apk/free/debug/app-free-debug.apk
SERIAL=$(grantiva emulator ensure --name fix-k25)         # fresh AVD: app not installed
grantiva build install --device "$SERIAL" --no-launch --no-build --app-file app/build/outputs/apk/free/debug/app-free-debug.apk; echo "exit $?"
adb -s "$SERIAL" shell pm list packages | grep landmarks || echo "not installed"
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k25
```

## Evidence
- findings/evidence/cov-android/AND-115/02.out, 02.err, commands.txt (note on the missing package)
- Row pointer: findings/evidence/cov-android/AND-OBS-01/commands.txt

## Suspected cause
- `Sources/GrantivaCLI/BuildCommand.swift:126-131`: `if buildOptions.shouldSkipInstall { note("Skipping build and install
  (--no-build)") } else if let resolvedBinary { ... productPath = resolvedBinary.appPath }`. `shouldSkipInstall` is
  `noBuild` (Sources/GrantivaCLI/Options.swift:52), so `--no-build` wins and `productPath` stays nil; the install at
  :170-174 is skipped because `productPath` is nil.
- The completion line (`completionMessage`, :237-247) is printed from `status`, which `completeInstall` (:229-235) sets
  to `.installed` whenever `--no-launch` is given, regardless of whether anything was installed.
- `run` has the same precedence (Sources/GrantivaCLI/RunCommand.swift:337-341) and `diff capture` (DiffCommand.swift:336);
  check whether they should also honour `--app-file` or reject the pair.

## Acceptance criteria
- The repro either installs the APK (`pm list packages` lists `com.kylebrowning.landmarks`, output says
  `Installing com.kylebrowning.landmarks...`) or exits 1 before touching the device with an error naming the two flags;
  pick one and apply it to `build install`, `run`, `diff capture` and `ci run` alike, and say it in `--no-build`'s help.
- `--no-build` alone keeps today's behaviour, but its completion line says the app was assumed present, e.g.
  `Done — com.kylebrowning.landmarks on cov-android (install skipped, not launched)`, never `installed`.
- `--json` `status` distinguishes installed / launched / skipped.
- GrantivaCLITests (BuildCommandTests or InstallCommandTests): with `noBuild` and `appFile` set, a fake platform records
  an install call (or the command throws the conflict error); with `noBuild` alone, no install and no "installed" text.
