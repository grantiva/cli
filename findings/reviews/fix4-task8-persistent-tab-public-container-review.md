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

## Scoped layout addendum after controller live evidence

**Revised verdict: CHANGES REQUESTED — P2 layout regression.** The initial static approval above was conditional on runtime layout checks. Controller-provided runtime evidence now demonstrates a real placement regression at `ios/Landmarks/ContentView.swift:14`: the outer representable accepts SwiftUI's already-inset proposal even though its UITabBarController needs the full window container to lay out native bars. This finding does not invalidate the preliminary actual-button heart AX success.

Read the selected-tree.json artifacts from `diagnostic-live2`, `public-container-live26`, and `public-container-live27`, and visually inspected `public-container-live27/current-screen.png`. All trees report the same 402 × 874 point window. Original SwiftUI-owned container ancestors occupy y=0, height=874. Both public-container runs instead show the UIKit content subtree at y=62, height=778, ending at y=840: the window minus its 62-point top and 34-point bottom safe areas. The tab bar retains its 83-point height but moves from y=791 to y=757; its Favorites button retains its 54-point height but moves from y=795 to y=761. Thus the bar is elevated by exactly the additional 34-point bottom inset. The screenshot visibly corroborates the excessive space below the floating bar. The navigation bar also moves from y=62 to y=72, with the Favorites header moving from y=119 to y=129.

Recommended minimal correction: apply `.ignoresSafeArea(.container)` to the outer `PersistentTabContainer` in ContentView, so UIKit receives full window bounds and its native tab/navigation containers handle system safe areas. Keep this at the representable boundary, retain the hosted NavigationStack contents and bindings, and do not compensate with fixed padding, hardcoded device insets, bar-frame mutation, or ignoresSafeArea on individual screens. Limiting the region to `.container` preserves SwiftUI's separate keyboard safe-area behavior. This is the recommended correction based on source and measured geometry; it has not been implemented or runtime-validated in this review.

The controller should verify restored full-window container bounds and expected top/bottom bar/header placement on iOS 26 and 27, with screenshots and raw frames, then repeat required AX, navigation/local-state, presentation and stock-flow checks including text editing/keyboard behavior. Existing service/environment propagation should remain unchanged. No source changes, builds, device operations, test reruns, or subagents were performed for this addendum.

## Safe-area correction review — f6cdff54

Reviewed `f6cdff54c0bed5632ce23bc1b528a2e7a33cb118` against `db6c2ea1564a1aad6b311bd7278491c907c99db9`, limited to the prior P2 and new breakage introduced by its correction.

**Spec verdict: APPROVED for controller-owned runtime verification.** The one-line `.ignoresSafeArea(.container)` addition is at the requested outer PersistentTabContainer boundary and addresses the identified source-level cause. The P2's runtime closure remains pending raw frame and screenshot confirmation on iOS 26 and 27.

**Code quality verdict: APPROVED.** No new actionable source defect found. The modifier changes the outer container layout proposal without changing UITab/host ownership, selection synchronization, environment injection, path bindings, persistence, URL handling or screen code. Its explicit `.container` region does not opt out of keyboard safe-area handling. Actual keyboard/editing behavior still requires the controller's runtime check.

Independently verified retained `public-container-safearea-build` evidence: clean source at reviewed commit; exact clean/build UITesting scheme/configuration and generic simulator argv; API unset; fresh scoped runner home empty; session `fix4-5-tab`; dedicated DerivedData; UTC interval 2026-10-13 18:36:22.237176–18:36:33.032721; exit 0 and BUILD SUCCEEDED; empty stderr and source-status artifacts; no changed-file compiler warnings. Recomputed all 165 source-manifest hashes and all five app-manifest hashes with no mismatches. Retained scoped and full diffs exactly match git against their stated bases.

Proceed to controller verification of full-window container geometry, restored top/bottom native bar placement, exact button heart behavior, and the remaining full helper/stock/navigation/state/keyboard gates. This approval does not claim runtime layout success or authorize merge. No source edits, builds, tests, device operations or subagents were performed.
