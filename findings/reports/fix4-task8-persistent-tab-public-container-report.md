# Task 8 public tab container correction

Published commit `db6c2ea1564a1aad6b311bd7278491c907c99db9` to existing draft PR https://github.com/grantiva/landmarks-demo/pull/5 on `fix4/persistent-favorites-tab-identifier`. Worktree: `/Users/kyle/Developer/landmarks-demo/.worktrees/fix4-persistent-tab-identifier`. No device operations, subagents, merges, tags, or releases.

## Source and self-review

`ContentView.swift` replaces only its tab container with `PersistentTabContainer`, retaining the three original NavigationStacks and path bindings, destinations, Navigator environment, URL handler, loadState and saveState hooks. The unused service reader was removed; the services themselves continue through the environment.

`PersistentTabContainer.swift` creates a public `UITabBarController` with three stable `UITab` models and typed SwiftUI hosting controllers. Favorites receives `accessibilityIdentifier = "heart"` before tabs are assigned. Titles/order/images remain Landmarks/map, Favorites/heart, Deep Links/link. The coordinator retains the same hosting controllers throughout representable updates; root values update with the same concrete SwiftUI structure, without recreating controllers, tabs, or navigation identities. The modern UIKit delegate writes user selection back through the Navigator binding; updates apply restored/programmatic selection to UIKit only when different. Hosted roots explicitly receive the representable environment, including Navigator and all service keys, because independent UIHostingControllers form new SwiftUI roots.

The failed `FavoritesTabIdentifierInstaller.swift` is removed. No private hierarchy access, polling, diagnostic logs, assertions about SwiftUI runtime tabs, content identifier duplication, CLI changes, or label/symbol normalization remain.

Read the local SwiftUI specialist skill plus environment/dataflow references and inspected Xcode 27 simulator SDK public UITab.h and UITabBarController.h. These document the UITab accessibility conformance, controller tabs initializer/selectedTab API, and modern didSelectTab delegate. Source self-review and `git diff --check` passed. Scoped diff against b7ed and full diff against original 1552 are adjacent as `task8-persistent-tab-public-container-scoped.diff` and `task8-persistent-tab-public-container-full.diff`, also copied into evidence.

## Build provenance

Clean `Landmarks (UI Testing)` / `UITesting` generic iOS Simulator build from committed clean source passed with exit 0. Final artifact:

`/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-fix4-5-tab-public-final-derived-data.9vzn0tuu/Build/Products/UITesting-iphonesimulator/Landmarks.app`

Evidence: `findings/evidence/fix4-5-tab/public-container-build/`. It retains exact argv, source commit/status/manifests, UTC start/end, separate stdout/stderr, exit, environment, app path, five-file SHA-256/size manifest, both review diffs, and PR metadata. Final build has `GRANTIVA_API_KEY` unset, a freshly created empty scoped runner home, and `GRANTIVA_SESSION_ID=fix4-5-tab`; runner home remained empty. An initial successful build used the wrong session variable spelling; its streams are preserved under `initial-build/` and superseded by the final clean build with the correct variable. Final stderr is empty. Existing service/cache Swift concurrency warnings and the App Intents metadata warning remain; no new container warnings were emitted.

## Remaining runtime proof and concerns

Compile success establishes API compatibility, not accessibility projection. Controller-owned live verification on iOS 26 and 27 remains mandatory: match all installed app files, cold Landmarks launch with unselected Favorites identifier on the actual button, selected/unselected transitions, exact heart selector and annotation, terminate/relaunch and runner restart, all stock browse/favorite/edit/quoted-label flows, and negative controls.

The larger hosting boundary warrants explicit runtime checks that each tab retains navigation/local view state across switches and ordinary updates, service-backed data/actions remain available on all tabs, and deep links switch selection while updating the correct stack. Check layout/safe areas and tab presentation as well. No unit test was added because mirroring property assignments would not prove these UIKit/SwiftUI and accessibility behaviors. UI Testing intentionally clears persisted Navigator state at app startup in existing unchanged LandmarksApp code; true persisted launch-selection validation needs an appropriate non-reset launch configuration, while within-process Navigator restore can still be checked. Runtime acceptance and merge remain with the controller.

## Safe-area correction after live review

Commit `f6cdff54c0bed5632ce23bc1b528a2e7a33cb118` is pushed to the same draft PR 5. The sole change from db6c2ea is `.ignoresSafeArea(.container)` at the outer PersistentTabContainer boundary in ContentView. This addresses the independently measured double container insets by giving UIKit the full container proposal. The keyboard safe-area region remains enabled; hosted screens and tab/navigation behavior are unchanged by this correction. Source diff check passed.

A fresh clean UITesting simulator build from clean committed source succeeded with exit 0. API key was unset, `GRANTIVA_SESSION_ID=fix4-5-tab`, and a fresh scoped runner home stayed empty. Separate new evidence is `findings/evidence/fix4-5-tab/public-container-safearea-build/`; prior builds are intact. It includes source/argv/environment/timestamps/streams/exit, full source manifest, five-file app SHA-256 manifest, PR metadata, and scoped/full diffs. No changed-file compiler warnings; existing unrelated warnings remain.

App: `/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-fix4-5-tab-safearea-derived-data.gr_p5u90/Build/Products/UITesting-iphonesimulator/Landmarks.app`

New review diffs are adjacent as `task8-persistent-tab-public-container-safearea-scoped.diff` (db6c2ea to new head) and `task8-persistent-tab-public-container-safearea-full.diff` (1552 baseline to new head). No device operations or runtime assertions were made. Controller must rerun iOS 26/27 raw frames/screenshots, selector and full regressions, including keyboard/text editing behavior.
