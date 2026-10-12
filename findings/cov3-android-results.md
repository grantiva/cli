# Round 3 Android coverage results

QA CLI hash `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`; runner `1.1.28-grantiva.13+android-drivers-2`; session `cov3-android`; campaign-created AVD `cov3-android` at `emulator-5554`.

| ID | result | evidence | note |
|---|---|---|---|
| AND-001 | pass | findings/evidence/cov3-android/AND-001/ | CLI created and booted the missing AVD as emulator-5554; software-rendered API 35 configuration and ownership ledgers captured. |
| AND-019 | pass | findings/evidence/cov3-android/AND-019/ | Default build ran assembleFreeDebug and produced the expected APK. |
| AND-020 | pass | findings/evidence/cov3-android/AND-020/ | Default install built, installed, launched, and left the expected app process running. |
| AND-042 | pass | findings/evidence/cov3-android/AND-042/ | Configured flow set passed 12/12. |
| AND-090 | pass | findings/evidence/cov3-android/AND-090/ | Required Android doctor checks passed; optional inventory named the owner AVD without touching it. |
| AND-091 | pass | findings/evidence/cov3-android/AND-091/ | With ANDROID_HOME unset, SDK fallback succeeded. |
| AND-092 | pass | findings/evidence/cov3-android/AND-092/ | Invalid JAVA_HOME produced valid JSON with a JDK error and fix line, exit 1. |
| AND-106 | pass | findings/evidence/cov3-android/AND-106/ | Five screens captured and all 12 stock flows passed (90/90 steps). |
| AND-107 | pass | findings/evidence/cov3-android/AND-107/ | Five crash runs all failed with app_crash at launchApp or the first assertion; FATAL-to-failure 0.6-1.9 s. |
| B3-L57 | fail | findings/evidence/cov3-android/B3-L57/ | Runs 1 and 2 allowed launchApp to pass after FATAL due to a stale pre-crash process read; failure followed at the first assertion. |
| B3-L61 | pass | findings/evidence/cov3-android/B3-L61/ | Failure captures appeared 2.8-9.0 s after step failure, matching the documented current behavior. |
| B-R01.3 | pass | findings/evidence/cov3-android/B-R01.3/ | Android stock and crash acceptance covered by AND-106/107. |
| B-R02.6 | pass | findings/evidence/cov3-android/B-R02.6/ | Android stock flow half passed 12/12 with the .13 runner. |
| N-15 | pass | findings/evidence/cov3-android/N-15/ | Stock run used one UIAutomator2 session and emitted no GrantivaAgent marker. |
| N-16 | pass | findings/evidence/cov3-android/N-16/ | Narration correctly reported five screens followed by 12 flows. |

## Counts

15 of 467 slice rows recorded: 14 pass, 1 fail, 0 blocked, 0 n/a.
