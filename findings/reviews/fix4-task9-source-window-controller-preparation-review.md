# Task 9 source-window controller preparation review

**Specification compliance: CHANGES REQUIRED.**

**Code quality and execution safety: CHANGES REQUIRED.**

Static review only. Task 9 remains gated; this review does not authorize copying or executing the controller. No test, build, Go inventory, device, network, or prepared-helper execution was performed. The author's six fixture passes are reported evidence, not independently rerun evidence.

Reviewed helper SHA-256: `4970248a56705f06be0114418d58c4cec5b174194c5a6a9547744c9812202ed0`.
Reviewed preparation diff SHA-256: `30a46eb89c3567293b71c903b8185c9e77792d1a34aa4a77e293c4b31ecb0236`.

## Findings

### P1 — Go package approval is not connected to the actual successful inventory

`task9_source_window.py:152–171` hashes the supplied inventory-result file but never reads its result, checks its exit/timeout, validates its stdout hash, or binds its source/candidate proof. It hashes a separate proposal and compares its packages, but never checks the proposal's `inventoryStdoutSHA256` against that inventory's raw stdout. Thus an unrelated or failed inventory result plus a separately assembled proposal is accepted. The fixture at `task9_source_window_fixtures.py:test_reviewed_packages_require_hash_review_and_literal_module_paths` explicitly uses `{}` as the accepted inventory result and a proposal with no stdout binding.

The required sequence is fresh inventory, independent review of those exact ordered lines, then literal execution. Validate the inventory's successful result and raw stdout, reparse those bytes, require proposal/package equality to those exact lines, and bind the inventory command's candidate and frozen runner proof to this execution. Retain those input artifact hashes in the execution manifest. Extend the fake fixtures with mismatched raw output, failed result, and candidate/source mismatch cases.

### P1 — output paths are neither normalized nor excluded from frozen inputs

`task9_source_window.py:239–248,262–278` leaves `args.output` relative. With `--output evidence/window`, Python creates evidence relative to the controller's cwd, while the spawned command runs in the frozen repository and resolves the same relative home/cache/build strings there. Go requires an absolute GOCACHE; Swift and the L53 output can instead write under the source checkout. The helper's later home inventory then inspects a different location from the subprocess. This is an ordinary accepted CLI argument, not a hypothetical malformed schema.

Even with an absolute path, there is no preflight exclusion for a new output descendant of a frozen checkout or the candidate runner home. An absent directory beneath an ignored source build directory can pass the current clean-status/tracked-tree proof and still direct scratch output into frozen inputs.

Resolve the output root once before checking absence and constructing any paths. Reject roots within frozen source repositories and frozen candidate artifact/home locations before creating it. Derive all homes, caches, and scratch executables from that checked absolute root. Fake path-validation tests can cover these cases without executing source tools.

### P1 — Swift home contamination does not stop the window

`task9_source_window.py:292–303` records only files under fresh paths and sets `postflight.passed` solely from command exits. A Swift command that exits zero after populating a runner home is reported passed and the next command starts. Empty subdirectories and some non-file entries are not even represented. The source-window preparation explicitly requires proof that both Swift homes remain empty afterward.

Record complete entry inventories and require the Swift home pair to remain absent/empty. Persist a failing postflight and stop the selection on violation. Go cache population is expected and should remain a separate condition. Add a fake successful subprocess that creates a home entry to prove the controller closes correctly.

### P2 — existing gate review references are incorrectly forced to be JSON

`task9_source_window.py:52–59,106` uses `checked_ref` for the gate review; it always calls `load`, which requires a JSON object. The approved `findings/tools/round4-coverage/task9_primary_provision.py:45–49` treats `review` as an opaque hash-bound file and parses only cleanup as passing JSON. Neither the governing notes nor that accepted helper requires the review itself to be JSON. A valid gate referencing a Markdown static review therefore passes provisioning but cannot open this controller.

Separate byte-hash reference validation from optional JSON/schema parsing. Preserve the existing opaque gate-review contract; continue requiring passing JSON for cleanup. Verify compatibility with a fake Markdown review reference instead of creating a new gate schema requirement.

### P2 — shutdown ownership is not tied back to the approved provision

`task9_source_window.py:109–124` checks the provision candidate and the shutdown's provision hash, but the shutdown's ownership file is only checked against its own declared hash. Its contents are never read. The accepted provision helper writes the actual ownership object inline in `acceptance.json` (`findings/tools/round4-coverage/task9_primary_provision.py:135`), so the consumer already has an authoritative object to compare. Currently an unrelated ownership file can satisfy this check. The provision's existing `gateEvidenceSHA256` is also not compared with the supplied gate.

Check that the referenced ownership JSON matches the provision's inline ownership and has the same candidate and expected Android allocation (`cov4-android`, `emulator-5584`, recorded PID/launch identity). Check the provision's existing gate hash against the supplied gate. This is consumption of the approved helper's actual shape, not a request to change that helper or add device operations here.

### P2 — source drift aborts before durable postflight evidence

`task9_source_window.py:66–84,290–295` raises from `repo_proof` as soon as HEAD/status is wrong, before saving the observed postflight. A changed tracked-tree hash similarly raises before `postflight.json`. Raw command output survives, but the changed HEAD/status/hash and terminal closure reason do not, and no terminal manifest is written. This omits exactly the failure evidence the preparation requires and makes a source-drift closure harder to distinguish from an interrupted collector.

Capture observations separately from their acceptance predicates, save the observed postflight and first failure reason with exclusive creation, then stop. Do not repair, rerun, or overwrite the failed evidence. A mocked repository-proof fixture is sufficient to exercise this path.

## Controls that are correctly bounded

- The approved inventory bytes are pinned, including the 20 command specifications and 51 row mappings. Fixed argv vectors use no shell; full Go test/vet requires literal expansion and the ordinary pinned focused Go commands retain `-count=1`.
- CLI/runner/demo source SHAs and candidate lineage are checked. Repository proofs require exact HEAD, clean porcelain and tracked-file hashes before execution, and compare proofs afterward.
- Command streams are retained as bytes, timed commands kill their process group, result files use exclusive creation, and ordinary nonzero/timeout command results stop the current serial selection.
- API credentials are removed; distinct Swift home pairs and Go caches are allocated per selected command, subject to the path and postcondition findings above.
- The L53 scratch invocation preserves the approved empty argument and expected exit 64. No install, repack, source-edit, or device-operation command is implemented.
- AND-111 cannot execute through this controller; its optional external join requires candidate/shutdown hash binding. All rows retain `satisfiedHere: false`, missing commands and separate clauses, without fabricated verdicts or owner/key changes.

The existing fake tests cover useful primitives, but do not exercise the actual gate/source/preflight/postflight integration. The failures above follow directly from static control flow; they require no live reproduction. Missing future candidate/gate/shutdown instances, root-owned AND-111 work, public clauses, inspections, and final review remain future controller work rather than reasons to widen this bounded helper.

## Reviewed material

The preparation report and diff, helper and fixtures, source-window preparation, approved inventory JSON/Markdown, orchestration notes, and the approved provision helper and its preparation review were read. Only this review document was added. No product/helper source was changed.
