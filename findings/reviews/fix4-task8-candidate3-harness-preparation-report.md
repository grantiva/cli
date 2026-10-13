# Task 8 candidate 3 full-smoke harness preparation

Prepared a separate candidate-3 controller/helper tree at `task8-candidate3-harness/`. Candidate 2's durable helpers and immutable evidence were not edited. No product edit, build, phase execution, device command, promotion, push, or reviewer dispatch occurred.

## Candidate boundary

Candidate 3 is valid only after the L85 CLI fix is merged into a clean CLI checkout and `candidate3_release.py` builds a fresh release binary/bundle from that exact merged HEAD, promotes that exact pair, performs the fresh-home bundled-runner upgrade, and freezes a new `grantiva.task8.candidate.v1` manifest. Candidate 2 hashes or phase grades cannot fill candidate-3 results.

The unchanged dependencies remain independently bound and checked: runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, native/install version `1.1.28-grantiva.15` with stamp `1.1.28-grantiva.15+android-drivers-2`, and demo source `84af7581b75134b0e417b254e4317d565f7b73c6`. Both release preparation and phase identity validation contain the literal runner SHA. They require the state/manifest SHA, clean runner checkout HEAD, and all source-bearing fields in the frozen uncached-test proof to equal that literal; the existing proof hashes, metadata, command, result, and empty-status checks remain mandatory. The release controller expects fresh demo build-input evidence under the candidate-3 evidence root and validates the actual iOS app/APK; it does not reuse a candidate-2 app grade.

All Task 8 phases rerun into a new `findings/evidence/round4-smoke-candidate3` tree: candidate/upgrade, Android runner, lifecycle, joint forwarding, iOS MCP including corrected L85 and all transport pairs, Android MCP transport, docs/output, final force teardown, and physical cleanup. The full sequence remains gated: any failure fails candidate 3 and leaves Task 9 blocked.

## Controller inputs

Before any executable phase, the controller supplies and freezes:

- A fresh scratch root with fresh build home, APFS-cloned runner home, phase projects, empty no-session projects, fixture copies, and candidate-3 evidence root.
- The clean merged CLI checkout path and exact merged SHA. `candidate3_release.py --merged-sha <SHA>` rejects a different/dirty HEAD and freezes the freshly built release artifacts.
- The frozen candidate-2 manifest at `findings/evidence/round4-smoke-candidate2/candidate.json` governs the current QA precondition. The release controller requires the current QA binary and bundle to match it exactly and backs up those artifacts with that same manifest before promotion; candidate-2 evidence stays read-only.
- The unchanged runner source/proof paths, packaged archive identity, expected `.15` version/stamp, and WDA cache manifest.
- The clean demo `84af` checkout and fresh candidate-3 iOS/Android build-input records and artifacts.
- Protected simulator inventory for UUIDs `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C` and `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`, plus protected `Pixel_8_API_35` config identity.
- Fresh owned targets created by `candidate3_provision.py`: `smoke4-c3-ios` on the literal approved iOS 26 runtime and `smoke4-c3-android` at `emulator-5580`, with session `fix4-8-c3`. The ownership manifest records exact creation commands and the emulator PID.
- Exact Android SDK/ADB/emulator/avdmanager and Java 21 paths, fixture/analyzer inputs, project paths, and platform app identifiers shown in `manifest.example.json`.

`candidate3_phase.py` is the bounded serial dispatcher and copies the exact executed helper beside each phase. The helpers independently validate candidate and ownership manifests before operating. `candidate3_docs.py` and `candidate3_cleanup.py` are separate controller steps. Root owns promotion, live execution, and final adjudication.

## Lifecycle snapshot race correction

The copied lifecycle helper no longer launches untracked daemon report-snapshot threads. Each capture gets a private stop event, an authentication event, a non-daemon thread, retained authenticated report/generated-flow paths, and an exception/result channel. The worker signals authentication only after binding the live exact PID/device argv, retaining both paths, and recording ownership. Every startup-interrupt, detached-ready, ready-interrupt, and force-teardown caller waits boundedly for that authentication (and verifies the observed PID when available) before interrupting or finishing the runner. This handshake does not wait for runner readiness or flow completion, so the startup-interrupt case retains its `starting` timing semantics. Worker errors and authentication timeouts fail synchronously.

Every caller then stops and joins its exact thread with a bounded timeout. After the stop request, the worker copies from its authenticated report path if the source still exists and otherwise records explicit terminal absence. Required acceptance depends on a complete passed retained report, not on continued live source existence. The stop operation re-raises worker copy/ownership failures. Required captures join and validate retained complete passed reports before phase cleanup or acceptance can continue. Repeated stop calls read only retained bytes; they do not recopy a deleted live source. When a generated flow was observed, its retained copy is also mandatory.

This does not weaken report evidence. `copy_report_snapshot` still tolerates only disappearing `.tmp` files from atomic writes; a missing or incomplete required retained report, missing stable files during copying, and all unrelated copy failures raise through the caller. Detached readiness still requires the retained report and passed status, and the helper cannot complete while a capture thread remains live.

The first live lifecycle attempt established that production cleanup can legitimately remove the report directory after a passing startup interruption. The round-3 policy therefore permits terminal report absence only for `startup_interrupt`, while preserving any earlier snapshot and writing explicit terminal metadata. Round 4 moves ready-interrupt capture completion before SIGINT and adds mandatory retained-report completion validation shared with detached readiness and force teardown; force already joins before teardown. Startup remains optional and preserves observed raw bytes and terminal metadata. Round 5 additionally recognizes normal detached-command cleanup of temporary launch files while the ready runner remains live: source absence at the first join is accepted only after required retained-report validation. See `task8-candidate3-lifecycle-fix-round5-report.md`; the original live attempt remains immutable and a fresh full lifecycle rerun is required.

## Cleanup corrections

Candidate-3 cleanup preserves the reviewed PID-reuse protection: immediately before an emulator fallback signal, the current PID row must still have the exact emulator/qemu executable, `-avd smoke4-c3-android`, and `-port 5580`. A missing row is harmless; a reused/mismatched row is refused and never signaled.

The helper now inventories the exact simulator UUID/name/runtime before classifying processes. `launchd_sim` and the installed `Landmarks` executable are recognized as simulator-managed only when their argv carries that exact controller-owned UUID and the simulator identity matches the ownership manifest. They are never directly signaled; exact `simctl shutdown/delete <UUID>` removes them. Unknown marker-bearing processes remain failures, so this exception cannot absorb unrelated processes or weaken protected-target rules.

AVD deletion accepts both Android tool formats while retaining exact ownership proof:

- legacy `AvdId=<owned name>` plus `avd.ini.displayname=<owned name>`; or
- generated `avd.id=<build>` plus `avd.name=<build>`.

Either format also requires the owned registration file to bind `path` to the exact `smoke4-c3-android.avd` directory and `path.rel=avd/smoke4-c3-android.avd`, the ownership manifest's successful exact `avdmanager create` command, baseline absence, live AVD-name identity, and the authenticated current PID/serial rules. Protected simulators and `Pixel_8_API_35` remain mandatory and unchanged.

## Prepared files and verification

The directory contains controller scripts, phase helpers, identity validation, example candidate/ownership/phase manifests, and lifecycle documentation copied from the final candidate-2 harness and rebound to candidate-3 paths/session/owned names. `manifest.example.json` references only this SDD helper directory and the candidate-3 evidence root.

Static Python compilation and JSON parsing were run only against these preparation files; no helper main, product test, build, or live command was executed during preparation. The round-5 correction has thirteen bounded filesystem/thread and AST fixture checks described in its report, including source deletion before the first required join and the actual attempt-2 retained report. The complete new-file diff is `task8-candidate3-harness-preparation.diff`; focused correction diffs are retained through `task8-candidate3-lifecycle-fix-round5.diff`.
