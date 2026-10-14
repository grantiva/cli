# Final candidate iOS coverage results

Candidate 4 smoke gate and standing delegation are active. Results below are proposed from fresh candidate-bound captures and remain subject to independent review.

Exact ordered obligations are frozen in `findings/evidence/cov5-ios/preparation/execution-manifest.json`: 536 iOS effective keys, 39 supplemental iOS 27.0 qualifications, and six CLI-owned iOS-actor handoffs.

| ID | result | evidence | note |
|---|---|---|---|
| IOS-001 | pass | findings/evidence/cov5-ios/IOS-001/ | Literal name-only creation selected observed latest iOS 27.0; 4/4 clauses. |
| IOS-002 | pass | findings/evidence/cov5-ios/IOS-002/ | Same UUID reused Booted and then exactly deleted; 3/3 clauses. |
| IOS-003 | pass | findings/evidence/cov5-ios/IOS-003/ | Explicit iPhone 17/latest created on iOS 27.0 and retained for IOS-019; 3/3 clauses. |
| IOS-004 | pass | findings/evidence/cov5-ios/IOS-004/ | Intermediate inventory proves iOS 26.0; 99.9 refused without creation; 5/5 clauses. |
| IOS-005 | pass | findings/evidence/cov5-ios/IOS-005/ | Intermediate inventory independently proves Shutdown before deletion; 4/4 clauses. |
| IOS-006 | pass | findings/evidence/cov5-ios/IOS-006/ | New/reuse JSON identities, runtimes, states, and geometry are correct; 5/5 clauses. |
| IOS-007 | pass | findings/evidence/cov5-ios/IOS-007/ | Model-less name refused with guidance and remained absent; 3/3 clauses. |
| IOS-008 | pass | findings/evidence/cov5-ios/IOS-008/ | Two exact concurrent captures yielded one Created and one Reused device; no log-PID authentication claim; 5/5 clauses. |
| IOS-009 | pass | findings/evidence/cov5-ios/IOS-009/ | Isolated ledger and current inventory match both owned extra UUIDs; 3/3 clauses. |
| IOS-010 | pass | findings/evidence/cov5-ios/IOS-010/ | Plain/JSON managed sessions include owner/session and ISO timestamps and exclude manually booted protected devices. |
| IOS-019 | pass | findings/evidence/cov5-ios/IOS-019/ | Exact retained Pin deleted; repeated exact name returns clear nonzero missing-name error. |
| IOS-011 | pass | findings/evidence/cov5-ios/IOS-011/ | 3/3 warning names only the three Grantiva-booted occupants; bounded first capture retained. |
| IOS-012 | pass | findings/evidence/cov5-ios/IOS-012/ | 1/1 warning names only primary26 after targeted shutdowns. |
| IOS-013 | pass | findings/evidence/cov5-ios/IOS-013/ | Corrected absent-name leg times out nonzero after configured 5s and leaves no named device; original fixture mismatch retained. |
| IOS-014 | pass | findings/evidence/cov5-ios/IOS-014/ | Same-session scratch-source build/install succeeds with one durable owner; initial bundle-ID guard failure retained and frozen app restored. |
| IOS-015 | pass | findings/evidence/cov5-ios/IOS-015/ | Scoped session deletes Grantiva-created extra3 and only shuts down manual extra4; duplicate-name deviation and exact recovery retained. |
| IOS-016 | pass | findings/evidence/cov5-ios/IOS-016/ | Authenticated keep-alive parent killed; force reclaim reaps orphan WDA xcodebuild/diagnose and removes device home/temp state. |
| IOS-017 | pass | findings/evidence/cov5-ios/IOS-017/ | Exact owned free UUID exits 0 with `reclaimed:false`. |
| IOS-018 | pass | findings/evidence/cov5-ios/IOS-018/ | Corrected isolated ledger contains two fixtures; cleanup deletes shutdown extra3 only, preserves active extra4, and external checksums match. |
| IOS-020 | pass | findings/evidence/cov5-ios/IOS-020/ | Manual extra3 passes flow, takes no managed slot, remains Booted after empty session teardown, then is retired exactly. |
| IOS-117 | fail | findings/evidence/cov5-ios/IOS-117/ | Exact iOS 26 stock invocation fails in configured Detail screen before flows: after Lakes, the successful `tapOn: Landmarks` leaves Lakes content visible and Golden Gate Bridge is absent; matching the selected tab/back-label element is an inference because the raw trace exposes no matched element ID. First failure preserved. |
| IOS-118 | pass | findings/evidence/cov5-ios/IOS-118/ | Exact iOS 27 stock invocation captures 5/5 screens, passes 12/12 flows, and uses the cached iOS 27 agent. |
| IOS-119 | pass | findings/evidence/cov5-ios/IOS-119/ | Crash flow exits 1 at the first assertion with app-crashed/not-running cause and failure screenshot. |
| IOS-120 | fail | findings/evidence/cov5-ios/IOS-120/ | iOS 27 captures 5/5; iOS 26 independently repeats the observed post-Lakes navigation failure; a selector collision is the source-backed inference, so the required dual-runtime clause fails. |
