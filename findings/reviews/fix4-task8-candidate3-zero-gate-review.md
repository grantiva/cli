# Task 8 candidate 3 aggregate zero-gate review

**Specification verdict: APPROVED. Task 8 candidate 3 bounded smoke passes its zero-failed-acceptance gate.** All required phases have fresh candidate-3 passing evidence and independent phase approval; final physical cleanup is independently approved below. No unaddressed demonstrated product finding or failed acceptance remains in this candidate's Task 8 smoke.

**Evidence-quality verdict: APPROVED.** Frozen identity, phase provenance, raw results, attempt separation, physical cleanup and protected inventories agree. The preserved force warning, earlier helper failures, source-live timeout and stale descriptive label are qualified explicitly below; none supplies a substituted pass or changes an acceptance predicate.

This permits progression to Task 9. It does not claim Task 9 execution, a complete coverage pass, `ROUND 4: CLEAN`, campaign exit, or release/tag approval.

## Governing scope and identity

Reviewed Task 8 of `docs/superpowers/plans/2026-10-13-round4-fix-wave.md`, the full-coverage campaign design, candidate report, frozen manifest, individual candidate-3 phase reviews, helper-correction reviews, phase invocation/acceptance records and final cleanup controller/raw artifacts. Existing detailed phase reviews provide the semantic report/transport assessments; this aggregate review checks their coverage and provenance together and independently assesses cleanup.

Recomputed `candidate.json` SHA-256 is `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`. The QA binary still hashes to `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`. Identity is CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, runner `ba9008f4b2cd2c7320a9c46e04faed612b0958a2` / `1.1.28-grantiva.15` / installed and packaged hash `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`, and demo `84af7581b75134b0e417b254e4317d565f7b73c6`.

Each of the six device-phase invocation results explicitly records this candidate hash, exit 0, session `fix4-8-c3`, the candidate's isolated cloned runner home and an unset API environment. The freeze review proves the fresh merged build/promotion, fresh demo artifacts, APFS clone of 8,593 entries, preservation of 8,069 cache entries, and all 800 files in the four regenerated WDA configurations. Unit-test empty homes remain distinct.

## Complete Task 8 coverage

| Requirement | Accepted fresh evidence under `findings/evidence/round4-smoke-candidate3/` | Independent review |
|---|---|---|
| Build, upgrade, immutable identity | `01-candidate`, `build-inputs`, `candidate.json` | `fix4-task8-candidate3-freeze-review.md` |
| Docs, doctor text/JSON, public migration notes, regenerated help | `06-docs-output`: 172 pages, 16 tests, zero failures | `fix4-task8-candidate3-docs-review.md` |
| Owned device provisioning and baseline | `provision` | `fix4-task8-candidate3-provision-review.md` |
| Android healthy/crash/gesture/favorite/stopApp/optional-required/cycle smoke | `02-runner-android`: five crash and five favorite repetitions, all four gesture forms and result surfaces | `fix4-task8-candidate3-android-runner-review.md` |
| Startup/ready interruption, detached readiness, absent app, log cleanup, cycle controls | `03-lifecycle-attempt3`: all 13 non-force checks | `fix4-task8-candidate3-lifecycle-review.md` |
| Forward ownership regression | `03b-joint-forward`: four endings, unrelated controls preserved | `fix4-task8-candidate3-joint-forward-review.md` |
| iOS MCP errors, full selector family including L85 and Cancel, transport/retry | `04-mcp-ios`: ten pairs, 20 designated large replies, ten small replies and ten notifications | `fix4-task8-candidate3-mcp-ios-review.md` |
| Android MCP errors and transport | `05-mcp-android`: same required transport counts | `fix4-task8-candidate3-mcp-android-review.md` |
| Force teardown JSON and terminal process/session/lease behavior | `07-final-force-teardown-attempt2` | `fix4-task8-candidate3-force-review.md` |
| Physical removal and protected baseline | `08-final-cleanup` | This review |

Review filenames in the last column are under `findings/reviews/`. No candidate-1/candidate-2 result populates this gate. The demo checkout's directory name contains `candidate2`, but its candidate-3 fresh build records and frozen artifact hashes establish the actual input identity. Similarly, joint-forward acceptance retains the stale prose scope `Final packaged candidate 2 joint forward cleanup`; its fresh invocation, manifest hash, devices, process identities and raw records establish candidate 3. The raw label must remain unchanged and must not be presented as a reused grade.

## Independent physical-cleanup assessment

`08-final-cleanup/acceptance.json` passes with no failures. The raw command records support all four mutations: exact iOS shutdown/delete of `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E`, exact `emulator-5580` stop, and deletion of AVD `smoke4-c3-android`, each exit 0. Before mutation, retained ownership and live identity bind iOS name/runtime, Android serial/AVD, and emulator PID 61153 with its exact `-avd` and `-port 5580` arguments. No protected target is a mutation argument.

Before cleanup the only marked processes are the owned emulator and two simulator-managed processes; unknown marked processes and project/global sessions are empty. No leftover runner requires extra product-cleanup rescue. After cleanup, raw simulator inventory excludes the owned UUID; ADB lists no attached devices; AVD enumeration contains only `Pixel_8_API_35`. The final forward table is byte-identical to the empty provisioning baseline. Final process inventory contains no candidate marker or emulator PID; independently cross-checking all 30 PID keys across the five retained lifecycle/force ownership records finds none present. Additional recorded MCP/joint-forward runner PIDs are also absent.

The controller verifies no project/global session or exact owned-device lease remains. These are explicit post-cleanup checks, not an inference from successful force JSON. Final protected simulator records match provisioning after excluding only dynamic `dataPathSize`/`logPathSize`: `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C` and `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6` retain their identities and Booted states. Independently recomputed protected Pixel configuration hash is unchanged at `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`.

## Preserved qualifications and attempt isolation

The two earlier lifecycle failures retain their original `failure.json` and streams. Independent correction review identifies report-copy/source-lifetime requirements in the helper, not failed product acceptance. Only the complete fresh attempt 3 is graded. The original final-force helper failed copying a disappearing detached report before force; it remains failed and contributes no force acceptance. The reviewed foreground fixture supplies the fresh attempt-2 result without relaxing required report completion or force cleanup.

Fresh force stderr warns that holder PID 79528 did not exit by the teardown deadline. Preserve that warning. The command nevertheless returns 0 with exact-target `runnerSessionStopped: true` and `reclaimed: true`; foreground CLI returns 0 with the exact teardown notice; runner PID 79556, CLI PID 79528, session and lease are absent without fallback cleanup. A deferred parent wait and `kill(pid, 0)` can explain an unreaped child warning, but no contemporaneous process-state sample proves that explanation. Approval rests on the observed required terminal predicates, not a claimed diagnosis or empty stderr.

The initial source-live iOS 26 Cancel hierarchy timeout under `findings/evidence/fix4-85` remains unreproduced and unregraded; its cause is not proven fixed by this review. Candidate 3 freshly completes Cancel and the whole iOS selector/MCP phase. The earlier observation is retained for subsequent coverage and any recurrence must be triaged. It is not silently converted into a pass, nor is it an observed failed acceptance of this frozen candidate's completed smoke. Candidates 1 and 2 remain failed.

No live helper, device command, process query, test, build, or network action was executed for this review. Only retained files were read and this review document was written.
