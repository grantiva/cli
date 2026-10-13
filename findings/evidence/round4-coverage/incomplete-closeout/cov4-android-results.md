# Round 4 Android coverage results

AND-001 | fail (evidence-collection gap) | `findings/evidence/cov4-android/AND-001/` | Product output and live ownership show absent-name creation and boot as `emulator-5554`, but the wrapper failed after product completion before recording the product exit and end timestamp; first verdict preserved, requiring a later controller-targeted new-generation adjacent attempt.
AND-002 | blocked missing-image environment rule; no SDK download authorized | `findings/evidence/cov4-android/AND-002/` | Controller-carried block; no product command or image download executed.
AND-003 | pass | `findings/evidence/cov4-android/AND-003/` | Repeated ensure reused generation-2 `cov4-android` and returned the same `emulator-5554` serial.
AND-004 | pass | `findings/evidence/cov4-android/AND-004/` | Fresh `cov4-android-2 --no-boot` creation printed the AVD name and left adb unchanged.
AND-005 | pass | `findings/evidence/cov4-android/AND-005/` | Config-selected extra AVD booted as `emulator-5556`; authenticated PID 14402 uses the headless QEMU executable and `-no-window`.
AND-006 | pass | `findings/evidence/cov4-android/AND-006/` | Ensure without `--name` read `emulator: cov4-android-2` and reused `emulator-5556`.
AND-007 | pass | `findings/evidence/cov4-android/AND-007/` | The fresh AND-004 creation command omitted `--system-image`; retained config proves the default API 35 Google APIs arm64-v8a image.
AND-008 | pass | `findings/evidence/cov4-android/AND-008/` | JSON parsed and reports `created:false`, `cov4-android-2`, `emulator-5556`, and `Booted`.
AND-009 | pass | `findings/evidence/cov4-android/AND-009/` | Sessions JSON parsed and lists both Grantiva-started generation-2 primary and reserved extra with live PID, serial, adb state, and start time.
AND-010 | pass | `findings/evidence/cov4-android/AND-010/` | Exact targeted teardown stopped the owned UIAutomator2 runner session, removed both serial-specific forwards, and killed the extra emulator.
AND-011 | fail (evidence-fixture instability — triage) | `findings/evidence/cov4-android/AND-011/` | Non-force refusal passed, but the shell-backgrounded manual emulator was not proven alive immediately before the force call; the force call reported a no-op and the emulator was absent afterward, so the required force-kill behavior is not established.
AND-012 | blocked Global Constraint forbids `teardown --all` | `findings/evidence/cov4-android/AND-012/` | Forbidden global lifecycle command was not executed.
AND-013 | fail (evidence-fixture instability — triage) | `findings/evidence/cov4-android/AND-013/` | The dead-PID record was pruned, but the shell-backgrounded manual emulator was not proven stable immediately before teardown; output reported it already gone, so the required refusal against a live replacement process is not established.
AND-014 | pass | `findings/evidence/cov4-android/AND-014/` | Exact delete removed the stopped Grantiva-created extra AVD and its ownership entry.
AND-015 | pass | `findings/evidence/cov4-android/AND-015/` | A manually created extra AVD was refused without force and deleted with force; the initial Java-less fixture setup failure is preserved beside the successful setup rerun.
AND-016 | pass | `findings/evidence/cov4-android/AND-016/` | Forced deletion of the authenticated running extra AVD was refused with a clear teardown-first error; the AVD remained until targeted cleanup.
AND-017 | pass | `findings/evidence/cov4-android/AND-017/` | Cold boot with the literal 5-second timeout exited after about five seconds with a clear timeout error; the authenticated row-created process was then targeted for cleanup.
