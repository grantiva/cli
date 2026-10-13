# Task 8 candidate 3 lifecycle evidence review

**Specification verdict: APPROVED for the fresh candidate-3 non-force lifecycle phase.** Attempt 3 passes all 13 required checks across startup interruption, detached readiness and ready interruption on both platforms, absent-app handling, three log-cleanup endings, and three canonical cycle controls.

**Evidence-quality verdict: APPROVED.** The frozen identity, exact runner/device ownership, raw command streams, retained generated flows and reports, terminal snapshot metadata, cleanup assertions, and final acceptance agree. No blocking, important, or minor finding was identified. This verdict covers only `03-lifecycle-attempt3`; isolated force teardown and physical device cleanup remain future phases, so this is not an overall Task 8 gate verdict.

## Frozen invocation

- The invocation exits 0 after 76.885 seconds and writes `status: passed` with exactly the five non-force phases and 13 checks.
- Candidate manifest SHA-256 is `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`. Verified identity binds clean CLI source `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, QA binary `1b6a973b…`, bundle manifest `b0343304…`, runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, identical packaged/installed runner hash `9342b8a3…`, install stamp `1.1.28-grantiva.15+android-drivers-2`, demo `84af7581…`, and iOS app manifest `b9619e1d…`.
- The executed helper SHA-256 is `e5ece28eed78f72feb2e0ec7ef0e2da83bfc5b13dda56aeb788360ac907d13b8`, matching the independently approved round-5 helper. The command uses isolated runner home, literal session `fix4-8-c3`, and an unset API environment.
- Live identity binds owned `smoke4-c3-ios` at `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E` on iOS 26.0 and owned `smoke4-c3-android` at `emulator-5580` on Android API 35. Neither protected owner simulator nor `Pixel_8_API_35` is a target.

## Startup and readiness

- Startup interruption observes genuine `starting` and exact authenticated runner PIDs `71858` on iOS and `71869` on Android. Both commands exit 130 with their exact platform SIGINT notices. Generated flows are retained, and the startup-only optional terminal policy truthfully records whether the temporary source report remained available.
- Detached starts first expose `already_running` with a null port for the same PIDs, then publish ready sessions: iOS PID `71967`, port `8274`; Android PID `73151`, port `60759`. Both immediate hierarchies contain Landmarks.
- The four detached/ready retained reports contain `report.json` with overall and flow status `passed`. This includes the two ready-interrupt reports and proves completed launch before cleanup even where the detached source report directory had already disappeared at terminal capture.
- Normal JSON stops identify the exact PIDs, platforms, device identities, and ports and return `status: stopped`. Android's post-stop forward inventory is empty.
- Ready-state foreground interruption authenticates exact runner PIDs `73585` and `74745`, retains complete passed reports plus generated flows, observes Landmarks hierarchies, and exits 130 with exactly one correct platform notice per command.
- Final acceptance is written only after the helper's exact PID-gone and project/global session-cleanup assertions complete for each lifecycle ending. `owned-resources.json` preserves the exact executable argv, device, phase, and PID bindings used by those guards.

## Absent application, logs, and cycles

- iOS targeted uninstall succeeds; both container probes return absent, canonical no-app launch refuses with exit 1, and restoration from the frozen app succeeds. Android's missing application fails promptly with exit 1, creates no persistent session, and leaves an empty forward inventory.
- Log cleanup covers success, failure, and interruption with exits 0, 1, and 130. Success and failure retain reports with statuses `passed` and `failed`. The interrupted case retains the authenticated CLI/runner relationship, exact runner executable hash, report and semantically equivalent flow binding, and exit 130.
- Each log case records one exact owned child marker/PID, one terminal `simctl ... log stream` diagnostic, and three subsequent process inventories with the marker absent. No case emits the helper's unconfirmed-cleanup diagnostic.
- Screens, root, and absolute cycle cases each exit 1 in 1.67–1.72 seconds, well inside the five-second bound. Their stderr contains the exact canonical dependency chain recorded in acceptance.

## Attempt isolation and remaining work

The two earlier candidate-3 lifecycle attempts remain immutable harness false failures and supply no result to this verdict. Attempt 3 is a fresh output root with its own invocation, reports, PIDs, flows, and acceptance; nothing here is graded from those attempts.

The accepted phase intentionally excludes `force-teardown`. The controller must still run the separately isolated force phase and later perform and review exact physical cleanup before it can close Task 8.

This was a read-only review of retained evidence. I did not rerun the helper or tests, invoke the CLI/runner, build anything, edit source/helpers, or perform a device operation.
