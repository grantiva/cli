# Android Support, Plan 1 of 3: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the Android toolchain on the development Mac, settle the runner keep-alive question, and introduce the platform resolution, config, and `DevicePlatform` seam so that every iOS command runs exactly as before but through an abstraction an Android implementation can slot into.

**Architecture:** A `Platform` enum is resolved once per command from flag, environment, config files, and directory contents. `GrantivaConfig` gains a `project` enum carrying either Xcode or Gradle fields. A `DevicePlatform` protocol owns every simctl, xcodebuild, and runner-argument decision; `IOSPlatform` is a pure extraction of today's code. Commands hold a `DevicePlatform` value instead of calling SimulatorManager and XcodeBuildRunner directly. No Android implementation ships in this plan; Plan 2 adds `AndroidPlatform`, Plan 3 adds the emulator subcommand, hierarchy, MCP, and record.

**Tech Stack:** Swift 6.1 package, macOS 15+, ArgumentParser, Yams, XCTest. Homebrew, Temurin JDK, Android command-line tools.

**Spec:** `docs/superpowers/specs/2026-10-07-android-support-design.md`

## Global Constraints

- Package stays `platforms: [.macOS(.v15)]`; no Linux.
- Config file names are exactly `grantiva.yml` (iOS) and `grantiva-android.yml` (Android).
- Platform flag is `--platform ios|android`; environment variable is `GRANTIVA_PLATFORM`.
- A config file that exists but fails to parse is an error with the YAML diagnostic, never a silent fallthrough.
- Device identifiers stay in fields and JSON keys named `udid`; no renames.
- `BuildResult.scheme` and `destination` become optional; `CaptureSimulatorTarget` and its `simulator` JSON key are unchanged.
- Runner tarball adds only `drivers/android/appium-uiautomator2-server-v*.apk` and `drivers/android/appium-uiautomator2-server-debug-androidTest.apk`.
- Every existing test keeps passing after every task. `swift test` is the gate.
- No Claude attribution lines in commits.

## Review Focus

1. A `grantiva.yml` with a YAML syntax error must stop the command with the parser's line and column, not run against detected defaults. Pinned in Task 5.
2. `--platform android` in a directory with only `grantiva.yml` must error naming the missing `grantiva-android.yml`, not load the iOS file as Android. Pinned in Task 4.
3. `GRANTIVA_PLATFORM=android` must lose to an explicit `--platform ios`. Pinned in Task 4.
4. An old `.grantiva/config.json` written before this change must still load as an iOS detection cache. Pinned in Task 5.
5. `grantiva simulator teardown --udid emulator-5554` must be rejected: the simulator subcommand is iOS-only even though the validator now accepts serials. Pinned in Task 6.

---

### Task 1: Local Android environment

**Files:**
- Create: `scripts/android-env.sh`
- Create: `docs/android-environment.md`

**Interfaces:**
- Produces: a working `adb`, `emulator`, `avdmanager`, `sdkmanager` under `~/Library/Android/sdk`, a JDK, and one AVD named `Pixel_8_API_35`. Later tasks and plans assume these names.

- [ ] **Step 1: Write the setup script**

```bash
#!/bin/zsh
# scripts/android-env.sh — install the Android toolchain Grantiva needs for
# Android development on this Mac. Idempotent; re-run freely.
set -euo pipefail

SDK="$HOME/Library/Android/sdk"
AVD_NAME="Pixel_8_API_35"
IMAGE="system-images;android-35;google_apis;arm64-v8a"

brew list --cask temurin >/dev/null 2>&1 || brew install --cask temurin
brew list --cask android-commandlinetools >/dev/null 2>&1 || brew install --cask android-commandlinetools

mkdir -p "$SDK"
export ANDROID_HOME="$SDK"
export JAVA_HOME="$(/usr/libexec/java_home)"

# Homebrew puts cmdline-tools under its own prefix; sdkmanager needs --sdk_root
# to populate ~/Library/Android/sdk, which is where Grantiva looks.
SDKMANAGER="$(brew --prefix)/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null
"$SDKMANAGER" --sdk_root="$SDK" "platform-tools" "emulator" "cmdline-tools;latest" "build-tools;35.0.0" "platforms;android-35" "$IMAGE"

AVDMANAGER="$SDK/cmdline-tools/latest/bin/avdmanager"
if ! "$AVDMANAGER" list avd | grep -q "Name: $AVD_NAME"; then
  echo no | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "$IMAGE" -d pixel_8
fi

echo
echo "Add to your shell profile:"
echo "  export ANDROID_HOME=\"$SDK\""
echo "  export PATH=\"\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH\""
echo
"$SDK/platform-tools/adb" version | head -1
"$SDK/emulator/emulator" -version | head -1
"$AVDMANAGER" list avd | grep "Name:"
```

- [ ] **Step 2: Run it**

Run: `chmod +x scripts/android-env.sh && scripts/android-env.sh`
Expected: ends with an adb version line, an emulator version line, and `Name: Pixel_8_API_35`. Takes 10 to 20 minutes on first run; the system image is about 1.5 GB.

- [ ] **Step 3: Boot the AVD once and confirm adb sees it**

Run:
```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
"$ANDROID_HOME/emulator/emulator" -avd Pixel_8_API_35 -no-snapshot-save -no-boot-anim >/dev/null 2>&1 &
until [ "$("$ANDROID_HOME/platform-tools/adb" -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
"$ANDROID_HOME/platform-tools/adb" devices -l
```
Expected: a line `emulator-5554 device product:... model:... device:...`. Leave it running for Task 3.

- [ ] **Step 4: Write the environment doc**

```markdown
# Android development environment

Grantiva's Android support drives an emulator through `adb`. Install the toolchain with:

    scripts/android-env.sh

It installs Temurin (JDK), the Android command-line tools, platform-tools, the emulator,
one API 35 arm64 system image, and creates an AVD named `Pixel_8_API_35`. Then add to your
shell profile:

    export ANDROID_HOME="$HOME/Library/Android/sdk"
    export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

Grantiva finds the SDK through `ANDROID_HOME`, then `ANDROID_SDK_ROOT`, then
`~/Library/Android/sdk`.

## CI

GitHub-hosted macOS runners cannot boot the Android emulator (no nested virtualization),
and Grantiva does not run on Linux. Android `ci run` needs a self-hosted Mac runner or a
developer machine.
```

- [ ] **Step 5: Commit**

```bash
git add scripts/android-env.sh docs/android-environment.md
git commit -m "Add Android environment setup script and doc"
```

---

### Task 2: Ship the UIAutomator2 APKs in the runner tarball

**Files:**
- Modify: `Sources/GrantivaCore/Resources/grantiva-runner-arm64.tar.gz`
- Modify: `Sources/GrantivaCore/Resources/grantiva-runner-amd64.tar.gz`
- Modify: `Sources/GrantivaCore/Runner/RunnerManager.swift:23`
- Test: `Tests/GrantivaCoreTests/RunnerManagerTests.swift`

**Interfaces:**
- Produces: `~/.grantiva/runner/drivers/android/appium-uiautomator2-server-v9.11.1.apk` and `appium-uiautomator2-server-debug-androidTest.apk` after `RunnerManager.live.ensureAvailable()`. `RunnerManager.runnerVersion` stays `"1.1.18-grantiva.7"` because CI compares it to the binary's own `--version`; a new `RunnerManager.installStamp` (`"1.1.18-grantiva.7+android-drivers"`) is what the version file holds, so existing installs re-extract.

- [ ] **Step 1: Write the failing test**

Add to `Tests/GrantivaCoreTests/RunnerManagerTests.swift`:

```swift
func testEmbeddedTarballContainsTheUIAutomator2APKs() throws {
    for arch in ["arm64", "amd64"] {
        let url = try XCTUnwrap(RunnerManager.embeddedTarballURL(arch: arch))
        let listing = try listTarball(url)
        XCTAssertTrue(listing.contains("./drivers/android/appium-uiautomator2-server-v9.11.1.apk"), arch)
        XCTAssertTrue(listing.contains("./drivers/android/appium-uiautomator2-server-debug-androidTest.apk"), arch)
        XCTAssertFalse(listing.contains { $0.hasPrefix("./drivers/android/devicelab") }, "only the UIA2 APKs ship: \(arch)")
    }
}

private func listTarball(_ url: URL) throws -> [String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    process.arguments = ["-tzf", url.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
}
```

Also add this test for the stamp:

```swift
func testInstallStampChangesWhenDriversChangeButRunnerVersionDoesNot() {
    XCTAssertEqual(RunnerManager.runnerVersion, "1.1.18-grantiva.7")
    XCTAssertEqual(RunnerManager.installStamp, "1.1.18-grantiva.7+android-drivers")
}
```

`RunnerManager.embeddedTarballURL(arch:)` does not exist yet; Step 4 adds it (the test target cannot reach GrantivaCore's `Bundle.module` directly).

- [ ] **Step 2: Run it to verify it fails**

Run: `swift test --filter RunnerManagerTests/testEmbeddedTarballContainsTheUIAutomator2APKs`
Expected: FAIL on the first `XCTAssertTrue`.

- [ ] **Step 3: Rebuild both tarballs with the APKs**

```bash
set -euo pipefail
WORK=$(mktemp -d)
gh api repos/grantiva/runner/contents/drivers/android/appium-uiautomator2-server-v9.11.1.apk -H 'Accept: application/vnd.github.raw' > "$WORK/server.apk"
gh api repos/grantiva/runner/contents/drivers/android/appium-uiautomator2-server-debug-androidTest.apk -H 'Accept: application/vnd.github.raw' > "$WORK/test.apk"
for arch in arm64 amd64; do
  rm -rf "$WORK/$arch" && mkdir -p "$WORK/$arch"
  tar -xzf "Sources/GrantivaCore/Resources/grantiva-runner-$arch.tar.gz" -C "$WORK/$arch"
  mkdir -p "$WORK/$arch/drivers/android"
  cp "$WORK/server.apk" "$WORK/$arch/drivers/android/appium-uiautomator2-server-v9.11.1.apk"
  cp "$WORK/test.apk" "$WORK/$arch/drivers/android/appium-uiautomator2-server-debug-androidTest.apk"
  (cd "$WORK/$arch" && tar -czf "$OLDPWD/Sources/GrantivaCore/Resources/grantiva-runner-$arch.tar.gz" .)
done
ls -la Sources/GrantivaCore/Resources/
```

If the GitHub API refuses the raw download because the file is over 1 MB, clone `grantiva/runner` to `$WORK/runner` and copy from `drivers/android/` instead.

- [ ] **Step 4: Add an install stamp so existing installs re-extract**

The CI workflow's "Verify runner version matches embedded tarballs" step compares `RunnerManager.runnerVersion` to the binary's `--version`, and the binary is unchanged, so `runnerVersion` must stay `1.1.18-grantiva.7`. Re-extraction is driven by the version file instead. In `Sources/GrantivaCore/Runner/RunnerManager.swift`:

```swift
    public static let runnerVersion = "1.1.18-grantiva.7"

    /// What the version file holds. Bump the suffix whenever the tarball
    /// layout changes without a runner rebuild, so `installIfNeeded` sees a
    /// mismatch and re-extracts.
    public static let installStamp = runnerVersion + "+android-drivers"

    static func embeddedTarballURL(arch: String) -> URL? {
        Bundle.module.url(forResource: "grantiva-runner-\(arch)", withExtension: "tar.gz")
    }
```

Replace the existing `Bundle.module.url(forResource: archResourceName, withExtension: "tar.gz")` at line 66 with `embeddedTarballURL(arch: ...)` using the same arch string it already computes. Then find where `live` passes `version: runnerVersion` into `installIfNeeded` and pass `version: installStamp` instead. `installIfNeeded` itself is unchanged: it compares the file to whatever `version` it is given.

- [ ] **Step 5: Run the tests**

Run: `swift test --filter RunnerManagerTests`
Expected: PASS, including the two new tests. Then, without deleting anything, run `swift run grantiva runner install` and confirm it re-extracts (the version file previously held `1.1.18-grantiva.7`, which no longer matches the stamp) and `ls ~/.grantiva/runner/drivers/android` lists both APKs. Confirm `cat ~/.grantiva/runner/version` prints `1.1.18-grantiva.7+android-drivers` and `ls ~/.grantiva/runner/cache/wda-builds` still lists the prebuilt WDA builds.

- [ ] **Step 6: Commit**

```bash
git add Sources/GrantivaCore/Resources Sources/GrantivaCore/Runner/RunnerManager.swift Tests/GrantivaCoreTests/RunnerManagerTests.swift
git commit -m "Ship the UIAutomator2 driver APKs in the embedded runner"
```

---

### Task 3: Spike: does the runner serve keep-alive for UIAutomator2?

**Files:**
- Create: `docs/superpowers/plans/2026-10-07-android-spike-result.md`

**Interfaces:**
- Produces: a written answer that Plan 3 reads to choose between the two section 6 designs in the spec.

- [ ] **Step 1: Prepare a trivial flow against a stock app**

With the emulator from Task 1 still running:

```bash
mkdir -p /tmp/spike && cat > /tmp/spike/settings.yaml <<'EOF'
appId: com.android.settings
---
- launchApp
- assertVisible: "Network & internet"
EOF
```

- [ ] **Step 2: Run the runner directly with keep-alive**

```bash
~/.grantiva/runner/grantiva-runner --platform android --device emulator-5554 --no-ansi \
  test --output /tmp/spike/out --flatten --artifacts always --keep-alive /tmp/spike/settings.yaml
```

Leave it running. In another terminal:

```bash
ls /tmp/grantiva-sessions/
cat /tmp/grantiva-sessions/*.grantiva
```

Record: does a session file appear, and what port does it name?

- [ ] **Step 3: Probe the session**

If a session file names a port `P`:

```bash
curl -s "http://127.0.0.1:P/source" | head -c 600; echo
curl -s "http://127.0.0.1:P/source?format=json" | head -c 600; echo
curl -s "http://127.0.0.1:P/status" | head -c 300; echo
```

Record each status code and the first bytes of the body. If `/source` returns XML with `<hierarchy` and `bounds=` attributes, the runner proxies UIAutomator2 under keep-alive. If it 404s or no session file appears, it does not.

- [ ] **Step 4: Probe UIAutomator2 directly as the fallback**

```bash
adb -s emulator-5554 forward tcp:6790 tcp:6790
curl -s http://127.0.0.1:6790/wd/hub/status | head -c 300; echo
```

Record whether the server answers while the runner holds the session. Then Ctrl-C the runner and confirm `/tmp/grantiva-sessions` is empty and `adb forward --list` shows nothing for the device.

- [ ] **Step 5: Write the result**

```markdown
# Android keep-alive spike result, 2026-10-07

Runner: 1.1.18-grantiva.7 binary with the android drivers stamp. Emulator: Pixel_8_API_35, serial emulator-5554.

Session file appeared: yes/no. Port: <P>.
GET /source: <status>, body starts `<...>`.
GET /source?format=json: <status>.
GET /status: <status>.
UIAutomator2 direct on 6790 while session held: <status>.
After Ctrl-C: sessions dir empty yes/no; forwards cleared yes/no.

Decision for Plan 3: <"runner proxies UIA2; hierarchy and DriverClient use the session port" or
"runner does not proxy UIA2; Android DriverClient forwards 6790 itself and hierarchy reads /wd/hub/session/<id>/source">.
```

Fill in every field from what you observed. No field may be left as the placeholder.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/plans/2026-10-07-android-spike-result.md
git commit -m "Record Android keep-alive spike result"
```

---

### Task 4: Platform enum and resolution

**Files:**
- Create: `Sources/GrantivaCore/Platform/Platform.swift`
- Create: `Sources/GrantivaCore/Platform/PlatformResolver.swift`
- Test: `Tests/GrantivaCoreTests/PlatformResolverTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum Platform: String, Sendable, Codable, CaseIterable { case ios, android }
  extension Platform { public var configFileName: String }  // "grantiva.yml" / "grantiva-android.yml"
  public struct PlatformResolver: Sendable {
      public init(directory: URL, environment: [String: String], fileManager: FileManager = .default)
      public func resolve(flag: Platform?) throws -> Platform
      public func existingConfigFiles() -> [Platform]
      public func detectFromDirectory() -> [Platform]
  }
  ```
  Task 5 and Task 8 call `resolve(flag:)`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class PlatformResolverTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func touch(_ name: String, directory: Bool = false) throws {
        let url = dir.appendingPathComponent(name)
        if directory {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try "".write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func resolver(env: [String: String] = [:]) -> PlatformResolver {
        PlatformResolver(directory: dir, environment: env)
    }

    func testFlagWinsOverEverything() throws {
        try touch("grantiva.yml")
        try touch("settings.gradle")
        XCTAssertEqual(try resolver(env: ["GRANTIVA_PLATFORM": "android"]).resolve(flag: .ios), .ios)
    }

    func testEnvironmentWinsOverFiles() throws {
        try touch("grantiva.yml")
        XCTAssertEqual(try resolver(env: ["GRANTIVA_PLATFORM": "android"]).resolve(flag: nil), .android)
    }

    func testInvalidEnvironmentValueIsAnError() throws {
        XCTAssertThrowsError(try resolver(env: ["GRANTIVA_PLATFORM": "windows"]).resolve(flag: nil)) { error in
            XCTAssertTrue("\(error)".contains("GRANTIVA_PLATFORM"))
        }
    }

    func testSingleConfigFilePicksItsPlatform() throws {
        try touch("grantiva-android.yml")
        XCTAssertEqual(try resolver().resolve(flag: nil), .android)
        try touch("grantiva.yml")
        try FileManager.default.removeItem(at: dir.appendingPathComponent("grantiva-android.yml"))
        XCTAssertEqual(try resolver().resolve(flag: nil), .ios)
    }

    func testBothConfigFilesRequireTheFlag() throws {
        try touch("grantiva.yml")
        try touch("grantiva-android.yml")
        XCTAssertThrowsError(try resolver().resolve(flag: nil)) { error in
            XCTAssertTrue("\(error)".contains("--platform"))
        }
    }

    func testFlagForMissingConfigFileNamesTheFile() throws {
        try touch("grantiva.yml")
        XCTAssertThrowsError(try resolver().resolve(flag: .android)) { error in
            XCTAssertTrue("\(error)".contains("grantiva-android.yml"), "\(error)")
        }
    }

    func testFlagWithoutAnyConfigFallsThroughToDetection() throws {
        try touch("settings.gradle.kts")
        XCTAssertEqual(try resolver().resolve(flag: .android), .android)
    }

    func testDirectoryDetectionIOS() throws {
        try touch("Demo.xcodeproj", directory: true)
        XCTAssertEqual(try resolver().resolve(flag: nil), .ios)
    }

    func testDirectoryDetectionAndroid() throws {
        try touch("settings.gradle.kts")
        XCTAssertEqual(try resolver().resolve(flag: nil), .android)
    }

    func testBothProjectKindsRequireTheFlag() throws {
        try touch("Demo.xcworkspace", directory: true)
        try touch("settings.gradle")
        XCTAssertThrowsError(try resolver().resolve(flag: nil)) { error in
            XCTAssertTrue("\(error)".contains("--platform"))
        }
    }

    func testMaestroDirectoryCountsAsConfigButNotAsPlatform() throws {
        try touch(".maestro", directory: true)
        try touch("settings.gradle")
        XCTAssertEqual(try resolver().resolve(flag: nil), .android)
    }

    func testNothingFoundMentionsBothPlatforms() throws {
        XCTAssertThrowsError(try resolver().resolve(flag: nil)) { error in
            let text = "\(error)"
            XCTAssertTrue(text.contains("grantiva.yml") && text.contains("grantiva-android.yml"), text)
        }
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `swift test --filter PlatformResolverTests`
Expected: compile failure, `PlatformResolver` not found.

- [ ] **Step 3: Implement**

`Sources/GrantivaCore/Platform/Platform.swift`:

```swift
import Foundation

public enum Platform: String, Sendable, Codable, CaseIterable {
    case ios
    case android

    public var configFileName: String {
        switch self {
        case .ios: return "grantiva.yml"
        case .android: return "grantiva-android.yml"
        }
    }

    public var displayName: String {
        switch self {
        case .ios: return "iOS"
        case .android: return "Android"
        }
    }
}
```

`Sources/GrantivaCore/Platform/PlatformResolver.swift`:

```swift
import Foundation

/// Decides which platform a command is operating on. Order: `--platform`,
/// `GRANTIVA_PLATFORM`, whichever config file exists, then the project files
/// in the directory. See the spec, section 1, "Resolution order".
public struct PlatformResolver: Sendable {
    public static let environmentKey = "GRANTIVA_PLATFORM"

    private let directory: URL
    private let environment: [String: String]
    private let fileManager: FileManager

    public init(
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.environment = environment
        self.fileManager = fileManager
    }

    public func resolve(flag: Platform?) throws -> Platform {
        let configs = existingConfigFiles()

        if let flag {
            // An explicit platform whose config file is missing, while the
            // other platform's file is present, is almost always a typo.
            if !configs.isEmpty, !configs.contains(flag) {
                throw GrantivaError.invalidArgument(
                    "--platform \(flag.rawValue) was given but \(flag.configFileName) does not exist here. "
                        + "Found \(configs.map(\.configFileName).joined(separator: ", ")). "
                        + "Create \(flag.configFileName) with `grantiva init --platform \(flag.rawValue)`."
                )
            }
            return flag
        }

        if let raw = environment[Self.environmentKey], !raw.isEmpty {
            guard let platform = Platform(rawValue: raw.lowercased()) else {
                throw GrantivaError.invalidArgument(
                    "\(Self.environmentKey) is \"\(raw)\"; expected ios or android."
                )
            }
            return platform
        }

        switch configs.count {
        case 1:
            return configs[0]
        case 2:
            throw GrantivaError.invalidArgument(
                "Both grantiva.yml and grantiva-android.yml exist. Pass --platform ios|android or set \(Self.environmentKey)."
            )
        default:
            break
        }

        let detected = detectFromDirectory()
        switch detected.count {
        case 1:
            return detected[0]
        case 2:
            throw GrantivaError.invalidArgument(
                "Found both an Xcode project and Gradle settings. Pass --platform ios|android or set \(Self.environmentKey)."
            )
        default:
            throw GrantivaError.invalidArgument(
                "No project found. Expected grantiva.yml or an .xcodeproj/.xcworkspace for iOS, "
                    + "or grantiva-android.yml or settings.gradle(.kts) for Android."
            )
        }
    }

    /// Platforms whose config file exists, in `Platform.allCases` order.
    public func existingConfigFiles() -> [Platform] {
        Platform.allCases.filter {
            fileManager.fileExists(atPath: directory.appendingPathComponent($0.configFileName).path)
        }
    }

    /// Platforms implied by project files in the directory, in `Platform.allCases` order.
    public func detectFromDirectory() -> [Platform] {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }
        let visible = entries.filter { !$0.hasPrefix(".") }
        var found: [Platform] = []
        if visible.contains(where: { $0.hasSuffix(".xcworkspace") || $0.hasSuffix(".xcodeproj") }) {
            found.append(.ios)
        }
        if visible.contains("settings.gradle") || visible.contains("settings.gradle.kts") {
            found.append(.android)
        }
        return found
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `swift test --filter PlatformResolverTests`
Expected: all 12 PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/GrantivaCore/Platform Tests/GrantivaCoreTests/PlatformResolverTests.swift
git commit -m "Add Platform and PlatformResolver"
```

---

### Task 5: Config gains a project enum and loud parsing

**Files:**
- Modify: `Sources/GrantivaCore/Config/GrantivaConfig.swift`
- Create: `Sources/GrantivaCore/Config/AndroidProject.swift`
- Modify: `Sources/GrantivaCore/Config/ProjectDetector.swift:116-158` (cache decode tolerance only)
- Test: `Tests/GrantivaCoreTests/GrantivaConfigPlatformTests.swift`
- Test: `Tests/GrantivaCoreTests/ProjectDetectorTests.swift`

**Interfaces:**
- Consumes: `Platform` from Task 4.
- Produces:
  ```swift
  public struct AndroidProject: Sendable, Codable, Equatable {
      public var module: String          // default "app"
      public var variant: String         // default "debug"
      public var applicationId: String?
      public var emulator: String?
      public var systemImage: String?
      public var buildArgs: [String]
  }
  extension GrantivaConfig {
      public var platform: Platform              // stored
      public var android: AndroidProject?        // non-nil iff platform == .android
      public static func load(platform: Platform, from directory: URL = cwd) throws -> GrantivaConfig
      public static func loadIfPresent(platform: Platform, from directory: URL = cwd) throws -> GrantivaConfig?
  }
  ```
  The existing iOS stored properties (`scheme`, `workspace`, `project`, `simulator`, `bundleId`, `buildSettings`) stay as they are so no caller changes in this task. The existing `load(from:)` keeps working and means `load(platform: .ios, from:)`.

- [ ] **Step 1: Write the failing tests**

`Tests/GrantivaCoreTests/GrantivaConfigPlatformTests.swift`:

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class GrantivaConfigPlatformTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String, _ contents: String) throws {
        try contents.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func testAndroidFileDecodesAndroidKeysWithDefaults() throws {
        try write("grantiva-android.yml", """
            application_id: com.example.demo
            emulator: Pixel_8_API_35
            screens:
              - name: Home
                path: launch
            """)
        let config = try GrantivaConfig.load(platform: .android, from: dir)
        XCTAssertEqual(config.platform, .android)
        let android = try XCTUnwrap(config.android)
        XCTAssertEqual(android.module, "app")
        XCTAssertEqual(android.variant, "debug")
        XCTAssertEqual(android.applicationId, "com.example.demo")
        XCTAssertEqual(android.emulator, "Pixel_8_API_35")
        XCTAssertEqual(android.buildArgs, [])
        XCTAssertEqual(config.screens.count, 1)
        XCTAssertNil(config.scheme)
    }

    func testAndroidFileHonoursExplicitKeys() throws {
        try write("grantiva-android.yml", """
            platform: android
            module: mobile
            variant: freeDebug
            system_image: "system-images;android-35;google_apis;arm64-v8a"
            build_args: ["-PfastBuild=true"]
            """)
        let android = try XCTUnwrap(try GrantivaConfig.load(platform: .android, from: dir).android)
        XCTAssertEqual(android.module, "mobile")
        XCTAssertEqual(android.variant, "freeDebug")
        XCTAssertEqual(android.systemImage, "system-images;android-35;google_apis;arm64-v8a")
        XCTAssertEqual(android.buildArgs, ["-PfastBuild=true"])
    }

    func testAndroidFileWithIOSPlatformKeyIsRejected() throws {
        try write("grantiva-android.yml", "platform: ios\n")
        XCTAssertThrowsError(try GrantivaConfig.load(platform: .android, from: dir)) { error in
            XCTAssertTrue("\(error)".contains("platform: ios"), "\(error)")
        }
    }

    func testIOSFileStillLoadsThroughTheOldEntryPoint() throws {
        try write("grantiva.yml", "scheme: Demo\nsimulator: iPhone 16\n")
        let config = try GrantivaConfig.load(from: dir)
        XCTAssertEqual(config.platform, .ios)
        XCTAssertEqual(config.scheme, "Demo")
        XCTAssertNil(config.android)
    }

    func testMalformedYAMLIsReportedWithTheParserMessage() throws {
        try write("grantiva.yml", "scheme: Demo\nscreens:\n  - name: Home\n   path: launch\n")
        XCTAssertThrowsError(try GrantivaConfig.load(platform: .ios, from: dir)) { error in
            let text = "\(error)"
            XCTAssertTrue(text.contains("grantiva.yml"), text)
            XCTAssertTrue(text.contains("line") || text.contains("Line"), text)
        }
    }

    func testLoadIfPresentReturnsNilOnlyWhenNoFileExists() throws {
        XCTAssertNil(try GrantivaConfig.loadIfPresent(platform: .android, from: dir))
        try write("grantiva-android.yml", "module: [unclosed\n")
        XCTAssertThrowsError(try GrantivaConfig.loadIfPresent(platform: .android, from: dir))
    }

    func testAndroidLoadDoesNotFallBackToMaestroDirectory() throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(".maestro"), withIntermediateDirectories: true)
        XCTAssertNil(try GrantivaConfig.loadIfPresent(platform: .android, from: dir))
    }
}
```

Add to `Tests/GrantivaCoreTests/ProjectDetectorTests.swift`:

```swift
func testPreChangeCacheFileStillLoads() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir.appendingPathComponent(".grantiva"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let legacy = """
        {"scheme":"Demo","project":"Demo.xcodeproj","bundleId":"com.demo","detectedAt":700000000}
        """
    let cacheURL = dir.appendingPathComponent(".grantiva/config.json")
    try legacy.write(to: cacheURL, atomically: true, encoding: .utf8)
    let cached = ProjectDetector.loadCache(cacheURL: cacheURL, projectDirectory: dir)
    XCTAssertEqual(cached?.scheme, "Demo")
    XCTAssertEqual(cached?.bundleId, "com.demo")
}
```

`saveCache` uses a plain `JSONEncoder()`, whose default date strategy is seconds since 2001 as a number, so the numeric `detectedAt` fixture matches what real caches contain.

- [ ] **Step 2: Run them to verify they fail**

Run: `swift test --filter 'GrantivaConfigPlatformTests|ProjectDetectorTests/testPreChangeCacheFileStillLoads'`
Expected: compile failure on `platform`, `android`, `load(platform:)`.

- [ ] **Step 3: Add AndroidProject**

`Sources/GrantivaCore/Config/AndroidProject.swift`:

```swift
import Foundation

/// The Gradle-side half of `grantiva-android.yml`. Mirrors the Xcode fields
/// that live directly on `GrantivaConfig` for iOS.
public struct AndroidProject: Sendable, Codable, Equatable {
    public var module: String
    public var variant: String
    public var applicationId: String?
    public var emulator: String?
    public var systemImage: String?
    public var buildArgs: [String]

    public init(
        module: String = "app",
        variant: String = "debug",
        applicationId: String? = nil,
        emulator: String? = nil,
        systemImage: String? = nil,
        buildArgs: [String] = []
    ) {
        self.module = module
        self.variant = variant
        self.applicationId = applicationId
        self.emulator = emulator
        self.systemImage = systemImage
        self.buildArgs = buildArgs
    }

    enum CodingKeys: String, CodingKey {
        case module, variant, emulator
        case applicationId = "application_id"
        case systemImage = "system_image"
        case buildArgs = "build_args"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        module = try c.decodeIfPresent(String.self, forKey: .module) ?? "app"
        variant = try c.decodeIfPresent(String.self, forKey: .variant) ?? "debug"
        applicationId = try c.decodeIfPresent(String.self, forKey: .applicationId)
        emulator = try c.decodeIfPresent(String.self, forKey: .emulator)
        systemImage = try c.decodeIfPresent(String.self, forKey: .systemImage)
        buildArgs = try c.decodeIfPresent([String].self, forKey: .buildArgs) ?? []
    }
}
```

- [ ] **Step 4: Extend GrantivaConfig**

In `Sources/GrantivaCore/Config/GrantivaConfig.swift`:

Add two stored properties after `a11y`:

```swift
    /// Which platform this file describes. `.ios` for grantiva.yml and
    /// Maestro-format input; `.android` for grantiva-android.yml.
    public var platform: Platform = .ios
    /// Gradle-side settings. Present only when `platform == .android`.
    public var android: AndroidProject?
```

Add `case platform` to `CodingKeys`. The Android keys are decoded by `AndroidProject` from the same container, so they are not listed here.

Extend the memberwise `init` with trailing parameters `platform: Platform = .ios, android: AndroidProject? = nil` and assign them.

In `init(from decoder:)`, after the existing decodes:

```swift
        platform = try container.decodeIfPresent(Platform.self, forKey: .platform) ?? .ios
        android = nil
```

Add a second decoding entry point and the platform-aware loaders. Replace the existing `load(from:)` with:

```swift
    public static func load(
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> GrantivaConfig {
        try load(platform: .ios, from: directory)
    }

    /// Loads the config file for `platform`, or throws `configNotFound`.
    /// A file that exists but does not parse is an error carrying the file
    /// name and the YAML diagnostic; it never falls through.
    public static func load(
        platform: Platform,
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> GrantivaConfig {
        guard let config = try loadIfPresent(platform: platform, from: directory) else {
            throw GrantivaError.configNotFound
        }
        return config
    }

    /// Like `load(platform:from:)` but returns nil when no file exists.
    public static func loadIfPresent(
        platform: Platform,
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> GrantivaConfig? {
        let fm = FileManager.default
        let configURL = directory.appendingPathComponent(platform.configFileName)

        if fm.fileExists(atPath: configURL.path) {
            let contents = try String(contentsOf: configURL, encoding: .utf8)
            return try parse(contents, platform: platform, fileName: platform.configFileName)
        }

        // The .maestro/ fallback is an iOS-era convention; Android has none.
        guard platform == .ios else { return nil }
        let maestroDir = directory.appendingPathComponent(".maestro")
        if fm.fileExists(atPath: maestroDir.path) {
            return try MaestroFlowParser.loadDirectory(maestroDir)
        }
        return nil
    }

    static func parse(_ contents: String, platform: Platform, fileName: String) throws -> GrantivaConfig {
        if platform == .ios, MaestroFlowParser.isMaestroFormat(contents) {
            return try MaestroFlowParser.parse(contents)
        }
        var config: GrantivaConfig
        do {
            config = try YAMLDecoder().decode(GrantivaConfig.self, from: contents)
        } catch {
            throw GrantivaError.invalidArgument("\(fileName) could not be parsed: \(error)")
        }
        if let declared = (try? YAMLDecoder().decode(DeclaredPlatform.self, from: contents))?.platform,
           declared != platform {
            throw GrantivaError.invalidArgument(
                "\(fileName) declares `platform: \(declared.rawValue)` but it is the \(platform.displayName) config file."
            )
        }
        config.platform = platform
        if platform == .android {
            do {
                config.android = try YAMLDecoder().decode(AndroidProject.self, from: contents)
            } catch {
                throw GrantivaError.invalidArgument("\(fileName) could not be parsed: \(error)")
            }
        }
        return config
    }

    private struct DeclaredPlatform: Decodable {
        var platform: Platform?
    }
```

Yams' decoding error description includes the line and column of a syntax error. Confirm with the malformed-YAML test; if the message lacks the word "line", wrap it: catch `YamlError` specifically and render `"\(fileName): \(error)"` using its `description`, which does include the position.

- [ ] **Step 5: Make the detection cache tolerant**

No code change is expected: `DetectedProject` has not changed shape, so the legacy cache test passes as written. It exists to pin that this plan never adds a required field to the cached type.

- [ ] **Step 6: Run the tests**

Run: `swift test`
Expected: all PASS, including the seven new config tests and the cache test. Any existing test that constructs `GrantivaConfig` memberwise keeps compiling because the new parameters have defaults.

- [ ] **Step 7: Commit**

```bash
git add Sources/GrantivaCore/Config Tests/GrantivaCoreTests/GrantivaConfigPlatformTests.swift Tests/GrantivaCoreTests/ProjectDetectorTests.swift
git commit -m "Add platform-aware config loading and AndroidProject"
```

---

### Task 6: DeviceID validation accepts adb serials

**Files:**
- Modify: `Sources/GrantivaCore/Simulator/SimulatorUDID.swift`
- Test: `Tests/GrantivaCoreTests/SimulatorUDIDTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum DeviceID {
      public static func isSimulatorUDID(_ value: String) -> Bool
      public static func isADBSerial(_ value: String) -> Bool
      public static func validate(_ value: String, flag: String = "--udid") throws -> String   // either form
  }
  ```
  `SimulatorUDID.validate` is unchanged and remains simulator-only; the simulator subcommand keeps calling it. HierarchyCommand, MCPServer, and DriverCommand switch to `DeviceID.validate` in Plan 3, when they gain Android behavior. This task only adds the type.

- [ ] **Step 1: Write the failing tests**

Add to `Tests/GrantivaCoreTests/SimulatorUDIDTests.swift`:

```swift
func testDeviceIDAcceptsSimulatorUDIDs() throws {
    XCTAssertEqual(try DeviceID.validate("921A0945-7157-4533-BA1F-21E8132D3E40"), "921A0945-7157-4533-BA1F-21E8132D3E40")
}

func testDeviceIDAcceptsEmulatorSerials() throws {
    XCTAssertEqual(try DeviceID.validate(" emulator-5554 "), "emulator-5554")
    XCTAssertTrue(DeviceID.isADBSerial("emulator-5584"))
}

func testDeviceIDAcceptsHardwareAndTCPSerials() throws {
    XCTAssertEqual(try DeviceID.validate("R5CT30ABCDE"), "R5CT30ABCDE")
    XCTAssertEqual(try DeviceID.validate("192.168.1.20:5555"), "192.168.1.20:5555")
}

func testDeviceIDRejectsBlankAndShellNoise() {
    XCTAssertThrowsError(try DeviceID.validate(""))
    XCTAssertThrowsError(try DeviceID.validate("   "))
    XCTAssertThrowsError(try DeviceID.validate("emulator 5554"))
    XCTAssertThrowsError(try DeviceID.validate("$UDID"))
}

func testSimulatorUDIDStillRejectsSerials() {
    XCTAssertThrowsError(try SimulatorUDID.validate("emulator-5554")) { error in
        XCTAssertTrue("\(error)".contains("not a simulator UDID"))
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `swift test --filter SimulatorUDIDTests`
Expected: compile failure, `DeviceID` not found.

- [ ] **Step 3: Implement**

Append to `Sources/GrantivaCore/Simulator/SimulatorUDID.swift`:

```swift
/// Shape validation for any device identifier Grantiva accepts: a simulator
/// UDID or an adb serial. Use this where a command can target either
/// platform; keep `SimulatorUDID.validate` where only a simulator makes sense.
public enum DeviceID {
    public static func isSimulatorUDID(_ value: String) -> Bool {
        SimulatorUDID.isWellFormed(value)
    }

    /// adb serials: `emulator-NNNN`, a hardware serial (letters, digits, `_`,
    /// `-`, `.`), or `host:port`. One token, no whitespace, no shell
    /// metacharacters.
    public static func isADBSerial(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 64 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-.:"))
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        guard value.first!.isLetter || value.first!.isNumber else { return false }
        return true
    }

    public static func validate(_ value: String, flag: String = "--udid") throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GrantivaError.invalidArgument(
                "\(flag) is empty. Pass a simulator UDID or an adb serial — if this came from a shell variable, it was unset."
            )
        }
        guard isSimulatorUDID(trimmed) || isADBSerial(trimmed) else {
            throw GrantivaError.invalidArgument(
                "\(flag) \(trimmed) is neither a simulator UDID (8-4-4-4-12 hex) nor an adb serial (for example emulator-5554)."
            )
        }
        return trimmed
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `swift test --filter SimulatorUDIDTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/GrantivaCore/Simulator/SimulatorUDID.swift Tests/GrantivaCoreTests/SimulatorUDIDTests.swift
git commit -m "Add DeviceID validation that accepts adb serials"
```

---

### Task 7: DevicePlatform protocol and the iOS implementation

**Files:**
- Create: `Sources/GrantivaCore/Platform/DevicePlatform.swift`
- Create: `Sources/GrantivaCore/Platform/IOSPlatform.swift`
- Modify: `Sources/GrantivaCore/Build/BuildResult.swift:5-6`
- Modify: `Sources/GrantivaCore/Runner/RunnerSession.swift:76-96` and `:355-378`
- Test: `Tests/GrantivaCoreTests/IOSPlatformTests.swift`

**Interfaces:**
- Consumes: `Platform` (Task 4), `SimulatorManager`, `XcodeBuildRunner`, `SimulatorDisplayGeometry`, `BuildResult`.
- Produces:
  ```swift
  public struct DeviceGeometry: Sendable, Equatable {
      public let pixelWidth: Int, pixelHeight: Int, scale: Double
      public var dimensions: SimulatorProvisionResult.Dimensions
  }
  public struct BootedDevice: Sendable, Equatable { public let udid: String; public let name: String }
  public struct PlatformBuildRequest: Sendable {
      public let config: GrantivaConfig; public let resolved: ResolvedProject
      public let deviceID: String; public let extraBuildSettings: [String]
  }
  public protocol DevicePlatform: Sendable {
      var platform: Platform { get }
      func bootDevice(named nameOrID: String) async throws -> BootedDevice
      func displayGeometry(deviceID: String) async throws -> DeviceGeometry
      func build(_ request: PlatformBuildRequest) async throws -> BuildResult
      func install(appID: String, productPath: String, deviceID: String) async throws
      func launch(appID: String, deviceID: String) async throws
      func terminate(appID: String, deviceID: String) async throws
      func uninstall(appID: String, deviceID: String) async throws
      func prepareForCapture(deviceID: String) async
      func restoreAfterCapture(deviceID: String) async
      func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String]
      func runnerTestArguments() -> [String]
  }
  public struct IOSPlatform: DevicePlatform {
      public init(simulators: SimulatorManager = .live, xcodebuild: XcodeBuildRunner = XcodeBuildRunner(), execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) })
  }
  public enum DevicePlatformFactory { public static func make(_ platform: Platform) -> any DevicePlatform }  // .ios -> IOSPlatform(); .android -> fatalError until Plan 2
  ```
  Task 8 wires the commands to this. `RunnerSession` gains `platform: any DevicePlatform` parameters.

- [ ] **Step 1: Write the failing tests**

`Tests/GrantivaCoreTests/IOSPlatformTests.swift`:

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class IOSPlatformTests: XCTestCase {
    func testRunnerGlobalArgumentsMatchTheHistoricalShape() {
        let platform = IOSPlatform()
        XCTAssertEqual(
            platform.runnerGlobalArguments(deviceID: "ABC-123", appFile: "/tmp/Demo.app"),
            ["--platform", "ios", "--device", "ABC-123", "--no-ansi", "--no-app-install", "--app-file", "/tmp/Demo.app"]
        )
        XCTAssertEqual(
            platform.runnerGlobalArguments(deviceID: "ABC-123", appFile: nil),
            ["--platform", "ios", "--device", "ABC-123", "--no-ansi", "--no-app-install"]
        )
    }

    func testRunnerTestArgumentsDisableIdleWaitOnIOS() {
        XCTAssertEqual(IOSPlatform().runnerTestArguments(), ["--wait-for-idle-timeout", "0"])
    }

    func testPrepareAndRestoreDriveSimctlStatusBar() async {
        let executor = ScriptedExecutor([.success(""), .success("")])
        let platform = IOSPlatform(execute: executor.execute)
        await platform.prepareForCapture(deviceID: "ABC")
        await platform.restoreAfterCapture(deviceID: "ABC")
        XCTAssertEqual(executor.commands.count, 2)
        XCTAssertTrue(executor.commands[0].hasPrefix("xcrun simctl status_bar ABC override --time 9:41"))
        XCTAssertEqual(executor.commands[1], "xcrun simctl status_bar ABC clear")
    }

    func testBuildUsesTheSimulatorDestination() async throws {
        let executor = ScriptedExecutor([
            .success(""),
            .success("BUILT_PRODUCTS_DIR = /tmp/P\nFULL_PRODUCT_NAME = Demo.app\n"),
        ])
        let platform = IOSPlatform(xcodebuild: XcodeBuildRunner(execute: executor.execute))
        let request = PlatformBuildRequest(
            config: GrantivaConfig(scheme: "Demo", project: "Demo.xcodeproj"),
            resolved: ResolvedProject(scheme: "Demo", project: "Demo.xcodeproj"),
            deviceID: "ABC",
            extraBuildSettings: []
        )
        let result = try await platform.build(request)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.destination, "platform=iOS Simulator,id=ABC")
        XCTAssertEqual(result.productPath, "/tmp/P/Demo.app")
        XCTAssertTrue(executor.commands[0].contains("'platform=iOS Simulator,id=ABC'"))
    }

    func testMakeReturnsIOS() {
        XCTAssertEqual(DevicePlatformFactory.make(.ios).platform, .ios)
    }
}

private final class ScriptedExecutor: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<String, Error>]
    private var recorded: [String] = []
    init(_ results: [Result<String, Error>]) { self.results = results }
    func execute(_ command: String) async throws -> String {
        try lock.withLock {
            recorded.append(command)
            return try results.removeFirst().get()
        }
    }
    var commands: [String] { lock.withLock { recorded } }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `swift test --filter IOSPlatformTests`
Expected: compile failure.

- [ ] **Step 3: Make BuildResult's scheme and destination optional**

In `Sources/GrantivaCore/Build/BuildResult.swift` change `public let scheme: String` and `public let destination: String` to `String?`, and the `init` parameters to `scheme: String? = nil, destination: String? = nil`. Build and fix the handful of call sites that read them: `TableFormatter.formatBuild` prints `scheme ?? "(none)"`; the MCP BuildTools JSON passes them through as optional. Run `swift build` until clean.

- [ ] **Step 4: Write the protocol**

`Sources/GrantivaCore/Platform/DevicePlatform.swift`:

```swift
import Foundation

public struct DeviceGeometry: Sendable, Equatable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let scale: Double

    public init(pixelWidth: Int, pixelHeight: Int, scale: Double) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
    }

    public var dimensions: SimulatorProvisionResult.Dimensions {
        .init(width: pixelWidth, height: pixelHeight)
    }
}

public struct BootedDevice: Sendable, Equatable {
    public let udid: String
    public let name: String

    public init(udid: String, name: String) {
        self.udid = udid
        self.name = name
    }
}

public struct PlatformBuildRequest: Sendable {
    public let config: GrantivaConfig
    public let resolved: ResolvedProject
    public let deviceID: String
    public let extraBuildSettings: [String]

    public init(config: GrantivaConfig, resolved: ResolvedProject, deviceID: String, extraBuildSettings: [String]) {
        self.config = config
        self.resolved = resolved
        self.deviceID = deviceID
        self.extraBuildSettings = extraBuildSettings
    }
}

/// Everything a command needs from a device that differs between iOS and
/// Android. Commands hold one of these and never call simctl, xcodebuild,
/// adb, or gradle themselves.
public protocol DevicePlatform: Sendable {
    var platform: Platform { get }

    func bootDevice(named nameOrID: String) async throws -> BootedDevice
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry

    func build(_ request: PlatformBuildRequest) async throws -> BuildResult
    func install(appID: String, productPath: String, deviceID: String) async throws
    func launch(appID: String, deviceID: String) async throws
    func terminate(appID: String, deviceID: String) async throws
    func uninstall(appID: String, deviceID: String) async throws

    /// Put the device in a deterministic state for screenshots. Never throws:
    /// a failure here degrades a capture, it does not abort a run.
    func prepareForCapture(deviceID: String) async
    func restoreAfterCapture(deviceID: String) async

    /// Arguments that go before the runner's `test` subcommand.
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String]
    /// Platform-specific arguments that go after `test`.
    func runnerTestArguments() -> [String]
}

public enum DevicePlatformFactory {
    public static func make(_ platform: Platform) -> any DevicePlatform {
        switch platform {
        case .ios:
            return IOSPlatform()
        case .android:
            // Plan 2 replaces this with AndroidPlatform().
            fatalError("Android support is not available in this build")
        }
    }
}
```

- [ ] **Step 5: Write the iOS implementation as a pure extraction**

`Sources/GrantivaCore/Platform/IOSPlatform.swift`:

```swift
import Foundation

public struct IOSPlatform: DevicePlatform {
    public let platform: Platform = .ios
    private let simulators: SimulatorManager
    private let xcodebuild: XcodeBuildRunner
    private let execute: @Sendable (String) async throws -> String

    public init(
        simulators: SimulatorManager = .live,
        xcodebuild: XcodeBuildRunner = XcodeBuildRunner(),
        execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) }
    ) {
        self.simulators = simulators
        self.xcodebuild = xcodebuild
        self.execute = execute
    }

    public static func destination(for udid: String) -> String {
        "platform=iOS Simulator,id=\(udid)"
    }

    public func bootDevice(named nameOrID: String) async throws -> BootedDevice {
        let device = try await simulators.boot(nameOrUDID: nameOrID)
        return BootedDevice(udid: device.udid, name: device.name)
    }

    public func displayGeometry(deviceID: String) async throws -> DeviceGeometry {
        let geometry = try await simulators.displayGeometry(udid: deviceID)
        return DeviceGeometry(pixelWidth: geometry.pixels[0], pixelHeight: geometry.pixels[1], scale: geometry.scale)
    }

    public func build(_ request: PlatformBuildRequest) async throws -> BuildResult {
        guard let scheme = request.resolved.scheme else {
            throw GrantivaError.invalidArgument(
                "No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary."
            )
        }
        return try await xcodebuild.build(
            scheme: scheme,
            workspace: request.resolved.workspace,
            project: request.resolved.project,
            destination: Self.destination(for: request.deviceID),
            buildSettings: request.extraBuildSettings
        )
    }

    public func install(appID: String, productPath: String, deviceID: String) async throws {
        try await xcodebuild.install(bundleId: appID, productPath: productPath, udid: deviceID)
    }

    public func launch(appID: String, deviceID: String) async throws {
        try await xcodebuild.launch(bundleId: appID, udid: deviceID)
    }

    public func terminate(appID: String, deviceID: String) async throws {
        try await xcodebuild.terminate(bundleId: appID, udid: deviceID)
    }

    public func uninstall(appID: String, deviceID: String) async throws {
        try await xcodebuild.uninstall(bundleId: appID, udid: deviceID)
    }

    public func prepareForCapture(deviceID: String) async {
        _ = try? await execute(
            "xcrun simctl status_bar \(deviceID) override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4"
        )
    }

    public func restoreAfterCapture(deviceID: String) async {
        _ = try? await execute("xcrun simctl status_bar \(deviceID) clear")
    }

    public func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] {
        var args = ["--platform", "ios", "--device", deviceID, "--no-ansi", "--no-app-install"]
        if let appFile {
            args += ["--app-file", appFile]
        }
        return args
    }

    public func runnerTestArguments() -> [String] {
        ["--wait-for-idle-timeout", "0"]
    }
}
```

The status bar command strings must be copied byte for byte from `RunnerSession.swift:71` and `:352` (the override) and `:466` (the clear). Open those lines and compare before moving on.

- [ ] **Step 6: Route RunnerSession through the platform**

In `Sources/GrantivaCore/Runner/RunnerSession.swift`, both `run(...)` (around line 60) and `runFlowFiles(...)` (around line 340) take a new parameter `platform: any DevicePlatform = IOSPlatform()` placed right after `udid`. Replace the inline status bar override with `await platform.prepareForCapture(deviceID: udid)`, the clear with `await platform.restoreAfterCapture(deviceID: udid)`, and the argument construction with:

```swift
        var args = [runnerBin] + platform.runnerGlobalArguments(deviceID: udid, appFile: appFile)
        args += ["test", "--output", reportDir, "--flatten"]
        args += platform.runnerTestArguments()
        args += ["--artifacts", runnerArtifactMode(for: snapshot)]
```

Keep `--keep-alive` and the flow path appends as they are. Do this in both functions; the order of `--output`, `--flatten`, `--wait-for-idle-timeout 0`, `--artifacts` must come out identical to today's, which the existing `RunnerSessionAppIdTests` and `RunnerExecutionTests` exercise via `/bin/sh` stand-ins. If any of those tests assert on the exact argument order, they are the regression check; if they do not, add one assertion to `RunnerSessionAppIdTests` capturing the full `args` array for the iOS case.

- [ ] **Step 7: Run everything**

Run: `swift test`
Expected: all PASS, including the five new IOSPlatform tests.

- [ ] **Step 8: Commit**

```bash
git add Sources/GrantivaCore/Platform Sources/GrantivaCore/Build/BuildResult.swift Sources/GrantivaCore/Runner/RunnerSession.swift Tests/GrantivaCoreTests/IOSPlatformTests.swift
git commit -m "Add DevicePlatform protocol with the iOS implementation"
```

---

### Task 8: Commands resolve a platform and use DevicePlatform

**Files:**
- Modify: `Sources/GrantivaCLI/GlobalOptions.swift` (the file holding `GlobalOptions` and `BuildOptions`)
- Modify: `Sources/GrantivaCLI/RunCommand.swift:62-63,108-245`
- Modify: `Sources/GrantivaCLI/CICommand.swift:198-199,211-340`
- Modify: `Sources/GrantivaCLI/DiffCommand.swift:50-90,210-250`
- Modify: `Sources/GrantivaCLI/BuildCommand.swift:34-60,101-125`
- Modify: `Sources/GrantivaCLI/InitCommand.swift`
- Modify: `Sources/GrantivaMCP/MCPServer.swift:22`
- Test: `Tests/GrantivaCLITests/PlatformOptionTests.swift`

**Interfaces:**
- Consumes: `PlatformResolver`, `GrantivaConfig.loadIfPresent(platform:)`, `DevicePlatformFactory.make`, `IOSPlatform`.
- Produces: a shared `PlatformOptions` option group:
  ```swift
  struct PlatformOptions: ParsableArguments {
      @Option(name: .long, help: "...") var platform: Platform?
      func resolve() throws -> Platform
      func loadConfig() throws -> (Platform, GrantivaConfig?)   // loud on malformed
  }
  ```
  Every device-touching command adds `@OptionGroup var platformOptions: PlatformOptions`.

- [ ] **Step 1: Write the failing tests**

`Tests/GrantivaCLITests/PlatformOptionTests.swift`:

```swift
import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class PlatformOptionTests: XCTestCase {
    func testPlatformFlagParsesBothValues() throws {
        XCTAssertEqual(try PlatformOptions.parse(["--platform", "ios"]).platform, .ios)
        XCTAssertEqual(try PlatformOptions.parse(["--platform", "android"]).platform, .android)
        XCTAssertThrowsError(try PlatformOptions.parse(["--platform", "web"]))
    }

    func testLoadConfigIsLoudOnMalformedFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "scheme: [oops\n".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        let options = try PlatformOptions.parse([])
        XCTAssertThrowsError(try options.loadConfig(directory: dir, environment: [:])) { error in
            XCTAssertTrue("\(error)".contains("grantiva.yml"), "\(error)")
        }
    }

    func testLoadConfigWithNoFilesInAnXcodeDirectoryIsIOSWithNilConfig() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Demo.xcodeproj"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (platform, config) = try PlatformOptions.parse([]).loadConfig(directory: dir, environment: [:])
        XCTAssertEqual(platform, .ios)
        XCTAssertNil(config)
    }
}
```

`Platform` needs `ExpressibleByArgument`; add `extension Platform: ExpressibleByArgument {}` in the CLI target.

- [ ] **Step 2: Run them to verify they fail**

Run: `swift test --filter PlatformOptionTests`
Expected: compile failure.

- [ ] **Step 3: Add PlatformOptions**

In the file that defines `BuildOptions`, add:

```swift
extension Platform: ExpressibleByArgument {}

struct PlatformOptions: ParsableArguments {
    @Option(name: .long, help: "Target platform: ios or android. Defaults to whichever of grantiva.yml / grantiva-android.yml exists, else the project files in this directory. GRANTIVA_PLATFORM also sets it.")
    var platform: Platform?

    func resolve(
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> Platform {
        try PlatformResolver(directory: directory, environment: environment).resolve(flag: platform)
    }

    /// Resolves the platform and loads its config file. A missing file yields
    /// nil config; a malformed one throws.
    func loadConfig(
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> (Platform, GrantivaConfig?) {
        let resolved = try resolve(directory: directory, environment: environment)
        let config = try GrantivaConfig.loadIfPresent(platform: resolved, from: directory)
        return (resolved, config)
    }
}
```

- [ ] **Step 4: Wire RunCommand**

In `RunCommand`:

- Add `@OptionGroup var platformOptions: PlatformOptions` after `buildOptions`.
- Replace `var simulatorManager: SimulatorManager = .live` with `var devicePlatform: (any DevicePlatform)?` (nil means "make from the resolved platform"; tests inject a fake).
- Replace `let config = try? GrantivaConfig.load()` with:
  ```swift
  let (platform, config) = try platformOptions.loadConfig()
  let device: any DevicePlatform = devicePlatform ?? DevicePlatformFactory.make(platform)
  ```
- Replace the boot, destination, and geometry block with:
  ```swift
  log("Booting \(platform.displayName) device: \(resolved.simulator)")
  let booted = try await device.bootDevice(named: resolved.simulator)
  log("Device booted: \(booted.name) (\(booted.udid))")
  let geometry = try await device.displayGeometry(deviceID: booted.udid)
  let expectedPixels = geometry.dimensions
  ```
  and every later `device.udid` read becomes `booted.udid`.
- Replace the `XcodeBuildRunner().build(...)` call with:
  ```swift
  let buildResult = try await device.build(PlatformBuildRequest(
      config: config ?? GrantivaConfig(),
      resolved: resolved,
      deviceID: booted.udid,
      extraBuildSettings: buildOptions.xcodeBuildSettings(merging: resolved.buildSettings)
  ))
  ```
  The `guard let buildScheme` block before it is removed; `IOSPlatform.build` throws the same message.
- Replace `XcodeBuildRunner().install(bundleId: bid, productPath: productPath, udid: device.udid)` with `device.install(appID: bid, productPath: productPath, deviceID: booted.udid)`.
- Pass `platform: device` into every `RunnerSession.run(...)` and `RunnerSession.runFlowFiles(...)` call in this file.
- The `LogStreamer` block stays iOS-only for now; wrap it in `if platform == .ios` so an Android run in Plan 2 does not call `simctl spawn`. Plan 2 moves it behind the protocol.

- [ ] **Step 5: Wire CICommand, DiffCommand, BuildCommand the same way**

Apply the identical substitutions in `CICommand.swift` (lines 198-340), both subcommands in `DiffCommand.swift` (lines 50-90 and 210-250), and both subcommands in `BuildCommand.swift` (lines 34-60 and 101-125). The four patterns are always: option group added, `simulatorManager` field becomes `devicePlatform`, `try? GrantivaConfig.load()` becomes `try platformOptions.loadConfig()`, `platform=iOS Simulator,id=` and `XcodeBuildRunner()` calls go through `device`. `CICommand`'s `simctl launch` pre-launch becomes `device.launch(appID:deviceID:)`. Grep afterwards:

Run: `grep -rn 'platform=iOS Simulator\|XcodeBuildRunner()\|simulatorManager' Sources/GrantivaCLI/RunCommand.swift Sources/GrantivaCLI/CICommand.swift Sources/GrantivaCLI/DiffCommand.swift Sources/GrantivaCLI/BuildCommand.swift`
Expected: no output.

- [ ] **Step 6: Wire InitCommand and MCPServer minimally**

`InitCommand`: add `@OptionGroup var platformOptions: PlatformOptions`. Resolve with `PlatformResolver(...).detectFromDirectory()` when no flag is given; if it returns two platforms, throw the "pass --platform" error; if `.android` is chosen, throw `GrantivaError.invalidArgument("Android init arrives in the next release; create grantiva-android.yml by hand for now")`. The iOS path is unchanged. Plan 2 fills in the Android file writer.

`MCPServer.swift:22`: replace `let config = try? GrantivaConfig.load()` with `let config = try GrantivaConfig.loadIfPresent(platform: .ios)`, so a malformed `grantiva.yml` fails the server start loudly. Plan 3 adds platform resolution here.

- [ ] **Step 7: Run everything and an iOS smoke test**

Run: `swift test`
Expected: all PASS.

Then, against the iOS example app in `../grantiva-examples` (clone it next to this repo if missing):

```bash
cd ../grantiva-examples && swift run --package-path ../grantiva-cli grantiva run --flow flows/smoke.yaml 2>&1 | tail -5
```

Use whatever flow or screen the example's `grantiva.yml` defines if `flows/smoke.yaml` does not exist. Expected: the run completes exactly as before this plan; the resolved line now reads `Booting iOS device: iPhone 16`.

Also confirm `GRANTIVA_PLATFORM=android swift run grantiva run` in that directory fails with the "grantiva-android.yml does not exist" message rather than crashing.

- [ ] **Step 8: Commit**

```bash
git add Sources/GrantivaCLI Sources/GrantivaMCP/MCPServer.swift Tests/GrantivaCLITests/PlatformOptionTests.swift
git commit -m "Resolve a platform per command and route device work through DevicePlatform"
```

---

### Task 9: Changelog and hand-off notes

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add an Unreleased section**

At the top of `CHANGELOG.md`, above `## 2.0.1`:

```markdown
## Unreleased

### Added
- `--platform ios|android` on `run`, `ci run`, `build`, `diff capture`, `diff compare`, and `init`, plus the `GRANTIVA_PLATFORM` environment variable. Android is resolved and validated but not yet runnable; it lands in the next two releases.
- `grantiva-android.yml` is recognised as the Android config file. A config file that exists but does not parse is now an error naming the file and the YAML position, instead of being silently ignored.
- The embedded runner ships the UIAutomator2 driver APKs.

### Changed
- Device, build, and runner-argument handling moved behind a `DevicePlatform` abstraction. iOS behaviour is unchanged.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "Changelog for the platform foundation"
```

---

## Follow-on plans

- **Plan 2, Android run and VRT:** `AndroidPlatform` (adb, gradle, emulator boot, demo mode, geometry, logs, output-metadata.json), `--module`/`--variant`/`--application-id`/`--emulator`/`--device` flags, `init --platform android`, Android `doctor` checks, per-platform baseline and capture directories, the local-only remote error, `examples/android`.
- **Plan 3, Android parity:** `emulator` subcommand, hierarchy and `DriverClient` per the spike result, MCP platform resolution and the `grantiva_emulator_*` tools, `record` via `screenrecord`, `grantiva_test` via `connectedAndroidTest`, orphan cleanup, `runner start/stop/dump-hierarchy` through the platform.
