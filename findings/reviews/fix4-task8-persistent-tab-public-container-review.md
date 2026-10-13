# Task 8 public tab container independent review

Reviewed commit `db6c2ea1564a1aad6b311bd7278491c907c99db9`, draft PR 5, against original `1552ae983a27528eff4c1f8145aa075698b47f71` and failed prior `b7ed2d2e4e221fb1bd37517325ddde210a822afb`.

**Spec verdict: APPROVED for controller-owned runtime verification.** The source meets the revised public-container architecture requirements. Runtime acceptance remains open.

**Code quality verdict: APPROVED.** No actionable source defects found in the scoped or full baseline diff. This is a static review approval, not approval to merge or a claim that L66 is resolved.

## Review evidence

Read the public-container brief/report, original persistent-tab brief/report, both diffs, current ContentView/container, Navigator, app startup, service environment keys, and tab-view state/environment readers. Consulted [SwiftUI specialist skill](/Users/kyle/.agents/skills/swiftui-specialist/SKILL.md), including environment/dataflow guidance, and installed Xcode 27 UIKit headers. The SDK publicly exposes UITab accessibility identification, the tabs initializer and selectedTab, and the modern user-selection delegate.

- The controller creates and owns three public UITab objects once. Favorites receives literal `heart` before assignment to UITabBarController. No reliance remains on SwiftUI-owned tab model counts, ancestor attachment, private hierarchy mutation, or polling. The failed installer and its crash assertions are deleted.
- Typed UIHostingControllers are retained by the coordinator and returned by the stable UITab providers. Updates replace root values with the same concrete structure; they do not recreate hosts, tabs, or add identity-changing modifiers. This supports preserving local SwiftUI state and NavigationStacks; actual retention still needs runtime evidence.
- Each hosted root receives context.environment on creation and every update, preserving Navigator and service injection across the new hosting boundary. The same observable Navigator instance and key-path bindings remain; the removed ContentView service read was unused. No copied navigation model or frozen service snapshot is introduced.
- The latest selection binding is retained on each update. UIKit user selection writes it through the modern delegate; initial and subsequent programmatic/restored selections select the matching stable tab. Equality guards avoid redundant writes. Existing independent path bindings, screen destinations, URL handling, loadState, and saveState hooks remain intact.
- Tab order, titles and image names remain Landmarks/map, Favorites/heart, Deep Links/link. Existing screen implementations are unchanged. The content-level duplicate heart identifier is removed relative to the original baseline. No CLI contract changes or diagnostic logging appear.

## Retained build verification

Inspected `findings/evidence/fix4-5-tab/public-container-build/` without rerunning builds or tests. Final evidence identifies the reviewed commit with empty source status before/after commit. Exact argv runs clean/build for Landmarks (UI Testing), UITesting, generic iOS Simulator, dedicated fresh DerivedData, signing disabled. Environment records API key unset, scoped fresh runner home, and `GRANTIVA_SESSION_ID=fix4-5-tab`. Final UTC interval is 2026-10-13 18:24:29.820250 through 18:24:36.794274; exit is 0 and stdout contains BUILD SUCCEEDED. Stderr and runner-home listing are empty. No changed-file compiler warnings appear; existing service/cache and App Intents warnings remain outside this diff.

Independently recomputed all 165 retained source-manifest hashes and all five built-app hashes: zero mismatches. Retained scoped/full diffs exactly match git diffs for their stated bases and current HEAD. The superseded initial build is clearly separated; the final evidence has the correct session variable. No simulator/device operations, source edits, test reruns, or subagents were used in this review.

## Required runtime gate

Controller must establish actual Favorites button AX ownership and literal-heart selection/annotation on cold, selected and unselected states, tab transitions, terminate/relaunch and runner restart, on iOS 26 and 27, after matching installed bytes. Re-run stock browse/favorite/edit/quoted-label flows and selector/steps negative controls. The larger hosting boundary additionally needs navigation and local-state retention across tab switches and updates, service-backed actions in every tab, programmatic selection/deep-link stack updates, and layout/safe-area/tab presentation checks.

UITesting app startup already removes NavigatorState in unchanged LandmarksApp code. Consequently, UITesting cold relaunch cannot prove persisted initial Favorites selection. This is an existing test configuration constraint, not a regression introduced here. Within-process restoration can exercise selection/path propagation; true persisted launch restoration needs an appropriate non-reset configuration. Build success does not close any runtime gate.
