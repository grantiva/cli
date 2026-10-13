# Task 2 — L86 source fix

Status: implementation and source validation complete; single full-suite run GREEN. Independent review and controller-owned live acceptance/CI remain pending.

Worktree: `/Users/kyle/Developer/grantiva-cli/.worktrees/fix5-twin-ownership`; branch `fix5/twin-boot-ownership`; base `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`.

Source/test commit: `77aa2a63064afc3a68d9ea71232f46e1937ba2ff`. Evidence remains uncommitted for controller archival onto coverage-campaign, as directed. Full run started against identical source/test bytes before this commit.

## Implementation

`SimulatorCapacity.snapshot(devices:)` captures registry records under the existing flock before asynchronously enumerating devices. Pruning removes only records present and unchanged in that prior observation and classified stale by the existing prune policy. New or changed records survive the old observation; a later fresh observation can still prune genuinely stale records. Ownership is never derived from Booted state. Registry JSON format is unchanged.

The raw-array `sessions` API was replaced with a snapshot token that pairs the list and prior records. Audited every production prune path: reserve, manager boot's already-booted ownership check, managedSessions, teardown by session, teardown by UDID, and cleanup. All now use the paired observation. An observation for another registry conservatively cannot prune. Empty-registry reads still create no runner home.

## Tests and preserved evidence

Evidence: `findings/evidence/fix5-L86` in the fix worktree. Each command has exact argv/cwd/base HEAD, source patch, exit/elapsed/hashes, stdout/stderr and fresh home paths; GRANTIVA_API_KEY unset for every command. Both configured home roots remained absent on all four runs. Gzip archives were verified against all recorded raw SHA-256 hashes; `postflight.json` confirms the tested patch exactly equals the source/test commit diff.

- `red`: original product source plus deterministic regressions, exit 1. Two tests, nine expected failed assertions. Capacity loses ownership/state/acquisition identity; manager retains one boot but loses ownership/owner/acquisition identity and cannot shut down/delete the owned created device.
- `focused-green`: despite its directory name, FAILED during compilation, exit 1: a migrated test closure captured non-Sendable XCTest self. No tests executed. Preserved without overwrite.
- `focused-corrected`: fixed test capture to immutable device array, exit 0. 84 tests, zero failures across SimulatorCapacityTests, SimulatorManagerTests, DefaultSimulatorOwnershipCoreTests and SimulatorReaperTests.
- `full`: one `swift test` invocation, exit 0, 201.123 seconds. 2,027 tests, zero failures (MCP 281, Core 978, CLI 667, API 101). No retry performed. Both fresh home roots remain absent.

The affected twin-manager regression now captures the second Shutdown list, boots and activates the seeded live foreign-PID twin, then returns that stale list. It asserts exactly one boot, original owner/acquiredAt and active/true ownership; it then verifies shutdown/deletion using created-device provenance. No sleep scheduling remains in that regression. Additional session tests cover Shutdown and missing snapshots plus records added during enumeration, followed by fresh stale pruning. Existing focused tests cover capacity limits, pending twin coordination, foreign sessions, dead owners, durable/sessionless records, manual and legacy-device protection.

## Scope and remaining acceptance

No live device operations, runner builds, releases, push/PR/merge, or frozen candidate edits. Swift builds only built the package/test products. Controller must independently review, run owned concurrent-ensure/teardown live acceptance, and required CI before integration. Snapshot API is a source-level API change within GrantivaCore; all repository consumers were migrated. This protocol does not hold flock across asynchronous simctl work and introduces no schema migration.
