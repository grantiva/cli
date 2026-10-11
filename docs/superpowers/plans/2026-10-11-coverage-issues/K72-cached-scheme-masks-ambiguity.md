# A cached one-scheme detection keeps picking that scheme silently after the project gains a second scheme

Severity: wrong-result
Component: cli
Platforms: ios (iOS-only: Xcode scheme detection; no Android twin expected)
Rows: B-I13.2 (ios); original brief I13 (~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/I13-no-scheme-with-several-schemes.md)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Brief I13, criterion 2: "A cached detection never overrides a missing scheme when the project has several." With
no `--scheme` and no `scheme:` in grantiva.yml, a project with two schemes fails with
`No scheme specified … Found: Landmarks, Landmarks (UI Testing).` (as B-I13.1 shows on a fresh project).

## Actual
In a copy with the UI Testing scheme removed, `build build` auto-detected `Landmarks` and cached it. The second
scheme was then restored. cache-file.out and after-cache.out:
```
{"project":"Landmarks.xcodeproj","bundleId":"com.kylebrowning.Landmarks","scheme":"Landmarks","detectedAt":813394868.210972,"schemes":["Landmarks"]}
    Schemes:
        Landmarks
        Landmarks (UI Testing)
✓ Build succeeded
  Scheme: Landmarks
exit=0
✓ Build succeeded
  Scheme: Landmarks
exit=0
```
Both builds pick `Landmarks` silently. On a project without that cache the same command fails with the
`Found: …` list (twice.out, exit 1 both times).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k72
unset GRANTIVA_API_KEY
rm -rf /tmp/k72 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k72 && cd /tmp/k72/ios   # 4e49dc4
sed -i '' '/^scheme:/d' grantiva.yml; rm -rf .grantiva
UDID=$(grantiva simulator ensure --name "fix-k72 iPhone 17" --runtime 26.0)
S="Landmarks.xcodeproj/xcshareddata/xcschemes/Landmarks (UI Testing).xcscheme"
mv "$S" /tmp/k72/uitest.xcscheme
grantiva build build --simulator "$UDID" --derived-data-path dd; echo "exit=$?"   # 0, Scheme: Landmarks (one scheme: fine)
cat .grantiva/config.json
mv /tmp/k72/uitest.xcscheme "$S"                                                  # two schemes again
grantiva build build --simulator "$UDID" --derived-data-path dd; echo "exit=$?"   # today: 0, Scheme: Landmarks
grantiva simulator teardown --session-id fix-k72
```
(If the scheme file sits elsewhere, find it with `xcodebuild -list -project Landmarks.xcodeproj` and
`find . -name '*.xcscheme'`.)

## Evidence
- findings/evidence/cov-ios/B-I13.2/commands.txt, cache-file.out, after-cache.out, twice.out/twice.err
- findings/evidence/cov-ios/B-I13.1/ (one-scheme auto-detect that wrote the cache)

## Suspected cause
- `Sources/GrantivaCore/Config/ProjectResolver.swift:76-91`: with no flag or config scheme, `loadCache()` is used
  whenever the cached record has a `schemes` list (:80 only discards caches without one). The cache is never
  checked against the project, so a list recorded when there was one scheme stays authoritative.
- :106-109 then sees `found.count == 1` and :110 takes `detected?.scheme`.
- `ProjectDetector.saveCache`/`loadCache` (Sources/GrantivaCore/Config/ProjectDetector.swift) store `detectedAt` but
  nothing that identifies the project state (e.g. the scheme files' modification times).

## Acceptance criteria
- Re-running the repro: the last `build build` exits non-zero with
  `No scheme specified … Found: Landmarks, Landmarks (UI Testing).`
- A one-scheme project still auto-detects silently, on first and on cached runs.
- The cache cannot supply a scheme when no scheme is configured unless it is known to match the current project
  (either re-detect in that case, or invalidate the cache when the `.xcodeproj`/`.xcworkspace` scheme set changes).
- GrantivaCoreTests/ProjectResolutionTests: a cached `DetectedProject` with `schemes: ["A"]` plus a detector that
  now reports `["A", "B"]` and no configured scheme throws the no-scheme error naming both.
