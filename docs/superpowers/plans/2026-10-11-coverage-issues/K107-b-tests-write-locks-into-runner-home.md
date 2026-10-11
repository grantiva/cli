# Unit tests create `FAKE-…` and `TEST-REPORT-…` lease lock files in the real runner home

Severity: ux
Component: cli
Platforms: n/a (test suite; the files land in whatever runner home the environment that runs `swift test` points at)
Rows: IOS-057 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Split: second cause behind IOS-057's lock directory; K107-a covers the product's own lock files.

## Expected
Tests never write into the user's runner home (`GRANTIVA_RUNNER_HOME` or `~/.grantiva/runner`). Most lease tests
already pass a temp `directory:` (e.g. WDADeviceHomeTests.swift:103, `leaseDirectory` under the test home).

## Actual
The QA runner home's `locks/` holds 468 `TEST-REPORT-<UUID>.lock` and 206 `FAKE-<UUID>.lock`
(`findings/evidence/cov-ios/IOS-057/after.out`), plus `AAAA-1111.lock`. These identifiers exist only in the test
suite:
```
Tests/GrantivaCoreTests/RunnerSessionReportTests.swift:205:    private func udid() -> String { "TEST-REPORT-\(UUID().uuidString)" }
Tests/GrantivaCoreTests/RunnerSessionCleanupTests.swift:333:            udid: "FAKE-\(UUID().uuidString)",
Tests/GrantivaCoreTests/WDADeviceHomeTests.swift:31:        let env1 = IOSPlatform().runnerEnvironment(runnerHome: home, deviceID: "AAAA-1111")
```
Each run of the suite adds a fresh UUID set, so the directory grows without bound.

## Repro
```
cd /Users/kyle/Developer/grantiva-cli          # any checkout at 51c597a
export GRANTIVA_RUNNER_HOME=/tmp/k107b-home; rm -rf "$GRANTIVA_RUNNER_HOME"
swift test --filter 'RunnerSessionReportTests|RunnerSessionCleanupTests' 2>&1 | tail -3
ls "$GRANTIVA_RUNNER_HOME/locks" | sed -E 's/[0-9A-F-]{36}/<UUID>/' | sort | uniq -c
```
Today: `TEST-REPORT-<UUID>.lock` and `FAKE-<UUID>.lock` entries appear under `/tmp/k107b-home/locks`. Without the
override they land in `~/.grantiva/runner/locks`.

## Evidence
- findings/evidence/cov-ios/IOS-057/after.out (lock directory listing, 694 entries)
- findings/cov-ios-results.md row IOS-057

## Suspected cause
- RunnerSessionReportTests.swift:76-77, :112-113, :135 and RunnerSessionCleanupTests.swift:329-341 call
  `RunnerSession.runFlowFiles(…, udid: <test id>, …)` with no lease directory.
- Sources/GrantivaCore/Runner/RunnerSession.swift:47 and :336 call `SimulatorLease.acquire(udid:platform:)` with the
  default directory, which is `RunnerManager.baseDir + "/locks"` (SimulatorLease.swift:48-50), and
  `RunnerManager.baseDir` is a process-wide `static let` read from the environment (RunnerManager.swift:110-121).
  `runFlowFiles` has no parameter to redirect it, so the tests cannot avoid the real home.
- The origin of `AAAA-1111.lock` was not pinned (the WDADeviceHome tests that take leases pass a temp
  `leaseDirectory`); it is likely another `runFlowFiles`/`prepare` call without one.

## Acceptance criteria
- `RunnerSession.runFlowFiles` (and the single-flow capture entry) accept a lease directory, or a runner home,
  defaulting to the current behaviour; every test passes a temp one.
- Running the full `swift test` with `GRANTIVA_RUNNER_HOME` pointed at an empty directory leaves that directory empty
  (or nonexistent) afterwards.
- Add a guard test in `GrantivaCoreTests` (e.g. `TestHygieneTests.testSuiteDoesNotWriteIntoTheRunnerHome`), or a
  CI step that runs the suite with `GRANTIVA_RUNNER_HOME` set to a fresh dir and fails if anything appears in it.
