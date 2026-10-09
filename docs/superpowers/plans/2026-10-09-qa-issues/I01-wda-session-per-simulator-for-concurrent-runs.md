# Give each simulator its own WebDriverAgent test session so concurrent runs on different UDIDs stop killing each other

Severity: wrong-result
Platforms: ios
Found by: IOS-F24 (matrix row IOS-059)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1/qa-ios-2 (iPhone 17, iOS 26.0)

## Expected
Two runs on two different simulators both pass. Source: README §Agent-Native Features, Concurrent runs ("Runs on
different simulator UDIDs execute in parallel"); CHANGELOG 2.0.0.

## Actual
In 3 of 3 paired runs in triage (4 of 4 in the slice) one run failed; each flow passes when run alone right after. The
failing run's WDA comes up on its own port and is gone 0.4 s later:
```
14:59:23.107156 [INFO] Starting WDA on device 93DF5345-... (port: 8485)
14:59:25.344525 [INFO] WDA started successfully on port 8485
14:59:25.739651 [ERROR] WDA GET /window/size failed (4ms): ... dial tcp [::1]:8485: connect: connection refused
    ✗ launchApp (2.3s)
      ╰─ Failed to create session for app: com.kylebrowning.Landmarks — failed to create session: Post
         "http://localhost:8485/session": dial tcp [::1]:8485: connect: connection refused. Check that We...
```
Both runs' WDA is `xcodebuild test-without-building` with the same xctestrun and the same
`-derivedDataPath ~/.grantiva/runner/cache/wda-builds/sim-ios26.0-iphone/DerivedData` (F25 teardown JSON).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
for s in qa-ios-1 qa-ios-2; do grantiva simulator ensure --name $s --device-type "iPhone 17" --runtime 26.0
  grantiva build install --simulator $s; done
for i in 1 2 3; do
  grantiva run --no-build --flow .maestro/06-visit.yaml --simulator qa-ios-1 2>a$i.err & a=$!
  grantiva run --no-build --flow .maestro/07-deeplink.yaml --simulator qa-ios-2 2>b$i.err & b=$!
  wait $a; ea=$?; wait $b; echo "pair $i: a=$ea b=$?"; done
```
Any pair with a non-zero exit reproduces it.

## Evidence
- findings/evidence/triage/F24/{a1,b2,b3}.err and a1/maestro-runner.log (lines 13-24); triage/F25-teardown.json
- findings/evidence/IOS-059/exits*.txt, IOS-059/a4/maestro-runner.log (lines 13-47), IOS-059/solo-*.err

## Suspected cause
The WDA launch lives in the bundled grantiva-runner (outside Sources/): it reuses one DerivedData/xctestrun per
runtime+device family, so the second `test-without-building` on the same bundle tears down the first test session.
Grantiva's side: IOSPlatform.runnerEnvironment (Sources/GrantivaCore/Platform/IOSPlatform.swift:115-118) and
runnerGlobalArguments (:74-80) pass nothing per-UDID, and SimulatorLease (Sources/GrantivaCore/Runner/RunnerSession.swift:35)
only serialises runs on the same UDID.

## Acceptance criteria
- Re-running the repro 5 times: every pair exits 0/0.
- Each concurrent WDA uses a per-UDID derived data / result-bundle path (copy or clone the cached build products per UDID
  rather than rebuild), or Grantiva serialises the WDA launch step across UDIDs with a host lock while letting flows run
  in parallel. Document the chosen behaviour in README §Agent-Native Features (Concurrent runs).
- Test: a GrantivaCoreTests case asserting that runner arguments/environment for two different UDIDs yield distinct
  WDA derived-data paths (or that the launch lock is taken), plus a runner-side regression test.
