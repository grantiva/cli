# Task 9 source-window controller preparation report

Status: **PREPARATION ONLY; NOT EXECUTED.** Task 9 remains gated. No source test, build, `go list`, live/device/network command, source edit, candidate substitution, repack, install, or promotion occurred.

## Prepared artifacts

- `task9_source_window.py` is an SDD-only serial evidence collector pinned to reviewed inventory SHA-256 `15437fda241ded594234cb4c59c0378eb50a595222945a6bc13d8d006894fc5b` and frozen source heads CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, runner `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, and demo `84af7581b75134b0e417b254e4317d565f7b73c6`.
- `task9_source_window_fixtures.py` exercises only temporary fake files and bounded local Python subprocesses. It does not touch any candidate checkout or invoke a source tool.

The helper requires a new `grantiva.task9.candidate.v1`, passing hash-bound Task 8 zero gate, accepted primary provision, and accepted `created-shutdown` transition before it creates an output directory. The candidate must carry `task8CandidateManifestSHA256` equal to the independently reviewed candidate-3 manifest. Gate reviews, cleanup, ownership, provision, and shutdown records are rehashed before use. Every source checkout must have its exact frozen HEAD, empty porcelain status, and stable tracked-tree hash.

## Execution boundary

The command inventory is data, but its byte hash is pinned; changing argv or row mappings closes the helper. Every selected command receives an explicit argv vector, bounded timeout, process-group termination on timeout, complete binary stdout/stderr, timestamps, exit, pre/post source proofs, and a command-specific initially absent home or cache. Evidence files use exclusive creation, and the final manifest hashes all metadata and streams. A failed command stops the serial selection. The helper never emits row verdicts: every row remains `satisfiedHere: false` with collected command evidence and pending inspections/live/public/provenance joins listed separately.

Go package resolution is deliberately two-stage:

1. `--phase go-inventory` is the only phase allowed to invoke literal `go list ./...`. It validates complete nonempty lines, uniqueness, and module locality, then writes an unapproved package proposal.
2. A later `--phase execute` invocation may select `go-full` or `go-vet` only with a separate `grantiva.task9.go-packages.v1` artifact. That artifact must be independently approved, hash the earlier inventory result, contain unique module-local literal packages, and contain neither `./...` nor an ellipsis. Those packages replace the visible inventory marker as individual argv elements. Recursive Go test/vet argv are rejected.

The L53 scratch build resolves its output only below the fresh evidence root, never the candidate runner home, and treats the approved follow-up's exit 64 as the required result. No candidate substitution or installation path exists.

AND-111 is deliberately not executable here. Root may join a separate passing `grantiva.task9.and111.v1` record only when it hashes the same candidate and shutdown transition. That root-owned operation must copy the frozen Android demo, change only `emulator` in `android/grantiva-android.yml` from protected `Pixel_8_API_35` to literal `cov4-android`, invoke the frozen CLI with literal `build build`, and retain its no-boot/no-install/shutdown proofs. This helper performs no shutdown, restart, device inventory, or other device action.

## Fixture verification

`python3 -m py_compile task9_source_window.py task9_source_window_fixtures.py` passed.

`python3 task9_source_window_fixtures.py` passed 6 tests. The fixtures verify full stdout/stderr retention, bounded timeout with partial output, refusal before an overwrite command can start, unique module-local inventory parsing, independent package-review/hash binding, rejection of recursive package argv, exact literal expansion, external AND-111 status, and evidence-file hashing.

Independent static review is still required before this SDD helper can be copied or invoked. The Task 8 zero gate, final Task 9 candidate/gate instances, primary shutdown-transition record, reviewed Go package artifact, source inspections, public command evidence, AND-111 evidence, and all later live/provenance joins remain root-owned future inputs.
