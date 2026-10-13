# Task 9 source-window command inventory review

## Verdict

**Specification verdict: APPROVED as preparation.** The inventory defines 20 bounded command/inspection specifications mapped to 51 Task 9 rows. The named tests exist at the frozen candidate 3 source heads and their assertions cover the source clauses assigned to them. Inspection, public-command, live-device, provenance-join, and campaign-close clauses remain explicitly separate and ungraded.

**Execution-safety verdict: APPROVED with the stated controller gates.** The draft authorizes no command before candidate 3 obtains the Task 8 zero gate. It contains no authentication, release, merge, repack, install, or general device action. The sole product compile and sole scratch runner build are the literal row-scoped exceptions already approved by the source-window ruling.

The `go-full` and `go-vet` entries are intentionally non-executable templates. They must not run until the controller captures and reviews `go list ./...`, freezes its nonempty unique module-local output, and replaces the marker with individual literal package argv elements. A test or vet argv containing `./...` remains prohibited.

## Candidate and command inventory

The draft binds candidate manifest SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`, CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, runner `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, and demo `84af7581b75134b0e417b254e4317d565f7b73c6`. It assigns:

- eleven Swift commands: ten focused filters and one independent full suite;
- eight Go specifications: four focused tests, inventory, full test, vet, and the L53-only scratch build/invocation;
- one `AND-111` compile-only frozen-product command.

All focused Swift test classes and concrete cases listed in the JSON exist in the frozen CLI tree. All listed Go top-level tests exist in the declared explicit packages. The L83 table test contains both `UIAutomator2` and `DeviceLab driver` subtests and verifies exact owned socket/port removal, unrelated-forward survival, and safe repeated cleanup.

## Semantic coverage

- L53's Swift cases cover explicit empty target flags, malformed simulator UDID, and canonical cycle behavior. The runner table covers empty/whitespace `--device`, preserved empty/whitespace `--udid`, unknown `--serial`, exit 64, and validation before discovery. P3 alone receives the authorized scratch runner build; its frozen-installed-runner/public-command half remains separately required.
- L67, L74, L75, and L81 map to the precise doctor-selection, ISO-8601 encoder, cycle/path-rewriter, and ownership-note suites. The inventory correctly leaves public doctor output, live session JSON, and scratch CLI path forms as fresh separate evidence.
- L82 and L84 retain their production foreground/attachment and scoped orphan-cleanup siblings plus the explicitly required full Swift output/provenance joins. Their live Android clauses remain outside the window.
- L83 uses the exact runner cleanup table and reserves full uncached Go test/vet plus merge/repack/smoke provenance for the join row; it authorizes no repack.
- L85 names the back-priority, broad-label fallback, label/identifier/placeholder order, quoting, application exclusion, server-error/retry, coordinate, lifecycle, and MCP no-session tests. Demo inspection and owned-iOS behavior remain separate, while L85.5 stays a closeout provenance join rather than a circular prerequisite.
- PC.5 and PC.9–PC.13 name the completed-launch-report, stop cancellation/postcondition, stable-target cancellation/success, ordinary soft-deadline, keyboard step-context, and long-press budget tests in their actual packages.
- EJ.3 retains canonical-path/alias/stream tests but still requires both B3-L20 platform halves.

No historical pass is assigned as a Task 9 result. Historical evidence is limited to lineage/provenance, and every executable row requires new output from this future window.

## Go package-list gate

`go list ./...` appears only in the inventory operation and is expressly non-test evidence. Focused tests already use explicit package paths and `-count=1`. The full test and vet specifications contain a visible replacement marker rather than a runnable recursive pattern. Before execution the controller must freeze the exact list output and rewrite the actual argv arrays; leaving the marker or substituting `./...` is a blocking preparation failure.

The global environment contract records the API key unset and distinct initially absent caches/homes. Each command also requires exact repo realpath, HEAD, clean status, candidate hash, source/input tree hash, raw streams, exit and postflight drift checks. Failure closes the affected row without an in-place repair or retry.

## Bounded build and device boundary

The L53 scratch build writes only to the new window root and cannot replace the candidate runner. `AND-111` invokes the frozen CLI binary in a scratch copy of the frozen demo Android project; it may compile that scratch app but may not rebuild CLI/runner source or install, boot, launch, stop, or delete a device.

`AND-111` is executable only after the controller creates and records the campaign-mapped literal `cov4-android` AVD through the approved ownership/reservation flow and proves it exists and is shut down. The config must literally name `emulator: cov4-android`; absence is not equivalent to this precondition. Byte-equivalent ADB device inventories and unchanged shut-down AVD identity/state are required before and after the compile.

## Scope

This was a static review of the preparation, JSON/Markdown inventory, frozen test/source names, and governing Task 9 criteria. I did not execute `go list`, a test, a build, a source command, or a device operation, and I did not populate any Task 9 result.
