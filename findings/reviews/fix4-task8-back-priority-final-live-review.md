# Task 8 L85 source-live and final cleanup review

## Verdict

**Source-live specification verdict: APPROVED.** The exact reviewed source build passes the focused L85 acceptance on iOS 26 and iOS 27. The successful iOS 26 retry used the original helper timing and completed every preserved selector control, the real back/tab collision, independent root confirmation, screenshot, coordinate control, and scoped runner cleanup.

**Evidence-quality verdict: APPROVED.** The raw requests, replies, provenance, independent artifacts, helper-generated acceptance records, and cleanup records agree. The first iOS 26 timeout remains preserved and classified as an unreproduced, unresolved WDA hierarchy-snapshot failure. Neither the later bounded replay nor the successful full retry proves that event transient.

**Merge-readiness verdict: APPROVED for the narrow source fix.** Source HEAD `6cad3f2b4081f0862cd0e93140eda11c2816b9ba` was previously independently reviewed, its frozen release binary is SHA-256 `f9b8161b00049b71b5ffb84176dad97232d89640e24182132e88daffb7c63c78`, and required CI run `38467031047` is reported passing. The two-runtime focused live acceptance and physical cleanup are complete. This approval does not promote the source build into a final candidate: after merge, candidate 3 must be rebuilt and frozen from the merged commit and pass the complete Task 8 smoke/full campaign gate required by L85.

## Source-live evidence

Both runs bind the same clean source HEAD and release-build proof, the unchanged runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2` with runner hash `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`, and demo source `84af7581b75134b0e417b254e4317d565f7b73c6`. Their provenance explicitly retains `finalMergedCandidate: false` and `task8Passed: false`.

The iOS 26 retry and original iOS 27 run each contain 22 valid MCP replies and exit zero. Their raw request order covers:

- exact missing-steps, wrong-type and empty-step L65 controls plus the unknown-selector error;
- cold unselected and selected `heart` identifier behavior;
- placeholder `Name`, ordinary-label `Cancel`, quoted `Mount "Denali"`, and preserved navigation state across tab switches;
- the category collision containing the application root, real `Landmarks` BackButton, and same-labelled selected tab;
- semantic `Landmarks` returning a hierarchy containing Golden Gate Bridge;
- a fresh independent hierarchy, exact-device screenshot, and point-coordinate control.

The accepted iOS 26 screenshot visibly shows the Landmarks root with Golden Gate Bridge after the semantic back action, and its independent hierarchy contains the same root content. The helper records `semanticBackWins: true` on both runtimes. The iOS 26 retry cleaned runner PID 56999 and its fresh project session; the iOS 27 run cleaned PID 54136 and its session, with no primary or cleanup errors.

## Earlier iOS 26 failure

The first full iOS 26 attempt remains a real failed observation: its ordinary-label Cancel click was accepted, then the post-tap hierarchy request stalled. The bounded replay subsequently showed dismissal and two healthy source reads, but its screenshot inserted additional settling time. The full retry is stronger acceptance evidence because it restored the original helper sequence and timing and then reached and passed L85. Even so, one later pass provides no recurrence rate and cannot prove the earlier WDA failure transient, fixed, or impossible.

The appropriate record is therefore: focused source-live acceptance passes on both required runtimes; the isolated earlier iOS 26 WDA snapshot timeout is unreproduced and unresolved; candidate 3's complete post-merge smoke remains the required reliability and integration gate. Repeating source-live until a preferred result would weaken the evidence, so no further source-build retry is justified here.

## Final physical cleanup

The final cleanup began with only the two manifest-owned fixtures in scope: iOS 26 UUID `DE2663B5-C24E-42DA-998D-20F7A80054B3` and iOS 27 UUID `B1CC9AC8-4E49-45C1-BD94-EECD27C40AC1`, both booted. Exact shutdown and delete commands exited zero. The after inventory contains neither UUID.

The process capture contains none of the four recorded owned runner PIDs: 52770 from the first iOS 26 attempt, 54136 from iOS 27, 56512 from the bounded replay, or 56999 from the iOS 26 full retry. All four exact project sessions are recorded absent. Protected baseline simulators `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C` and `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6` remain booted with the same runtime and name before and after cleanup. The final cleanup acceptance is therefore supported by its raw inventory and command records.

`resource-checks.json` additionally records the scoped runner-home session registry as exactly `[]` and the protected Pixel configuration at unchanged SHA-256 `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`. The final live report agrees with the raw evidence and preserves the no-regrade classification: it does not call the first timeout transient, and it explicitly reserves complete qualification for candidate 3's fresh post-merge full smoke.

## Scope

This was a read-only review of retained source-live, diagnostic, provenance, CI-status, and cleanup evidence against the L85 brief and approved helper contract. I did not execute tests, builds, device commands, or modify product source.
