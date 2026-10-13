# Task 8 — final persistent Favorites tab fix independent review

## Verdict

**Pass for controller-owned runtime validation.** I found no source-level blocker in either the scoped revision (`16c0e7c7b30224718365504eb6d811b6ec64f865..b7ed2d2e4e221fb1bd37517325ddde210a822afb`) or the full base diff (`1552ae983a27528eff4c1f8145aa075698b47f71..b7ed2d2e4e221fb1bd37517325ddde210a822afb`). The final implementation corrects the semantic owner exposed by the live diagnostic, covers every possible initially selected tab, and remains limited to the demo.

Runtime accessibility proof remains the closure gate. A successful build and the SDK declaration establish API validity, but they do not establish how the target OS exports the resulting `UITab` identifier into the XCTest accessibility hierarchy.

## Findings

No blocking or advisory source findings.

## Semantic target

The retained `diagnostic-live1` evidence establishes why the change from `UITabBarItem` to `UITab` is necessary:

- the bridge had the expected direct ancestry, `FavoritesTabIdentifierViewController -> TabHostingController -> UIKitTabBarController`;
- the same live Favorites `UITabBarItem` read back `accessibilityIdentifier == "heart"` before mutation, immediately after mutation, and on the next main-loop turn;
- cold, selected, and subsequently unselected accessibility trees still did not expose literal `heart` on the Favorites tab button.

This rules out the previously suspected attachment timing and item-replacement explanations for that build. The final code instead writes `tabs[1].accessibilityIdentifier` on the SwiftUI-owned `UITabBarController`.

The Xcode 27 public SDK explicitly declares `UITab (UIAccessibility) <UIAccessibilityIdentification>` and declares `UITabBarController.tabs` available from iOS 18. The demo deployment target is iOS 26, so no additional availability check is needed for its supported iOS target. The implementation uses no private API or tab-bar subview traversal.

## Cold ownership and lifecycle

Mounting `FavoritesTabIdentifierInstaller()` behind each of the three tab contents closes the source-level initial-selection gap in the first revision. Whichever content SwiftUI activates for the cold or restored selection has an installer capable of reaching the same owning tab controller and assigning the persistent Favorites `UITab`. The assignment is idempotent; multiple mounted installers or later update/appearance callbacks only repeat the same value on the same semantic target.

The implementation remains bounded: it tries during representable updates, one deferred callback after parent attachment, and appearance. It does not poll. Its index and fixture guards are appropriate for this fixed three-tab demo: debug builds assert the expected count and title, while all builds safely return if index 1 is unavailable or is no longer titled `Favorites`.

Static review still cannot prove when SwiftUI invokes the selected path's attachment callback relative to the first accessibility snapshot, nor that the OS projects `UITab.accessibilityIdentifier` onto the actual `XCUIElementTypeButton`. Those questions require the planned clean runtime capture.

## Scope and regression review

The full base-to-head diff is two source files and has the intended effects only:

- removes the content-level `.accessibilityIdentifier("heart")`, leaving no duplicate/offscreen content owner;
- preserves the visible `Favorites` label, `heart` system image, tab ordering and tags, selection binding, navigation paths, deep-link behavior, and persistence hooks;
- adds no CLI selector alias, identifier fallback, label substitution, symbol normalization, or relaxed matching;
- contains no diagnostic logging or mutation of `UITabBarItem` in the final product.

The three background representables are empty bridge views and do not introduce state or alter the tab content hierarchy's navigation semantics. No new source-level breakage is evident.

## Diff and build evidence

The retained `review-16c0-to-head.diff` and `full-base-to-head.diff` byte-match freshly generated diffs for the stated commits. `git diff --check` passes. The source worktree was clean at the captured head, and the final evidence identifies `b7ed2d2e4e221fb1bd37517325ddde210a822afb`.

The retained clean `Landmarks (UI Testing)` / `UITesting` generic iOS Simulator build completed with exit 0 and `** BUILD SUCCEEDED **`, using dedicated DerivedData, an unset API key, a scoped empty runner home, and session `fix4-5-tab-final-build2`. Stderr and the runner-home listing are empty. Warnings in stdout are pre-existing concurrency warnings in caching/service sources plus App Intents metadata processing; none points to the changed files.

No build, test, simulator, or device command was run during this review.

## Remaining runtime gate

Install the exact retained app from commit `b7ed2d2e4e221fb1bd37517325ddde210a822afb` and first match the complete installed files to the built-app manifest. Then capture the actual Favorites `XCUIElementTypeButton` and prove:

1. From a cold launch with Landmarks initially selected, it has identifier `heart`, visible label `Favorites`, and unselected state before Favorites has been visited.
2. Literal `heart` selects Favorites, and the same button retains identifier `heart` while selected.
3. After returning to Landmarks, the persistent unselected button still has identifier `heart`; no `Other` or offscreen content element is the sole owner.
4. The same properties survive termination/relaunch and runner/MCP restart, including restored initial selections, on the owned iOS 26 target and iOS 27 where applicable.
5. Existing browse, favorite, edit, quoted-label, unknown-selector, and missing/wrong/empty-steps controls remain unchanged.

If `UITab.accessibilityIdentifier` does not project to the button in the first cold hierarchy, this revision does not satisfy the requirement despite its correct public API target and must return to source work. Subject to that explicit runtime gate, the final source is approved for validation.
