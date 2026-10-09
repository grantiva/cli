# Fail with "No scheme specified" (or name the chosen scheme in a warning) when the project has several schemes and none is configured

Severity: contract
Platforms: ios
Found by: IOS-F11 (matrix row IOS-027)
Binary: grantiva 2.0.1 (commit c8dc86d), Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
With no `--scheme` and no `scheme:` in grantiva.yml: "No scheme specified. Pass --scheme, set it in grantiva.yml, or use
--app-file to provide a pre-built binary." Source: README §Pre-built binaries; the message at
Sources/GrantivaCore/Config/ProjectResolver.swift:101-104 and IOSPlatform.swift:34-37.

## Actual
The landmarks project has two schemes (`Landmarks`, `Landmarks (UI Testing)`). With `scheme:` removed:
```
[grantiva] Building Landmarks for qa-ios-1...
✓ Build succeeded
  Scheme: Landmarks
```
exit 0. The non-UI-testing scheme was chosen silently, and the detection is cached in `.grantiva/config.json`, so later
runs keep using it.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
sed -i '' '/^scheme:/d' grantiva.yml
xcodebuild -list -project Landmarks.xcodeproj | sed -n '/Schemes:/,$p'
grantiva build build --simulator qa-ios-1; echo "exit $?"
```

## Evidence
- findings/evidence/triage/F11.out, F11.err
- findings/evidence/IOS-027/out.txt, IOS-027/err.txt

## Suspected cause
Sources/GrantivaCore/Config/ProjectDetector.swift:86 takes `schemes.first`, and ProjectResolver.swift:98 resolves
`flagScheme ?? configScheme ?? detected?.scheme`, so the documented error fires only when detection finds no scheme at
all. The detected value is cached by `saveCache` (ProjectResolver.swift:91).

## Acceptance criteria
- Re-running the repro: exit non-zero with the "No scheme specified" message listing the schemes found (e.g. `Found:
  Landmarks, Landmarks (UI Testing)`), or, if auto-pick is kept, a stderr warning naming the chosen scheme and the
  others. With exactly one scheme, auto-detection still works silently.
- A cached detection never overrides a missing scheme when the project has several.
- GrantivaCoreTests/ProjectDetectorTests (or ProjectResolverTests): `xcodebuild -list` JSON with two schemes and no
  configured scheme yields the error (or warning); with one scheme it resolves to it.
