# Task 8 force marker semantics fix review

**Verdict: APPROVED.** The correction removes the false physical-deletion claim while preserving the force-teardown acceptance requirements. The helper, README, manifest, harness table, and preparation reports consistently distinguish Grantiva resource reclaim from later physical simulator cleanup. No new defect was found in the scoped change.

The helper still requires the force command's JSON to report `runnerSessionStopped: true` and `reclaimed: true`, with typed `processes` and `reapedProcesses` arrays. It then proves the exact registered runner PID is gone and both project and shared session state are absent. Only after those assertions pass does it write `IOS-FORCE-RECLAIMED.json`, whose fields truthfully record `resourcesReclaimed: true`, `physicalDeviceDeleted: false`, and `finalCleanupRequired: true` for the exact owned UDID.

The isolated opt-in is consistently renamed `--allow-force-reclaim-owned-ios` in parser validation, invocation documentation, phase table, and both manifest copies. The old recreation/destruction marker and state labels are absent from the active helper and documentation. Durable and mirrored helper, lifecycle README, and manifest copies are byte-identical.

Phase 07 now claims only runner/session/Grantiva-resource reclaim and retained physical simulator state. Phase 08 is explicitly responsible for targeted shutdown and deletion of the owned iOS simulator and proof that its UDID is absent, alongside the existing Android/residual-state cleanup and protected-inventory checks. This preserves the force acceptance criterion while assigning physical deletion to the controller phase that performs and verifies it.

This was a bounded static re-review. No device action, product edit, or test rerun was performed.
