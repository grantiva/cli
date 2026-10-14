# Candidate 4 CLI direct ordinals 202–251 review

Verdict: **APPROVED — 50/50 proposed passes are supported.**

I derived this slice from flattened `batches[].rows[]` array position plus one in `cov5-cli/findings/evidence/cov5-cli/direct-row-batches.json`; nested `row.ordinal` is not used. The range starts at B-C03.3 and ends at B-C25.1.

I compared each row with its exact frozen matrix clause, result link, verdict, raw command or protocol output, identity record, and any source-disposition join. Every executed capture is bound to candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783` with matching frozen artifacts. No retained command timed out or reported process-group cleanup failure.

The runtime and protocol rows demonstrate the requested observable boundaries: VRT re-entry uses the running absolute executable despite a hostile PATH stub; both MCP servers initialize and list 22 tools; parser errors retain file, line, command, screen, and value context; record argument and output-extension errors occur before device resolution or recording; missing and empty configs use the corrected platform-specific wording; unknown-key warnings preserve compatibility; doctor uses the run parser diagnostic and reports stale SDK variables as warnings; init explains placeholders and selects an installed device type; logout text and JSON remain successful without credentials.

B-C12.1 uses the corrected evidence join. `CLI-025-rerun-1` is the fresh literal no-config fixture: doctor places dual project detection under Advisory, while run exits 1 naming `--platform ios|android` and `GRANTIVA_PLATFORM`. The B-C12.1 directory separately proves both invalid `GRANTIVA_PLATFORM=windows` cases fail, and both cross-platform init flags fail while their retained file inventories stay empty. Its dual-config doctor probe is preserved and excluded because it is not the literal no-config fixture. All joined commands carry candidate-4 identities.

Rows that reuse adjacent raw do so explicitly and retain the originating identity: B-C14.2 points to B-C14.1's bad-frames command, B-C19.2 points to CLI-155's exact Maestro fixture, and B-C24.2 points to B-C24.1's generated config and init capture. The evidence supports the additional clause in each case rather than transferring an earlier candidate result.

The source-only rows locate the named implementation or regression tests in the exact candidate tree. Their controller-approved source disposition joins them to the current candidate's 2,027-test Swift result and the current unchanged focused runner, full runner, and vet results. The corrected webhook rows follow the frozen expectation correction: unknown event names remain server-validated and `events` is intentionally absent as a subcommand and from the changelog.

Material gaps: **none found**.
