# Task 9 source-window controller review fix round 1

Status: **PREPARATION ONLY; NOT EXECUTED.** The reviewed inputs remain `task9_source_window.py` SHA-256 `4970248a56705f06be0114418d58c4cec5b174194c5a6a9547744c9812202ed0` and original preparation diff SHA-256 `30a46eb89c3567293b71c903b8185c9e77792d1a34aa4a77e293c4b31ecb0236`. That original diff is preserved unchanged. No source test, build, `go list`, device, live, network, or frozen-source command ran.

## Review findings addressed verbatim

The independent review required these six changes:

1. **P1 — Go package approval is not connected to the actual successful inventory.** The accepted chain now requires a successful non-timeout result, its exact raw stdout hash, a `go-inventory` start record with literal argv, the same candidate hash and frozen runner proof, a proposal bound to those raw bytes/candidate/source, independently approved literal packages equal to reparsing those exact bytes, and retained hashes for every input in the execution manifest. Fixtures reject a failed result, changed raw output, candidate mismatch, and source mismatch.
2. **P1 — output paths are neither normalized nor excluded from frozen inputs.** The output is resolved once to an absolute path before allocation. It must be absent and cannot descend from any frozen CLI, runner, or demo checkout, candidate runner home, or declared binary/bundle/packaged/installed/APK/app artifact. All homes, caches, and scratch paths derive from that checked absolute root.
3. **P1 — Swift home contamination does not stop the window.** Postflight now records every file, directory, symlink, and other descendant. Either Swift home may remain absent or present-and-empty; any entry creates a durable failure reason and stops later selection even when the command exits zero. Go cache entries remain expected evidence.
4. **P2 — existing gate review references are incorrectly forced to be JSON.** Hash validation is separate from JSON parsing. Gate review is opaque hash-bound content and the fake integration uses Markdown. Cleanup remains required passing JSON.
5. **P2 — shutdown ownership is not tied back to the approved provision.** Provision must hash the supplied gate. Shutdown must hash the provision and gate. Its referenced ownership JSON must exactly equal provision's inline ownership and bind the candidate, gate path/hash, owned `cov4-android` / `emulator-5584`, one recorded PID, and matching `-avd cov4-android -port 5584` launch identity. Shutdown's allocation triple must match it.
6. **P2 — source drift aborts before durable postflight evidence.** Repository observation is separate from acceptance. Changed HEAD, dirty status, or tree drift is written to postflight and `terminal-failure.json`; the final manifest becomes `CLOSED_NONPASS_UNREVIEWED` and retains observed final source proofs. The controller neither repairs nor reruns.

The requested findings, verbatim from the review, were:

> **P1 — Go package approval is not connected to the actual successful inventory**
>
> The required sequence is fresh inventory, independent review of those exact ordered lines, then literal execution. Validate the inventory's successful result and raw stdout, reparse those bytes, require proposal/package equality to those exact lines, and bind the inventory command's candidate and frozen runner proof to this execution. Retain those input artifact hashes in the execution manifest. Extend the fake fixtures with mismatched raw output, failed result, and candidate/source mismatch cases.
>
> **P1 — output paths are neither normalized nor excluded from frozen inputs**
>
> Resolve the output root once before checking absence and constructing any paths. Reject roots within frozen source repositories and frozen candidate artifact/home locations before creating it. Derive all homes, caches, and scratch executables from that checked absolute root. Fake path-validation tests can cover these cases without executing source tools.
>
> **P1 — Swift home contamination does not stop the window**
>
> Record complete entry inventories and require the Swift home pair to remain absent/empty. Persist a failing postflight and stop the selection on violation. Go cache population is expected and should remain a separate condition. Add a fake successful subprocess that creates a home entry to prove the controller closes correctly.
>
> **P2 — existing gate review references are incorrectly forced to be JSON**
>
> Separate byte-hash reference validation from optional JSON/schema parsing. Preserve the existing opaque gate-review contract; continue requiring passing JSON for cleanup. Verify compatibility with a fake Markdown review reference instead of creating a new gate schema requirement.
>
> **P2 — shutdown ownership is not tied back to the approved provision**
>
> Check that the referenced ownership JSON matches the provision's inline ownership and has the same candidate and expected Android allocation (`cov4-android`, `emulator-5584`, recorded PID/launch identity). Check the provision's existing `gateEvidenceSHA256` against the supplied gate. This is consumption of the approved helper's actual shape, not a request to change that helper or add device operations here.
>
> **P2 — source drift aborts before durable postflight evidence**
>
> Capture observations separately from their acceptance predicates, save the observed postflight and first failure reason with exclusive creation, then stop. Do not repair, rerun, or overwrite the failed evidence. A mocked repository-proof fixture is sufficient to exercise this path.

## Verification

Exact allowed command:

```text
python3 -m py_compile .superpowers/sdd/2026-10-13-round4-fix-wave/task9_source_window.py .superpowers/sdd/2026-10-13-round4-fix-wave/task9_source_window_fixtures.py && python3 .superpowers/sdd/2026-10-13-round4-fix-wave/task9_source_window_fixtures.py
```

Exact output:

```text
...........
----------------------------------------------------------------------
Ran 11 tests in 0.706s

OK
```

These were temporary fake-filesystem/fake-subprocess fixtures only. The full integration fixture ran the actual controller argument, gate, source-proof, command, postflight, closure, and manifest paths with fake `git` and `swift` programs. It verified that a zero-exit command which creates an empty subdirectory under `GRANTIVA_RUNNER_HOME` closes the window and preserves the raw `fake swift success` stream.

Task 9 remains gated. Independent static re-review is required; this implementer did not dispatch it.
