# Round 4 iOS coverage results

| ID | result | evidence | note |
|---|---|---|---|
| IOS-001 | pass | findings/evidence/cov4-ios/IOS-001/ | Fresh inferred-type simulator created on latest iOS, booted, UUID-only stdout. |
| IOS-002 | pass | findings/evidence/cov4-ios/IOS-002/ | Same UUID reused with Booted diagnostic, then exact owned cleanup. |
| IOS-003 | pass | findings/evidence/cov4-ios/IOS-003/ | Explicit iPhone 17 on latest installed runtime iOS 27.0; retained for IOS-019. |
| IOS-004 | pass | findings/evidence/cov4-ios/IOS-004/ | iOS 26.0 succeeds; 99.9 clearly refuses and creates nothing. |
| IOS-005 | pass | findings/evidence/cov4-ios/IOS-005/ | Fresh simulator created Shutdown with UUID-only stdout. |
| IOS-006 | pass | findings/evidence/cov4-ios/IOS-006/ | New/reuse JSON includes correct identity, runtime, state, and geometry. |
| IOS-007 | pass | findings/evidence/cov4-ios/IOS-007/ | Model-less absent name refused with documented guidance and no creation. |
| IOS-008 | pass | findings/evidence/cov4-ios/IOS-008/ | Concurrent calls returned one UUID with one Created and one Reused result. |
| IOS-009 | pass | findings/evidence/cov4-ios/IOS-009/ | Owned created UUIDs are recorded in the frozen runner-home capacity ledger. |
| IOS-010 | pass | findings/evidence/cov4-ios/IOS-010/ | Plain/JSON list only managed owned slots; ISO timestamps valid and manual booted devices excluded. |
