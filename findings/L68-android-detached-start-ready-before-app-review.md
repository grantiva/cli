# L68 Android detached-start readiness review

**Verdict: approve with one wording clarification.** The finding is supported by the isolated current-candidate evidence and the source ordering. It does not rely on iOS/Android overlap, a malformed fixture, or a permanent launch failure.

The isolated capture is decisive: detached start returned a session recorded as `ready`; the hierarchy begun about 37 ms later contained only System UI; the next poll, begun about 1.18 s after return, contained Landmarks; and the same daemon subsequently logged the intended `launchApp` plus animation wait. Candidate `DriverCommand.swift` waits for a fresh UIAutomator2 attachment and then records ready, while the generated flow executes asynchronously. That is the exact driver-ready/app-not-ready gap described in L68.

The acceptance criteria are appropriately condition-based. They require the immediate documented operation to see the app and use bounded polling only for diagnosis. They do not turn the observed ~1.18 s into a fixed sleep or threshold. Preserving launch-failure, timeout, stale-session, and cancellation behavior keeps the proposed fix narrow.

Clarify the first Expected paragraph to attribute the immediate-Landmarks requirement to matrix row AND-127's binding example. Candidate `runner start --help` itself promises return “once the driver is up,” and `docs/android.md` lines 138–147 describe hierarchy through a held UIAutomator2 session but do not independently promise app foreground readiness after detached start. The matrix still makes the observed behavior a valid campaign contract failure; this edit would avoid overstating the prose documentation.

The draft correctly keeps the process-wide `session-flow.yaml` question separate. The isolated run executed the correct generated flow and reproduced the gap, so concurrency contamination is unsupported as the cause of L68.
