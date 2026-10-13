# iOS attempts 120b and 121b review

## B2-K17 — duration and status provenance

**Approve the iOS half.** Attempt 121b's live five-screen `diff capture --no-build --json` exits zero and preserves the exact temporary runner `report.json` plus `flow-000.json` before cleanup. `duration-status-audit.json` joins all eight exposed output steps to their runner commands: every status matches, every duration is positive, and output seconds equal report milliseconds divided by 1000. This includes the launch-only Home step at 2.408 seconds rather than a synthetic zero.

The retained attempt 41 exact-negative run supplies the required failure half. Its JSON has real positive durations for launch (1.986), the first passing assertion (1.076), and the failed exact assertion (12.517), with the final status `failed` and its actual message. The matching failure report/flow artifacts are retained. Exact-head `RunnerReportContractTests` pin the same aggregation behavior when commands are matched. Together these prove measured duration/status provenance for both success and failure, including launch-only handling; no unmatched synthetic value is being graded.

## B2-K82-b — run artifacts separated from VRT captures

**Approve the iOS half.** Attempt 120b cleanly separates the namespaces throughout the exact sequence:

- The successful 01-browse run places only its two named screenshots under `.grantiva/run-captures/`.
- The exact-negative run adds only `failure-1791887764.png` there.
- `diff capture` writes exactly the five configured images under `.grantiva/captures/` while leaving those run artifacts intact.
- `diff approve` approves exactly Deep Links, Detail, Favorites, Home and Lakes; it does not approve either `01-browse-cmd-*` image or the failure image.
- `diff compare` returns exactly those five configured screens, all passed, and never treats a run artifact as a VRT screen.

The deliberately old-style baseline `01-browse-cmd-003-Home.png` has identical before/after SHA manifests, so it is preserved rather than silently deleted, yet is excluded from both approval and comparison. The retained README diff excerpt documents the two locations, and the exact-head DiffCommand test excerpt pins configured-screen filtering. All five command exits have the expected values: pass run 0, negative run 1, capture 0, approve 0, compare 0.

## Small correction to the prior 119b review

`ios119b-k33-ios064-review.md` now states the actual signal input: SIGINT was sent to the positive CLI PID. It no longer calls that input a process-group SIGINT.
