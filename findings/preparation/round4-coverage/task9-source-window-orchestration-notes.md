# Task 9 source-window orchestration notes

Status: **PREPARATION ONLY.** These notes do not open Task 9, authorize execution, create a candidate/result, alter the approved 20-command/51-row inventory, or change device ownership. They describe the controller work needed after a future reviewed Task 8 zero gate.

## Entry gate and immutable inputs

The controller must complete these steps before any Task 9 command:

1. Freeze a `grantiva.task9.candidate.v1` manifest that carries the approved CLI, runner, demo, binary, bundle, runner-home, iOS-app, and APK identities. Record its SHA-256.
2. Create the reviewed `grantiva.task8.zero-gate.v1` record bound to that exact manifest hash. Its hash-bound review and passing cleanup artifacts must already exist.
3. Recheck the approved source-window inventory binding: candidate manifest `e9cfc7dc…`, CLI `6ba12ed…`, runner `ba9008f…`, and demo `84af7581…` must either be exactly the frozen Task 9 identities or the source window must remain closed. The approved inventory must not be silently rebound.
4. Allocate one new absent window root. Record its realpath and absence before creation. Predeclare distinct Swift homes for all 11 Swift commands, distinct Go caches for focused/full/vet/build work, the L53 scratch runner destination, raw-stream roots, and inspection roots.

The window begins only after the primary provision and the Android shutdown transition below have passed independent review. General slice dispatch remains closed until the completed source-window manifest is independently reviewed.

## Primary provision and the AND-111 shutdown precondition

Run the approved `task9_primary_provision.py` once with the exact candidate, zero-gate, and an absent evidence output. It creates and boots both primary simulators and boots `cov4-android` as `emulator-5584`, installs the frozen artifacts, verifies protected targets, and writes `grantiva.task9.primary-provision.v1` plus `grantiva.task9.primary-ownership.v1` evidence.

`AND-111` requires that the literal `cov4-android` AVD exist but be shut down. Provision acceptance therefore cannot feed the row directly. After provision acceptance, while general slice dispatch is still closed, the controller must use its existing allocation ownership to perform one exact targeted shutdown transition:

1. Revalidate the ownership record, candidate hash, serial `emulator-5584`, live AVD name `cov4-android`, exact recorded emulator PID, and PID argv (`-avd cov4-android -port 5584`). Refuse the transition on any mismatch or PID reuse.
2. Capture pre-shutdown AVD inventory, `adb devices -l`, complete forward inventory, exact PID/argv, protected simulator records, and protected `Pixel_8_API_35` config hash.
3. Send the exact serial-scoped emulator shutdown command to `emulator-5584`; do not use a global teardown, pattern kill, another serial, or the protected AVD. Wait boundedly for that serial and the authenticated owned PID to disappear. A timeout is durable non-pass evidence and does not authorize broader cleanup.
4. Capture the same inventories afterward. Require `cov4-android` still exists in the AVD list, `emulator-5584` is absent from `adb devices -l`, its owned PID is absent, the forward table has no unexpected delta, protected records/hashes are unchanged, and the two allocated iOS simulators are untouched.
5. Write a reviewed shutdown-transition artifact bound to the primary ownership SHA-256 and candidate SHA-256. Its returned state is `created-shutdown`, not deleted or released. The controller retains ownership for later Android dispatch and campaign cleanup.

This is already within the controller's approved allocation/reservation role and the source-window ruling's explicit shutdown-AVD precondition. It requires no provision-helper change and grants no new slice or global-device authority. The shutdown occurs before the source window; no source-window command may boot, stop, or delete the AVD.

## Source-window command sequence

Use one serial controller. A failure records the first non-pass and closes the affected execution path; it does not authorize an in-place fix or overwrite.

1. **Window preflight.** Validate candidate and gate hashes, primary provision acceptance, shutdown-transition acceptance, protected inventories, exact repo realpaths/HEADs/empty status, toolchain paths, unset API key, and the absence of every declared home/cache/output. Snapshot relevant frozen source/input tree hashes.
2. **Frozen inspections.** Capture the no-command inspection obligations first: L70.1–.3, L74.1/.2, L85.4's demo-source half, inherited source criteria, and provenance joins. Record exact repository/head/path and file hashes. These records do not populate joined live verdicts.
3. **Swift focused commands.** Run the ten approved focused command IDs in inventory order, each with its own initially absent `GRANTIVA_RUNNER_HOME` and `MAESTRO_RUNNER_HOME` and `GRANTIVA_API_KEY` unset. Capture preflight, argv/environment/cwd/times, raw streams, exit, per-target/test counts, and postflight home contents plus unchanged HEAD/status/tree hash.
4. **Swift full command.** Run `swift-full` from a separate empty home pair. Retain per-target and aggregate counts. It supports only literal full-suite clauses.
5. **Go package freeze.** Run `go-inventory` once. Store ordered raw output and a reviewed resolved-package artifact. Reject empty output, duplicates, paths outside the frozen module, or source drift. Expand the reviewed lines as separate literal argv entries; retain no `./...` marker in subsequent test/vet argv.
6. **Go focused commands.** Run `go-l53`, `go-l83`, `go-pc9`, and `go-pc10-13`, with `-count=1` and their approved explicit packages/tests. Each gets its declared fresh cache evidence.
7. **Go full and vet.** Run `go-full` and then `go-vet` with the frozen literal package vector and separate new caches. Preserve package-level output/exits and aggregate exit.
8. **L53 scratch build/control.** Run `go-l53-scratch-build` into the new window path, hash the output and bind it to the frozen runner HEAD, then run only its approved empty-device invocation. Require exit 64 and pre-discovery diagnostic. Separately retain the frozen installed-runner/public control required by the row. Never copy the scratch binary into the frozen runner home.
9. **Public and scratch CLI evidence.** Capture the approved separate public clauses for L53, L67, L75, and L81 using isolated scratch inputs and the frozen executable. Keep them mapped to their existing keys; source tests alone do not satisfy these clauses.
10. **AND-111 last.** Make a scratch copy of the frozen demo Android input, hash the source and copy, and write only the row input config naming literal `emulator: cov4-android`. Reprove the AVD exists and is shut down and capture byte-preserving `adb devices -l`, AVD identity/state, forward inventory, and protected hashes. Run the frozen CLI `build build` with the frozen runner home and API key unset. Capture compilation outputs/artifacts. Recheck byte-equivalent adb inventory, unchanged shutdown state, no installed/launched app or new serial, unchanged forwards/protected state, and unchanged candidate/repositories.
11. **Window close.** Capture final repo HEAD/status/tree hashes and all home/cache inventories. Hash every command metadata file and raw stream. Freeze `source-window-manifest.json`, then obtain independent review before any slice consumes it.

## Evidence joins and later slice handoff

The source-window manifest maps each of the 51 approved rows to its supporting command/inspection artifacts and explicitly lists every outstanding live, public, provenance, or closeout clause. Evidence goes to the fixed effective-key owner: CLI receives its source/provenance rows, iOS later joins PC.5 and other platform halves, and Android owns `AND-111`. No result key or denominator changes.

After approval, the ordinary no-build/no-test slice rule resumes. The primary Android allocation may then be booted only under the later explicit Android reservation; the shutdown proof remains immutable AND-111 evidence. Six iOS-actor CLI keys retain their existing handoff route, and L85.5 remains pending until campaign closeout.

## Orchestration artifacts still missing

The approved documents define policy but do not yet provide these concrete controller artifacts. Each needs implementation plus independent static review before execution:

- **Task 9 candidate instance and zero-gate instance.** Their schema names and required relationships are described, but no final hash-bound files/paths exist while Task 8 remains open.
- **Source-window runner/manifest schema.** There is no reviewed controller that enforces the 20-command sequence, fresh-home allocation, source drift closure, first-output immutability, raw-stream hashing, and 51-row mapping. `source-window-manifest.json` is named but its required JSON fields/schema and validation rules are not defined.
- **Primary-to-shutdown transition schema.** A concrete record must bind candidate, provision acceptance, ownership hash, exact serial/AVD/PID/argv, permitted targeted shutdown, before/after inventories, timeout behavior, returned state, and protected-state comparison. The primary helper intentionally does not perform this transition.
- **Go inventory freeze artifact.** The inventory contains a non-executable package placeholder. A reviewed JSON form is needed for ordered raw lines, module-root validation, duplicate/outside-module checks, final literal argv vectors, and reviewer approval before full test/vet.
- **Per-command evidence schema.** Exact fields are specified in prose, but no common reviewed schema currently enforces realpath/HEAD/status/tree hash, environment allowlist, start/end/exit/timeout, raw-stream hashes, fresh-home/cache before/after, and unchanged postflight.
- **AND-111 scratch-input manifest.** The exact demo subdirectory/copy exclusions, generated config path/content, tree-hash method, build-artifact inventory, and no-install/no-boot checks need a frozen reviewed recipe. The command inventory's placeholder cwd is insufficient for execution.
- **Inspection and join manifests.** L70/L74/L85 and inherited inspection records need a consistent frozen-path/hash schema. The 51-row mapping also needs explicit `satisfiedHere` versus `pendingClause` fields so source evidence cannot prematurely grade a live/provenance/closeout row.
- **Handoff/review record.** A reviewed artifact must bind the final source-window manifest hash to the three fixed result destinations without writing verdicts on behalf of a slice or duplicating the six CLI handoffs.

None of these gaps changes the approved inventory or requires a new product/helper feature. They are controller evidence and validation work needed to make the future authorized window concrete and reviewable.

This note was produced by static inspection only. No test, build, source command, device command, candidate, gate, reservation, result, or live evidence was created.
