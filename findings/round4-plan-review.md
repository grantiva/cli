# Round 4 fix-wave plan review

Review target: `docs/superpowers/plans/2026-10-13-round4-fix-wave.md`

Inputs checked: the four retained round-2 briefs (L51, L53, L61, L62), L64–L80, the campaign design, CLI source at the round-3 candidate, and runner source at `fd9d8e8`. This review is static; it did not run devices or implement product changes.

## Verdict

The corrected plan has sound repository ownership, release construction, version selection, APFS-clone upgrade, WDA-cache regeneration, and L53 flag scope. It is not execution-ready until the following load-bearing gaps are fixed. None requires changing the proposed PR partition.

## Required corrections

### 1. L61's bounded collectors can leak permanently blocked goroutines

Task 1's test deliberately implements `Screenshot()` as `select {}` and expects the outer call to return after two seconds. The proposed implementation keeps the existing context-free `core.Driver.Screenshot()` and `Hierarchy()` methods and only adds a context-aware log-tail interface. A timeout around those calls can bound the caller, but it cannot stop either goroutine. Every failed step can therefore retain another blocked goroutine and its captured driver/report state indefinitely.

The production source confirms the mismatch: `captureArtifacts` directly calls the context-free methods, while the UIAutomator2 package already has context-aware request plumbing (`SetRequestContext`, `parentContext`, `sourceCtx`, and `boundedCall`). Task 1 must specify cancellable internal screenshot and hierarchy collection for UIAutomator2, without widening the public cross-driver interface if desired. Its tests must release or cancel blocking fakes and assert collectors terminate, preferably with a repeated-failure goroutine/resource control. Merely returning within 2.25 seconds is insufficient to claim a bounded collector.

### 2. L80 must not impose response ordering by ID

Review Focus item 1 says concurrent responses and notifications “retain ordering by ID rather than by completion.” L80 explicitly requires each response ID exactly once **regardless of completion order**. Sorting or serializing by ID is an extra protocol behavior and could create head-of-line blocking.

Replace that sentence with: complete records remain individually serialized; response IDs are preserved exactly once; completion order is unconstrained; notifications and small-response delivery remain intact. Task 5's concrete set-based assertion already has the right semantics.

### 3. Task 5 omits the binding live acceptance for L65 and most of L66

Task 5 Step 7 only proves two iOS selector examples and large-response transport. The briefs require:

- L65's exact missing-`steps` error through ToolRegistry with a live session on **both platforms**, plus no-session precedence and the wrong-type/empty-array controls.
- L66's full IOS-102, B2-K78, and iOS D2-36 reruns, including label → identifier → placeholder priority, winning-attribute annotation, application-node exclusion, escaping, retry semantics, and the existing binding assertions.

Add these named acceptance runs to Step 7 (and Task 8 smoke where useful). Unit predicate recording alone does not replace the briefs' live/full-row requirements.

### 4. Task 4's bounded acceptance is too compressed to satisfy five lifecycle briefs

Step 9 names broad topics but omits literal acceptance that previously exposed the defects. Expand it to require:

- L68: rerun every AND-127 clause after the immediate app hierarchy, including metadata, tool listing, stop, and forward cleanup.
- L69: N3-03 on iOS and Android using an observed `starting` state and the detached first-start form, with explicit-null `port`, same PID, ready and stopped controls, and no second process.
- L72: startup SIGINT in plain, quiet, and JSON modes; exit 130; no false WDA timeout; B3-L37 notice and cleanup; separate steady-ready, genuine timeout, and unprompted-death controls.
- L73: live-session force teardown plus the genuinely free force no-op and non-force behavior/helper-array controls.
- L78: repeated immediate process inventories after success, failure, and interruption; another live run remains unaffected; exit 130 and the single truthful verbose terminal diagnostic remain intact.

The focused unit tests should mirror these branches. “Startup and ready SIGINT controls” and “force teardown JSON” are not enough to close the briefs.

### 5. Task 3 does not exercise every L79 report surface or the required repetitions

The brief requires three repetitions and agreement across text, JSON, JUnit, and ready/report summaries, while retaining useful `element_not_found` detail and a required-step failure control. Step 1 covers the production report/JUnit model and Step 6 covers text/JSON/quiet once, but neither names three repetitions, ready/report summaries, or preservation of error detail.

Add one explicit end-to-end acceptance step after repack that performs three optional-miss repetitions and checks all named surfaces, the following required step, exit 0, warning detail, and the otherwise-identical nonoptional control.

### 6. L67's named CLI-025 rerun is absent

Task 6 has a good focused doctor test, but L67 requires the complete CLI-025 rerun: text and JSON ambiguity under Advisory, exit 0 despite usable toolchains, selection guidance, and `run` continuing to reject ambiguous platform selection. Add the named rerun to Task 6 acceptance rather than relying only on Task 9's generic matrix execution.

### 7. Two source/test paths need correction before worktree execution

- Task 4 lists `RunnerLifecycleDocument.swift` without a directory, and no file with that name exists in the candidate tree. The lifecycle document implementation must be located from the actual source before assigning the edit; do not create a guessed top-level file.
- Task 5 names `Tests/GrantivaMCPTests/MCPTransportTests.swift`, and Task 6 names `Tests/GrantivaCLITests/DocsContractTests.swift`; neither currently exists. They can validly be new files, but the plan labels them only as “Test,” unlike other explicit `Create` entries. Mark them `Create` and identify the actual transport integration test seam. This prevents an implementer from searching for nonexistent existing fixtures or silently testing a mock below the MCP package's real stdio writer.

`FlowReferenceResolver.swift` is correctly under `Sources/GrantivaCore/Runner/`; the brace-group path in Task 4 resolves there.

## Recommended strengthening

- Task 1's L64 device acceptance should retain the healthy and post-return-crash controls from the brief, not only one generic healthy stock flow.
- Task 4's L71 acceptance should explicitly include the D2-08 `--app-file` build-install leg in addition to absent and installed skipped controls.
- Task 7's WDA regeneration should state how availability is handled when one of the named runtimes is not installed. The plan correctly forbids reuse, but currently treats all four runtimes as unconditionally present.

## Checks that passed

- L51 correctly moves direction, explicit start/end, and element swipes to held W3C actions while preserving `engine: adb` as the sole shell-input escape hatch.
- L53 correctly limits the runner change to its existing `--device` flag and keeps `--serial` unknown; the CLI owns its actual target flags.
- L62 preserves runner/demo ownership isolation and requires 5/5 evidence on software and GPU AVDs.
- L64 preserves permission batching, first-frame behavior, and post-launch crash watch.
- L75 now points to the CLI repository's real resolver/session path and uses the exact project-root-relative cycle.
- The Go version/toolchain match the runner module, and the scoped package commands avoid bare `go test ./...`.
- The bundle task regenerates WDA caches, validates both architectures, and the release smoke exercises an APFS-cloned upgrade home rather than an empty-home substitute.

After the seven required corrections, the plan is suitable to enter Task 0 and test-first implementation.
