# Replace raw NSError dumps with actionable messages: hierarchy timeout, app not installed under `--no-build`

Severity: ux
Platforms: ios
Found by: IOS-F15, IOS-F23 (matrix rows IOS-055, IOS-044)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1/qa-ios-2 (iPhone 17, iOS 26.0)

## Expected
- `hierarchy --timeout` gives up "with a clear error" (help: hierarchy `--timeout`).
- `run --no-build` with the app missing says the app is not installed (help: run `--no-build` assumes it is installed).

## Actual
F15, `hierarchy --udid qa-ios-2 --timeout 0.01` (exit 1; the timeout itself works):
```
Error: Error Domain=NSURLErrorDomain Code=-1001 "The request timed out." UserInfo={_kCFStreamErrorCodeKey=-2102,
NSUnderlyingError=0x7900ccc810 {Error Domain=kCFErrorDomainCFNetwork Code=-1001 "(null)" UserInfo={...}}, ...
NSErrorFailingURLStringKey=http://127.0.0.1:8129/source, ...}
```
F23, after `simctl uninstall`: 7.5 KB of stderr repeating, per step,
```
    ✗ launchApp (2.0s)
      ╰─ Failed to create session for app: com.kylebrowning.Landmarks — ... FBSOpenApplicationServiceErrorDomain Code=4
         ... returned nil for "com.kylebrowning.Landmarks" ... Check that WebDriverAgent is still running on
         http://localhost:8485 and that no other run holds its port. (cause: ...same NSError again...)
```
It never says "not installed", and the hint sends the user after WebDriverAgent.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
for s in qa-ios-1 qa-ios-2; do grantiva simulator ensure --name $s --device-type "iPhone 17" --runtime 26.0; done
grantiva build install --simulator qa-ios-2
grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-2 --keep-alive --ready-file /tmp/i15.ready &
while [ ! -f /tmp/i15.ready ]; do sleep 0.2; done
grantiva hierarchy --udid "$(grantiva simulator ensure --name qa-ios-2)" --timeout 0.01; kill -INT %1; wait
xcrun simctl uninstall qa-ios-1 com.kylebrowning.Landmarks
grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-1 2>&1 | wc -c
```

## Evidence
- findings/evidence/triage/F15.err, F23.err; findings/evidence/IOS-055/t001.err, IOS-044/err.txt

## Suspected cause
- Sources/GrantivaCLI/HierarchyCommand.swift:86-87: `URLSession.shared.data(for:)` errors propagate unmapped, so the
  NSError description is printed verbatim.
- The FBS text and WDA hint come from the bundled runner. Under `--no-build`, Sources/GrantivaCLI/RunCommand.swift:215-216
  skips install without checking that `resolved.bundleId` is installed (XcodeBuildRunner.swift:66 already shows the
  `simctl get_app_container` probe).

## Acceptance criteria
- Re-running the repro: hierarchy prints one line, e.g. `Error: GrantivaAgent on port 8129 did not answer within 0.01s
  (--timeout). Is the run still alive?`; the `--no-build` run fails before the runner starts with `com.kylebrowning.Landmarks
  is not installed on qa-ios-1. Drop --no-build or run grantiva build install.`
- Map URLError (`.timedOut`, `.cannotConnectToHost`) to GrantivaError messages with the port and remediation.
- Tests: HierarchyCommandTests maps a URLError.timedOut to the one-line message; RunCommandTests with a fake
  `get_app_container` failure asserts the not-installed error and that the runner is never launched.
