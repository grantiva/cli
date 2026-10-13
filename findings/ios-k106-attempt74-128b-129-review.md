# iOS B2-K106 review: attempts 74, 128b, and 129

Candidate provenance: Grantiva CLI `8f2cff67`. This review is read-only and grades only the iOS half of `B2-K106`.

## Verdict

**PASS.** Attempt 129 supplies the previously missing killed non-keep-alive runtime leg. Joined with attempt 74 and the exact semantic tests, every K106 clause is supported.

## Criterion mapping

- **Killed keep-alive run and forced reclaim:** `cov3-ios-attempt74/run.command.json` is an exact `run ... --keep-alive` with a row-owned simulator. `run.exit.txt` records the `kill -9` result. `teardown.out` reports the claimed Grantiva staging directory in `temporaryDirectoriesRemoved`, and the post-teardown inventories show it absent.
- **Preserved explicit report directory:** attempt 74 uses `--report-dir .../preserved-report`; `preserved-report-after.txt` says `present`, and the retained report files remain readable. This is the explicit “preserved report dir is never removed” branch.
- **Killed non-keep-alive run and both temporary directories:** attempt 129's `run.command.json` has no `--keep-alive`. `claim-before-kill.json` records `keepAlive:false` and exactly the staged-flow and generated-report temp directories. `run.exit` is `-9`. `teardown.exit` is `0`; `teardown.out` lists both exact paths in `temporaryDirectoriesRemoved`; the harness verifies both paths are absent afterward.
- **JSON reporting:** both teardown outputs encode `temporaryDirectoriesRemoved`. Attempt 129's top-level `reclaimed:false` does not contradict K106: its campaign capacity record was intentionally retained until the separate session cleanup, while the two required temp directories were removed. `parent-session-cleanup.exit` is `0`.
- **Live owner and unrelated live-run protection:** exact-head `SimulatorReaperTests.testForceTeardownKeepsTempDirectoriesOfALiveOwner` creates claimed temp directories owned by the live test process, asserts an empty removed list, and asserts both directories remain. This is the criterion's specified semantic-test branch. Attempt 74's row-owned runtime and the separate campaign devices establish that teardown was targeted to its exact UDID.
- **Two-directory claim and result contract:** `SimulatorLeaseTests.testClaimRoundTripsTheTemporaryDirectories` records `/tmp/grantiva-A` and `/tmp/grantiva-report-B` and round-trips the new claim field; `SimulatorReaperTests.testForceTeardownRemovesTheKilledRunsTempDirectories` asserts both dead-owner paths are removed and listed in encoded output.

## Attempt 128b qualification

Attempt 128b is not needed to grade K106. Its aggregate `preserved.cmp` failure is a harness comparison error: `preserved-before.sha256` and `preserved-after.sha256` differ only for the active lease file, which legitimately changes while the run proceeds. The two report marker hashes, both xcconfig hashes, and the unrelated marker-lock hash are identical, and `run-alive-after-install.exit` is `0`. It is useful concurrency corroboration but should remain qualified rather than treated as a clean whole-harness pass.

## Evidence roots

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt74/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt128b/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt129/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorReaperTests.swift:395`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorLeaseTests.swift:270`
