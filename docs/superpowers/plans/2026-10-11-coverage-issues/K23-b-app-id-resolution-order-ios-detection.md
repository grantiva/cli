# iOS `run --flow --no-build` never falls back to project detection for the bundle ID, contrary to README:174

Severity: contract
Component: cli
Platforms: ios (Android has no project detection for the application ID)
Rows: IOS-126 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: split from cluster C23 (see K23-a). Detection is skipped on purpose under `--no-build` in code
(ProjectResolver.swift:52: "When `skipBuild` is true, scheme is not required (no xcodebuild needed)"), so the orchestrator
may prefer a README correction ("project detection only when building"). Written as a defect because README:174 ends the
order with project detection without that caveat.

## Expected
README:174: the bundle ID order is flag, config `bundle_id`, `--app-file` ID, the flow's `appId:` header (ignored when
it is a `${VARIABLE}`), then project detection. Matrix IOS-126: with a scheme configured, no `bundle_id`, no flag and
`appId: ${APP_ID}`, the ID comes from project detection.

## Actual
The first two links of the order hold (IOS-126/flag-wins.*: flag beats config; config-next.err: config is used,
`com.example.wrong is not installed on cov-ios-1`). With `grantiva-nobundle.yml`:
```
scheme: "Landmarks (UI Testing)"
simulator: cov-ios-1
flows:
  - appvar.yaml
```
and `appvar.yaml` starting `appId: ${APP_ID}`, `run --no-build --simulator $U1 --flow appvar.yaml --verbose`
(IOS-126/var-ignored.err, last lines) runs no `xcodebuild` and fails:
```
Skipping build and install (--no-build)
Error: Invalid argument: Bundle ID is required to run flows. Pass --bundle-id or set bundle_id in grantiva.yml.
```

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k23b
unset GRANTIVA_API_KEY
rm -rf /tmp/k23b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k23b && cd /tmp/k23b/ios
UDID=$(grantiva simulator ensure --name "fix-k23b iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
printf 'scheme: "Landmarks (UI Testing)"\nflows:\n  - appvar.yaml\n' > grantiva.yml
sed 's/^appId: .*/appId: ${APP_ID}/' .maestro/01-browse.yaml > appvar.yaml
rm -f .grantiva/config.json   # detection cache, ProjectDetector.swift:128
grantiva run --simulator "$UDID" --no-build --flow appvar.yaml --verbose > /tmp/k23b/out.txt 2>&1; echo "exit $?"
grep -E 'xcodebuild|Error' /tmp/k23b/out.txt
grantiva simulator teardown --udid "$UDID"; grantiva simulator delete --name "fix-k23b iPhone 17"
```
Without `--no-build` the same command builds and finds the ID, so only the `--no-build` path is affected.

## Evidence
- findings/evidence/cov-ios/IOS-126/var-ignored.err, flag-wins.*, config-next.err, grantiva-nobundle.yml, appvar.yaml, commands.txt

## Suspected cause
- `Sources/GrantivaCore/Config/ProjectResolver.swift:74-99`: all detection (cache or live `detector.detect()`) sits inside
  `if !skipBuild { ... }`. With `--no-build` (`BuildOptions.shouldSkipBuild`, Sources/GrantivaCLI/Options.swift:49),
  `detected` stays nil and `bundleId` at :118 is `bundleIdFlag ?? config?.bundleId ?? appBundleId ?? nil`.
- `Sources/GrantivaCLI/RunCommand.swift:500-506` (`flowBundleId`) correctly ignores the `${APP_ID}` header, so nothing
  is left and :373-375 throws `TargetOptions.appIDMessage(for: .ios)`.

## Acceptance criteria
- In the repro, the bundle ID is found by detection (cached or `xcodebuild -showBuildSettings` for the configured scheme)
  and the flow runs; or, if detection under `--no-build` is ruled out, README:174 says "project detection (not with
  `--no-build`)" and the error says to pass `--bundle-id` because `--no-build` skips detection.
- When detection is used under `--no-build`, it does not build and does not require a scheme when the cache already
  holds a bundle ID.
- Flag > config > `--app-file` > literal header order unchanged (IOS-126's first two runs still behave as today).
- GrantivaCoreTests (ProjectResolutionTests): `resolve(skipBuild: true, ...)` with scheme, no bundle ID and a stub
  detector returns the detector's bundle ID (or, for the docs option, a test pins the error text).
