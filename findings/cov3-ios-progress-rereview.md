# Scoped rereview — corrected iOS provenance and N3-04 evidence

Scope: rereview only of the findings in `cov3-ios-progress-review.md`: provenance eligibility, historical-import disclosure, overwritten captures, counts, duplicate IDs, and N3-04's changed inputs. No broader iOS verdict review and no device commands.

## Disposition

**ADDRESSED for interim evidence use, with one explicitly retained provenance limitation.** No new breakage was found in the corrected areas.

## Verification

### Provenance eligibility and overwrite history — addressed

`PROVENANCE.md` now enumerates `B3-L15.2` and `MCP-031` among the post-recovery focused groups and separately describes attempts 2 through 9 where applicable. The active ledger no longer relies on the stale “ten groups” statement.

The overwrite incident is now explicit: it names `B3-L13/stop.out`, `B3-L43/start.out`, `B3-L43/session.out`, and `N3-07/dump.out`, explains that `commands.txt` was appended while stable output filenames were replaced, and states that uncommitted intermediate bytes are unrecoverable.

The archive at `findings/evidence/cov3-ios-prior-commit-9542e3d4/` is valid. All four entries pass its `SHA256SUMS`, and each archive hash exactly matches `git show 9542e3d4:findings/evidence/cov3-ios/<path>`. The README accurately limits the claim to the prior tracked checkpoint bytes rather than claiming a complete rerun history.

### Historical-import exclusion — honestly bounded

`pre-import-top-level-inventory.txt` contains the 20 recovered top-level groups and prominently labels itself a reconstructed stable record from the Task 4 agent transcript, not a contemporaneous raw capture. `PROVENANCE.md` repeats that qualification, retains the controller post-import identical/different manifests, and explicitly excludes known later additions under `STEP1`.

This does not create a contemporaneous file-by-file snapshot inside every pre-existing group; that historical limitation cannot be repaired after the fact. It is now disclosed rather than overstated, and the active eligibility rule is reviewable at the top-level-group and named-exclusion level. That is sufficient for interim use, while final reporting should retain the limitation.

### Counts and ID integrity — addressed

The current table parses to:

- 131 matrix base rows: 122 pass, 4 fail, 5 blocked;
- 39 `@27.0` repeat passes;
- 5 handed CLI passes;
- 175 total displayed rows.

These figures match the “Honest current counts” section. The earlier 40-repeat and 107-base figures are gone. No duplicate exact IDs were introduced in the corrected table.

### N3-04 omitted-scheme gap — addressed under the controller safety ruling

Attempt 6 sends build, run, and test with `simulator: "cov3-ios-26"` and omits `scheme`. That differs from the matrix's literal empty argument object only by the controller-required explicit campaign-owned simulator. The raw transcript proves the relevant fallback behavior:

- build sources `Scheme: Landmarks (UI Testing)` from config and names U1/its UDID;
- run sources the same scheme and names the same simulator/UDID;
- test sources the same scheme, names U1/UDID, and returns the expected no-test-action `isError`;
- attempt 2 separately preserves the explicit `grantiva_sim_boot` name/UDID/runtime response.

The new ledger note accurately distinguishes attempt 2 as explicit-scheme variation and attempt 6 as omitted-scheme evidence with the safety-required simulator override. It does not claim to exercise an unsafe default-device path. N3-04's earlier semantic gap is closed within the binding device-safety constraint.

## Interim conclusion

The previously reported count, eligibility-list, overwrite-disclosure, and N3-04 issues are corrected. The reconstructed pre-import inventory remains non-contemporaneous and top-level rather than a complete original file manifest, but the artifacts now say so plainly and do not claim stronger provenance.
