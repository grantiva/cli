# A Maestro-format `grantiva-android.yml` does not parse, so Android screens have no id-selector route

Severity: wrong-result
Component: cli
Platforms: android (Android-only: iOS already parses the Maestro form; the iOS half of B-C08.2 passed through it)
Rows: AND-128, B-C08.2 (android); original brief C08 (QA campaign, criterion 2)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
- README:154-172 ("write `grantiva.yml` in Maestro format", with `appId:` header and commands) documents the Maestro
  form for the config file; docs/android.md does not say Android lacks it. Matrix AND-128: a Maestro-format
  `grantiva-android.yml` is read, every step executes, one capture per `takeScreenshot` (README:132-172).
- Brief C08 criterion 2 (matrix B-C08.2): screen steps gain an id-selector form (e.g. `tap: {id: X}`), carried through
  FlowGenerator for tap, assertVisible, assertNotVisible, scrollUntilVisible and extendedWaitUntil. On iOS this is
  met via the Maestro-format config (`tapOn: {id: ...}` → `tapById`); the native `{text, exact}` mapping (README:136-146)
  has no `id` key on either platform.

## Actual
Maestro-format config as `grantiva-android.yml` (AND-128/02.err, same with `--platform android` in 03):
```
Error: Invalid argument: grantiva-android.yml could not be parsed: DecodingError.dataCorrupted: Data was corrupted. Debug description: The given data was not valid YAML.. Underlying error: 2:1: error: composer: expected a single document in the stream in line 1, column 1
but found another document:
---
^
grantiva-android.yml:1: unknown key "appId"
```
Native config with `assert_visible: {id: "clock"}` (B-C08.2/01.out):
```
Error: Invalid argument: grantiva-android.yml could not be parsed: DecodingError.keyNotFound: Key 'text' not found in keyed decoding container. Path: screens[0].path[2].assert_visible. ...
rc=1
```
So Android has no way to select a screen step by id. (The native screens-steps config works: AND-128/01, 6 captures.)

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k24
unset GRANTIVA_API_KEY
rm -rf /tmp/k24 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k24 && cd /tmp/k24/android
SERIAL=$(grantiva emulator ensure --name fix-k24)
grantiva build install --device "$SERIAL" --no-launch
cp .maestro/coverage/cfg/maestro-format.grantiva-android.yml grantiva-android.yml
grantiva diff capture --device "$SERIAL" --no-build; echo "exit $?"
git checkout grantiva-android.yml
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-k24
```
`.maestro/coverage/cfg/maestro-format.grantiva-android.yml`:
```
appId: com.kylebrowning.landmarks
---
- launchApp
- swipe:
    direction: UP
- waitForAnimationToEnd
- takeScreenshot: "Home Swiped"
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- extendedWaitUntil:
    visible: "Cache Policy"
    timeout: 5000
- tapOn:
    id: "clock"
- assertVisible:
    id: "clock"
- takeScreenshot: "Caching Maestro"
```

## Evidence
- findings/evidence/cov-android/AND-128/02.err, 03.err (Maestro form), 01.out (native form works), maestro-format.yml, screens-steps.yml, commands.txt
- findings/evidence/cov-android/B-C08.2/01.out, config.yml, commands.txt
- iOS half: findings/evidence/cov-ios/IOS-141/, IOS-142/ (B-C08.2 pass on iOS)

## Suspected cause
- `Sources/GrantivaCore/Config/GrantivaConfig.swift:305`: `if platform == .ios, MaestroFlowParser.isMaestroFormat(contents)`
  gates the Maestro parser to iOS (introduced with Android support, 3372b75). On Android the file falls through to the
  native YAML decoder, which rejects the two-document stream and the `appId` key.
- The id route exists only in the Maestro parser: `MaestroFlowParser.swift:274-276, 346, 362, 369` set
  `tapById`/`assertVisibleById`/`assertNotVisibleById`; the native `Step` decoder (GrantivaConfig.swift:110-123) reads
  `tap`/`assert_visible`/`assert_not_visible` only as a string or `Label {text, exact}`.
- For Android the parsed config must also carry an `AndroidProject` (module/variant/emulator defaults, and
  `application_id` from `appId:`), which `MaestroFlowParser.parse` does not build today; check FlowGenerator's Android
  output for the id selectors (`id:` maps to resource-id/test tag on UIAutomator2).

## Acceptance criteria
- The repro captures `Home Swiped` and `Caching Maestro`, every step runs (the `tapOn {id: clock}` and
  `assertVisible {id: clock}` steps show as id selectors), exit 0; same with `--platform android`.
- A Maestro-format `grantiva-android.yml` gets Android defaults (module `app`, variant `debug`) and the `appId` as
  application ID unless a flag overrides it.
- B-C08.2's native config either keeps failing with a clear message pointing to the Maestro form, or gains
  `{id: ...}` on `tap`/`assert_visible`/`assert_not_visible` on both platforms (then README:136-146 documents it).
- docs/android.md states the Maestro config form is supported.
- GrantivaCoreTests (GrantivaConfigPlatformTests): `load(platform: .android)` of the Maestro fixture returns screens with
  `tapById`/`assertVisibleById` set; FlowGeneratorTests: the Android flow emits `id:` for those steps.
