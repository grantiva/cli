# Task 8 — persistent Favorites tab identifier implementation report

## Result

Implemented and published the reopened demo Task 5 fix from base `1552ae983a27528eff4c1f8145aa075698b47f71`.

- Commit: `16c0e7c7b30224718365504eb6d811b6ec64f865` (`Persist the Favorites tab identifier`)
- Branch: `fix4/persistent-favorites-tab-identifier`
- Draft PR: https://github.com/grantiva/landmarks-demo/pull/5

## Diff and design

- `ios/Landmarks/ContentView.swift` removes the content-level `.accessibilityIdentifier("heart")` and mounts a demo-only bridge behind the Favorites tab content.
- `ios/Landmarks/FavoritesTabIdentifierInstaller.swift` adds a narrow `UIViewControllerRepresentable`. Its controller sets the public `UITabBarItem.accessibilityIdentifier` on the fixed fixture's second tab.
- The hook runs idempotently from representable updates, after controller attachment on the next main-loop turn, and when the tab content appears. It does not poll or walk/mutate private tab-bar subviews.
- Debug assertions guard the fixture's expected three-item shape and `Favorites` title; release behavior safely returns if that invariant is absent.
- The visible `Favorites` label, `heart` system image, tab order/tag, selection binding, navigation stacks, and persistence hooks are unchanged. No CLI selector alias, label change, symbol normalization, or fallback was added.

The attachment assumption is intentionally narrow: the representable is embedded in the Favorites tab content, whose hosting controller is expected to acquire the SwiftUI-owned tab controller as an ancestor. `didMove(toParent:)` defers one main-loop turn so the hierarchy can finish attaching; `viewDidAppear` and `updateUIViewController` reapply the same property without changing semantics. The clean compile confirms the public API and project integration, but does not prove runtime hierarchy attachment.

## Build proof

The final source diff passed `git diff --check`. A clean build of scheme `Landmarks (UI Testing)`, configuration `UITesting`, for generic iOS Simulator completed with exit `0` and `** BUILD SUCCEEDED **` using Xcode 27.0.0. The command used a dedicated fresh DerivedData directory, `GRANTIVA_API_KEY` unset, a fresh empty scoped `GRANTIVA_RUNNER_HOME`, and session `fix4-5-tab`. The runner home remained empty.

Full retained evidence is under `findings/evidence/fix4-5-tab/`: exact argv, environment and DerivedData path, source base/diff/status, start/end timestamps, exit status, stdout, stderr, runner-home contents, resulting commit, draft-PR metadata, and checksums. The compiler emitted existing Swift 6 concurrency warnings in caching/service files and an App Intents metadata warning; no warning points to either changed file.

No targeted logic test was added because any unit test would only mirror the property assignment and could not verify UIKit/SwiftUI attachment or the accessibility hierarchy. No device or simulator runtime command was run, per controller ownership.

## Remaining controller-owned runtime proof

This implementation must still be proven on the owned clean iOS 26 target, and iOS 27 where applicable:

1. Build/install from exact commit `16c0e7c7b30224718365504eb6d811b6ec64f865`; retain the complete built-app manifest and match every installed file.
2. From cold launch with Landmarks selected, prove the Favorites `XCUIElementTypeButton` itself has identifier `heart`, label `Favorites`, and is unselected; literal `heart` must navigate to Favorites.
3. Prove the same tab button retains identifier `heart` while selected, then after returning to Landmarks. Reject evidence where only a content/offscreen `Other` owns `heart`.
4. Terminate/relaunch and restart the runner/MCP process, repeating enough cycles for both persisted initial selections with raw requests, responses, and before/after hierarchies.
5. Re-run browse, favorite, edit, and quoted-label flows plus negative controls for an unknown selector and missing/wrong/empty `steps`.

The material residual risk is whether SwiftUI's runtime controller hierarchy attaches the background representable early enough for an initially unselected Favorites tab on both target OS versions. Static review and a successful build cannot close that risk; the retained hierarchy evidence above is required before reclosing L66.

## Final revision after live diagnosis

Controller-owned live evidence disproved the first implementation's semantic target. `findings/evidence/fix4-5-tab/diagnostic-live1/probe-log.stdout` proves that the bridge had a direct `UIKitTabBarController` ancestor and that its Favorites `UITabBarItem` already read back `accessibilityIdentifier == "heart"` before mutation, immediately afterward, and on the next main-loop turn using the same object. The cold, selected, and unselected accessibility hierarchies still exposed no identifier on the actual Favorites button. The failure was therefore `UITabBarItem` accessibility propagation in this SwiftUI runtime, not attachment timing or item replacement.

Final commit `b7ed2d2e4e221fb1bd37517325ddde210a822afb` replaces the item mutation with `UITab.accessibilityIdentifier = "heart"`. This is the SDK-backed semantic target: Xcode 27's public `UITab.h` explicitly declares `UITab (UIAccessibility) <UIAccessibilityIdentification>`, while `UITabBarItem` does not declare that conformance. The bridge resolves `UITabBarController.tabs`, asserts the fixed three-tab fixture and `Favorites` at index 1, and writes only that public `UITab` property.

The bridge is mounted behind all three tab contents. Whichever tab is initially active therefore receives the attachment callback and can initialize the persistent Favorites `UITab` from a cold launch, including Landmarks or another restored selection. The operation remains idempotent and uses update, deferred attachment, and appearance callbacks without polling. All diagnostic logging and item mutation are absent from the final product. Labels, symbols, tags, selection binding, navigation stacks, deep-link handling, and state persistence remain unchanged.

The final clean `Landmarks (UI Testing)` / `UITesting` generic simulator build succeeded with exit 0 from exact source `b7ed2d2e4e221fb1bd37517325ddde210a822afb`. It used a new dedicated DerivedData directory, an unset API key, fresh empty scoped runner home, and session `fix4-5-tab-final-build2`; stderr and the runner-home listing are empty. Exact source, review diff `16c0e7c7b30224718365504eb6d811b6ec64f865..b7ed2d2e4e221fb1bd37517325ddde210a822afb`, full base diff, argv, environment, timestamps, streams, exit, and app path are retained under `findings/evidence/fix4-5-tab/final-build2/`.

The final app for controller-owned runtime proof is `/private/tmp/grantiva-fix4-5-tab-final-derived-data.rROcfq/Build/Products/UITesting-iphonesimulator/Landmarks.app`. Draft PR 5 was pushed and its description updated. Runtime proof is still required before merge: exact installed-file matching plus cold, selected, unselected, tab-change, relaunch/restart, stock-flow, quoted-label, and negative-control evidence on the owned targets. Static/API proof does not overclaim the resulting AX hierarchy.
