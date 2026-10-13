# Task 5 — L65, L66, L80

Status: COMPLETE — independent source/fix1/demo review approved; final a485f7b6 passed1973tests and CI; CLI PR209 merged4231a01a and demo PR4 merged1552ae98. Detailed prior evidence and chronology below remain unchanged.

## Provenance / commits

CLI worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-mcp-wda`, branch `fix4/mcp-wda`, clean base `8f2cff676b3c12e951478920fa20e600cdca4e29`.

- `a6f0896c` — Serialize MCP responses and fix script and WDA selector contracts.
- `4978a9a7` — Align tap tool description with WDA identifier selection.
- **Final CLI head `62088d41`** — Preserve MCP framing through cancellation and transport failure.

Demo worktree `/private/tmp/grantiva-fix4-demo-selector`, branch `fix4/stable-tab-identifier`, base `75acc87b52c965246b0cf03ba4cd57fe4d44336b`.

- `4e3ecfd589be47e51441d0a92c98b4612ded1f70` — Give Favorites tab a stable accessibility identifier. Initial inner Label modifier passed immediately after installation but failed after relaunch; preserved as RED evidence.
- **Final demo head `19c1aada9c856479f0c29fbd51c029866ae2b3a9`** — Attach Favorites identifier to its tab content. Total diff from demo base is exactly one `.accessibilityIdentifier("heart")` line after Favorites `.tabItem`. Four durability cycles passed, including actual navigation in both selected/unselected states, app/runner restarts and post-stock cold restart.

Read task brief, plan Global Constraints, approved campaign design, binding L65/L66/L80 briefs, and implementer template. Controller approved minimal extra edits in `ValidatingTransport.swift` and public `UITools.swift` description. No subagents/reviewers dispatched. No protected/default devices or owner-home writes. Runner homes scoped; API key unset. All device operations identify the reserved device. No global teardown or process-pattern kills.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/fix4-5/`. Unit logs originally created in the task worktree were moved byte-for-byte to `unit/`; CLI worktree is clean at final head. Raw captures retained unchanged, including failed setup and fixture attempts.

## Final CLI implementation

1. Missing `steps` is separately rejected with exactly `Error: Invalid argument: 'steps' is required.` and `isError`. Wrong-type retains `Error: Invalid argument: 'steps' array is required.`; empty array returns hierarchy. ToolRegistry no-session precedence stays intact.
2. iOS label tap queries `label`, actual `identifier`, then `placeholderValue`. Existing application exclusion, literal escaping, click/error/retry behavior and winning-attribute annotation remain. Public docs and tool schema now name `identifier` correctly.
3. Every SDK response/notification and validation-generated error uses a common whole-message send gate in the existing `ValidatingTransport`. SDK dependency stays unchanged: `StdioTransport` 0.12.1 (`a0ae212ebf6eab5f754c3129608bc5557637e605`) writes a newline-framed buffer in partial writes and yields on EAGAIN; an actor alone permits interleaving at those suspension points. Grantiva now holds message ownership until send completes.
4. Cancellation/failure hardening: before starting a queued frame, check task cancellation and the protocol cancellation tracker. Keep protocol responses pending until they actually reach the write gate. Once a frame starts, retain an unstructured inner-write task so caller cancellation cannot truncate it. Explicit disconnect cancels that owned task, closes underlying I/O, and awaits termination. A real write failure leaves framing uncertain, so the transport is closed and every waiter is released with an error; no later frame is appended to the failed prefix. Deferred ownership transfer releases the queue on every path.

No change to dependency metadata or MCPServer construction is needed: production already constructs `ValidatingTransport(wrapping: StdioTransport())`.

Files changed from CLI base:
- `Sources/GrantivaCore/WDA/WDAClient.swift`
- `Sources/GrantivaMCP/Tools/ScriptTools.swift`
- `Sources/GrantivaMCP/Tools/UITools.swift`
- `Sources/GrantivaMCP/ValidatingTransport.swift`
- `Tests/GrantivaCoreTests/WDAClientTests.swift`
- `Tests/GrantivaMCPTests/MCPTransportTests.swift`
- `Tests/GrantivaMCPTests/ScriptToolsTests.swift`
- `Tests/GrantivaMCPTests/ToolErrorContractTests.swift`
- `docs/mcp.md`

## TDD / test evidence

Commands use `env -u GRANTIVA_API_KEY`, task session ID, and task-created empty `GRANTIVA_RUNNER_HOME`. Logs below are relative to evidence `unit/`.

- Baseline: `swift test --filter 'GrantivaMCPTests|WDAClientTests'`: **267 MCP + 25 WDA**, zero failures (`baseline.log`). Initial empty home `/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/fix4-mcp-wda-unit-9un0w4b9` remained empty.
- RED `swift test --filter GrantivaMCPTests`: **270 tests / 9 assertions failed** (4 marked unexpected because JSON parsing threw). Chunked large-response tests fail with `Badly formed object around line 1, column 4098`; script tests expose the extra `array` word, including both platform registries (`red-mcp.log`).
- RED `swift test --filter WDAClientTests`: **26 tests / 10 assertions failed**. Actual predicates query `name`; NSPredicate-based node matching picks lower-priority placeholder nodes for `heart` and quoted identifiers (`red-wda.log`). This checks real selected attributes/priority, not a stub's second response.
- GREEN same focused MCP/WDA command: **270 + 26 passed** (`green-focused.log`).
- Initial full `swift test`: **1,965 passed** (273 MCP / 948 Core / 643 CLI / 101 API), zero failures (`green-full.log`). Fresh home remained empty (`full-test-environment.json`). `swift build` passed (`build.log`).
- Schema wording follow-up: `swift test --filter UIToolsTests`: **37 passed**, fresh home empty (`schema-focused.log`, `schema-test-environment.json`).
- Gate hardening RED `swift test --filter MCPTransportTests`: **12 tests / 5 assertions failed** (`gate-red.log`). Cancelling the active partial write produces 51 bytes instead of 85; real partial failure permits a queued frame, producing 45 bytes instead of the stopped 8-byte prefix, with two underlying sends and no disconnect.
- Gate GREEN `swift test --filter 'MCPTransportTests|MCPCancellationTests'`: **13 transport + 5 existing cancellation tests passed** (`gate-green-final.log`). Controls cover active-write cancellation, queued task cancellation, queued protocol cancellation, real partial-write failure plus waiter release, and explicit disconnect of the retained write task. The suspension fixture pauses after exactly 8 bytes to avoid relying on OS pipe sizes. Existing cancellation suppression tests also pass.
- **Final full `swift test` on final CLI source: 1,970 passed (278 MCP / 948 Core / 643 CLI / 101 API), zero failures, exit 0** (`final-full.log`). Fresh home `/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/fix4-5-final-unit-_9v136vw` was `[]` before and after, API key absent, session `fix4-5` (`final-full-environment.json`). This second full run was controller-requested because cancellation semantics changed.

Transport integration regressions use the actual MCP Server and existing InMemoryTransport pair through ValidatingTransport. Ten mixed resource/tool pairs return 70,000-character strings. A yielding sink limits each underlying write to 4,096 bytes. Every newline is decoded; exact ID sets/counts and complete payloads are checked without ordering constraints. A second case adds ten small replies, ten real notifications, and ten validation-generated errors. Self-review: `git diff --check` passed; all normal, standalone validation and split-batch error paths share the gate. The transport test file is larger because fault/cancellation controls are colocated with the existing integration fixture; no source restructuring was added.

## Live environments / final CLI binary

Final live debug executable: `/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-mcp-wda/.build/debug/grantiva`, adjacent resource bundle. SHA256 `b5d53ae7b11da15acbb5a6256e039e724bb1e6f110394e2515558385ce363097` (`final-cli-sha256`). Frozen QA binary/home untouched.

Scratch `/private/tmp/grantiva-fix4-5.7th4H3`; APFS clone of owner's runner directory at `scratch/runner-home` (source read-only). Session ID `fix4-5`. Unit empty homes never substitute for this live clone.

- iOS: `fix4-5-ios-26`, UDID `4AB20A5D-520A-4EA3-97ED-D09D90DCE79D`, iOS26.0. Project `scratch/ios-project`. Original runner PID8270; final transport-retest runner PID16138; WDA8297. Further fixture-restart PIDs are recorded in corresponding start outputs. Final restart runner PID21826 (earlier fixture restart PID18867). Cleanup complete.
- Android: `fix4-5-android`, serial `emulator-5580`, emulator PID12409; runner PID14662. Project `scratch/android-project`. Before inventory and port probe proved reservation free. First avdmanager setup failed before creation because Java was unset; retained logs. Retry used scoped JAVA_HOME21 and succeeded. Existing demo APK path/hash recorded in `android-apk-sha256`.

## Binding live results on final CLI

**L65 complete on both platforms:** live ToolRegistry calls via MCP preserve exact missing/wrong-type/empty-array controls. No-session precedence separately verified. iOS final `ios-final-stable-selector/` and `ios-final-stable-selector-checks.json` pass missing/wrong/empty calls; earlier `ios-final-contracts/stdout.raw` also contains these calls before its later demo-selector failure; Android `android-final/`, `android-no-session/`. Initial iOS no-session `ios-no-session/`. Final CLI no-session cleanup control also passed (`ios-final-no-session/`, `ios-cleanup.json`).

**L80 complete on both platforms after hardening:**
- iOS `ios-final2-transport/` + `ios-final2-transport-checks.json`: **20/20 large response IDs**, **220,872–220,918 bytes each**, ten concurrent small responses and ten subscribed resource-updated notifications. Every raw stdout line is valid JSON; every ID exactly once, unconstrained completion order. First final attempt (`ios-final-transport/`) hit documented starting state before WDA had a session; retained unchanged. Readiness-gated second attempt passed.
- Android `android-final/` + `android-final-checks.json`: **20/20 large response IDs**, **69,270–69,317 bytes each**, ten small responses and ten subscribed notifications; all lines valid and IDs unique.
- Earlier successful iOS runs `ios-transport/` and `ios-stable-transport/` are supporting evidence, not substituted for final-code retests.

**L66 complete with final stable demo fixture:**
- Actual `heart.fill` identifier, script identifier tap, `Name` placeholder, exact annotations, quoted `Mount "Denali"`, application exclusion via Landmarks back button with same-named application root, and point-coordinate tap from live Favorites frame passed (`ios-selector-actual*`, `ios-before-app-exclusion.json`, `ios-coordinate-input.json`). Final transport scripts repeated application exclusion/coordinate controls.
- Live retry control passed through a local HTTP pass-through recorder forwarding to real WDA: exactly two `/elements` requests returning400, one second apart, final app-not-running error after1.0415s. Owned app explicitly terminated by UDID. Task-owned session JSON temporarily pointed at recorder, then restored byte-for-byte. `ios-retry-http.json`, `ios-retry-checks.json`, `ios-retry/`.
- Base demo75acc87 presents runtime identifier `heart.fill` for selected and unselected Favorites; literal `heart` queries fail. No production alias or relaxed contract added. Initial failures: `ios-selector/`, `ios-selector-complement/`, `heart-direct-predicates.json`; source snapshot `demo-ContentView.swift`.
- Controller approved separate demo hook to preserve literal contract. Read swiftui-specialist SKILL.md and modifiers reference. First modifier inside tab Label (`4e3ecfd`) passed selected/unselected/script/Name/quotes immediately after installation (`ios-stable-selector*`). Four stock flow controls passed: browse, favorite, edit, quoted label (`ios-stable-stock.out`, `ios-stable-stock-report/`).
- Additional final restart check caught literal-heart loss (`ios-final-contracts/`). Screenshot `ios-final-heart-failure.png`, direct queries `ios-final-heart-failure-direct.json`, and `ios-stable-foreground-diagnosis.json` show actual Landmarks foreground bundle/PID before and after explicit activation, but empty heart query. Installed debug dylib hash matches stable build, not baseline (`ios-post-stock-installed-build-identity.json`); executable shim hashes alone are insufficient. No false durability claim remains.
- Final demo follow-up `19c1aad` moves the same modifier from inside Label to the tab NavigationStack immediately after `.tabItem`. Rebuilt with `xcodebuild -project /private/tmp/grantiva-fix4-demo-selector/ios/Landmarks.xcodeproj -scheme "Landmarks (UI Testing)" -destination id=4AB20A5D-520A-4EA3-97ED-D09D90DCE79D -derivedDataPath /private/tmp/grantiva-fix4-5.7th4H3/StableDerivedData build CODE_SIGNING_ALLOWED=NO` (exact recorded build invocation/log: `stable2-app-build.log`). Selected and unselected literal-heart taps passed four cycles with actual tab selection values asserted: two app launch cycles, runner restart, then all four stock flows and a cold app+runner restart (`stable2_acceptance.py`, `ios-stable2-checks.json`, `stable3_acceptance.py`, `ios-stable3-checks.json`).
- Final demo stock command `grantiva run --no-build --platform ios --simulator 4AB20A5D-520A-4EA3-97ED-D09D90DCE79D --report-dir <evidence>/ios-stable3-stock-report --json`: all four browse/favorite/edit/quoted-label flows passed (`ios-stable3-stock.out`, report directory, exact command JSON). Config has no cached build product path; `--no-build` installed-code identity was checked before and after, both matching rebuilt debug dylib SHA256 `ab52887ac6b2a747dd1ec8af7c39284cf4f3971297caacc2669e9aca2cabea87` (`stable3-pre-stock-identity.json`, `stable3-post-stock-identity.json`).
- Final CLI and final demo full selector sequence passes label-without-annotation, literal `heart` selected/unselected with identifier annotation, script tap fallback, `Name` placeholder annotation, and quoted label (`ios-final-stable-selector/`, `ios-final-stable-selector-checks.json`). Hierarchies immediately before taps are retained. No product alias or contract relaxation was introduced. Demo self-review confirms only the one-line fixture hook remains against base and `git diff --check` passes.

## Cleanup / open criteria

Android cleanup complete: `android-cleanup.json` records runner stop0, emulator kill0, AVD delete0, emulatorPID12409 and serial absent, owned AVD absent, owner Pixel_8_API_35 preserved. Android slot released to controller.

iOS cleanup complete: `ios-cleanup.json` records runner stop0, final no-session precedence pass, scoped simulator shutdown0/delete0, owned UDID absent, every pre-existing simulator ID preserved, runner PIDs8270/16138/18867/21826 absent. `ios-cleanup-{before,after}-{devices,processes}.out` retain inventories. No remaining process command references the owned UDID, cloned runner home or task CLI binary. iOS slot released to controller. Scratch/evidence retained for review.

No open implementer live criteria. Both worktrees clean. Controller owns independent review, PR/CI, and merge. No criterion has been weakened or silently deferred.

Controller completion: see task-5-fix1-report.md, task-5-fix1-review.md and task-5-demo-final-review.md. Final CLI source a485f7b6; full suite1973pass; CI38409615340 SUCCESS; merged4231a01aedba3cffaaa27986b58cd7b0251af742. All owned devices cleaned, no release/tag.
