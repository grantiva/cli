# Show Gradle's "What went wrong" reason when an Android build fails

Severity: ux
Platforms: android
Found by: AND-F04 (matrix rows AND-024, AND-025)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
A build error the user can act on, non-zero exit. Source: help: build build (`--variant`, `--module`); matrix AND-024/025.

## Actual
```
$ grantiva build build --variant noSuchVariant
[grantiva] Building :app:assembleNoSuchVariant for Pixel_8_API_35...
✗ Build failed
  Scheme: (none)
  Duration: 0.5s
  ✗ FAILURE: Build failed with an exception.
exit 1
```
`--json` gives `"errors" : ["FAILURE: Build failed with an exception."]`. Gradle's reason is not shown anywhere:
```
* What went wrong:
Cannot locate tasks that match ':app:assembleNoSuchVariant' as task 'assembleNoSuchVariant' not found in project ':app'.
```
`--module nosuch` behaves the same. (The `Scheme:` line is covered by A10.)

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva build build --variant noSuchVariant; echo "exit $?"
grantiva build build --variant noSuchVariant --json | jq .errors
./gradlew :app:assembleNoSuchVariant 2>&1 | grep -A1 "What went wrong"
```

## Evidence
- findings/evidence/AND-024/{nosuch.txt,nosuch.json,gradle-direct.txt}, AND-025/module-nosuch.txt

## Suspected cause
Sources/GrantivaCore/Android/GradleBuildRunner.swift:91-93 (`isErrorLine`) keeps only lines starting `e: `, containing
`error:`, or starting `FAILURE:`; the `* What went wrong:` block that follows is dropped.

## Acceptance criteria
- Re-running the repro: text output and the `--json` `errors` array include the "Cannot locate tasks that match
  ':app:assembleNoSuchVariant'..." line (the whole What-went-wrong block, up to `* Try:`).
- Ideally, for an unknown variant/module, also list the available ones (`./gradlew :app:tasks` or the variant list).
- GrantivaCoreTests/GradleBuildRunnerTests: parsing a captured Gradle failure log yields the What-went-wrong text in
  `errors`.
