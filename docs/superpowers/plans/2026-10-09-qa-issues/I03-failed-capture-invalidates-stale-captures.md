# Clear or invalidate stale captures when `diff capture` fails, so `diff compare` cannot pass against them

Severity: wrong-result
Platforms: ios
Found by: IOS-F36 (matrix row IOS-093)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
`diff compare` never reports a pass for a capture that did not happen. Source: README §Local Workflow
(capture → compare → approve).

## Actual
With the Detail path made to fail, capture exits 1 and leaves all 5 captures with their old mtimes:
```
    ✗ assertVisible: text="No Such Text QA"
Error: Runner failed (exit 1):
 exited with code 1
```
`diff compare --json` then reports every screen as passed against the previous run's images:
```
{"passed": true, "screens": [{"capture_path": ".grantiva/captures/Deep%20Links.png", "message": "Passed",
 "pixel_diff_percent": 0, ...
```
A CI step that runs compare after a failed capture (e.g. with `|| true`) goes green.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
grantiva diff capture --no-build --simulator qa-ios-1 && grantiva diff approve --json >/dev/null
sed -i '' 's/assert_visible: "Plan Visit"/assert_visible: "No Such Text QA"/' grantiva.yml
ls -lT .grantiva/captures/*.png; grantiva diff capture --no-build --simulator qa-ios-1; echo "capture exit $?"
ls -lT .grantiva/captures/*.png; grantiva diff compare --json | head -c 200
```

## Evidence
- findings/evidence/triage/F36-cap.err, F36-cap.out (empty stdout), F36-cmp.json
- findings/evidence/IOS-094/changed/capture.err, IOS-094/changed/compare.json

## Suspected cause
Sources/GrantivaCore/Runner/RunnerSession.swift:116-125 throws on a non-zero runner exit before touching `outputDir`, and
captures are only replaced per screen at :157-161, so nothing marks the old files stale. DiffCommand's compare reads
whatever is in `.grantiva/captures`.

## Acceptance criteria
- Re-running the repro: after the failed capture, `diff compare` exits non-zero and says the captures are missing or stale
  (no screen reported `passed`).
- Capture writes into a fresh temp dir and swaps it in only on success, or deletes the screen files at start, or writes a
  capture manifest (run id, status) that compare checks. Screens captured before the failure may be kept if the
  manifest marks the run failed.
- GrantivaCoreTests/RunnerSessionTests: a fake runner exiting 1 leaves no pre-existing capture that compare would accept.
