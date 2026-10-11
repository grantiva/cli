# `build install --bundle-id <other>` fails with a raw simctl `No such file or directory` instead of naming the bundle ID mismatch

Severity: ux
Component: cli
Platforms: ios (iOS-only: simctl data-container lookup; no Android twin expected)
Rows: IOS-123 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`--bundle-id` is accepted on `build build` and `build install` (help: build_build.txt:21, build_install.txt:26;
matrix IOS-123, which passed for `build build`). When the given ID does not belong to the app that was built and
installed, the error names the ID and the mismatch, in the style the CLI already uses for a missing app
(IOS-044: `com.kylebrowning.Landmarks is not installed on cov-ios-1. Drop --no-build or run grantiva build install.`).

## Actual
bundle-id-other.err (`build install --no-launch --simulator <cov-ios-1> --bundle-id com.example.Other --json`, exit 1):
```
Error: An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=2):
The operation couldn’t be completed. No such file or directory
No such file or directory
```
Nothing says which bundle ID was looked up or that the installed app is `com.kylebrowning.Landmarks`. The app
itself was installed (simctl install does not use the ID) before the failure.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k73
unset GRANTIVA_API_KEY
rm -rf /tmp/k73 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k73 && cd /tmp/k73/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k73 iPhone 17" --runtime 26.0)
grantiva build install --no-launch --simulator "$UDID" --bundle-id com.example.Other --json; echo "exit=$?"
xcrun simctl listapps "$UDID" | grep -c com.kylebrowning.Landmarks           # 1: the app was installed anyway
grantiva simulator teardown --session-id fix-k73
```

## Evidence
- findings/evidence/cov-ios/IOS-123/commands.txt, bundle-id-other.err, bundle-id.out (the accepted `build build`)

## Suspected cause
- `Sources/GrantivaCLI/TargetOptions.swift:144`: on iOS the installed/tested ID is `resolved.bundleId ?? binaryID`,
  so `--bundle-id` wins without any check against the product.
- `Sources/GrantivaCLI/BuildCommand.swift:170-176`: the product is installed (simctl install ignores the ID), then
  `dataContainerPath(bundleId:)` runs `xcrun simctl get_app_container <udid> com.example.Other data`
  (`Sources/GrantivaCore/Build/XcodeBuildRunner.swift:65-67`), whose exit-2 error is thrown unwrapped.
- On iOS the build result carries no `applicationId` (XcodeBuildRunner does not read the product's Info.plist), so
  there is nothing to compare with today.

## Acceptance criteria
- Re-running the repro: exit non-zero before or right after install with a message naming both IDs, for example
  `--bundle-id com.example.Other does not match the built app (com.kylebrowning.Landmarks, …/Landmarks.app/Info.plist).`
  No `NSPOSIXErrorDomain` text.
- With a matching `--bundle-id` (or none) the command behaves as today (IOS-022/IOS-023).
- If the team prefers to keep installing and only fail the container lookup, the lookup failure is mapped to
  `com.example.Other is not installed on <simulator>` plus the installed app's ID.
- GrantivaCLITests/InstallCommandTests: an injected platform whose product Info.plist says `A` and `--bundle-id B`
  produces the mismatch error and never calls the data-container lookup with `B`.
