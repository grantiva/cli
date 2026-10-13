# Task 4 live correction, round 4

Commit `60ccdf13a74e4ab6bb7966cc2af067ec13ddfb10`; parent fbaf0f25. Live evidence exposed a separate cleanup race, not an unresolved prior review item. Source review and further live controls pending.

In `live/ios-startup-attempt1`, plain startup SIGINT exited130 cleanly, but quiet SIGINT left its starting session naming already-dead runner27895. Both foreground startup and SignalRelay invoke the same production Once. Once cleared its body before running it unlocked, so the other caller could return and exit the process while cleanup was still in progress.

Once now holds its lock through the bounded file/lease cleanup. Every concurrent caller returns after completion. The body must not re-enter the same Once; existing call sites do not do so (the foreground-hold wrapper may call the separate startup Once). No work acquires these Once locks in reverse order. The deterministic concurrency RED held the first cleanup at a semaphore and observed the second return prematurely; GREEN requires it remain waiting until release. All64 RunnerLifecycleCommandTests passed with empty fresh scoped home, API key unset. Evidence `live/unit-fix4`, git diff --check passed.

Repeating plain/quiet/JSON startup twice each, then genuine timeout and unexpected-death controls. Final-tree full suite/CI remains pending.
