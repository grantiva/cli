# No CI step proves that `swift test` leaves an empty `GRANTIVA_RUNNER_HOME` empty; the in-suite guard covers only the lease lock directory

Severity: contract
Component: cli (tests/CI)
Platforms: n/a (test suite). Source check only; no slice ran `swift test`.
Rows: B2-K107-b [cli]
Regresses/extends: K107-b (docs/superpowers/plans/2026-10-11-coverage-issues/K107-b-tests-write-locks-into-runner-home.md) incomplete, criteria 2-3; fixing PR #190.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11
Triage note: the slice's grep looked for `TestHygieneTests` / "does not write into the runner home" and missed the guard #190 did add (`LeaseDirectoryGuardTests` in all three test targets, plus a refusal in `SimulatorLease` under XCTest). That guard meets criterion 3's "guard test" for lease locks. What is still unproven is criterion 2 (the whole runner home stays empty), which only a run of the suite against an empty home can show. Treat this brief as "add the CI step", not "the guard is missing".

## Expected
K107-b criteria:
1. tests take an injectable lease directory (met: `RunnerManager.leaseDirectory`, used by `RunnerSession.swift:92/:381`);
2. "Running the full `swift test` with `GRANTIVA_RUNNER_HOME` pointed at an empty directory leaves that directory empty
   (or nonexistent) afterwards";
3. "Add a guard test in `GrantivaCoreTests` ..., or a CI step that runs the suite with `GRANTIVA_RUNNER_HOME` set to a
   fresh dir and fails if anything appears in it."

## Actual
- `.github/workflows/ci.yml:37-41` runs plain `swift build` and `swift test`; no `GRANTIVA_RUNNER_HOME`, no emptiness check.
- The guard that exists (`Tests/GrantivaCoreTests/Support/LeaseDirectoryGuard.swift`, same file in GrantivaCLITests
  and GrantivaMCPTests) only refuses `SimulatorLease.acquire` without a directory and checks that `<home>/locks` was
  not created. `testTheDefaultLockDirectoryWasNotCreatedByTests` returns early when the lock directory already existed
  at start (`:62-63`), which is the case on any developer machine, so locally it asserts nothing.
- Other writers into the runner home are not guarded: `WDADeviceHome` (`<home>/versions/<stamp>/devices/<udid>`),
  `RunnerHelperReaper` and `SimulatorReaper` default to `RunnerManager.baseDir`
  (`RunnerHelperReaper.swift:130`, `SimulatorReaper.swift:228`), and `SimulatorManager` defaults `runnerHome` to it
  (`SimulatorManager.swift:23`). Whether a test reaches them without an injected root was not checked.
- The QA runner home holds 674 `FAKE-`/`TEST-REPORT-` lock files (findings/evidence/cov2-cli/B2-K107-b/qa_home_locks.out),
  all dated 2026-10-10 20:04-22:07, before #190 merged (2026-10-11 04:29). They are evidence of the pre-fix leak, not of
  a current one.

## Repro
Source check (no device):
```
cd /Users/kyle/Developer/grantiva-cli/.worktrees/release-main
grep -n -E 'RUNNER_HOME|swift test' .github/workflows/ci.yml
grep -rln 'LeaseDirectoryGuard' Tests
ls ~/.grantiva-qa/runner/locks | grep -c -E 'FAKE|TEST-REPORT'
```
The criterion-2 check itself (the step to add; run it on a branch, not from this brief):
```
H=$(mktemp -d); GRANTIVA_RUNNER_HOME="$H" swift test; find "$H" -mindepth 1 | head; test -z "$(ls -A "$H")"
```

## Evidence
- findings/evidence/cov2-cli/B2-K107-b/source.out, tests.out, qa_home_locks.out, commands.txt
- findings/ledgers/2026-10-11-round2-fix-wave-ledger.md:43 (review of #190: "TestHygieneTests weak/flaky", criterion 2 open)

## Suspected cause
Criterion 3 was implemented as a lease-only hook (`SimulatorLease.checkDefaultDirectoryUse`,
`Sources/GrantivaCore/Runner/SimulatorLease.swift:117-125`; `LeaseDirectoryGuard.swift:12-90`) instead of a whole-home
check, and the CI half was not added. `swift test` resolves the runner home from the environment
(`RunnerManager.resolveBaseDir`), so on CI any stray write lands in the runner's real `~/.grantiva/runner`, where nobody
looks.

## Acceptance criteria
- `.github/workflows/ci.yml` runs the suite with `GRANTIVA_RUNNER_HOME` set to a fresh `mktemp -d` and fails the job,
  listing the paths, if anything exists under it afterwards.
- That step passes on main (criterion 2 met), or the writers it finds take an injected root in their tests.
- `testTheDefaultLockDirectoryWasNotCreatedByTests` still runs when `GRANTIVA_RUNNER_HOME` points at an empty directory
  (it does today; keep it).
- Optional: a GrantivaCoreTests check (e.g. in `LeaseDirectoryGuardTests`) that snapshots the listing of
  `RunnerManager.baseDir` at bundle start and asserts it unchanged at bundle end, so a local `swift test` also catches a
  leak.
