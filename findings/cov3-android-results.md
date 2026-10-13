# Round 3 Android coverage results

QA CLI hash `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`; runner `1.1.28-grantiva.13+android-drivers-2`; session `cov3-android`; campaign-created AVD `cov3-android` at `emulator-5554`.

| ID | result | evidence | note |
|---|---|---|---|
| AND-001 | pass | findings/evidence/cov3-android/AND-001/ | CLI created and booted the missing AVD as emulator-5554; software-rendered API 35 configuration and ownership ledgers captured. |
| AND-002 | blocked no suitable system image | findings/evidence/cov3-android/AND-002/ | Shared constraints state that installed alternatives exceed 1 GB; the row's rerun rule keeps it blocked unless the environment changes. |
| AND-019 | pass | findings/evidence/cov3-android/AND-019/ | Default build ran assembleFreeDebug and produced the expected APK. |
| AND-020 | pass | findings/evidence/cov3-android/AND-020/ | Default install built, installed, launched, and left the expected app process running. |
| AND-012 | blocked Global Constraint | findings/evidence/cov3-android/AND-012/ | The row requires emulator teardown --all, which the binding process-safety rule forbids. |
| AND-033 | pass | findings/evidence/cov3-android/AND-033/ | Uncreatable ready-file parent failed immediately with the path and filesystem reason before resolution/build/boot narration. |
| AND-034 | pass | findings/evidence/cov3-android/AND-034/ | Stale ready file was absent while the run was active and rewritten once with passed terminal state. |
| AND-035 | pass | findings/evidence/cov3-android/AND-035-exact/ | The quoted `--env 'LANDMARKS_NOTE=a=b c'` value appeared unchanged in the UI and logcat intent extras. |
| AND-037 | pass | findings/evidence/cov3-android/AND-037/ | LANDMARKS_NOTE=hello reached the launch extras and appeared as UI text under Deep Links. |
| AND-038 | pass | findings/evidence/cov3-android/AND-038/ | Both repeated environment values reached the launch extras and the seed-many scroll flow passed. |
| AND-039 | pass | findings/evidence/cov3-android/AND-039-cli-exact/, findings/evidence/cov3-android/AND-039-header-exact/ | Both CLI `LANDMARKS_SEED=empty` and the flow header env produced No landmarks yet and passed. |
| AND-040 | pass | findings/evidence/cov3-android/AND-040/ | Crash environment produced app_crash at launchApp, exit 1, a failure capture, and a failed ready file. |
| AND-041 | pass | findings/evidence/cov3-android/AND-106/ | The stock quoted-label flow tapped `Mount "Denali"`, asserted Alaska, and passed. |
| AND-042 | pass | findings/evidence/cov3-android/AND-042/ | Configured flow set passed 12/12. |
| AND-044 | pass | findings/evidence/cov3-android/CF-01-selectors/ | The non-ASCII `Mountains → Yosemite Valley` selector tapped successfully and Yosemite Valley was visible. |
| AND-047 | pass | findings/evidence/cov3-android/AND-047/ | failure kept only failure assets, trailing kept step trace assets, and full kept the complete passing-flow trace. |
| AND-048 | pass | findings/evidence/cov3-android/AND-048/ | Explicit report directory contained reports and captures while the project capture inventory remained unchanged. |
| AND-050 | pass | findings/evidence/cov3-android/AND-050/ | JSON pass, flow failure, no-report-directory, and unattached-device shapes were valid and carried the expected statuses/errors. |
| AND-059 | pass | findings/evidence/cov3-android/AND-059/ | During keep-alive the owned session, forward, UIAutomator2, and saved settings were present; SIGINT released the hold, restored every setting, removed session/settings/forward, and wrote no new failure PNG. |
| AND-060 | pass | findings/evidence/cov3-android/AND-060/ | SIGINT during the long flow exited 130, ready file became interrupted with no running flow, and session/settings/forward cleanup completed. |
| AND-063 | pass | findings/evidence/cov3-android/AND-063/ | Second run failed fast with the owning PID/runner PID and exact teardown/unique-name guidance, without runner-exit wrapper text. |
| AND-069 | n/a no physical device | findings/evidence/cov3-android/AND-001/ | Campaign inventory contains only Android emulators; the matrix explicitly marks the physical-device default-settings row n/a when no physical device exists. |
| AND-070 | n/a no physical device | findings/evidence/cov3-android/AND-001/ | Campaign inventory contains only Android emulators; the matrix explicitly marks the physical-device allow-device-settings row n/a when no physical device exists. |
| AND-071 | pass | findings/evidence/cov3-android/AND-071/ | --logs streamed 22 uid-filtered logcat lines and left no logcat process. |
| AND-072 | pass | findings/evidence/cov3-android/AND-072/ | --logs-tag implied streaming and output only the requested Landmarks tag. |
| AND-073 | pass | findings/evidence/cov3-android/AND-073/ | Default and info invoked logcat priority I, debug invoked D and added debug lines; warning was rejected with exit 64. |
| AND-074 | pass | findings/evidence/cov3-android/AND-074-exact/ | Android rejected the iOS-only `--logs-predicate` option by name before device work. |
| AND-075 | pass | findings/evidence/cov3-android/AND-075-rerun/, findings/evidence/cov3-android/AND-075-rerun-failure/ | Genuine success, 99-crash flow failure, and SIGINT paths exited 0, 1, and 130; each post-run process check found no matching adb logcat process. |
| AND-076 | pass | findings/evidence/cov3-android/AND-076/ | Static recording was exactly 5.000 s, emitted three requested PNGs, and reported the held frame at 0 ms. |
| AND-077 | pass | findings/evidence/cov3-android/AND-077/ | Duration 181 was refused before recording with the Android 180-second cap message. |
| AND-078 | pass | findings/evidence/cov3-android/AND-078/ | Explicit serial, AVD name, and configured default all targeted emulator-5554. |
| AND-079 | pass | findings/evidence/cov3-android/AND-079/ | Absolute output path with a space was written there; JSON named cov3-android and emulator-5554 in both legacy and platform fields. |
| AND-124 | pass | findings/evidence/cov3-android/AND-124/ | Static four-second recording printed the held-frame warning. |
| AND-128 | pass | findings/evidence/cov3-android/AND-128/, findings/evidence/cov3-android/AND-128-maestro-format/ | The screens-steps config captured six screens with every step passing; the separate Maestro-format config captured both screens with all seven steps passing. |
| AND-123 | pass | findings/evidence/cov3-android/AND-123/ | A pre-run marker remained in the device buffer but was absent from streamed run logs. |
| AND-139 | pass | findings/evidence/cov3-android/AND-139/ | Plain, quiet, and verbose JSON were byte-identical; quiet retained the warning, and verbose added timestamped subprocess traces. |
| AND-201 | pass | findings/evidence/cov3-android/AND-106/ | The stock browse flow tapped Golden Gate Bridge and the detail assertions for San Francisco and Plan Visit passed. |
| AND-202 | pass | findings/evidence/cov3-android/AND-202-targeted/ | A preserved exact-input flow used `tapOn: {text: "Lake Tahoe"}` without `exact`; it opened the matching detail and passed. |
| AND-203 | pass | findings/evidence/cov3-android/CF-01-selectors/ | id=clock assert and tap both passed on Caching Demo, independently proving resource-id selection. |
| AND-204 | pass | findings/evidence/cov3-android/CF-01-selectors/ | Whole-text regex taps/asserts passed while substring-only Lake was correctly not visible. |
| AND-205 | pass | findings/evidence/cov3-android/CF-01-selectors/ | Regex assert, exact literal negative assert, and exact Lake Tahoe tap all passed with no unsupported warning. |
| AND-206 | pass | findings/evidence/cov3-android/AND-206-targeted/ | Exact Golden Gate.* was treated literally, failed as not visible while Golden Gate Bridge was present, named the exact selector, and exited 1. |
| AND-207 | pass | findings/evidence/cov3-android/AND-207-targeted/ | Index 1 selected Mono Lake; Lee Vining was visible and Lake Tahoe was absent on the detail screen. |
| AND-208 | pass | findings/evidence/cov3-android/CF-04-point-taps/ | 50%,50% tap produced Last tap: center and Taps: 1. |
| AND-209 | pass | findings/evidence/cov3-android/AND-209-targeted-retry/ | Both 100%,100% and 0%,0% taps passed; a following on-screen Gesture Lab assertion and preserved screenshot succeeded after each edge tap. |
| AND-210 | pass | findings/evidence/cov3-android/AND-210-targeted-retry/ | Starting from Taps 0, id-based doubleTapOn produced Double taps 1 while Taps remained 0. |
| AND-211 | pass | findings/evidence/cov3-android/CF-03-gesture-lab-taps/ | id-based longPressOn produced Long presses: 1. |
| AND-212 | pass | findings/evidence/cov3-android/AND-106/ | The stock edit flow appended ` Renamed`, showed Golden Gate Bridge Renamed, and passed without a report warning. |
| AND-213 | pass | findings/evidence/cov3-android/AND-213-targeted/ | Unicode input remained unmangled in `San Francisco, CA · Ünïcødé ✓`, and the exact UI assertion passed. |
| AND-214 | pass | findings/evidence/cov3-android/CF-01-selectors/ | Visible string, text-map, regex, and id assertions all passed. |
| AND-215 | pass | findings/evidence/cov3-android/AND-106/ | The category flow's assertNotVisible for Golden Gate Bridge passed on Lakes. |
| AND-216 | pass | findings/evidence/cov3-android/CF-05-swipe-forms/ | LEFT, RIGHT, UP, and DOWN direction swipes each produced the matching Last swipe value. |
| AND-217 | pass | findings/evidence/cov3-android/AND-106/ | Swipe left from Lake Tahoe opened removal; Remove from favorites led to the Favorites empty state. |
| AND-218 | pass | findings/evidence/cov3-android/CF-05-swipe-forms/ | UP swipe from id=gesture-pad passed and produced Last swipe: up. |
| AND-219 | pass | findings/evidence/cov3-android/AND-219-targeted/ | Swipe from No Such Row failed at the swipe with `Element not found for swipe` and exit 1. |
| AND-220 | pass | findings/evidence/cov3-android/CF-05-swipe-forms/ | Percentage start/end swipe passed, retained its coordinates in output, and produced Last swipe: left. |
| AND-221 | pass | findings/evidence/cov3-android/CF-06-swipe-absolute/ | Absolute 300,600 to 60,600 coordinates were treated as pixels and produced Last swipe: left. |
| AND-222 | pass | findings/evidence/cov3-android/CF-05-swipe-forms/ | 1500 ms directional swipe registered left and measured 1629 ms. |
| AND-223 | pass | findings/evidence/cov3-android/AND-106/ | Four bare downward scrolls with seed-many completed and Landmark 28 was visible. |
| AND-224 | pass | findings/evidence/cov3-android/AND-038/ | Seed-many flow found Landmark 70 and then Golden Gate Bridge in both scroll directions. |
| AND-225 | pass | findings/evidence/cov3-android/AND-225-targeted/ | Both string and `{file:}` runFlow forms executed the sub-flow and its assertions successfully. |
| AND-226 | pass | findings/evidence/cov3-android/AND-226-targeted/ | Inline runFlow commands tapped Favorites and passed the empty-state assertion. |
| AND-228 | pass | findings/evidence/cov3-android/CF-09-waits/ | notVisible wait passed after Loading disappeared in 3217 ms. |
| AND-229 | pass | findings/evidence/cov3-android/CF-09-waits/ | Bare and timeout-map waitForAnimationToEnd forms both passed. |
| AND-227 | pass | findings/evidence/cov3-android/AND-106/ | The stock slow flow found Loaded after delay in 3.2 seconds, within its 10-second wait. |
| AND-230 | pass | findings/evidence/cov3-android/AND-106/ | Bare launchApp succeeded throughout the passing 12-flow stock run. |
| AND-235 | pass | findings/evidence/cov3-android/AND-106/ | takeScreenshot with the plain spaced name `Deep Link Lakes` succeeded and was named in the output. |
| AND-236 | pass | findings/evidence/cov3-android/AND-106/ | The header-env seed-empty stock flow launched with LANDMARKS_SEED=empty and asserted No landmarks yet. |
| AND-090 | pass | findings/evidence/cov3-android/AND-090/ | Required Android doctor checks passed; optional inventory named the owner AVD without touching it. |
| AND-091 | pass | findings/evidence/cov3-android/AND-091/ | With ANDROID_HOME unset, SDK fallback succeeded. |
| AND-092 | pass | findings/evidence/cov3-android/AND-092/ | Invalid JAVA_HOME produced valid JSON with a JDK error and fix line, exit 1. |
| AND-093 | pass | findings/evidence/cov3-android/MCP-live-readonly/ | With the Android config and live runner session, tools/list returned the documented 22-tool Android-capable set. |
| AND-094 | pass | findings/evidence/cov3-android/MCP-live-readonly/ | Live grantiva_context reported platform android, cov3-android at emulator-5554 from the runner session, and the Android SDK path. |
| AND-095 | pass | findings/evidence/cov3-android/MCP-interactions-retry/ | Coordinate tap at 205,457 dp on the Gesture Lab pad returned the updated app tree with Taps incremented from 0 to 1. |
| AND-102 | pass | findings/evidence/cov3-android/MCP-live-readonly/ | grantiva_test returned an isError result explaining that it is iOS-only and naming connectedAndroidTest. |
| AND-097 | pass | findings/evidence/cov3-android/MCP-interactions-retry/ | In a confirmed Deep Links app session, default screenshot returned image/png base64 and file format wrote `.grantiva/mcp-screenshot.png`. |
| AND-098 | pass | findings/evidence/cov3-android/MCP-interactions-retry/ | grantiva_script executed a dp tap_xy, wait, and swipe in order; the final app tree showed Taps 2 and Last swipe up. |
| AND-104 | pass | findings/evidence/cov3-android/MCP-live-readonly/ | All 18 JSON-RPC requests were answered while the live Android session and adb forward were active; stdout had zero non-JSON lines. |
| AND-088 | blocked credentials | findings/evidence/cov3-android/AND-088/ | The round-3 rerun rule keeps this credentials-dependent row blocked because the environment has not changed. |
| AND-089 | pass | findings/evidence/cov3-android/AND-089-exact/ | Android ci run refused immediately with the documented local-only baseline message. |
| AND-085 | pass | findings/evidence/cov3-android/AND-085-exact/ | First Android capture wrote five PNGs under `.grantiva/captures/android`; JSON named cov3-android/emulator-5554 and included Android and compatibility device fields. |
| AND-086 | pass | findings/evidence/cov3-android/AND-086-exact/ | Approve copied all five captures into `.grantiva/baselines/android`, returned the five approved screen names, and left platform-specific paths. |
| AND-106 | pass | findings/evidence/cov3-android/AND-106/ | Five screens captured and all 12 stock flows passed (90/90 steps). |
| AND-107 | pass | findings/evidence/cov3-android/AND-107/ | Five crash runs all failed with app_crash at launchApp or the first assertion; FATAL-to-failure 0.6-1.9 s. |
| AND-108 | pass | findings/evidence/cov3-android/AND-108/ | JSON and file inventory show five of five screens; Lakes executed Landmarks→Lakes and Detail executed Golden Gate Bridge→Plan Visit. |
| AND-116 | pass | findings/evidence/cov3-android/CF-13-android-arguments-merge/ | The launch request in client.log contains both LANDMARKS_SEED from `arguments` and LANDMARKS_NOTE from `environment` in one arguments map. |
| AND-117 | pass | findings/evidence/cov3-android/CF-11-launch-environment/, findings/evidence/cov3-android/AND-117-exact/ | Step environment beat header env in the first flow; the exact rerun explicitly passed `--env LANDMARKS_NOTE=from-cli`, and the from-cli UI assertion passed over both header and step values. |
| AND-120 | pass | findings/evidence/cov3-android/AND-120/ | Combined screens-and-flows run wrote the separate screens report under the requested report directory and full snapshots produced 243 trace PNGs. |
| AND-121 | pass | findings/evidence/cov3-android/CF-17-back/ | The runner-only `back` command executed successfully and the following Deep Links assertion passed. |
| AND-112 | pass | findings/evidence/cov3-android/AND-112/ | Unknown --device serial failed before build, naming attached emulator-5554 and explaining that --device never boots. |
| AND-231 | pass | findings/evidence/cov3-android/CF-10-lifecycle/ | After favoriting Lake Tahoe, launchApp clearState succeeded and Favorites showed the empty-state message. |
| AND-232 | pass | findings/evidence/cov3-android/CF-11-launch-environment/ | launchApp environment delivered LANDMARKS_NOTE and the UI assertion for `from step` passed. |
| AND-233 | pass | findings/evidence/cov3-android/CF-10-lifecycle/ | stopApp succeeded both before launch and twice consecutively after launch, demonstrating idempotence. |
| AND-234 | pass | findings/evidence/cov3-android/CF-10-lifecycle/ | killApp followed by launchApp succeeded and Featured was visible after relaunch. |
| AND-237 | pass | findings/evidence/cov3-android/CF-16-setpermissions/ | Header-app setPermissions and bare scroll both passed through to the runner and succeeded. |
| AND-238 | pass | findings/evidence/cov3-android/CF-13-android-arguments-merge/ | client.log records one launch_app request with LANDMARKS_SEED=`empty` and LANDMARKS_NOTE=`merged` in the delivered arguments. |
| AND-239 | pass | findings/evidence/cov3-android/CF-17-back/ | Back from Caching Demo succeeded and the following Deep Links screen assertion passed. |
| B-C10.1 [android] | pass | findings/evidence/cov3-android/CF-16-setpermissions/ | The Android C10 repro passed both header-app setPermissions and bare scroll. |
| B3-L57 | fail | findings/evidence/cov3-android/B3-L57/ | Runs 1 and 2 allowed launchApp to pass after FATAL due to a stale pre-crash process read; failure followed at the first assertion. |
| B3-L61 | pass | findings/evidence/cov3-android/B3-L61/ | Failure captures appeared 2.8-9.0 s after step failure, matching the documented current behavior. |
| B-R01.3 | pass | findings/evidence/cov3-android/B-R01.3/ | Android stock and crash acceptance covered by AND-106/107. |
| B-R02.6 | pass | findings/evidence/cov3-android/B-R02.6/ | Android stock flow half passed 12/12 with the .13 runner. |
| B-R02.4 | pass | findings/evidence/cov3-android/CF-06-swipe-absolute/ | Absolute coordinates used the allowed pixel path, landed on screen, and produced Last swipe: left. |
| N-15 | pass | findings/evidence/cov3-android/N-15/ | Stock run used one UIAutomator2 session and emitted no GrantivaAgent marker. |
| N-16 | pass | findings/evidence/cov3-android/N-16/ | Narration correctly reported five screens followed by 12 flows. |
| N-08 | blocked root | findings/evidence/cov3-android/N-08/ | The round-3 rerun rule keeps the root-dependent row blocked because the environment has not changed. |
| B-A05.1 | pass | findings/evidence/cov3-android/B-A05.1/ | Two-second static video and requested 1000 ms PNG succeeded; JSON identified the actual held frame at 0 ms. |
| B-A04.1 [android] | pass | findings/evidence/cov3-android/B-A04.1/ | Across all ten captures, Deep Links and Home had distinct hashes within every run. |
| B2-K34-a | pass | findings/evidence/cov3-android/B2-K34-a/ | Verbose held-frame line distinguished last-frame start, track end, requested duration, and on-screen hold; JSON matched the held-frame start. |
| B2-K34-b | pass | findings/evidence/cov3-android/B2-K34-b/ | Ten recordings each emitted a diagnostic Held frame line; late-frame cases suppressed the note and exposed recordedMilliseconds, while idle cases printed the note. |
| B2-K84 | pass | findings/evidence/cov3-android/B2-K84/ | Out-of-range 5000 ms frame failed validation in 0.03 s with exit 64 and left the prior video checksum unchanged; boundary 2000 ms was accepted. |
| B2-K85 | pass | findings/evidence/cov3-android/B2-K85/ | Relative output produced relative video/frame paths and absolute output produced absolute paths in both text and JSON. |
| B2-K111 | pass | findings/evidence/cov3-android/B2-K111/ | Five four-second recordings measured exactly 4.000 s; pre-trim metadata remained exposed and a frame requested at 4000 ms resolved successfully. |
| B2-K12 | pass | findings/evidence/cov3-android/B2-K12/ | Unknown serial failed with attached-device/--emulator guidance; explicit running serial and AVD both narrated Using emulator with no Booting line and passed. |
| B2-K76-a [android] | pass | findings/evidence/cov3-android/AND-038/ | Slow passing scrollUntilVisible steps retained checkmarks and explicit `(21.xs, slow)` suffixes with no warning glyph. |
| D2-19 | pass | findings/evidence/cov3-android/D2-19/ | Plain, quiet, JSON+verbose, verbose, and quiet+verbose output modes all retained the expected result and exit status. |
| D2-14 [android] | pass | findings/evidence/cov3-android/D2-14/ | runner stop --json reported stopped for passing and failing keep-alive runs; ready files remained byte-unchanged as passed/failed and both foreground runs exited. |
| N2-09 | pass | findings/evidence/cov3-android/N2-09/ | Runs without report-dir wrote only run-captures; runs with report-dir did not write project run-captures, and diff commands ignored run-captures. |
| X-004 | pass | findings/evidence/cov3-android/X-004/ | Ready files reported passed, failed, and interrupted terminal states; SIGINT run exited 130. |
| X-010 [android] | pass | findings/evidence/cov3-android/X-010/ | JSON included frame fields plus emulator/serial and matching simulator/udid compatibility fields. |
| N2-14 [android] | pass | findings/evidence/cov3-android/AND-038/ | Slow passing Android searches used the `(duration, slow)` suffix and no warning glyph; wait flow likewise contained no warning marker. |
| N-11 [android] | pass | findings/evidence/cov3-android/AND-209-targeted-retry/ | Both edge point taps passed and retained the Gesture Lab screen, with a screenshot preserved after each. |
| MCP-040 | pass | findings/evidence/cov3-android/MCP-live-readonly/ | Android grantiva_test returned a tool-level isError result stating that the tool is iOS-only. |
| MCP-043 | pass | findings/evidence/cov3-android/MCP-live-readonly/ | Live context named platform android, session serial emulator-5554, configured cov3-android emulator, and Android SDK. |
| MCP-055 | pass | findings/evidence/cov3-android/MCP-live-readonly/ | Emulator list with config returned both known AVDs and correctly identified only cov3-android/emulator-5554 as booted. |
| MCP-002 | pass | findings/evidence/cov3-android/MCP-interactions-retry/ | Confirmed live Android app session returned screenshot base64 PNG and file-path variants. |
| MCP-006 | pass | findings/evidence/cov3-android/MCP-interactions-retry/ | Label tap opened Gesture Lab, then a hierarchy-derived dp coordinate tap incremented Taps from 0 to 1. |
| MCP-010 | pass | findings/evidence/cov3-android/MCP-interactions-retry/ | Left swipe returned the app tree with Last swipe left; sideways returned a validation isError result and the server remained live. |
| MCP-018 | pass | findings/evidence/cov3-android/MCP-interactions-retry/ | Confirmed Deep Links app session returned a JSON accessibility hierarchy with app labels, element types, frames, and states. |
| B3-L15.2 [android] | fail | findings/evidence/cov3-android/MCP-live-readonly/mcp/script-missing.json, findings/evidence/cov3-android/MCP-live-readonly/mcp/swipe-missing.json, findings/evidence/cov3-android/MCP-live-readonly/mcp/type-missing.json | Live swipe and type errors match exactly, but script returned `'steps' array is required.` instead of the required exact `'steps' is required.`; all three were single-Error isError results. Shared defect L65. |
| B2-K89 [android] | pass | findings/evidence/cov3-android/B2-K89-exact/, findings/evidence/cov3-android/B2-K89-mixed-retry/ | No-baseline and mixed comparisons exit 1 with `passed:false`, MCP matches, and candidate README lines 726-729 explicitly document both cases and distinguish `ci run`. The earlier relative-path audit read the demo scratch README and is retained as invalid harness evidence; `readme-audit-absolute.txt` records the exact candidate path and HEAD. |

| AND-051 | pass | findings/evidence/cov3-android/HIERARCHY-session-exact/ | The passing flow reached its ready file while the keep-alive process remained alive; the held UIAutomator2 session served four hierarchy commands before an explicit clean stop. |
| AND-053 | pass | findings/evidence/cov3-android/AND-053-exact/ | Default hierarchy returned the live UIAutomator2 XML page source containing the unchanged Landmarks detail app tree. |
| AND-054 | pass | findings/evidence/cov3-android/AND-054-exact/ | `hierarchy --format json` returned the same live tree as valid JSON with 411x891 dp root geometry and dp child frames. |
| AND-055 | pass | findings/evidence/cov3-android/AND-055-exact/ | `hierarchy --json` returned byte-identical JSON to `--format json` in the same held session. |
| AND-061 | pass | findings/evidence/cov3-android/AND-061-exact/, findings/evidence/cov3-android/HIERARCHY-session-exact/ | An immediate hierarchy call after observing the ready file succeeded in 0.2 seconds against the still-live held session. |

| AND-096 | pass | findings/evidence/cov3-android/MCP-type-exact/ | In a confirmed Edit Landmark session, label tap, appended text entry, and upward swipe each succeeded and returned the updated app tree; the final field value was Golden Gate Bridge Renamed. |
| MCP-014 | pass | findings/evidence/cov3-android/MCP-type-exact/ | With the Name field focused, `grantiva_type {text: " Renamed"}` appended text and returned a tree containing Golden Gate Bridge Renamed. |
| MCP-026 | pass | findings/evidence/cov3-android/MCP-script-exact/ | The four-step tap/wait/dp-tap/swipe script ran in order and returned Taps 1 / Last swipe up; a no-focus type stopped at step 1 with the required focused-field error, and the invalid script ran nothing while naming both invalid steps. |
| B-C17.1 | pass | findings/evidence/cov3-android/MCP-script-exact/ | The invalid live script returned a tool-level isError, stated no steps were run, and explained both step 1 unknown action and step 2 non-object errors. |

| B-C21.2 [android] | pass | findings/evidence/cov3-android/MCP-killed-app-errors/live/ | A live tap for a definitely missing label returned a tool-level `isError` with `Error: Element not found`, never a JSON-RPC error, and the MCP server remained alive. |
| MCP-078 [android] | fail | findings/evidence/cov3-android/MCP-killed-app-errors/ | After an explicit force-stop and pid absence, tap, type, and script returned tool-level isError results, but screenshot, swipe, a11y_tree, and a11y_check incorrectly succeeded against system UI instead of reporting that the session app was killed. |

| B2-K102 [android] | pass | findings/evidence/cov3-android/MCP-killed-app-errors/live/, findings/evidence/cov3-android/MCP-type-exact/, findings/evidence/cov3-android/MCP-script-exact/, findings/evidence/cov3-android/MCP-k102-focus/ | Standalone and script type calls with no focused field returned isError without typing; the script stopped at its named first step. After focusing Name, standalone type produced Golden Gate Bridge Renamed and the two-step script produced Golden Gate Bridge Scripted. Candidate Android transport and MCP tests encode the same no-keys/focus contract. |
| AND-099 | pass | findings/evidence/cov3-android/MCP-a11y-two-screens/ | The live audit applied the 48dp threshold (reporting a 411x13dp target) on the Landmarks list; Deep Links returned no violations, so its merged-text Compose controls were not falsely reported missing_label. |

| B2-K24 | pass | findings/evidence/cov3-android/B2-K24-exact-rerun1/, findings/evidence/cov3-android/B2-K24-doc-audit-absolute.txt | Fresh default and explicit `--platform android` captures each exited 0, wrote both PNGs, and showed `Tap on id "clock"` / `Assert visible id "clock"` passing. Exact candidate docs cover Maestro Android configs and native `{id}` selectors; source plus exact-head CI prove Android defaults, appId override, and id-selector generation tests. |

| AND-030 | pass | findings/evidence/cov3-android/AND-043-exact-rerun1/ | Twelve exact `--device emulator-5554` runs all narrated and reported cov3-android/emulator-5554, targeting the requested serial. |
| AND-043 | pass | findings/evidence/cov3-android/AND-043-exact-rerun1/ | Stock flows 01 through 12 were each invoked separately with `--flow`; every run exited 0 and each report contained exactly the one requested passing flow. |
| AND-045 | pass | findings/evidence/cov3-android/AND-043-exact-rerun1/ | All twelve installed-app runs explicitly narrated `Skipping build and install (--no-build)` and proceeded directly to the runner, with no Gradle command or build execution. |

| AND-046 | pass | findings/evidence/cov3-android/AND-046-049-exact-rerun1/continue/ | With crash flow first and `--continue-on-failure`, the crash failed, the following browse flow still passed 8/8, the report recorded one failed plus one passed flow, and the command exited 1. |
| AND-049 | pass | findings/evidence/cov3-android/AND-046-049-exact-rerun1/timeout/ | The 30-second cap returned after 31.5 seconds wall time with exit 1; ready and report were terminal failed with no running flow, and the kill sentence had no stray trailing colon. |

| AND-126 | pass | findings/evidence/cov3-android/AND-126-127-exact-rerun1/ | `runner start --device emulator-5554 --headless --detach --json` returned started, the repeat returned already_running, and stop returned stopped; all were valid JSON, flags were accepted, and cleanup removed session/forwards. |
| B2-K16 [android] | pass | findings/evidence/cov3-android/AND-126-127-exact-rerun1/ | Android started, already_running, and stopped documents consistently used numeric pid/port plus applicationId and serial; compatibility bundle_id/udid keys match the documented deprecation, and exact-head CLI tests cover the shapes. |

| AND-125 | pass | findings/evidence/cov3-android/AND-125-exact-rerun1/ | The documented five-second record example exited 0 and preserved one nonempty MP4 plus exactly three PNG frames for 0, 1000, and 3000ms. |

| AND-127 | fail | findings/evidence/cov3-android/AND-126-127-exact-rerun1/, findings/evidence/cov3-android/AND-127-exact-rerun1/, findings/evidence/cov3-android/AND-127-isolated-poll-rerun2/ | Detached start reported ready before its generated `launchApp` flow had foregrounded the app: the immediate hierarchy was system UI. An isolated retry without concurrent runner work reproduced the timing window, then returned Landmarks on the next poll 1.183 seconds later. |

| AND-105 | pass | findings/evidence/cov3-android/AND-105-exact-rerun1/ | In a project containing both iOS and Android configs, explicit `mcp --platform android` started cleanly; context selected grantiva-android.yml, Android module/variant/application ID, cov3-android/emulator-5554, and the Android SDK. |

| AND-103 | pass | findings/evidence/cov3-android/AND-103-exact-rerun1/ | In a confirmed live Android session, MCP VRT capture wrote five configured screens under captures/android, approve promoted them under baselines/android, and compare passed all five with Android paths; unrelated captures were listed as ignored. |

| AND-118 | pass | findings/evidence/cov3-android/AND-118-exact-rerun1/ | With neither emulator config nor a device flag, narration used explicit `device=(none)`, then selected `cov3-android (emulator-5554)`; no empty device serial appeared and the flow passed. |

| AND-119 | pass | findings/evidence/cov3-android/AND-119-exact-rerun1/ | With continue-on-failure, the configured screen session failed at `No Such Element` but the following browse flow still ran and passed; the command retained exit 1. The slow-screen timeout fired at its named `Slow` step under the configured 30-second cap; total wall time including setup and cleanup was 34.2 seconds, with a terminal failed report. |

| AND-081 | pass | findings/evidence/cov3-android/AND-081-084-exact-rerun1/ | One confirmed Landmarks session produced nonempty tree, JSON, and XML hierarchies; all three contained the same Landmarks application content and exited 0. |
| AND-082 | pass | findings/evidence/cov3-android/AND-081-084-exact-rerun1/ | Stop returned a structured stopped result for the exact Android PID/port/serial, the PID was dead, the project session file was removed, and the owned 6790 forward present during the session was absent afterward. |
| AND-084 | pass | findings/evidence/cov3-android/AND-081-084-exact-rerun1/ | After PID 54010 was proven dead, its exact session record was restored; a fresh start replaced it with PID 54330 on the requested emulator-5554, and final stop removed the session cleanly. |

| B-A13.2 | pass | findings/evidence/cov3-android/AND-106/ | The round-3 stock Android screen session passed all 22 steps and captured both the Lakes category screen and the Golden Gate Bridge Detail screen among its five configured captures. |
| B-R01.2 | pass | findings/evidence/cov3-android/AND-106/ | Stock `03-edit` typed the suffix, clicked Done at y=233 on the 1080x2400 emulator (well above the keyboard), closed the sheet, and asserted `Golden Gate Bridge Renamed`. |
| X-001 [android] | pass | findings/evidence/cov3-android/AND-043-exact-rerun1/runs/01-browse/, findings/evidence/cov3-android/X-cross-platform-audit/ | Matching current-round one-flow Android and iOS captures share the resolved/flow-count, eight ordered steps, two screenshots, summary, and final flow totals; only expected platform setup/device text and timings differ, and Android never says GrantivaAgent. |
| X-003 [android] | pass | findings/evidence/cov3-android/AND-043-exact-rerun1/runs/01-browse/, findings/evidence/cov3-android/X-cross-platform-audit/ | Matching current-round Android and iOS report directories contain report.json, flows/flow-000.json, and junit-report.xml with the same normalized top-level schema and exact `.maestro/01-browse.yaml` source path. |
| X-002 [android] | pass | findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-pass/, findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-fail/, findings/evidence/cov3-android/X-cross-platform-audit/ | Matching current-round Android and iOS pass/fail JSON documents use identical keys and value types, including reportDir representation; failure adds the error string on both platforms and success omits it. |

| AND-031 | pass | findings/evidence/cov3-android/output-contracts-exact-rerun1/AND-031/ | With empty screens and flows and no device selector, run failed immediately with `No screens or flows configured`; its requested ready file was terminal `failed`, named the error, and retained the absolute report directory. |
| B2-K19 [android] | fail | findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-fail/, findings/evidence/cov3-android/output-contracts-exact-rerun1/AND-137-quiet-fail/ | Matrix expectation conflict, not a product defect: `--quiet` alone reduced a real failure to the Error lines, while `--json --quiet --verbose` emitted verbose runner output because exact source intentionally makes verbose win. The JSON error correctly names the failed flow and step; separate JSON/quiet and diff/CI variants remain unverified. |
| B2-K21-a [android] | pass | findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-pass/, findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-fail/ | Passing and failing JSON both retained the requested absolute `reportDir`; success omitted error while failure included its structured message, matching the documented contract. |
| B2-K21-b [android] | pass | findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-pass/, findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-fail/ | Passing and failing JSON each used one `screens` entry for the requested flow, with name, passed state, and real command steps; failure added a step message and success attached its named screenshot paths without changing the entry kind. |

| AND-036 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/AND-036/ | With no emulator in config and exactly the owned emulator running, run selected it without a device/emulator flag and passed all eight browse steps. |
| AND-111 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/ | From no attached Android device, `build build` ran `assembleFreeDebug`, exited 0, and left adb and the QEMU process inventory empty. |
| AND-114 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/ | With no emulator configured, no attached device, and two frozen AVD choices, run failed naming both choices and instructing `--emulator`; it booted neither. |
| AND-113 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/AND-113/ | From a stopped state, build install logged `Booting AVD cov3-android as emulator-5554`, built, installed, launched, and reported the app running on cov3-android. |
| AND-143 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/AND-143/ | Explicit emulator/headless/module install booted cov3-android as emulator-5554, built app, installed and launched it; the owned QEMU command line contained `-no-window`. |
| AND-029 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/AND-029/ | From a stopped state, explicit `--emulator cov3-android --no-build` booted emulator-5554 and passed the browse flow. |
| AND-032 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/AND-032/ | From a stopped state, explicit headless emulator run booted cov3-android, passed the browse flow, and the owned QEMU command line contained `-no-window`. |
| AND-140 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/AND-140/ | Explicit emulator/module/freeDebug/headless capture booted the owned AVD with `-no-window`, built and captured all five configured screens, and printed `Emulator: cov3-android (emulator-5554)`. |
| AND-141 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/AND-141/ | Diff capture used the frozen nonempty APK, read its application ID with apkanalyzer, printed `Using pre-built binary` with no Gradle invocation, and captured all five screens. |
| AND-142 | pass | findings/evidence/cov3-android/PHASEB-build-lifecycle-exact-rerun1/ | All four compare-and-capture targeting variants reached capture and comparison: emulator/module/variant/application/headless built and used the owned headless AVD; exact device/no-build skipped build; app-file used the prebuilt APK; allow-device-settings was accepted. The comparisons returned 1 only because the fresh captures exceeded the existing baseline thresholds, with per-screen reasons preserved. |
| AND-083 | pass | findings/evidence/cov3-android/AND-083-exact-rerun2/ | Against a preserved config containing competing application `configured.sentinel` and nonexistent emulator `configured-sentinel-do-not-create`, explicit `--application-id x.y --emulator cov3-android` started on owned emulator-5554 and persisted x.y; stop returned the same exact identity. |
| B2-K13 [android] | pass | findings/evidence/cov3-android/AND-106/, findings/evidence/cov3-android/output-contracts-exact-rerun1/B2-K13-flow-flag/, findings/evidence/cov3-android/output-contracts-exact-rerun2/B2-K13-flows12/, findings/evidence/cov3-android/output-contracts-exact-rerun2/B2-K13-screens5/ | Combined stock narration named five screens and twelve flows separately and never said thirteen; focused flows-only printed twelve once, screens-only printed five with no flow count, and explicit `--flow` printed one flow once. |
| B2-K20 [android] | pass | findings/evidence/cov3-android/output-contracts-exact-rerun2/B2-K20-ready/, findings/evidence/cov3-android/AND-119-exact-rerun1/ | Failed screens were named `screens` with the exact Broken step, separate `Screens: 2...` and `Flows: 1...` totals, then browse passed; ready listed failed screens and passed browse. The timeout variant named screen Slow, the 30-second cap, and no dangling interrupt label. |

| AND-003 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/ | Repeating ensure for campaign secondary AVD `cov3-android-2` returned `Reused` and the same assigned serial emulator-5556. |
| AND-004 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/AND-004-007/ | Fresh `cov3-android-2 --no-boot` created the distinct campaign-owned AVD, printed its name on stdout, and the immediate adb snapshot proved it was not booted. |
| AND-005 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/AND-005-006/ | Config-selected ensure with `--headless` booted secondary serial emulator-5556; its exact QEMU process contained `-no-window`. |
| AND-006 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/AND-005-006/ | Ensure without a name read preserved config `emulator: cov3-android-2` and booted that exact AVD as emulator-5556. |
| AND-007 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/AND-004-007/ | Creation without a system-image flag produced config `system-images/android-35/google_apis/arm64-v8a` with the expected ABI and tag. |
| AND-008 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/AND-008/ | Ensure JSON decoded successfully and named cov3-android-2, emulator-5556, Booted, and created false. |
| AND-009 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/AND-009/ | Sessions JSON decoded successfully and listed both campaign-started AVDs with exact serial, PID, adb state, process liveness, and start time. |
| AND-010 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/ | Teardown targeted only secondary emulator-5556, stopped its owned runner PID, removed its 6790 forward/session, and killed cov3-android-2; the primary emulator was untouched. |
| AND-014 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/AND-014-146/ | Delete removed the stopped Grantiva-created cov3-android-2 AVD, and the following avdmanager inventory no longer listed it. |
| AND-146 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/AND-014-146/ | Delete JSON decoded successfully as `{deleted:true,name:"cov3-android-2"}`, and avdmanager no longer listed the AVD. |
| AND-109 | pass | findings/evidence/cov3-android/secondary-avd-lifecycle-exact-rerun1/ | After recreating cov3-android-2 and deleting it externally with avdmanager, the next Grantiva sessions call pruned its created-AVD ledger record and listed only the primary campaign AVD. |
| AND-137 | fail | findings/evidence/cov3-android/output-modes-exact-rerun3/, findings/evidence/cov3-android/output-contracts-exact-rerun1/AND-137-quiet-fail/ | Plain, quiet, and verbose used the identical cwd, config, flow, device, and report path, but stdout was not byte-identical because real per-step durations differed. Quiet stderr was empty, verbose added timestamped subprocess/exit lines, and a quiet failure retained only its Error message, so the remaining mismatch is the literal byte-equality criterion over dynamic JSON. |
| AND-138 | fail | findings/evidence/cov3-android/output-modes-exact-rerun3/ | Plain, quiet, and verbose used the identical cwd, config, device, and capture path, but stdout was not byte-identical because capture duration, measured step duration, and timestamp differed. Quiet stderr was empty and verbose added timestamped subprocess/exit lines; the remaining mismatch is the literal byte-equality criterion over dynamic JSON. |
## Counts

196 of 467 slice rows recorded: 183 pass, 7 fail, 4 blocked, 2 n/a.
