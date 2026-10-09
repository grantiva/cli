# Let `screens:` `tap:` steps request an exact match, or prefer an exact full-text hit over a substring hit

Severity: enhancement
Platforms: android
Note: iOS likely affected too, same generated flow.
Found by: AND-F07 (NOT A BUG; matrix rows AND-042), triage "Enhancement"
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
The stock label-contract path `tap: "Landmarks"` then `tap: "Lakes"` works on Android. Today the documented behaviour is
the cause: CHANGELOG.md:128 ("`text:` matching is case-insensitive and unanchored ... `exact: true` on a selector now
matches the full string"), and `screens:` steps cannot say `exact: true`.

## Actual
On Deep Links, `tapOn: "Landmarks"` clicks the `landmarks://landmark/golden-gate-bridge` button (bounds [200,752][881,805],
first in tree order) rather than the bottom tab whose text is exactly `Landmarks` ([89,2253][256,2295]):
```
client.log: textContains("Landmarks") ... click (540,779)
```
The capture shows Golden Gate Bridge detail, and the stock screens path then fails at `tap: "Lakes"`. Because screens run
before flows and a failed screen aborts the suite (C04), the app's 12 configured flows never run.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva run --no-build --flow $QA/findings/evidence/flows/qa-tab-landmarks.yaml --device emulator-5554 \
  --snapshot full --report-dir /tmp/a13
open /tmp/a13/captures/qa-tab-landmarks-cmd-003-AfterLandmarksTap.png     # Golden Gate Bridge detail
grantiva diff capture --no-build --device emulator-5554                    # stock config: fails at "Lakes"
```

## Evidence
- findings/evidence/AND-042-screens/report/{client.log,captures/qa-tab-landmarks-cmd-003-AfterLandmarksTap.png}
- findings/evidence/AND-061/hierarchy-immediate.xml, AND-042/report/captures/failure-*.png

## Suspected cause
Sources/GrantivaCore/Config/GrantivaConfig.swift:28-50 (`Step.tap` is a bare `String`) and
Sources/GrantivaCore/Runner/FlowGenerator.swift:37-39 (emits `- tapOn: "<label>"` with no selector options). Runner
(~/Developer/maestro-runner pkg/driver/uiautomator2/driver.go:1142-1160): `textContains` first hit in tree order wins.

## Acceptance criteria
- `tap:` (and `assert_visible`/`assert_not_visible`) accept a mapping form `{text: "Landmarks", exact: true}` that
  FlowGenerator emits as `tapOn: {text: ..., exact: true}`; and/or the runner prefers a node whose full text equals the
  query before falling back to substring matches (document which in CHANGELOG and README).
- With either change, the stock landmarks `screens:` config captures Lakes and Detail on Android.
- GrantivaCoreTests: GrantivaConfig decoding of the mapping form, and a FlowGeneratorTests case emitting `exact: true`.
