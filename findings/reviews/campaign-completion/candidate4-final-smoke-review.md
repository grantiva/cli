# Candidate4 final smoke evidence review

Status: APPROVED — final Task3 candidate4 smoke evidence and physical cleanup. Completed phases, recorder correction/resume, force teardown and final postflight are accepted in this bounded review. No remaining material Task3 gate gap found. Full fresh campaign coverage remains a separate later gate.

This review reads retained evidence only. No test/build/device/network commands or reruns were performed. Prior candidate4-build-review.md, recorder diagnosis and scoped recorder-fix review remain applicable; no historical harness audit was reopened.

## Binding

Candidate manifest SHA-256 is `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`. Independently compared invocation argv to argv-bound.json for candidate identity, Android runner, lifecycle resume, joint forward, iOS MCP and docs; compared recorded helper, candidate and ownership hashes with their referenced files. The later Android MCP argv and candidate binding also agree. All these completed controller invocations exit0 without timeout, except the separately preserved original lifecycle attempt, which remains exit1. Build/artifact provenance was already independently approved and is not relabeled as new smoke execution.

## Completed phase evidence

- Candidate identity: completed bound helper invocation exit0; frozen manifest/artifact chain is the previously reviewed candidate4 chain.
- Android runner: acceptance includes healthy launch, five intentional crash detections with matching launch PIDs and bounded fatal-to-decision intervals, four gesture forms/routing, five favorite runs, stop/clear-state, optional-versus-required misses, and subdirectory cycle. Retained reports corroborate healthy/favorite/optional/stop success and all five crash/required controls failing as intended. Expected negative exits are part of the assertions, not ignored failures.
- Lifecycle: original 03-lifecycle checks.partial.json retains the two completed startup-interrupt checks, both exit130. Its original recorder failure/exit1 remains unchanged. The reviewed correction's adjacent invocation selects only detach-ready, absent-app, log-cleanup and cycle-controls and exits0. Both detached starts and repeated starting calls exit0 with consistent PIDs; ready structures, immediate hierarchy captures and normal stops are present for iOS and Android. Both retained launch reports are complete passed reports with total1/passed1 and no failed/skipped/running/pending flows. Terminal snapshots explicitly record legitimate source absence and retained generated flows. Ready-interrupt controls exit130; missing-app diagnostics/restoration, log child cleanup for success/failure/interruption, and three prompt cycle refusals are recorded. This aggregate combines completed clauses across immutable attempts; it does not regrade the original failed invocation.
- Joint forwards: all four cases complete: interruption130, normal stop0, absent-app1 and healthy-stock0. Raw immediate/after-one-second forward inventories retain both control mappings while owned runner mappings disappear. Separate acceptance binds PID/session absence checks. Final helper control cleanup produces an empty forwards list. Controls are deliberately created test resources, not unexplained external mappings.
- iOS MCP: no-session, active and retry subprocesses exit0. Raw newline JSON parses into unique response IDs (2, 67 and 2 respectively); active output includes ten notifications and complete large responses. Acceptance covers active/no-session precedence, wrong-type/empty inputs, selector behavior and failures, large/small transport pairs and retry behavior. Root's exact-project stop exits0 for PID51419/status:stopped.
- Android MCP (completed during this review): no-session and active subprocesses exit0. Raw output has 2 and 49 unique response IDs respectively and ten active notifications, with large responses retained. Its phase acceptance and exact-project session stop both complete successfully. It does not inherit iOS-only retry/selector claims.
- Docs/output: retained invocation and release corpus command exit0. Raw corpus output confirms 16 tests/zero failures; acceptance records 172 help pages, empty fresh unit home, doctor text/JSON agreement, migration-note inspection and ambiguous-platform advisory controls.

## Final gate disposition

Foreground force and physical cleanup are now reviewed below. Their later completion closes the initially pending parts of this report. Final Task3 smoke is approved for the exact candidate manifest; this does not assert complete campaign coverage or revise candidate3's historical failures.

Acceptance-file bindings for this partial review:

- `02-runner-android/helper/acceptance.json`: `8e39f50791f2d67ccc48de03ac98f920951a1f081429a6cec4e9bce73b4ff1e3`.
- `03-lifecycle-recorder-fix1/helper/acceptance.json`: `938a4b48c2ae06c87c8b6a971b651c3d0055551f138f21055390c30d27c83f2a`.
- `03b-joint-forward/helper/acceptance.json`: `b162cac5410d7a0f28d7b608cfcb50d572ca711d4f32eb5d59632c2382764b26`.
- `04-mcp-ios/helper/acceptance.json`: `16547ae83ef5da3a719f9cb3adb6b23f0167e1c0a5982a866b6bbc8466f99789`.
- `05-mcp-android/helper/acceptance.json`: `7e100ef5f04fbd11bfe4161ebd85cebb1490b24f5b9a7665b40c53c29436684c`.
- `06-docs-output/helper/acceptance.json`: `d4cfd567ac0b13146a50bc85f1602fb45deb3ee19ebb08e6fe8e631b07106c0c`.

## Foreground force follow-up

Reviewed 07-final-force-teardown: authenticated ready evidence binds foreground CLI52343, runner52371, exact owned iOS UUID, installed runner argv and its keep-alive lease. The exact-UDID force command exits0. Raw foreground result exits0 and stderr contains the explicit teardown notice; retained report has both launch steps completed successfully. Acceptance and IOS-FORCE-RECLAIMED record PID/session/lease cleanup and device-home reclamation, explicitly physicalDeviceDeleted:false and finalCleanupRequired:true. Accepted as resource reclamation only; final physical retirement and protected-resource postflight are established in the following section. Acceptance SHA-256 `a2b50e0cc096cbd2b1d4e6c85ba5b30c0222a0f8993eaf1a7a50bef483e483cc`.

## Final physical cleanup and postflight

Reviewed 08-final-cleanup's executed script and retained commands. Its preexecution correction does not represent a failed live cleanup attempt. Input ownership/candidate/baseline hashes are bound, and the preserved live Android identity matches recorded PID39152, process group, session, start time, executable and argv. Parent PID is deliberately observed but not treated as stable across controller exit. Serial emulator-5580 independently identifies smoke4-c4-android. No blanket deletion or process signal is present.

Exact iOS UUID shutdown and delete each exit0. Exact serial emulator kill exits0; the final retained targeted PID probe exits1/empty and adb devices is empty before AVD deletion. Explicit-JDK avdmanager delete exits0 and reports the exact AVD deleted. The final AVD list contains only protected Pixel_8_API_35; the final simulator JSON omits the owned UUID. The after-owned-state record has empty sessions, leases and forwards, corroborated by empty raw forwards. Protected before/after structures are equal and compared by the executed script to provision baseline; Pixel config retains its original hash. Acceptance hash bindings still match all seven accepted phase files.

Cleanup acceptance SHA-256: `3f98d2693d3e3d41bf82f72299cff84e40d4bfbb123540e18ef3a8ed945fcbfa`.

Read-only final review hashes independently match the frozen CLI, full bundle, packaged/installed runners and Android APK; local git reads confirm clean CLI, runner and demo worktrees at their manifest commits. Root's retained post-smoke-artifact-check.json additionally records the unchanged full iOS app file set and empty simulator capacity registry. No protected device was queried by this reviewer. These postflight checks close Task3 identity/cleanup; no new tests, builds or live device operations were performed during review.
