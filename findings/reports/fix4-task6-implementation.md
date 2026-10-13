# Task 6 report: public diagnostics and migration documentation

Status: complete

Branch: `fix4/public-docs`

Base: `03cee568869c45077c3015f97f8b75d19ea822c4`

Head: `ce23e52b892b446f913e82f1d3d4d07db710e765`

Commits:

- `bc10deb87fd687d7449866376f671888ee148548` — `Fix doctor diagnostics and document compatibility changes`
- `ce23e52b892b446f913e82f1d3d4d07db710e765` — `Make doctor default ownership tests deterministic`

## Changes

- L67: ambiguous Xcode/Gradle project selection now creates the Platform warning in `Advisory`. Tests inspect the formatted text and decoded JSON, prove exit classification remains non-failing, retain the selection guidance, and prove `PlatformResolver` (the `run` path) still rejects the ambiguity.
- L81: the full `DoctorRunner.checkBootedSimulator` entry appends the unowned default-name simulator note to the selected booted simulator's message. Production-entry tests cover booted-first and default-first orders, no default-name device, a Grantiva-owned default-name device, formatter output, decoded JSON, status, and section. Existing no-booted and list-failure coverage remains passing.
- L70: README documents literal filenames, legacy baseline lookup, approval-time migration, the `Deep%20Links.png` to `Deep Links.png` example, and why ambiguous `%` filenames required the change. It explicitly says working legacy baselines need no manual rename.
- L74: public documentation states that date-valued JSON uses ISO 8601 UTC strings and inventories `timestamp`, `detectedAt`, `startedAt`, `acquiredAt`, `createdAt`, and `finishedAt`. It also pins the selector order and current lifecycle JSON keys.

## Semantic red

Raw logs: `findings/evidence/fix4-6/red/`

- `DoctorSelectionTests`: failed on the Platform section assertion.
- `DoctorTests`: failed on the missing ownership note in both input orders.
- `DocsContractTests`: failed on the new literal documentation contract.
- `HelpCorpusTests`: passed unchanged.
- The fresh empty runner home remained empty.

## Verification

Focused green logs: `findings/evidence/fix4-6/green-focused/`

- `DoctorSelectionTests`: pass.
- `DoctorTests`: pass (`DoctorTests-rerun.log` records the final corrected semantic JSON assertion).
- `DocsContractTests`: pass.
- `HelpCorpusTests`: pass.

Exact CLI acceptance: `findings/evidence/fix4-6/acceptance/`

- Ambiguous `doctor` text exit: 0; Platform appears under Advisory with the full selection guidance.
- Ambiguous `doctor --json` exit: 0; Platform has `"section": "Advisory"` and the full guidance.
- Ambiguous `run` exit: 1 with `Found both an Xcode project and Gradle settings. Pass --platform ios|android or set GRANTIVA_PLATFORM.`
- The read-only live doctor check exposed the default-name ownership note without changing any simulator.
- The acceptance runner home remained empty.

L81 deterministic source fixture is in `Tests/GrantivaCoreTests/DoctorTests.swift`; its raw focused output is under `green-focused/DoctorTests-rerun.log`. It calls the full production entry in both list orders and includes absent-default and owned-default negative controls.

Help regeneration: `findings/evidence/fix4-6/help/`

- Regenerated 172 pages with the campaign's `helpcorpus.sh`.
- `canonical.diff` is empty; no generated page is stale.

Full verification: `findings/evidence/fix4-6/full/`

- Full `swift test`: exit 0.
- Fresh empty unit-test runner home: 0 entries after the suite.
- `GRANTIVA_API_KEY` was unset and `GRANTIVA_SESSION_ID=fix4-6` throughout acceptance/test commands.

Final source and literal evidence: `findings/evidence/fix4-6/final/`

- `implementation.diff`
- `baseline-literals.txt`
- `docs-literals.txt`
- `git-diff-check.exit` (0)

## Concerns

None. No simulator or emulator was created, booted, shut down, or deleted; no owner-device mutation or default runner home was used. No merge or release was performed.

## CI fix 1: host-independent default simulator fixture

PR #210's first macOS 15 CI run failed after a successful build because that
host resolved `DefaultSimulator.name` to `iPhone 17 Pro`, while the binding
fixture deliberately models a booted `iPhone 17 Pro` and an unowned default
`iPhone 18 Pro`. The production behavior was correct for the host; the test
had accidentally coupled its explicit iPhone 18 scenario to ambient Xcode
device catalogs.

The full raw CI log was copied unchanged to
`findings/evidence/fix4-6/ci-fix1/task6-ci-failure.log`; its SHA-256 matches the
supplied `/private/tmp/task6-ci-failure.log`:
`1b5083f77242e835677d1eeb05b9427c5226edfd6c156d4cc083c553c82a6877`.

`DoctorRunner.checkBootedSimulator` now accepts a package-internal
`defaultName` test seam whose production default remains
`DefaultSimulator.name`. The binding fixture explicitly supplies
`iPhone 18 Pro` in both device orders and in the absent/owned negative
controls. A sibling production-entry test exercises both currently supported
catalog outcomes, `iPhone 17 Pro` and `iPhone 18 Pro`, without changing the
expected ownership contract.

CI-fix evidence: `findings/evidence/fix4-6/ci-fix1/`.

- `semantic-red.log`: compile/API-contract red, exit 1 with no tests executed,
  because the production entry did not yet accept the deterministic
  `defaultName` seam; isolated runner home remained empty. This proves the
  test seam was absent at the parent commit, rather than independently proving
  the runtime defect.
- `task6-ci-failure.log`: behavioral red provenance from the original macOS 15
  CI run. The suite executed and recorded eight runtime assertion failures
  caused by ambient `DefaultSimulator.name` resolving to `iPhone 17 Pro` while
  the binding fixture expected `iPhone 18 Pro`.
- `focused-green.log`: 36 Doctor tests pass; isolated runner home remained
  empty.
- `full-fresh-home.log`: CI-equivalent `scripts/test-fresh-home.sh` passes and
  ends with `Runner home stayed empty.` Independent parsing counted 2,010
  passing tests: 281 MCP, 967 Core, 661 CLI, and 101 API.
- `GRANTIVA_API_KEY` remained unset and `GRANTIVA_SESSION_ID=fix4-6`.
