# Stop auto-accepting app alerts during flows; accept only system permission prompts

Severity: wrong-result
Platforms: ios
Found by: IOS-F06 (matrix row IOS-030, flow 04)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
The app's own SwiftUI "unsaved changes" alert stays up until the flow taps `Keep Editing`. Source: README §Maestro
Compatibility (drop-in Maestro flows; Maestro never dismisses app alerts on its own).

## Actual
2 of 4 triage runs (4 of 6 in the slice) failed; the alert vanished mid-lookup, taking the edit screen with it, which is
what its default button (Discard) does:
```
    ⚠ assertVisible: text="You have unsaved changes that will be lost." (7.3s)
    ✗ tapOn: text="Keep Editing" (12.6s)
✗ 04-discard 30.1s
```
The runner creates the WDA session with
```
WDA POST /session body={"capabilities":{"alwaysMatch":{"bundleId":"com.kylebrowning.Landmarks","defaultAlertAction":"accept...
WDA POST /session/.../appium/settings body={"settings":{"acceptAlertButtonSelector":"**/XCUIElementTypeButton[`label BEGINSWITH[c] 'Allow' OR l...
```

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
for i in 1 2 3 4 5 6; do grantiva run --no-build --flow .maestro/04-discard.yaml --simulator qa-ios-1 >/dev/null 2>&1; echo "run $i: $?"; done
```
Any non-zero run reproduces it.

## Evidence
- findings/evidence/triage/F06-run{1..4}.err (run2 lines 40-44)
- findings/evidence/IOS-F-04flaky/summary.txt, run2..5.err, run3/maestro-runner.log (lines 23, 29)

## Suspected cause
In the bundled grantiva-runner (outside Sources/): the session sets `defaultAlertAction: accept` and an
`acceptAlertButtonSelector` of `label BEGINSWITH[c] 'Allow' OR label == 'OK'`. When no button matches, WDA's accept
falls back to the alert's default button, so any app alert that appears during the (slow) element polling is accepted.
Grantiva passes no alert option (IOSPlatform.runnerTestArguments, Sources/GrantivaCore/Platform/IOSPlatform.swift:82-84).

## Acceptance criteria
- Re-running the repro 10 times: 10/10 pass.
- Auto-accept is limited to SpringBoard (system) alerts such as permission prompts, or is off by default with an opt-in
  flag (e.g. `--auto-accept-alerts`); app-owned alerts are never dismissed implicitly. Note the change in CHANGELOG.
- Runner-side test: an app alert with buttons "Discard"/"Keep Editing" is still present after an element lookup; a
  GrantivaCoreTests case asserts the runner arguments carry the chosen alert policy.
