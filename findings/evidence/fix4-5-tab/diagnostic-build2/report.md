# Modern SwiftUI tab diagnostic build 2

- Diagnostic source: `114d7fd5b1072843e608e1a66aead101232035f8`
- Parent source: `b7ed2d2e4e221fb1bd37517325ddde210a822afb`
- Local branch: `diagnostic/modern-tabs-identifier-2`
- Probe prefix: `[GrantivaModernTabProbe]`
- App: `/private/tmp/grantiva-fix4-5-tab-modern-diagnostic-derived-data.TXI6DO/Build/Products/UITesting-iphonesimulator/Landmarks.app`

This diagnostic migrates the three legacy `.tabItem` declarations to SwiftUI's public iOS 18+ `Tab` declarations while retaining the same `TabView` selection binding, titles, SF Symbols, `Navigator.Tab` values, `NavigationStack` paths, destinations, environment, state restoration, and deep-link behavior.

The bounded probe logs each attachment/update/appearance callback, controller parent chain, public ancestor `UIViewController.tab` values, and the public `UITabBarController.tabs` count. It records every tab's title, immutable identifier, object identity, and accessibility identifier. It mutates only when the collection is exactly the fixed three-tab fixture with `Favorites` at index 1, then logs immediate and next-main-loop accessibility-identifier readback. A missing controller or any transitional/unexpected shape returns safely; there is no assertion, polling, private view traversal, button mutation, alias, or label change.

The clean `Landmarks (UI Testing)` / `UITesting` generic simulator build completed with exit 0 and `BUILD SUCCEEDED`. It used a dedicated DerivedData directory, unset `GRANTIVA_API_KEY`, fresh empty scoped `GRANTIVA_RUNNER_HOME`, and session `fix4-5-tab-diagnostic-build2`. Stderr and the runner-home listing are empty. The five-file app manifest is retained in `app-manifest-sha256.txt`.

Controller-owned live proof should capture `[GrantivaModernTabProbe]` logs from cold launch on Landmarks, then Favorites selection and return to Landmarks, together with accessibility hierarchies. The modern-path prerequisite is an exact three-element public `tabs` collection containing Favorites at index 1. Success additionally requires `heart` readback on that same `UITab` and literal `heart` on the actual Favorites `XCUIElementTypeButton` while cold-unselected, selected, and unselected again. No conclusion about the prior legacy collection's exact count is encoded in this diagnostic.
