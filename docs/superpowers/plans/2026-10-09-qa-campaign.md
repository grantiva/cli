# Cross-platform QA Campaign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exercise every documented Grantiva CLI feature on iOS and Android against two Landmarks demo apps, record every defect, and file one GitHub issue per bug.

**Architecture:** Phase 0 builds the demo apps (iOS adaptation, Android Compose port) and the feature matrix in parallel. Phase 1 runs three testing agents, one per slice (CLI, iOS, Android), each in its own worktree against one shared release binary. Phase 2 triages findings into issues.

**Tech Stack:** Swift/SwiftUI (iOS app), Kotlin/Jetpack Compose/Gradle (Android app), Maestro-format YAML flows, grantiva CLI at `c8dc86d`, `gh` for issues.

**Spec:** `docs/superpowers/specs/2026-10-09-qa-campaign-design.md`

## Global Constraints

- Target commit: `c8dc86d`. One release binary, built once, at `/Users/kyle/.grantiva-qa/bin/grantiva`. Every agent calls it as `$GRANTIVA`.
- Demo repo: `grantiva/landmarks-demo`, private. Local clone for building at `/Users/kyle/Developer/landmarks-demo`.
- iOS bundle ID `com.kylebrowning.Landmarks`, deployment target iOS 26.0, UI test scheme named exactly `Landmarks (UI Testing)`.
- Android application ID `com.kylebrowning.landmarks`, minSdk 26, targetSdk 35, module `app`, flavors `free` and `paid`, build types `debug` and `release`.
- Device names: iOS agent `qa-ios-1`, `qa-ios-2`, `qa-ios-3`; CLI agent `qa-cli-1`; Android agent `Pixel_8_API_35` and `qa-android-1`. Session IDs `qa-ios`, `qa-cli`, `qa-android`.
- Never touch the pre-existing booted `iPhone 17 Pro` (`B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`). Never kill a process you did not start. Never run `simulator cleanup` or `emulator teardown` without a serial while another agent is active.
- Agents never edit files under `Sources/` or `Tests/` of the CLI repo.
- Android shells always begin with: `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- No Grantiva account. `GRANTIVA_API_KEY` must be unset in every agent shell.
- Commits: no Co-Authored-By or Generated-with lines.

## Review Focus

Inputs the spec implies but no app flow exercises on its own. Each has a matrix row in the task named.

1. A screen label containing a quote or an emoji in `tapOn` (flow parsing and WDA/UIA2 selector escaping). Matrix row CLI-061, IOS-041, AND-041.
2. A `--ready-file` path inside a directory that does not exist (spec says an unwritable path fails immediately). IOS-033, AND-033.
3. `--env` value containing `=` and a space, e.g. `LANDMARKS_NOTE=a=b c`. IOS-035, AND-035.
4. `report.json` when the suite has zero flows (empty `flows:` list). CLI-044, IOS-031.
5. `grantiva hierarchy` while two keep-alive sessions are live and `--udid` is omitted (spec: newest live session wins). IOS-052, AND-052.

---

## Shared label contract

Both apps render these exact strings as visible text or accessibility labels. Flows depend on them. Builders must not rename them.

| Where | Label |
|---|---|
| Tab bar | `Landmarks`, `Favorites`, `Deep Links` |
| Landmarks list sections | `Featured`, `Categories`, `All Landmarks` |
| Categories | `Mountains`, `Lakes`, `Bridges` |
| Sample landmarks (seed `default`) | `Golden Gate Bridge` / `San Francisco, CA` / Bridges / featured; `Lake Tahoe` / `Sierra Nevada, CA` / Lakes; `Half Dome` / `Yosemite, CA` / Mountains / featured; `Yosemite Valley` / `Yosemite, CA` / Mountains; `Bixby Creek Bridge` / `Big Sur, CA` / Bridges; `Mono Lake` / `Lee Vining, CA` / Lakes; `Mount Shasta` / `Siskiyou County, CA` / Mountains; `Crater Lake` / `Oregon` / Lakes; `Brooklyn Bridge` / `New York, NY` / Bridges; `Mount "Denali"` / `Alaska` / Mountains |
| Seed `many` | the 10 above plus `Landmark 11` … `Landmark 70`, location `Nowhere, CA`, category cycling Mountains, Lakes, Bridges |
| Seed `empty` | no landmarks; list shows `No landmarks yet` |
| Detail | `About`, `Plan Visit`, toolbar button with accessibility label `Favorite` (toggles to `Unfavorite`) |
| Visit confirmation | `Visit Scheduled!`, `You're all set to visit <name>.`, `Done`, title `Confirmation` |
| Favorites empty | `Landmarks you favorite will appear here.`; row swipe action `Remove` |
| Edit landmark | title `Edit Landmark`, fields `Name`, `Location`, buttons `Cancel`, `Done`, alert text `You have unsaved changes that will be lost.`, alert buttons `Discard`, `Keep Editing` |
| Deep Links | title `Deep Links`, buttons `Caching Demo`, `Edit Landmark`, `landmarks://landmark/golden-gate-bridge`, `landmarks://category/lakes`, `Mountains → Yosemite Valley`, `Slow Screen` |
| Caching demo | title `Caching Demo`, picker `Cache Policy` with `Cache Then Fetch`, `Cache Else Fetch`, `Network Only`, `Cache Only`, `Network Else Cache`; buttons `Fetch with Policy`, `Clear Cache`; a live clock text with accessibility identifier `clock` showing `HH:mm:ss` |
| Slow screen | title `Slow Screen`; shows `Loading…` for 3 s, then `Loaded after delay` |
| Crash | when `LANDMARKS_CRASH_ON_LAUNCH=1`, the app calls `fatalError` (iOS) / `throw RuntimeException` (Android) 500 ms after first frame |

Environment variables read at launch by both apps: `LANDMARKS_SEED` (`default`, `empty`, `many`; default `default`), `LANDMARKS_CRASH_ON_LAUNCH`, `LANDMARKS_NOTE` (shown verbatim under the Deep Links title when set). On Android, `launchApp` env is delivered as intent extras by the runner; the app reads both `System.getenv` and intent extras, extras first.

Deep link URL scheme on both: `landmarks://landmark/<slug>` and `landmarks://category/<mountains|lakes|bridges>`. Slug is the name lowercased with spaces as hyphens and punctuation removed.

## Shared flows

Directory `.maestro/` on each platform. `appId` is `com.kylebrowning.Landmarks` on iOS and `com.kylebrowning.landmarks` on Android. Everything else is identical.

```yaml
# 01-browse.yaml
appId: APPID
---
- launchApp
- assertVisible: "Landmarks"
- assertVisible: "Featured"
- takeScreenshot: "Home"
- tapOn: "Golden Gate Bridge"
- assertVisible: "San Francisco, CA"
- assertVisible: "Plan Visit"
- takeScreenshot: "Landmark Detail"
```

```yaml
# 02-favorite.yaml
appId: APPID
---
- launchApp
- tapOn: "Lake Tahoe"
- tapOn: "Favorite"
- assertVisible: "Unfavorite"
- tapOn: "Landmarks"
- tapOn: "Favorites"
- assertVisible: "Lake Tahoe"
- takeScreenshot: "Favorites With Item"
- swipe:
    direction: LEFT
    from: "Lake Tahoe"
- tapOn: "Remove"
- assertNotVisible: "Lake Tahoe"
- assertVisible: "Landmarks you favorite will appear here."
- takeScreenshot: "Favorites Empty"
```

```yaml
# 03-edit.yaml
appId: APPID
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Edit Landmark"
- assertVisible: "Edit Landmark"
- tapOn: "Name"
- inputText: " Renamed"
- tapOn: "Done"
- assertVisible: "Golden Gate Bridge Renamed"
- takeScreenshot: "Edited"
```

```yaml
# 04-discard.yaml
appId: APPID
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Edit Landmark"
- tapOn: "Location"
- inputText: "X"
- tapOn: "Cancel"
- assertVisible: "You have unsaved changes that will be lost."
- takeScreenshot: "Discard Alert"
- tapOn: "Keep Editing"
- assertVisible: "Edit Landmark"
- tapOn: "Cancel"
- tapOn: "Discard"
- assertVisible: "Deep Links"
```

```yaml
# 05-category.yaml
appId: APPID
---
- launchApp
- tapOn: "Lakes"
- assertVisible: "Lake Tahoe"
- assertVisible: "Mono Lake"
- assertNotVisible: "Golden Gate Bridge"
- takeScreenshot: "Lakes"
```

```yaml
# 06-visit.yaml
appId: APPID
---
- launchApp
- tapOn: "Half Dome"
- tapOn: "Plan Visit"
- assertVisible: "Visit Scheduled!"
- assertVisible: "You're all set to visit Half Dome."
- takeScreenshot: "Visit Confirmed"
- tapOn: "Done"
- assertVisible: "Half Dome"
```

```yaml
# 07-deeplink.yaml
appId: APPID
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "landmarks://category/lakes"
- assertVisible: "Mono Lake"
- takeScreenshot: "Deep Link Lakes"
```

```yaml
# 08-caching.yaml
appId: APPID
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Caching Demo"
- assertVisible: "Cache Policy"
- tapOn: "Fetch with Policy"
- takeScreenshot: "Caching Demo"
- tapOn: "Clear Cache"
```

```yaml
# 09-seed-empty.yaml
appId: APPID
env:
  LANDMARKS_SEED: empty
---
- launchApp
- assertVisible: "No landmarks yet"
- takeScreenshot: "Empty"
```

```yaml
# 10-seed-many.yaml
appId: APPID
env:
  LANDMARKS_SEED: many
---
- launchApp
- scroll
- scroll
- scroll
- scroll
- assertVisible: "Landmark 30"
- takeScreenshot: "Scrolled"
```

```yaml
# 11-slow.yaml
appId: APPID
---
- launchApp
- tapOn: "Deep Links"
- tapOn: "Slow Screen"
- assertVisible: "Loading…"
- extendedWaitUntil:
    visible: "Loaded after delay"
    timeout: 10000
- takeScreenshot: "Slow Loaded"
```

```yaml
# 12-quote-label.yaml
appId: APPID
---
- launchApp
- tapOn: "Mountains"
- tapOn: 'Mount "Denali"'
- assertVisible: "Alaska"
- takeScreenshot: "Quoted Label"
```

```yaml
# 99-crash.yaml   (expected to FAIL; excluded from the gate and from grantiva.yml flows)
appId: APPID
env:
  LANDMARKS_CRASH_ON_LAUNCH: "1"
---
- launchApp
- assertVisible: "Landmarks"
- assertVisible: "Featured"
- assertVisible: "This never appears"
```

`grantiva.yml` (iOS) and `grantiva-android.yml` (Android) screens:

```yaml
screens:
  - name: Home
    path: launch
  - name: Favorites
    path:
      - tap: "Favorites"
  - name: Deep Links
    path:
      - tap: "Deep Links"
  - name: Lakes
    path:
      - tap: "Landmarks"
      - tap: "Lakes"
  - name: Detail
    path:
      - tap: "Landmarks"
      - tap: "Golden Gate Bridge"
      - assert_visible: "Plan Visit"
diff:
  threshold: 0.02
  perceptual_threshold: 5.0
```

iOS file adds `scheme: "Landmarks (UI Testing)"`, `simulator: qa-ios-1`, `bundle_id: com.kylebrowning.Landmarks`. Android file adds `platform: android`, `module: app`, `variant: freeDebug`, `application_id: com.kylebrowning.landmarks`, `emulator: Pixel_8_API_35`.

---

### Task 0: Shared binary, worktrees, demo repo bootstrap

Run by the orchestrating session.

**Files:**
- Create: `/Users/kyle/.grantiva-qa/bin/grantiva`, `/Users/kyle/.grantiva-qa/VERSION`
- Create: worktrees `.worktrees/qa-cli`, `.worktrees/qa-ios`, `.worktrees/qa-android`
- Create: repo `grantiva/landmarks-demo` with `README.md`, `ios/`, `android/`, `flows/README.md`

- [ ] **Step 1: Build the shared binary from the target commit**

```bash
cd /Users/kyle/Developer/grantiva-cli && git rev-parse --short HEAD   # must print c8dc86d on main; qa-campaign branch is c8dc86d plus docs
swift build -c release 2>&1 | tail -1
mkdir -p ~/.grantiva-qa/bin && cp .build/release/grantiva ~/.grantiva-qa/bin/grantiva
~/.grantiva-qa/bin/grantiva --version | tee ~/.grantiva-qa/VERSION
~/.grantiva-qa/bin/grantiva runner install 2>&1 | tail -1
~/.grantiva-qa/bin/grantiva runner version
```
Expected: version printed, runner installed under `~/.grantiva/runner`.

- [ ] **Step 2: Create the worktrees**

```bash
cd /Users/kyle/Developer/grantiva-cli
for s in cli ios android; do git worktree add -q .worktrees/qa-$s -b qa/$s qa-campaign; mkdir -p .worktrees/qa-$s/findings/evidence; done
grep -q '^\.worktrees/' .gitignore || echo '.worktrees/' >> .gitignore
git worktree list
```

- [ ] **Step 3: Create the demo repo**

```bash
mkdir -p /Users/kyle/Developer/landmarks-demo && cd /Users/kyle/Developer/landmarks-demo && git init -q -b main
mkdir -p ios android flows
cat > README.md <<'MD'
# Landmarks demo apps for Grantiva

Two implementations of the same Landmarks app, iOS (SwiftUI) and Android (Jetpack Compose),
with identical labels, data, and Maestro-format flows, used to exercise every Grantiva CLI
feature. See `flows/README.md` for what each flow covers and the environment variables the apps
read (`LANDMARKS_SEED`, `LANDMARKS_CRASH_ON_LAUNCH`, `LANDMARKS_NOTE`).

- `ios/` — scheme `Landmarks (UI Testing)`, bundle `com.kylebrowning.Landmarks`
- `android/` — module `app`, variant `freeDebug`, application id `com.kylebrowning.landmarks`
MD
printf 'build/\n.build/\nDerivedData/\n.gradle/\n*.xcuserstate\nxcuserdata/\n.grantiva/captures/\nlocal.properties\n.idea/\n' > .gitignore
git add -A && git commit -q -m "Bootstrap landmarks-demo"
gh repo create grantiva/landmarks-demo --private --source=. --remote=origin --push
```

- [ ] **Step 4: Write `flows/README.md`** with the "Shared label contract" and "Shared flows" tables from this plan copied verbatim, then commit and push.

---

### Task 1: iOS demo app

Run by a build agent in `/Users/kyle/Developer/landmarks-demo/ios`. Source: `kylebrowning/landmarks-app-complete`.

**Files:**
- Create: `ios/Landmarks.xcodeproj`, `ios/Landmarks/**` (copied, then modified)
- Modify: `Landmarks/LandmarksApp.swift`, `Landmarks/Models/Landmark.swift`, `Landmarks/Services/LandmarkService.swift`, `Landmarks/Views/LandmarkDetailView.swift`, `Landmarks/Views/LandmarkListView.swift`, `Landmarks/Views/DeepLinksView.swift`, `Landmarks/Views/ServicesDemoView.swift`, `Landmarks/Navigation/Screen.swift`, `Landmarks/Navigation/Navigator.swift`
- Create: `Landmarks/Views/SlowScreenView.swift`, `Landmarks/TestEnvironment.swift`, `Landmarks.xcodeproj/xcshareddata/xcschemes/Landmarks (UI Testing).xcscheme`, `Landmarks.xcodeproj/xcshareddata/xcschemes/Landmarks.xcscheme`, `ios/grantiva.yml`, `ios/.maestro/*.yaml`

**Interfaces:**
- Produces: a simulator build selectable with `--scheme "Landmarks (UI Testing)"` whose UI matches the shared label contract.

- [ ] **Step 1: Copy the source app**

```bash
cd /Users/kyle/Developer/landmarks-demo && rm -rf ios && gh repo clone kylebrowning/landmarks-app-complete ios -- -q --depth 1 && rm -rf ios/.git ios/.gitignore
```

- [ ] **Step 2: Add `TestEnvironment.swift`**

```swift
import Foundation

enum TestEnvironment {
    enum Seed: String { case `default`, empty, many }
    static var seed: Seed { Seed(rawValue: ProcessInfo.processInfo.environment["LANDMARKS_SEED"] ?? "") ?? .default }
    static var crashOnLaunch: Bool { ProcessInfo.processInfo.environment["LANDMARKS_CRASH_ON_LAUNCH"] == "1" }
    static var note: String? { ProcessInfo.processInfo.environment["LANDMARKS_NOTE"] }
}
```

- [ ] **Step 3: Extend sample data** in `Landmark.swift`. Replace `sampleData` with the ten landmarks from the label contract (stable UUIDs: `00000000-0000-0000-0000-00000000000N`), add:

```swift
static func seeded(_ seed: TestEnvironment.Seed) -> [Landmark] {
    switch seed {
    case .default: return sampleData
    case .empty: return []
    case .many:
        let cats = Category.allCases
        return sampleData + (11...70).map { i in
            Landmark(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!,
                     name: "Landmark \(i)", location: "Nowhere, CA", description: "Generated landmark \(i).",
                     imageName: "goldengate", category: cats[(i - 1) % cats.count])
        }
    }
}
```
In `LandmarkService.mock`, replace every `Landmark.sampleData` with `Landmark.seeded(TestEnvironment.seed)`.

- [ ] **Step 4: Scheme and compilation condition.** In `project.pbxproj`, for both Debug and Release configurations of the app target, set `IPHONEOS_DEPLOYMENT_TARGET = 26.0`. Add a new build configuration `UITesting` duplicated from Debug with `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG UI_TESTING"`. Create shared scheme `Landmarks (UI Testing)` whose Run and Build actions use `UITesting`, and share the default `Landmarks` scheme. Verify with:

```bash
cd /Users/kyle/Developer/landmarks-demo/ios && xcodebuild -list -project Landmarks.xcodeproj
```
Expected: schemes `Landmarks` and `Landmarks (UI Testing)`; configurations include `UITesting`.

- [ ] **Step 5: App entry.** In `LandmarksApp.swift`:

```swift
init() {
    #if UI_TESTING
    services = .mock
    #elseif DEBUG
    services = .live(baseURL: URL(string: "http://localhost:8080")!)
    #else
    services = .live(baseURL: URL(string: "https://api.yourapp.com")!)
    #endif
    if TestEnvironment.crashOnLaunch {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { fatalError("LANDMARKS_CRASH_ON_LAUNCH") }
    }
}
```

- [ ] **Step 6: Labels.** Detail toolbar favorite button: add `.accessibilityLabel(isFavorite ? "Unfavorite" : "Favorite")` where `isFavorite` reads the store's favorite state for the landmark (the existing code wrongly uses `isFeatured` for the heart icon; fix it to use favorites). Landmark list: when `store.landmarks.isEmpty` after load, show `ContentUnavailableView("No landmarks yet", systemImage: "map")`. Deep Links: add `Text(note)` under the title when `TestEnvironment.note` is set, and a button `Slow Screen` navigating to `.deepLinks(.slowScreen)` (add the case to `Screen.DeepLinksScreen` and the destination in `DestinationContent`). Caching demo: add a `TimelineView(.periodic(from: .now, by: 1))` rendering `Date.now.formatted(date: .omitted, time: .standard)` with `.accessibilityIdentifier("clock")`.

- [ ] **Step 7: `SlowScreenView.swift`**

```swift
import SwiftUI
struct SlowScreenView: View {
    @State private var loaded = false
    var body: some View {
        Group { if loaded { Text("Loaded after delay") } else { ProgressView("Loading…") } }
            .navigationTitle("Slow Screen")
            .task { try? await Task.sleep(for: .seconds(3)); loaded = true }
    }
}
```

- [ ] **Step 8: Deep link slugs.** In `Navigator.swift` URL handling, resolve `landmarks://landmark/<slug>` by matching `slug == name.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }.replacingOccurrences(of: " ", with: "-")`, and `landmarks://category/<raw>` case-insensitively. Register `CFBundleURLSchemes = ["landmarks"]` via `INFOPLIST_KEY_CFBundleURLTypes` or an `Info.plist` entry.

- [ ] **Step 9: Build and smoke**

```bash
cd /Users/kyle/Developer/landmarks-demo/ios
xcodebuild -scheme "Landmarks (UI Testing)" -project Landmarks.xcodeproj -destination 'generic/platform=iOS Simulator' -derivedDataPath build build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Write `ios/grantiva.yml` and `ios/.maestro/01…12,99` from the shared flows with `appId: com.kylebrowning.Landmarks`.**

- [ ] **Step 11: Run the gate**

```bash
export GRANTIVA=~/.grantiva-qa/bin/grantiva GRANTIVA_SESSION_ID=qa-build-ios
cd /Users/kyle/Developer/landmarks-demo/ios
udid=$($GRANTIVA simulator ensure --name qa-build-ios --runtime 26.0)
for f in .maestro/0*.yaml .maestro/1*.yaml; do $GRANTIVA run --flow "$f" --simulator "$udid" --report-dir "build/reports/$(basename $f .yaml)" || echo "GATE FAIL $f"; done
$GRANTIVA run --flow .maestro/99-crash.yaml --simulator "$udid" --no-build && echo "GATE FAIL 99 should fail"
$GRANTIVA simulator teardown --session-id qa-build-ios
```
Expected: no `GATE FAIL`. Fix the app, not the flows, until green. If a flow fails because of a CLI defect rather than the app, write it to `/Users/kyle/Developer/landmarks-demo/ios/GATE-NOTES.md` with the exact command and output, and work around it in the app only if the shared label contract is preserved.

- [ ] **Step 12: Commit and push**

```bash
cd /Users/kyle/Developer/landmarks-demo && git add ios && git commit -q -m "Add iOS Landmarks demo with UI Testing scheme and flows" && git push -q
```

---

### Task 2: Android demo app

Run by a build agent in `/Users/kyle/Developer/landmarks-demo/android`. Shell starts with the Android exports from Global Constraints.

**Files:**
- Create: `android/settings.gradle.kts`, `android/build.gradle.kts`, `android/gradle.properties`, `android/gradle/libs.versions.toml`, `android/gradlew` (+ wrapper jar and properties), `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/java/com/kylebrowning/landmarks/` — `LandmarksApp.kt` (Application: crash-on-launch), `MainActivity.kt` (reads intent extras and env into `TestEnvironment`, sets content), `TestEnvironment.kt`, `data/Landmark.kt`, `data/Category.kt`, `data/SampleData.kt`, `data/LandmarkStore.kt`, `nav/Screen.kt`, `nav/AppNavHost.kt`, `ui/LandmarksListScreen.kt`, `ui/LandmarkDetailScreen.kt`, `ui/CategoryScreen.kt`, `ui/VisitConfirmationScreen.kt`, `ui/EditLandmarkScreen.kt`, `ui/FavoritesScreen.kt`, `ui/DeepLinksScreen.kt`, `ui/CachingDemoScreen.kt`, `ui/SlowScreen.kt`
- Create: `android/grantiva-android.yml`, `android/.maestro/*.yaml`

**Interfaces:**
- Produces: `./gradlew :app:assembleFreeDebug` yields `app/build/outputs/apk/free/debug/app-free-debug.apk` with `output-metadata.json` carrying `applicationId`.

- [ ] **Step 1: Gradle skeleton.** AGP 8.7.x, Kotlin 2.0.x, Compose BOM 2024.10, `compose-navigation` 2.8.x, Material3. `app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.kylebrowning.landmarks"; compileSdk = 35
    defaultConfig { applicationId = "com.kylebrowning.landmarks"; minSdk = 26; targetSdk = 35; versionCode = 1; versionName = "1.0" }
    flavorDimensions += "tier"
    productFlavors { create("free") { dimension = "tier" }; create("paid") { dimension = "tier"; applicationIdSuffix = ".paid" } }
    buildTypes { release { isMinifyEnabled = false; signingConfig = signingConfigs.getByName("debug") } }
    buildFeatures { compose = true }
}
```
`AndroidManifest.xml`: `MainActivity` exported, launcher intent filter, plus a `VIEW` intent filter with `<data android:scheme="landmarks" />` and `BROWSABLE`/`DEFAULT` categories. `android:name=".LandmarksApp"` on `<application>`.

- [ ] **Step 2: Test environment**

```kotlin
object TestEnvironment {
    enum class Seed { DEFAULT, EMPTY, MANY }
    var seed: Seed = Seed.DEFAULT; var crashOnLaunch = false; var note: String? = null
    fun load(extras: android.os.Bundle?) {
        fun v(k: String) = extras?.getString(k) ?: System.getenv(k)
        seed = when (v("LANDMARKS_SEED")) { "empty" -> Seed.EMPTY; "many" -> Seed.MANY; else -> Seed.DEFAULT }
        crashOnLaunch = v("LANDMARKS_CRASH_ON_LAUNCH") == "1"; note = v("LANDMARKS_NOTE")
    }
}
```
`MainActivity.onCreate` calls `TestEnvironment.load(intent.extras)` before `setContent`, then if `crashOnLaunch` posts `{ throw RuntimeException("LANDMARKS_CRASH_ON_LAUNCH") }` with a 500 ms delay on the main handler.

- [ ] **Step 3: Data.** `Category(val label: String) { MOUNTAINS("Mountains"), LAKES("Lakes"), BRIDGES("Bridges") }`. `Landmark(id: String, name, location, description, isFeatured, category)`. `SampleData.seeded(seed)` returns the ten contract landmarks, empty, or ten plus `Landmark 11..70` as in the contract. `LandmarkStore` is a singleton holding `landmarks: SnapshotStateList<Landmark>` and `favorites: SnapshotStateList<String>` (ids) with `toggleFavorite`, `update(landmark)`, and `clear()`.

- [ ] **Step 4: Screens.** Bottom `NavigationBar` with items labelled `Landmarks`, `Favorites`, `Deep Links` (text labels always shown). Each tab is its own `NavHost` back stack. Screens render the contract labels exactly:
  - List: `LazyColumn` with section headers `Featured`, `Categories`, `All Landmarks`; rows show name and location; empty seed shows `No landmarks yet`.
  - Detail: `TopAppBar(title = name)` with an `IconButton` whose `Modifier.semantics { contentDescription = if (fav) "Unfavorite" else "Favorite" }`; body `About`, description, `Button("Plan Visit")`.
  - Visit confirmation: `Visit Scheduled!`, `You're all set to visit $name.`, `Button("Done")` pops back.
  - Favorites: list of favorite landmarks; `SwipeToDismissBox` revealing `Remove` (also add a visible `Remove` text button per row so `tapOn: "Remove"` resolves after the swipe); empty text `Landmarks you favorite will appear here.`
  - Edit: `OutlinedTextField` labelled `Name` and `Location` (labels via `label = { Text("Name") }` and `contentDescription`), top bar `Cancel` and `Done`; `Cancel` with changes shows `AlertDialog` text `You have unsaved changes that will be lost.`, buttons `Discard`, `Keep Editing`. Opened from Deep Links on Golden Gate Bridge; `Done` saves to the store and pops back, so the list shows `Golden Gate Bridge Renamed`.
  - Deep Links: title, optional note text, buttons from the contract; `landmarks://…` buttons call the same resolver as the `VIEW` intent.
  - Caching demo: `Cache Policy` exposed dropdown with the five options, `Fetch with Policy`, `Clear Cache`, clock `Text` updated every second via `LaunchedEffect` with `testTag("clock")` and `contentDescription = "clock"`.
  - Slow screen: `Loading…` then `Loaded after delay` after `delay(3000)`.

- [ ] **Step 5: Build**

```bash
cd /Users/kyle/Developer/landmarks-demo/android && ./gradlew -q :app:assembleFreeDebug :app:assemblePaidDebug :app:assembleFreeRelease 2>&1 | tail -5
ls app/build/outputs/apk/free/debug/ && cat app/build/outputs/apk/free/debug/output-metadata.json | grep applicationId
```
Expected: three APKs, `applicationId` is `com.kylebrowning.landmarks`.

- [ ] **Step 6: Write `android/grantiva-android.yml` and `android/.maestro/*` from the shared flows with `appId: com.kylebrowning.landmarks`.**

- [ ] **Step 7: Run the gate**

```bash
export GRANTIVA=~/.grantiva-qa/bin/grantiva GRANTIVA_SESSION_ID=qa-build-android
cd /Users/kyle/Developer/landmarks-demo/android
$GRANTIVA doctor --platform android
for f in .maestro/0*.yaml .maestro/1*.yaml; do $GRANTIVA run --flow "$f" --emulator Pixel_8_API_35 --report-dir "build/reports/$(basename $f .yaml)" || echo "GATE FAIL $f"; done
$GRANTIVA run --flow .maestro/99-crash.yaml --no-build --emulator Pixel_8_API_35 && echo "GATE FAIL 99 should fail"
```
Expected: no `GATE FAIL`. Same rule as iOS: fix the app, record CLI defects in `android/GATE-NOTES.md`.

- [ ] **Step 8: Commit and push**

```bash
cd /Users/kyle/Developer/landmarks-demo && git add android && git commit -q -m "Add Android Landmarks demo in Compose with flows" && git push -q
```

---

### Task 3: Feature matrix

Run by a matrix agent in `.worktrees/qa-cli` (read-only on the CLI source). Output is consumed by Tasks 5 to 7.

**Files:**
- Create: `docs/superpowers/plans/2026-10-09-qa-feature-matrix.md`

**Interfaces:**
- Produces: a table with columns `ID | Command | Flags/inputs | Expected | Source | Result`, IDs `CLI-001…`, `IOS-001…`, `AND-001…`, one section per slice. The Review Focus IDs in this plan (CLI-044, CLI-061, IOS-031, IOS-033, IOS-035, IOS-041, IOS-052, AND-033, AND-035, AND-041, AND-052) must exist with exactly those meanings.

- [ ] **Step 1: Enumerate the surface mechanically**

```bash
export GRANTIVA=~/.grantiva-qa/bin/grantiva
walk(){ $GRANTIVA $1 --help 2>&1 > "help/$(echo $1 | tr ' ' _).txt"; for s in $(awk '/^SUBCOMMANDS:/{f=1;next} /^[A-Z]/{f=0} f && /^  [a-z]/{print $1}' "help/$(echo $1 | tr ' ' _).txt"); do [ $s = help ] || walk "$1 $s"; done; }
mkdir -p help && for t in run record hierarchy build ci diff simulator emulator auth doctor runner mcp init console; do walk $t; done; ls help | wc -l
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"qa","version":"0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n' | $GRANTIVA mcp --project-dir /tmp > help/mcp-tools.json
```

- [ ] **Step 2: Write rows.** For each help file, one row per flag and one per documented behavior in README, `docs/*.md`, `SIMULATOR-LIFECYCLE.md`, and CHANGELOG entries since 0.9. Every `Expected` cell quotes or paraphrases its `Source` (`README §Agent-Native Features`, `docs/android.md §Devices`, `help: run`, `CHANGELOG 1.x`). Target at least 70 CLI rows, 90 iOS rows, 90 Android rows. Include every spec section 2 bullet.

- [ ] **Step 3: Cross-source consistency pass.** Where README, docs, CHANGELOG, and help disagree, add a `CLI-` row whose `Expected` is "sources agree" and mark it `fail` with a finding in `findings/cli-docs.md` immediately.

- [ ] **Step 4: Commit on branch `qa/cli`**

```bash
cd /Users/kyle/Developer/grantiva-cli/.worktrees/qa-cli && git add docs/superpowers/plans/2026-10-09-qa-feature-matrix.md findings && git commit -q -m "Add QA feature matrix"
```

---

### Task 4: Gate check and campaign kickoff

Orchestrator. Depends on Tasks 1, 2, 3.

- [ ] **Step 1:** Confirm both `GATE-NOTES.md` files (if present) are read and their CLI defects seeded into `findings/` as `GATE-F<nn>` entries in the matching slice.
- [ ] **Step 2:** Copy the matrix into the iOS and Android worktrees: `cp .worktrees/qa-cli/docs/superpowers/plans/2026-10-09-qa-feature-matrix.md .worktrees/qa-ios/docs/superpowers/plans/ && cp … .worktrees/qa-android/docs/superpowers/plans/`.
- [ ] **Step 3:** Record host baseline: `xcrun simctl list devices booted > ~/.grantiva-qa/host-before.txt; adb devices >> ~/.grantiva-qa/host-before.txt`.
- [ ] **Step 4:** Launch Tasks 5, 6, 7 as three concurrent agents with the briefs below.

---

### Task 5: CLI slice campaign

Agent in `.worktrees/qa-cli`. Fixtures under `.worktrees/qa-cli/fixtures/` (git-tracked). `GRANTIVA_SESSION_ID=qa-cli`.

**Files:**
- Create: `fixtures/detect/{xcode-only,gradle-only,both,neither,maestro-dir,maestro-yml,both-configs}/…`, `fixtures/config/{malformed.yml,unknown-keys.yml,every-step.yml,run-flow/…}`, `fixtures/maestro/<command>.yaml` for each supported and unsupported Maestro command
- Create: `findings/cli.md`, `findings/evidence/**`
- Modify: matrix `CLI-` rows' `Result` column

- [ ] **Step 1: Contracts.** For every help file from Task 3: run `--help`, assert exit 0 and stdout non-empty and stderr empty. For every command advertising `--json` that works without a device (`doctor`, `auth status`, `runner version`, `simulator sessions`, `emulator sessions`, `init`-free ones), run with `--json`, `--json --quiet`, `--json --verbose`; pipe stdout to `python3 -I -c 'import json,sys; json.load(sys.stdin)'`; assert stderr contains no JSON.
- [ ] **Step 2: Detection and config.** Build the fixture directories (empty `App.xcodeproj/project.pbxproj`, empty `settings.gradle.kts`, etc.). In each, run `$GRANTIVA doctor`, `$GRANTIVA init`, `$GRANTIVA run --no-build` and record the platform chosen or the error, with and without `--platform`, `GRANTIVA_PLATFORM`. Verify malformed YAML names file and line. Verify `--scheme` on Android and `--module` on iOS are rejected naming the flag.
- [ ] **Step 3: Maestro parsing.** For each fixture flow, `$GRANTIVA run --flow fixtures/maestro/<cmd>.yaml --platform ios --simulator qa-cli-1 --no-build --report-dir out/<cmd>` against an installed iOS Landmarks build (use `qa-cli-1`, ensure it, install once via `build install` from the demo repo). Record whether supported commands execute and unsupported ones are skipped silently as the README says. CLI-061 is the quoted-label flow. CLI-044 is a config with `flows: []`.
- [ ] **Step 4: Unauthenticated surface.** With `GRANTIVA_API_KEY` unset and no stored credentials: `auth status`, `auth logout`, `ci run` in the iOS demo dir, and every `console <group> list|show|overview` read command. Expect a clear not-authenticated error, non-zero exit, empty stdout.
- [ ] **Step 5: MCP.** Write `fixtures/mcp/send.sh` that pipes newline-delimited JSON-RPC to `$GRANTIVA mcp --project-dir <dir> --platform <p>`. For all 19 tools: `tools/call` with no arguments, wrong types, and a valid call with no device. Assert each error is a JSON-RPC error or `isError: true` result with a message, never a hang (wrap in `timeout 30`). Compare `tools/list` schemas with `--platform ios` and `--platform android`.
- [ ] **Step 6: Runner.** `runner install` twice (idempotent, second is fast), `runner version`, tamper `~/.grantiva/runner/version` then `runner install` repairs it (restore afterwards).
- [ ] **Step 7:** Write every finding to `findings/cli.md` in the spec's template, fill the matrix `Result` column, commit on `qa/cli`. Teardown `qa-cli-1` with `simulator teardown --session-id qa-cli`.

---

### Task 6: iOS slice campaign

Agent in `.worktrees/qa-ios`, app at `/Users/kyle/Developer/landmarks-demo/ios`. `GRANTIVA_SESSION_ID=qa-ios`. Simulators `qa-ios-1..3`, runtime 26.0 unless a row says 27.0.

**Files:**
- Create: `findings/ios.md`, `findings/evidence/**`
- Modify: matrix `IOS-` rows

- [ ] **Step 1: Simulator lifecycle.** `ensure` by name only, `--device-type`, `--runtime 27.0`, `--runtime latest`, `--no-boot`, `--json` (check geometry fields), reuse by name returns the same UDID, stdout is only the UDID. `sessions`, `teardown --session-id`, `teardown --udid --force` on a simulator with a deliberately orphaned runner (start `run --keep-alive` then `kill -9` the grantiva process), `delete`, `cleanup`. Capacity: with `GRANTIVA_MAX_SIMULATORS=2` boot two, start a third with `GRANTIVA_SIMULATOR_WAIT_TIMEOUT_SECONDS=20`, confirm it waits, lists occupants, and times out with a non-zero exit. Confirm the pre-existing `iPhone 17 Pro` is never listed as Grantiva-managed and never shut down.
- [ ] **Step 2: Build.** `build`, `build install --no-launch --json` (check `dataContainerPath` exists and is writable; seed a file; then `run --no-build` flow 01 and confirm the file survived), `--derived-data-path "/private/tmp/qa ios/dd"` with the space, wrong `--scheme` error text, `--app-file` with the built `.app` and with an `.ipa` zipped from it (`Payload/Landmarks.app`), `--app-file` pointing at a device (non-simulator) build must be rejected.
- [ ] **Step 3: Run flags.** For each row: default (all flows from `grantiva.yml`), `--flow` each shared flow, `--continue-on-failure` with `99-crash` first in the list, `--snapshot` each accepted value, `--report-dir` (assert `report.json`, assets, failure screenshot for 99, and that `.grantiva/captures` was not written), `--timeout 5` against the slow flow, `--wait-for-idle-timeout`, `--env LANDMARKS_NOTE=hello` (assert `hello` visible via hierarchy), IOS-035 (`--env 'LANDMARKS_NOTE=a=b c'`), `--logs` (assert `[log]` lines appear and are scoped to the bundle), `--logs-predicate`, `--logs-level`, `--ready-file` (status values for pass, fail, interrupted; file removed at startup; IOS-033 unwritable path fails before build), IOS-031 (empty flows list), IOS-041 (quoted label flow 12).
- [ ] **Step 4: Keep-alive and hierarchy.** `run --flow 01 --keep-alive --ready-file` in the background; after ready, `hierarchy`, `hierarchy --format json`, `hierarchy --udid`, `hierarchy --timeout 1`; start a second keep-alive on `qa-ios-2` and run `hierarchy` with no `--udid` (IOS-052); `kill -INT` the first and assert `/tmp/grantiva-sessions/` has no file or owner sidecar for it and no `grantiva-runner`, `WebDriverAgent`, or `xcodebuild` child survives (`pgrep -fl`). Second run against an owned UDID fails fast with the documented guidance. Two concurrent runs on `qa-ios-1` and `qa-ios-3` both pass.
- [ ] **Step 5: Record.** `record --simulator qa-ios-1 --duration 4 --output findings/evidence/rec.mp4 --frames-at 500,1500,3500 --json`; assert the video and three PNGs exist and JSON lists them.
- [ ] **Step 6: Runner sessions.** `runner start` on `qa-ios-2`, `hierarchy --udid`, `runner stop`; stop twice; stop with no session.
- [ ] **Step 7: Diff.** `diff capture` (five screens), `diff approve`, `diff compare` is clean, then `diff capture` with `--env LANDMARKS_SEED=many` and `diff compare` reports Home changed with a diff image; raise `threshold` to 1.0 and confirm pass; `--json` on each. Check `.grantiva/baselines/` layout and that Android directories are not created.
- [ ] **Step 8: MCP against a live session.** With keep-alive held on `qa-ios-1`, drive `$GRANTIVA mcp --project-dir <ios dir>`: `grantiva_context`, `hierarchy`, `grantiva_tap` on `Favorites`, `grantiva_type`, `grantiva_swipe`, `grantiva_screenshot` and `screenshot` (verify the file lands at the requested path; memory from a prior session says it may not), `grantiva_script`, `grantiva_sim_list|ensure|boot|delete`, `grantiva_build`, `grantiva_run`, `grantiva_test`, `grantiva_vrt_capture|compare|approve`.
- [ ] **Step 9:** Findings to `findings/ios.md`, matrix results, commit on `qa/ios`, teardown `--session-id qa-ios`, confirm `xcrun simctl list devices booted` matches the baseline plus nothing of yours.

---

### Task 7: Android slice campaign

Agent in `.worktrees/qa-android`, app at `/Users/kyle/Developer/landmarks-demo/android`. `GRANTIVA_SESSION_ID=qa-android`. Android exports at the top of every shell.

**Files:**
- Create: `findings/android.md`, `findings/evidence/**`
- Modify: matrix `AND-` rows

- [ ] **Step 1: Doctor and environment.** `doctor --platform android` and `--json` with the toolchain; then in a shell with `ANDROID_HOME` unset and `PATH` stripped of the SDK: expected failing checks and non-zero exit.
- [ ] **Step 2: Emulator lifecycle.** `emulator ensure --name qa-android-1 --system-image "system-images;android-35;google_apis;arm64-v8a"` (installs image if needed, prints serial), `--no-boot` prints the AVD name, `sessions`, `teardown <serial>`, `delete qa-android-1` (refused while running; allowed after teardown), `delete Pixel_8_API_35` without `--force` refused. `--headless` boot of `qa-android-1`.
- [ ] **Step 3: Build and variants.** `build` default (`freeDebug` from config), `--variant paidDebug` (application id gains `.paid`; confirm the run launches the right id), `--variant freeRelease`, `--module app`, `--application-id` override, `--app-file` with the APK (id read from APK), `run --no-build` with no `application_id` in config and no `--app-file` is the documented error.
- [ ] **Step 4: Run flags.** Same list as iOS Step 3 using `--emulator` / `--device emulator-5554`, plus `--logs`, `--logs-tag Landmarks`, `--logs-level`, and `--logs-predicate` rejected. AND-033, AND-035, AND-041 as defined in Review Focus.
- [ ] **Step 5: Device settings.** Read `adb shell settings get global animator_duration_scale` before; run flow 01; confirm scale was 0 during (poll in background) and restored after; confirm `.grantiva/android-settings-emulator-5554.json` exists during and is removed after; `kill -9` a run mid-flow, confirm the file persists, run again, confirm settings restored and file removed. Confirm demo mode clock reads 09:41 in a capture and the app clock still ticks.
- [ ] **Step 6: Keep-alive and hierarchy.** As iOS Step 4 on `emulator-5554` and `qa-android-1`; additionally confirm `adb forward --list` is empty for both serials after Ctrl-C and `/tmp/uia2-*.sock` is gone; AND-052 with two sessions.
- [ ] **Step 7: Record.** `record --device emulator-5554 --duration 4 --frames-at 500,1500,3500 --json`; note the documented duration cap.
- [ ] **Step 8: Diff and refusals.** `diff capture|approve|compare` under `.grantiva/captures/android/` and `.grantiva/baselines/android/`; `ci run` refuses with the exact documented message; confirm iOS directories untouched.
- [ ] **Step 9: Runner sessions and MCP.** `runner start --device emulator-5554`, `hierarchy --udid emulator-5554`, `runner stop`; MCP with `--platform android` for every tool as in iOS Step 8 (`grantiva_sim_*` should either map to emulators or error clearly; record which).
- [ ] **Step 10:** Findings to `findings/android.md`, matrix results, commit on `qa/android`, `emulator teardown` only your serials, `adb devices` matches baseline.

---

### Task 8: Triage, issues, report

Orchestrator, after Tasks 5 to 7.

- [ ] **Step 1: Merge.** Concatenate the three findings files plus `GATE-F*` into `~/.grantiva-qa/findings-all.md`. Group by behavior; a cross-platform duplicate becomes one entry listing both repros.
- [ ] **Step 2: Confirm.** Re-run each entry's `Repro` once with `$GRANTIVA`. Drop entries that do not reproduce, keep them in an appendix marked `not reproduced`.
- [ ] **Step 3: File.** `gh label create qa-campaign --repo grantiva/cli --color D93F0B --force`, then per confirmed entry:

```bash
gh issue create --repo grantiva/cli --label qa-campaign --title "<behavior, imperative>" --body-file <entry.md>
```
Body is the finding entry plus a `Demo repro` line linking `grantiva/landmarks-demo` and the flow path, and the binary version from `~/.grantiva-qa/VERSION`. Severity `docs` entries get the additional label `documentation`.
- [ ] **Step 4: Report.** Write `docs/superpowers/plans/2026-10-09-qa-campaign-report.md` on `qa-campaign`: matrix totals per slice (pass, fail, blocked, host), findings by severity, issue links, host-caused items, and the demo repo commit. Commit, merge the three `qa/*` branches into `qa-campaign`, push, open a PR titled "QA campaign: feature matrix, findings, report".
- [ ] **Step 5: Host restore.** `simulator cleanup`, `emulator sessions` empty, diff `host-before.txt` against the current state.
