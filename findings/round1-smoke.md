# Round 1 smoke after the fix wave (2026-10-10)

Binary: `~/.grantiva-qa/bin/grantiva` 2.1.0 (main 51c597a), bundling grantiva-runner 1.1.28-grantiva.9
(`versions/1.1.28-grantiva.9+android-drivers-2` in `~/.grantiva-qa/runner`). Demo: landmarks-demo 00fdc21, copied to scratch.
Devices: AVD `smoke-android` (emulator-5554, API 35); simulator `smoke-ios` (E1B88A86-3CD0-44AB-AB76-EDAB7AF964C0, iPhone 17, iOS 26.0).
Both torn down at the end. Commands: `evidence/round1-smoke/commands.txt`.

| Check | Result | Evidence | Note |
|---|---|---|---|
| A1 Android full run | pass | evidence/round1-smoke/A1-run.txt | Flows 12/12 (90/90 steps, 1m 2s); screens 19/19 (5 config screens + 14 flow shots). No ⚠ step. 03-edit: `inputText " Renamed"` appended (assert "Golden Gate Bridge Renamed" passed, capture shows the renamed label); toolbar `tapOn "Done"` ✓ 184ms. |
| A2 swipe reveals row action | pass | A2-run.txt, A2-md5.txt, A2-cmd-008-before.png, A2-cmd-008-after.png | cmd-008 before `81a56e5b…` ≠ after `85b177d9…`; the after capture shows the "Remove" action. Flow 13/13. |
| A3 99-crash x3 | pass | A3-crash-1.txt, A3-crash-2.txt, A3-crash-3.txt | Run 1: ✗ launchApp 1.6s (crashed on launch). Run 2: ✓ launchApp 1.8s, ✗ assertVisible "Landmarks" 318ms (crashed after launch). Run 3: ✗ launchApp 1.6s. All carry `java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH`. Flow 2.4-2.6s; wall clock 5.0-5.4s for the whole command. |
| A4 `exact:` on Android | pass | A4-diff-capture.txt, A4-config.diff | Scratch config adds `{text: …, exact: true}` to Lakes/Detail paths. Captured 5 screens incl. Lakes (67.6 KB) and Detail (87.2 KB); steps print `exact=true`; no `"exact" is not supported on android` line. |
| A5 build with emulator stopped | pass | A-teardown.txt, A5-build-paid.txt | `build build --variant paidDebug` built in 2.9s; `adb devices` empty before, right after and again at 22:23:00; no emulator/qemu process. AVD then deleted. |
| I1 iOS full run, cached agent | pass | I1-run.txt | Flows 12/12 (90/90, 1m 49s); screens 19/19. Cache hit printed for both phases; no xcodebuild of the agent. |
| I2 iOS 03-edit | pass | I1-run.txt (line 158) | Unchanged: inputText 1.1s, Done 1.1s, assert "Golden Gate Bridge Renamed" ✓. |
| I3 simulator teardown removes device dir | pass | I3-teardown.txt | Before: `devices/E1B88A86-…` present; after: none (count 0). "Deleted Grantiva-created smoke-ios … and released session round1-smoke." |
| End state | pass | I3-teardown.txt | `xcrun simctl list devices \| grep -c smoke-` = 0; `adb devices` empty. |

Cache-hit line (I1, printed twice: screens phase and flows phase):

```
  ⏳ Building GrantivaAgent...
  ✓ Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8-r1)
  ✓ GrantivaAgent built
```

Timings (wall clock, `time`): emulator ensure 16.6s; Android build install 10.1s; A1 run 1:21; A2 11.8s; A3 5.4s / 5.0s / 5.4s;
A4 diff capture 10.7s; A5 paidDebug build 2.9s; simulator ensure 21.7s; iOS build install 13.3s; I1 run 2:16.

## Observations (not failures)

- Android `run` prints `Running 12 flow(s) in one GrantivaAgent session` (A1-run.txt line 104). GrantivaAgent is the iOS agent; on Android this should name the UIAutomator2 session or be platform-neutral.
- Android `run` first prints `Running 13 flow(s)...` (12 flows + the screens flow) and then `Running 12 flow(s)`; the 13 is the internal count.
- A3 step durations differ between the live line and the summary block of the same run (run 1: launchApp 1.6s live vs 2.6s summary; run 2: assertVisible 318ms vs 574ms). Cosmetic.
- iOS still prints `⏳ Building GrantivaAgent...` / `✓ GrantivaAgent built` around the cache-hit line, which reads like a build even though none happens.
- A3 run 2 crashed after launchApp had already passed (race between process start and the crash); it still failed on the next step with the crash message in 318ms, so the early-fail path works for both cases.
