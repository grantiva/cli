# Persistent Favorites tab diagnostic build 1

- Diagnostic source: `afd60e2822143e0a422e23040026189599837714`
- Clean parent/PR source: `16c0e7c7b30224718365504eb6d811b6ec64f865`
- Local-only branch: `diagnostic/persistent-favorites-tab-identifier-1`
- Worktree: `/Users/kyle/Developer/landmarks-demo/.worktrees/diag4-persistent-tab-identifier`
- Probe prefix: `[GrantivaTabProbe]`
- App: `/private/tmp/grantiva-fix4-5-tab-diagnostic-derived-data.i13E9X/Build/Products/UITesting-iphonesimulator/Landmarks.app`

The temporary probe logs each update, attachment, and appearance trigger; its controller parent chain; direct `tabBarController` resolution; the window root; and tab controllers discovered recursively through public `children`. For each discovered controller it logs the public tab items' count, title, object identity, and identifier before assignment. If the fixed fixture shape is exactly three items with `Favorites` at index 1, it assigns `heart` to that public `UITabBarItem` and logs immediate and next-main-loop readback.

It does not inspect or mutate private tab-bar button subviews, poll, change labels, add selector aliases, or modify the clean PR branch. The diagnostic commit is local and was not pushed.

The clean `Landmarks (UI Testing)` / `UITesting` generic iOS Simulator build completed with exit 0 and `BUILD SUCCEEDED`. It used dedicated DerivedData, an unset `GRANTIVA_API_KEY`, fresh empty scoped `GRANTIVA_RUNNER_HOME`, and session `fix4-5-tab-diagnostic-build1`; the runner home remained empty. Existing warnings are confined to unrelated caching/service concurrency diagnostics and App Intents metadata extraction.

Controller-owned live execution should capture `[GrantivaTabProbe]` process logs from cold launch through Favorites selection and return to Landmarks, alongside accessibility hierarchies. The key discriminator is whether direct resolution is nil while public root traversal discovers a tab controller, and whether the same Favorites item retains `heart` on immediate and next-loop readback.
