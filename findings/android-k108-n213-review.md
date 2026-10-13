# Android B2-K108 and N2-13 scoped review

Candidate provenance: CLI `8f2cff67`, runner `fd9d8e8`. Current round evidence only.

## B2-K108: partial, do not grade yet

The device-free corpus and two cases are valid:

- `metrics-json.out` measures the copied retained pair at pixel `0.0642299` (rendered `6.42%`) and perceptual `44.3272`.
- `pixel-only-*` exits 1 in text and JSON and correctly says `pixel=6.42% exceeds threshold 0.03%`; perceptual `44.3` remains below `45.3`.
- `both-*` exits 1 in text and JSON and names both `threshold 0.03%` and `perceptual_threshold 22.2`.
- The JSON documents retain the normal comparison fields and differ through the expected failure message/result values. The text rendering contains the JSON failure message.
- Exact-head `DiffCommandTests.swift.excerpt` and `CIComparisonPipelineTests.swift.excerpt` cover the shared formatter, including the CI path. Android CI runtime remains intentionally unsupported under the campaign ruling.

The purported perceptual-only case is invalid. `perceptual-only-grantiva-android.yml` sets pixel threshold `0.010642...`, rendered as only `1.06%`; the observed pixel difference is `6.42%`. Accordingly both checks fail and both are named in `perceptual-only-{text,json}.out`. The harness divided a JSON fraction as though it were a percentage. Its final assertion accepted this because it checked for the perceptual phrase without requiring the pixel threshold to remain unexceeded.

Smallest complement: reuse the frozen copied pair, set `threshold: 1.0` and `perceptual_threshold: 22.2`, run text and JSON, and assert the message contains `exceeds perceptual_threshold` while it does **not** contain `exceeds threshold`. Preserve the original output and add a new uniquely named complement.

## N2-13: pass

The exact matrix set is complete through current joins:

- `CF-crash1`, `CF-crash2`, and `CF-crash3` each run the stock `.maestro/99-crash.yaml`, exit 1, and retain reports.
- `B3-L49-L50-crash-waits-rerun1` supplies three current repetitions each of the first-post-launch `extendedWaitUntil: {visible: ...}` and `assertNotVisible` variants. Their reports fail at `launchApp` with `error.type: app_crash` and `RuntimeException: LANDMARKS_CRASH_ON_LAUNCH`; the wait never passes.
- `N2-13-crash-wait-complements-rerun1` adds the exact missing `scrollUntilVisible` and `waitForAnimationToEnd` first-post-launch forms. `decoded.json` records exit 1, `launchStatus: failed`, `waitStatus: skipped`, `errorType: app_crash`, and the RuntimeException message for both. They finish in 4.83 s and 4.72 s, well below the wait timeout.

The complement wrapper's success is appropriate: it expected the two CLI commands themselves to exit nonzero and then asserted all five evidence conditions. No wait is reported passed against the dead app.

## Evidence roots

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K108-threshold-wording-devicefree-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/N2-13-crash-wait-complements-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L49-L50-crash-waits-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/CF-crash{1,2,3}/`

## B2-K108 complement review

`B2-K108-perceptual-only-complement1` closes the sole gap above. Its `commands.json` pins the same retained PNG hashes and records exact device-free text and JSON commands with explicit `--platform android`; both exit 1. The config sets `threshold: 1.0` (rendered `100.00%`) and `perceptual_threshold: 22.2`. Both outputs measure pixel `6.42%` and perceptual `44.3`, and the exact message is purely perceptual: `perceptual=44.3 exceeds perceptual_threshold 22.2 (pixel=6.42%, threshold 100.00%)`. It does not claim that the pixel threshold was exceeded. `decoded.json` independently records all five required checks true.

**Final B2-K108 [android] verdict: PASS.** The original corpus supplies valid pixel-only and both-threshold text/JSON cases, this complement supplies the valid perceptual-only text/JSON case, and the retained exact-head tests establish the shared `diff compare`/CI formatter while Android CI execution remains outside the supported runtime surface.
