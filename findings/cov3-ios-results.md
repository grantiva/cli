# iOS slice results: round 3 coverage pass

Binary `/Users/kyle/.grantiva-qa/bin/grantiva`, SHA-256 `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`, version 2.1.0; runner `1.1.28-grantiva.13+android-drivers-2`; runner home `/Users/kyle/.grantiva-qa/runner`; session `cov3-ios`.

Only raw captures known to predate the invalid historical import, plus the ten post-recovery focused groups listed in `findings/evidence/cov3-ios/PROVENANCE.md`, are graded here. `findings/cov3-ios-results.imported-invalid.md` and `findings/evidence/cov3-ios-historical-cov2-import/` are excluded.

| ID | result | evidence | note |
|---|---|---|---|
| B3-L08.1 | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Both protected owner simulators were already booted; guarded no-simulator MCP build was not sent. |
| B3-L08.2 | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Both protected owner simulators were already booted; guarded default-path CLI calls were not sent. |
| B2-K37.2 [ios] | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Default-device guard prohibited the no-simulator call. |
| MCP-031 [ios] | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | No-simulator call is graded by the same guard and was not sent. |
| N3-12 | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Protected owner simulators were already booted; guarded MCP calls were not sent. |
| N3-13 | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Required empty booted list was unavailable; guarded MCP build was not sent. |
| IOS-001 | pass | findings/evidence/cov3-ios/IOS-001/ | Created and booted `cov3-ios-3 iPhone 17` as UDID `2E3D6203-A4A0-4C8C-A3D6-05EE4D608EE3`; stdout only UDID. |
| IOS-002 | pass | findings/evidence/cov3-ios/IOS-002/ | Reuse returned the same UDID and `Reused … — Booted`. |
| IOS-003 | pass | findings/evidence/cov3-ios/IOS-003/ | `cov3-ios-4 Pin` created as iPhone 17 on newest runtime. |
| IOS-004 | pass | findings/evidence/cov3-ios/IOS-004/ | Runtime 26.0 created; 99.9 refused; no 99.9 device created; row device deleted. |
| IOS-009 | pass | findings/evidence/cov3-ios/IOS-009/ | Campaign device is in the QA runner home's capacity ledger; owner-home grep has no campaign entry. |
| IOS-010 | pass | findings/evidence/cov3-ios/IOS-010/ | Text and JSON list only the three campaign-owned slots; booted owner devices are absent. |
| IOS-011 | pass | findings/evidence/cov3-ios/IOS-011/ | Capacity warning names exactly three campaign devices; timeout leaves no fourth device. |
| IOS-012 | pass | findings/evidence/cov3-ios/IOS-012/ | Limit 1 waits and times out while three campaign slots are active. |
| IOS-013 | pass | findings/evidence/cov3-ios/IOS-013/ | Five-second capacity timeout exits nonzero and leaves no device or ledger record. |
| IOS-019 | pass | findings/evidence/cov3-ios/IOS-019/ | First delete succeeds; second clearly reports simulator not found. |
| IOS-117 | pass | findings/evidence/cov3-ios/IOS-117/ | iOS 26.0 stock set: 5/5 screens and 12/12 flows; cache `sim-ios26.0-iphone-wda16.12.8-r1`. |
| IOS-118 | pass | findings/evidence/cov3-ios/IOS-118/ | iOS 27.0 stock set: 5/5 screens and 12/12 flows; cache `sim-ios27.0-iphone-wda16.12.8-r1`. |
| IOS-119 | pass | findings/evidence/cov3-ios/IOS-119/ | Crash flow exits 1 at first assertion with `app crashed` / not-running cause and failure summary. |
| IOS-120 | pass | findings/evidence/cov3-ios/IOS-120/ | Five configured screens captured on both iOS 26.0 and 27.0. |
| IOS-151 | pass | findings/evidence/cov3-ios/IOS-151/ | No-build Maps flow accepts the location alert, records the note, and passes. |
| IOS-239 @27.0 | pass | findings/evidence/cov3-ios/IOS-239@27.0/ | iOS 27.0 Maps repeat accepts the location alert and passes. |
| B3-L10 [ios] | pass | findings/evidence/cov3-ios/B3-L10/ | Plain and quiet stdout both contain the failed flow block and totals; quiet preserves the error; JSON shape remains valid. |
| B3-L13 [ios] | pass | findings/evidence/cov3-ios/B3-L13/ | Fresh start/stop JSON; stopped shape includes port, app ID aliases, UDID, runnerPid, killed and reaped. |
| B3-L19 [ios] | pass | findings/evidence/cov3-ios/B3-L19/ | Text and JSON preserve `runFlow: 14-runflow-sub.yaml`; no absolute staged path. |
| B3-L21 | pass | findings/evidence/cov3-ios/B3-L21/ | Doctor and refusal use `iPhone 17` / `iOS 26.0`, never raw identifiers. |
| B3-L39 [ios] | pass | findings/evidence/cov3-ios/B3-L39/ | launched/installed carry appPath; skipped carries explicit null appPath. |
| B3-L43 [ios] | pass | findings/evidence/cov3-ios/B3-L43/ | Start JSON and session.json use documented iOS field names and aliases. |
| B3-L60 | pass | findings/evidence/cov3-ios/B3-L60/ | Idle duration-3 recording is exactly 3.000000 seconds by ffprobe. |
| N3-05 [ios] | pass | findings/evidence/cov3-ios/N3-05/ | Existing simulator reports `Reused cov3-ios-26 (…) — Booted` and its UDID. |
| N3-07 [ios] | pass | findings/evidence/cov3-ios/N3-07/ | Hierarchy and runner-dump JSON frame members are numeric. |
| N3-14 | pass | findings/evidence/cov3-ios/N3-14/ | QA-home sessions contain only campaign devices; owner-home capacity ledger is absent and was not created. |

## Honest current counts

Matrix base rows recorded: 31 of 478 (pass 25, blocked 6, fail 0, n/a 0). iOS 27.0 repeat lines: 1 pass. Unrun matrix base rows: 447.

The stock and coverage batches may support additional matrix rows, but those rows remain unrun in this ledger until their exact input/expectation is mapped to raw output. No round-2 outcome is used as a round-3 verdict.
