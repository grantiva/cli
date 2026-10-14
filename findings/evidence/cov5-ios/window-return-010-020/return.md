# IOS-010–020 lifecycle window return

The active reservation completed in controller order: IOS-010, IOS-019, IOS-011–018, and IOS-020. Eleven rows are proposed pass, with every original capture and adjacent correction retained.

Final physical inventory has no `cov5-ios-3` or `cov5-ios-4` device. Primary26 `532523A7-30B3-4048-A538-4F3DB2EFB807` and primary27 `EED50B5C-119B-4982-A495-4521CAE8494F` are Booted. Each installed `Landmarks` executable has SHA-256 `966f768a4c7ba3ed5bbc1abf4531221888af4620e1eb7b74c501815fae1a5576`, equal to the frozen app. Protected devices `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C` and `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6` remain Booted.

Main-home sessions contain only the two primaries. The final process inventory contains no owned Grantiva run, WDA xcodebuild, or `simctl diagnose` process. The main created ledger retains one stale entry for physically absent IOS-011 UUID `7833CD8F-7289-465C-9817-EFBFEE58F5AB`: targeted force reclaim reported `reclaimed:false`, exact owned physical deletion succeeded, and the reservation prohibited a main/global cleanup. This is recorded without rewriting the ledger.

Preserved deviations and corrections:

- IOS-011's bounded waiter created `7833CD8F-7289-465C-9817-EFBFEE58F5AB` before waiting and left it Shutdown. Its exact reconciliation is retained with IOS-015.
- IOS-013's first capture reused that IOS-011 name, so it is a fixture mismatch. The corrected capture proves the name absent before invocation, exits nonzero after the configured five seconds, and leaves it absent. Current `SimulatorManager.swift:236–285` creates/registers before waiting and removes the device on the error path; that removal is source-backed inference because the live inventories did not expose the transient UUID, so no UUID is claimed.
- IOS-014 preserves the first bundle-ID validation failure and the successful corrected build/install using the built and frozen identifier `com.kylebrowning.Landmarks`, followed by frozen-app restoration.
- IOS-015 preserves the duplicate-name failure, exact-UUID recovery, and successful two-member session teardown with `deleted:true` for the Grantiva-created fixture and `deleted:false` for the manual fixture.
- IOS-018 preserves the first fixture mismatch, where manual extra4 was absent from the isolated created ledger, and the corrected isolated-home capture with exactly two created entries. Cleanup deletes shutdown extra3, retains active extra4, and leaves all external ledger checksums unchanged.
