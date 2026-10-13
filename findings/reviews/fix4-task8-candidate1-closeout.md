# Task 8 candidate 1 closeout review

**Verdict: APPROVED as a failed-candidate closeout.** `findings/round4-smoke.md` accurately closes candidate 1 without claiming final smoke or coverage success. The three product blockers remain explicit, passing subsets are bounded to their evidence, the inaccurate historical force marker is qualified, and final owned-resource cleanup is supported by exact targeted commands and read-only absence verification. No correction is required.

## Failed candidate and blockers

- The frozen candidate remains CLI `fb7af9d1702cd4f294aae48eb5f1ed52dbfe2d88`, binary SHA-256 `9519a249d854f70e9dc6da2703b9db33a01166ee18bdf3b7938efa901083efa8`, runner source `ff68658f73e4b6d9d94897d99ad1a0a270a105b7`, installed/packaged runner SHA-256 `eb289d8a505b22351b88bf2dfb728dd4af74fb7187ce68637d99c809bf55cb07`, and demo `1552ae983a27528eff4c1f8145aa075698b47f71`. The current `candidate.json` byte hash remains `7c6b9634572c982e724849548510805a99168217228e7eb1ab689fdd04d8bc73`.
- L82 is truthfully retained as failed: the isolated ready-state reproduction starts from an empty forward baseline, reaches exit 130, and leaves the exact CLI-owned forward immediately and after one second. The absent-app control is separately described as passing and is not blamed for the inherited leak.
- Reopened L66 is truthfully retained as failed. The original iOS MCP invocation exits 1 on literal `heart` after Landmarks is selected, while the separate continuation proves only L65, ten large transport pairs, and the two-lookup retry contract. The closeout does not call that continuation a full selector pass, and the installed app identity is tied to the frozen five-file manifest.
- L83 is truthfully retained as failed. The controller creates the exact no-rebind control `emulator-5580 tcp:6790 tcp:16790`, inventories it before the run, executes healthy stock with exit 0, and records an empty post-run inventory plus `unrelatedForwardSurvives: false`. This proves deletion of the unrelated local forward and keeps runner repair/repack mandatory.

## Passing and qualified evidence

- The Android runner phase is correctly described through its independently approved split evidence. Earlier setup attempts and the diagnostic monolithic exit are retained rather than regraded.
- Lifecycle attempt 4 has `status: passed` for the scoped log/cycle phases. Success, failure, and interruption retain exits 0/1/130, three marked-child absence snapshots each, truthful report status handling, and one terminal diagnostic. The three cycle controls retain their exact chains, exit 1, and sub-two-second duration.
- Force teardown's raw acceptance does prove `runnerSessionStopped: true`, `reclaimed: true`, typed process arrays, and exact runner/session cleanup. Its historical `IOS-DEVICE-RECREATE-REQUIRED.json` and `ownedDeviceDestroyed` fields are false physical-deletion claims; the closeout explicitly says force reclaimed resources but did not delete the simulator and assigns governing physical cleanup to the later targeted shutdown/delete evidence. This is consistent with the approved helper/documentation correction and does not rewrite the preserved raw artifact.
- Docs/output and the bounded platform MCP/runner subsets are stated as passes only within their retained scope. No full candidate pass is inferred from them.

## Final cleanup and ownership boundary

- Attempt 2 records exact targeted commands: `simctl shutdown` and `simctl delete` for owned UDID `B718468C-771F-47BC-9CD8-A1143D540AC5`, `adb -s emulator-5580 emu kill`, and `avdmanager delete avd --name smoke4-android`, all with exit 0.
- The separate verification records the owned simulator and AVD deleted, the Android serial absent, empty forward inventory, and no owned processes, project/shared sessions, or device locks. Protected simulator identity, type, availability, boot state, paths, and `lastUsedAt` remain unchanged; the protected AVD configuration hash is retained.
- The protected-inventory qualification is accurate: the initial strict dictionary comparison differed only in live `dataPathSize`/`logPathSize` growth. Those dynamic size fields are excluded explicitly while all stable identity/state fields remain exact, with raw before/after captures retained.
- The later `fix4-tab-26` simulator belongs to the separate demo-repair work. It is outside candidate 1 ownership and is neither claimed as candidate 1's device nor included in candidate 1 cleanup conclusions.

Candidate 1 therefore remains failed and cannot authorize Task 9 execution. The approved source/helper fixes are follow-up work requiring a rebuilt clean candidate and fresh acceptance; they do not alter this closeout verdict.

This was an independent bounded evidence review. No device command, source edit, test, or smoke rerun was performed.
