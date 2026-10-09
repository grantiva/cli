# Use the plain screen name, not percent-encoding, in capture, baseline and diff file names

Severity: ux
Platforms: ios, android
Found by: IOS-F18 (matrix rows IOS-090, IOS-092, IOS-029)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)
Note: the encoding is deliberate (BaselineStore.swift:4, "Keeps a display name reversible"), so the fix is to narrow it,
not drop it; ux stands.

## Expected
Captures and baselines are named after the screen, e.g. `.grantiva/captures/Deep Links.png`. Source: README §Local
Workflow (files named by screen).

## Actual
```
"baseline_path": ".grantiva/baselines/Deep%20Links.png",
"capture_path": ".grantiva/captures/Deep%20Links.png",
"diff_image_path": ".grantiva/captures/diffs/Deep%20Links_diff.png",
```
`run --report-dir` writes the same names into `captures/`. Shell globs, CI artifact viewers and code review show
`%20` names, and the baselines committed to git carry them. Android shows the same names (A04 repro uses
`Deep%20Links.png`).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
grantiva diff capture --no-build --simulator qa-ios-1 --json | grep path; ls .grantiva/captures
```

## Evidence
- findings/evidence/triage/cap1.json, cmp-r1.json; findings/evidence/IOS-090/out.json, IOS-092/layout.txt, IOS-029/rep/captures/

## Suspected cause
Sources/GrantivaCore/Diff/BaselineStore.swift:5-10 (`ScreenArtifact.fileName`) percent-encodes everything outside
`urlPathAllowed` minus `/`, which includes the space; `screenName(from:)` (:12-17) reverses it.

## Acceptance criteria
- Re-running the repro: files are `Deep Links.png` and `diffs/Deep Links_diff.png`; JSON paths match.
- Encode only what cannot appear in one path component (`/`, `:`, NUL, and `%` itself so decoding stays unambiguous),
  and have `screenName(from:)` / the baseline loader accept existing `%20` files, migrating them on `diff approve`. Note
  the rename in CHANGELOG.
- GrantivaCoreTests/ScreenArtifactTests: `fileName(for: "Deep Links") == "Deep Links.png"`, `"a/b"` still yields one
  component, round-trip holds for both forms, and a legacy `Deep%20Links.png` baseline is still found.
