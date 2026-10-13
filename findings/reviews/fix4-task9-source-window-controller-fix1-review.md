# Task 9 source-window controller fix1 re-review

**Specification compliance: CHANGES REQUIRED. Code quality: CHANGES REQUIRED.** Four original findings are resolved; two retain narrow failure cases. No unrelated obligations are added.

Static re-review only; no tests, build, Go inventory, helper execution, network or device operations were performed. Task 9 remains gated. The reported 11 fake fixture passes were inspected, not rerun.

Verified reviewed hashes:

- Helper: `b7b176286a4e9ddcf5041980964e82bf99ef71f955547ed3ecf1906af2e63b06`
- Fixtures: `70eb0a4917d782f76a3ac75aa85ba8b085377da5a0e1b10dfae670f5c27349f1`
- Fix1 diff: `e43b3abc8046a23a0f92bff1190d4c5254404b8109b1ba221eef16bc760d09cb`

## Resolved findings

1. **Go inventory chain.** `package_artifact` now checks successful non-timeout result, exact stdout bytes/hash, the literal inventory start argv, matching candidate and runner proof, proposal binding, and equality of approved packages to freshly parsed raw lines. The execution manifest retains input hashes. The fake checks reject failed results and changed bytes/candidate/source.
2. **Output normalization and confinement.** `resolve_output` resolves the root before allocation, rejects existing output and descendants of frozen source/home/artifact paths, and all derived execution paths use that absolute root.
3. **Opaque gate review compatibility.** `hashed_ref` validates the gate review without JSON parsing. Cleanup remains passing JSON. Markdown review content is represented in the fake gate integration.
4. **Provision/ownership binding.** The supplied gate hash is compared to provision acceptance, referenced ownership must equal provision's inline object, and candidate plus Android AVD/serial/PID/launch identity are checked. I compared these fields to the actual approved `findings/tools/round4-coverage/task9_primary_provision.py`: it writes inline `ownership`, `gateEvidenceSHA256`, ownership `gateEvidence`, and Android `launch.argv`/`launch.pid`/`ownedPIDs` with the consumed shapes. The new shutdown allocation/gate fields belong to the future transition record, not an incompatible change to provision output.

## Remaining findings

### P2 — home root objects can still be mistaken for empty homes

`task9_source_window.py:261–268,301–302` inventories descendants but does not classify the root itself. If a successful fake Swift command writes a regular file at `GRANTIVA_RUNNER_HOME`, `path.exists()` is true and `path.rglob('*')` yields no descendants. The result is `state: present, entries: []`, so postflight accepts it as empty. A dangling symlink at the home path takes the same acceptance path. These are not absent or empty-directory homes, and the introduced descendant-kind enumeration does not detect them.

Record the root kind using a non-following check. Permit only an absent root or a real directory with no entries; persist and close on a file, symlink or other root kind. Keep normal populated Go caches valid. Add small fake cases for file and dangling-symlink home roots alongside the existing empty-subdirectory case. The original home-cleanliness finding is otherwise repaired: nonempty real directories now produce durable failure and stop the selection.

### P2 — deletion of a tracked source file still loses drift postflight

`task9_source_window.py:69–85` captures HEAD/status but still calls `require(path.is_file() ...)` for every tracked entry. Deleting a tracked file is a normal dirty-source case: `git ls-files` still lists it, so this raises before `observe_repo` returns. At `417` the controller consequently never saves postflight, terminal failure, or the closed manifest. The same failure can occur during final observation at `433`. This is the original durable-drift finding, not a new general exception-handling requirement.

Return an observation containing the captured HEAD/status and a structured missing/invalid tracked-file observation rather than throwing away the proof. Treat that observation as a failing proof, persist it through the existing postflight/terminal closure path, and retain the first failure. A fake deleted-tracked-file case should verify the terminal artifacts are actually written; the current proof fixture supplies an already constructed observation and cannot exercise this remaining branch. Changed HEAD/status/content with readable tracked files is now handled correctly.

## Scope and unchanged controls

The fix report, fix diff, changed helper/fixtures, and approved provision output shape were inspected. Pinned command inventory, literal argv, raw streams, timeout handling, exclusive creation, candidate source identities, AND-111 external-only boundary, and all-false row verdict fields remain intact. No additional breakage was found in the scoped changes. Only this review document was added; product and helper code were untouched.
