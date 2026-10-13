# Task 8 foreground attachment scoped re-review

Review base: `5d8cd234ab88c240a43a4c527a635306dd668f42`.
Reviewed head: `015521cb75ff46b19aa66790300d6c85d2bd6e3b`.
Scope: prior P1 handoff race and new breakage within the scoped fix. Read the scoped diff, updated production code, appended implementation report, and preserved review-fix evidence. No test reruns, devices, product edits, or subagents.

## P1 — ADDRESSED

Successful Android discovery now transfers or rejects its attachment before the `isTerminating` branch can discard the result. This closes the prior acquired-result cancellation leak.

The holder now has explicit acquisition and release-requested state synchronized by an NSCondition. When transfer wins, it stores the attachment and ends acquisition under the same lock; release takes that attachment exactly once and synchronously waits for detach. When release wins, it marks release requested and waits while acquisition remains pending. The late transfer observes that state, detaches its attachment before ending acquisition, and returns rejection rather than retaining it after cleanup. The waiting release wakes only after that completion, subject to its existing timeout bound. The production outer Once continues to serialize concurrent normal-exit and signal callbacks until cleanup returns.

No-attachment results, the earlier recordStarting error path, and iOS explicitly finish acquisition, preventing those paths from unnecessarily waiting for an Android handoff. iOS retains its existing readiness behavior. Exact resource identity still comes from the owned attachment callback; there is no forward enumeration or global cleanup. The fix changes no flags, output documents, notice strings, or exit-code handling.

The two new tests exercise the actual holder's competing orderings and gate asynchronous detach, checking that synchronous cleanup does not return while detach is still blocked. The earlier normal/interrupted exactly-once lifecycle test remains present. This is sufficient focused evidence for the reviewed state transition, with production call-site inspection establishing the transfer-before-termination-check order.

The 15-second policy remains a bounded wait: acquisition or detach that exceeds the deadline can still outlast the signal callback. This review does not interpret the tests or report as guaranteeing cleanup completion after that deadline. That existing bounded-cleanup limitation is not an additional blocker for this scoped fix.

## Source verdict and evidence

**Source approved for this scoped fix. No remaining P1 or new blocking finding in the reviewed diff.**

Verified all four review-fix checksums and byte-for-byte equality of both scoped/full saved diffs with the corresponding actual git commit diffs. Focused transcript confirms 72 passing tests, including both new delayed-detach cases. Full transcript confirms MCP 281, Core 971, CLI 665, API 101: **2,018 tests, zero failures**. Command/result manifests name the correct source diffs, separate runner homes, literal session `fix4-4-forward`, API environment unset, combined PTY streams, times, exit 0, and empty final inventories.

Earlier semantic RED/GREEN per-run metadata remains unavailable and is now candidly qualified; this re-review does not retroactively claim it exists. The original semantic failure proof and the new passing evidence serve different purposes. No passed tests were rerun for review.

## Remaining live/integration gate

Source approval is not live acceptance or merge/release approval. Controller still owns L82 verification on the rebuilt candidate: ready attachment/port identity, SIGINT exit130 and exact notice, immediate/delayed absence of the owned forward, absent project/global session and runner PID; normal foreground stop; absent-app control; and an unrelated forward preserved. Current-head CI and the established integration/merge gates must pass. The reported prior unrelated SimulatorManager timing failure is not treated as passing CI, and L83 remains a separate runner change outside this CLI review.
