# cov5 Android coverage results

Candidate manifest SHA-256: `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`

| ID | Result | Evidence | Note |
|---|---|---|---|
| AND-001 | pass | `findings/evidence/cov5-android/AND-001/` | Created missing `cov5-android`, booted it as `emulator-5554`, and printed only that serial. |
| AND-002 | blocked | `findings/evidence/cov5-android/AND-002/` | No suitable small uninstalled image is available; the delegation forbids downloading one. |
| AND-003 | pass | `findings/evidence/cov5-android/AND-003/` | Reused `cov5-android` with the same `emulator-5554` serial. |
| AND-004 | pass | `findings/evidence/cov5-android/AND-004/` | Created distinct `cov5-android-2` with `--no-boot`; stdout was its name and adb showed it remained stopped. |
| AND-005 | pass | `findings/evidence/cov5-android/AND-005/` | Booted the configured secondary as `emulator-5556`; PID 59061 argv contains `-no-window`. |
| AND-006 | pass | `findings/evidence/cov5-android/AND-006/` | No-name ensure selected configured `cov5-android-2` and returned `emulator-5556`. |
| AND-007 | pass | `findings/evidence/cov5-android/AND-007/` | No-image-override creation retained Android 35 Google APIs arm64-v8a and pixel_8 configuration. |
| AND-008 | pass | `findings/evidence/cov5-android/AND-008/` | Ensure JSON decoded and reported the reused, booted secondary. |
| AND-009 | pass | `findings/evidence/cov5-android/AND-009/` | Sessions JSON decoded and listed both live campaign-owned emulators with exact serials and PIDs. |

Initial group total: **8 pass, 1 blocked, 0 fail, 0 n/a**.

AND-002 basis clarification: the retained inventory establishes that only the Android 35 Google APIs arm64 image is installed. The row remains blocked under the carried environment constraint and explicit no-SDK-download delegation; this evidence does not make a claim about the size or availability of remote images.

| ID | Result | Evidence | Note |
|---|---|---|---|
| AND-010 | pass | `findings/evidence/cov5-android/AND-010/` | Authenticated and targeted the owned secondary; forwards and its started record were removed and PID 59061 was killed. |
| AND-011 | pass | `findings/evidence/cov5-android/AND-011/` | Stable manual PID 68606 was refused without force, survived refusal, and was killed with targeted force. The transient fixed-port first launch remains preserved. |
| AND-012 | blocked | `findings/evidence/cov5-android/AND-012/` | Global teardown is forbidden; `--all` was not executed. |
| AND-013 | pass | `findings/evidence/cov5-android/AND-013/` | Sessions pruned the exact dead-PID fixture; teardown refused the manual replacement without force. |
| AND-014 | pass | `findings/evidence/cov5-android/AND-014/` | Deleted the stopped Grantiva-created secondary and pruned its ownership entry. |
| AND-015 | pass | `findings/evidence/cov5-android/AND-015/` | Refused a manually created AVD without force, retained it, then deleted it with force. |
| AND-016 | pass | `findings/evidence/cov5-android/AND-016/` | Refused forced deletion of running manual PID 70249 and retained both process and AVD. |
| AND-017 | pass | `findings/evidence/cov5-android/AND-017/` | Five-second cold boot failed clearly after about 5.41 seconds; exact timeout process was then authenticated and cleaned up. |
| AND-018 | pass | `findings/evidence/cov5-android/AND-018/` | External PID 71427 was reused but never adopted; frozen-APK flow passed and the emulator survived run cleanup. |

Quiet lifecycle group total: **8 pass, 1 blocked, 0 fail, 0 n/a**.

AND-010 review qualification: the first capture proves targeted emulator kill, serial/ledger cleanup, and an empty post-teardown forward inventory, but its pre-teardown forward inventory was also empty and it did not establish a live UIAutomator2 server. The server-stop and actual-forward-removal clauses require the prepared narrow supplemental capture in `AND-010/supplemental-readiness.md`; the original raw result and verdict remain preserved.

The authorized AND-010 supplemental capture is complete and upgrades that qualification: a live UIAutomator2 process and two exact emulator-5556 forwards existed before targeted teardown; teardown stopped runner PID 88721, killed owned emulator PID 88587, removed both forwards, pruned the started ledger, and removed `.grantiva/session.json`. Invalid `runner sessions` attempts remain preserved and excluded; the supported ledger proof uses `emulator sessions --json`.

| ID | Result | Evidence | Note |
|---|---|---|---|
| AND-106 | pass | `findings/evidence/cov5-android/AND-106/` | Adjacent grading rerun passed all 12 stock flows after authorized frozen-APK fixture setup. |
| AND-107 | pass | `findings/evidence/cov5-android/AND-107/` | Required launch crash produced `app_crash`, exact runtime exception, failure report and screenshot. |
| AND-108 | pass | `findings/evidence/cov5-android/AND-108/` | Captured all five configured screens, including Lakes and Detail; artifacts and hashes retained. |
| AND-109 | pass | `findings/evidence/cov5-android/AND-109/` | Next product sessions call pruned the manually deleted secondary from the created ledger. |
| AND-146 | pass | `findings/evidence/cov5-android/AND-146/` | JSON deletion named the stopped Grantiva-created secondary and physical inventory proved absence. |
| AND-110 | blocked | `findings/evidence/cov5-android/AND-110/` | Non-global examples passed; required global `--all` leg remained blocked, making the whole key partial. |
| AND-019 | pass | `findings/evidence/cov5-android/AND-019/` | Default freeDebug build passed. |
| AND-020 | pass | `findings/evidence/cov5-android/AND-020/` | Build, boot, install, and launch passed. |
| AND-021 | pass | `findings/evidence/cov5-android/AND-021/` | JSON no-launch install plus stopped-before/not-running-after control passed. |
| AND-022 | pass | `findings/evidence/cov5-android/AND-022/` | freeRelease build and actual signing status retained. |
| AND-023 | pass | `findings/evidence/cov5-android/AND-023/` | paidDebug build passed. |
| AND-024 | pass | `findings/evidence/cov5-android/AND-024/` | Invalid variant text and JSON diagnostics passed. |
| AND-025 | pass | `findings/evidence/cov5-android/AND-025/` | Valid and invalid module selection passed. |
| AND-111 | pass | `findings/evidence/cov5-android/AND-111/` | Compile-only build did not boot or install. |
| AND-112 | pass | `findings/evidence/cov5-android/AND-112/` | Explicit unattached device failed without boot. |
| AND-113 | pass | `findings/evidence/cov5-android/AND-113/` | Default install booted, installed, and launched. |
| AND-143 | pass | `findings/evidence/cov5-android/AND-143/` | Headless install used `-no-window`. |
| AND-144 | pass | `findings/evidence/cov5-android/AND-144/` | Distinguishable dual-config fixture selected Android. |
| AND-026 | pass | `findings/evidence/cov5-android/AND-026/` | APK metadata overrode mismatching config ID with warning. |
| AND-027 | pass | `findings/evidence/cov5-android/AND-027/` | CLI application-ID override and expected absent-target failure passed. |
| AND-028 | pass | `findings/evidence/cov5-android/AND-028/` | Explicit app-file run passed. |
| AND-029 | pass | `findings/evidence/cov5-android/AND-029/` | Named stopped AVD boot and run passed. |
| AND-030 | pass | `findings/evidence/cov5-android/AND-030/` | Exact serial targeting passed. |
| AND-031 | pass | `findings/evidence/cov5-android/AND-031/` | Empty work failed before boot/build and wrote failed ready state. |
| AND-032 | pass | `findings/evidence/cov5-android/AND-032/` | Headless run booted with `-no-window`. |
| AND-033 | pass | `findings/evidence/cov5-android/AND-033/` | Invalid ready parent failed before boot/build. |
| AND-034 | pass | `findings/evidence/cov5-android/AND-034/` | Stale-before and terminal rewrite are direct; startup deletion is source-backed. |
| AND-035 | pass | `findings/evidence/cov5-android/AND-035/` | Spaced equals environment value reached UI and logcat extras. |
| AND-036 | pass | `findings/evidence/cov5-android/AND-036/` | No-emulator config selected the only running emulator. |
| AND-037 | pass | `findings/evidence/cov5-android/AND-037/` | Single note environment value reached UI. |
| AND-038 | pass | `findings/evidence/cov5-android/AND-038/` | Both repeated environment values reached the app. |
| AND-039 | pass | `findings/evidence/cov5-android/AND-039/` | CLI and header empty-seed forms passed. |
| AND-040 | pass | `findings/evidence/cov5-android/AND-040/` | Crash, failure screenshot, and failed ready record passed. |
| AND-041 | pass | `findings/evidence/cov5-android/AND-041/` | Exact flow-12 evidence joins the stock capture. |
| AND-042 | pass | `findings/evidence/cov5-android/AND-042/` | Exact configured 12-flow evidence joins AND-106. |
| AND-043 | pass | `findings/evidence/cov5-android/AND-043/` | Twelve distinct selected-flow invocations passed. |
| AND-044 | pass | `findings/evidence/cov5-android/AND-044/` | Unicode-arrow tap passed. |
| AND-045 | pass | `findings/evidence/cov5-android/AND-045/` | Installed-APK no-build run passed. |
| AND-046 | pass | `findings/evidence/cov5-android/AND-046/` | Continue-on-failure ran later flow and remained nonzero. |
| AND-047 | pass | `findings/evidence/cov5-android/AND-047/` | Failure, trailing, and full snapshot policies retained distinct artifacts. |
| AND-048 | pass | `findings/evidence/cov5-android/AND-048/` | Explicit report contents and unchanged capture manifest passed. |
| AND-049 | pass | `findings/evidence/cov5-android/AND-049/` | Thirty-second timeout, failed ready state, and exact kill message passed. |
| AND-050 | pass | `findings/evidence/cov5-android/AND-050/` | Passing and failing stdout are JSON-only documents. |

Core window total: **43 pass, 1 blocked, 0 fail, 0 n/a**. Initial fixture mistakes and unsupported-option attempts remain adjacent to the grading reruns and are excluded explicitly in the row verdicts.
