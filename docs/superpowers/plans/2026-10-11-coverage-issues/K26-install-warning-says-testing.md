# `build install` warns that it is "testing" an application ID, though it only installs

Severity: ux
Component: cli
Platforms: android (Android-only: application_id handling)
Rows: B-A03.2 (android); original brief A03 (QA campaign, criterion 2)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Brief A03 criterion 2 (matrix B-A03.2): the config-vs-APK application ID rule also applies to `--variant` builds and to
`build install`. The ID handling itself passes (the paid variant is installed under its own ID, text and `--json`).
The warning should fit the command: for `build install` it talks about installing (e.g. `installing
com.kylebrowning.landmarks.paid`), not about testing.

## Actual
`build install --variant paidDebug --device emulator-5554 --no-launch` (B-A03.2/01.err, 01.out):
```
Warning: application_id com.kylebrowning.landmarks in grantiva-android.yml differs from the app's own application ID com.kylebrowning.landmarks.paid; testing com.kylebrowning.landmarks.paid. Update application_id or pass --application-id to override.
[grantiva] Installing com.kylebrowning.landmarks.paid...
[grantiva] Done — com.kylebrowning.landmarks.paid installed on cov-android (not launched)
```
`--application-id` does not "override" what `build install` installs either: the APK is installed under its own ID
(`installAppID`), so the advice is also misleading here.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k26
unset GRANTIVA_API_KEY
rm -rf /tmp/k26 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k26 && cd /tmp/k26/android   # config application_id: com.kylebrowning.landmarks
SERIAL=$(grantiva emulator ensure --name fix-k26)
grantiva build install --variant paidDebug --device "$SERIAL" --no-launch 2>&1 | grep -E 'Warning|Done'
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k26
```

## Evidence
- findings/evidence/cov-android/B-A03.2/01.out, 01.err (text), 02.out, 02.err (`--json`), commands.txt

## Suspected cause
- `Sources/GrantivaCore/Config/AndroidProject.swift:34-44` (`applicationID(override:binary:configured:)`) builds one
  message for every caller; line 41 hard-codes `testing \(binary). Update application_id or pass --application-id to
  override.` (line 37 likewise says `testing` for the flag case).
- Callers: `TargetOptions.installedAppID` (Sources/GrantivaCLI/TargetOptions.swift:140-148) from both
  `RunCommand.swift:373` (where "testing" is right) and `BuildCommand.swift:162` (where it is not).

## Acceptance criteria
- `build install` with the mismatch prints e.g. `Warning: application_id com.kylebrowning.landmarks in
  grantiva-android.yml differs from the app's own application ID com.kylebrowning.landmarks.paid; installing
  com.kylebrowning.landmarks.paid. Update application_id to match.` (no "testing", no `--application-id` advice
  unless that flag changes what is installed).
- `run` keeps the "testing ..." wording.
- `--json` output unchanged apart from the warning text on stderr.
- GrantivaCoreTests (or GrantivaCLITests TargetOptionsTests): the warning for the install context contains
  "installing" and not "testing"; for the run context it contains "testing".
