# Android `run --flow` with no config and no `--application-id` ignores the flow's `appId:` header and fails

Severity: contract
Component: cli
Platforms: android (the iOS half of B-C10.2 passed: with no config iOS uses the header)
Rows: B-C10.2 (android); original brief C10 (QA campaign, criterion 2)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: cluster C23 is split. K23-a (this file) is Android ignoring a literal `appId:` header; K23-b is iOS not
falling back to project detection under `--no-build`. Different code paths.

## Expected
Brief C10 criterion 2 (matrix B-C10.2): `run --flow` with no config and no `--bundle-id`/`--application-id` uses the
flow's `appId:` header. README:174: "`--bundle-id` / `--application-id`, then `bundle_id` / `application_id` in the config
file, then the ID read from `--app-file`, then the flow's own `appId:` header (ignored when it is a `${VARIABLE}`
reference), then project detection." iOS behaves so (cov-ios B-C10.2: "the flow's appId used, setPermissions + scroll
pass, exit 0").

## Actual
Android, from a directory with no `grantiva-android.yml` (B-C10.2/01.out):
```
Resolved: module=app variant=debug device=emulator-5554 screens=0 flows=1
Preparing runner...
Runner ready
Booting emulator: emulator-5554
Emulator booted: cov-android (emulator-5554)
Skipping build and install (--no-build)
Error: Invalid argument: Application ID is required. Pass --application-id, set application_id in grantiva-android.yml, build from source, or pass --app-file <apk>.
rc=1
```
The flow's header is the literal `appId: com.kylebrowning.landmarks`.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k23a
unset GRANTIVA_API_KEY
rm -rf /tmp/k23a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k23a && cd /tmp/k23a/android
SERIAL=$(grantiva emulator ensure --name fix-k23a)
grantiva build install --device "$SERIAL" --no-launch
mkdir -p /tmp/k23a/nocfg/.maestro && cp .maestro/coverage/16-setpermissions.yaml /tmp/k23a/nocfg/.maestro/ && cd /tmp/k23a/nocfg
grantiva run --platform android --device "$SERIAL" --no-build --flow .maestro/16-setpermissions.yaml; echo "exit $?"
cd /tmp/k23a/android; grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k23a
```
Flow `16-setpermissions.yaml` (android copy):
```
appId: com.kylebrowning.landmarks
---
- launchApp
- setPermissions:
    permissions:
      all: allow
- launchApp
- scroll
- takeScreenshot: "Permissions Set"
```

## Evidence
- findings/evidence/cov-android/B-C10.2/01.out, commands.txt
- iOS half (pass): findings/evidence/cov-ios/B-C10.2/

## Suspected cause
The header is consulted, then discarded on Android:
- `Sources/GrantivaCLI/RunCommand.swift:258-273` sets `resolved.bundleId` from `flowBundleId(...)` (:500-506) when no ID
  was given explicitly, and the `--no-build` installed-check at :325-328 even uses it.
- But the ID used for the run comes from `target.installedAppID(...)` at :373-375, and on Android
  `Sources/GrantivaCLI/TargetOptions.swift:144-147` recomputes it from `applicationId` flag, binary ID and config only
  (`androidAppID(flag:binary:configured:)`), ignoring `resolved.bundleId`. With none of the three, it returns nil and
  :374 throws `TargetOptions.appIDMessage(for: .android)` (TargetOptions.swift:161-162).
- iOS returns `resolved.bundleId ?? binaryID` (:144), which is why iOS passes.
(The cluster map's cause, `target.resolve` throwing first, does not hold: `resolveAndroid` (TargetOptions.swift:92-121)
returns a nil application ID without throwing.)

## Acceptance criteria
- The repro runs the flow against `com.kylebrowning.landmarks`, both steps pass, exit 0.
- The order in README:174 holds on Android: `--application-id` > config `application_id` > `--app-file` ID > literal
  flow `appId:` > (detection, if any); a `${VAR}` header is still ignored.
- The mismatch warning for config vs APK (AndroidProject.applicationID) still fires where it applies.
- With no ID anywhere (header `${APP_ID}`, no config, no flag) the existing error is kept.
- GrantivaCLITests (TargetOptionsTests): `installedAppID(platform: .android, ...)` with only `resolved.bundleId` set
  returns it; with a flag and a header, the flag wins.
