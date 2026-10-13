# Task 8 — persistent Favorites tab identifier independent review

## Verdict

**Source review passes for controller-owned runtime validation.** I found no source-level blocker in the exact base-to-head diff (`1552ae983a27528eff4c1f8145aa075698b47f71..16c0e7c7b30224718365504eb6d811b6ec64f865`). The implementation is the intended narrow demo-only repair: it removes the content identifier, assigns literal `heart` to the public `UITabBarItem.accessibilityIdentifier`, and leaves the visible `Favorites` label, symbol, tag, navigation stacks, and CLI contract unchanged.

This is not final acceptance of the behavior. The required cold-launch, unselected-tab behavior depends on SwiftUI's runtime controller attachment and remains unproven until the controller captures the real accessibility hierarchy.

## Source assessment

The two-file diff is internally coherent and limited to the demo:

- `ContentView.swift` removes `.accessibilityIdentifier("heart")` from the Favorites content branch, eliminating the duplicate/offscreen content owner that caused the prior selected-only projection.
- `FavoritesTabIdentifierInstaller.swift` uses public SwiftUI/UIKit APIs only. It does not traverse or mutate private tab-bar button subviews.
- `installIdentifier()` resolves the fixed fixture's second tab item, verifies the expected three-item shape and `Favorites` title in debug builds, checks the index and title in all builds, and assigns the property idempotently.
- `updateUIViewController`, deferred work from `didMove(toParent:)`, and `viewDidAppear` provide multiple bounded opportunities to apply the same assignment without a polling loop.
- The filesystem-synchronized Xcode group includes the new Swift file without a project-file edit. The full diff contains no CLI alias, selector relaxation, label change, symbol normalization, or unrelated source change.

The use of a separate representable is consistent with the consulted SwiftUI view-structure guidance: the bridge is a small leaf with no state or expensive initialization, and its unconditional background modifier preserves structural identity.

## Lifecycle limitation and required proof

The bridge's ancestry assumption cannot be established from source or a generic build. When `didMove(toParent:)` runs, the representable controller has joined a hosting parent, but that callback does not itself guarantee that the hosting chain already has a `UITabBarController` ancestor. The single `DispatchQueue.main.async` retry is a reasonable attachment opportunity, not a lifecycle guarantee. `viewDidAppear` is a reliable later opportunity only after Favorites becomes visible. Likewise, source review cannot establish whether SwiftUI eagerly mounts this background for an initially unselected tab on each target OS.

Therefore the decisive first check is a cold launch whose persisted/default selection is Landmarks, before Favorites has ever been selected. The captured hierarchy must show the persistent Favorites `XCUIElementTypeButton` itself with:

- `identifier: heart`
- visible label `Favorites`
- unselected state

Literal `heart` must then select Favorites. The same button must retain that identifier while selected and after returning to Landmarks. Evidence fails if `heart` appears only on an `Other`, content element, or offscreen duplicate.

The controller should repeat that proof after app termination/relaunch and runner/MCP restart, including both persisted initial selections, on the owned iOS 26 target and iOS 27 where applicable. It must also retain the exact built-app manifest/installed-byte match and rerun the existing browse, favorite, edit, quoted-label, unknown-selector, and malformed/missing-steps controls described in the implementation report.

If the first cold/unselected capture lacks `heart`, this implementation has missed its primary requirement even if selecting Favorites causes `viewDidAppear` to install it later. That result should return to source work for stronger attachment handling rather than be treated as a timing retry.

## Build evidence review

The retained evidence under `findings/evidence/fix4-5-tab/` supports the reported compile result:

- exact argv records a clean build of `Landmarks (UI Testing)` / `UITesting` for generic iOS Simulator with dedicated DerivedData;
- start/end timestamps are `2026-10-13T17:44:10Z` and `2026-10-13T17:44:17Z`;
- `exit.txt` records success and `stdout.txt` ends with `** BUILD SUCCEEDED **`;
- the scoped runner-home inventory is empty;
- the emitted warnings are in pre-existing caching/service code plus App Intents metadata processing, not either changed file.

No additional build or device command was run during this review, as required. A unit test would only mirror the property assignment and would not validate the material SwiftUI/UIKit ancestry behavior, so the absence of a new logic test is reasonable.

## Conclusion

Proceed to controller-owned installation and runtime validation from exact commit `16c0e7c7b30224718365504eb6d811b6ec64f865`. Source scope and API ownership are correct; closure depends on explicit hierarchy evidence for cold default Landmarks selection, selected/unselected transitions, and relaunch cycles.
