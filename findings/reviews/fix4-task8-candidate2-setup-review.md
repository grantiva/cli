# Task 8 candidate 2 setup controller review

## Verdicts

- **Specification compliance: APPROVED.** The docs/output and provisioning controllers implement the bounded post-freeze setup requested, with the expected candidate, scratch, ownership, device, app, help, doctor, and corpus-test bindings.
- **Code quality and operational safety: APPROVED.** Commands are targeted, evidence is recorded before assertions can advance the workflow, and owned resources are persisted soon enough for later cleanup. No concrete command/schema error or unsafe broad mutation was found.

This was a read-only review of `candidate2_docs.py` and `candidate2_provision.py`. Neither controller, any test, any device command, nor any provisioning action was run.

## Docs/output controller

- The frozen candidate binary is hash-checked before use. API and platform overrides are removed, and session `fix4-8` plus the prepared runner home are explicit for every command.
- Help generation performs a breadth-first traversal from the root, recognizes only exact two-space lowercase/hyphenated subcommand entries under `SUBCOMMANDS:`, prevents repeated path keys and excessive depth, and requires exactly 172 pages plus the expected representative files before publication to `findings/help`.
- Public compatibility terms are read from the frozen candidate source checkout. The prepared ambiguous fixture currently contains exactly `App.xcodeproj` and `settings.gradle.kts` and no `grantiva*` configuration; both text and JSON doctor runs must report the same advisory warning. Normal doctor text/JSON ownership agreement is also asserted.
- The 16 corpus tests use the exact reviewed build scratch path from candidate creation, `/private/tmp/grantiva-round4-candidate2-ciz5f2kj/swift-build-scratch`, while their runtime uses the separate newly created empty `corpus-test-home`. The controller requires the exact zero-failure summary and that the runtime home remains empty.
- Output mutation is limited to the new evidence directory and the intended regenerated `findings/help` pages. It performs no device work.

## Provisioning controller

- Before creation, the controller captures the full simulator, AVD, connected-Android, and forward inventories; rejects an existing `smoke4-ios`, `smoke4-android`, or `emulator-5580`; and records the protected owner AVD config hash.
- It creates only `smoke4-ios` on iOS 26.0 and `smoke4-android` on Android API 35, launching the latter only on serial/port 5580. There is no delete, erase, shutdown, kill, remove-all, or mutation of a pre-existing device.
- iOS ownership is saved immediately after successful creation and before boot/install. Android ownership is saved immediately after successful AVD creation, then updated with the exact emulator PID immediately after launch. The resulting records match the approved ownership schema: literal `fix4-8`, platform, ID, name, runtime, ownership flag, creation epoch, provision command/exit, Android AVD, and owned PID list.
- iOS installation uses the candidate manifest's app path. The installed app container is enumerated and must exactly equal the frozen file/hash manifest. Android identity is checked through the fixed serial and exact AVD name after boot completion; APK installation remains owned by the later reviewed Android smoke helper rather than being duplicated here.
- The three intended iOS project configs are written only inside prepared scratch projects and bind the candidate bundle ID to the newly created simulator UDID. Existing Android project configs are left intact.
- Failure after either successful creation still leaves that resource in the already written ownership evidence; failure after emulator launch leaves its exact PID recorded. This gives the later targeted cleanup controller the identities it needs without broad discovery or destructive fallback.

Approval is limited to running these controllers after the reviewed release controller has successfully frozen `candidate.json`, as required by their input contract.
