# Task 8 — literal `heart` unselected-tab diagnosis

## Verdict

The reopened L66 failure is a demo-fixture defect. The CLI selector contract is behaving correctly and must not be relaxed.

`ContentView.swift:28` applies `.accessibilityIdentifier("heart")` to the Favorites tab's `NavigationStack`, after `.tabItem`. That modifier identifies the selected tab's content subtree; it is not a declaration on the persistent tab-bar item. SwiftUI/UIKit may copy that content annotation onto the selected `XCUIElementTypeButton`, but this is incidental projection. On the current iOS 26 runtime, selecting Landmarks removes that projection: the actual Favorites button reverts to the SF Symbol identity `heart.fill`, so exact identifier lookup for literal `heart` correctly finds nothing.

The smallest durable fix is to set `accessibilityIdentifier = "heart"` on the Favorites `UITabBarItem` itself through a narrowly scoped SwiftUI/UIKit bridge owned by the demo. `UITabBarItem` is the semantic model for the persistent tab button, so its identifier does not depend on which tab content is mounted or selected.

## Source and retained runtime evidence

- Clean demo source is `1552ae983a27528eff4c1f8145aa075698b47f71` (`findings/evidence/round4-smoke/01-candidate/demo-source.json`). The copied source at `/private/tmp/grantiva-round4-smoke-j35_m7hg/demo/ios/Landmarks/ContentView.swift:27-29` is:

  ```swift
  .tabItem { Label("Favorites", systemImage: "heart") }
  .accessibilityIdentifier("heart")
  .tag(Navigator.Tab.favorites)
  ```

- Git history confirms the earlier label-local attempt (`4e3ecfd`) put the modifier inside the `.tabItem` label builder and was replaced by the current content modifier (`19c1aad`, merged as `1552ae9`). Thus neither attempted location is a public, direct identifier on the tab item.
- The current installed app is exactly the Task 8 candidate: all five installed files match the five-file candidate manifest (`findings/evidence/round4-smoke/candidate.json`; `findings/evidence/round4-smoke/04-mcp-ios/installed-app-identity.json`). This rules out a stale install.
- The exact request order is retained in `findings/evidence/round4-smoke/04-mcp-ios/helper/active/requests.jsonl:8-11`. Raw responses in `stdout.raw` prove:
  - id 7: label `Favorites` selects Favorites;
  - id 8: literal `heart` succeeds by identifier while Favorites is selected;
  - id 9: label `Landmarks` selects Landmarks;
  - id 10: literal `heart` returns the exact element-not-found contract.
- The hierarchy returned after id 9 contains the Favorites image identifier `heart.fill` and no persistent tab-button identifier `heart`. The content modifier's `heart` identity belongs to the Favorites content branch and is unavailable when that branch is unselected.
- Task 5's accepted captures (`findings/evidence/fix4-5/ios-stable2-cycle1/before-6.json`, `before-10.json`, and `ios-stable3-cycle4/before-10.json`, `before-14.json`) showed `identifier: heart` on the tab button in both states for that tested runtime/build context. Those captures establish that the desired behavior occurred there, but they do not change the source-level ownership of the modifier. Current exact-build evidence disproves the review's broader durability inference.

## Concrete fix options

### Recommended: a tiny `UITabBarItem` identifier bridge

Add a small `UIViewControllerRepresentable` (preferably a separate demo-only view type) behind the `TabView`. Its controller resolves its owning `UITabBarController`, finds the Favorites item, and assigns:

```swift
favoritesItem.accessibilityIdentifier = "heart"
```

Resolve the item by the stable tab value/order established by this fixed three-tab fixture, with a debug assertion that the resolved item's title is `Favorites`; or resolve by title and assert exactly one match. Apply after attachment (`viewDidAppear`/next main-loop turn) and reapply from `updateUIViewController`, making the operation idempotent. Remove the existing content `.accessibilityIdentifier("heart")` so there is one owner and no duplicate offscreen `XCUIElementTypeOther` identity.

This is the smallest option that targets the real persistent UIKit item and keeps the visible accessibility label `Favorites`, the selected/unselected SF Symbols (`heart.fill`/`heart` as rendered by the system), the tab tag, and navigation state unchanged.

Material implementation risks to control:

- Do not walk or mutate private tab-bar button subviews. Set the public `UITabBarItem.accessibilityIdentifier` property.
- Do not rely on a one-shot `makeUIViewController` call before the representable has a tab-bar-controller ancestor.
- Assert the expected item/title/count in debug builds so tab reordering cannot silently attach `heart` to another tab.
- Keep this fixture hook local to the demo; no selector alias, symbol normalization, or CLI fallback belongs in production.

### Larger fallback: own the tab controller

Represent the three tabs with a small `UITabBarController` wrapper and construct the Favorites `UITabBarItem` with `accessibilityIdentifier = "heart"`. This gives explicit lifecycle ownership but is disproportionate: it replaces SwiftUI `TabView` composition and raises navigation/environment/state-integration risk. Use it only if the narrow bridge cannot reliably acquire the SwiftUI-owned controller during a focused prototype.

### Rejected shortcuts

- Moving `.accessibilityIdentifier("heart")` back inside `Label` was already tried at `4e3ecfd` and does not directly configure the resulting `UITabBarItem`.
- `.accessibilityLabel("heart")` on modern `TabContent` would replace the user-facing semantic label `Favorites`; it is not an identifier hook.
- Matching `heart.fill`, accepting `heart*`, mapping `heart` to `Favorites`, or retrying by label would weaken the exact literal-selector contract and conceal a fixture defect.

## Proof required before reclosing L66

Retain raw evidence from the exact clean fixed demo source and exact installed candidate app, on the owned iOS 26 simulator:

1. Build the UI Testing configuration successfully and record the complete app manifest; install it and prove every recorded file matches the installed container.
2. From a cold launch with Landmarks selected, capture the hierarchy before tapping. The Favorites `XCUIElementTypeButton` itself must have `identifier: heart`, `label: Favorites`, and no selected value. Literal `heart` must report identifier matching and navigate to Favorites.
3. While Favorites is selected, capture the same button with `identifier: heart`, `label: Favorites`, and selected value, then tap literal `heart` successfully without changing away from Favorites.
4. Tap Landmarks, capture the unselected Favorites button again, then tap literal `heart`; it must navigate back to Favorites. Explicitly reject evidence in which only an offscreen/content `Other` carries `heart`.
5. Terminate and relaunch the app, restart the runner/MCP process, and repeat steps 2-4. Run enough independent cycles to cover both persisted initial selections; each request/response and before/after hierarchy must be retained and matched.
6. Run the existing stock browse, favorite, edit, and quoted-label flows to prove tab behavior, labels, symbols, navigation stacks, and fixture semantics remain intact.
7. Include negative exact-selector controls (`No Such Selector`, missing/wrong/empty `steps`) so success is not attributable to an alias or relaxed contract.

No device action or implementation change was performed for this diagnosis.
