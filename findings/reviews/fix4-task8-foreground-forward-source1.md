# Task 8 foreground attachment independent review

Reviewed head `5d8cd234ab88c240a43a4c527a635306dd668f42` against `fb7af9d1702cd4f294aae48eb5f1ed52dbfe2d88`, the binding L82 brief, implementation report, full basediff, production lifecycle/SignalRelay/Android detach implementation, and preserved test evidence. No tests rerun; no devices or product edits.

## Verdict

**Changes requested.** Ready-state ownership and cleanup are correctly addressed, but the successful attachment handoff still loses ownership when interruption crosses startup completion. This is a concrete race within the requested foreground attachment lifecycle. L83 runner cleanup remains independent and is outside this review.

## Finding: P1 — retain acquired attachment before termination can consume cleanup

Locations: `Sources/GrantivaCLI/DriverCommand.swift:720–747`, `Sources/GrantivaCLI/RunnerOutputForwarder.swift:38–49`.

The startup cleanup is registered at line 697 before awaiting readiness. On return, line 721 checks `isTerminating` before the successful attachment is transferred to the holder at line 747. If SIGINT arrives after the successful discovery but before this check, `wait.attachment` is nonnil, yet the terminating branch runs cleanup against an empty holder and throws 130 without calling that attachment's detach. The exact CLI-owned forward survives.

There is also a handoff interleaving after the check: startup reads `isTerminating == false`; the signal queue reaps the child and executes the registered Once while the holder is empty; the startup task then retains the attachment. `release()` has no terminal/released state, so the late retain succeeds, and the Once body has already been consumed. No subsequent cleanup releases it. Locks prevent data races on the optional but do not establish lifecycle ownership. SignalRelay can exit immediately after its callbacks, so merely asynchronously disposing of a late retain would also need coordination with that exit boundary.

Fix the successful discovery-to-owner handoff and termination rejection together, with bounded synchronous termination cleanup waiting for any acquired attachment it is responsible for. Add deterministic production-seam coverage for termination with an acquired result and cleanup-before-transfer, including detach completion before the termination callback returns. Do not broaden this into unrelated runner or device cleanup.

This race was not introduced as a new Android failure mode by this patch; the baseline discarded every successful attachment. It is an unclosed case in the stated lifecycle/cancellation acceptance claim, now exposed by the new ownership boundary.

## Positive quality findings

Once the attachment has transferred, the outer `Once` holds its lock throughout synchronous release, so competing normal-exit and SignalRelay cleanup callers wait for the same detach rather than letting the relay exit early. The holder clears its optional under lock before invoking detach; the detached task avoids holding that lock during platform work. The bounded 15-second wait is consistent with the existing synchronous cleanup architecture, though it is a bound, not proof that a hung ADB cleanup completed.

Only the retained attachment callback is used. AndroidPlatform's callback removes exactly its allocated local TCP port when it created the forward. No global-forward removal was added. Detached startup still publishes the same port, iOS takes the unchanged readiness branch and the empty holder is harmless, and flags, JSON, notices, and exit formatting are unchanged. The production change is small and its source scope is appropriate.

## Evidence assessment

All entries in `findings/evidence/fix4-4-forward/checksums.txt` verified. `final-source.diff` byte-for-byte matches the actual base-to-head git diff. The GREEN source matches that final diff.

The instrumented RED is candidly described and is a valid semantic fault-injection/baseline-compatible ownership comparison, not a claim that an unmodified baseline could compile a new holder type. RED and GREEN differ semantically only in `owner.retain(attachment)`. RED compiled and failed four detach-count assertions across normal and interrupted cases; GREEN passed. The test invokes the actual production transfer method and `holdForeground`, rather than a standalone imitation. It meaningfully catches discarded successful ownership, but it retains before registering the interrupt callback and therefore cannot cover the startup race above. Its unrelated callback assertion is limited; actual exact-port safety is additionally established by inspecting the production detach closure and existing Android tests.

The governing full transcript reports MCP 281, Core 971, CLI 663, API 101: **2,016 tests, zero failures**. Full command/result metadata records the separate final2 runner home, API unset, literal session `fix4-4-forward`, timestamps, exit 0, and empty final inventory. Focused metadata/transcript records 70 passing tests, but that focused run predates the final seam revision; the final full run includes the final regression test.

Evidence provenance limitations: `full-swift/command.json` still names `source.diff`, the earlier source, rather than `final-source.diff`; correct that pointer. Semantic RED/GREEN folders contain source diff and terminal output only, with no per-run argv/environment/home/exit manifests, so their fresh-home/API-unset/session claims are reported rather than independently established by those artifacts. Terminal timestamps establish when tests ran; combined PTY output is honestly identified. These documentation gaps do not negate the observed semantic failures or the final passing counts, but they should be reconciled from existing execution records without rerunning passed tests just to recreate evidence.

## Remaining gates

Resolve the startup ownership finding and review its deterministic regression. Controller then owns the L82 live acceptance: empty baseline, ready attachment identity/port, exact SIGINT exit130 and notice, immediate and delayed absence of the owned forward, absent project/global session and runner PID; normal foreground stop; absent-app control; and preservation of an unrelated forward. CI, merge authorization, and rebuilt-candidate verification remain required. Passing unit evidence alone does not mark Task8/Task9 clean, and this review does not grant merge or release approval.
