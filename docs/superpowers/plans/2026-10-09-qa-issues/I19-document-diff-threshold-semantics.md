# Document that a screen must pass both `diff.threshold` and `perceptual_threshold`, and how the perceptual distance is averaged

Severity: docs
Platforms: ios
Found by: IOS-F28 (matrix row IOS-094)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
README tells users what each key does, so raising `threshold` to loosen a flaky screen works as described. Source:
README.md:111-113 (§Configuration shows `diff: threshold: 0.02, perceptual_threshold: 5.0` with no semantics).

## Actual
With `threshold: 1.0` (100 %), compare still fails screens whose pixel difference is far under it:
```
{"screen_name": "Deep Links", "status": "failed", "message": "Failed: pixel=7.97% perceptual=6.4",
 "pixel_diff_percent": 0.0797, "pixel_threshold": 1, "perceptual_distance": 6.42, "perceptual_threshold": 5}
```
Favorites failed the same way (`pixel=1.01% perceptual=7.7`). Undocumented: (1) a screen passes only if
`pixel ≤ threshold` AND `perceptual ≤ perceptual_threshold`; (2) `perceptual_distance` is the mean CIE76 distance over
the differing pixels only, so a few strongly changed pixels fail a screen whatever `threshold` is; (3) `threshold` is a
fraction (0.02 = 2 %), while messages print percent.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
grantiva diff capture --no-build --simulator qa-ios-1 && grantiva diff approve --json >/dev/null
sed -i '' 's/threshold: 0.02/threshold: 1.0/' grantiva.yml
grantiva diff capture --no-build --simulator qa-ios-1 && grantiva diff compare --json | grep -E '"message"|pixel_threshold'
```
(Fails only when a screen differs, e.g. through the capture race in A04's iOS detail; repeat if all pass.)

## Evidence
- findings/evidence/triage/F28-thr1.json
- findings/evidence/IOS-094/thr1.json, IOS-094/thr1-p100.json (passes only when `perceptual_threshold` is also 100)

## Suspected cause
Sources/GrantivaCLI/DiffCommand.swift:517-518 ANDs the two checks; Sources/GrantivaCore/Diff/ImageDiffer.swift:91 divides
the Lab distance sum by `diffCount`, not by all pixels. README §Configuration never explains either.

## Acceptance criteria
- README §Configuration (and `grantiva init`'s template comment, if any) states: both checks must pass; `threshold` is
  a 0-1 fraction of differing pixels; `perceptual_threshold` is the mean CIE76 ΔE over differing pixels only (0 when
  identical; ~2.3 just noticeable), with a sentence on loosening a screen by raising both.
- If the averaging is changed instead (e.g. over all pixels), note it in CHANGELOG and update ImageDifferTests.
- Doc-only change needs no unit test; if code changes, add ImageDifferTests for a 1-pixel strong change vs. thresholds.
