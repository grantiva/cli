# Doctor hides the default-simulator ownership note when another simulator is booted

Severity: contract
Component: doctor simulator diagnostics
Platforms: iOS host check
Rows: N3-15
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.

## Expected

N3-15 requires `doctor` and `doctor --json` to say that a simulator with Grantiva's default name is not used as the default when that simulator exists but Grantiva did not create it:

`("iPhone 18 Pro" (<udid>) was not created by Grantiva, so it is not used as the default)`

The check remains advisory and the note does not change the command's exit code. The row is read-only and does not require every simulator to be shut down.

## Actual

After final campaign cleanup, the host still has two owner simulators booted:

- `iPhone 17 Pro` `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`, iOS 26.0;
- default-named `iPhone 18 Pro` `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`, iOS 27.0, the exact user-created simulator identified by L08 and absent from Grantiva's created-simulator ledger.

Both doctor forms exit 0. Text prints only:

```text
✓ Booted Simulator  iPhone 17 Pro — iOS 26.0
```

JSON likewise contains a single successful `Booted Simulator` record whose message names only the iPhone 17 Pro. Neither output names the iPhone 18 Pro, its UDID, or the required ownership/default note. Booted inventories before and after are byte-identical, so the valid read-only rerun touched neither owner device.

## Evidence

- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/text.out`
- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/json.out`
- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/booted-before.json`
- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/booted-after.json`
- `findings/evidence/cov3-controller/N3-15-after-final-cleanup/commands.json`
- `findings/controller-N3-15-final-environment-review.md`
- Retained L08 ownership proof for the exact iPhone 18 Pro and UDID: `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L08-mcp-build-default-takes-user-simulator.md:19-35`.

## Supported cause

`Sources/GrantivaCore/Doctor/DoctorRunner.swift:94-115` lists simulators and immediately returns an `.ok` check for `devices.first(where: \.isBooted)`. It calls `noBootedSimulatorCheck` only when no simulator is booted. The default-name ownership lookup and note at lines 119-128 therefore run only in the no-booted branch.

`Tests/GrantivaCoreTests/DoctorTests.swift:252-269` calls `noBootedSimulatorCheck` directly with a shutdown, unowned default-named simulator. The production-entry test at lines 279-285 covers one booted device separately. No test calls the full `checkBootedSimulator` entry point with both a booted non-default device and an unowned default-named device.

## Acceptance criteria

- Call the full `DoctorRunner.checkBootedSimulator` production entry with a booted non-default iPhone 17 Pro and an unowned default-named iPhone 18 Pro. The returned check names the booted simulator and also contains `"iPhone 18 Pro" (USER-DEFAULT) was not created by Grantiva, so it is not used as the default`.
- Repeat with the two devices in the opposite list order. The ownership note is present in both orders; simulator-list ordering cannot hide it.
- Doctor text and `--json` expose the same note. The check remains in `Advisory`, its status remains `ok` when a simulator is booted, and the note does not change either command's exit code.
- When no simulator with the default name exists, a booted non-default simulator remains the ordinary concise success with no ownership note.
- When the default-named simulator's UDID is in the active runner home's created ledger, no `was not created by Grantiva` note is emitted.
- Preserve the existing no-booted behavior, including its ownership-aware ensure fix, and preserve the `Could not list simulators` failure branch.
- Add focused `GrantivaCoreTests/DoctorTests` coverage through `checkBootedSimulator`, not only direct tests of `noBootedSimulatorCheck`.
