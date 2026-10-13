# Task 8 tab-container regression helper review

## Verdicts

- **Spec: NEEDS CORRECTION.** The helper correctly adopts the ruling that every fresh UI Testing process starts on Landmarks and never claims Favorites survives process restart. However, its background/save path can itself trigger a fresh launch, its stock command is not bound to the required stock flows, and several required proofs are asserted more broadly than the captured evidence supports.
- **Quality: NEEDS CORRECTION.** Device ownership checks, protected-device exclusions, exact selector assertions, and the demo-only qualification are useful, but the current controller can either fail before the intended campaign or write `acceptance.json` with unsupported stock, persistence, provenance, and cleanup claims.

## Load-bearing findings

1. **The supposed same-process background/resume case restarts the runner and can relaunch/reset the UI Testing app.** `background_resume()` backgrounds the app, closes MCP, stops the runner, calls `simctl launch`, and then calls `runner start --bundle-id`. Existing UI Testing behavior resets Navigator on every app launch, and prior startup evidence shows runner startup can launch the app rather than merely attach to the existing process. The helper neither records nor requires a stable app PID across this sequence. Consequently `resume-favorites` may reset to Landmarks and fail, or a lifecycle variation could pass without proving same-process retention. Keep the runner/app process alive for the background/resume proof, restart only MCP if needed, and record the exact unchanged app PID before background and after activation. Test runner/app restart separately and require the ruled fresh-Landmarks result from both prior selections.

2. **Background save evidence does not establish that the two selections were saved.** `background_save()` requires only that `defaults read ... NavigatorState` returns nonempty bytes, then stores a SHA-256. It never decodes or validates the selected tab and never even requires the Favorites and Landmarks reads to differ. The live selection after activation can remain solely in memory while a stale/default preference value satisfies this check. Read the exact owned app preference artifact or otherwise decode the public defaults value, retain its bytes, and assert the saved selection corresponds to Favorites and Landmarks respectively. At minimum, prove the two state artifacts differ and bind each to the immediately preceding selected state.

3. **The stock campaign is neither provisioned nor enumerated.** The owned scratch projects currently contain only `grantiva.yml`, with no copied stock flow set/config. `grantiva run --no-build ...` therefore cannot be assumed to run the required browse, favorite, and edit flows. Even if it returns JSON, checking only `allPassed` permits an empty or different recipe to support `stockBrowseFavoriteEditFlows: true`. Before execution, copy or explicitly name the exact approved demo stock flows and config into attempt-local inputs, record their hashes, pass them explicitly, and assert the result/report contains the expected flow identities and counts for browse, favorite, and edit on each runtime.

4. **The supplied app is not cryptographically bound to demo commit `db6c2ea…`.** The helper verifies that `--commit` and the ownership JSON contain the expected string and that installed files match the supplied app. Those are caller-provided assertions; it never compares the supplied app manifest with `public-container-build/app-manifest.json`, its recorded app path/build identity, or another source-derived build manifest. A different app directory could pass while provenance says `db6c2ea…`. Bind the supplied app's complete manifest to the reviewed clean build evidence and retain that evidence in the attempt. Continue to qualify the run as demo-only on the retained CLI/runner.

5. **Success and failure cleanup do not prove the scoped runner/session/app state is gone.** The `finally` block closes MCP and calls `runner stop` only when the project session file still exists. It does not verify the recorded runner PID exited, remove PID-prefixed global session files, inspect the scoped home for a surviving runner, or handle a runner that survives after its project session disappears. It also leaves the app running and installed while the report describes no device cleanup. Record the exact runner and app PIDs, require project/global session and process absence after every stop, and perform bounded cleanup of the owned app/simulator state in `finally`; retain each cleanup command/result. Do not use broad process kills or global teardown.

6. **The symbol check is global rather than tied to the three tab buttons.** `tab_contract()` finds the three tab buttons by label/order, then independently searches every image in the hierarchy for `map`, `link`, and either heart symbol. Content images elsewhere can satisfy this while a tab item has the wrong symbol. Inspect each tab button's descendants and require Landmarks/map, Favorites/heart or heart.fill, and Deep Links/link on the corresponding buttons before claiming labels/order/symbols are preserved.

## Correctly represented behavior

- The expected demo commit, owned-runtime restriction to iOS 26.0/27.0, protected simulator exclusions, scratch-contained project/home, unset API key, CLI hash, installed-file equality, and demo-only old-candidate qualification are explicit.
- Cold launch requires Landmarks, an unselected real Favorites button with exact `identifier: heart`, literal-heart identifier annotation, a selected Favorites transition, and no second heart-identified node.
- Terminated relaunches are attempted from both prior selected states and correctly expect Landmarks after each fresh UI Testing launch. The helper does not claim persisted Favorites survives the intentional reset.
- The in-process navigation test reaches quoted `Mount "Denali"`, switches through Favorites, and requires the same Landmarks detail after returning.
- Missing `steps`, wrong-type `steps`, empty `steps`, unknown selector, literal labels, quoted labels, identifier matching, and placeholder matching are covered with exact or appropriately bounded assertions.
- The same script is runtime-gated for separate iOS 26.0 and 27.0 attempts; it does not treat the preliminary iOS 26 capture as full acceptance.

## Boundary

This was a read-only independent review of `task8-tab-container-regression.diff`, `tab_container_regression.py`, its preparation report, the public-container ruling, the original tab brief, and the cited preliminary/build evidence. I did not run the helper, tests, builds, MCP, simctl, or devices, and I made no changes outside this review report.

## Scoped correction re-review

- **Spec: NEEDS CORRECTION.** Findings 1–3 and 6 are resolved, and finding 5 has the required exact ownership cleanup mechanics. Finding 4 is resolved only for the now-superseded `public-container-build`: the helper hardwires that directory, its app path, manifest, and commit. The forthcoming safe-area build changes both app and commit, so the intended controller invocation will fail provenance checks or would require overwriting reviewed evidence. Accept an explicit reviewed build-evidence directory or manifest argument, then bind `--app` and `--commit` to that selected evidence. Require it to be the forthcoming `public-container-safearea-build` for the next campaign.
- **Quality: NEEDS CORRECTION.** Cleanup is exact and bounded, but it can mask the original test failure. The `finally` block catches only the first normal-stop error; later PID/process/session/app cleanup assertions and commands may raise while another exception is already active, replacing the primary diagnostic. The script also writes `acceptance.json` with `passed: true` before cleanup. Preserve the primary exception, collect every cleanup error while continuing safe cleanup, always write cleanup evidence, and raise cleanup failure only when there was no primary failure. Publish passing acceptance only after required cleanup succeeds, or make the pre-cleanup record explicitly provisional.

### Closed findings

- **Same-process background/resume — resolved.** The runner remains alive, only MCP reconnects, the app PID is recorded before and after activation, and equality is mandatory. Terminated relaunch remains separate and requires a new PID plus fresh Landmarks from both prior selections.
- **Saved Navigator state — resolved.** The helper reads the exact owned app preference plist, decodes `NavigatorState`, requires the expected `selectedTab`, retains raw and decoded evidence, and requires Favorites/Landmarks state hashes to differ.
- **Stock coverage — resolved.** The exact four attempt-local flows and runtime config are hash-bound, and `report.json` must contain exactly the four named passing flows with a nonempty 4/4 summary.
- **Current-build provenance — resolved for `public-container-build`.** The app file manifest, app path, source head, and built-source commit are cross-checked. The remaining issue is selecting the new safe-area build evidence without hardwiring or replacing this older reviewed directory.
- **Owned cleanup mechanics — resolved apart from exception precedence/publication timing.** Runner PIDs are verified against scoped home/device before exact SIGINT fallback; PID-prefixed global sessions and the owned project session are removed only for tracked PIDs; the app is terminated and optionally uninstalled; the simulator is retained for the controller.
- **Tab symbols — resolved.** Each expected symbol is now required within its corresponding tab button subtree.

No other load-bearing regression was identified in `task8-tab-container-regression-fix.diff`. The reviewed `port` field is valid for the ready session schema used by this CLI, and the exact flow names match the report format.

This was a read-only scoped diff review against `task8-tab-container-regression-fix-base`. I inspected the prepared flow/config identities and existing build evidence but did not execute the helper, tests, MCP, simctl, or devices.

## Scoped correction re-review — round 2

- **Spec: PASS.** The helper now requires explicit `--build-evidence`, restricts the next campaign to `public-container-safearea-build`, and binds the supplied app and commit to that directory's exact app manifest, recorded app path, source head, and built-source commit. The selected evidence and both safe-area ownership files agree on source `f6cdff54c0bed5632ce23bc1b528a2e7a33cb118` and the same built app path. The superseded `public-container-build` is no longer consulted or overwritten.
- **Quality: PASS.** Campaign failures retain their original exception and traceback. Cleanup proceeds through independently captured errors, writes cleanup evidence, and cannot replace an existing primary failure. Cleanup failure is raised only when the campaign itself had no primary failure, and `acceptance.json` is emitted only after the campaign and cleanup both succeed. No new load-bearing breakage was identified in the scoped fix-2 diff.

The current helper SHA-256 is `565a4818b5d412d143d2ae037e3b311d1c01ed77846ec79f9775d5c5ea88e26e`, matching the dispatched identity. The checked-in `task8-tab-container-regression-fix2.diff` and a freshly regenerated no-index diff both hash to `0215ee579738a2803738a461781b78b99b56e9be6afc21f7d9de5d9b9570a485`, which does not match the dispatched diff hash `89dc4900fc223d76a7fd5568ae8341b1013afc100e0eb2f4939269afa564f20b`. This metadata discrepancy does not change the verdict because the review compared the fix-2 baseline directly with the matching current helper; update any external record that expects the stale diff hash.

This was a read-only scoped review of fix 2 and the selected safe-area provenance artifacts. I did not execute the helper, tests, MCP, simctl, or devices.

## Scoped runtime-failure diagnosis — iOS 26 background save

**Diagnosis: CONTROLLER OBSERVATION IS TOO EARLY; NO PRODUCT DEFECT ESTABLISHED.** The failed full-helper attempt must remain failed and must not be promoted to acceptance. Its exact cleanup succeeded: app PID `93339` and runner PID `93009` were removed, project/global sessions were absent, and no cleanup error masked the original assertion.

The raw `POST /wda/homescreen` evidence proves that WDA accepted the public homescreen command and returned HTTP 200 with its session response. By itself, that response does not prove when `UIApplication.willResignActiveNotification` was delivered or when CFPreferences flushed its cache to the on-disk plist. The source does save synchronously into `UserDefaults.standard` when `willResignActiveNotification` arrives, but `UserDefaults.set` does not make a direct host-side read of the app-container plist an immediate synchronization contract.

The two reads discriminate the issue:

- At `1791916785`, about one second after the homescreen response, the copied preferences plist was `{}`, causing the helper's assertion and correctly halting the campaign.
- At `1791916825`, a read-only post-cleanup capture of the same exact app-data preferences path contained `NavigatorState` with `selectedTab: favorites` and three empty paths.

That later semantic value is consistent with the expected background save and shows that the missing immediate snapshot is insufficient evidence of a product failure. It also shows that eventual persistence is observable. It does not retroactively pass the halted attempt or prove the remaining campaign.

### Minimal discriminating probe

Use the same installed safe-area app, owned simulator, scoped runner home/project, and existing provenance. Start a fresh bounded attempt so the UI Testing launch clears prior `NavigatorState`, then keep the app and runner PIDs unchanged throughout each background cycle:

1. Record the empty baseline. On the Deep Links tab, invoke the existing **Clear Saved State** control, return to Favorites, and confirm the real `heart` tab button is selected.
2. Record the app PID, call the same WDA homescreen endpoint, reactivate the app, and require the same PID and Favorites selection.
3. Without another background transition, switch to Deep Links and invoke **Restore Navigation State**. Require it to return to Favorites. This is the load-bearing semantic proof that the lifecycle save occurred; it reads through the same in-process UserDefaults API rather than relying on plist flush timing.
4. Repeat from Landmarks: clear or overwrite the baseline deliberately, select Landmarks, background/reactivate with the same PID, switch to Deep Links, restore, and require Landmarks. Retain distinct before/after hierarchies and raw MCP streams.
5. As secondary diagnostics, poll both the exact app-container plist and a scoped simulator-domain defaults read at short bounded intervals, retaining every result. Do not make immediate plist materialization the acceptance gate; use it only to characterize flush latency. Require the semantic Restore result for each selection.

This probe preserves the ruling: background saves are verified where observable, in-process navigation/selection retention remains mandatory, and fresh process launches must still reset to Landmarks from both prior states. It does not claim persisted Favorites survives a UI Testing restart.

The helper should replace the immediate direct-plist assertion with the semantic restore proof above, while retaining eventual preference captures as provenance. The original `public-container-regression26` failure and cleanup records remain immutable.

This was a read-only diagnosis of the failed attempt and relevant demo source. I did not run a probe, MCP, simctl, tests, or devices, and I made no source or helper edits.

## Scoped observation-fix re-review — round 3

- **Spec: NEEDS ONE CORRECTION.** The immediate plist assertion is correctly removed from acceptance. Favorites and Landmarks now each require the expected selection after activation, the same app PID before background, after activation, and after restore, and a semantic restore through the app's existing state-restoration control. Timed plist and simulator-domain defaults reads are explicitly diagnostic only. This implements the runtime diagnosis without weakening fresh-launch Landmarks behavior. One load-bearing selector mismatch remains: the Deep Links SwiftUI button's accessibility label combines its title and subtitle, so the literal control label is `Restore Navigation State, Restores previously saved state`, not `Restore Navigation State`. The current discovery predicate and `grantiva_tap` call can fail before the semantic proof. Use the exact combined button label for both discovery and tap, and retain that literal in the proof record.
- **Quality: NEEDS ONE CORRECTION.** The bounded discovery loop and `grantiva_swipe` request use the correct tool and schema (`{"direction":"up"}`), retain each hierarchy/swipe result, and cannot scroll indefinitely. No other new breakage was identified. Correct the literal combined label before execution.

The new semantic sequence itself is valid: after background/reactivation it checks the expected current selection, moves to Deep Links without another background transition, invokes restore, and requires the saved selection to return while the exact app PID remains unchanged. The second cycle overwrites the first saved state with Landmarks, so it independently distinguishes both values. It does not claim Favorites survives process restart.

The current helper and fix-3 diff SHA-256 values match the dispatched identities: `25d1521abd8c9da673ee442c58ba12d99e5e0113e0ab6e044af344f2e257a24e` and `97d793bf5b843774b4cdc45a84848b0154e7fe312e7ccb3fc50cc9d9cb77eb98`.

This was a read-only scoped review of the round-3 diff and the existing Deep Links source. I did not run the helper, MCP, simctl, tests, or devices.

## Scoped literal correction re-review

- **Spec: PASS.** The sole round-3 blocker is resolved. Bounded hierarchy discovery and `grantiva_tap` now use the exact combined accessibility label `Restore Navigation State, Restores previously saved state`, and the semantic save/restore proof records the same literal.
- **Quality: PASS.** The diff adds one constant and replaces only the prior shortened discovery/tap/proof strings. The bounded swipe behavior, same-PID assertions, semantic Favorites/Landmarks restore checks, diagnostic-only preference polling, cleanup, and provenance remain unchanged. No new breakage was identified.

The current helper SHA-256 is `dd565024fd53f69ca31887acc12d9b4b9d2549e5caf7a133b82ecc30c83aaa9e`, matching the dispatched identity. This was a read-only scoped literal review; I did not run the helper, MCP, simctl, tests, or devices.
