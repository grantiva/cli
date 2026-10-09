# Android Support, Plan 2 of 3: Run and VRT Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `grantiva init`, `doctor`, `build`, `build install`, `run`, `diff capture`, `diff compare`, and `diff approve` work end to end against an Android emulator, with local baselines, while every iOS path keeps its current behavior.

**Architecture:** An `AndroidPlatform` implements the `DevicePlatform` protocol from Plan 1, composed from small testable units: `AndroidSDK` (tool discovery), `ADB` (exact adb command lines), `AndroidCaptureSettings` (demo mode and animation scales with crash recovery), `GradleBuildRunner` plus `APKOutputMetadata` (build and APK selection), and `EmulatorManager` (device selection and AVD boot). The protocol grows the six operations the commands still call simctl for directly. On the CLI side a shared `TargetOptions` group carries the iOS and Android target flags, rejects a flag from the other platform, and produces a `ResolvedProject` for either. VRT reads and writes platform-specific capture and baseline directories; Android remote baselines are refused until the backend keys by platform.

**Tech Stack:** Swift 6.1 package, macOS 15+, ArgumentParser, Yams, XCTest. Android SDK (adb, emulator, apkanalyzer), Gradle wrapper, OpenJDK 21, Jetpack Compose for the example app.

**Spec:** `docs/superpowers/specs/2026-10-07-android-support-design.md`

**Previous plan:** `docs/superpowers/plans/2026-10-07-android-support-1-foundation.md` (merged as PR #159). Its spike result is `docs/superpowers/plans/2026-10-07-android-spike-result.md`.

## Global Constraints

- Package stays `platforms: [.macOS(.v15)]`; no Linux.
- Config file names are exactly `grantiva.yml` (iOS) and `grantiva-android.yml` (Android). Android keys: `module` (default `app`), `variant` (default `debug`), `application_id`, `emulator`, `system_image`, `build_args`.
- Android flags are exactly `--module`, `--variant`, `--application-id`, `--emulator <AVD>`, `--device <serial>`, `--allow-device-settings`, `--headless`, `--logs-tag <tag>`. An iOS-only flag (`--scheme`, `--simulator`, `--bundle-id`, `--derived-data-path`, `--logs-predicate`) given to an Android run is an error naming the flag, and the reverse likewise.
- Device identifiers stay in fields and JSON keys named `udid`; adb serials are stored there unchanged.
- Android runner argv: `--platform android --device <serial> --no-ansi --no-app-install [--app-file <apk>] test --output <dir> --flatten --artifacts <mode> [--fail-fast] [--keep-alive] <flows>`. `--driver` and `--auto-start-emulator` are never passed. `--wait-for-idle-timeout 0` stays iOS-only.
- The runner is launched with `MAESTRO_RUNNER_HOME=<runner dir>` for Android (spike finding); iOS adds no environment.
- Tool roots in order: `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `~/Library/Android/sdk`. JDK: `JAVA_HOME`, then `/usr/libexec/java_home`. Nothing is installed automatically.
- Emulator boot: `emulator -avd <name> -port <N> -no-snapshot-save -no-boot-anim`, plus `-no-window` when `--headless` or stdout is not a terminal; `N` is the first free even port in 5554...5584.
- Install: `adb -s <serial> install -r -t -d <apk>`, one retry after `pm uninstall` on `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Launch: `monkey -p <id> -c android.intent.category.LAUNCHER 1`. Terminate: `am force-stop`. Uninstall: `pm uninstall`.
- Capture state: demo mode clock `0941`, battery 100 unplugged, notifications hidden, wifi and signal full, the three animation scales `0`, rotation pinned to portrait; previous values saved in `.grantiva/android-settings-<serial>.json` and restored.
- Directories: iOS `.grantiva/captures` and `.grantiva/baselines` unchanged; Android `.grantiva/captures/android` and `.grantiva/baselines/android`.
- Message, verbatim: `Android baselines are local only until the Grantiva backend supports platforms; use local baselines`.
- Every existing test keeps passing after every task. `swift test` is the gate.
- No Claude attribution lines in commits.

## Rulings made while writing this plan (spec gaps and deviations)

1. **Local baselines on `diff compare` and `diff approve`.** The spec says Android `diff` with remote baselines fails. Those two commands pick remote implicitly whenever the user is logged in, which would block every logged-in developer from local Android VRT. Ruling: on Android they always use the local store and print one warning line (the verbatim message above) when credentials are present. `ci run` on Android fails with that message before any work, as the spec says.
2. **No post-run emulator shutdown.** iOS leaves the simulator booted after `run`; Android does the same. Emulators Grantiva boots are recorded in `~/.grantiva/android/started.json` so Plan 3's `emulator teardown` can kill only those.
3. **`cleanupOrphans` on iOS is a no-op.** The spec maps it to SimulatorReaper, which `simulator teardown` already owns. Changing iOS post-run behavior is out of scope.
4. **`record` flags move to Plan 3** with the rest of RecordCommand's Android work. `hierarchy`, `runner start/stop`, and the MCP server stay iOS-only until Plan 3.
5. **The runner tarball keeps the APKs** (amd64 50.7 MB). Moving them to a shared resource is Plan 3 housekeeping.
6. **Data container on Android** stays "not supported": there is no app data path readable without root.
7. **AVD listing uses `emulator -list-avds`**, which needs no JDK, instead of `avdmanager list avd`. `emulator ensure` (Plan 3) uses avdmanager to create.

## Review Focus

1. `--device emulator-5556` naming a device whose `adb devices` state is `offline` or `unauthorized` must fail naming the state, not hang in the runner. Pinned in Task 7.
2. `grantiva run --logs` on Android must never spawn `xcrun simctl`; it streams `logcat --uid`. Pinned in Task 8.
3. A `.grantiva/android-settings-<serial>.json` left by a crashed run is restored before the next capture changes anything. Pinned in Task 3.
4. An ABI-split build with no universal APK and no element matching the device ABI fails naming the ABIs present, instead of installing the wrong APK. Pinned in Task 4.
5. `grantiva diff approve` in an Android project never writes into `.grantiva/baselines/` itself, only `.grantiva/baselines/android/`. Pinned in Task 10.

## File structure

New, under `Sources/GrantivaCore/Android/`:
- `AndroidSDK.swift`: SDK root and tool path discovery; JDK lookup.
- `ADB.swift`: `ADB` and `ADBDevice`; every adb command line and output parser.
- `AndroidCaptureSettings.swift`: demo mode and animation scale save/set/restore.
- `GradleBuildRunner.swift` and `APKOutputMetadata.swift`: build and APK selection.
- `EmulatorManager.swift` and `AndroidProvenance.swift`: device selection, AVD boot, boot wait, started-emulator ledger.
- `AndroidPlatform.swift`: the `DevicePlatform` implementation.

Modified: `Platform/DevicePlatform.swift`, `Platform/IOSPlatform.swift`, `Build/AppBinaryResolver.swift` (`ResolvedBinary.appID`), `Build/BuildResult.swift` (`applicationId`), `Config/ProjectResolver.swift` (`ResolvedProject.android` and `resolveAndroid`), `Runner/RunnerSession.swift`, `Runner/RunnerExecution.swift`, `Runner/LogStreamer.swift`, `Simulator/SimulatorUDID.swift`, `Doctor/DoctorRunner.swift`.

New, under `Sources/GrantivaCLI/`: `TargetOptions.swift`. Modified: `Options.swift`, `RunCommand.swift`, `CICommand.swift`, `BuildCommand.swift`, `DiffCommand.swift`, `InitCommand.swift`, `DoctorCommand.swift`.

New: `examples/android/` (Compose app plus `grantiva-android.yml`), `docs/android.md`.

Tests: one new `Tests/GrantivaCoreTests/<Unit>Tests.swift` per new core file, plus `Tests/GrantivaCLITests/TargetOptionsTests.swift`, `AndroidCommandTests.swift`, `InitAndroidTests.swift`, changes to `PlatformOptionTests.swift`, `DoctorTests.swift`, `DiffCommandTests.swift`.

Shared test helper, created in Task 2: `Tests/GrantivaCoreTests/Support/ScriptedShell.swift`.

---

### Task 1: AndroidSDK discovery

**Files:**
- Create: `Sources/GrantivaCore/Android/AndroidSDK.swift`
- Test: `Tests/GrantivaCoreTests/AndroidSDKTests.swift`

**Interfaces:**
- Produces: `AndroidSDK(root:)`, `AndroidSDK.locate(environment:home:fileManager:) -> AndroidSDK?`, `AndroidSDK.require(environment:home:fileManager:) throws -> AndroidSDK`, `adb`, `emulator`, `avdmanager`, `sdkmanager`, `apkanalyzer` path properties, `AndroidSDK.javaHome(environment:fileManager:execute:) async -> String?`, `AndroidSDK.missingMessage`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class AndroidSDKTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("android-sdk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func makeSDK(_ name: String) throws -> String {
        let root = scratch.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("platform-tools"), withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("platform-tools/adb"))
        return root.path
    }

    func testLocatePrefersAndroidHomeThenSdkRootThenLibrary() throws {
        let home = try makeSDK("home")
        let sdkRoot = try makeSDK("sdkroot")
        let library = scratch.appendingPathComponent("user").path
        _ = try makeSDK("user/Library/Android/sdk")

        XCTAssertEqual(AndroidSDK.locate(environment: ["ANDROID_HOME": home, "ANDROID_SDK_ROOT": sdkRoot], home: library)?.root, home)
        XCTAssertEqual(AndroidSDK.locate(environment: ["ANDROID_SDK_ROOT": sdkRoot], home: library)?.root, sdkRoot)
        XCTAssertEqual(AndroidSDK.locate(environment: [:], home: library)?.root, "\(library)/Library/Android/sdk")
    }

    func testLocateSkipsARootWithoutAdb() throws {
        let empty = scratch.appendingPathComponent("empty").path
        try FileManager.default.createDirectory(atPath: empty, withIntermediateDirectories: true)
        let good = try makeSDK("good")
        XCTAssertEqual(AndroidSDK.locate(environment: ["ANDROID_HOME": empty, "ANDROID_SDK_ROOT": good], home: scratch.path)?.root, good)
        XCTAssertNil(AndroidSDK.locate(environment: ["ANDROID_HOME": empty], home: scratch.path))
    }

    func testRequireThrowsTheSetupMessage() {
        XCTAssertThrowsError(try AndroidSDK.require(environment: [:], home: scratch.path)) { error in
            XCTAssertTrue("\(error)".contains("ANDROID_HOME"), "\(error)")
            XCTAssertTrue("\(error)".contains("scripts/android-env.sh"), "\(error)")
        }
    }

    func testToolPathsHangOffTheRoot() {
        let sdk = AndroidSDK(root: "/sdk")
        XCTAssertEqual(sdk.adb, "/sdk/platform-tools/adb")
        XCTAssertEqual(sdk.emulator, "/sdk/emulator/emulator")
        XCTAssertEqual(sdk.avdmanager, "/sdk/cmdline-tools/latest/bin/avdmanager")
        XCTAssertEqual(sdk.sdkmanager, "/sdk/cmdline-tools/latest/bin/sdkmanager")
        XCTAssertEqual(sdk.apkanalyzer, "/sdk/cmdline-tools/latest/bin/apkanalyzer")
    }

    func testJavaHomeUsesTheVariableWhenItExistsElseJavaHomeTool() async throws {
        let jdk = scratch.appendingPathComponent("jdk").path
        try FileManager.default.createDirectory(atPath: jdk, withIntermediateDirectories: true)
        let fromEnv = await AndroidSDK.javaHome(environment: ["JAVA_HOME": jdk], execute: { _ in XCTFail("must not shell out"); return "" })
        XCTAssertEqual(fromEnv, jdk)

        let fromTool = await AndroidSDK.javaHome(environment: ["JAVA_HOME": "/nonexistent"], execute: { command in
            XCTAssertEqual(command, "/usr/libexec/java_home")
            return "/Library/Java/JavaVirtualMachines/jdk-21/Contents/Home\n"
        })
        XCTAssertEqual(fromTool, "/Library/Java/JavaVirtualMachines/jdk-21/Contents/Home")

        let none = await AndroidSDK.javaHome(environment: [:], execute: { _ in throw GrantivaError.commandFailed("no java", 1) })
        XCTAssertNil(none)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter AndroidSDKTests`
Expected: compile failure, `AndroidSDK` not found.

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

/// Where the Android command-line tools live. Nothing is installed here;
/// `scripts/android-env.sh` does that.
public struct AndroidSDK: Sendable, Equatable {
    public let root: String

    public init(root: String) {
        self.root = root
    }

    public var adb: String { "\(root)/platform-tools/adb" }
    public var emulator: String { "\(root)/emulator/emulator" }
    public var avdmanager: String { "\(root)/cmdline-tools/latest/bin/avdmanager" }
    public var sdkmanager: String { "\(root)/cmdline-tools/latest/bin/sdkmanager" }
    public var apkanalyzer: String { "\(root)/cmdline-tools/latest/bin/apkanalyzer" }

    public static let missingMessage =
        "Android SDK not found. Set ANDROID_HOME (or ANDROID_SDK_ROOT) to an SDK with platform-tools/adb, "
        + "or run scripts/android-env.sh to install one at ~/Library/Android/sdk."

    /// `ANDROID_HOME`, then `ANDROID_SDK_ROOT`, then `~/Library/Android/sdk`.
    /// A candidate counts only when it holds `platform-tools/adb`.
    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) -> AndroidSDK? {
        let candidates = [
            environment["ANDROID_HOME"],
            environment["ANDROID_SDK_ROOT"],
            "\(home)/Library/Android/sdk",
        ].compactMap { $0 }.filter { !$0.isEmpty }
        for candidate in candidates {
            let sdk = AndroidSDK(root: candidate)
            if fileManager.fileExists(atPath: sdk.adb) {
                return sdk
            }
        }
        return nil
    }

    public static func require(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) throws -> AndroidSDK {
        guard let sdk = locate(environment: environment, home: home, fileManager: fileManager) else {
            throw GrantivaError.invalidArgument(missingMessage)
        }
        return sdk
    }

    /// `JAVA_HOME` when it names an existing directory, else the output of
    /// `/usr/libexec/java_home`, else nil.
    public static func javaHome(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        execute: @Sendable (String) async throws -> String = { try await shell($0) }
    ) async -> String? {
        if let configured = environment["JAVA_HOME"], !configured.isEmpty, fileManager.fileExists(atPath: configured) {
            return configured
        }
        guard let output = try? await execute("/usr/libexec/java_home") else { return nil }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter AndroidSDKTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/GrantivaCore/Android/AndroidSDK.swift Tests/GrantivaCoreTests/AndroidSDKTests.swift
git commit -m "Add AndroidSDK tool discovery"
```

---

### Task 2: ADB command wrapper and ASCII-only serials

**Files:**
- Create: `Sources/GrantivaCore/Android/ADB.swift`
- Create: `Tests/GrantivaCoreTests/Support/ScriptedShell.swift`
- Modify: `Sources/GrantivaCore/Simulator/SimulatorUDID.swift` (`DeviceID.isADBSerial`)
- Test: `Tests/GrantivaCoreTests/ADBTests.swift`, add one test to `Tests/GrantivaCoreTests/SimulatorUDIDTests.swift`

**Interfaces:**
- Consumes: `shellQuoted`, `GrantivaError`.
- Produces: `ADBDevice(serial:state:)` with `isEmulator`, `isUsable`; `ADB(path:execute:)` with `devices()`, `avdName(serial:)`, `getprop(serial:_:)`, `shell(serial:_:)`, `install(serial:apk:applicationId:)`, `launch(serial:applicationId:)`, `forceStop(serial:applicationId:)`, `uninstall(serial:applicationId:)`, `screenshot(serial:to:)`, `displaySize(serial:)`, `density(serial:)`, `packageUID(serial:applicationId:)`, `removeAllForwards(serial:)`, `emuKill(serial:)`, and static parsers `parseDevices`, `parseDisplaySize`, `parseDensity`, `parsePackageUID`. `ADB.uiAutomator2Packages`.

- [ ] **Step 1: Write the shared scripted shell**

```swift
import Foundation
@testable import GrantivaCore

/// Records every command line and answers from a script, in order.
/// Shared by the Android unit tests so each file does not redefine it.
final class ScriptedShell: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<String, Error>]
    private var recorded: [String] = []

    init(_ results: [Result<String, Error>] = []) { self.results = results }

    /// Every call succeeds with this answer when the script runs out.
    var fallback: String = ""

    func execute(_ command: String) async throws -> String {
        try lock.withLock {
            recorded.append(command)
            guard !results.isEmpty else { return fallback }
            return try results.removeFirst().get()
        }
    }

    var commands: [String] { lock.withLock { recorded } }
}
```

- [ ] **Step 2: Write the failing ADB tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class ADBTests: XCTestCase {
    private let adbPath = "/sdk/platform-tools/adb"

    func testDevicesParsesSerialsAndStatesAndSkipsTheHeader() {
        let output = """
        List of devices attached
        emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:1
        R58M1234ABC            unauthorized usb:1-1 transport_id:2
        emulator-5556          offline
        """
        XCTAssertEqual(ADB.parseDevices(output), [
            ADBDevice(serial: "emulator-5554", state: "device"),
            ADBDevice(serial: "R58M1234ABC", state: "unauthorized"),
            ADBDevice(serial: "emulator-5556", state: "offline"),
        ])
        XCTAssertTrue(ADBDevice(serial: "emulator-5554", state: "device").isEmulator)
        XCTAssertFalse(ADBDevice(serial: "R58M1234ABC", state: "device").isEmulator)
        XCTAssertFalse(ADBDevice(serial: "emulator-5556", state: "offline").isUsable)
    }

    func testEveryCommandLineIsQuotedAndTargetsTheSerial() async throws {
        let shell = ScriptedShell()
        shell.fallback = ""
        let adb = ADB(path: adbPath, execute: shell.execute)
        let serial = "emulator-5554"
        _ = try await adb.devices()
        _ = try? await adb.avdName(serial: serial)
        _ = try await adb.getprop(serial: serial, "ro.product.cpu.abi")
        try await adb.launch(serial: serial, applicationId: "com.example.app")
        try await adb.forceStop(serial: serial, applicationId: "com.example.app")
        try await adb.uninstall(serial: serial, applicationId: "com.example.app")
        try await adb.screenshot(serial: serial, to: "/tmp/shot's.png")
        try await adb.removeAllForwards(serial: serial)
        try await adb.emuKill(serial: serial)
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' devices -l",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' emu avd name",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell getprop 'ro.product.cpu.abi'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell monkey -p 'com.example.app' -c android.intent.category.LAUNCHER 1",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'com.example.app'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell pm uninstall 'com.example.app'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' exec-out screencap -p > '/tmp/shot'\\''s.png'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove-all",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' emu kill",
        ])
    }

    func testAvdNameDropsTheOKLine() async throws {
        let shell = ScriptedShell([.success("Pixel_8_API_35\nOK")])
        let name = try await ADB(path: adbPath, execute: shell.execute).avdName(serial: "emulator-5554")
        XCTAssertEqual(name, "Pixel_8_API_35")
    }

    func testInstallRetriesOnceAfterUninstallOnUpdateIncompatible() async throws {
        let shell = ScriptedShell([
            .failure(GrantivaError.commandFailed("adb: failed to install app.apk: Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: ...]", 1)),
            .success("Success"),
            .success("Success"),
        ])
        let adb = ADB(path: adbPath, execute: shell.execute)
        try await adb.install(serial: "emulator-5554", apk: "/b/app.apk", applicationId: "com.example.app")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' install -r -t -d '/b/app.apk'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell pm uninstall 'com.example.app'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' install -r -t -d '/b/app.apk'",
        ])
    }

    func testInstallDoesNotRetryOtherFailures() async {
        let shell = ScriptedShell([.failure(GrantivaError.commandFailed("INSTALL_FAILED_INSUFFICIENT_STORAGE", 1))])
        let adb = ADB(path: adbPath, execute: shell.execute)
        do {
            try await adb.install(serial: "emulator-5554", apk: "/b/app.apk", applicationId: "com.example.app")
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(shell.commands.count, 1)
        }
    }

    func testDisplaySizePrefersOverrideThenPhysical() {
        XCTAssertEqual(ADB.parseDisplaySize("Physical size: 1080x2400\nOverride size: 720x1600")?.width, 720)
        XCTAssertEqual(ADB.parseDisplaySize("Physical size: 1080x2400")?.height, 2400)
        XCTAssertNil(ADB.parseDisplaySize("garbage"))
        XCTAssertEqual(ADB.parseDensity("Physical density: 420\nOverride density: 280"), 280)
        XCTAssertEqual(ADB.parseDensity("Physical density: 420"), 420)
    }

    func testPackageUIDMatchesTheExactPackageOnly() {
        let output = """
        package:com.android.settings uid:1000
        package:com.android.settings.auto_generated_rro_product__ uid:10028
        """
        XCTAssertEqual(ADB.parsePackageUID(output, applicationId: "com.android.settings"), 1000)
        XCTAssertNil(ADB.parsePackageUID(output, applicationId: "com.android"))
    }

    func testShellCommandIsQuotedAsOneArgument() async throws {
        let shell = ScriptedShell([.success("")])
        _ = try await ADB(path: adbPath, execute: shell.execute).shell(serial: "emulator-5554", "settings put global window_animation_scale 0")
        XCTAssertEqual(shell.commands, ["'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'settings put global window_animation_scale 0'"])
    }
}
```

Add to `SimulatorUDIDTests.swift`:

```swift
    func testADBSerialIsASCIIOnly() {
        XCTAssertTrue(DeviceID.isADBSerial("emulator-5554"))
        XCTAssertTrue(DeviceID.isADBSerial("192.168.1.10:5555"))
        XCTAssertFalse(DeviceID.isADBSerial("émulator-5554"))
        XCTAssertFalse(DeviceID.isADBSerial("-5554"))
        XCTAssertFalse(DeviceID.isADBSerial("emu\nlator"))
    }
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter 'ADBTests|SimulatorUDIDTests'`
Expected: compile failure on `ADB`; the serial test fails on the accented input.

- [ ] **Step 4: Write ADB.swift**

```swift
import Foundation

public struct ADBDevice: Sendable, Equatable {
    public let serial: String
    public let state: String

    public init(serial: String, state: String) {
        self.serial = serial
        self.state = state
    }

    public var isEmulator: Bool { serial.hasPrefix("emulator-") }
    public var isUsable: Bool { state == "device" }
}

/// Every adb command Grantiva runs, as exact command lines. Output parsing
/// is static so it can be tested without a device.
public struct ADB: Sendable {
    public let path: String
    private let execute: @Sendable (String) async throws -> String

    public static let uiAutomator2Packages = ["io.appium.uiautomator2.server", "io.appium.uiautomator2.server.test"]

    public init(path: String, execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) }) {
        self.path = path
        self.execute = execute
    }

    /// `'<adb>' [-s '<serial>'] <args...>`: every argument that is user data
    /// is quoted; fixed adb words are not, so the lines read like a terminal.
    func line(_ serial: String?, _ tail: String) -> String {
        var parts = [shellQuoted(path)]
        if let serial { parts += ["-s", shellQuoted(serial)] }
        parts.append(tail)
        return parts.joined(separator: " ")
    }

    public func devices() async throws -> [ADBDevice] {
        Self.parseDevices(try await execute(line(nil, "devices -l")))
    }

    public static func parseDevices(_ output: String) -> [ADBDevice] {
        output.components(separatedBy: "\n").compactMap { raw in
            let fields = raw.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count >= 2, fields[0] != "List", !fields[0].hasPrefix("*") else { return nil }
            return ADBDevice(serial: fields[0], state: fields[1])
        }
    }

    /// `adb emu avd name` prints the name and then `OK`.
    public func avdName(serial: String) async throws -> String {
        let output = try await execute(line(serial, "emu avd name"))
        guard let first = output.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !first.isEmpty, first != "OK" else {
            throw GrantivaError.commandFailed("Could not read the AVD name of \(serial)", 1)
        }
        return first
    }

    public func getprop(serial: String, _ key: String) async throws -> String {
        try await execute(line(serial, "shell getprop \(shellQuoted(key))")).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Runs one shell command on the device, passed as a single quoted argument.
    @discardableResult
    public func shell(serial: String, _ command: String) async throws -> String {
        try await execute(line(serial, "shell \(shellQuoted(command))"))
    }

    public func install(serial: String, apk: String, applicationId: String?) async throws {
        let command = line(serial, "install -r -t -d \(shellQuoted(apk))")
        do {
            _ = try await execute(command)
        } catch let error as GrantivaError {
            guard case .commandFailed(let message, _) = error,
                  message.contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE"),
                  let applicationId else { throw error }
            try await uninstall(serial: serial, applicationId: applicationId)
            _ = try await execute(command)
        }
    }

    public func launch(serial: String, applicationId: String) async throws {
        _ = try await execute(line(serial, "shell monkey -p \(shellQuoted(applicationId)) -c android.intent.category.LAUNCHER 1"))
    }

    public func forceStop(serial: String, applicationId: String) async throws {
        _ = try await execute(line(serial, "shell am force-stop \(shellQuoted(applicationId))"))
    }

    public func uninstall(serial: String, applicationId: String) async throws {
        _ = try await execute(line(serial, "shell pm uninstall \(shellQuoted(applicationId))"))
    }

    public func screenshot(serial: String, to path: String) async throws {
        _ = try await execute(line(serial, "exec-out screencap -p > \(shellQuoted(path))"))
    }

    public func displaySize(serial: String) async throws -> (width: Int, height: Int) {
        let output = try await shell(serial: serial, "wm size")
        guard let size = Self.parseDisplaySize(output) else {
            throw GrantivaError.invalidArgument("Could not read the display size of \(serial): \(output)")
        }
        return size
    }

    /// `Override size` wins over `Physical size`.
    public static func parseDisplaySize(_ output: String) -> (width: Int, height: Int)? {
        func value(after label: String) -> (Int, Int)? {
            guard let lineText = output.components(separatedBy: "\n").first(where: { $0.hasPrefix(label) }) else { return nil }
            let dims = lineText.dropFirst(label.count).trimmingCharacters(in: .whitespaces).split(separator: "x")
            guard dims.count == 2, let w = Int(dims[0]), let h = Int(dims[1]) else { return nil }
            return (w, h)
        }
        return value(after: "Override size:") ?? value(after: "Physical size:")
    }

    public func density(serial: String) async throws -> Int {
        let output = try await shell(serial: serial, "wm density")
        guard let density = Self.parseDensity(output) else {
            throw GrantivaError.invalidArgument("Could not read the display density of \(serial): \(output)")
        }
        return density
    }

    public static func parseDensity(_ output: String) -> Int? {
        func value(after label: String) -> Int? {
            guard let lineText = output.components(separatedBy: "\n").first(where: { $0.hasPrefix(label) }) else { return nil }
            return Int(lineText.dropFirst(label.count).trimmingCharacters(in: .whitespaces))
        }
        return value(after: "Override density:") ?? value(after: "Physical density:")
    }

    public func packageUID(serial: String, applicationId: String) async throws -> Int? {
        Self.parsePackageUID(try await shell(serial: serial, "pm list packages -U \(applicationId)"), applicationId: applicationId)
    }

    /// `pm list packages -U <id>` is a substring match; keep only the exact package.
    public static func parsePackageUID(_ output: String, applicationId: String) -> Int? {
        for raw in output.components(separatedBy: "\n") {
            let fields = raw.trimmingCharacters(in: .whitespaces).split(separator: " ")
            guard fields.count == 2, fields[0] == "package:\(applicationId)", fields[1].hasPrefix("uid:") else { continue }
            return Int(fields[1].dropFirst(4))
        }
        return nil
    }

    public func removeAllForwards(serial: String) async throws {
        _ = try await execute(line(serial, "forward --remove-all"))
    }

    public func emuKill(serial: String) async throws {
        _ = try await execute(line(serial, "emu kill"))
    }
}
```

- [ ] **Step 5: Limit serials to ASCII**

In `SimulatorUDID.swift`, replace the body of `isADBSerial`:

```swift
    public static func isADBSerial(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 64 else { return false }
        let scalars = value.unicodeScalars
        guard scalars.allSatisfy({ scalar in
            scalar.isASCII && (scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) || "_-.:".unicodeScalars.contains(scalar))
        }) else { return false }
        guard let first = scalars.first, first.properties.isAlphabetic || ("0"..."9").contains(first) else { return false }
        return true
    }
```

- [ ] **Step 6: Run to verify pass**

Run: `swift test --filter 'ADBTests|SimulatorUDIDTests'`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/GrantivaCore/Android/ADB.swift Sources/GrantivaCore/Simulator/SimulatorUDID.swift Tests/GrantivaCoreTests/Support/ScriptedShell.swift Tests/GrantivaCoreTests/ADBTests.swift Tests/GrantivaCoreTests/SimulatorUDIDTests.swift
git commit -m "Add the ADB command wrapper and limit serials to ASCII"
```

---

### Task 3: Capture settings with crash recovery

**Files:**
- Create: `Sources/GrantivaCore/Android/AndroidCaptureSettings.swift`
- Test: `Tests/GrantivaCoreTests/AndroidCaptureSettingsTests.swift`

**Interfaces:**
- Consumes: `ADB.shell(serial:_:)`.
- Produces: `AndroidCaptureSettings(adb:stateDirectory:)` with `prepare(serial:)`, `restore(serial:)`, `restoreIfCrashed(serial:) -> Bool`, `AndroidCaptureSettings.statePath(serial:directory:)`, `AndroidCaptureSettings.trackedSettings`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class AndroidCaptureSettingsTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("android-capture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func settings(_ shell: ScriptedShell) -> AndroidCaptureSettings {
        AndroidCaptureSettings(adb: ADB(path: "/sdk/platform-tools/adb", execute: shell.execute), stateDirectory: scratch.path)
    }

    private func shellBody(_ command: String) -> String {
        // "'/sdk/platform-tools/adb' -s 'emulator-5554' shell '<body>'" -> body
        let marker = " shell '"
        guard let range = command.range(of: marker) else { return command }
        return String(command[range.upperBound...].dropLast()).replacingOccurrences(of: "'\\''", with: "'")
    }

    func testPrepareSavesCurrentValuesThenSetsDemoModeScalesAndRotation() async throws {
        let reads: [Result<String, Error>] = [
            .success("0"), .success("1.0"), .success("1.0"), .success("1.0"), .success("1"), .success("null"),
        ]
        let shell = ScriptedShell(reads)
        try await settings(shell).prepare(serial: "emulator-5554")
        let bodies = shell.commands.map(shellBody)
        XCTAssertEqual(Array(bodies.prefix(6)), [
            "settings get global sysui_demo_allowed",
            "settings get global window_animation_scale",
            "settings get global transition_animation_scale",
            "settings get global animator_duration_scale",
            "settings get system accelerometer_rotation",
            "settings get system user_rotation",
        ])
        XCTAssertEqual(Array(bodies.dropFirst(6)), [
            "settings put global sysui_demo_allowed 1",
            "am broadcast -a com.android.systemui.demo -e command enter",
            "am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941",
            "am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false",
            "am broadcast -a com.android.systemui.demo -e command notifications -e visible false",
            "am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4",
            "am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4",
            "settings put global window_animation_scale 0",
            "settings put global transition_animation_scale 0",
            "settings put global animator_duration_scale 0",
            "settings put system accelerometer_rotation 0",
            "settings put system user_rotation 0",
        ])
        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: state))
        let saved = try JSONDecoder().decode([String: String?].self, from: Data(contentsOf: URL(fileURLWithPath: state)))
        XCTAssertEqual(saved["global/window_animation_scale"], "1.0")
        XCTAssertEqual(saved["system/user_rotation"] ?? nil, nil, "null reads back as absent")
    }

    func testRestoreWritesSavedValuesExitsDemoModeAndDeletesTheFile() async throws {
        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        let saved: [String: String?] = [
            "global/sysui_demo_allowed": "0", "global/window_animation_scale": "1.0",
            "global/transition_animation_scale": "1.0", "global/animator_duration_scale": "1.0",
            "system/accelerometer_rotation": "1", "system/user_rotation": nil,
        ]
        try JSONEncoder().encode(saved).write(to: URL(fileURLWithPath: state))
        let shell = ScriptedShell()
        await settings(shell).restore(serial: "emulator-5554")
        let bodies = shell.commands.map(shellBody)
        XCTAssertEqual(bodies.first, "am broadcast -a com.android.systemui.demo -e command exit")
        XCTAssertTrue(bodies.contains("settings put global window_animation_scale 1.0"))
        XCTAssertTrue(bodies.contains("settings put system accelerometer_rotation 1"))
        XCTAssertTrue(bodies.contains("settings delete system user_rotation"), "a null value is deleted, not written as the string null")
        XCTAssertTrue(bodies.contains("settings put global sysui_demo_allowed 0"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: state))
    }

    func testRestoreIfCrashedRestoresWhenAFileIsLeftAndIsANoOpOtherwise() async throws {
        let shell = ScriptedShell()
        let settings = settings(shell)
        let untouched = await settings.restoreIfCrashed(serial: "emulator-5554")
        XCTAssertFalse(untouched)
        XCTAssertTrue(shell.commands.isEmpty)

        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        try JSONEncoder().encode(["global/window_animation_scale": "1.0"] as [String: String?]).write(to: URL(fileURLWithPath: state))
        let restored = await settings.restoreIfCrashed(serial: "emulator-5554")
        XCTAssertTrue(restored)
        XCTAssertTrue(shell.commands.map(shellBody).contains("settings put global window_animation_scale 1.0"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: state))
    }

    func testStatePathSanitizesTheSerial() {
        XCTAssertEqual(
            AndroidCaptureSettings.statePath(serial: "192.168.1.10:5555", directory: ".grantiva"),
            ".grantiva/android-settings-192.168.1.10_5555.json"
        )
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter AndroidCaptureSettingsTests`
Expected: compile failure.

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

/// Puts an Android device into a deterministic state for screenshots and
/// puts it back afterwards. The previous values are written to disk first so
/// a crashed run can be undone by the next one.
public struct AndroidCaptureSettings: Sendable {
    public struct Setting: Sendable, Equatable {
        public let namespace: String
        public let key: String
        public let captureValue: String
        var id: String { "\(namespace)/\(key)" }
    }

    /// In the order they are read, and written back.
    public static let trackedSettings: [Setting] = [
        Setting(namespace: "global", key: "sysui_demo_allowed", captureValue: "1"),
        Setting(namespace: "global", key: "window_animation_scale", captureValue: "0"),
        Setting(namespace: "global", key: "transition_animation_scale", captureValue: "0"),
        Setting(namespace: "global", key: "animator_duration_scale", captureValue: "0"),
        Setting(namespace: "system", key: "accelerometer_rotation", captureValue: "0"),
        Setting(namespace: "system", key: "user_rotation", captureValue: "0"),
    ]

    static let demoCommands = [
        "am broadcast -a com.android.systemui.demo -e command enter",
        "am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941",
        "am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false",
        "am broadcast -a com.android.systemui.demo -e command notifications -e visible false",
        "am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4",
        "am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype none -e level 4",
    ]

    private let adb: ADB
    private let stateDirectory: String

    public init(adb: ADB, stateDirectory: String = ".grantiva") {
        self.adb = adb
        self.stateDirectory = stateDirectory
    }

    public static func statePath(serial: String, directory: String = ".grantiva") -> String {
        let safe = serial.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return "\(directory)/android-settings-\(safe).json"
    }

    /// Reads and saves every tracked value, then applies the capture state.
    public func prepare(serial: String) async throws {
        var saved: [String: String?] = [:]
        for setting in Self.trackedSettings {
            let value = try await adb.shell(serial: serial, "settings get \(setting.namespace) \(setting.key)")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            saved[setting.id] = value == "null" ? .some(nil) : .some(value)
        }
        try FileManager.default.createDirectory(atPath: stateDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(saved).write(to: URL(fileURLWithPath: Self.statePath(serial: serial, directory: stateDirectory)))

        try await adb.shell(serial: serial, "settings put global sysui_demo_allowed 1")
        for command in Self.demoCommands {
            try await adb.shell(serial: serial, command)
        }
        for setting in Self.trackedSettings where setting.key != "sysui_demo_allowed" {
            try await adb.shell(serial: serial, "settings put \(setting.namespace) \(setting.key) \(setting.captureValue)")
        }
    }

    /// Exits demo mode and writes the saved values back. Never throws: a
    /// failed restore is logged and the state file is still removed so the
    /// next run does not loop on it.
    public func restore(serial: String) async {
        let path = Self.statePath(serial: serial, directory: stateDirectory)
        let saved = (try? Data(contentsOf: URL(fileURLWithPath: path)))
            .flatMap { try? JSONDecoder().decode([String: String?].self, from: $0) } ?? [:]
        _ = try? await adb.shell(serial: serial, "am broadcast -a com.android.systemui.demo -e command exit")
        for setting in Self.trackedSettings {
            guard let entry = saved[setting.id] else { continue }
            let command: String
            if let value = entry {
                command = "settings put \(setting.namespace) \(setting.key) \(value)"
            } else {
                command = "settings delete \(setting.namespace) \(setting.key)"
            }
            do {
                try await adb.shell(serial: serial, command)
            } catch {
                GrantivaLog.logger.warning("could not restore \(setting.id) on \(serial): \(error)")
            }
        }
        try? FileManager.default.removeItem(atPath: path)
    }

    /// A state file at the start of a run means the previous run crashed
    /// between `prepare` and `restore`. Returns true when a restore ran.
    public func restoreIfCrashed(serial: String) async -> Bool {
        guard FileManager.default.fileExists(atPath: Self.statePath(serial: serial, directory: stateDirectory)) else { return false }
        GrantivaLog.logger.warning("restoring Android settings left by an interrupted run on \(serial)")
        await restore(serial: serial)
        return true
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter AndroidCaptureSettingsTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/GrantivaCore/Android/AndroidCaptureSettings.swift Tests/GrantivaCoreTests/AndroidCaptureSettingsTests.swift
git commit -m "Add Android capture settings with crash recovery"
```

---

### Task 4: Gradle build and APK selection

**Files:**
- Create: `Sources/GrantivaCore/Android/APKOutputMetadata.swift`
- Create: `Sources/GrantivaCore/Android/GradleBuildRunner.swift`
- Modify: `Sources/GrantivaCore/Build/BuildResult.swift` (add `applicationId: String?`)
- Test: `Tests/GrantivaCoreTests/APKOutputMetadataTests.swift`, `Tests/GrantivaCoreTests/GradleBuildRunnerTests.swift`

**Interfaces:**
- Consumes: `BuildResult`, `shellQuoted`, `GrantivaError`.
- Produces: `BuildResult.applicationId: String?` (new, default nil, Codable); `APKOutputMetadata` (Decodable) with `applicationId`, `variantName`, `elements`, `static find(buildDirectory:variant:fileManager:) throws -> Located?` where `Located { metadata, directory }`, `apkPath(in:deviceABI:) throws -> String`; `GradleBuildRunner(execute:fileManager:)` with `build(projectRoot:module:variant:extraArgs:javaHome:deviceABI:) async throws -> BuildResult`, `static taskName(module:variant:)`, `static command(projectRoot:module:variant:extraArgs:javaHome:fileManager:)`, `static buildDirectory(projectRoot:module:extraArgs:)`.

- [ ] **Step 1: Write the failing metadata tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class APKOutputMetadataTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("apk-meta-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func write(_ json: String, at relative: String) throws -> String {
        let url = scratch.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url.deletingLastPathComponent().path
    }

    private let universal = """
    {"version":3,"artifactType":{"type":"APK","kind":"Directory"},"applicationId":"com.example.app","variantName":"debug",
     "elements":[{"type":"SINGLE","filters":[],"attributes":[],"versionCode":1,"versionName":"1.0","outputFile":"app-debug.apk"}],"elementType":"File"}
    """

    private let split = """
    {"version":3,"artifactType":{"type":"APK","kind":"Directory"},"applicationId":"com.example.app","variantName":"freeDebug",
     "elements":[
       {"type":"ONE_OF_MANY","filters":[{"filterType":"ABI","value":"arm64-v8a"}],"attributes":[],"versionCode":1,"versionName":"1.0","outputFile":"app-free-arm64-v8a-debug.apk"},
       {"type":"ONE_OF_MANY","filters":[{"filterType":"ABI","value":"x86_64"}],"attributes":[],"versionCode":1,"versionName":"1.0","outputFile":"app-free-x86_64-debug.apk"}
     ],"elementType":"File"}
    """

    func testFindLocatesTheVariantAnywhereUnderOutputsApk() throws {
        let dir = try write(split, at: "outputs/apk/free/debug/output-metadata.json")
        _ = try write(universal, at: "outputs/apk/debug/output-metadata.json")
        let located = try XCTUnwrap(APKOutputMetadata.find(buildDirectory: scratch.path, variant: "freeDebug"))
        XCTAssertEqual(located.directory, dir)
        XCTAssertEqual(located.metadata.applicationId, "com.example.app")
        XCTAssertEqual(try APKOutputMetadata.find(buildDirectory: scratch.path, variant: "debug")?.metadata.elements.count, 1)
        XCTAssertNil(try APKOutputMetadata.find(buildDirectory: scratch.path, variant: "release"))
    }

    func testUniversalOrSingleOutputIsChosenRegardlessOfABI() throws {
        let metadata = try JSONDecoder().decode(APKOutputMetadata.self, from: Data(universal.utf8))
        XCTAssertEqual(try metadata.apkPath(in: "/b/debug", deviceABI: "x86_64"), "/b/debug/app-debug.apk")
    }

    func testABISplitChoosesTheDeviceABI() throws {
        let metadata = try JSONDecoder().decode(APKOutputMetadata.self, from: Data(split.utf8))
        XCTAssertEqual(try metadata.apkPath(in: "/b", deviceABI: "x86_64"), "/b/app-free-x86_64-debug.apk")
        XCTAssertEqual(try metadata.apkPath(in: "/b", deviceABI: "arm64-v8a"), "/b/app-free-arm64-v8a-debug.apk")
    }

    func testABISplitWithNoMatchNamesTheABIsPresent() throws {
        let metadata = try JSONDecoder().decode(APKOutputMetadata.self, from: Data(split.utf8))
        XCTAssertThrowsError(try metadata.apkPath(in: "/b", deviceABI: "armeabi-v7a")) { error in
            XCTAssertTrue("\(error)".contains("armeabi-v7a"), "\(error)")
            XCTAssertTrue("\(error)".contains("arm64-v8a, x86_64"), "\(error)")
        }
    }
}
```

- [ ] **Step 2: Write the failing Gradle tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class GradleBuildRunnerTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("gradle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testTaskNameCapitalizesEachVariantComponent() {
        XCTAssertEqual(GradleBuildRunner.taskName(module: "app", variant: "debug"), ":app:assembleDebug")
        XCTAssertEqual(GradleBuildRunner.taskName(module: "mobile", variant: "freeDebug"), ":mobile:assembleFreeDebug")
    }

    func testCommandUsesTheWrapperWhenPresentElseGradleOnPath() throws {
        let noWrapper = GradleBuildRunner.command(projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: ["-PsomeFlag=1"], javaHome: "/jdk")
        XCTAssertEqual(noWrapper, "cd \(shellQuoted(scratch.path)) && JAVA_HOME='/jdk' gradle ':app:assembleDebug' --console=plain '-PsomeFlag=1'")

        try "".write(to: scratch.appendingPathComponent("gradlew"), atomically: true, encoding: .utf8)
        let withWrapper = GradleBuildRunner.command(projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: [], javaHome: nil)
        XCTAssertEqual(withWrapper, "cd \(shellQuoted(scratch.path)) && ./gradlew ':app:assembleDebug' --console=plain")
    }

    func testBuildDirectoryHonorsPBuildDir() {
        XCTAssertEqual(GradleBuildRunner.buildDirectory(projectRoot: "/p", module: "app", extraArgs: []), "/p/app/build")
        XCTAssertEqual(GradleBuildRunner.buildDirectory(projectRoot: "/p", module: "app", extraArgs: ["-PbuildDir=/tmp/out"]), "/tmp/out")
        XCTAssertEqual(GradleBuildRunner.buildDirectory(projectRoot: "/p", module: "app", extraArgs: ["-PbuildDir=out"]), "/p/out")
    }

    func testSuccessfulBuildReturnsApkAndApplicationId() async throws {
        let metadataDir = scratch.appendingPathComponent("app/build/outputs/apk/debug")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        try """
        {"version":3,"artifactType":{"type":"APK","kind":"Directory"},"applicationId":"com.example.app","variantName":"debug",
         "elements":[{"type":"SINGLE","filters":[],"attributes":[],"versionCode":1,"versionName":"1.0","outputFile":"app-debug.apk"}],"elementType":"File"}
        """.write(to: metadataDir.appendingPathComponent("output-metadata.json"), atomically: true, encoding: .utf8)

        let shell = ScriptedShell([.success("> Task :app:assembleDebug\nw: some warning\nBUILD SUCCESSFUL in 3s")])
        let result = try await GradleBuildRunner(execute: shell.execute).build(
            projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: [], javaHome: nil, deviceABI: "arm64-v8a"
        )
        XCTAssertTrue(result.success)
        XCTAssertNil(result.scheme)
        XCTAssertNil(result.destination)
        XCTAssertEqual(result.productPath, metadataDir.appendingPathComponent("app-debug.apk").path)
        XCTAssertEqual(result.applicationId, "com.example.app")
        XCTAssertEqual(result.warnings, ["w: some warning"])
    }

    func testFailedBuildCollectsErrorLines() async throws {
        let shell = ScriptedShell([.failure(GrantivaError.commandFailed("e: Main.kt:3:1 Unresolved reference\nFAILURE: Build failed with an exception.", 1))])
        let result = try await GradleBuildRunner(execute: shell.execute).build(
            projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: [], javaHome: nil, deviceABI: "arm64-v8a"
        )
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errors, ["e: Main.kt:3:1 Unresolved reference", "FAILURE: Build failed with an exception."])
        XCTAssertNil(result.productPath)
    }

    func testSuccessfulBuildWithoutMetadataFailsNamingTheDirectory() async throws {
        let shell = ScriptedShell([.success("BUILD SUCCESSFUL")])
        do {
            _ = try await GradleBuildRunner(execute: shell.execute).build(
                projectRoot: scratch.path, module: "app", variant: "debug", extraArgs: [], javaHome: nil, deviceABI: "arm64-v8a"
            )
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("output-metadata.json"), "\(error)")
            XCTAssertTrue("\(error)".contains("app/build"), "\(error)")
        }
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter 'APKOutputMetadataTests|GradleBuildRunnerTests'`
Expected: compile failure.

- [ ] **Step 4: Add `applicationId` to BuildResult**

In `BuildResult.swift` add `public let applicationId: String?` after `productPath`, with `applicationId: String? = nil` as the last init parameter and `self.applicationId = applicationId`. Existing call sites compile unchanged.

- [ ] **Step 5: Write APKOutputMetadata.swift**

```swift
import Foundation

/// The Android Gradle Plugin writes one of these next to each variant's APKs
/// under `<module>/build/outputs/apk/`. It is the source of the application
/// ID and of which APK fits the target device.
public struct APKOutputMetadata: Decodable, Sendable, Equatable {
    public struct Filter: Decodable, Sendable, Equatable {
        public let filterType: String
        public let value: String
    }

    public struct Element: Decodable, Sendable, Equatable {
        public let type: String
        public let filters: [Filter]
        public let outputFile: String

        var abi: String? { filters.first(where: { $0.filterType == "ABI" })?.value }
    }

    public struct Located: Sendable, Equatable {
        public let metadata: APKOutputMetadata
        public let directory: String
    }

    public let applicationId: String
    public let variantName: String
    public let elements: [Element]

    public static let fileName = "output-metadata.json"

    /// Walks `<buildDirectory>/outputs/apk` for the metadata of `variant`.
    public static func find(buildDirectory: String, variant: String, fileManager: FileManager = .default) throws -> Located? {
        let apkRoot = "\(buildDirectory)/outputs/apk"
        guard let enumerator = fileManager.enumerator(atPath: apkRoot) else { return nil }
        for case let relative as String in enumerator where relative.hasSuffix(fileName) {
            let path = "\(apkRoot)/\(relative)"
            guard let data = fileManager.contents(atPath: path) else { continue }
            let metadata: APKOutputMetadata
            do {
                metadata = try JSONDecoder().decode(APKOutputMetadata.self, from: data)
            } catch {
                throw GrantivaError.buildFailed("\(path) could not be parsed: \(error)")
            }
            if metadata.variantName == variant {
                return Located(metadata: metadata, directory: (path as NSString).deletingLastPathComponent)
            }
        }
        return nil
    }

    /// The universal or single output when there is one, else the element
    /// whose ABI filter matches the device.
    public func apkPath(in directory: String, deviceABI: String) throws -> String {
        if let universal = elements.first(where: { $0.abi == nil }) {
            return "\(directory)/\(universal.outputFile)"
        }
        if let match = elements.first(where: { $0.abi == deviceABI }) {
            return "\(directory)/\(match.outputFile)"
        }
        let present = elements.compactMap(\.abi).sorted().joined(separator: ", ")
        throw GrantivaError.buildFailed(
            "No APK for the device ABI \(deviceABI); the build produced ABI splits for \(present). "
                + "Add a universal APK (splits.abi.universalApk true) or build for the device's ABI."
        )
    }
}
```

- [ ] **Step 6: Write GradleBuildRunner.swift**

```swift
import Foundation

/// Runs `assemble<Variant>` for one module and finds the APK it produced.
public struct GradleBuildRunner: Sendable {
    private let execute: @Sendable (String) async throws -> String
    private let fileManager: FileManager

    public init(
        execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) },
        fileManager: FileManager = .default
    ) {
        self.execute = execute
        self.fileManager = fileManager
    }

    /// `freeDebug` becomes `assembleFreeDebug`: only the first letter changes,
    /// the camel case inside the variant is already right.
    public static func taskName(module: String, variant: String) -> String {
        ":\(module):assemble\(variant.prefix(1).uppercased())\(variant.dropFirst())"
    }

    public static func command(
        projectRoot: String, module: String, variant: String, extraArgs: [String], javaHome: String?,
        fileManager: FileManager = .default
    ) -> String {
        var parts = ["cd \(shellQuoted(projectRoot)) &&"]
        if let javaHome { parts.append("JAVA_HOME=\(shellQuoted(javaHome))") }
        parts.append(fileManager.fileExists(atPath: "\(projectRoot)/gradlew") ? "./gradlew" : "gradle")
        parts.append(shellQuoted(taskName(module: module, variant: variant)))
        parts.append("--console=plain")
        parts += extraArgs.map(shellQuoted)
        return parts.joined(separator: " ")
    }

    /// `-PbuildDir=<path>` in the build arguments overrides `<module>/build`.
    public static func buildDirectory(projectRoot: String, module: String, extraArgs: [String]) -> String {
        if let override = extraArgs.first(where: { $0.hasPrefix("-PbuildDir=") })?.dropFirst("-PbuildDir=".count), !override.isEmpty {
            let path = String(override)
            return path.hasPrefix("/") ? path : "\(projectRoot)/\(path)"
        }
        return "\(projectRoot)/\(module)/build"
    }

    public func build(
        projectRoot: String, module: String, variant: String, extraArgs: [String], javaHome: String?, deviceABI: String
    ) async throws -> BuildResult {
        let start = Date()
        let command = Self.command(projectRoot: projectRoot, module: module, variant: variant, extraArgs: extraArgs, javaHome: javaHome, fileManager: fileManager)
        let output: String
        do {
            output = try await execute(command)
        } catch let error as GrantivaError {
            guard case .commandFailed(let message, _) = error else { throw error }
            let lines = message.components(separatedBy: "\n")
            let errors = lines.filter { Self.isErrorLine($0) }
            return BuildResult(
                success: false, duration: Date().timeIntervalSince(start),
                warnings: lines.filter { Self.isWarningLine($0) },
                errors: errors.isEmpty ? [message] : errors, productPath: nil
            )
        }
        let warnings = output.components(separatedBy: "\n").filter { Self.isWarningLine($0) }
        let buildDirectory = Self.buildDirectory(projectRoot: projectRoot, module: module, extraArgs: extraArgs)
        guard let located = try APKOutputMetadata.find(buildDirectory: buildDirectory, variant: variant, fileManager: fileManager) else {
            throw GrantivaError.buildFailed(
                "The build succeeded but no \(APKOutputMetadata.fileName) for variant \(variant) was found under \(buildDirectory)/outputs/apk. "
                    + "Check module and variant in grantiva-android.yml, or set -PbuildDir in build_args if the build directory is custom."
            )
        }
        let apk = try located.metadata.apkPath(in: located.directory, deviceABI: deviceABI)
        return BuildResult(
            success: true, duration: Date().timeIntervalSince(start),
            warnings: warnings, errors: [], productPath: apk,
            applicationId: located.metadata.applicationId
        )
    }

    static func isWarningLine(_ line: String) -> Bool {
        line.hasPrefix("w: ") || line.contains("warning:")
    }

    static func isErrorLine(_ line: String) -> Bool {
        line.hasPrefix("e: ") || line.contains("error:") || line.hasPrefix("FAILURE:")
    }
}
```

- [ ] **Step 7: Run to verify pass**

Run: `swift test --filter 'APKOutputMetadataTests|GradleBuildRunnerTests|XcodeBuildRunnerTests'`
Expected: all pass; the Xcode tests prove the BuildResult change is additive.

- [ ] **Step 8: Commit**

```bash
git add Sources/GrantivaCore/Android/APKOutputMetadata.swift Sources/GrantivaCore/Android/GradleBuildRunner.swift Sources/GrantivaCore/Build/BuildResult.swift Tests/GrantivaCoreTests/APKOutputMetadataTests.swift Tests/GrantivaCoreTests/GradleBuildRunnerTests.swift
git commit -m "Add GradleBuildRunner and APK output metadata selection"
```

---

### Task 5: Emulator selection, boot, and provenance

**Files:**
- Create: `Sources/GrantivaCore/Android/AndroidProvenance.swift`
- Create: `Sources/GrantivaCore/Android/EmulatorManager.swift`
- Test: `Tests/GrantivaCoreTests/AndroidProvenanceTests.swift`, `Tests/GrantivaCoreTests/EmulatorManagerTests.swift`

**Interfaces:**
- Consumes: `ADB`, `AndroidSDK`, `ChildProcess.spawn`, `BootedDevice`.
- Produces: `StartedEmulatorRecord(serial:avd:pid:startedAt:)`; `AndroidProvenance(directory:)` with `register(_:)`, `all()`, `remove(serial:)`, `contains(serial:)`, `.live`; `EmulatorManager(sdk:adb:execute:spawn:provenance:headless:bootTimeout:pollInterval:)` with `listAVDs()`, `selectDevice(configured:)`, `boot(avd:)`, `waitForBoot(serial:)`, `static choosePort(used:)`, `static bootArguments(avd:port:headless:)`.

- [ ] **Step 1: Write the failing provenance tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class AndroidProvenanceTests: XCTestCase {
    func testRegisterListRemoveRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("android-prov-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let ledger = AndroidProvenance(directory: dir)
        XCTAssertEqual(try ledger.all(), [])
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: 123))
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: 123))
        XCTAssertEqual(try ledger.all().count, 1, "registering twice keeps one record")
        XCTAssertTrue(try ledger.contains(serial: "emulator-5554"))
        try ledger.remove(serial: "emulator-5554")
        XCTAssertFalse(try ledger.contains(serial: "emulator-5554"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(dir)/started.json"))
    }
}
```

- [ ] **Step 2: Write the failing emulator tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class EmulatorManagerTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("emu-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private final class SpawnRecorder: @unchecked Sendable {
        var calls: [(String, [String])] = []
        func spawn(_ executable: String, _ arguments: [String]) throws -> Int32 {
            calls.append((executable, arguments)); return 4242
        }
    }

    private func manager(_ shell: ScriptedShell, spawn: SpawnRecorder = SpawnRecorder(), headless: Bool = true) -> EmulatorManager {
        EmulatorManager(
            sdk: AndroidSDK(root: "/sdk"),
            adb: ADB(path: "/sdk/platform-tools/adb", execute: shell.execute),
            execute: shell.execute,
            spawn: spawn.spawn,
            provenance: AndroidProvenance(directory: scratch.path),
            headless: headless,
            bootTimeout: 1,
            pollInterval: 0.01
        )
    }

    func testChoosePortSkipsSerialsInUse() {
        XCTAssertEqual(EmulatorManager.choosePort(used: []), 5554)
        XCTAssertEqual(EmulatorManager.choosePort(used: ["emulator-5554", "emulator-5556"]), 5558)
        let all = stride(from: 5554, through: 5584, by: 2).map { "emulator-\($0)" }
        XCTAssertNil(EmulatorManager.choosePort(used: all))
    }

    func testBootArgumentsMatchTheSpec() {
        XCTAssertEqual(
            EmulatorManager.bootArguments(avd: "Pixel_8_API_35", port: 5556, headless: false),
            ["-avd", "Pixel_8_API_35", "-port", "5556", "-no-snapshot-save", "-no-boot-anim"]
        )
        XCTAssertEqual(EmulatorManager.bootArguments(avd: "P", port: 5554, headless: true).last, "-no-window")
    }

    func testListAVDsSkipsInfoLines() async throws {
        let shell = ScriptedShell([.success("INFO    | Storing crashdata in: /tmp/x\nPixel_8_API_35\nPixel_7_API_34")])
        let avds = try await manager(shell).listAVDs()
        XCTAssertEqual(avds, ["Pixel_8_API_35", "Pixel_7_API_34"])
        XCTAssertEqual(shell.commands, ["'/sdk/emulator/emulator' -list-avds"])
    }

    func testSelectDeviceUsesTheRunningEmulatorWithTheConfiguredAVD() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 device\nemulator-5556 device"),
            .success("Pixel_7_API_34\nOK"),
            .success("Pixel_8_API_35\nOK"),
        ])
        let device = try await manager(shell).selectDevice(configured: "Pixel_8_API_35")
        XCTAssertEqual(device, BootedDevice(udid: "emulator-5556", name: "Pixel_8_API_35"))
    }

    func testSelectDeviceWithoutConfigUsesTheOnlyRunningEmulator() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 device\nR58M1234ABC device"),
            .success("Pixel_8_API_35\nOK"),
        ])
        let device = try await manager(shell).selectDevice(configured: nil)
        XCTAssertEqual(device.udid, "emulator-5554", "physical devices are never picked by default")
    }

    func testSelectDeviceWithTwoRunningAndNoConfigAsksForAChoice() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 device\nemulator-5556 device"),
            .success("A\nOK"), .success("B\nOK"),
        ])
        do {
            _ = try await manager(shell).selectDevice(configured: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("emulator-5554 (A)"), "\(error)")
            XCTAssertTrue("\(error)".contains("--emulator"), "\(error)")
        }
    }

    func testSelectDeviceBootsTheConfiguredAVDWhenNotRunning() async throws {
        let spawn = SpawnRecorder()
        let shell = ScriptedShell([
            .success("List of devices attached"),                 // adb devices
            .success("Pixel_8_API_35"),                           // emulator -list-avds
            .success("List of devices attached"),                 // devices again, for the port choice
            .success("1"),                                        // sys.boot_completed
            .success("package:/system/framework/framework-res.apk"), // pm path android
            .success(""),                                         // wm dismiss-keyguard
        ])
        let device = try await manager(shell, spawn: spawn).selectDevice(configured: "Pixel_8_API_35")
        XCTAssertEqual(device, BootedDevice(udid: "emulator-5554", name: "Pixel_8_API_35"))
        XCTAssertEqual(spawn.calls.count, 1)
        XCTAssertEqual(spawn.calls[0].0, "/sdk/emulator/emulator")
        XCTAssertEqual(spawn.calls[0].1, ["-avd", "Pixel_8_API_35", "-port", "5554", "-no-snapshot-save", "-no-boot-anim", "-no-window"])
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).all().map(\.serial), ["emulator-5554"])
    }

    func testSelectDeviceWithUnknownAVDListsTheOnesThatExist() async throws {
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_7_API_34")])
        do {
            _ = try await manager(shell).selectDevice(configured: "Nope")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("Pixel_7_API_34"), "\(error)")
        }
    }

    func testSelectDeviceWithNoConfigNoRunningAndOneAVDBootsIt() async throws {
        let spawn = SpawnRecorder()
        let shell = ScriptedShell([
            .success("List of devices attached"), .success("Only_One"),
            .success("List of devices attached"), .success("1"), .success("package:x"), .success(""),
        ])
        let device = try await manager(shell, spawn: spawn).selectDevice(configured: nil)
        XCTAssertEqual(device.name, "Only_One")
        XCTAssertEqual(spawn.calls.count, 1)
    }

    func testOfflineAndUnauthorizedDevicesAreReportedNotUsed() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5554 offline\nemulator-5556 unauthorized"),
            .success(""),
        ])
        do {
            _ = try await manager(shell).selectDevice(configured: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("emulator-5554 is offline"), "\(error)")
            XCTAssertTrue("\(error)".contains("emulator-5556 is unauthorized"), "\(error)")
        }
    }

    func testWaitForBootTimesOutWithAClearMessage() async throws {
        let shell = ScriptedShell()
        shell.fallback = "0"
        do {
            try await manager(shell).waitForBoot(serial: "emulator-5554")
            XCTFail("expected timeout")
        } catch {
            XCTAssertTrue("\(error)".contains("did not finish booting"), "\(error)")
            XCTAssertTrue("\(error)".contains("GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS"), "\(error)")
        }
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter 'AndroidProvenanceTests|EmulatorManagerTests'`
Expected: compile failure.

- [ ] **Step 4: Write AndroidProvenance.swift**

```swift
import Darwin
import Foundation

public struct StartedEmulatorRecord: Codable, Equatable, Sendable {
    public let serial: String
    public let avd: String
    public let pid: Int32
    public let startedAt: Date

    public init(serial: String, avd: String, pid: Int32, startedAt: Date = Date()) {
        self.serial = serial
        self.avd = avd
        self.pid = pid
        self.startedAt = startedAt
    }
}

/// Which emulators Grantiva itself booted. `emulator teardown` (Plan 3)
/// kills only these; nothing else ever touches an emulator the user started.
public struct AndroidProvenance: Sendable {
    public static let live = AndroidProvenance()

    public let directory: String

    public init(directory: String? = nil) {
        self.directory = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".grantiva/android").path
    }

    private var ledgerPath: String { "\(directory)/started.json" }

    public func register(_ record: StartedEmulatorRecord) throws {
        try withLedgerLock { records in
            guard !records.contains(where: { $0.serial == record.serial }) else { return }
            records.append(record)
        }
    }

    public func contains(serial: String) throws -> Bool {
        try withLedgerLock { $0.contains { $0.serial == serial } }
    }

    public func remove(serial: String) throws {
        try withLedgerLock { $0.removeAll { $0.serial == serial } }
    }

    public func all() throws -> [StartedEmulatorRecord] {
        try withLedgerLock { $0 }
    }

    @discardableResult
    private func withLedgerLock<T>(_ body: (inout [StartedEmulatorRecord]) throws -> T) throws -> T {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open("\(directory)/ledger.lock", O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed("Could not open the emulator ledger lock: \(String(cString: strerror(errno)))", 1)
        }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else {
            throw GrantivaError.commandFailed("Could not lock the emulator ledger: \(String(cString: strerror(errno)))", 1)
        }
        defer { flock(descriptor, LOCK_UN) }
        var records: [StartedEmulatorRecord] = []
        if let data = FileManager.default.contents(atPath: ledgerPath), !data.isEmpty {
            records = try JSONDecoder().decode([StartedEmulatorRecord].self, from: data)
        }
        let result = try body(&records)
        try JSONEncoder().encode(records).write(to: URL(fileURLWithPath: ledgerPath), options: .atomic)
        return result
    }
}
```

- [ ] **Step 5: Write EmulatorManager.swift**

```swift
import Darwin
import Foundation

/// Picks the emulator a run uses and boots an AVD when none is running.
public struct EmulatorManager: Sendable {
    public typealias Spawn = @Sendable (_ executable: String, _ arguments: [String]) throws -> Int32

    private let sdk: AndroidSDK
    private let adb: ADB
    private let execute: @Sendable (String) async throws -> String
    private let spawn: Spawn
    private let provenance: AndroidProvenance
    private let headless: Bool
    private let bootTimeout: TimeInterval
    private let pollInterval: TimeInterval

    public static let bootTimeoutVariable = "GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS"

    public init(
        sdk: AndroidSDK,
        adb: ADB,
        execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) },
        spawn: @escaping Spawn = EmulatorManager.detachedSpawn,
        provenance: AndroidProvenance = .live,
        headless: Bool = false,
        bootTimeout: TimeInterval = EmulatorManager.configuredBootTimeout(),
        pollInterval: TimeInterval = 1
    ) {
        self.sdk = sdk
        self.adb = adb
        self.execute = execute
        self.spawn = spawn
        self.provenance = provenance
        self.headless = headless
        self.bootTimeout = bootTimeout
        self.pollInterval = pollInterval
    }

    public static func configuredBootTimeout(environment: [String: String] = ProcessInfo.processInfo.environment) -> TimeInterval {
        environment[bootTimeoutVariable].flatMap(Double.init) ?? 180
    }

    /// The emulator must outlive this process, so it is spawned into its own
    /// process group (ChildProcess does that) and never tracked by SignalRelay.
    /// Its output goes to a log file beside the provenance ledger.
    public static let detachedSpawn: Spawn = { executable, arguments in
        let logDir = AndroidProvenance.live.directory
        try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        let port = arguments.firstIndex(of: "-port").map { arguments[$0 + 1] } ?? "unknown"
        let log = Darwin.open("\(logDir)/emulator-\(port).log", O_CREAT | O_WRONLY | O_TRUNC | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard log >= 0 else {
            throw GrantivaError.commandFailed("Could not open the emulator log file", 1)
        }
        defer { Darwin.close(log) }
        let devnull = Darwin.open("/dev/null", O_RDONLY)
        defer { if devnull >= 0 { Darwin.close(devnull) } }
        let child = try ChildProcess.spawn(
            executable: executable, arguments: arguments,
            stdin: devnull >= 0 ? devnull : nil, stdout: log, stderr: log
        )
        return child.pid
    }

    public func listAVDs() async throws -> [String] {
        try await execute("\(shellQuoted(sdk.emulator)) -list-avds")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("INFO") && !$0.hasPrefix("WARNING") }
    }

    public static func choosePort(used: [String]) -> Int? {
        stride(from: 5554, through: 5584, by: 2).first { !used.contains("emulator-\($0)") }
    }

    public static func bootArguments(avd: String, port: Int, headless: Bool) -> [String] {
        var args = ["-avd", avd, "-port", String(port), "-no-snapshot-save", "-no-boot-anim"]
        if headless { args.append("-no-window") }
        return args
    }

    /// Spec rules: only running emulators count by default. With a configured
    /// AVD name, the running emulator with that name is used, else it is
    /// booted. Without one: a single running emulator, else a single existing
    /// AVD is booted, else the AVDs are listed.
    public func selectDevice(configured: String?) async throws -> BootedDevice {
        let devices = try await adb.devices()
        let broken = devices.filter { !$0.isUsable }
        let running = devices.filter { $0.isEmulator && $0.isUsable }
        var names: [String: String] = [:]
        for device in running {
            names[device.serial] = (try? await adb.avdName(serial: device.serial)) ?? device.serial
        }
        let brokenNote = broken.isEmpty ? "" : " Skipped: " + broken.map { "\($0.serial) is \($0.state)" }.joined(separator: ", ") + "."

        if let configured, !configured.isEmpty {
            if let match = running.first(where: { names[$0.serial] == configured }) {
                return BootedDevice(udid: match.serial, name: configured)
            }
            let avds = try await listAVDs()
            guard avds.contains(configured) else {
                throw GrantivaError.invalidArgument(
                    "No AVD named \"\(configured)\". Existing AVDs: \(avds.isEmpty ? "(none)" : avds.joined(separator: ", ")). "
                        + "Create it with scripts/android-env.sh or avdmanager.\(brokenNote)"
                )
            }
            return try await boot(avd: configured)
        }

        switch running.count {
        case 1:
            return BootedDevice(udid: running[0].serial, name: names[running[0].serial] ?? running[0].serial)
        case 0:
            let avds = try await listAVDs()
            if avds.count == 1 {
                return try await boot(avd: avds[0])
            }
            throw GrantivaError.invalidArgument(
                avds.isEmpty
                    ? "No emulator is running and no AVD exists. Run scripts/android-env.sh to create one.\(brokenNote)"
                    : "No emulator is running. Pass --emulator <AVD> or set emulator in grantiva-android.yml. AVDs: \(avds.joined(separator: ", ")).\(brokenNote)"
            )
        default:
            let list = running.map { "\($0.serial) (\(names[$0.serial] ?? "?"))" }.joined(separator: ", ")
            throw GrantivaError.invalidArgument(
                "Several emulators are running: \(list). Pass --emulator <AVD> or --device <serial>.\(brokenNote)"
            )
        }
    }

    /// Boots `avd` on the first free even port and waits for it.
    public func boot(avd: String) async throws -> BootedDevice {
        let used = try await adb.devices().map(\.serial)
        guard let port = Self.choosePort(used: used) else {
            throw GrantivaError.invalidArgument("No free emulator port between 5554 and 5584; shut one down first.")
        }
        let serial = "emulator-\(port)"
        let arguments = Self.bootArguments(avd: avd, port: port, headless: headless || isatty(STDOUT_FILENO) == 0)
        GrantivaLog.logger.info("Booting AVD \(avd) as \(serial)")
        let pid = try spawn(sdk.emulator, arguments)
        try provenance.register(StartedEmulatorRecord(serial: serial, avd: avd, pid: pid))
        try await waitForBoot(serial: serial)
        return BootedDevice(udid: serial, name: avd)
    }

    /// Done when `sys.boot_completed` is 1, `pm path android` answers, and the
    /// keyguard has been dismissed.
    public func waitForBoot(serial: String) async throws {
        let deadline = Date().addingTimeInterval(bootTimeout)
        while Date() < deadline {
            if (try? await adb.getprop(serial: serial, "sys.boot_completed")) == "1",
               let path = try? await adb.shell(serial: serial, "pm path android"), path.contains("package:") {
                _ = try? await adb.shell(serial: serial, "wm dismiss-keyguard")
                return
            }
            try await Task.sleep(for: .seconds(pollInterval))
        }
        throw GrantivaError.commandFailed(
            "\(serial) did not finish booting within \(Int(bootTimeout))s. Raise \(Self.bootTimeoutVariable) or check \(provenance.directory)/emulator-<port>.log.",
            1
        )
    }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `swift test --filter 'AndroidProvenanceTests|EmulatorManagerTests'`
Expected: all pass. If `testSelectDeviceBootsTheConfiguredAVDWhenNotRunning` fails on script order, align the script with the exact call order in `boot` (devices for the port, then the boot poll) and keep the assertions.

- [ ] **Step 7: Commit**

```bash
git add Sources/GrantivaCore/Android/AndroidProvenance.swift Sources/GrantivaCore/Android/EmulatorManager.swift Tests/GrantivaCoreTests/AndroidProvenanceTests.swift Tests/GrantivaCoreTests/EmulatorManagerTests.swift
git commit -m "Add emulator selection, boot, and the started-emulator ledger"
```

---

### Task 6: Grow the DevicePlatform protocol and thread it through the runner

**Files:**
- Modify: `Sources/GrantivaCore/Platform/DevicePlatform.swift`
- Modify: `Sources/GrantivaCore/Platform/IOSPlatform.swift`
- Modify: `Sources/GrantivaCore/Build/AppBinaryResolver.swift` (`ResolvedBinary.appID`)
- Modify: `Sources/GrantivaCore/Runner/LogStreamer.swift` (`start(executable:arguments:)`)
- Modify: `Sources/GrantivaCore/Runner/RunnerExecution.swift` (`Request.environment`)
- Modify: `Sources/GrantivaCore/Runner/RunnerSession.swift` (environment, orphan cleanup, no default platform)
- Modify: `Sources/GrantivaCore/Config/ProjectResolver.swift` (`ResolvedProject.android`)
- Test: `Tests/GrantivaCoreTests/IOSPlatformTests.swift`, `Tests/GrantivaCoreTests/RunnerSessionAppIdTests.swift`, `Tests/GrantivaCoreTests/LogStreamerTests.swift`

**Interfaces:**
- Produces, on `DevicePlatform`:
  - `func resolveBinary(_ path: String) async throws -> ResolvedBinary` (`ResolvedBinary` gains `public let appID: String?`, init parameter `appID: String? = nil`).
  - `func defaultDevice() async throws -> BootedDevice` (iOS: the booted simulator; used by `diff capture --no-build`).
  - `func screenshot(deviceID: String, to path: String) async throws` (iOS: `xcrun simctl io <udid> screenshot <path>`).
  - `func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand` with `public struct LogStreamCommand: Sendable, Equatable { public let executable: String; public let arguments: [String] }`.
  - `func runnerEnvironment(runnerHome: String) -> [String: String]` (iOS: `[:]`).
  - `func cleanupOrphans(deviceID: String) async` (iOS: no-op).
- `RunnerExecution.Request.environment: [String: String] = [:]`, passed to `ChildProcess.spawn(environment:)` when non-empty.
- `RunnerSession.run` and `runFlowFiles`: `platform:` loses its default; both call `platform.runnerEnvironment(runnerHome: runnerDir)` and, after the runner exits, `await platform.cleanupOrphans(deviceID:)` inside `runWithStatusBarCleanup`.
- `ResolvedProject.android: AndroidProject?` (new stored property, memberwise init parameter `android: AndroidProject? = nil`, last).
- `LogStreamer.start(executable:arguments:)`; the existing `start(udid:predicate:level:)` becomes a wrapper that builds the simctl arguments and calls it.

- [ ] **Step 1: Write the failing tests**

Add to `IOSPlatformTests.swift`:

```swift
    func testScreenshotUsesSimctlIO() async throws {
        let executor = ScriptedExecutor([.success("")])
        try await IOSPlatform(execute: executor.execute).screenshot(deviceID: "ABC", to: "/tmp/a b.png")
        XCTAssertEqual(executor.commands, ["xcrun simctl io 'ABC' screenshot '/tmp/a b.png'"])
    }

    func testLogStreamBuildsTheSimctlSpawnCommand() async throws {
        let command = try await IOSPlatform().logStream(deviceID: "ABC", appID: "com.example", filter: nil, level: "debug")
        XCTAssertEqual(command.executable, "/usr/bin/xcrun")
        XCTAssertEqual(command.arguments, [
            "simctl", "spawn", "ABC", "log", "stream", "--style", "compact",
            "--predicate", defaultLogPredicate(forBundleID: "com.example"), "--level", "debug",
        ])
        let explicit = try await IOSPlatform().logStream(deviceID: "ABC", appID: nil, filter: "subsystem == \"x\"", level: nil)
        XCTAssertEqual(explicit.arguments.suffix(2), ["--predicate", "subsystem == \"x\""])
        let none = try await IOSPlatform().logStream(deviceID: "ABC", appID: nil, filter: nil, level: nil)
        XCTAssertFalse(none.arguments.contains("--predicate"))
    }

    func testRunnerEnvironmentIsEmptyOnIOS() {
        XCTAssertEqual(IOSPlatform().runnerEnvironment(runnerHome: "/r"), [:])
    }

    func testResolveBinaryRejectsAnAPK() async {
        do {
            _ = try await IOSPlatform().resolveBinary("/tmp/app.apk")
            XCTFail("expected rejection")
        } catch {
            XCTAssertTrue("\(error)".contains(".app or .ipa"), "\(error)")
        }
    }
```

Add to `RunnerSessionAppIdTests.swift` (next to the argv-order test):

```swift
    func testRunnerEnvironmentComesFromThePlatform() {
        struct EnvPlatform: DevicePlatform {
            let platform: Platform = .android
            func bootDevice(named: String) async throws -> BootedDevice { fatalError() }
            func displayGeometry(deviceID: String) async throws -> DeviceGeometry { fatalError() }
            func build(_ request: PlatformBuildRequest) async throws -> BuildResult { fatalError() }
            func install(appID: String, productPath: String, deviceID: String) async throws {}
            func launch(appID: String, deviceID: String) async throws {}
            func terminate(appID: String, deviceID: String) async throws {}
            func uninstall(appID: String, deviceID: String) async throws {}
            func prepareForCapture(deviceID: String) async {}
            func restoreAfterCapture(deviceID: String) async {}
            func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { [] }
            func runnerTestArguments() -> [String] { [] }
            func resolveBinary(_ path: String) async throws -> ResolvedBinary { fatalError() }
            func defaultDevice() async throws -> BootedDevice { fatalError() }
            func screenshot(deviceID: String, to path: String) async throws {}
            func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand { fatalError() }
            func runnerEnvironment(runnerHome: String) -> [String: String] { ["MAESTRO_RUNNER_HOME": runnerHome] }
            func cleanupOrphans(deviceID: String) async {}
        }
        XCTAssertEqual(
            RunnerSession.runnerEnvironment(platform: EnvPlatform(), runnerDir: "/home/.grantiva/runner"),
            ["MAESTRO_RUNNER_HOME": "/home/.grantiva/runner"]
        )
    }
```

Add to `LogStreamerTests.swift`:

```swift
    func testStartWithExplicitExecutableStreamsItsOutputWithThePrefix() throws {
        let streamer = LogStreamer()
        try streamer.start(executable: "/bin/echo", arguments: ["hello from a fake log"])
        // Give the readability handler a moment, then stop; the assertion is
        // that start(executable:arguments:) exists and does not throw for a
        // real executable. Output goes to stderr and is not captured here.
        Thread.sleep(forTimeInterval: 0.2)
        streamer.stop()
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter 'IOSPlatformTests|RunnerSessionAppIdTests|LogStreamerTests'`
Expected: compile failures for the new members.

- [ ] **Step 3: Extend the protocol**

In `DevicePlatform.swift` add, before the protocol:

```swift
public struct LogStreamCommand: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}
```

And inside the protocol, after `runnerTestArguments()`:

```swift
    /// Validates a pre-built binary for this platform and reads its app ID.
    func resolveBinary(_ path: String) async throws -> ResolvedBinary
    /// The device a `--no-build` capture targets when none is named.
    func defaultDevice() async throws -> BootedDevice
    /// A full-screen PNG of the device, written to `path`.
    func screenshot(deviceID: String, to path: String) async throws
    /// The process that streams the app's logs. `filter` is the platform's
    /// own syntax (an NSPredicate on iOS, a logcat tag on Android).
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand
    /// Extra environment for the runner process.
    func runnerEnvironment(runnerHome: String) -> [String: String]
    /// Kills driver processes a crashed runner may have left on the device.
    func cleanupOrphans(deviceID: String) async
```

- [ ] **Step 4: Implement them on IOSPlatform**

```swift
    public func resolveBinary(_ path: String) async throws -> ResolvedBinary {
        let resolved = try AppBinaryResolver.resolve(path)
        return ResolvedBinary(appPath: resolved.appPath, tempDir: resolved.tempDir, appID: AppBinaryResolver.bundleId(from: resolved.appPath))
    }

    public func defaultDevice() async throws -> BootedDevice {
        let device = try await simulators.bootedDevice()
        return BootedDevice(udid: device.udid, name: device.name)
    }

    public func screenshot(deviceID: String, to path: String) async throws {
        _ = try await execute("xcrun simctl io \(shellQuoted(deviceID)) screenshot \(shellQuoted(path))")
    }

    public func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand {
        var args = ["simctl", "spawn", deviceID, "log", "stream", "--style", "compact"]
        let predicate = filter ?? appID.map(defaultLogPredicate(forBundleID:))
        if let predicate, !predicate.isEmpty {
            args += ["--predicate", predicate]
        }
        if let level, !level.isEmpty {
            args += ["--level", level]
        }
        return LogStreamCommand(executable: "/usr/bin/xcrun", arguments: args)
    }

    public func runnerEnvironment(runnerHome: String) -> [String: String] { [:] }

    public func cleanupOrphans(deviceID: String) async {}
```

In `AppBinaryResolver.swift`, `ResolvedBinary` gains `public let appID: String?` and `public init(appPath: String, tempDir: URL?, appID: String? = nil)`. Keep the two internal constructions unchanged (they take the default).

- [ ] **Step 5: Generalize LogStreamer**

Rename the body of `start(udid:predicate:level:)` into `public func start(executable: String, arguments: [String]) throws`, where `p.executableURL = URL(fileURLWithPath: executable)` and `p.arguments = arguments`. Then:

```swift
    public func start(udid: String, predicate: String?, level: String?) throws {
        var args = ["simctl", "spawn", udid, "log", "stream", "--style", "compact"]
        if let predicate, !predicate.isEmpty { args += ["--predicate", predicate] }
        if let level, !level.isEmpty { args += ["--level", level] }
        try start(executable: "/usr/bin/xcrun", arguments: args)
    }
```

- [ ] **Step 6: Thread environment and cleanup through the runner**

`RunnerExecution.Request`: add `var environment: [String: String] = [:]` after `expectedFlows`. In `run`, pass `environment: request.environment.isEmpty ? nil : request.environment` to `ChildProcess.spawn`.

`RunnerSession`: remove `= IOSPlatform()` from both `platform:` parameters. Add:

```swift
    static func runnerEnvironment(platform: any DevicePlatform, runnerDir: String) -> [String: String] {
        platform.runnerEnvironment(runnerHome: runnerDir)
    }
```

In both `run` and `runFlowFiles`, build the request with `environment: runnerEnvironment(platform: platform, runnerDir: runnerDir)`, and change the cleanup closure to:

```swift
            clear: { id in
                await platform.restoreAfterCapture(deviceID: id)
                await platform.cleanupOrphans(deviceID: id)
            }
```

Also, before `platform.prepareForCapture` in both paths, nothing else changes; crash recovery is the Android platform's own job inside `prepareForCapture`.

`ResolvedProject`: add `public let android: AndroidProject?` and the trailing init parameter `android: AndroidProject? = nil`. `resolve(...)` keeps producing `android: nil`.

- [ ] **Step 7: Build and run the suite**

Run: `swift build && swift test`
Expected: the whole suite passes. Callers of `RunnerSession.run`/`runFlowFiles` in RunCommand, CICommand, and DiffCommand already pass `platform:`.

- [ ] **Step 8: Commit**

```bash
git add Sources/GrantivaCore Tests/GrantivaCoreTests
git commit -m "Grow DevicePlatform with binary, device, screenshot, log, environment, and orphan hooks"
```

---

### Task 7: AndroidPlatform

**Files:**
- Create: `Sources/GrantivaCore/Android/AndroidPlatform.swift`
- Modify: `Sources/GrantivaCore/Platform/DevicePlatform.swift` (`DevicePlatformFactory.make` throws, takes `AndroidPlatform.Options`)
- Test: `Tests/GrantivaCoreTests/AndroidPlatformTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1 to 6.
- Produces: `AndroidPlatform.Options(allowDeviceSettings:headless:)`; `AndroidPlatform(sdk:adb:gradle:emulators:captureSettings:execute:options:environment:)` with `static func live(options:) throws -> AndroidPlatform`; `DevicePlatformFactory.make(_ platform: Platform, android: AndroidPlatform.Options = .init()) throws -> any DevicePlatform`.

Behavior, per spec section 3 and the protocol:
- `bootDevice(named:)`: an adb serial that appears in `adb devices` is used as is (state must be `device`, else an error naming the state); a serial that does not appear is an error; otherwise the name is an AVD name (empty means "unset") and goes to `EmulatorManager.selectDevice(configured:)`.
- `displayGeometry`: `wm size` and `wm density`; `scale = density / 160`.
- `build`: `GradleBuildRunner.build` from the current directory with `request.resolved.android ?? AndroidProject()`, `extraArgs: request.extraBuildSettings`, `javaHome: AndroidSDK.javaHome()`, `deviceABI: getprop ro.product.cpu.abi`.
- `install`/`launch`/`terminate`/`uninstall`: `ADB`.
- `prepareForCapture`: on a physical device without `allowDeviceSettings`, log "skipping demo mode and animation settings on physical device <serial>; pass --allow-device-settings to apply them" and return. Otherwise `restoreIfCrashed` then `prepare`; a thrown error is logged, never rethrown.
- `restoreAfterCapture`: `restore` unless skipped above.
- `runnerGlobalArguments`: `["--platform", "android", "--device", id, "--no-ansi", "--no-app-install"]` plus `["--app-file", apk]`. `runnerTestArguments`: `[]`.
- `resolveBinary`: the file must exist and end in `.apk`; app ID from `apkanalyzer manifest application-id <apk>`; a failure there leaves `appID` nil.
- `defaultDevice`: `selectDevice(configured: nil)`.
- `screenshot`: `ADB.screenshot`.
- `logStream`: `logcat -c` first; `uid` from `packageUID`; `LogStreamCommand(executable: adb.path, arguments: ["-s", id, "logcat", "--uid=<uid>", "-v", "time"] + (filter.map { ["-s", $0] } ?? []))`. No uid (app not installed) throws `invalidArgument` naming the app ID. `level` maps to a logcat priority suffix on the tag filter when both are given (`<tag>:<level>`); otherwise ignored.
- `runnerEnvironment`: `["MAESTRO_RUNNER_HOME": runnerHome, "ANDROID_HOME": sdk.root, "PATH": "<sdk>/platform-tools:<sdk>/emulator:" + existing PATH]`.
- `cleanupOrphans`: `am force-stop` both `ADB.uiAutomator2Packages`, then `removeAllForwards`; errors ignored.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import XCTest
@testable import GrantivaCore

final class AndroidPlatformTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("android-platform-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func platform(_ shell: ScriptedShell, options: AndroidPlatform.Options = .init()) -> AndroidPlatform {
        let sdk = AndroidSDK(root: "/sdk")
        let adb = ADB(path: sdk.adb, execute: shell.execute)
        return AndroidPlatform(
            sdk: sdk, adb: adb,
            gradle: GradleBuildRunner(execute: shell.execute),
            emulators: EmulatorManager(sdk: sdk, adb: adb, execute: shell.execute, spawn: { _, _ in 1 },
                                       provenance: AndroidProvenance(directory: scratch.path), bootTimeout: 1, pollInterval: 0.01),
            captureSettings: AndroidCaptureSettings(adb: adb, stateDirectory: scratch.path),
            execute: shell.execute,
            options: options,
            environment: ["PATH": "/usr/bin", "JAVA_HOME": "/nonexistent"]
        )
    }

    func testRunnerArgumentsForAndroid() {
        let p = platform(ScriptedShell())
        XCTAssertEqual(
            p.runnerGlobalArguments(deviceID: "emulator-5554", appFile: "/b/app.apk"),
            ["--platform", "android", "--device", "emulator-5554", "--no-ansi", "--no-app-install", "--app-file", "/b/app.apk"]
        )
        XCTAssertEqual(p.runnerTestArguments(), [])
        let env = p.runnerEnvironment(runnerHome: "/home/.grantiva/runner")
        XCTAssertEqual(env["MAESTRO_RUNNER_HOME"], "/home/.grantiva/runner")
        XCTAssertEqual(env["ANDROID_HOME"], "/sdk")
        XCTAssertEqual(env["PATH"], "/sdk/platform-tools:/sdk/emulator:/usr/bin")
    }

    func testBootDeviceWithARunningSerialUsesItDirectly() async throws {
        let shell = ScriptedShell([
            .success("List of devices attached\nemulator-5556 device"),
            .success("Pixel_8_API_35\nOK"),
        ])
        let booted = try await platform(shell).bootDevice(named: "emulator-5556")
        XCTAssertEqual(booted, BootedDevice(udid: "emulator-5556", name: "Pixel_8_API_35"))
    }

    func testBootDeviceWithAnOfflineSerialFailsNamingTheState() async {
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5556 offline")])
        do {
            _ = try await platform(shell).bootDevice(named: "emulator-5556")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("emulator-5556 is offline"), "\(error)")
        }
    }

    func testBootDeviceWithAnUnknownSerialFails() async {
        let shell = ScriptedShell([.success("List of devices attached")])
        do {
            _ = try await platform(shell).bootDevice(named: "R58M1234ABC")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("R58M1234ABC"), "\(error)")
            XCTAssertTrue("\(error)".contains("adb devices"), "\(error)")
        }
    }

    func testDisplayGeometryDerivesScaleFromDensity() async throws {
        let shell = ScriptedShell([.success("Physical size: 1080x2400"), .success("Physical density: 420")])
        let geometry = try await platform(shell).displayGeometry(deviceID: "emulator-5554")
        XCTAssertEqual(geometry, DeviceGeometry(pixelWidth: 1080, pixelHeight: 2400, scale: 2.625))
    }

    func testPrepareIsSkippedOnPhysicalDevicesUnlessAllowed() async {
        let shell = ScriptedShell()
        await platform(shell).prepareForCapture(deviceID: "R58M1234ABC")
        await platform(shell).restoreAfterCapture(deviceID: "R58M1234ABC")
        XCTAssertTrue(shell.commands.isEmpty)

        let allowed = ScriptedShell()
        allowed.fallback = "1"
        await platform(allowed, options: .init(allowDeviceSettings: true)).prepareForCapture(deviceID: "R58M1234ABC")
        XCTAssertFalse(allowed.commands.isEmpty)
    }

    func testPrepareRestoresACrashedRunFirst() async throws {
        let state = AndroidCaptureSettings.statePath(serial: "emulator-5554", directory: scratch.path)
        try JSONEncoder().encode(["global/window_animation_scale": "1.0"] as [String: String?]).write(to: URL(fileURLWithPath: state))
        let shell = ScriptedShell()
        shell.fallback = "1"
        await platform(shell).prepareForCapture(deviceID: "emulator-5554")
        XCTAssertTrue(shell.commands[0].contains("command exit"), "the crash restore runs before anything else: \(shell.commands[0])")
        XCTAssertTrue(shell.commands.contains { $0.contains("settings put global window_animation_scale 1.0") })
    }

    func testResolveBinaryRequiresAnExistingAPKAndReadsItsID() async throws {
        let apk = scratch.appendingPathComponent("app.apk").path
        try Data().write(to: URL(fileURLWithPath: apk))
        let shell = ScriptedShell([.success("com.example.app\n")])
        let resolved = try await platform(shell).resolveBinary(apk)
        XCTAssertEqual(resolved.appPath, apk)
        XCTAssertEqual(resolved.appID, "com.example.app")
        XCTAssertEqual(shell.commands, ["'/sdk/cmdline-tools/latest/bin/apkanalyzer' manifest application-id \(shellQuoted(apk))"])

        do {
            _ = try await platform(ScriptedShell()).resolveBinary(scratch.appendingPathComponent("Demo.app").path)
            XCTFail("expected rejection")
        } catch {
            XCTAssertTrue("\(error)".contains(".apk"), "\(error)")
        }
    }

    func testLogStreamClearsThenFiltersByUID() async throws {
        let shell = ScriptedShell([.success(""), .success("package:com.example.app uid:10123")])
        let command = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example.app", filter: "MyTag", level: nil)
        XCTAssertEqual(shell.commands[0], "'/sdk/platform-tools/adb' -s 'emulator-5554' logcat -c")
        XCTAssertEqual(command.executable, "/sdk/platform-tools/adb")
        XCTAssertEqual(command.arguments, ["-s", "emulator-5554", "logcat", "--uid=10123", "-v", "time", "-s", "MyTag"])
    }

    func testLogStreamWithoutAnInstalledAppFails() async {
        let shell = ScriptedShell([.success(""), .success("")])
        do {
            _ = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example.app", filter: nil, level: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("com.example.app"), "\(error)")
        }
    }

    func testCleanupOrphansForceStopsUIA2AndRemovesForwards() async {
        let shell = ScriptedShell()
        await platform(shell).cleanupOrphans(deviceID: "emulator-5554")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'io.appium.uiautomator2.server'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'io.appium.uiautomator2.server.test'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove-all",
        ])
    }

    func testBuildReadsTheDeviceABIAndUsesTheResolvedModuleAndVariant() async throws {
        let metadataDir = scratch.appendingPathComponent("mobile/build/outputs/apk/free/debug")
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        try """
        {"applicationId":"com.example.free","variantName":"freeDebug","elements":[{"type":"SINGLE","filters":[],"outputFile":"mobile-free-debug.apk"}]}
        """.write(to: metadataDir.appendingPathComponent("output-metadata.json"), atomically: true, encoding: .utf8)
        let shell = ScriptedShell([.success("arm64-v8a"), .failure(GrantivaError.commandFailed("no java", 1)), .success("BUILD SUCCESSFUL")])
        let request = PlatformBuildRequest(
            config: GrantivaConfig(platform: .android, android: AndroidProject()),
            resolved: ResolvedProject(android: AndroidProject(module: "mobile", variant: "freeDebug", buildArgs: ["-Px=1"])),
            deviceID: "emulator-5554",
            extraBuildSettings: ["-Px=1"]
        )
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(scratch.path)
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        let result = try await platform(shell).build(request)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.applicationId, "com.example.free")
        XCTAssertTrue(shell.commands[2].contains("':mobile:assembleFreeDebug' --console=plain '-Px=1'"), shell.commands[2])
    }

    func testFactoryMakesAndroidWhenAnSDKExists() throws {
        XCTAssertEqual(try DevicePlatformFactory.make(.ios).platform, .ios)
        // `.android` needs a real SDK on this machine; the error path is what
        // every machine can check.
        if AndroidSDK.locate() == nil {
            XCTAssertThrowsError(try DevicePlatformFactory.make(.android))
        } else {
            XCTAssertEqual(try DevicePlatformFactory.make(.android).platform, .android)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter AndroidPlatformTests`
Expected: compile failure.

- [ ] **Step 3: Write AndroidPlatform.swift**

```swift
import Foundation

public struct AndroidPlatform: DevicePlatform {
    public struct Options: Sendable, Equatable {
        public var allowDeviceSettings: Bool
        public var headless: Bool

        public init(allowDeviceSettings: Bool = false, headless: Bool = false) {
            self.allowDeviceSettings = allowDeviceSettings
            self.headless = headless
        }
    }

    public let platform: Platform = .android
    private let sdk: AndroidSDK
    private let adb: ADB
    private let gradle: GradleBuildRunner
    private let emulators: EmulatorManager
    private let captureSettings: AndroidCaptureSettings
    private let execute: @Sendable (String) async throws -> String
    private let options: Options
    private let environment: [String: String]

    public init(
        sdk: AndroidSDK,
        adb: ADB,
        gradle: GradleBuildRunner,
        emulators: EmulatorManager,
        captureSettings: AndroidCaptureSettings,
        execute: @escaping @Sendable (String) async throws -> String = { try await shell($0) },
        options: Options = Options(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.sdk = sdk
        self.adb = adb
        self.gradle = gradle
        self.emulators = emulators
        self.captureSettings = captureSettings
        self.execute = execute
        self.options = options
        self.environment = environment
    }

    /// The real thing: throws when no SDK is installed.
    public static func live(options: Options = Options()) throws -> AndroidPlatform {
        let sdk = try AndroidSDK.require()
        let adb = ADB(path: sdk.adb)
        return AndroidPlatform(
            sdk: sdk, adb: adb, gradle: GradleBuildRunner(),
            emulators: EmulatorManager(sdk: sdk, adb: adb, headless: options.headless),
            captureSettings: AndroidCaptureSettings(adb: adb),
            options: options
        )
    }

    static func isPhysical(_ serial: String) -> Bool { !serial.hasPrefix("emulator-") }

    // MARK: Devices

    /// An attached serial is used as is; otherwise the name must be an AVD,
    /// which `selectDevice` uses or boots. Anything else is an error that
    /// names both lists, since a serial and an AVD name look alike.
    public func bootDevice(named nameOrID: String) async throws -> BootedDevice {
        let devices = try await adb.devices()
        if let match = devices.first(where: { $0.serial == nameOrID }) {
            guard match.isUsable else {
                throw GrantivaError.invalidArgument(
                    "\(nameOrID) is \(match.state). Reconnect it, accept the USB debugging prompt, or pick another device."
                )
            }
            let name = match.isEmulator ? ((try? await adb.avdName(serial: match.serial)) ?? match.serial) : match.serial
            return BootedDevice(udid: match.serial, name: name)
        }
        if nameOrID.isEmpty {
            return try await emulators.selectDevice(configured: nil)
        }
        let avds = try await emulators.listAVDs()
        guard avds.contains(nameOrID) else {
            throw GrantivaError.invalidArgument(
                "No attached device has the serial \"\(nameOrID)\" (see `adb devices`) and no AVD has that name "
                    + "(see `emulator -list-avds`). AVDs: \(avds.isEmpty ? "(none)" : avds.joined(separator: ", "))."
            )
        }
        return try await emulators.selectDevice(configured: nameOrID)
    }

    public func defaultDevice() async throws -> BootedDevice {
        try await emulators.selectDevice(configured: nil)
    }

    public func displayGeometry(deviceID: String) async throws -> DeviceGeometry {
        let size = try await adb.displaySize(serial: deviceID)
        let density = try await adb.density(serial: deviceID)
        return DeviceGeometry(pixelWidth: size.width, pixelHeight: size.height, scale: Double(density) / 160)
    }

    // MARK: Build and install

    public func build(_ request: PlatformBuildRequest) async throws -> BuildResult {
        let android = request.resolved.android ?? AndroidProject()
        let abi = try await adb.getprop(serial: request.deviceID, "ro.product.cpu.abi")
        let javaHome = await AndroidSDK.javaHome(environment: environment, execute: execute)
        return try await gradle.build(
            projectRoot: FileManager.default.currentDirectoryPath,
            module: android.module, variant: android.variant,
            extraArgs: request.extraBuildSettings, javaHome: javaHome, deviceABI: abi
        )
    }

    public func install(appID: String, productPath: String, deviceID: String) async throws {
        try await adb.install(serial: deviceID, apk: productPath, applicationId: appID)
    }

    public func launch(appID: String, deviceID: String) async throws {
        try await adb.launch(serial: deviceID, applicationId: appID)
    }

    public func terminate(appID: String, deviceID: String) async throws {
        try await adb.forceStop(serial: deviceID, applicationId: appID)
    }

    public func uninstall(appID: String, deviceID: String) async throws {
        try await adb.uninstall(serial: deviceID, applicationId: appID)
    }

    public func resolveBinary(_ path: String) async throws -> ResolvedBinary {
        let absolute = (path as NSString).standardizingPath
        guard FileManager.default.fileExists(atPath: absolute) else {
            throw GrantivaError.appNotFound(absolute)
        }
        guard absolute.hasSuffix(".apk") else {
            throw GrantivaError.invalidBinary("Expected an .apk file for Android, got: \"\(URL(fileURLWithPath: absolute).lastPathComponent)\"")
        }
        let id = try? await execute("\(shellQuoted(sdk.apkanalyzer)) manifest application-id \(shellQuoted(absolute))")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ResolvedBinary(appPath: absolute, tempDir: nil, appID: (id?.isEmpty ?? true) ? nil : id)
    }

    // MARK: Capture state

    private func settingsAllowed(_ serial: String) -> Bool {
        if Self.isPhysical(serial), !options.allowDeviceSettings {
            GrantivaLog.logger.info(
                "skipping demo mode and animation settings on physical device \(serial); pass --allow-device-settings to apply them"
            )
            return false
        }
        return true
    }

    public func prepareForCapture(deviceID: String) async {
        guard settingsAllowed(deviceID) else { return }
        _ = await captureSettings.restoreIfCrashed(serial: deviceID)
        do {
            try await captureSettings.prepare(serial: deviceID)
        } catch {
            GrantivaLog.logger.warning("could not apply capture settings on \(deviceID): \(error)")
        }
    }

    public func restoreAfterCapture(deviceID: String) async {
        guard Self.isPhysical(deviceID) == false || options.allowDeviceSettings else { return }
        await captureSettings.restore(serial: deviceID)
    }

    public func screenshot(deviceID: String, to path: String) async throws {
        try await adb.screenshot(serial: deviceID, to: path)
    }

    // MARK: Logs

    public func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand {
        _ = try? await execute(adb.line(deviceID, "logcat -c"))
        guard let appID else {
            throw GrantivaError.invalidArgument("--logs on Android needs the application ID to filter logcat; pass --application-id.")
        }
        guard let uid = try await adb.packageUID(serial: deviceID, applicationId: appID) else {
            throw GrantivaError.invalidArgument("\(appID) is not installed on \(deviceID), so its logs cannot be streamed.")
        }
        var args = ["-s", deviceID, "logcat", "--uid=\(uid)", "-v", "time"]
        if let filter, !filter.isEmpty {
            let tag = (level?.isEmpty == false) ? "\(filter):\(level!.prefix(1).uppercased())" : filter
            args += ["-s", tag]
        }
        return LogStreamCommand(executable: adb.path, arguments: args)
    }

    // MARK: Runner

    public func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] {
        var args = ["--platform", "android", "--device", deviceID, "--no-ansi", "--no-app-install"]
        if let appFile { args += ["--app-file", appFile] }
        return args
    }

    public func runnerTestArguments() -> [String] { [] }

    public func runnerEnvironment(runnerHome: String) -> [String: String] {
        let path = environment["PATH"].map { ":" + $0 } ?? ""
        return [
            "MAESTRO_RUNNER_HOME": runnerHome,
            "ANDROID_HOME": sdk.root,
            "PATH": "\(sdk.root)/platform-tools:\(sdk.root)/emulator\(path)",
        ]
    }

    public func cleanupOrphans(deviceID: String) async {
        for package in ADB.uiAutomator2Packages {
            _ = try? await adb.forceStop(serial: deviceID, applicationId: package)
        }
        _ = try? await adb.removeAllForwards(serial: deviceID)
    }
}
```

- [ ] **Step 4: Make the factory throw and take options**

In `DevicePlatform.swift`:

```swift
public enum DevicePlatformFactory {
    public static func make(_ platform: Platform, android: AndroidPlatform.Options = AndroidPlatform.Options()) throws -> any DevicePlatform {
        switch platform {
        case .ios:
            return IOSPlatform()
        case .android:
            return try AndroidPlatform.live(options: android)
        }
    }
}
```

Update `InjectedDevicePlatform.make` in `Sources/GrantivaCLI/Options.swift` to `func make(_ platform: Platform, android: AndroidPlatform.Options = .init()) throws -> any DevicePlatform { try value ?? DevicePlatformFactory.make(platform, android: android) }` and add `try` at its six call sites (RunCommand, CICommand, BuildOnlyCommand, InstallCommand, CaptureCommand, CompareCommand). `MCPServer.swift:22` and `DriverCommand.swift:110` construct `IOSPlatform()` directly or call the factory with `.ios`; add `try` where the compiler asks.

- [ ] **Step 5: Build and run**

Run: `swift build && swift test --filter 'AndroidPlatformTests|IOSPlatformTests|PlatformOptionTests'`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Sources Tests
git commit -m "Add AndroidPlatform"
```

---

### Task 8: Target flags and command wiring

**Files:**
- Create: `Sources/GrantivaCLI/TargetOptions.swift`
- Create: `Tests/GrantivaCLITests/Support/FakeDevicePlatform.swift`
- Modify: `Sources/GrantivaCLI/Options.swift` (lift the Android gate; `InjectedDevicePlatform.make` throws and takes options)
- Modify: `Sources/GrantivaCLI/RunCommand.swift`, `CICommand.swift`, `BuildCommand.swift`, `DiffCommand.swift`
- Test: `Tests/GrantivaCLITests/TargetOptionsTests.swift`, `Tests/GrantivaCLITests/AndroidCommandTests.swift`, `Tests/GrantivaCLITests/PlatformOptionTests.swift`, `Tests/GrantivaCLITests/RunCommandTests.swift`

**Interfaces:**
- Consumes: `DevicePlatform` (Task 6), `AndroidPlatform.Options` (Task 7), `ResolvedProject.android` (Task 6), `DeviceID.validate`.
- Produces: `TargetOptions: ParsableArguments` with the ten flags listed in Global Constraints (`--scheme`, `--simulator`, `--bundle-id`, `--module`, `--variant`, `--application-id`, `--emulator`, `--device`, `--allow-device-settings`, `--headless`); `checkFlags(for:derivedDataPath:logsPredicate:logsTag:) throws`; `androidOptions: AndroidPlatform.Options`; `resolve(platform:config:skipBuild:appID:) async throws -> ResolvedProject`; `static resolveAndroid(...)`; `extraBuildSettings(platform:derivedDataPath:resolved:) -> [String]`; `static appIDMessage(for: Platform) -> String`.
- Every command that had `--scheme`/`--simulator`/`--bundle-id` as its own options now declares `@OptionGroup var target: TargetOptions`. The flag names and help are unchanged for iOS users.

- [ ] **Step 1: Write the fake platform for command tests**

```swift
import Foundation
@testable import GrantivaCLI
import GrantivaCore

/// Records every call. Device-level results are canned so a command can be
/// driven to a chosen point without a simulator or emulator.
final class FakeDevicePlatform: DevicePlatform, @unchecked Sendable {
    let platform: Platform
    private let lock = NSLock()
    private var recorded: [String] = []
    var calls: [String] { lock.withLock { recorded } }
    private func record(_ call: String) { lock.withLock { recorded.append(call) } }

    var bootedName = "Fake"
    var bootedID = "emulator-5598"
    var buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: "/fake/app.apk", applicationId: "com.fake.built")

    init(platform: Platform) { self.platform = platform }

    func bootDevice(named nameOrID: String) async throws -> BootedDevice {
        record("bootDevice(\(nameOrID))"); return BootedDevice(udid: bootedID, name: bootedName)
    }
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry {
        record("displayGeometry(\(deviceID))"); return DeviceGeometry(pixelWidth: 1080, pixelHeight: 2400, scale: 2.625)
    }
    func build(_ request: PlatformBuildRequest) async throws -> BuildResult {
        record("build(module=\(request.resolved.android?.module ?? "-"),variant=\(request.resolved.android?.variant ?? "-"),args=\(request.extraBuildSettings))"); return buildResult
    }
    func install(appID: String, productPath: String, deviceID: String) async throws { record("install(\(appID),\(productPath))") }
    func launch(appID: String, deviceID: String) async throws { record("launch(\(appID))") }
    func terminate(appID: String, deviceID: String) async throws { record("terminate(\(appID))") }
    func uninstall(appID: String, deviceID: String) async throws { record("uninstall(\(appID))") }
    func prepareForCapture(deviceID: String) async { record("prepare") }
    func restoreAfterCapture(deviceID: String) async { record("restore") }
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { ["--platform", platform.rawValue, "--device", deviceID] }
    func runnerTestArguments() -> [String] { [] }
    func resolveBinary(_ path: String) async throws -> ResolvedBinary {
        record("resolveBinary(\(path))"); return ResolvedBinary(appPath: path, tempDir: nil, appID: "com.fake.binary")
    }
    func defaultDevice() async throws -> BootedDevice { record("defaultDevice"); return BootedDevice(udid: bootedID, name: bootedName) }
    func screenshot(deviceID: String, to path: String) async throws { record("screenshot") }
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand {
        record("logStream(\(appID ?? "-"),\(filter ?? "-"))"); return LogStreamCommand(executable: "/bin/echo", arguments: ["fake log"])
    }
    func runnerEnvironment(runnerHome: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async { record("cleanupOrphans") }
}
```

- [ ] **Step 2: Write the failing TargetOptions tests**

```swift
import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class TargetOptionsTests: XCTestCase {
    func testIOSFlagsAreRejectedOnAndroidAndViceVersa() throws {
        let scheme = try TargetOptions.parse(["--scheme", "Demo"])
        XCTAssertThrowsError(try scheme.checkFlags(for: .android, derivedDataPath: nil)) { error in
            XCTAssertTrue("\(error)".contains("--scheme"), "\(error)")
            XCTAssertTrue("\(error)".contains("iOS"), "\(error)")
        }
        XCTAssertNoThrow(try scheme.checkFlags(for: .ios, derivedDataPath: nil))

        let module = try TargetOptions.parse(["--module", "app", "--device", "emulator-5554"])
        XCTAssertThrowsError(try module.checkFlags(for: .ios, derivedDataPath: nil)) { error in
            XCTAssertTrue("\(error)".contains("--module"), "\(error)")
        }
        XCTAssertNoThrow(try module.checkFlags(for: .android, derivedDataPath: nil))

        XCTAssertThrowsError(try TargetOptions.parse([]).checkFlags(for: .android, derivedDataPath: "/dd")) { error in
            XCTAssertTrue("\(error)".contains("--derived-data-path"), "\(error)")
        }
        XCTAssertThrowsError(try TargetOptions.parse([]).checkFlags(for: .ios, derivedDataPath: nil, logsTag: "T")) { error in
            XCTAssertTrue("\(error)".contains("--logs-tag"), "\(error)")
        }
        XCTAssertThrowsError(try TargetOptions.parse([]).checkFlags(for: .android, derivedDataPath: nil, logsPredicate: "p")) { error in
            XCTAssertTrue("\(error)".contains("--logs-predicate"), "\(error)")
        }
    }

    func testDeviceSerialIsValidated() throws {
        XCTAssertThrowsError(try TargetOptions.parse(["--device", "not a serial"]).checkFlags(for: .android, derivedDataPath: nil))
    }

    func testAndroidResolutionMergesFlagsOverConfigOverBinary() async throws {
        let config = GrantivaConfig(
            screens: [.init(name: "Home", path: .launch)], platform: .android,
            android: AndroidProject(module: "mobile", variant: "release", applicationId: "com.cfg", emulator: "Cfg_AVD", buildArgs: ["-Pa=1"])
        )
        let fromConfig = try await TargetOptions.parse([]).resolve(platform: .android, config: config, skipBuild: false, appID: "com.bin")
        XCTAssertEqual(fromConfig.android?.module, "mobile")
        XCTAssertEqual(fromConfig.android?.variant, "release")
        XCTAssertEqual(fromConfig.bundleId, "com.cfg")
        XCTAssertEqual(fromConfig.simulator, "Cfg_AVD")
        XCTAssertEqual(fromConfig.buildSettings, ["-Pa=1"])
        XCTAssertNil(fromConfig.scheme)
        XCTAssertEqual(fromConfig.screens.count, 1)

        let flags = try TargetOptions.parse(["--module", "app", "--variant", "debug", "--application-id", "com.flag", "--device", "emulator-5556"])
        let fromFlags = try await flags.resolve(platform: .android, config: config, skipBuild: false, appID: "com.bin")
        XCTAssertEqual(fromFlags.android?.module, "app")
        XCTAssertEqual(fromFlags.android?.variant, "debug")
        XCTAssertEqual(fromFlags.bundleId, "com.flag")
        XCTAssertEqual(fromFlags.simulator, "emulator-5556", "--device wins over the configured emulator")

        let bare = try await TargetOptions.parse([]).resolve(platform: .android, config: nil, skipBuild: true, appID: "com.bin")
        XCTAssertEqual(bare.android?.module, "app")
        XCTAssertEqual(bare.android?.variant, "debug")
        XCTAssertEqual(bare.bundleId, "com.bin")
        XCTAssertEqual(bare.simulator, "", "no emulator configured means auto-select")
    }

    func testExtraBuildSettingsUseGradleArgsOnAndroid() async throws {
        let resolved = ResolvedProject(buildSettings: ["-Pa=1"], android: AndroidProject())
        XCTAssertEqual(try TargetOptions.parse([]).extraBuildSettings(platform: .android, derivedDataPath: nil, resolved: resolved), ["-Pa=1"])
        let ios = ResolvedProject(buildSettings: ["-quiet"])
        XCTAssertEqual(try TargetOptions.parse([]).extraBuildSettings(platform: .ios, derivedDataPath: "/dd", resolved: ios), ["-quiet", "-derivedDataPath", "/dd"])
    }

    func testAppIDMessagesNameThePlatformsFlag() {
        XCTAssertTrue(TargetOptions.appIDMessage(for: .ios).contains("--bundle-id"))
        XCTAssertTrue(TargetOptions.appIDMessage(for: .android).contains("--application-id"))
        XCTAssertTrue(TargetOptions.appIDMessage(for: .android).contains("grantiva-android.yml"))
    }
}
```

- [ ] **Step 3: Write the failing command tests**

`Tests/GrantivaCLITests/AndroidCommandTests.swift`:

```swift
import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class AndroidCommandTests: XCTestCase {
    private var dir: URL!
    private var previousDirectory: String!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("android-cmd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        module: app
        emulator: Pixel_8_API_35
        flows:
          - smoke.yaml
        """.write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        try "appId: com.placeholder\n---\n- launchApp\n".write(to: dir.appendingPathComponent("smoke.yaml"), atomically: true, encoding: .utf8)
        previousDirectory = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        unsetenv("GRANTIVA_PLATFORM")
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(previousDirectory)
        try? FileManager.default.removeItem(at: dir)
    }

    private let stubRunner = RunnerManager(ensureAvailable: {}, runnerPath: { "/usr/bin/false" }, runnerDir: { NSTemporaryDirectory() })

    func testRunOnAndroidRejectsAnIOSFlagBeforeTouchingADevice() async throws {
        var command = try RunCommand.parse(["--no-build", "--scheme", "Demo"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("--scheme"), "\(error)")
            XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
        }
    }

    func testRunOnAndroidWithoutAnApplicationIDFailsAfterBootWithTheAndroidMessage() async throws {
        var command = try RunCommand.parse(["--no-build"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("--application-id"), "\(error)")
            XCTAssertEqual(fake.calls.first, "bootDevice(Pixel_8_API_35)", "\(fake.calls)")
        }
    }

    /// Review Focus 2: `--logs` on Android streams through the platform, never simctl.
    func testRunOnAndroidWithLogsStreamsThroughThePlatform() async throws {
        var command = try RunCommand.parse(["--no-build", "--application-id", "com.fake", "--logs", "--logs-tag", "Fake", "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        // The stub runner is /usr/bin/false, so the run fails at the runner;
        // everything before it is what this test pins.
        _ = try? await command.run()
        XCTAssertTrue(fake.calls.contains("logStream(com.fake,Fake)"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("screenshot"), "the failure screenshot goes through the platform: \(fake.calls)")
        XCTAssertTrue(fake.calls.contains("cleanupOrphans"), "\(fake.calls)")
    }

    func testBuildInstallOnAndroidUsesTheBuiltApplicationID() async throws {
        var command = try InstallCommand.parse(["--no-launch", "--module", "mobile", "--variant", "freeDebug"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
        } catch {
            // The data-container step is unsupported on Android and throws after install.
            XCTAssertTrue("\(error)".contains("data container"), "\(error)")
        }
        XCTAssertTrue(fake.calls.contains("build(module=mobile,variant=freeDebug,args=[])"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("install(com.fake.built,/fake/app.apk)"), "\(fake.calls)")
    }

    func testAppFileAPKGoesThroughThePlatformResolver() async throws {
        let apk = dir.appendingPathComponent("prebuilt.apk").path
        try Data().write(to: URL(fileURLWithPath: apk))
        var command = try InstallCommand.parse(["--no-launch", "--app-file", apk])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        _ = try? await command.run()
        XCTAssertTrue(fake.calls.contains("resolveBinary(\(apk))"), "\(fake.calls)")
        XCTAssertTrue(fake.calls.contains("install(com.fake.binary,\(apk))"), "\(fake.calls)")
    }
}
```

Update `PlatformOptionTests.swift`: replace the two `...FailsCleanlyUntilAndroidShips` tests and the `androidNotYet` constant with:

```swift
    func testGradleOnlyDirectoryResolvesAndroidWithNilConfig() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "".write(to: dir.appendingPathComponent("settings.gradle.kts"), atomically: true, encoding: .utf8)
        let (platform, config) = try PlatformOptions.parse([]).loadConfig(directory: dir, environment: [:])
        XCTAssertEqual(platform, .android)
        XCTAssertNil(config)
    }

    func testAndroidConfigOnlyDirectoryLoadsTheAndroidConfig() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "module: mobile\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let (platform, config) = try PlatformOptions.parse([]).loadConfig(directory: dir, environment: [:])
        XCTAssertEqual(platform, .android)
        XCTAssertEqual(config?.android?.module, "mobile")
    }
```

In `RunCommandTests.swift`, delete `testFailureScreenshotCommandQuotesHostilePathAndUDID` (the quoting now lives in `IOSPlatform.screenshot`, pinned in Task 6).

- [ ] **Step 4: Run to verify failure**

Run: `swift test --filter 'TargetOptionsTests|AndroidCommandTests|PlatformOptionTests'`
Expected: compile failure.

- [ ] **Step 5: Write TargetOptions.swift**

```swift
import ArgumentParser
import Foundation
import GrantivaCore

/// The flags that name what to build and where to run it, for both
/// platforms. A command declares this once; which half applies is decided by
/// the resolved platform, and a flag from the other half is an error.
struct TargetOptions: ParsableArguments {
    @Option(name: .long, help: "Scheme to build (iOS)")
    var scheme: String?

    @Option(name: .long, help: "Simulator name or UDID (iOS)")
    var simulator: String?

    @Option(name: .long, help: "Bundle identifier (iOS)")
    var bundleId: String?

    @Option(name: .long, help: "Gradle module to assemble (Android; default app)")
    var module: String?

    @Option(name: .long, help: "Gradle build variant, e.g. debug or freeDebug (Android; default debug)")
    var variant: String?

    @Option(name: .long, help: "Application ID (Android; read from the build or the APK when omitted)")
    var applicationId: String?

    @Option(name: .long, help: "AVD name to use, booting it if needed (Android)")
    var emulator: String?

    @Option(name: .long, help: "adb serial of an attached emulator or physical device (Android)")
    var device: String?

    @Flag(name: .long, help: "Apply demo mode and animation settings on a physical device too (Android)")
    var allowDeviceSettings = false

    @Flag(name: .long, help: "Boot an emulator without a window (Android)")
    var headless = false

    var androidOptions: AndroidPlatform.Options {
        AndroidPlatform.Options(allowDeviceSettings: allowDeviceSettings, headless: headless)
    }

    /// Rejects flags that belong to the other platform, naming the flag.
    func checkFlags(for platform: Platform, derivedDataPath: String?, logsPredicate: String? = nil, logsTag: String? = nil) throws {
        let iosFlags: [(String, Bool)] = [
            ("--scheme", scheme != nil), ("--simulator", simulator != nil), ("--bundle-id", bundleId != nil),
            ("--derived-data-path", derivedDataPath != nil), ("--logs-predicate", logsPredicate != nil),
        ]
        let androidFlags: [(String, Bool)] = [
            ("--module", module != nil), ("--variant", variant != nil), ("--application-id", applicationId != nil),
            ("--emulator", emulator != nil), ("--device", device != nil), ("--allow-device-settings", allowDeviceSettings),
            ("--headless", headless), ("--logs-tag", logsTag != nil),
        ]
        let wrong = platform == .ios ? androidFlags : iosFlags
        if let offending = wrong.first(where: { $0.1 })?.0 {
            let owner = platform == .ios ? "an Android" : "an iOS"
            throw GrantivaError.invalidArgument(
                "\(offending) is \(owner) option, but this is \(platform == .ios ? "an iOS" : "an Android") project "
                    + "(resolved from --platform, GRANTIVA_PLATFORM, the config file, or the directory)."
            )
        }
        if let device {
            _ = try DeviceID.validate(device, flag: "--device")
        }
    }

    func resolve(platform: Platform, config: GrantivaConfig?, skipBuild: Bool, appID: String?) async throws -> ResolvedProject {
        switch platform {
        case .ios:
            return try await ResolvedProject.resolve(
                schemeFlag: scheme, simulatorFlag: simulator, bundleIdFlag: bundleId, config: config,
                skipBuild: skipBuild, appBundleId: appID
            )
        case .android:
            return Self.resolveAndroid(
                moduleFlag: module, variantFlag: variant, applicationIdFlag: applicationId,
                emulatorFlag: emulator, deviceFlag: device, config: config, appID: appID
            )
        }
    }

    /// Flags over config over the binary's manifest. No Gradle parsing and no
    /// detection cache: a missing module or variant is the default.
    static func resolveAndroid(
        moduleFlag: String?, variantFlag: String?, applicationIdFlag: String?,
        emulatorFlag: String?, deviceFlag: String?, config: GrantivaConfig?, appID: String?
    ) -> ResolvedProject {
        let configured = config?.android ?? AndroidProject()
        let applicationId = applicationIdFlag ?? configured.applicationId ?? appID
        let android = AndroidProject(
            module: moduleFlag ?? configured.module,
            variant: variantFlag ?? configured.variant,
            applicationId: applicationId,
            emulator: emulatorFlag ?? configured.emulator,
            systemImage: configured.systemImage,
            buildArgs: configured.buildArgs
        )
        return ResolvedProject(
            bundleId: applicationId,
            buildSettings: configured.buildArgs,
            simulator: deviceFlag ?? android.emulator ?? "",
            screens: config?.screens ?? [],
            flows: config?.flows ?? [],
            diff: config?.diff ?? .init(),
            a11y: config?.a11y ?? .init(),
            android: android
        )
    }

    func extraBuildSettings(platform: Platform, derivedDataPath: String?, resolved: ResolvedProject) -> [String] {
        switch platform {
        case .ios:
            return BuildOptions.xcodeBuildSettings(derivedDataPath: derivedDataPath, merging: resolved.buildSettings)
        case .android:
            return resolved.buildSettings
        }
    }

    static func appIDMessage(for platform: Platform) -> String {
        switch platform {
        case .ios:
            return "Bundle ID is required to run flows"
        case .android:
            return "Application ID is required. Pass --application-id, set application_id in grantiva-android.yml, build from source, or pass --app-file <apk>."
        }
    }
}
```

- [ ] **Step 6: Lift the gate in Options.swift**

In `PlatformOptions.loadConfig` delete the `if resolved == .android { throw ... }` block and its comment, and make the advice one line for both platforms: `"Create \(resolved.configFileName) with grantiva init --platform \(resolved.rawValue)."`. Change `InjectedDevicePlatform.make` to:

```swift
    func make(_ platform: Platform, android: AndroidPlatform.Options = .init()) throws -> any DevicePlatform {
        try value ?? DevicePlatformFactory.make(platform, android: android)
    }
```

- [ ] **Step 7: Rewire the commands**

Apply the same shape to `RunCommand`, `CIRunCommand`, `BuildOnlyCommand`, `InstallCommand`, `CaptureCommand`, and `CompareCommand`:

1. Replace the `@Option var scheme/simulator/bundleId` trio with `@OptionGroup var target: TargetOptions`. Every later `scheme`, `simulator`, `bundleId` read becomes `target.scheme` and so on. `BuildOnlyCommand` keeps its own `--derived-data-path`.
2. After `let (platform, config) = try platformOptions.loadConfig()`:
   ```swift
   try target.checkFlags(for: platform, derivedDataPath: buildOptions.derivedDataPath)   // RunCommand adds logsPredicate: logsPredicate, logsTag: logsTag
   let device = try devicePlatform.make(platform, android: target.androidOptions)
   ```
3. Replace `let resolvedBinary = try buildOptions.resolveAppBinary()` and the `appBundleId` line with:
   ```swift
   let resolvedBinary: ResolvedBinary? = if let appFile = buildOptions.appFile { try await device.resolveBinary(appFile) } else { nil }
   defer { resolvedBinary?.cleanup() }
   let appBundleId = resolvedBinary?.appID
   ```
4. Replace `ResolvedProject.resolve(schemeFlag: ...)` with `try await target.resolve(platform: platform, config: config, skipBuild: buildOptions.shouldSkipBuild, appID: appBundleId)`. (`BuildOnlyCommand` passes `skipBuild: false, appID: nil`.)
5. Replace `extraBuildSettings: buildOptions.xcodeBuildSettings(merging: resolved.buildSettings)` with `extraBuildSettings: target.extraBuildSettings(platform: platform, derivedDataPath: buildOptions.derivedDataPath, resolved: resolved)`.
6. Where the command reads `buildResult.productPath`, also keep `builtAppID = buildResult.applicationId` (declare `var builtAppID: String?` beside `productPath`). Change every `guard let bid = resolved.bundleId else { throw ...("Bundle ID is required ...") }` to `guard let bid = resolved.bundleId ?? builtAppID else { throw GrantivaError.invalidArgument(TargetOptions.appIDMessage(for: platform)) }`. `InstallCommand`'s message "No bundle ID. Pass --bundle-id or set bundle_id in grantiva.yml." stays for iOS; use `platform == .ios ? <that string> : TargetOptions.appIDMessage(for: .android)`.
7. `BuildOnlyCommand`'s `guard let buildScheme = resolved.scheme` becomes `if platform == .ios, resolved.scheme == nil { throw <same message> }` and the log line reads `"[grantiva] Building \(resolved.scheme ?? ":\(resolved.android?.module ?? "app"):assemble\(resolved.android?.variant ?? "debug")") for \(booted.name)..."`.
8. `RunCommand`:
   - Add `@Option(name: .long, help: "logcat tag to keep when streaming Android logs with --logs (Android).") var logsTag: String?`.
   - Replace the whole `logStreamer` block with:
     ```swift
     let logStreamer: LogStreamer?
     if logs || logsPredicate != nil || logsTag != nil {
         let streamer = LogStreamer()
         do {
             let stream = try await device.logStream(
                 deviceID: booted.udid, appID: resolved.bundleId ?? appBundleId,
                 filter: logsPredicate ?? logsTag, level: logsLevel
             )
             try streamer.start(executable: stream.executable, arguments: stream.arguments)
             log("Streaming \(deviceNoun) logs")
             logStreamer = streamer
         } catch {
             GrantivaLog.logger.warning("failed to start log stream: \(error)")
             logStreamer = nil
         }
     } else {
         logStreamer = nil
     }
     defer { logStreamer?.stop() }
     ```
   - Replace `_ = try? await shell(Self.failureScreenshotCommand(udid: booted.udid, path: failurePath))` with `try? await device.screenshot(deviceID: booted.udid, to: failurePath)` and delete `failureScreenshotCommand`.
   - The `guard let bid` moves after the build block and uses `builtAppID` as in item 6.
9. `DiffCommand.CaptureCommand`: replace `try await DiffCommand.currentlyBootedDevice(platform: platform)` with `try await device.defaultDevice()` and delete `currentlyBootedDevice`. The `device` constant must be created before that branch (it already is).
10. `DiffCommand.CompareCommand`: the bare path becomes
    ```swift
    let platform: Platform
    let config: GrantivaConfig?
    if capture {
        (platform, config) = try platformOptions.loadConfig()
    } else {
        platform = (try? platformOptions.resolve()) ?? .ios
        config = try GrantivaConfig.loadIfPresent(platform: platform)
    }
    ```
    and the `--capture` branch follows items 2 to 6.
11. `BuildCommand.InstallCommand`: the data container step stays as it is (Android throws its "not supported" message).

- [ ] **Step 8: Build and run the whole suite**

Run: `swift build && swift test`
Expected: everything passes, including the five new command tests. The `AndroidCommandTests` log-stream test must show no `xcrun` anywhere in its output.

- [ ] **Step 9: Commit**

```bash
git add Sources Tests
git commit -m "Add Android target flags and route every device command through the platform"
```

---

### Task 9: `init --platform android` and doctor checks

**Files:**
- Modify: `Sources/GrantivaCLI/InitCommand.swift`
- Modify: `Sources/GrantivaCore/Doctor/DoctorRunner.swift`
- Modify: `Sources/GrantivaCLI/DoctorCommand.swift`
- Test: `Tests/GrantivaCLITests/InitAndroidTests.swift`, `Tests/GrantivaCoreTests/DoctorTests.swift`

**Interfaces:**
- Produces: `InitCommand.androidTemplate(module:applicationId:emulator:) -> String`, `InitCommand.detectModule(in:) -> String`; `DoctorRunner.runAllChecks(platforms: [Platform], required: Bool) async -> [DoctorCheck]` (the no-argument `runAllChecks()` stays and means `platforms: [.ios], required: true`); Android checks `checkAndroidSDK`, `checkADB`, `checkEmulatorBinary`, `checkJDK`, `checkAVDs`, `checkRunningEmulator`, `checkConfig(for:)`; `DoctorCommand.platformSelection(flag:directory:environment:) -> (platforms: [Platform], required: Bool)`.

- [ ] **Step 1: Write the failing init tests**

```swift
import ArgumentParser
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class InitAndroidTests: XCTestCase {
    private var dir: URL!
    private var previousDirectory: String!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("init-android-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        previousDirectory = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
    }

    override func tearDownWithError() throws {
        FileManager.default.changeCurrentDirectoryPath(previousDirectory)
        try? FileManager.default.removeItem(at: dir)
    }

    func testInitInAGradleDirectoryWritesTheAndroidFile() async throws {
        try "".write(to: dir.appendingPathComponent("settings.gradle.kts"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("mobile"), withIntermediateDirectories: true)
        try "plugins { id(\"com.android.application\") }".write(to: dir.appendingPathComponent("mobile/build.gradle.kts"), atomically: true, encoding: .utf8)
        try await InitCommand.parse([]).run()
        let yaml = try String(contentsOf: dir.appendingPathComponent("grantiva-android.yml"), encoding: .utf8)
        XCTAssertTrue(yaml.contains("module: mobile"), yaml)
        XCTAssertTrue(yaml.contains("variant: debug"), yaml)
        XCTAssertTrue(yaml.contains("emulator: Pixel_8_API_35"), yaml)
        XCTAssertTrue(yaml.contains("system_image: \"system-images;android-35;google_apis;arm64-v8a\""), yaml)
        XCTAssertTrue(yaml.contains("# application_id:"), yaml)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("grantiva.yml").path))
        let loaded = try GrantivaConfig.load(platform: .android, from: dir)
        XCTAssertEqual(loaded.android?.module, "mobile")
        XCTAssertEqual(loaded.screens.count, 1)
    }

    func testInitWithTheFlagAndAnApplicationIDWritesItUncommented() async throws {
        try await InitCommand.parse(["--platform", "android", "--application-id", "com.example.app"]).run()
        let yaml = try String(contentsOf: dir.appendingPathComponent("grantiva-android.yml"), encoding: .utf8)
        XCTAssertTrue(yaml.contains("\napplication_id: com.example.app\n"), yaml)
        XCTAssertTrue(yaml.contains("module: app"), yaml)
    }

    func testInitDoesNotOverwriteAnExistingAndroidFile() async throws {
        try "module: keep\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        try await InitCommand.parse(["--platform", "android"]).run()
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("grantiva-android.yml"), encoding: .utf8), "module: keep\n")
    }

    func testDetectModulePrefersAppThenTheFirstApplicationModule() throws {
        XCTAssertEqual(InitCommand.detectModule(in: dir.path), "app")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("feature"), withIntermediateDirectories: true)
        try "plugins { id 'com.android.library' }".write(to: dir.appendingPathComponent("feature/build.gradle"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("phone"), withIntermediateDirectories: true)
        try "plugins { id 'com.android.application' }".write(to: dir.appendingPathComponent("phone/build.gradle"), atomically: true, encoding: .utf8)
        XCTAssertEqual(InitCommand.detectModule(in: dir.path), "phone")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("app"), withIntermediateDirectories: true)
        try "".write(to: dir.appendingPathComponent("app/build.gradle.kts"), atomically: true, encoding: .utf8)
        XCTAssertEqual(InitCommand.detectModule(in: dir.path), "app")
    }
}
```

- [ ] **Step 2: Write the failing doctor tests**

Add to `DoctorTests.swift`:

```swift
    func testAndroidSDKCheckIsAnErrorOnlyWhenAndroidIsRequired() async {
        let runner = DoctorRunner()
        let missingRequired = runner.checkAndroidSDK(sdk: nil, required: true)
        XCTAssertEqual(missingRequired.status, .error)
        XCTAssertTrue(missingRequired.fix?.contains("scripts/android-env.sh") == true)
        let missingOptional = runner.checkAndroidSDK(sdk: nil, required: false)
        XCTAssertEqual(missingOptional.status, .warning)
        let present = runner.checkAndroidSDK(sdk: AndroidSDK(root: scratch.path), required: true)
        XCTAssertEqual(present.status, .ok)
        XCTAssertEqual(present.message, scratch.path)
    }

    func testAVDCheckWarnsWhenNoneExist() async {
        let runner = DoctorRunner()
        let none = await runner.checkAVDs(list: { [] })
        XCTAssertEqual(none.status, .warning)
        XCTAssertTrue(none.fix?.contains("android-env.sh") == true)
        let some = await runner.checkAVDs(list: { ["Pixel_8_API_35"] })
        XCTAssertEqual(some.status, .ok)
        XCTAssertEqual(some.message, "Pixel_8_API_35")
    }

    func testConfigCheckNamesThePlatformsFile() {
        let runner = DoctorRunner()
        let android = runner.checkConfig(for: .android, directory: scratch.path)
        XCTAssertEqual(android.name, "grantiva-android.yml")
        XCTAssertEqual(android.status, .warning)
        XCTAssertEqual(android.fix, "Run: grantiva init --platform android")
    }

    func testRunAllChecksWithBothPlatformsOptionalNeverFails() async {
        let checks = await DoctorRunner().runAllChecks(platforms: [.ios, .android], required: false)
        XCTAssertTrue(checks.contains { $0.name == "Android SDK" })
        XCTAssertTrue(checks.contains { $0.name == "Xcode" })
        XCTAssertFalse(DoctorRunner.hasFailures(checks.filter { $0.name.hasPrefix("Android") || $0.name == "adb" || $0.name == "JDK" }))
    }
```

And a CLI test in `Tests/GrantivaCLITests/DoctorSelectionTests.swift`:

```swift
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class DoctorSelectionTests: XCTestCase {
    func testSelectionFollowsFlagEnvConfigDirectoryThenBoth() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var selection = DoctorCommand.platformSelection(flag: .android, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.android]); XCTAssertTrue(selection.required)

        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: ["GRANTIVA_PLATFORM": "ios"])
        XCTAssertEqual(selection.platforms, [.ios]); XCTAssertTrue(selection.required)

        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios, .android]); XCTAssertFalse(selection.required)

        try "".write(to: dir.appendingPathComponent("settings.gradle"), atomically: true, encoding: .utf8)
        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.android]); XCTAssertTrue(selection.required)

        try "".write(to: dir.appendingPathComponent("grantiva.yml"), atomically: true, encoding: .utf8)
        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios]); XCTAssertTrue(selection.required, "a config file beats directory detection")

        try "".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        selection = DoctorCommand.platformSelection(flag: nil, directory: dir, environment: [:])
        XCTAssertEqual(selection.platforms, [.ios, .android]); XCTAssertTrue(selection.required, "both configs: both toolchains are required")
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter 'InitAndroidTests|DoctorTests|DoctorSelectionTests'`
Expected: compile failure.

- [ ] **Step 4: Implement init**

In `InitCommand.swift` add `@Option(name: .long, help: "Application ID (Android)") var applicationId: String?`, update the abstract to "Generate grantiva.yml (iOS) or grantiva-android.yml (Android) in the current directory.", and replace the `if platform == .android { throw ... }` block with:

```swift
        if platform == .android {
            let configPath = "\(cwd)/grantiva-android.yml"
            if fm.fileExists(atPath: configPath) {
                GrantivaLog.logger.info("grantiva-android.yml already exists — skipping")
                return
            }
            let yaml = Self.androidTemplate(
                module: Self.detectModule(in: cwd),
                applicationId: applicationId,
                emulator: "Pixel_8_API_35"
            )
            try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)
            GrantivaLog.logger.info("Created grantiva-android.yml")
            return
        }
```

Add the statics:

```swift
    static func androidTemplate(module: String, applicationId: String?, emulator: String) -> String {
        let idLine = applicationId.map { "application_id: \($0)" } ?? "# application_id: com.example.myapp   # read from the build when omitted"
        return """
        # Generated by grantiva init — commit this file
        platform: android
        module: \(module)
        variant: debug
        \(idLine)
        emulator: \(emulator)
        system_image: "system-images;android-35;google_apis;arm64-v8a"
        # build_args: ["-PsomeFlag=1"]

        screens:
          - name: Home
            path: launch

        diff:
          threshold: 0.02
          perceptual_threshold: 5.0

        # a11y:
        #   rules:
        #     - missing_label
        #     - small_tap_target

        """
    }

    /// `app` when it has a build file, else the first module whose build
    /// file applies `com.android.application`, else `app`.
    static func detectModule(in directory: String) -> String {
        let fm = FileManager.default
        func buildFile(_ module: String) -> String? {
            ["build.gradle.kts", "build.gradle"].map { "\(directory)/\(module)/\($0)" }.first { fm.fileExists(atPath: $0) }
        }
        if buildFile("app") != nil { return "app" }
        let entries = ((try? fm.contentsOfDirectory(atPath: directory)) ?? []).sorted()
        for entry in entries where !entry.hasPrefix(".") {
            guard let file = buildFile(entry), let contents = try? String(contentsOfFile: file, encoding: .utf8),
                  contents.contains("com.android.application") else { continue }
            return entry
        }
        return "app"
    }
```

- [ ] **Step 5: Implement the doctor checks**

In `DoctorRunner.swift`:

```swift
    public func runAllChecks() async -> [DoctorCheck] {
        await runAllChecks(platforms: [.ios], required: true)
    }

    /// `platforms` are the toolchains to inspect; `required` says whether a
    /// missing toolchain is an error (a detected project) or advice (nothing
    /// detected, so both platforms are reported).
    public func runAllChecks(platforms: [Platform], required: Bool) async -> [DoctorCheck] {
        var checks: [DoctorCheck] = []
        if platforms.contains(.ios) {
            checks.append(await checkXcode(required: required))
            checks.append(await checkXcodeVersion(required: required))
            checks.append(await checkBootedSimulator())
        }
        if platforms.contains(.android) {
            let sdk = AndroidSDK.locate()
            checks.append(checkAndroidSDK(sdk: sdk, required: required))
            if let sdk {
                checks.append(await checkADB(sdk: sdk, required: required))
                checks.append(checkEmulatorBinary(sdk: sdk, required: required))
                checks.append(await checkJDK(required: required))
                let manager = EmulatorManager(sdk: sdk, adb: ADB(path: sdk.adb))
                checks.append(await checkAVDs(list: { (try? await manager.listAVDs()) ?? [] }))
                checks.append(await checkRunningEmulator(adb: ADB(path: sdk.adb)))
            }
        }
        checks.append(await checkRunner())
        for platform in platforms {
            checks.append(checkConfig(for: platform))
        }
        checks.append(checkGitRepository())
        checks.append(checkGrantivaAuth())
        checks.append(checkGitHubApp())
        return checks
    }
```

Give `checkXcode` and `checkXcodeVersion` a `required: Bool = true` parameter and use `required ? .error : .warning` for their failure statuses. Add:

```swift
    func checkAndroidSDK(sdk: AndroidSDK?, required: Bool) -> DoctorCheck {
        guard let sdk else {
            return DoctorCheck(
                name: "Android SDK", status: required ? .error : .warning,
                message: "Not found (ANDROID_HOME, ANDROID_SDK_ROOT, ~/Library/Android/sdk)",
                fix: "Run: scripts/android-env.sh, or set ANDROID_HOME"
            )
        }
        return DoctorCheck(name: "Android SDK", status: .ok, message: sdk.root, fix: nil)
    }

    func checkADB(sdk: AndroidSDK, required: Bool) async -> DoctorCheck {
        guard let version = try? await shell("\(shellQuoted(sdk.adb)) version | head -1"), !version.isEmpty else {
            return DoctorCheck(name: "adb", status: required ? .error : .warning, message: "\(sdk.adb) did not run", fix: "Run: sdkmanager platform-tools")
        }
        return DoctorCheck(name: "adb", status: .ok, message: version, fix: nil)
    }

    func checkEmulatorBinary(sdk: AndroidSDK, required: Bool) -> DoctorCheck {
        guard FileManager.default.fileExists(atPath: sdk.emulator) else {
            return DoctorCheck(name: "Android Emulator", status: required ? .error : .warning, message: "Not installed", fix: "Run: sdkmanager emulator")
        }
        return DoctorCheck(name: "Android Emulator", status: .ok, message: sdk.emulator, fix: nil)
    }

    func checkJDK(required: Bool) async -> DoctorCheck {
        guard let home = await AndroidSDK.javaHome() else {
            return DoctorCheck(name: "JDK", status: required ? .error : .warning, message: "No JDK found (JAVA_HOME or /usr/libexec/java_home)", fix: "Run: brew install openjdk@21 and set JAVA_HOME (see docs/android-environment.md)")
        }
        return DoctorCheck(name: "JDK", status: .ok, message: home, fix: nil)
    }

    func checkAVDs(list: () async -> [String]) async -> DoctorCheck {
        let avds = await list()
        guard !avds.isEmpty else {
            return DoctorCheck(name: "Android AVDs", status: .warning, message: "No AVD exists", fix: "Run: scripts/android-env.sh (creates Pixel_8_API_35)")
        }
        return DoctorCheck(name: "Android AVDs", status: .ok, message: avds.joined(separator: ", "), fix: nil)
    }

    func checkRunningEmulator(adb: ADB) async -> DoctorCheck {
        let running = ((try? await adb.devices()) ?? []).filter { $0.isEmulator && $0.isUsable }
        guard !running.isEmpty else {
            return DoctorCheck(name: "Running Emulator", status: .warning, message: "No emulator running", fix: "Grantiva boots the configured AVD on demand; or run: emulator -avd Pixel_8_API_35")
        }
        return DoctorCheck(name: "Running Emulator", status: .ok, message: running.map(\.serial).joined(separator: ", "), fix: nil)
    }

    func checkConfig(for platform: Platform, directory: String = FileManager.default.currentDirectoryPath) -> DoctorCheck {
        let name = platform.configFileName
        if FileManager.default.fileExists(atPath: "\(directory)/\(name)") {
            return DoctorCheck(name: name, status: .ok, message: "Found", fix: nil, section: .project)
        }
        return DoctorCheck(
            name: name, status: .warning, message: "Not found",
            fix: platform == .ios ? "Run: grantiva init" : "Run: grantiva init --platform android",
            section: .project
        )
    }
```

Delete `checkGrantivaConfig` (replaced by `checkConfig(for: .ios)`; update any test that called it).

In `DoctorCommand.swift` add `@OptionGroup var platformOptions: PlatformOptions`, and:

```swift
    func run() async throws {
        let selection = Self.platformSelection(flag: platformOptions.platform)
        let checks = await DoctorRunner().runAllChecks(platforms: selection.platforms, required: selection.required)
        ...unchanged...
    }

    /// Flag, then GRANTIVA_PLATFORM, then config files, then project files;
    /// nothing found means both platforms, reported as advice.
    static func platformSelection(
        flag: Platform?,
        directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> (platforms: [Platform], required: Bool) {
        if let flag { return ([flag], true) }
        let resolver = PlatformResolver(directory: directory, environment: environment)
        if let env = Platform(rawValue: (environment[PlatformResolver.environmentKey] ?? "").trimmingCharacters(in: .whitespaces).lowercased()) {
            return ([env], true)
        }
        let configs = resolver.existingConfigFiles()
        if !configs.isEmpty { return (Platform.allCases.filter(configs.contains), true) }
        let detected = resolver.detectFromDirectory()
        if !detected.isEmpty { return (Platform.allCases.filter(detected.contains), true) }
        return (Platform.allCases, false)
    }
```

`PlatformResolver.existingConfigFiles()` and `detectFromDirectory()` exist from Plan 1 and return `[Platform]`; if `existingConfigFiles` returns a `Set`, adapt the `contains` call.

- [ ] **Step 6: Build and run**

Run: `swift build && swift test --filter 'InitAndroidTests|DoctorTests|DoctorSelectionTests|InitCommand'`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Sources Tests
git commit -m "Add init --platform android and Android doctor checks"
```

---

### Task 10: Per-platform capture and baseline directories; local-only Android baselines

**Files:**
- Modify: `Sources/GrantivaCLI/DiffCommand.swift`
- Modify: `Sources/GrantivaCLI/CICommand.swift`
- Modify: `Sources/GrantivaCLI/RunCommand.swift` (default capture directory)
- Test: `Tests/GrantivaCLITests/DiffCommandTests.swift` (add), `Tests/GrantivaCLITests/AndroidCommandTests.swift` (add)

**Interfaces:**
- Produces: `DiffCommand.captureDirectory(for: Platform) -> String` (`.grantiva/captures` / `.grantiva/captures/android`), `DiffCommand.baselineDirectory(for: Platform) -> String` (`.grantiva/baselines` / `.grantiva/baselines/android`), `DiffCommand.resolveBaselineStore(platform:credentials:) async throws -> BaselineStore`, `DiffCommand.androidLocalOnlyMessage` (the verbatim string), `CICommand.androidLocalOnlyMessage` (same constant, re-exported).

- [ ] **Step 1: Write the failing tests**

Add to `DiffCommandTests.swift`:

```swift
    func testDirectoriesArePerPlatform() {
        XCTAssertEqual(DiffCommand.captureDirectory(for: .ios), ".grantiva/captures")
        XCTAssertEqual(DiffCommand.captureDirectory(for: .android), ".grantiva/captures/android")
        XCTAssertEqual(DiffCommand.baselineDirectory(for: .ios), ".grantiva/baselines")
        XCTAssertEqual(DiffCommand.baselineDirectory(for: .android), ".grantiva/baselines/android")
    }

    func testAndroidBaselineStoreIsLocalEvenWhenAuthenticated() async throws {
        let credentials = AuthCredentials(apiKey: "key", baseURL: "https://example.invalid")
        let store = try await DiffCommand.resolveBaselineStore(platform: .android, credentials: credentials)
        XCTAssertEqual(store.baselineDirectory(), ".grantiva/baselines/android")
        let anonymous = try await DiffCommand.resolveBaselineStore(platform: .android, credentials: nil)
        XCTAssertEqual(anonymous.baselineDirectory(), ".grantiva/baselines/android")
    }

    func testIOSBaselineStoreIsUnchangedWhenAnonymous() async throws {
        let store = try await DiffCommand.resolveBaselineStore(platform: .ios, credentials: nil)
        XCTAssertEqual(store.baselineDirectory(), ".grantiva/baselines")
    }

    /// Review Focus 5: approving Android captures never touches the iOS baseline root.
    func testApproveOnAndroidWritesOnlyUnderTheAndroidDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        try "module: app\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(atPath: ".grantiva/captures/android", withIntermediateDirectories: true)
        try Data([0x89, 0x50]).write(to: URL(fileURLWithPath: ".grantiva/captures/android/Home.png"))

        try await DiffCommand.ApproveCommand.parse([]).run()

        XCTAssertTrue(FileManager.default.fileExists(atPath: ".grantiva/baselines/android/Home.png"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ".grantiva/baselines/Home.png"))
    }
```

Add to `AndroidCommandTests.swift`:

```swift
    func testCIRunOnAndroidFailsWithTheLocalOnlyMessageBeforeAnyDeviceWork() async throws {
        try """
        module: app
        screens:
          - name: Home
            path: launch
        """.write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        var command = try CICommand.CIRunCommand.parse(["--no-build", "--application-id", "com.fake"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains(DiffCommand.androidLocalOnlyMessage), "\(error)")
            XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
        }
    }

    func testRunOnAndroidCapturesUnderTheAndroidDirectory() async throws {
        var command = try RunCommand.parse(["--no-build", "--application-id", "com.fake", "--timeout", "30"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        command.runnerManager = stubRunner
        _ = try? await command.run()
        let failureShots = (try? FileManager.default.contentsOfDirectory(atPath: ".grantiva/captures/android")) ?? []
        XCTAssertFalse(failureShots.isEmpty, "the failure capture directory is the Android one")
        XCTAssertFalse(FileManager.default.fileExists(atPath: ".grantiva/captures/\(failureShots[0])"), "nothing lands in the iOS directory")
    }
```

(The fake platform's `screenshot` records only; make the second test pass by having `FakeDevicePlatform.screenshot` write an empty file at `path`.)

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter 'DiffCommandTests|AndroidCommandTests'`
Expected: compile failure.

- [ ] **Step 3: Implement**

In `DiffCommand`:

```swift
    static let androidLocalOnlyMessage =
        "Android baselines are local only until the Grantiva backend supports platforms; use local baselines"

    static func captureDirectory(for platform: Platform) -> String {
        platform == .ios ? ".grantiva/captures" : ".grantiva/captures/android"
    }

    static func baselineDirectory(for platform: Platform) -> String {
        platform == .ios ? ".grantiva/baselines" : ".grantiva/baselines/android"
    }

    /// Remote when authenticated, local otherwise; Android is always local
    /// and says so once when a login would otherwise have picked remote.
    static func resolveBaselineStore(
        platform: Platform,
        credentials: AuthCredentials? = AuthStore.resolveCredentials()
    ) async throws -> BaselineStore {
        if platform == .android {
            if credentials != nil {
                GrantivaLog.logger.warning("\(androidLocalOnlyMessage)")
            }
            return .local(directory: baselineDirectory(for: .android))
        }
        if let credentials {
            let client = try RangeClient(apiKey: credentials.apiKey, baseURL: credentials.baseURL)
            let projectId = try await ProjectIdentifier.resolve()
            return client.asBaselineStore(project: projectId.projectSlug, branch: projectId.currentBranch, baseURL: credentials.baseURL)
        }
        return .local()
    }
```

Delete the old `resolveBaselineStore()`; its callers pass `platform:`.

- `CaptureCommand`: `let outputDir = DiffCommand.captureDirectory(for: platform)`.
- `CompareCommand`: `let captureDir = DiffCommand.captureDirectory(for: platform)`, `let diffDir = "\(captureDir)/diffs"`, and where it resolves the store, `try await DiffCommand.resolveBaselineStore(platform: platform)`.
- `ApproveCommand`: add `@OptionGroup var platformOptions: PlatformOptions`; `let platform = (try? platformOptions.resolve()) ?? .ios`; `let captureDir = DiffCommand.captureDirectory(for: platform)`; `let store = try await DiffCommand.resolveBaselineStore(platform: platform)`.
- `CIRunCommand`: right after `let (platform, config) = try platformOptions.loadConfig()`, add
  ```swift
  guard platform == .ios else {
      throw GrantivaError.invalidArgument(DiffCommand.androidLocalOnlyMessage)
  }
  ```
  before `devicePlatform.make`. Its `captureDir`/`diffDir` stay the iOS constants (it never reaches Android).
- `RunCommand`: the default `captureDir` becomes `DiffCommand.captureDirectory(for: platform)` (the `--report-dir` branch is unchanged).

- [ ] **Step 4: Build and run**

Run: `swift build && swift test`
Expected: the whole suite passes.

- [ ] **Step 5: Commit**

```bash
git add Sources Tests
git commit -m "Keep Android captures and baselines in their own directories and refuse remote Android baselines"
```

---

### Task 11: `examples/android` Compose app

**Files:**
- Create: `examples/android/settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `gradle/libs.versions.toml`, `gradle/wrapper/gradle-wrapper.properties`, `gradle/wrapper/gradle-wrapper.jar`, `gradlew`, `.gitignore`
- Create: `examples/android/app/build.gradle.kts`, `app/src/main/AndroidManifest.xml`, `app/src/main/java/dev/grantiva/example/MainActivity.kt`, `app/src/main/res/values/strings.xml`, `app/src/main/res/values/themes.xml`
- Create: `examples/android/grantiva-android.yml`, `examples/android/README.md`

**Interfaces:**
- Produces: an app with application ID `dev.grantiva.example`, three screens reachable by tapping the texts `Home`, `Details`, `Settings` in a bottom bar, and a config with three `screens` entries. Task 12 runs the acceptance pass against it.

- [ ] **Step 1: Install Gradle for the wrapper and generate it**

```bash
brew list gradle >/dev/null 2>&1 || brew install gradle
mkdir -p examples/android && cd examples/android
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
gradle wrapper --gradle-version 8.11.1 --distribution-type bin
cd ../..
```

Expected: `examples/android/gradlew`, `gradlew.bat`, and `gradle/wrapper/` exist. Delete `gradlew.bat`.

- [ ] **Step 2: Write the project files**

`examples/android/settings.gradle.kts`:

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "GrantivaExample"
include(":app")
```

`examples/android/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
```

`examples/android/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx2g
android.useAndroidX=true
kotlin.code.style=official
```

`examples/android/gradle/libs.versions.toml`:

```toml
[versions]
agp = "8.7.3"
kotlin = "2.0.21"
composeBom = "2024.12.01"
activityCompose = "1.9.3"

[libraries]
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
```

`examples/android/.gitignore`:

```
build/
.gradle/
local.properties
.grantiva/captures/
*.iml
.idea/
```

`examples/android/app/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "dev.grantiva.example"
    compileSdk = 35

    defaultConfig {
        applicationId = "dev.grantiva.example"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.activity.compose)
}
```

`examples/android/app/src/main/AndroidManifest.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="@string/app_name"
        android:theme="@style/Theme.GrantivaExample">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

`examples/android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Grantiva Example</string>
</resources>
```

`examples/android/app/src/main/res/values/themes.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.GrantivaExample" parent="android:Theme.Material.Light.NoActionBar" />
</resources>
```

`examples/android/app/src/main/java/dev/grantiva/example/MainActivity.kt`:

```kotlin
package dev.grantiva.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

enum class Screen(val title: String) { Home("Home"), Details("Details"), Settings("Settings") }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { ExampleApp() } }
    }
}

@Composable
fun ExampleApp() {
    var current by rememberSaveable { mutableStateOf(Screen.Home) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                Screen.entries.forEach { screen ->
                    NavigationBarItem(
                        selected = current == screen,
                        onClick = { current = screen },
                        icon = {},
                        label = { Text(screen.title) },
                        modifier = Modifier.semantics { contentDescription = screen.title }
                    )
                }
            }
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp)) {
            when (current) {
                Screen.Home -> {
                    Text("Welcome to Grantiva", style = MaterialTheme.typography.headlineMedium)
                    Text("This screen is the launch baseline.")
                }
                Screen.Details -> {
                    Text("Details", style = MaterialTheme.typography.headlineMedium)
                    Text("Three lines of body copy give the diff something to compare.")
                    Text("Line two.")
                    Text("Line three.")
                }
                Screen.Settings -> {
                    var enabled by rememberSaveable { mutableStateOf(true) }
                    Text("Settings", style = MaterialTheme.typography.headlineMedium)
                    Switch(checked = enabled, onCheckedChange = { enabled = it })
                }
            }
        }
    }
}
```

`examples/android/grantiva-android.yml`:

```yaml
# Grantiva example Android project. Run from this directory:
#   grantiva run
#   grantiva diff capture && grantiva diff approve && grantiva diff compare
platform: android
module: app
variant: debug
application_id: dev.grantiva.example
emulator: Pixel_8_API_35
system_image: "system-images;android-35;google_apis;arm64-v8a"

screens:
  - name: Home
    path: launch
  - name: Details
    path:
      - tap: Details
      - assert_visible: Line three.
  - name: Settings
    path:
      - tap: Settings
      - assert_visible: Settings

diff:
  threshold: 0.02
  perceptual_threshold: 5.0
```

`examples/android/README.md`:

```markdown
# Android example

A three-screen Jetpack Compose app used to exercise Grantiva's Android support.

Prerequisites: `scripts/android-env.sh` from the repository root (SDK, JDK 21, the
`Pixel_8_API_35` AVD), and `JAVA_HOME`/`ANDROID_HOME` exported as that script prints.

    cd examples/android
    grantiva doctor
    grantiva build
    grantiva run
    grantiva diff capture
    grantiva diff approve
    grantiva diff compare

The first `./gradlew` run downloads the Android Gradle Plugin and Compose; allow a few minutes.
```

- [ ] **Step 3: Build it once by hand**

```bash
cd examples/android
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
./gradlew :app:assembleDebug --console=plain
ls app/build/outputs/apk/debug/
cd ../..
```

Expected: `app-debug.apk` and `output-metadata.json`. If the first run fails on an SDK license or a missing `platforms;android-35`, run `yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses` and `"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "platforms;android-35" "build-tools;35.0.0"`, then retry. If AGP 8.7.3 refuses the installed JDK, say so in the report; do not change the JDK.

- [ ] **Step 4: Commit**

```bash
git add examples/android
git commit -m "Add the Android example app"
```

---

### Task 12: Acceptance on the emulator, docs, and changelog

**Files:**
- Create: `docs/superpowers/plans/2026-10-08-android-plan2-acceptance.md`
- Create: `docs/android.md`
- Modify: `docs/android-environment.md` (link to `docs/android.md`), `CHANGELOG.md`, `README.md` (one paragraph under the platform/usage section pointing at `docs/android.md`)

**Interfaces:**
- Consumes: everything above, `examples/android`, the `Pixel_8_API_35` AVD, `scripts/android-env.sh`.

- [ ] **Step 1: Run the acceptance pass and record it**

From `examples/android`, with `JAVA_HOME` and `ANDROID_HOME` exported as in Task 11 and `swift build` done at the repo root (`GRANTIVA=../../.build/debug/grantiva`):

```bash
$GRANTIVA doctor                                   # Android section OK, iOS section present
$GRANTIVA build                                    # BUILD SUCCESSFUL, APK path printed
$GRANTIVA run --logs                               # 3 screens pass; [log] lines appear; no xcrun in --verbose output
$GRANTIVA diff capture                             # 3 captures under .grantiva/captures/android
$GRANTIVA diff approve                             # 3 baselines under .grantiva/baselines/android
$GRANTIVA diff compare                             # all pass
sed -i '' 's/Line two\./Line two, changed./' app/src/main/java/dev/grantiva/example/MainActivity.kt
$GRANTIVA diff compare --capture                   # Details fails on the changed Line two (its Line three. assertion still holds), Home and Settings pass
git checkout app/src/main/java/dev/grantiva/example/MainActivity.kt
$GRANTIVA ci run                                   # exits non-zero with the local-only message, before booting anything
$GRANTIVA run --device emulator-5554               # same 3 screens via the serial
cd /tmp && mkdir -p gradle-init && cd gradle-init && touch settings.gradle.kts && $GRANTIVA init && cat grantiva-android.yml && cd - && rm -rf /tmp/gradle-init
```

Then `adb -s emulator-5554 shell settings get global window_animation_scale` must print the pre-run value (1.0 on a fresh AVD) and `ls .grantiva/android-settings-*` must find nothing.

Record every command, its exit status, and the first lines of its output in `docs/superpowers/plans/2026-10-08-android-plan2-acceptance.md`, under a heading per command. A step that cannot pass on this machine is recorded with its error verbatim; do not mark it passed.

Then at the repo root: `swift test` (whole suite) and, if an iOS project builds on this host, one iOS `grantiva run` against it; otherwise record that the iOS end-to-end run is blocked by the pre-existing Xcode 27 WebDriverAgent build failure noted in Plan 1's hand-off.

- [ ] **Step 2: Write docs/android.md**

```markdown
# Grantiva for Android

Grantiva runs the same commands against an Android emulator that it runs against an iOS
simulator. The Android project gets its own config file, `grantiva-android.yml`, beside
`grantiva.yml`.

## Setup

Run `scripts/android-env.sh` once (see `docs/android-environment.md`), export `JAVA_HOME`
and `ANDROID_HOME` as it prints, then in your project:

    grantiva init --platform android     # writes grantiva-android.yml
    grantiva doctor

`init` picks the platform from the directory: a `settings.gradle` or `settings.gradle.kts`
means Android, an `.xcodeproj` or `.xcworkspace` means iOS. With both, pass `--platform`.

## Config

    platform: android
    module: app                      # Gradle module; default app
    variant: debug                   # assembleDebug; freeDebug -> assembleFreeDebug
    application_id: com.example.app  # optional; read from the build output when absent
    emulator: Pixel_8_API_35         # AVD to use or boot
    system_image: "system-images;android-35;google_apis;arm64-v8a"
    build_args: ["-PsomeFlag=1"]
    screens: [...]                   # same shape as iOS
    flows: [...]
    diff: {...}

## Devices

Only running emulators are considered by default. `emulator:` names the AVD; it is used if
running, booted otherwise. With no `emulator:`, a single running emulator is used, else a
single existing AVD is booted. `--device <serial>` targets any attached device, including
a physical one. On a physical device the demo-mode and animation settings are skipped
unless `--allow-device-settings` is given. `--headless` boots without a window.

Flags: `--module`, `--variant`, `--application-id`, `--emulator`, `--device`,
`--allow-device-settings`, `--headless`, `--logs-tag`. iOS flags such as `--scheme` are
rejected on Android, and vice versa. `GRANTIVA_PLATFORM=android` or `--platform android`
forces the platform when both config files exist.

## Captures and baselines

Android captures go to `.grantiva/captures/android/` and baselines to
`.grantiva/baselines/android/`. Baselines are local only for now: `ci run` and remote
baselines refuse Android with "Android baselines are local only until the Grantiva backend
supports platforms; use local baselines". `diff capture`, `diff compare`, and
`diff approve` work locally.

Before each capture Grantiva enables System UI demo mode (clock 09:41, full battery,
no notifications), sets the three animation scales to 0, and pins portrait. The previous
values are saved to `.grantiva/android-settings-<serial>.json` and restored afterwards. If
a run is interrupted, the next run restores them first.

## Logs

`grantiva run --logs` streams `logcat` filtered to the app's uid. `--logs-tag <tag>` keeps
one tag. `--logs-predicate` is iOS-only.

## CI

GitHub-hosted macOS runners cannot boot the emulator. Use a self-hosted Mac or a developer
machine. `GRANTIVA_EMULATOR_BOOT_TIMEOUT_SECONDS` (default 180) bounds the boot wait.

## Not yet

`hierarchy`, `record`, `runner start`, the MCP server, and the `emulator` subcommand arrive
in the next release.
```

Add to `docs/android-environment.md`, at the end: `See docs/android.md for using Grantiva with an Android project.` Add one paragraph to `README.md` where platforms or usage are introduced: "Android: see `docs/android.md`."

- [ ] **Step 3: Changelog**

Replace the Plan 1 Unreleased wording that said Android "is not yet runnable" with the shipped state. Under `## Unreleased`:

```markdown
### Added
- Android support for `init`, `doctor`, `build`, `build install`, `run`, `diff capture`, `diff compare`, and `diff approve`, driven through `adb`, Gradle, and the embedded runner's UIAutomator2 driver. `grantiva init --platform android` (or `init` in a Gradle project) writes `grantiva-android.yml`. See `docs/android.md`.
- Android flags: `--module`, `--variant`, `--application-id`, `--emulator <AVD>`, `--device <serial>`, `--allow-device-settings`, `--headless`, and `--logs-tag`. A flag from the other platform is rejected by name.
- Emulator selection: the configured AVD is used when running and booted otherwise (`-no-snapshot-save -no-boot-anim`, `-no-window` under `--headless` or without a terminal). Emulators Grantiva boots are recorded in `~/.grantiva/android/started.json`.
- Stable Android captures: System UI demo mode, animation scales 0, portrait pinned; previous values saved in `.grantiva/android-settings-<serial>.json` and restored, including after an interrupted run.
- `doctor` checks the Android SDK, adb, emulator, JDK, and AVDs when the project is Android, and reports both toolchains as advice when no project is detected. `--platform` selects.
- `examples/android`, a three-screen Compose app with a `grantiva-android.yml`.

### Changed
- Android captures and baselines live in `.grantiva/captures/android/` and `.grantiva/baselines/android/`. iOS paths are unchanged.
- Android baselines are local only. `ci run` on Android, and remote baselines for Android, fail with "Android baselines are local only until the Grantiva backend supports platforms; use local baselines". `diff compare` and `diff approve` use the local store and print that line once when you are logged in.
- `--app-file` accepts an `.apk` on Android; the application ID is read with `apkanalyzer`.
- `grantiva run --logs` on Android streams `logcat` for the app's uid.
- The `--scheme`, `--simulator`, and `--bundle-id` options are now declared once, shared by every device command; their names and behavior are unchanged.
```

Keep the Plan 1 bullets that still hold (platform resolution, `grantiva-android.yml` recognition, runner tarball, config parse errors, the KMP note) and delete the ones that said Android fails with "arrives in the next release".

- [ ] **Step 4: Full suite**

Run: `swift test`
Expected: all pass, no warnings in the output.

- [ ] **Step 5: Commit**

```bash
git add docs CHANGELOG.md README.md
git commit -m "Document Android run and VRT, record the acceptance pass"
```

---

## Hand-off to Plan 3

- **Plan 3, Android hierarchy, keep-alive, MCP, record, emulator subcommand:** `UIAutomator2Client` behind a `DriverClient` protocol forwarding port 6790 itself (spike result), `hierarchy` and `runner dump-hierarchy` parsing the UIA2 tree, `record` via `screenrecord` with the 180 s cap, `runner start/stop` through the platform, MCP `grantiva_emulator_*` twins and `--platform` pass-through in VRTTools, the `emulator ensure/delete/sessions/teardown` subcommand using `AndroidProvenance`, `cleanupOrphans` from teardown, and a11y rules keyed on `class`/`content-desc`.
- Deferred from this plan: moving the APKs out of the per-arch runner tarballs; `BuildCommand.dataContainerPath` on Android stays unsupported.
