# iOS slice results: round 3 coverage pass

Binary `/Users/kyle/.grantiva-qa/bin/grantiva`, SHA-256 `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`, version 2.1.0; runner `1.1.28-grantiva.13+android-drivers-2`; runner home `/Users/kyle/.grantiva-qa/runner`; session `cov3-ios`.

Only raw captures known to predate the invalid historical import and the explicitly enumerated focused/attempt groups in `findings/evidence/cov3-ios/PROVENANCE.md` are graded here. `findings/cov3-ios-results.imported-invalid.md` and `findings/evidence/cov3-ios-historical-cov2-import/` are excluded.

| ID | result | evidence | note |
|---|---|---|---|
| B3-L08.1 | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Both protected owner simulators were already booted; guarded no-simulator MCP build was not sent. |
| B3-L08.2 | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Both protected owner simulators were already booted; guarded default-path CLI calls were not sent. |
| B2-K37.2 [ios] | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Default-device guard prohibited the no-simulator call. |
| N3-12 | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Protected owner simulators were already booted; guarded MCP calls were not sent. |
| N3-13 | blocked owner simulators booted | findings/evidence/cov3-ios/STEP1/ | Required empty booted list was unavailable; guarded MCP build was not sent. |
| IOS-001 | pass | findings/evidence/cov3-ios/IOS-001/ | Created and booted `cov3-ios-3 iPhone 17` as UDID `2E3D6203-A4A0-4C8C-A3D6-05EE4D608EE3`; stdout only UDID. |
| IOS-002 | pass | findings/evidence/cov3-ios/IOS-002/ | Reuse returned the same UDID and `Reused … — Booted`. |
| IOS-003 | pass | findings/evidence/cov3-ios/IOS-003/ | `cov3-ios-4 Pin` created as iPhone 17 on newest runtime. |
| IOS-004 | pass | findings/evidence/cov3-ios/IOS-004/ | Runtime 26.0 created; 99.9 refused; no 99.9 device created; row device deleted. |
| IOS-009 | pass | findings/evidence/cov3-ios/IOS-009/ | Campaign device is in the QA runner home's capacity ledger; owner-home grep has no campaign entry. |
| IOS-010 | pass | findings/evidence/cov3-ios/IOS-010/ | Text and JSON list only the three campaign-owned slots; booted owner devices are absent. |
| IOS-011 | pass | findings/evidence/cov3-ios/IOS-011/ | Capacity warning names exactly three campaign devices; timeout leaves no fourth device. |
| IOS-012 | pass | findings/evidence/cov3-ios/IOS-012/ | Limit 1 waits and times out while three campaign slots are active. |
| IOS-013 | pass | findings/evidence/cov3-ios/IOS-013/ | Five-second capacity timeout exits nonzero and leaves no device or ledger record. |
| IOS-019 | pass | findings/evidence/cov3-ios/IOS-019/ | First delete succeeds; second clearly reports simulator not found. |
| IOS-117 | pass | findings/evidence/cov3-ios/IOS-117/ | iOS 26.0 stock set: 5/5 screens and 12/12 flows; cache `sim-ios26.0-iphone-wda16.12.8-r1`. |
| IOS-118 | pass | findings/evidence/cov3-ios/IOS-118/ | iOS 27.0 stock set: 5/5 screens and 12/12 flows; cache `sim-ios27.0-iphone-wda16.12.8-r1`. |
| IOS-119 | pass | findings/evidence/cov3-ios/IOS-119/ | Crash flow exits 1 at first assertion with `app crashed` / not-running cause and failure summary. |
| IOS-120 | pass | findings/evidence/cov3-ios/IOS-120/ | Five configured screens captured on both iOS 26.0 and 27.0. |
| IOS-029 | pass | findings/evidence/cov3-ios/IOS-117/ | All configured flows run with per-step output and 12/12 pass. |
| IOS-030 | pass | findings/evidence/cov3-ios/FLOWS-26/, findings/evidence/cov3-ios/IOS-119/ | Each stock flow individual run passes; individually invoked 99-crash exits 1 with app-crash evidence. |
| IOS-031 | pass | findings/evidence/cov3-ios-attempt15/IOS-031/ | Empty flows/screens fails before build with no success report; ready file is `failed` with no flows. |
| IOS-032 | pass | findings/evidence/cov3-ios-attempt15/IOS-032/ | Stale year-2000 ready content is replaced once by the fresh passing run and current timestamp. |
| IOS-033 | pass | findings/evidence/cov3-ios-attempt15/IOS-033/ | Uncreatable absolute ready-file parent fails before build/device execution with a precise directory-creation error. |
| IOS-034 | pass | findings/evidence/cov3-ios-attempt15/IOS-034/ | Missing `/private/tmp` parent is created and receives the passing verdict. |
| IOS-039 | pass | findings/evidence/cov3-ios-attempt15/IOS-039/ | Crash environment exits 1, exports a failure screenshot/report, and writes ready status/flow `failed`. |
| IOS-038 | pass | findings/evidence/cov3-ios/FLOWS-26/09-seed-empty.out | Empty seed reaches the app and `No landmarks yet` is asserted. |
| IOS-041 | pass | findings/evidence/cov3-ios/IOS-117/ | Stock quoted-label flow taps Mount "Denali" and passes. |
| IOS-151 | pass | findings/evidence/cov3-ios/IOS-151/ | No-build Maps flow accepts the location alert, records the note, and passes. |
| IOS-239 @27.0 | pass | findings/evidence/cov3-ios/IOS-239@27.0/ | iOS 27.0 Maps repeat accepts the location alert and passes. |
| B3-L10 [ios] | pass | findings/evidence/cov3-ios/B3-L10/ | Plain and quiet stdout both contain the failed flow block and totals; quiet preserves the error; JSON shape remains valid. |
| B3-L14.2 [ios] | pass | findings/evidence/cov3-ios-attempt11b/B3-L14.1/ | Frozen harness shows active xcodebuild and descendants before the 2.014 s cancel; request id 2 has no response, xcodebuild is gone at cancel+5.009 s, and tools/list still answers. One reparented ibtoold remains and is disclosed. |
| B3-L15.2 [ios] | fail | findings/evidence/cov3-ios/B3-L15.2/mcp/transcript.txt | swipe/type match the exact required-argument shape, but script returns `Error: Invalid argument: 'steps' array is required.` instead of expected `'steps' is required.` |
| B3-L13 [ios] | pass | findings/evidence/cov3-ios/B3-L13/ | Fresh start/stop JSON; stopped shape includes port, app ID aliases, UDID, runnerPid, killed and reaped. |
| B3-L19 [ios] | pass | findings/evidence/cov3-ios/B3-L19/ | Text and JSON preserve `runFlow: 14-runflow-sub.yaml`; no absolute staged path. |
| B3-L21 | pass | findings/evidence/cov3-ios/B3-L21/ | Doctor and refusal use `iPhone 17` / `iOS 26.0`, never raw identifiers. |
| B3-L39 [ios] | pass | findings/evidence/cov3-ios/B3-L39/ | launched/installed carry appPath; skipped carries explicit null appPath. |
| B3-L43 [ios] | pass | findings/evidence/cov3-ios/B3-L43/ | Start JSON and session.json use documented iOS field names and aliases. |
| B3-L60 | pass | findings/evidence/cov3-ios/B3-L60/ | Idle duration-3 recording is exactly 3.000000 seconds by ffprobe. |
| N3-05 [ios] | pass | findings/evidence/cov3-ios/N3-05/ | Existing simulator reports `Reused cov3-ios-26 (…) — Booted` and its UDID. |
| N3-07 [ios] | pass | findings/evidence/cov3-ios/N3-07/ | Hierarchy and runner-dump JSON frame members are numeric. |
| N3-14 | pass | findings/evidence/cov3-ios/N3-14/ | QA-home sessions contain only campaign devices; owner-home capacity ledger is absent and was not created. |
| N3-04 [ios] | pass | findings/evidence/cov3-ios-attempt6/FALLBACK/, findings/evidence/cov3-ios-attempt2/N3-04/ | Omitted-scheme build/run/test calls, with only the safety-required owned simulator added, source `Landmarks (UI Testing)` from config and name U1/its UDID; explicit boot reports the same name/UDID and iOS 26.0. |
| MCP-031 [ios] | pass | findings/evidence/cov3-ios/MCP-031/ | Explicit `cov3-ios-26` build succeeds and returns scheme, simulator name/UDID, duration, warnings, errors and product. |
| IOS-112 | pass | findings/evidence/cov3-ios-attempt2/N3-04/ | Explicit owned simulator and requested scheme return `isError`; xcodebuild states that `Landmarks (UI Testing)` is not configured for the test action. |
| MCP-044 [ios] | pass | findings/evidence/cov3-ios-attempt3/MCP-044/ | With no runner session, context reports the configured `cov3-ios-26`, its exact UDID/runtime/state, config source, Xcode, and `No active session`; it does not select another booted simulator. |
| MCP-047 [ios] | pass | findings/evidence/cov3-ios-attempt3/MCP-047/ | With config, booted/all filters list simulator name, UDID, state, runtime, and availability. |
| MCP-048 [ios] | pass | findings/evidence/cov3-ios-attempt3/MCP-048/ | From an empty directory, booted/all filters still list simulator name, UDID, state, runtime, and availability without requiring config. |
| MCP-001 [ios] | pass | findings/evidence/cov3-ios-attempt4/MCP-001/ | Live-session default screenshot returns PNG image content; `format: file` writes `.grantiva/mcp-screenshot.png` and returns its path. |
| MCP-042 [ios] | pass | findings/evidence/cov3-ios-attempt4/MCP-042/ | Live context reports iOS config, exact owned simulator/UDID sourced from the runner session, Xcode, runner PID, WDA port, and bundle ID. |
| IOS-101 | pass | findings/evidence/cov3-ios-attempt4/IOS-101/ | With multiple simulators booted, live context selects the session's owned U1 and exact UDID rather than another booted device. |
| IOS-106 | pass | findings/evidence/cov3-ios-attempt4/IOS-106/ | MCP default screenshot returns base64 PNG image content and file format returns the saved PNG path. |
| X-019 [ios] | pass | findings/evidence/cov3-ios-attempt10/B2-K93/, findings/evidence/cov3-ios-attempt10/fail-default.err | Element-not-visible output names the failed step/message and prints the cross-platform hierarchy/MCP remediation line once. |
| X-020 [ios] | pass | findings/evidence/cov3-ios-attempt4/X-020/ | Live MCP context carries the configured platform and simulator plus the active runner's PID, port, bundle ID, and UDID. |
| MCP-029 [ios] | pass | findings/evidence/cov3-ios-attempt6/MCP-029/ | Omitted scheme is sourced from config; the safety-equivalent explicit owned simulator build succeeds with duration, warnings/errors, and product path. |
| MCP-034 [ios] | pass | findings/evidence/cov3-ios-attempt6/MCP-034/ | Omitted scheme is sourced from config; run builds, installs, launches, and reports scheme, bundle ID, simulator, and product path. |
| MCP-039 [ios] | pass | findings/evidence/cov3-ios-attempt6/MCP-039/ | Omitted scheme is sourced from config; test returns `isError` with xcodebuild's expected no-test-action reason. |
| MCP-009 [ios] | pass | findings/evidence/cov3-ios-attempt6/MCP-009/ | Tap opens Gesture Lab; left swipe returns a tree containing `Last swipe: left`; invalid `sideways` is an `isError` validation result. |
| MCP-017 [ios] | pass | findings/evidence/cov3-ios-attempt6/MCP-017/ | Live a11y tree returns JSON labels, element types, numeric frames, states, and visibility. |
| MCP-021 [ios] | pass | findings/evidence/cov3-ios-attempt6/MCP-021/ | Accessibility audit runs on the Landmarks list and Deep Links screen; both return a valid no-violations result. |
| MCP-076 [ios] | pass | findings/evidence/cov3-ios-attempt6/MCP-076/ | Ready live session resources return JSON hierarchy content and a base64 PNG blob with image/png MIME type. |
| IOS-099 | pass | findings/evidence/cov3-ios-attempt6/IOS-099/ | `tools/list` contains 22 tools both before and after runner start. |
| IOS-105 | pass | findings/evidence/cov3-ios-attempt6/IOS-105/ | Valid `up` swipe returns a tree containing `Last swipe: up`; invalid `sideways` returns `isError` and the accepted directions. |
| IOS-108 | pass | findings/evidence/cov3-ios-attempt6/IOS-108/ | Both live resources return their documented hierarchy JSON and PNG content. |
| IOS-109 | pass | findings/evidence/cov3-ios-attempt6/IOS-109/ | Live tree returns the Landmarks hierarchy and the list-screen audit completes successfully. |
| D2-44 [ios] | pass | findings/evidence/cov3-ios-attempt4/BATCH/, findings/evidence/cov3-ios-attempt6/D2-44/ | During startup both resources return the explicit starting JSON-RPC condition; once ready they return hierarchy JSON and PNG content. |
| CLI-048 | pass | findings/evidence/cov3-ios-attempt5/CLI-048/ | Relative `sub/flow.yaml` resolves from the config directory and passes; missing `sub/missing.yaml` fails validation and names the relative path. |
| CLI-049 | pass | findings/evidence/cov3-ios-attempt5/CLI-049/ | A→B→A fails promptly with `circular dependency detected: grantiva.yml -> a.yaml -> b.yaml -> a.yaml`; no hang. |
| CLI-061 | pass | findings/evidence/cov3-ios-attempt5/CLI-061/ | Parser/staging criterion only: report and runner log preserve `Mount "Denali" 🏔️` byte-for-byte. The deliberately nonexistent runtime target fails element lookup and is not claimed as an execution pass. |
| CLI-064 | pass | findings/evidence/cov3-ios-attempt5/CLI-064/ | Staged/executed flow distinguishes `tapOn: text="Favorites"` from `tapOn: id="heart"`; both execute and the flow passes. |
| CLI-066 | pass | findings/evidence/cov3-ios-attempt5/CLI-066/ | Bare scroll is emitted/executed as `scroll: DOWN`; explicit `{direction: up}` remains `scroll: up`; the flow passes. |
| IOS-102 | fail | findings/evidence/cov3-ios-attempt7/IOS-102/ | MCP label tap `Favorites` succeeds, but the required `heart` label/identifier fallback returns `Element not found: "heart"`; the later coordinate subcheck was not reached because the attempt's frame-label extraction also failed. |
| MCP-005 [ios] | pass | findings/evidence/cov3-ios-attempt7b/MCP-005/ | Label tap opens Gesture Lab; point `(201,495)` is derived from the live `Gesture pad` frame and its tap returns `Taps: 1` / `Last tap: center`. |
| IOS-103 | pass | findings/evidence/cov3-ios-attempt7b/IOS-103/ | Empty tap arguments return `isError` with the label-or-x/y requirement; the same server answers the following a11y-tree call. |
| D2-31 [ios] | pass | findings/evidence/cov3-ios-attempt7b/D2-31/ | CLI hierarchy, runner dump, and MCP tree are captured on the same Gesture Lab state with the same unwrapped tree shape, typed booleans, numeric complete frames, and element children. |
| B2-K99 [ios] | pass | findings/evidence/cov3-ios-attempt7b/B2-K99/ | CLI hierarchy, runner dump, and MCP tree all use the unwrapped top-level tree keys; no `value` or `sessionId` wrapper appears. |
| B2-K78 [ios] | fail | findings/evidence/cov3-ios-attempt8/B2-K78/ | `Favorites` label succeeds, but required MCP `heart` identifier fallback returns element-not-found. Later navigation can continue, but this acceptance criterion fails. |
| D2-36 [ios] | fail | findings/evidence/cov3-ios-attempt8/D2-36/ | The required label-order sequence fails on `heart`; MCP does not resolve the SF Symbol identifier after its label lookup. The attempt's separate Edit/Name precondition was also constructed incorrectly and is not graded. |
| MCP-013 [ios] | pass | findings/evidence/cov3-ios-attempt8b/MCP-013/ | With Name focused through the verified Deep Links/Edit Landmark route, typing ` Renamed` returns the updated tree with `Golden Gate Bridge Renamed`; an unfocused control call correctly errors first. |
| N3-11 [ios] | pass | findings/evidence/cov3-ios-attempt9b/N3-11/ | Bundleless copy has the exact QA hash and uses a scratch clone of the current runner home; real runner start on owned U1 warns exactly once about the missing bundle, succeeds with the installed runner, and its same-home stop succeeds without repeating the warning. |
| IOS-065 | pass | findings/evidence/cov3-ios-attempt10/IOS-065/, findings/evidence/cov3-ios-attempt10/fail-report/ | Default failure snapshot leaves exactly the failing-step screenshot in report assets and the exported failure capture. |
| IOS-066 | pass | findings/evidence/cov3-ios-attempt10/IOS-066/, findings/evidence/cov3-ios-attempt10/trailing-report/ | Trailing mode keeps last-good after and failing before/after shots; exported trace and report assets agree. |
| IOS-067 | pass | findings/evidence/cov3-ios-attempt10/IOS-067/, findings/evidence/cov3-ios-attempt10/full-report/ | Full mode keeps before/after trace shots for all eight steps; named screenshots remain separately exported. |
| IOS-070 | pass | findings/evidence/cov3-ios-attempt12/IOS-070/, findings/evidence/cov3-ios-attempt12/report-files.txt | Exact relative `out-pass` contains report JSON, flow data, JUnit, Allure assets and two named captures; the command exports screenshots there. |
| IOS-071 | pass | findings/evidence/cov3-ios-attempt12/IOS-071/ | Exact relative failing report contains no `/var/folders` path; report `sourceFile` and JUnit `file` preserve `.maestro/coverage/02-exact-negative.yaml`. |
| IOS-152 | pass | findings/evidence/cov3-ios-attempt12/IOS-152-stdout-sha256.txt, findings/evidence/cov3-ios-attempt12/IOS-152-plain/, findings/evidence/cov3-ios-attempt12/IOS-152-quiet/, findings/evidence/cov3-ios-attempt12/IOS-152-verbose/, findings/evidence/cov3-ios-attempt12/IOS-152-quiet-fail/ | Plain/quiet/verbose passing stdout is byte-identical; quiet stderr is empty on success but preserves the failure and hint; verbose adds timestamped subprocess commands and exits. |
| IOS-074 | pass | findings/evidence/cov3-ios-attempt10/IOS-074/, findings/evidence/cov3-ios-attempt10/pass-json.out, findings/evidence/cov3-ios-attempt10/fail-json.out | Pass/fail stdout each parse as one JSON object; failure has required result, failed-step, error and report fields and exit 1. |
| N-17 [ios] | pass | findings/evidence/cov3-ios-attempt10/N-17/, findings/evidence/cov3-ios-attempt10/pass-report/, findings/evidence/cov3-ios-attempt10/fail-report/ | Passing and failing step and flow durations agree between live lines, summaries and JSON at shared precision. |
| X-001 [ios] | pass | findings/evidence/cov3-ios-attempt10/X-001/, findings/evidence/cov3-ios-attempt10/pass-plain.out, findings/evidence/cov3-ios-attempt10/pass-plain.err | Passing text output has setup narration, flow count, per-step lines and summary using the iOS device name. |
| X-002 | pass | findings/evidence/cov3-ios-attempt10/pass-json.out, findings/evidence/cov3-ios-attempt10/fail-json.out, /Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-pass/stdout.log, /Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/output-contracts-exact-rerun1/JSON-fail/stdout.log | Corresponding iOS/Android passing and exact-negative JSON have identical top-level, flow and step key sets/types; both failure objects add the same error/message shapes and every reportDir is an absolute retained-report path. |
| X-003 [ios] | pass | findings/evidence/cov3-ios-attempt10/X-003/, findings/evidence/cov3-ios-attempt10/pass-report/ | Report contains report.json, `flows/flow-000.json`, and `junit-report.xml`; source path remains as passed. |
| IOS-045 | pass | findings/evidence/cov3-ios/FLOWS-26/01-selectors.out | Unicode arrow label taps and Yosemite Valley is asserted. |
| IOS-201 | pass | findings/evidence/cov3-ios/FLOWS-26/01-browse.out | Golden Gate Bridge opens and its location/detail controls are asserted. |
| IOS-075 | pass | findings/evidence/cov3-ios/FLOWS-26/10-lifecycle.out | `stopApp` before launch passes. |
| IOS-077 | pass | findings/evidence/cov3-ios/FLOWS-26/10-lifecycle-report/maestro-runner.log | Launch arguments reach the app as `argv=["--flag" "true"]`. |
| IOS-078 | pass | findings/evidence/cov3-ios/FLOWS-26/01-selectors.out, findings/evidence/cov3-ios/FLOWS-26/02-exact-negative.out | Regex passes, exact literal negative behaves correctly, and bare substring does not match. |
| IOS-202 | pass | findings/evidence/cov3-ios/FLOWS-26/01-selectors.out | Text selector taps the matching landmark. |
| IOS-203 | pass | findings/evidence/cov3-ios/FLOWS-26/01-selectors.out | Identifier assert and tap on `clock` pass. |
| IOS-204 | pass | findings/evidence/cov3-ios/FLOWS-26/01-selectors.out | Whole-value regex matches and bare `Lake` does not. |
| IOS-205 | pass | findings/evidence/cov3-ios/FLOWS-26/01-selectors.out | Regex/exact selector forms all produce the expected positive and negative matches. |
| IOS-206 | pass | findings/evidence/cov3-ios/FLOWS-26/02-exact-negative.out | Exact `Golden Gate.*` fails as a missing literal and exits nonzero. |
| IOS-207 | pass | findings/evidence/cov3-ios/FLOWS-26/01-selectors.out | Index 1 selects Mono Lake, proven by `Lee Vining, CA`. |
| IOS-208 | pass | findings/evidence/cov3-ios/FLOWS-26/04-point-taps.out | 50%,50% yields `Last tap: center` and `Taps: 1`. |
| IOS-209 | pass | findings/evidence/cov3-ios/FLOWS-26/04-point-taps.out | 100%,100% and 0%,0% point taps both pass. |
| IOS-210 | pass | findings/evidence/cov3-ios/FLOWS-26/03-gesture-lab-taps.out | Double tap increments `Double taps` without a second ordinary tap. |
| IOS-211 | pass | findings/evidence/cov3-ios/FLOWS-26/03-gesture-lab-taps.out | Long press increments `Long presses: 1`. |
| IOS-212 | pass | findings/evidence/cov3-ios/FLOWS-26/03-edit.out | Stock edit flow appends and asserts the renamed value. |
| IOS-213 | pass | findings/evidence/cov3-ios/FLOWS-26/15-input-unicode.out | Unicode location text appears unmangled. |
| IOS-214 | pass | findings/evidence/cov3-ios/FLOWS-26/01-selectors.out | Visible text, regex and identifier assertions pass. |
| IOS-215 | pass | findings/evidence/cov3-ios/FLOWS-26/05-category.out | Category flow's not-visible assertion passes. |
| IOS-216 | pass | findings/evidence/cov3-ios/FLOWS-26/05-swipe-forms.out | Direction swipes assert left/right/up/down results. |
| IOS-217 | pass | findings/evidence/cov3-ios/FLOWS-26/02-favorite.out | Element-origin row swipe exposes Remove and reaches empty favorites. |
| IOS-218 | pass | findings/evidence/cov3-ios/FLOWS-26/05-swipe-forms.out | Identifier-origin upward swipe reports up. |
| IOS-219 | pass | findings/evidence/cov3-ios/FLOWS-26/07-swipe-from-missing.out | Missing origin fails with `Element not found for swipe` and nonzero exit. |
| IOS-220 | pass | findings/evidence/cov3-ios/FLOWS-26/05-swipe-forms.out | Percent start/end swipe reports left. |
| IOS-221 | pass | findings/evidence/cov3-ios/FLOWS-26/06-swipe-absolute.out | Absolute point swipe lands and reports left. |
| IOS-222 | pass | findings/evidence/cov3-ios/FLOWS-26/05-swipe-forms.err | 1500 ms swipe registers left with expected slow duration. |
| IOS-223 | pass | findings/evidence/cov3-ios/FLOWS-26/10-seed-many.out | Four bare scrolls reach and assert Landmark 30. |
| IOS-224 | pass | findings/evidence/cov3-ios/FLOWS-26/08-scroll.out | Both down-to-70 and up-to-Golden-Gate searches pass. |
| IOS-225 | pass | findings/evidence/cov3-ios/FLOWS-26/14-runflow.out | Both string and file object sub-flow references execute nested steps. |
| IOS-226 | pass | findings/evidence/cov3-ios/FLOWS-26/14b-runflow-inline.err | Inline commands execute as nested steps. |
| IOS-227 | pass | findings/evidence/cov3-ios/FLOWS-26/11-slow.out | Delayed content becomes visible within the flow timeout. |
| IOS-079 | pass | findings/evidence/cov3-ios-attempt13/IOS-079/ | Default recording writes `.grantiva/recordings/recording.mov`, copied into evidence, and exits 0. |
| IOS-080 | pass | findings/evidence/cov3-ios-attempt13/IOS-080/ | Recording succeeds to the explicitly spaced `cov rec/a.mov` path. |
| IOS-081 | pass | findings/evidence/cov3-ios-attempt13/IOS-081/ | Exactly four PNGs are extracted for requested timestamps 0, 150, 300 and 2900 ms. |
| IOS-082 | pass | findings/evidence/cov3-ios-attempt13/IOS-082/ | Timestamp 5000 ms against duration 2 exits 64 with the precise past-duration error. |
| IOS-083 | pass | findings/evidence/cov3-ios-attempt13/IOS-083/ | JSON is valid and includes video, simulator/UDID, and requested/actual milliseconds for both frames. |
| IOS-137 | pass | findings/evidence/cov3-ios-attempt13/IOS-137/ | With stderr redirected away, stdout begins `Recording:` and the recording succeeds. |
| IOS-154 | pass | findings/evidence/cov3-ios-attempt13/IOS-154/ | Plain/quiet/verbose JSON stdout hashes are identical; quiet retains the warning, and verbose adds timestamped subprocess and metadata diagnostics. |
| IOS-085 | pass | findings/evidence/cov3-ios-attempt14/IOS-085-tree/, findings/evidence/cov3-ios-attempt14/IOS-085-json/, findings/evidence/cov3-ios-attempt14/IOS-085-xml/, findings/evidence/cov3-ios-attempt14/IOS-085-port/ | Tree, JSON, XML, `-f`, and explicit recorded `-p 8511` forms each return a nonempty hierarchy. |
| IOS-138 | pass | findings/evidence/cov3-ios-attempt14/IOS-138-start/, findings/evidence/cov3-ios-attempt14/IOS-138-stop/ | JSON start and stop both parse and carry documented iOS session fields/statuses. |
| IOS-140 | pass | findings/evidence/cov3-ios-attempt14/IOS-084/, findings/evidence/cov3-ios-attempt14/IOS-140-json/, findings/evidence/cov3-ios-attempt14/IOS-087/ | Documented start, JSON hierarchy, stop sequence succeeds on owned U1. |
| IOS-228 | pass | findings/evidence/cov3-ios/FLOWS-26/09-waits.out | notVisible wait passes after loading ends. |
| IOS-229 | pass | findings/evidence/cov3-ios/FLOWS-26/09-waits.out | Bare and timeout animation waits pass. |
| IOS-230 | pass | findings/evidence/cov3-ios/FLOWS-26/01-browse.out | Bare launchApp passes and the app screen is asserted. |
| IOS-231 | pass | findings/evidence/cov3-ios/FLOWS-26/10-lifecycle.out | clearState removes the just-created favorite and the empty state is asserted. |
| IOS-232 | pass | findings/evidence/cov3-ios/FLOWS-26/11-launch-environment.out | Step environment reaches the app as `from step`; header value is absent. |
| IOS-233 | pass | findings/evidence/cov3-ios/FLOWS-26/10-lifecycle.out | Consecutive stopApp steps are idempotent. |
| IOS-234 | pass | findings/evidence/cov3-ios/FLOWS-26/10-lifecycle.out | killApp followed by launchApp restores the Featured screen. |
| IOS-235 | pass | findings/evidence/cov3-ios/FLOWS-26/07-deeplink.out | Screenshot step with spaced name passes. |
| IOS-236 | pass | findings/evidence/cov3-ios/FLOWS-26/09-seed-empty.out | Header environment seeds the empty state asserted by the flow. |
| IOS-237 | pass | findings/evidence/cov3-ios/FLOWS-26/16-setpermissions.out | setPermissions and following bare scroll both pass. |
| IOS-238 | pass | findings/evidence/cov3-ios/FLOWS-26/10-lifecycle-report/maestro-runner.log | Arguments reach the app as `argv=["--flag" "true"]`. |
| IOS-239 | pass | findings/evidence/cov3-ios/IOS-151/ | Maps prompt is auto-accepted, narrated, recorded in notes, and the flow passes. |
| B-A02.2 [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/02-favorite.out, findings/evidence/cov3-ios/FLOWS-27/02-favorite.out | Element-origin left swipe reveals Remove and the flow passes on both runtimes. |
| B-C10.1 [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/16-setpermissions.out | setPermissions and bare scroll both pass. |
| B-C22.1 | pass | findings/evidence/cov3-ios/IOS-010/sessions-json.out | `acquiredAt` values are ISO-8601 strings. |
| B-I14.1 | pass | findings/evidence/cov3-ios/IOS-013/ | Timed-out capacity request leaves no new device or ledger entry. |
| B-R01.4 | pass | findings/evidence/cov3-ios/IOS-117/, findings/evidence/cov3-ios/IOS-118/ | Stock set is 12/12 on both runtimes. |
| B-R02.6 [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/02-favorite.out, findings/evidence/cov3-ios/FLOWS-27/02-favorite.out | Favorite/swipe flow passes on both runtimes with bundled `.13` runner. |
| N-11 [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/04-point-taps.out | 100%,100% and 0%,0% taps land without bounds errors. |
| N-18 | pass | findings/evidence/cov3-ios/IOS-117/stock-26.err, findings/evidence/cov3-ios/IOS-118/stock-27.err | Cache-hit narration appears once per session with no build narration. |
| N-10 | pass | findings/evidence/cov3-ios/FLOWS-26/02-favorite-report/maestro-runner.log | Runner report identifies WDA driver for the stock favorite flow. |
| X-015 [ios] | pass | findings/evidence/cov3-ios/IOS-010/sessions-json.out | Session records contain acquiredAt, ownership, state, name and UDID fields. |
| B2-K01 [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/, findings/evidence/cov3-ios/FLOWS-27/ | Step descriptions preserve index, point and start/end parameters identically on both runtimes. |
| B2-K13 | pass | findings/evidence/cov3-ios/IOS-117/ | Combined run announces five screens then twelve flows once and reports both totals. |
| B2-K110 | pass | findings/evidence/cov3-ios/FLOWS-26/02-favorite-report/report.json | Report identifies the WDA driver. |
| B2-K74 | pass | findings/evidence/cov3-ios/FLOWS-26/10-lifecycle-report/maestro-runner.log, findings/evidence/cov3-ios/FLOWS-27/10-lifecycle-report/maestro-runner.log | Arguments are argv only (`env=map[]`) on both runtimes and the flow passes. |
| B2-K76-a [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/08-scroll.err, findings/evidence/cov3-ios/FLOWS-26/09-waits.err | Slow passed steps use checkmarks and slow suffixes, never unexplained warning glyphs. |
| B2-K76-b | pass | findings/evidence/cov3-ios/FLOWS-26/08-scroll-report/maestro-runner.log, findings/evidence/cov3-ios/FLOWS-27/08-scroll-report/maestro-runner.log | Per-iteration timing is logged and both searches finish under the row limit. |
| B2-K77 | pass | findings/evidence/cov3-ios/FLOWS-26/10-lifecycle-report/maestro-runner.log | clearState is narrated as uninstall/reinstall and the cleared state is asserted. |
| B2-K91 | pass | findings/evidence/cov3-ios/IOS-151/ | Accepted alert appears under the step and in report notes. |
| B2-K98 | pass | findings/evidence/cov3-ios/IOS-117/stock-26.err, findings/evidence/cov3-ios/IOS-118/stock-27.err | Exactly one cache-hit line per session; no build line. |
| N2-14 [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/08-scroll.err, findings/evidence/cov3-ios/FLOWS-27/08-scroll.err, findings/evidence/cov3-ios/FLOWS-26/09-waits.err | Searches finish under 10 s; slow pass suffix is explicit and no warning glyph appears. |
| B2-K22 [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/14b-runflow-inline.err | Inline runFlow commands are accepted and nested steps execute. |
| B2-K75 | pass | findings/evidence/cov3-ios/FLOWS-26/07-swipe-from-missing.err, findings/evidence/cov3-ios/FLOWS-27/07-swipe-from-missing.err | Both runtimes say `Element not found for swipe` with the missing selector. |
| B2-K105 [ios] | pass | findings/evidence/cov3-ios/FLOWS-26/14-runflow.out | User-written relative sub-flow name is preserved; no rewritten absolute path. |
| N2-12 | pass | findings/evidence/cov3-ios/IOS-151/ | Accepted system alert is narrated and recorded as a step note. |
| IOS-202 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/01-selectors.out | Text selector repeat passes. |
| IOS-201 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/01-browse.out | Browse/tap repeat passes. |
| IOS-203 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/01-selectors.out | Identifier selector repeat passes. |
| IOS-204 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/01-selectors.out | Regex selector repeat passes. |
| IOS-205 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/01-selectors.out | Exact selector repeat passes. |
| IOS-206 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/02-exact-negative.out | Exact negative repeat fails as expected. |
| IOS-207 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/01-selectors.out | Indexed selector repeat passes. |
| IOS-208 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/04-point-taps.out | Center point repeat passes. |
| IOS-209 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/04-point-taps.out | Edge point repeat passes. |
| IOS-210 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/03-gesture-lab-taps.out | Double-tap repeat passes. |
| IOS-211 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/03-gesture-lab-taps.out | Long-press repeat passes. |
| IOS-212 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/03-edit.out | Edit/input repeat passes. |
| IOS-213 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/15-input-unicode.out | Unicode input repeat passes. |
| IOS-214 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/01-selectors.out | Assertion forms repeat passes. |
| IOS-215 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/05-category.out | not-visible repeat passes. |
| IOS-216 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/05-swipe-forms.out | Direction swipe repeat passes. |
| IOS-217 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/02-favorite.out | Element-origin swipe repeat passes. |
| IOS-218 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/05-swipe-forms.out | ID-origin swipe repeat passes. |
| IOS-219 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/07-swipe-from-missing.out | Missing-origin negative repeat behaves as expected. |
| IOS-220 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/05-swipe-forms.out | Percent swipe repeat passes. |
| IOS-221 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/06-swipe-absolute.out | Absolute swipe repeat passes. |
| IOS-222 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/05-swipe-forms.err | Duration swipe repeat passes. |
| IOS-223 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/10-seed-many.out | Bare scroll repeat passes. |
| IOS-224 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/08-scroll.out | scrollUntilVisible repeat passes. |
| IOS-225 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/14-runflow.out | File sub-flow repeat passes. |
| IOS-226 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/14b-runflow-inline.err | Inline sub-flow repeat passes. |
| IOS-227 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/11-slow.out | Delayed wait repeat passes. |
| IOS-228 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/09-waits.out | notVisible wait repeat passes. |
| IOS-229 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/09-waits.out | Animation wait repeat passes. |
| IOS-230 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/01-browse.out | Bare launch repeat passes. |
| IOS-231 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/10-lifecycle.out | clearState repeat passes. |
| IOS-232 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/11-launch-environment.out | Launch environment repeat passes. |
| IOS-233 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/10-lifecycle.out | stopApp repeat passes. |
| IOS-234 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/10-lifecycle.out | kill/relaunch repeat passes. |
| IOS-235 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/07-deeplink.out | Screenshot repeat passes. |
| IOS-236 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/09-seed-empty.out | Header env repeat passes. |
| IOS-237 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/16-setpermissions.out | Permissions repeat passes. |
| IOS-238 @27.0 | pass | findings/evidence/cov3-ios/FLOWS-27/10-lifecycle-report/maestro-runner.log | Argument argv repeat passes. |

| MCP-025 | pass | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt | A ready live session runs the validated four-step Gesture Lab script in order and returns a final tree; the no-focus script stops at step 2, and the malformed two-step request is rejected before execution with both invalid steps named. |
| MCP-078 | fail | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt | Missing-label failure is an `isError` result and six of seven session tools return `isError` after app termination, without JSON-RPC errors. `grantiva_screenshot` instead returns an image after the app is killed, so the matrix's literal every-session-tool expectation is not met. This remains a triage failure because a stopped app can still have a valid device screenshot. |
| MCP-080 | pass | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt | The MCP server starts before the session, attaches on the first tree call after detached start, and reattaches after stop/start replacement; both live trees succeed. |
| B-C11.2 | pass | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt | All seven session-dependent tools initially return the required no-active-session `isError`; after a session is started in the same scratch cwd, the next tree call attaches successfully. |
| B-C17.1 | pass | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt | Repro returns `isError`, names malformed steps 1 and 2 and states that no steps ran; a valid four-step script succeeds immediately beforehand. |
| B-C21.2 | pass | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt | Missing label returns an `isError` tool result with `Element not found`, rather than a JSON-RPC error. |
| D2-37 | pass | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt | Exact direct and scripted no-focus messages are returned as `isError`, and the script identifies step 2 plus the step that ran. |

| IOS-134 | pass | findings/evidence/cov3-ios-attempt17/04-fail-run.out | The Broken screen fails, is reported, and the configured 01-browse flow still runs all eight steps to completion under `--continue-on-failure`; command exits 1. |
| IOS-135 | pass | findings/evidence/cov3-ios-attempt17/07-slow-timeout.out | The 45-second screen wait is killed with the explicit 30-second message; wall time is 35 seconds including setup and the command exits 1. |
| IOS-141 | pass | findings/evidence/cov3-ios-attempt17/01-steps-json.out, findings/evidence/cov3-ios-attempt17/02-steps-verbose.out | All documented path forms execute and six named screens are captured; JSON records each action and duration. |
| IOS-142 | pass | findings/evidence/cov3-ios-attempt17/03-maestro-verbose.out | Maestro-format config accepts all steps and produces the two named `takeScreenshot` captures. |
| MCP-068 | pass | findings/evidence/cov3-ios-attempt18/mcp/transcript.txt | Live-session VRT refuses before execution at the runFlow step and explicitly directs the caller to stop the runner or use CLI capture. |
| B-A13.1 | pass | findings/evidence/cov3-ios-attempt17/01-steps-json.out | Regex, exact negative, exact tap and exact visible selectors all execute successfully; JSON labels exact forms explicitly. |
| B-C04.2 | pass | findings/evidence/cov3-ios-attempt17/04-fail-run.out, findings/evidence/cov3-ios-attempt17/07-slow-timeout.out | Continue-on-failure reports the failed screen then completes the configured flow; timeout kills the 45-second screen at the stated 30-second cap. |
| B-C07.1 | pass | findings/evidence/cov3-ios-attempt17/03-maestro-verbose.err | Maestro standard forms parse, reach the owned device, and complete the runner flow. |
| B-C08.1 | pass | findings/evidence/cov3-ios-attempt17/03-maestro-verbose.out, findings/evidence/cov3-ios-attempt17/03-maestro-verbose.err | Generated execution and summary retain `id=clock`; both tap and assertion labels identify the id selector. |
| B-C09.1 | pass | findings/evidence/cov3-ios-attempt17/01-steps-json.out, findings/evidence/cov3-ios-attempt17/02-steps-verbose.err | The configured wait records duration 3.0 seconds in JSON and live runner output. |
| B-C09.2 | pass | findings/evidence/cov3-ios-attempt17/02-steps-verbose.err, findings/evidence/cov3-ios-attempt17/03-maestro-verbose.err | Screens `wait: 3` becomes an unconditional 3.0-second Wait step, while Maestro `waitForAnimationToEnd` remains its own settle-wait command. |
| B-C15.2 | pass | findings/evidence/cov3-ios-attempt17/02-steps-verbose.out | Mixed-case UP/DOWN/Left/right directions all execute successfully. |
| B-R03.2 | pass | findings/evidence/cov3-ios-attempt17/04-fail-run.out, findings/evidence/cov3-ios-attempt17/07-slow-timeout.out | Device confirmation shows a 30-second screens cap and continuation from a reported screen failure into the configured flow. |
| B2-K102 | pass | findings/evidence/cov3-ios-attempt16c/mcp/transcript.txt, findings/evidence/cov3-ios-attempt18/mcp/transcript.txt, findings/evidence/cov3-ios-attempt18/round3-source-coverage-map.md | No-focus direct and scripted typing return actionable tool errors and stop at the named step; focused direct and four-step scripted typing both succeed and return updated trees. The copied exact-head source map identifies the required MCP and transport tests for iOS and Android no-key behavior. |

| IOS-084 | pass | findings/evidence/cov3-ios-attempt20/01-start.out, findings/evidence/cov3-ios-attempt20/state-during-start/ | Detached start prints the log/session metadata; the exact U1 lease claim exists during the session, names runner PID 44188, the owned UDID and scratch project, and records `handedOff: true`. |
| IOS-087 | pass | findings/evidence/cov3-ios-attempt20/04-stop.out, findings/evidence/cov3-ios-attempt20/state-after-stop/ | Stop reports the recorded runner stopped, removes the project session/owner files, and the exact U1 runner lease is absent afterward. |
| IOS-094 | pass | findings/evidence/cov3-ios-attempt19/04-threshold-default.out, findings/evidence/cov3-ios-attempt19/05-threshold-pixel-raised.out, findings/evidence/cov3-ios-attempt19/06-threshold-both-raised.out | Clock change fails perceptual distance at the default thresholds; raising pixel threshold alone still fails on perceptual 69.3 > 5.0; raising both to pixel 100% and perceptual 80 passes all six. |
| B-I03.1 | pass | findings/evidence/cov3-ios-attempt19/07-stale-initial-capture.out, findings/evidence/cov3-ios-attempt19/08-stale-failing-capture.err, findings/evidence/cov3-ios-attempt19/09-stale-compare.err | After a preserved successful capture, the failing capture clears the capture set; compare exits non-zero with `No captures found` and reports no screen passed. |
| IOS-146 | pass | findings/evidence/cov3-ios-attempt19/07-stale-initial-capture.out, findings/evidence/cov3-ios-attempt19/08-stale-failing-capture.err, findings/evidence/cov3-ios-attempt19/09-stale-compare.err | A Home-only capture succeeds; the replaced two-screen config fails at Broken; compare exits 1 and explicitly refuses because no complete captures remain, rather than passing stale Home bytes. Per-stage snapshots preserve each artifact state. |

| N2-11 | pass | findings/evidence/cov3-ios-attempt21/05-session-capture.out, findings/evidence/cov3-ios-attempt21/06-stop.out, findings/evidence/cov3-ios-attempt18/mcp/transcript.txt | After proven hierarchy readiness, stock `diff capture --no-build` uses the live owned session and captures 5/5; stop still reports the session stopped. The steps config's live-session runFlow case is refused before execution with the required stop/CLI guidance. |
| B2-K16 | pass | findings/evidence/cov3-ios-attempt21/01-start.out, findings/evidence/cov3-ios-attempt21/04-start-already-running.out, findings/evidence/cov3-ios-attempt21/06-stop.out, findings/evidence/cov3-ios-attempt18/round3-source-coverage-map.md | Started, already-running and stopped JSON all use numeric pid/port and consistent iOS bundleId/udid keys. Exact-head JSON contract tests cover the platform key sets. |

| MCP-065 | pass | findings/evidence/cov3-ios-attempt22/mcp/transcript.txt | With no live session, MCP capture honors configured campaign-owned cov3-ios-26 and returns three successful screens with JSON-equivalent metadata and measured steps. |
| MCP-070 | pass | findings/evidence/cov3-ios-attempt22/mcp/transcript.txt | Compare returns per-screen status plus pixel and perceptual thresholds/metrics; new, partial-baseline, and all-passing states are observed. |
| MCP-073 | pass | findings/evidence/cov3-ios-attempt22/mcp/transcript.txt | `{screens:["Home"]}` approves only Home and the next compare leaves the other two new; `{}` approves all three and the final compare passes all. |

| B2-K05 [ios] | pass | findings/evidence/cov3-ios-attempt10/B2-K05/, findings/evidence/cov3-ios-attempt10/pass-report/, findings/evidence/cov3-ios-attempt10/fail-report/, findings/evidence/cov3-ios-attempt10/B2-K05-source/exact-head-test.txt | Passing and failing live lines, summaries and report JSON agree at displayed precision. Exact runner fd9d8e8 test semantics use one measured duration source for live/report and explicitly exclude the 300 ms failure-artifact delay from step duration while including setup in the flow total. |

| B2-K81 [ios] | pass | findings/evidence/cov3-ios-attempt10/full-report/, findings/evidence/cov3-ios-attempt10/trailing-report/, findings/evidence/cov3-ios-attempt23/fail-failure-report/, findings/evidence/cov3-ios-attempt23/03-fail-trailing-ephemeral.err, findings/evidence/cov3-ios-attempt23/ios-composite-source-evidence.md | Full retains every trace step; trailing retains the last-good after and failing before/after; failure mode retains only its failure capture; no-report trailing exposes the same visible run-captures behavior without a temp report path. Retained report/Allure references resolve, and exact-head trace-export tests pin the trimming/reference semantics. |
| B2-K82-a [ios] | pass | findings/evidence/cov3-ios-attempt10/full-report/, findings/evidence/cov3-ios-attempt23/pass-trailing-report/, findings/evidence/cov3-ios-attempt23/01-pass-trailing.out, findings/evidence/cov3-ios-attempt23/ios-composite-source-evidence.md | Both full and trailing passing browse runs list exactly the two named takeScreenshot captures outside `captures/trace`; per-step before/after shots remain only under trace. Exact-head collector fixture pins named-screen filtering rather than artifact globbing. |

| IOS-114 | pass | findings/evidence/cov3-ios-attempt24/mcp/transcript.txt, findings/evidence/cov3-ios-attempt24/mcp/shell-01.exit.txt | The literal screen name `Home; touch /tmp/pwn` is treated as one unavailable capture name, returns an `isError` result, and the immediate shell check proves `/tmp/pwn` was not created. The server answers subsequent requests. |

| B-I02.3 | pass | findings/evidence/cov3-ios-attempt22/mcp/transcript.txt, findings/evidence/cov3-ios-attempt22/preserved-project-grantiva/ | With no live session, MCP VRT capture resolves the config's `simulator: cov3-ios-26`, captures three screens, and returns simulator name, exact owned U1 UDID, and dimensions. |
| B-I03.2 | pass | findings/evidence/cov3-ios-attempt19/07-stale-initial-capture.out, findings/evidence/cov3-ios-attempt19/08-stale-failing-capture.err, findings/evidence/cov3-ios-attempt19/09-stale-compare.err | Per-stage snapshots show the successful Home capture existed before the new run, the failing capture removed the usable capture set at its start, and compare refuses with `No captures found`; stale success cannot be accepted. |

| IOS-115 | pass | findings/evidence/cov3-ios-attempt24b/mcp/transcript.txt | Empty sim ensure, type, swipe, script and emulator ensure calls name `name`, `text`, `direction`, `steps` and `name` respectively; the unknown tool is named. Intervening and final `tools/list` calls all succeed. |
| IOS-116 | pass | findings/evidence/cov3-ios-attempt24b/harness.sh, findings/evidence/cov3-ios-attempt24b/mcp/transcript.txt | Both config files are present, runner start and MCP both explicitly select iOS, bounded readiness succeeds on exact owned U1, and live script/type calls drive that simulator before same-project stop. |

| B-C06.1 | pass | findings/evidence/cov3-ios-attempt4/BATCH/mcp/transcript.txt | During the live session, context reports simulator and runner-session UDIDs both as exact owned U1 and labels the simulator source `runner session`; the earlier no-session context explicitly says `No active session` and labels its configured-device source. |

| IOS-104 | pass | findings/evidence/cov3-ios-attempt24b/mcp/stdout.raw | Exact `text: "Yosemite"` succeeds; the complete raw JSON response returns the updated tree and its focused Name text field has value `Golden Gate BridgeYosemite`. |
| B-I06.1 | pass | findings/evidence/cov3-ios-attempt24b/mcp/stdout.raw | The live `grantiva_type` response says it typed `Yosemite`, returns the updated tree, and the complete raw hierarchy contains that text in the focused text-field value. |

| B-C03.1 | pass | findings/evidence/cov3-ios-attempt25/mcp-b/transcript.txt, findings/evidence/cov3-ios-attempt25/a-still-live.json | Project B explicitly refuses to attach and says the keep-alive session from another project was ignored. Its context reports no active session; a subsequent direct U1 hierarchy proves project A remained live and B did not disrupt it. |

| IOS-021 | pass | findings/evidence/cov3-ios-attempt26/01-build-explicit.out, findings/evidence/cov3-ios-attempt26/01-build-explicit.exit.txt | Explicit UI Testing scheme and exact owned U1 build succeeds with exit 0. |
| IOS-022 | pass | findings/evidence/cov3-ios-attempt26/02-install-launch.out, findings/evidence/cov3-ios-attempt26/02-install-launch.exit.txt | Build/install succeeds, prints the bundle data container, and reports the app running on cov3-ios-26. |
| IOS-023 | pass | findings/evidence/cov3-ios-attempt26/03-install-no-launch-json.out, findings/evidence/cov3-ios-attempt26/post-no-launch-launchctl.txt | No-launch exits 0 with status, scheme, bundleId, appPath, dataContainerPath, simulator name and exact U1 UDID; the immediate launchctl inventory contains no app process. |
| IOS-024 | pass | findings/evidence/cov3-ios-attempt26/04-install-spaced-dd.out, findings/evidence/cov3-ios-attempt26/05-install-relative-dd.out, findings/evidence/cov3-ios-attempt26/derived-data-inventory.txt | Absolute path with spaces and project-relative path both succeed; JSON app paths and retained directory inventory prove products landed in each requested Derived Data tree. |
| IOS-025 | pass | findings/evidence/cov3-ios-attempt26/config-build-settings.yml, findings/evidence/cov3-ios-attempt26/06-flag-wins-dd.command.txt, findings/evidence/cov3-ios-attempt26/derived-data-inventory.txt, findings/evidence/cov3-ios-attempt26/postrun-override-proof/DROUND3-excerpt.txt | The CLI flag redirects products to `flag-derived-data` instead of the configured path, while the retained Xcode build request proves the other configured `OTHER_SWIFT_FLAGS=-DROUND3` setting remained. |
| IOS-026 | pass | findings/evidence/cov3-ios-attempt26/07-nonexistent-scheme.out, findings/evidence/cov3-ios-attempt26/07-nonexistent-scheme.exit.txt | Exit 1 clearly names NoSuchScheme and says the Landmarks project does not contain it. |
| IOS-027 | pass | findings/evidence/cov3-ios-attempt26/08-no-scheme-two-project-schemes.err, findings/evidence/cov3-ios-attempt26/config-no-scheme.yml | With scheme omitted from config and command, exit 1 says `No scheme specified` and lists both `Landmarks` and `Landmarks (UI Testing)`. |
| IOS-028 | pass | findings/evidence/cov3-ios-attempt26/09-install-by-name.out, findings/evidence/cov3-ios-attempt26/10-install-by-udid.out | Simulator name and exact UDID variants both exit 0 and report the same cov3-ios-26 name and U1 destination UDID. |

| B-A06.1 [ios] | pass | findings/evidence/cov3-ios-attempt27/interrupted.ready, findings/evidence/cov3-ios-attempt27/pass-ephemeral.ready, findings/evidence/cov3-ios-attempt27b/timeout.ready, findings/evidence/cov3-ios-attempt27b/timeout.err | Active SIGINT records group/flow `interrupted`; valid 30-second timeout kills the active long-wait runner and records group/flow `failed` with no running state; the passing ephemeral run has no reportDir key. |
| B-A06.2 [ios] | pass | findings/evidence/cov3-ios-attempt27/interrupted.ready, findings/evidence/cov3-ios-attempt27/interrupt.exit.txt, findings/evidence/cov3-ios-attempt27/signal-timing.json | SIGINT is sent while exact long-wait flow is active; the owned command exits 130 and its final ready file records both group and flow as `interrupted`, proving interruption state is written during termination rather than leaving the flow running. |
| B-C04.1 [ios] | pass | findings/evidence/cov3-ios-attempt27/pass-report.ready, findings/evidence/cov3-ios-attempt27/pass-report/ | The explicit report run exits 0, leaves report.json, JUnit, Allure assets and logs, and the ready file's exact reportDir matches the retained directory. |

| B-A04.1 [ios] | pass | findings/evidence/cov3-ios-attempt28/commands.txt, findings/evidence/cov3-ios-attempt28/capture-pngs/, findings/evidence/cov3-ios-attempt28/capture-01.sha256 | All ten explicit-U1 capture commands exit 0. Each preserved iteration's Deep Links PNG hash differs from its Home PNG hash; per-iteration checksum files retain all ten comparisons. |
| B-I04.1 [ios] | pass | findings/evidence/cov3-ios-attempt28/commands.txt, findings/evidence/cov3-ios-attempt28/discard-01.out, findings/evidence/cov3-ios-attempt28/discard-10.out | Ten exact discard-flow reruns exit 0; each keeps the app-owned unsaved-changes alert visible until the flow explicitly chooses Keep Editing and later Discard. |
| B-I04.2 [ios] | pass | findings/evidence/cov3-ios-attempt28/discard-01.out, findings/evidence/cov3-ios-attempt28/system-alert.out | The app-owned discard alert remains for explicit user action, while the Maps system permission flow passes and confirms `Allow Once` is no longer visible; this distinguishes system alert handling from app alert handling. |




## Honest current counts

Matrix base rows recorded: 218 of 478 (pass 208, fail 5, blocked 5, n/a 0). iOS 27.0 repeat lines: 39 pass. Handed CLI rows: 6 pass (CLI-048/049/061/064/066 and N3-11 [ios]). Unrun matrix base rows: 260. MCP-031's guarded no-device behavior is graded only by B3-L08.1/N3-13. Attempt 2's explicit-scheme build/run/test captures remain input-variation evidence; attempt 6 closes the omitted-scheme criteria using only the safety-required explicit owned simulator. Attempt 4's starting-resource responses combine with attempt 6's ready-resource responses for D2-44; other failed-starting calls are not graded. CLI-061 grades only byte-preserving parsing/staging; its intentionally absent runtime label is excluded from that verdict.

The stock and coverage batches may support additional matrix rows, but those rows remain unrun in this ledger until their exact input/expectation is mapped to raw output. No round-2 outcome is used as a round-3 verdict.
