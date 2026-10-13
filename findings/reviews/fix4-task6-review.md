# Task 6 independent source, specification, quality, and evidence review

Review range: `03cee568869c45077c3015f97f8b75d19ea822c4..bc10deb87fd687d7449866376f671888ee148548`

Verdict: **PASS** for source, specification, quality, and local evidence. No actionable source finding was identified. Draft PR #210 CI and merge remain external process gates.

## Specification review

- **L67 passes.** `DoctorCommand.platformSelection` changes only the ambiguous Platform check's section from Project to Advisory. Its warning status, message, selection fix, detected platforms, and non-required classification remain intact. The production resolver still rejects the same ambiguity. Tests cover the section in formatted text and JSON and preserve rejection by `PlatformResolver`; retained CLI acceptance records text exit 0, JSON exit 0, and `run` exit 1 with the complete guidance.
- **L81 passes.** The full `DoctorRunner.checkBootedSimulator` production entry still chooses the first booted simulator and retains `.ok`/Advisory, then independently searches the complete device list for an unowned default-name simulator. Production-entry tests exercise both required list orders, the absent-default control, and the Grantiva-owned-default control. Existing no-booted and list-failure branches remain present and passed in the retained focused log. Formatter and Codable round-trip assertions cover the note, while retained live text and JSON acceptance show the note through the actual CLI without device mutation.
- **L70 passes.** README accurately describes literal-space artifact names, legacy percent-encoded baseline fallback, approval-time migration, the concrete `Deep%20Links.png` to `Deep Links.png` example, `%25` disambiguation, and that working legacy baselines need no manual rename. This matches `ScreenArtifact` and `BaselineStore.local` behavior.
- **L74 passes.** Public docs state ISO 8601 UTC as the representation scripts should consume, give the epoch example, and explicitly reject numeric timestamp alternatives. The six documented keys (`timestamp`, `detectedAt`, `startedAt`, `acquiredAt`, `createdAt`, `finishedAt`) exhaust the locally encoded public `Date` fields. The additional source `Date` property found during review, `RunnerHelperReaper.deadline`, is internal runtime state and is not Codable/output. Server-originated API timestamp strings are outside the shared encoder migration.
- The binding selector order is published exactly as `label → identifier → placeholder`. Current lifecycle examples name `runnerSessionStopped`, `leftoverProcesses`, and `reapedProcesses`. No command, flag, MCP tool, or existing JSON key changes in this range; no new JSON key is introduced.
- Public wording contains no internal campaign IDs or campaign terminology.

## Quality review

The implementation is narrow and order-independent. It reads provenance once, does not alter the reported booted device, and adds no simulator lifecycle side effect. Tests call production entries rather than duplicating helper logic. Documentation contract assertions use public literals and cover all requested compatibility subjects. No blocking or non-blocking code-quality finding was identified.

## Evidence review

- Semantic red is valid: retained logs show the new Doctor selection section assertion failing on Project, both L81 list-order cases failing for the absent note, and the documentation contract failing before implementation. Help corpus was correctly unchanged at red.
- Focused green is valid: the final Doctor rerun records 35 passing tests, and retained focused logs report the other requested test groups passing.
- Exact acceptance is valid: doctor text and JSON both place Platform under Advisory and retain the full guidance; each exits 0. `run` retains the ambiguity error and exits 1. Live doctor text/JSON also expose the ownership note. Acceptance and test runner-home inventories are empty, and the report records `GRANTIVA_API_KEY` unset and the task-specific session ID.
- Full-suite evidence reports exit 0. Controller parsing records 2,009 tests total: 281 MCP, 966 Core, 661 CLI, and 101 API.
- Help regeneration reports 172 pages and an empty canonical diff. Final git-diff check reports exit 0.

## Remaining evidence gates

- Draft PR #210 CI was still running when this review completed. CI success and the eventual reviewed squash merge must be recorded before the campaign marks Task 6 merged.
- The retained live ownership acceptance uses the host's real default-name simulator UUID rather than the fixture literal `USER-DEFAULT`; the deterministic production-entry tests provide the required exact literal and both list orders. Together these satisfy the acceptance requirement without touching owner devices.
