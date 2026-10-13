# Task 4 live correction, round 2

Commit: `ed2e10e61014f8bbc3905986e63c7255de843461`, parent `9c7748523e703338887124a52a0a3af6d40a884b`. No push. Source review and remaining live controls pending.

The first actual Android acceptance run reached a new UIAutomator2 session and passed the generated launchApp + waitForAnimationToEnd flow, yet timed out after 90 seconds. Its retained daemon log proves the runner wrote `report/2026-10-13_06-43-16/report.json`; the CLI polls `report/report.json`. The existing normal flow path already uses `--flatten`. DriverCommand now adds that same option beside its explicit startup-report directory, before the positional flow argument. iOS has no startup report argument and is unaffected.

Evidence: `findings/evidence/fix4-4/live/android-lifecycle-attempt1/` (actual failure, starting PID18412, explicit null-port control passed, daemon log retained); `live/unit-fix2/` (production argv regression RED exit1 before source fix, then all 63 RunnerLifecycleCommandTests GREEN). Every test invocation had a new empty runner home, both home variables scoped, API key unset; home remained empty. `git diff --check` passed. Full-suite qualification is unchanged: earlier 1,976-test pass predates final fixes; final-tree CI/full suite remains pending.

Android replay will retain the exact report path, generated flow and passed report before the CLI removes its temporary startup directory. No iOS devices have been created. Android emulator fix4-4-android/emulator-5580/PID18081 remains reserved and scoped to `/private/tmp/grantiva-fix4-4.b2UyuL/runner-home`, session fix4-4.
