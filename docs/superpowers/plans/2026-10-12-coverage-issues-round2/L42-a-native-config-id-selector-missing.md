# The native `screens:` steps have no id-selector form, so `tap: {id: "clock"}` in grantiva.yml / grantiva-android.yml cannot select by accessibility identifier or resource id

Severity: ux
Component: cli
Platforms: both by source (the native `Step` decoder is shared); observed on Android (B-C08.2, 1 of 1, logical). The iOS half of B-C08.2 passed through the flow-format config, which does carry `id`.
Rows: B-C08.2 [android]
Regresses/extends: C08 criterion 2 (docs/superpowers/plans/2026-10-09-qa-issues/C08-maestro-tapon-id-matches-identifier.md, in git history; #174 fixed criteria 1 and 3 for the flow-format form only). Split from L42-b (the raw error text), same cluster M36.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
C08 criterion 2: "Step gains an id-selector form (e.g. `tap: {id: X}`) carried through FlowGenerator for tap,
assertVisible, assertNotVisible, scrollUntilVisible and extendedWaitUntil." In the native form that means
`tap: {id: X}`, `assert_visible: {id: X}` and `assert_not_visible: {id: X}` select by identifier (iOS accessibility
identifier, Android resource id / Compose test tag), and README's screens section documents it next to
`{text: …, exact: true}`. (The native form has no scrollUntilVisible / extendedWaitUntil keys; those exist only through
the flow-format form, which already carries `id`.)

## Actual
findings/evidence/cov2-android/B-C08.2/01.err, for the config below run through `diff capture`:
```
Error: Invalid argument: grantiva-android.yml could not be parsed: DecodingError.keyNotFound: Key 'text' not found in keyed decoding container. Path: screens[0].path[2].tap. Debug description: No value associated with key CodingKeys(stringValue: "text", intValue: nil) ("text").
grantiva-android.yml:11: unknown key "id"
grantiva-android.yml:12: unknown key "id"
exit=1
```
README :138-152 (c65fc17) lists only the bare label and `{text, exact}` forms, so `{id}` is undocumented as well as
unsupported.

## Repro
Parsing fails before any device is used; `--device` is given so that, after the fix, the command does not resolve the
config's AVD.
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l42
unset GRANTIVA_API_KEY
rm -rf /tmp/l42 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l42 && cd /tmp/l42/android
cat > grantiva-android.yml <<'YAML'
platform: android
module: app
variant: freeDebug
application_id: com.kylebrowning.landmarks
emulator: fix-l42
screens:
  - name: Clock
    path:
      - tap: "Deep Links"
      - tap: "Caching Demo"
      - tap: {id: "clock"}
      - assert_visible: {id: "clock"}
YAML
grantiva diff capture --device emulator-5598 --no-build; echo exit=$?      # unused serial: today a parse error, after the fix a device error
# after the fix, on a real device:
SERIAL=$(grantiva emulator ensure --name fix-l42); grantiva build install --device "$SERIAL" --no-launch
grantiva diff capture --device "$SERIAL" --no-build --json; echo exit=$?   # Clock captured
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l42
```
The same `screens:` block in an iOS `grantiva.yml` should fail the same way today (not run).

## Evidence
- findings/evidence/cov2-android/B-C08.2/01.out, 01.err, 01.cmd, commands.txt
- findings/evidence/cov2-android/inputs/flows/native-id.yml (the config as run)
- findings/cov2-android-results.md row B-C08.2

## Suspected cause
- `Sources/GrantivaCore/Config/GrantivaConfig.swift:29-60`: `Screen.Step` has `tapById` / `assertVisibleById` /
  `assertNotVisibleById` (`:40-42`), documented as set only by the flow-file parser and not grantiva.yml keys.
- The native decoder `Step.init(from:)` (`:121-136`) accepts a bare string or `Label {text, exact}` (`:112-119`); an
  `{id}` mapping fails `Label`'s required `text`.
- `ConfigKeyValidator.swift:28-31` checks label mappings against `Label.CodingKeys` (`text`, `exact`), so `id` is
  reported as unknown.
- Only `MaestroFlowParser.swift:499` (`parseTapSelector`) sets `tapById`; `FlowGenerator.swift:69` and
  `SessionCapture.swift:179` already honour the flags, so the downstream path exists.

## Acceptance criteria
- `tap`, `assert_visible` and `assert_not_visible` accept `{id: "X"}` (and reject `{id, text}` together with a config
  error naming the step); the generated flow carries `id: "X"` (FlowGenerator) and the MCP session capture selects by id.
- `{id}` is not reported as an unknown key; README's screens section documents it.
- The repro captures Clock on Android (Caching Demo's `clock` test tag); an iOS config with `{id: "clock"}` captures it
  on iOS.
- Tests: GrantivaCoreTests/GrantivaConfigPlatformTests.swift decodes `tap: {id: "clock"}` into `tap == "clock"`,
  `tapById == true` (same for the two asserts) and round-trips it through `encode`; FlowGeneratorTests asserts it is
  emitted as `id:`; the key validator emits no warning for it.
