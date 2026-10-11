# Coverage campaign — handoff (resume from here)

Updated: 2026-10-12 (round-2 coverage pass in progress). This file is the tool-agnostic resume point for the full-coverage campaign. Everything an agent needs is on branch `coverage-campaign` of grantiva/cli, worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/regression`. The per-plan SDD ledgers are git-ignored scratch; copies are committed under `findings/ledgers/` at each phase boundary (the live ones are in `.superpowers/sdd/<plan>/progress.md`).

## Goal and exit criterion
Spec: `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Loop: fix wave → repack → smoke → full coverage pass → triage, until one full pass yields zero `fail` rows. Release is the owner's decision; the campaign never declares a release.

## Standing rules (binding for every agent)
- Never boot, shut down, erase, delete or command simulator `iPhone 17 Pro` (B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C), `iPhone 18 Pro` (FE441EE5-BBFC-4981-B68A-59C0DBCE26D6), AVD `Pixel_8_API_35`, or any device you did not create. Always pass `--simulator/--udid/--device` explicitly. Never `teardown --all`, `xcrun simctl shutdown all`, `simulator cleanup`, `pkill`/`killall`, or kill a PID you did not start. Never `git stash`.
- Test environment: `GRANTIVA="$HOME/.grantiva-qa/bin/grantiva"` (release build of grantiva/cli `main`, with `grantiva_GrantivaCore.bundle` beside it — without the bundle `runner install` silently uses a stale bundle), `GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"`, `GRANTIVA_SESSION_ID=<slice>`, `GRANTIVA_API_KEY` unset. Never write under `~/.grantiva/runner`. Android shells: `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- Runner repo `~/Developer/maestro-runner`: the only remote to use is `grantiva` (github.com/grantiva/runner). Never fetch/push/mention the other remotes or any project the runner derives from (identifiers and raw output exempt). `go test` only with a package list, never bare `./...`.
- PRs: TDD, CI green, review loop (task review → fix rounds with scoped re-reviews; minors are fixed too), then `gh pr merge --squash --delete-branch` and verify `state == MERGED`. No `Co-Authored-By`, no `Generated with`, no session links in commits/PR bodies. Findings are repo files (briefs), never GitHub issues.
- Verification slices never fix; every doubtful behaviour is `fail`; evidence per row (`commands.txt` + verbatim raw output).
- Command gotchas learned: `emulator teardown --serial` (no `--name`); `simulator ensure --name X --device-type "iPhone 17" --runtime "iOS 26.0"`; `simulator teardown --udid … --force` may keep a session record, use `--session-id`; there is no `runner --json` (use `runner version --json`).

## Where things are (versions)
- grantiva/cli `main` c65fc17 = 2.1.0, bundles grantiva-runner 1.1.28-grantiva.11 (runner `grantiva/main` 1be68db). QA bin/home are on these.
- landmarks-demo `main` b3f046f (coverage flows under `.maestro/coverage/`; Android `10-seed-many` asserts Landmark 28).
- Merged PRs this campaign: runner #13–#20; CLI #184–#199; demo #1, #2.

## Documents
- Round 1: matrix `docs/superpowers/plans/2026-10-11-round1-coverage-matrix.md`; report `2026-10-11-round1-coverage-report.md`; briefs `2026-10-11-coverage-issues/K01..K111` (+ `00-cluster-map*.md`, `00-expectation-corrections.md`).
- Round-2 fix wave plan: `2026-10-11-round2-fix-wave.md` (rulings table inside; all 15 tasks done incl. addendum). Smoke results: `findings/round2-smoke.md` (+ `findings/evidence/round2-smoke/`).
- Addendum briefs: `2026-10-12-coverage-issues-round2/L01..L07` (L01–L04 fixed in runner #20 / CLI #198; L05, L06, L07 OPEN for round 3).
- Round-2 coverage pass plan: `2026-10-12-round2-coverage-pass.md`; matrix `2026-10-12-round2-coverage-matrix.md` (1084 rows). Slice branches/worktrees: `cov2/cli` (`.worktrees/cov2-cli`), `cov2/ios` (`.worktrees/cov2-ios`), `cov2/android` (`.worktrees/cov2-android`); results `findings/cov2-<slice>-results.md`, evidence `findings/evidence/cov2-<slice>/`.
- Help corpus: `findings/help/` (regenerated from c65fc17).

## Status of the round-2 coverage pass (see the ledger copy for detail)
- Task 1 matrix: complete.
- Task 3 CLI slice: complete (cov2/cli 33c3a4e): 335 pass / 7 fail / 13 fail-triage / 6 blocked / 4 n/a + EXTRA-01..07.
- Task 4 iOS slice: implementer done (cov2/ios 6b7d686): 416 pass / 16 fail / 6 triage / 4 blocked; 39 @27.0 pass; review found 2 text fixes → fix round 1 in progress (B2-K37.2 precision, IOS-134 regrade).
- Task 5 Android slice: running (device `cov2-android`, session `cov2-android`).
- Triage prep: `cluster-map-round2.md` (CLI + iOS fails) being written in the SDD workspace; Android to fold in.
- Task 6 (next): `git merge --no-ff cov2/cli cov2/ios cov2/android` into `coverage-campaign`; one brief per fail in `docs/superpowers/plans/2026-10-12-coverage-issues-round2/` (continue the L numbering from L08; format as the K/L briefs); expectation corrections for the `fail (matrix/brief error — triage)` rows; report `docs/superpowers/plans/2026-10-12-round2-coverage-report.md` with the verdict `ROUND 2: <n> findings — round 3 fix wave required`; push; then write `2026-10-13-round3-fix-wave.md` (writing-plans) and execute it (runner + CLI PRs, repack .12, smoke, round-3 coverage pass).

## Incidents to report to the owner
1. Round 1, CLI slice: README quick-start resolved `init`'s default simulator to the owner's `iPhone 18 Pro` and booted it with the demo app (shut down afterwards, not deleted).
2. Round 2, iOS slice (MCP-031 / B2-K37.2): `grantiva_build {scheme}` with no simulator resolved the default to `iPhone 18 Pro` and booted it; it is still Booted (left alone per the rule). Its record in `~/.grantiva/simulator-capacity/sessions.json` (which marked it an ephemeral slot deletable by a session teardown) was removed; backup in the session scratchpad. The capacity ledger is not scoped by `GRANTIVA_RUNNER_HOME` (finding for Task 6).
3. Round 1 fix wave: a runner test once killed host emulators (fixed, F18); an agent's malformed `pkill` killed other shells (rule added); 8 stale AVD names pruned from `~/.grantiva/android/created-avds.json`.
4. 675 stale test lock files were found under `~/.grantiva/runner/locks` (K107-b); the tests no longer write there, the files were left for the owner.
5. Host load from other processes spiked to 46 during one smoke run; Android emulator timings in `findings/round2-smoke.md` are load-sensitive.

## Open items carried
L05 (first lookup after launch slow on software-rendered AVD), L06 (page-source selectors crash-check only between attempts), L07 (far-side swipe opens the row 2/3 under load; demo flow cannot detect a missed swipe), K111 (screenrecord overrun), deferred minors: holdTrack fails on a malformed extra track; SIGHUP reset under nohup.
