# Full-coverage test-and-fix campaign — design

Date: 2026-10-10. Owner: Kyle Browning. Status: approved in conversation ("A", "start working").

## Goal

Every grantiva feature works as documented, on iOS 26.0, iOS 27.0 and Android API 35, exercised through real flows against the landmarks-demo apps. Anything that contradicts a document, a brief, or a reasonable expectation is fixed, at every severity. Releasing 2.1.0 is not the goal; a clean full pass is. Tagging remains the owner's decision.

## Out of scope

`grantiva auth`, `grantiva console`, anything requiring a Grantiva account or network credentials; real hardware devices.

## Shape: rounds

A round is `fix wave -> repack -> build -> coverage pass -> triage`.

- **Fix wave.** Findings are fixed in PR batches, grouped by subsystem, in `grantiva/runner` (`~/Developer/maestro-runner`), `grantiva/cli` and `landmarks-demo` (flows and small test hooks). Each batch: TDD, review loop, CI green, squash-merged to `main` by the campaign (approved by owner). Commits and PRs carry no attribution lines and never mention any other project the runner is related to.
- **Repack.** The runner is rebuilt (`scripts/build-runner.sh --version <v> --wda-cache <dir> --cli <cli checkout>` in the runner repo), WDA caches regenerated for iOS 26.0/26.2/26.4/27.0 against Xcode 27 and pruned to build products, the tarballs and `RunnerManager.runnerVersion` bumped in one CLI PR.
- **Build.** One release build from `main` to `~/.grantiva-qa/bin/grantiva` with its `grantiva_GrantivaCore.bundle`; the runner home under test is a fresh APFS clone of the owner's `~/.grantiva/runner` so the upgrade path is exercised every round.
- **Coverage pass.** Three parallel slices (CLI, iOS, Android) in separate worktrees, each owning its devices, each row of the feature matrix run with a real flow. Round 1 rebuilds the 2.0.1 feature matrix (405 rows) for the new binary: every subcommand, flag and MCP tool minus auth/console, on every platform where it applies, plus the demo flow sets and every open brief's acceptance criteria. Later rounds re-run the full demo flow sets on all runtimes plus every matrix row a fix touched; the last candidate gets a full matrix again.
- **Triage.** Every finding becomes a brief (`docs/superpowers/plans/<date>-coverage-issues/<ID>-<slug>.md`, sections Expected / Actual / Repro / Evidence / Suspected cause / Acceptance criteria). There is no "minor, leave it" bucket.

## Exit criterion

One complete coverage pass on one binary with zero findings. The round report says so and stops.

## Round 1 fix-wave inputs

Briefs R01-R05 (`docs/superpowers/plans/2026-10-10-regression-issues/`), the twelve observations and the D02 wording list in `docs/superpowers/plans/2026-10-10-release-regression-report.md` §Observations, and the runner follow-ups left open in the review threads of grantiva/runner PRs #6-#12.

## Constraints that bind every round

Never touch the owner's simulator `iPhone 17 Pro` (B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C) or AVD `Pixel_8_API_35`; every device command names its device; `GRANTIVA_RUNNER_HOME` points at the clone; `GRANTIVA_API_KEY` unset. Findings and evidence live in the repo under `findings/`, never as GitHub issues.
