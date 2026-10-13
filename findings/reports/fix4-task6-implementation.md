# Task 6 report: public diagnostics and migration documentation

Status: complete

Branch: `fix4/public-docs`

Base: `03cee568869c45077c3015f97f8b75d19ea822c4`

Head: `bc10deb87fd687d7449866376f671888ee148548`

Commit: `Fix doctor diagnostics and document compatibility changes`

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

None. No simulator or emulator was created, booted, shut down, or deleted; no owner-device mutation or default runner home was used. Branch was committed locally and was not pushed; no PR was created, merged, or released.
