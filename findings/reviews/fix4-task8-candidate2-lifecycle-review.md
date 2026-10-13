# Task 8 candidate 2 lifecycle retry review

Scope: completed non-force lifecycle retry under `findings/evidence/round4-smoke-candidate2/03-lifecycle-attempt2`. This was a bounded read-only review of identity, raw case records, reports, process/session/forward controls, acceptance, and the retained background-thread exception. No live/device command was run.

## Verdicts

- **Specification/evidence verdict: APPROVED for all non-force lifecycle phases.** Startup interruption, detach/ready behavior, ready interruption, absent-app controls, log-child cleanup, and cycle diagnostics have complete binding evidence and expected outcomes on both platforms where required.
- **Quality/integration verdict: APPROVED with one nonblocking helper defect.** A background snapshot thread reports a stable-file disappearance after the Android detach report had already been captured and the source session directory was removed during scoped stop. The exception does not leave an acceptance gap or justify another lifecycle run, but the helper should make snapshot-thread completion/error handling explicit before future reuse.

## Identity and executed code

The invocation is bound to candidate manifest SHA-256 `6c0a8bd9da5cff886baf9aceb58394e6ca1632b5b3b10f6aa1bb066aa50be14e`, explicit owned iOS UDID `553C67C6-7C11-4976-85A0-148C9C8AC278`, Android `emulator-5580` / `smoke4-android`, session `fix4-8`, unset API environment, and the distinct attempt-2 output. It exits 0 and acceptance status is passed.

The verified identity retains CLI source `22055ff981ae1ffd5aaae69190d7af180f239162`, binary and bundle hashes, runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, matching packaged/installed runner SHA-256 `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`, `.15` install stamp, demo source `84af7581b75134b0e417b254e4317d565f7b73c6`, and iOS app manifest. Executed controller/helper hashes match the durable copies: `823c56714ffda2e869ab6fdd82a5ae013febe6bbe3f2f4c42f5a365d347f127a` and `a7cee86963f473850041854c1241cc07215d1e28e083ed0cf4278cdd780bd352`.

## Lifecycle cases

- **Startup interruption:** iOS PID 32715 and Android PID 32727 are captured in `starting` state. Both foreground commands exit 130 with the exact platform-specific SIGINT cleanup notice. The helper's exact PID, session, forward, and process cleanup assertions complete before recording each accepted row.
- **Detach/ready:** iOS PID 32764/port 8508 and Android PID 33928/port 64456 reach ready on their exact devices. Immediate hierarchy works. A second start while each is starting/running returns the expected `already_running` shape with null starting port rather than inventing a ready port; plain and JSON controls pass. Scoped stop returns `stopped` for the same PID/device/port, and Android forwards are absent afterward.
- **Ready interruption:** both platforms successfully serve hierarchy before interruption, then exit 130 with the accepted notice and cleanup controls.
- **Absent app:** targeted iOS uninstall is independently confirmed before and after canonical install refusal, then the exact frozen app is restored. Android missing-app start exits promptly without creating a session, and device forwards are absent afterward.
- **Log cleanup:** explicit `--platform ios` is present. Success, failure, and interruption exit 0, 1, and 130. Success and failure reports retain passed and failed terminal states; interruption binds the exact `.15` runner, staged/source flow hashes and semantic equivalence before SIGINT. Each case records one terminal log-stream diagnostic and three subsequent process inventories without its unique marker, proving the owned log child is gone.
- **Cycle controls:** screens, root-relative, and absolute forms all explicitly select iOS, exit 1 in about 1.71–1.73 seconds, and retain their exact circular dependency chains.

## Background snapshot exception assessment

`invocation/stderr.log` contains one exception from `Thread-4 (preserve_runner_report)`. Its source is the Android detach session report under temporary session `0CD2A503-…`; `shutil.copytree` observes the entire stable source report disappearing during a later copy pass, including `report.json`, logs, flows, assets, and allure directory. This is not the earlier `.tmp` race and was correctly not swallowed by the narrowed copy helper.

The exception is harmless to this phase's required evidence for three concrete reasons:

1. The destination Android runner snapshot already contains a valid terminal `report.json`, flow detail, JUnit, runner/client logs, and Allure result. The report is passed, has one passed flow, two passed commands, and no failed/skipped/running/pending work. The iOS counterpart is likewise retained.
2. Detach acceptance is independently established by the ready document, immediate hierarchy, already-running controls, exact stop response, session cleanup, and forward cleanup. None depends solely on the background snapshot.
3. The exception occurs in the daemon snapshot thread while scoped stop removes the temporary session report directory. The main helper continues through later ready-interrupt, absent-app, all three log cases, and all cycle cases, then writes passed acceptance and exits 0. It is therefore a post-capture teardown race, not evidence that the runner failed or that a report never existed.

The helper quality issue is that daemon-thread exceptions are not joined or propagated through an explicit result channel. A future revision should stop/join the snapshot worker before deleting the source, or treat whole-source disappearance as expected only after confirming a complete terminal destination snapshot. It must continue to surface stable-file disappearance before a complete capture. This improvement is not a reason to rerun the already complete lifecycle acceptance.

The original first lifecycle failure remains retained and is not rewritten by this retry. Force teardown, physical device deletion, the pending iOS MCP retry, and overall Task 8 completion remain separate gates.
