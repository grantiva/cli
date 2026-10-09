# Android Support, Plan 3: Hierarchy, Record, Keep-alive, MCP, and Emulator Lifecycle — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish Android parity: `hierarchy`, `runner dump-hierarchy`, `record`, `runner start/stop`, the `emulator` subcommand, the MCP server with `grantiva_emulator_*` tools and Android-aware UI tools, Android a11y rules, and the carry-forwards Plan 2 left behind.

**Architecture:** The CLI talks to the UIAutomator2 server directly: it forwards a local port to the device's port 6790 with `adb forward tcp:0 tcp:6790`, reads the runner-held session id from `GET /wd/hub/sessions`, and speaks WebDriver to `/wd/hub/session/<id>/...`. `WDAClient` becomes `DriverClient`, the same struct of closures, with two factories: `.wda(port:)` (unchanged behaviour) and `.uiAutomator2(endpoint:scale:)`. `DevicePlatform` gains `attachDriver` and `recordVideo` so commands and the MCP server never pick a driver themselves. `EmulatorManager` gains ensure/delete/sessions/teardown over the Plan 2 provenance ledger, and the `emulator` subcommand plus four MCP tools expose them.

**Tech Stack:** Swift 6.1, ArgumentParser, XCTest, Foundation `URLSession` and `XMLParser`, AVFoundation (frame extraction, unchanged), adb, `emulator`, `avdmanager`, `sdkmanager`, UIAutomator2 server 9.11.1, MCP Swift SDK.

**Spec:** `docs/superpowers/specs/2026-10-07-android-support-design.md` (sections 2, 3 "Emulator lifecycle", "`emulator` subcommand", "Orphans", 4, 6, 7). Spike result: `docs/superpowers/plans/2026-10-07-android-spike-result.md`.

**Branch:** `feat/android-plan3`, forked from `feat/android-run-vrt` (Plan 2, PR #160) at `4fc571d`. Plan 2's code is the baseline; nothing here depends on `main` having merged it.

## Global Constraints

- Swift 6.1, macOS 15+. The package builds with `swift build` and tests run with `swift test`; both must stay green after every task.
- Every subprocess goes through the `shell`/`execute` seam (`ScriptedShell` in tests) or `ChildProcess.spawn`. Tests assert exact command lines. No test may boot a device, open a socket, or touch `~/.grantiva`.
- Every value that reaches a shell line from user, config, or model input goes through `shellQuoted`.
- Android baselines stay local-only (Plan 2). Nothing in this plan touches `BaselineStore`, `ImageDiffer`, or `ci run`.
- iOS behaviour, argv, file paths, JSON keys, and messages are unchanged unless a task says otherwise and pins the change with a test. `CaptureSimulatorTarget` and its `simulator` JSON key stay. `RecordReport`'s `simulator` key stays.
- Emulators are the default device. A physical device is used only with `--device <serial>`. `emulator teardown` and `cleanupOrphans` never touch an emulator Grantiva did not start unless `--force` is given.
- The Go runner is unchanged. The CLI sets `MAESTRO_RUNNER_HOME` (already done by `AndroidPlatform.runnerEnvironment`) and never passes `--auto-start-emulator` or `--driver`.
- No `Co-Authored-By` or `Generated with` lines in commits.
- Test fixtures never signal real pids. A fixture that needs a live pid uses `getpid()`; one that needs a dead child spawns `/bin/true` and waits on it.
- Verified facts about UIAutomator2 9.11.1 (probed on the host emulator while writing this plan; the plan's code relies on them):
  - `adb -s <serial> forward tcp:0 tcp:6790` prints the allocated local port on stdout (for example `61211`).
  - `GET /wd/hub/status` → `{"sessionId":"None","value":{"ready":true,...}}`. `GET /wd/hub/sessions` → `{"value":[{"id":"<uuid>",...}]}`; an empty `value` means no session.
  - `GET /wd/hub/session/<id>/source` → `{"value":"<?xml ...><hierarchy ... width=\"1080\" height=\"2400\"> <android.widget.FrameLayout index=\"0\" package=\"…\" class=\"android.widget.FrameLayout\" text=\"\" content-desc=\"…\" resource-id=\"…\" clickable=\"false\" enabled=\"true\" bounds=\"[0,0][1080,2400]\" displayed=\"true\" …>`.
  - Element lookup takes `{"strategy":"xpath","selector":"…"}` or `{"strategy":"accessibility id","selector":"…"}` on `POST /wd/hub/session/<id>/elements` (array result) and `/element` (single). The WDA-style `using`/`value` body is rejected with "The mandatory field 'selector' is not present". Element ids come back under both `ELEMENT` and `element-6066-11e4-a52e-4f735466cecf`.
  - `POST /wd/hub/session/<id>/element/<e>/click` with `{}` clicks. `POST /wd/hub/session/<id>/actions` accepts W3C pointer actions (pixel coordinates) and W3C key actions (`{"type":"key","id":"kb","actions":[{"type":"keyDown","value":"h"},{"type":"keyUp","value":"h"}]}`). `POST /keys` fails with "no such element" unless a field is focused, so typing uses key actions.
  - `GET /wd/hub/session/<id>/window/current/size` → `{"value":{"width":1080,"height":2400}}` in pixels. `/window/rect` is not implemented.
  - `GET /wd/hub/session/<id>/screenshot` → `{"value":"<base64 png>"}`.
  - Unprefixed routes (`/status`, `/session/<id>/source`) also answer, but every request in this plan uses the `/wd/hub` prefix.
  - `screenrecord --time-limit N <file>` caps at 180 seconds per file.

## Rulings made while writing this plan

1. **`DriverClient` is the existing struct of closures, not a protocol.** The spec says "WDAClient becomes a `DriverClient` protocol with `WDAClient` and `UIAutomator2Client` implementations". The struct-of-closures is already the test seam every MCP test uses (`MCPTestSupport.fakeWDA`); a protocol would force an existential through every handler for no gain. `DriverClient` is the renamed struct, `typealias WDAClient = DriverClient` keeps old spellings compiling, and the two "implementations" are `DriverClient.wda(port:)` and `DriverClient.uiAutomator2(endpoint:scale:transport:)`. Cost if wrong: a later third driver adds a factory, not a conformance.
2. **Element lookup by label on Android is an XPath over `@content-desc` or `@text`, not `accessibility id` alone.** Compose text nodes carry `text` and no `content-desc`; `accessibility id` matches only `content-desc`. Verified on the example app: `accessibility id` "Details" found the navigation item, and only the XPath found the heading. Cost: XPath literal quoting, handled by `UIAutomator2.xpathLiteral`.
3. **Typing on Android uses W3C key actions**, because `/keys` needs a focused element and fails otherwise (verified). Cost: non-BMP characters are sent one scalar at a time, like iOS.
4. **Android frames are reported in dp**, dividing `bounds` pixels by `density/160`, so `frame` means the same thing as iOS points and the a11y rules read one shape. Tap coordinates given to `grantiva_tap` are still device pixels on Android (spec), and the tool description says so. Minimum tap target is 48 dp on Android, 44 pt on iOS.
5. **`record` refuses durations over 180 seconds on Android** with a clear message, rather than chaining `screenrecord` files. Cost: no long Android recordings in this release; the spec's "180 s cap per file" wording is satisfied by the cap.
6. **The MCP tool surface grows by exactly four emulator tools** (`grantiva_emulator_list`, `_boot`, `_ensure`, `_delete`), always registered so the advertised tool list is static. On a Mac without the Android SDK they return an error result naming `scripts/android-env.sh`. `grantiva_sim_*` are untouched.
7. **`grantiva_test` on an Android project returns an error result** ("grantiva_test runs xcodebuild test and is iOS-only; run ./gradlew connectedAndroidTest yourself"). There is no CLI `test` command to mirror and no result parser for `connectedAndroidTest`. Cost: one spec table row (`runTests`) deferred; recorded in the hand-off.
8. **`runner start` on Android records the forwarded local port in `RunnerSessionInfo.wdaPort`.** The field name stays (`session.json` compatibility); the human output says "UIAutomator2 port". Cost: none.
9. **`emulator ensure` prints the serial on stdout when it boots, and the AVD name under `--no-boot`**, mirroring `simulator ensure`'s "stdout is the identifier" contract.
10. **`emulator teardown` kills only ledger emulators; `--force` kills any serial.** `sessions` prunes ledger records whose pid is dead *and* whose serial adb no longer lists.
11. **The "nothing points anywhere → iOS" rule moves from `PlatformOptions.resolve` into `PlatformResolver.resolveOrDefault(flag:)`** so the MCP server (which is not an ArgumentParser command) applies the same rule. `PlatformOptions.resolve` delegates; its tests are unchanged.
12. **`cleanupOrphans` removes only this serial's forwards** by listing `adb forward --list` and removing each `tcp:<n>` whose first field is the serial. `adb forward --remove-all` is host-wide and is deleted (Plan 2 carry-forward).
13. **`AndroidProvenance.register` replaces an existing record with the same serial** (Plan 2 carry-forward: a reused serial left a stale pid).
14. **Keep-alive `hierarchy` on Android ignores the runner's session port**, which the spike showed is always 0. The session's owner sidecar carries the serial, and that is the only thing the Android path needs.
15. **The UIAutomator2 APKs move out of the two per-arch runner tarballs into one `android-drivers.tar.gz`** (Plan 2 carry-forward). Both arch tarballs shrink by ~17 MB and the amd64 tarball drops below GitHub's 50 MB warning. `installStamp` becomes `+android-drivers-2` so existing installs re-extract once.

## Review Focus

1. `grantiva hierarchy` on Android when the runner has died or never opened a UIAutomator2 session: the command must fail with a message naming `grantiva run --keep-alive`, and the forward it created must be removed. Pinned in Task 4 (`testAttachRemovesTheForwardWhenNoSessionExists`).
2. A label containing an apostrophe or double quote passed to `grantiva_tap`: the XPath must still be well-formed. Pinned in Task 4 (`testXPathLiteralHandlesBothQuoteKinds`).
3. `grantiva record --duration 200` on Android: refused before any device call, naming the 180-second cap. Pinned in Task 6 (`testAndroidRecordingOver180SecondsIsRefusedBeforeTouchingTheDevice`).
4. `grantiva emulator teardown --serial emulator-5556` for an emulator Grantiva did not start: refused without `--force`, killed with it. Pinned in Task 9 (`testTeardownRefusesAForeignSerialWithoutForce`, `testTeardownWithForceKillsAForeignSerial`).
5. `grantiva mcp` in a directory holding only `grantiva-android.yml`: the server starts and chooses the Android driver. Pinned in Task 10 (`testProjectDirectoryAcceptsAnAndroidOnlyProject`, `testLoadActiveSessionAcceptsAnADBSerial`).

## File structure

Created:
- `Sources/GrantivaCore/Android/UIAutomator2HierarchyParser.swift` — UIA2 XML → the shared hierarchy dictionary.
- `Sources/GrantivaCore/Android/UIAutomator2Client.swift` — forward, session discovery, `DriverClient.uiAutomator2`.
- `Sources/GrantivaCore/Runner/RecorderLifecycle.swift` — moved from `RecordCommand.swift`, now public.
- `Sources/GrantivaCLI/EmulatorCommand.swift` — `emulator ensure|delete|sessions|teardown`.
- `Sources/GrantivaMCP/Tools/EmulatorTools.swift` — the four MCP emulator tools.
- `Sources/GrantivaCore/Resources/android-drivers.tar.gz` — the two UIA2 APKs.
- Tests beside each.

Modified: `ADB.swift`, `AndroidProvenance.swift`, `EmulatorManager.swift`, `AndroidPlatform.swift`, `DevicePlatform.swift`, `IOSPlatform.swift`, `WDAClient.swift`, `PlatformResolver.swift`, `RunnerManager.swift`, `Package.swift`, `TargetOptions.swift`, `Options.swift`, `RecordCommand.swift`, `HierarchyCommand.swift`, `DriverCommand.swift`, `GrantivaCommand.swift`, `MCPServer.swift`, `ToolRegistry.swift`, `UITools.swift`, `BuildTools.swift`, `ContextTool.swift`, `VRTTools.swift`, `ScriptTools.swift`, `docs/android.md`, `CHANGELOG.md`, `README.md`.

---

### Task 1: adb forwards, screenrecord, and the provenance carry-forwards

**Files:**
- Modify: `Sources/GrantivaCore/Android/ADB.swift`
- Modify: `Sources/GrantivaCore/Android/AndroidProvenance.swift`
- Modify: `Sources/GrantivaCore/Android/AndroidPlatform.swift` (`cleanupOrphans`)
- Test: `Tests/GrantivaCoreTests/ADBTests.swift`, `Tests/GrantivaCoreTests/AndroidProvenanceTests.swift`, `Tests/GrantivaCoreTests/AndroidPlatformTests.swift`

**Interfaces:**
- Consumes: `ADB.line(_:_:)`, `shellQuoted`, `ScriptedShell`.
- Produces:
  - `ADB.forward(serial:devicePort:) async throws -> Int`
  - `ADB.removeForward(serial:localPort:) async throws`
  - `ADB.forwards(serial:) async throws -> [Int]` and `static parseForwards(_:serial:) -> [Int]`
  - `ADB.removeForwards(serial:) async throws`
  - `ADB.screenrecord(serial:remotePath:seconds:) async throws`
  - `ADB.pull(serial:remotePath:to:) async throws`
  - `ADB.removeFile(serial:remotePath:) async throws`
  - `ADB.removeAllForwards` is deleted.
  - `AndroidProvenance.register` replaces by serial; `registerCreatedAVD(_:)`, `createdAVDs()`, `removeCreatedAVD(_:)` over `created-avds.json`.

- [ ] **Step 1: Write the failing ADB tests**

Append to `Tests/GrantivaCoreTests/ADBTests.swift`, inside the test class:

```swift
    func testForwardAllocatesALocalPortAndParsesIt() async throws {
        let shell = ScriptedShell([.success("61211\n")])
        let adb = ADB(path: "/sdk/platform-tools/adb", execute: shell.execute)
        let port = try await adb.forward(serial: "emulator-5554", devicePort: 6790)
        XCTAssertEqual(port, 61211)
        XCTAssertEqual(shell.commands, ["'/sdk/platform-tools/adb' -s 'emulator-5554' forward tcp:0 tcp:6790"])
    }

    func testForwardRejectsAnUnparseablePort() async {
        let shell = ScriptedShell([.success("error: device offline")])
        let adb = ADB(path: "/sdk/platform-tools/adb", execute: shell.execute)
        do {
            _ = try await adb.forward(serial: "emulator-5554", devicePort: 6790)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("Could not forward a local port to emulator-5554:6790"), "\(error)")
        }
    }

    func testParseForwardsKeepsOnlyThisSerial() {
        let output = """
        emulator-5554 tcp:61211 tcp:6790
        emulator-5556 tcp:61212 tcp:6790
        emulator-5554 tcp:7000 localabstract:uia2
        """
        XCTAssertEqual(ADB.parseForwards(output, serial: "emulator-5554"), [61211, 7000])
        XCTAssertEqual(ADB.parseForwards("", serial: "emulator-5554"), [])
    }

    func testRemoveForwardsListsThenRemovesEachOfThisSerial() async throws {
        let shell = ScriptedShell([.success("emulator-5554 tcp:61211 tcp:6790\nemulator-5556 tcp:61212 tcp:6790\nemulator-5554 tcp:7000 tcp:7000")])
        let adb = ADB(path: "/sdk/platform-tools/adb", execute: shell.execute)
        try await adb.removeForwards(serial: "emulator-5554")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --list",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:7000",
        ])
    }

    func testScreenrecordPullAndRemoveCommandLines() async throws {
        let shell = ScriptedShell()
        let adb = ADB(path: "/sdk/platform-tools/adb", execute: shell.execute)
        try await adb.screenrecord(serial: "emulator-5554", remotePath: "/sdcard/grantiva-record.mp4", seconds: 5)
        try await adb.pull(serial: "emulator-5554", remotePath: "/sdcard/grantiva-record.mp4", to: "/tmp/out dir/rec.mp4")
        try await adb.removeFile(serial: "emulator-5554", remotePath: "/sdcard/grantiva-record.mp4")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell screenrecord --time-limit 5 '/sdcard/grantiva-record.mp4'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' pull '/sdcard/grantiva-record.mp4' '/tmp/out dir/rec.mp4'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell rm -f '/sdcard/grantiva-record.mp4'",
        ])
    }
```

In the existing `testEveryCommandLineIsQuotedAndTargetsTheSerial`, delete the `try await adb.removeAllForwards(serial: serial)` call and its expected `forward --remove-all` line.

- [ ] **Step 2: Write the failing provenance tests**

Append to `Tests/GrantivaCoreTests/AndroidProvenanceTests.swift`:

```swift
    func testRegisterReplacesARecordWithTheSameSerial() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("prov-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let ledger = AndroidProvenance(directory: dir)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Old", pid: 11))
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "New", pid: 22))
        let all = try ledger.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.avd, "New")
        XCTAssertEqual(all.first?.pid, 22)
    }

    func testCreatedAVDLedgerRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("prov-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let ledger = AndroidProvenance(directory: dir)
        XCTAssertEqual(try ledger.createdAVDs(), [])
        try ledger.registerCreatedAVD("Pixel_8_API_35")
        try ledger.registerCreatedAVD("Pixel_8_API_35")
        try ledger.registerCreatedAVD("Pixel_7_API_34")
        XCTAssertEqual(try ledger.createdAVDs(), ["Pixel_8_API_35", "Pixel_7_API_34"])
        try ledger.removeCreatedAVD("Pixel_8_API_35")
        XCTAssertEqual(try ledger.createdAVDs(), ["Pixel_7_API_34"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(dir)/created-avds.json"))
    }
```

- [ ] **Step 3: Update the cleanupOrphans test**

In `Tests/GrantivaCoreTests/AndroidPlatformTests.swift`, replace `testCleanupOrphansForceStopsUIA2AndRemovesForwards` with:

```swift
    func testCleanupOrphansForceStopsUIA2AndRemovesOnlyThisSerialsForwards() async {
        let shell = ScriptedShell([
            .success(""), .success(""),
            .success("emulator-5554 tcp:61211 tcp:6790\nemulator-5556 tcp:61212 tcp:6790"),
        ])
        await platform(shell).cleanupOrphans(deviceID: "emulator-5554")
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'io.appium.uiautomator2.server'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell am force-stop 'io.appium.uiautomator2.server.test'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --list",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211",
        ])
    }
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `swift test --filter 'ADBTests|AndroidProvenanceTests|AndroidPlatformTests'`
Expected: compile errors for `forward(serial:devicePort:)`, `parseForwards`, `removeForwards`, `screenrecord`, `pull`, `removeFile`, `createdAVDs`.

- [ ] **Step 5: Implement the ADB additions**

In `Sources/GrantivaCore/Android/ADB.swift`, replace `removeAllForwards` with:

```swift
    /// `adb forward tcp:0 tcp:<devicePort>` prints the local port it chose.
    public func forward(serial: String, devicePort: Int) async throws -> Int {
        let output = try await execute(line(serial, "forward tcp:0 tcp:\(devicePort)"))
        guard let port = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)), port > 0 else {
            throw GrantivaError.commandFailed("Could not forward a local port to \(serial):\(devicePort): \(output)", 1)
        }
        return port
    }

    public func removeForward(serial: String, localPort: Int) async throws {
        _ = try await execute(line(serial, "forward --remove tcp:\(localPort)"))
    }

    /// Local tcp ports forwarded for `serial`, from `adb forward --list`.
    public func forwards(serial: String) async throws -> [Int] {
        Self.parseForwards(try await execute(line(serial, "forward --list")), serial: serial)
    }

    /// Lines look like `<serial> tcp:<local> tcp:<remote>`; only this serial's
    /// `tcp:` locals count. `--remove-all` is host-wide, so it is never used.
    public static func parseForwards(_ output: String, serial: String) -> [Int] {
        output.components(separatedBy: "\n").compactMap { raw in
            let fields = raw.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count >= 2, fields[0] == serial, fields[1].hasPrefix("tcp:") else { return nil }
            return Int(fields[1].dropFirst(4))
        }
    }

    public func removeForwards(serial: String) async throws {
        for port in try await forwards(serial: serial) {
            try await removeForward(serial: serial, localPort: port)
        }
    }

    /// Blocks for `seconds`; screenrecord exits when its time limit elapses.
    public func screenrecord(serial: String, remotePath: String, seconds: Int) async throws {
        _ = try await execute(line(serial, "shell screenrecord --time-limit \(seconds) \(shellQuoted(remotePath))"))
    }

    public func pull(serial: String, remotePath: String, to localPath: String) async throws {
        _ = try await execute(line(serial, "pull \(shellQuoted(remotePath)) \(shellQuoted(localPath))"))
    }

    public func removeFile(serial: String, remotePath: String) async throws {
        _ = try await execute(line(serial, "shell rm -f \(shellQuoted(remotePath))"))
    }
```

In `AndroidPlatform.cleanupOrphans`, replace `_ = try? await adb.removeAllForwards(serial: deviceID)` with `_ = try? await adb.removeForwards(serial: deviceID)`.

- [ ] **Step 6: Implement the provenance changes**

In `Sources/GrantivaCore/Android/AndroidProvenance.swift`:

Replace `register`:

```swift
    /// A serial can be reused after an emulator exits, so a new record for
    /// the same serial replaces the old one instead of being dropped.
    public func register(_ record: StartedEmulatorRecord) throws {
        try withLedgerLock { records in
            records.removeAll { $0.serial == record.serial }
            records.append(record)
        }
    }
```

Add, after `all()`:

```swift
    // MARK: Created AVDs

    private var createdPath: String { "\(directory)/created-avds.json" }

    /// AVDs `emulator ensure` created. `emulator delete` refuses any other
    /// AVD without `--force`.
    public func registerCreatedAVD(_ name: String) throws {
        try withCreatedLock { names in
            guard !names.contains(name) else { return }
            names.append(name)
        }
    }

    public func createdAVDs() throws -> [String] {
        try withCreatedLock { $0 }
    }

    public func removeCreatedAVD(_ name: String) throws {
        try withCreatedLock { $0.removeAll { $0 == name } }
    }

    @discardableResult
    private func withCreatedLock<T>(_ body: (inout [String]) throws -> T) throws -> T {
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
        var names: [String] = []
        if let data = FileManager.default.contents(atPath: createdPath), !data.isEmpty {
            names = try JSONDecoder().decode([String].self, from: data)
        }
        let result = try body(&names)
        try JSONEncoder().encode(names).write(to: URL(fileURLWithPath: createdPath), options: .atomic)
        return result
    }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `swift test --filter 'ADBTests|AndroidProvenanceTests|AndroidPlatformTests'`
Expected: PASS, and `grep -rn removeAllForwards Sources Tests` prints nothing.

- [ ] **Step 8: Commit**

```bash
git add Sources/GrantivaCore/Android/ADB.swift Sources/GrantivaCore/Android/AndroidProvenance.swift Sources/GrantivaCore/Android/AndroidPlatform.swift Tests/GrantivaCoreTests/ADBTests.swift Tests/GrantivaCoreTests/AndroidProvenanceTests.swift Tests/GrantivaCoreTests/AndroidPlatformTests.swift
git commit -m "Scope adb forward removal to the serial, add forward and screenrecord helpers, replace ledger records by serial"
```

---

### Task 2: Flag and log carry-forwards from Plan 2

**Files:**
- Modify: `Sources/GrantivaCLI/TargetOptions.swift` (`checkFlags`)
- Modify: `Sources/GrantivaCore/Android/AndroidPlatform.swift` (`logStream`, `resolveBinary`)
- Test: `Tests/GrantivaCLITests/TargetOptionsTests.swift`, `Tests/GrantivaCoreTests/AndroidPlatformTests.swift`

**Interfaces:**
- Consumes: `TargetOptions.checkFlags(for:derivedDataPath:logsPredicate:logsTag:)`, `AndroidSDK.javaHome`.
- Produces: no new signatures. Behaviour: `--device` with `--emulator` is rejected; `--logs-level` without `--logs-tag` filters logcat with `*:<P>`; `apkanalyzer` runs with `JAVA_HOME` set when one is known.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/GrantivaCLITests/TargetOptionsTests.swift`:

```swift
    func testDeviceAndEmulatorTogetherAreRejected() throws {
        let target = try TargetOptions.parse(["--device", "emulator-5554", "--emulator", "Pixel_8_API_35"])
        XCTAssertThrowsError(try target.checkFlags(for: .android, derivedDataPath: nil)) { error in
            XCTAssertTrue("\(error)".contains("--device and --emulator are mutually exclusive"), "\(error)")
        }
    }
```

Append to `Tests/GrantivaCoreTests/AndroidPlatformTests.swift`:

```swift
    func testLogStreamWithALevelAndNoTagFiltersEveryTagAtThatPriority() async throws {
        let shell = ScriptedShell([.success(""), .success("package:com.example uid:10123")])
        let stream = try await platform(shell).logStream(deviceID: "emulator-5554", appID: "com.example", filter: nil, level: "warning")
        XCTAssertEqual(stream.arguments, ["-s", "emulator-5554", "logcat", "--uid=10123", "-v", "time", "-s", "*:W"])
    }

    func testResolveBinaryRunsApkanalyzerWithJavaHomeWhenKnown() async throws {
        let apk = scratch.appendingPathComponent("app.apk").path
        FileManager.default.createFile(atPath: apk, contents: Data())
        let shell = ScriptedShell([.success("/jdk\n"), .success("com.example.app\n")])
        let sdk = AndroidSDK(root: "/sdk")
        let adb = ADB(path: sdk.adb, execute: shell.execute)
        let p = AndroidPlatform(
            sdk: sdk, adb: adb, gradle: GradleBuildRunner(execute: shell.execute),
            emulators: EmulatorManager(sdk: sdk, adb: adb, execute: shell.execute, spawn: { _, _ in 1 },
                                       provenance: AndroidProvenance(directory: scratch.path), bootTimeout: 1, pollInterval: 0.01),
            captureSettings: AndroidCaptureSettings(adb: adb, stateDirectory: scratch.path),
            execute: shell.execute, environment: ["PATH": "/usr/bin"]
        )
        let resolved = try await p.resolveBinary(apk)
        XCTAssertEqual(resolved.appID, "com.example.app")
        XCTAssertEqual(shell.commands, [
            "/usr/libexec/java_home",
            "JAVA_HOME='/jdk' '/sdk/cmdline-tools/latest/bin/apkanalyzer' manifest application-id \(shellQuoted(apk))",
        ])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter 'TargetOptionsTests|AndroidPlatformTests'`
Expected: the three new tests FAIL (no mutual-exclusion error; arguments lack `*:W`; apkanalyzer line lacks `JAVA_HOME`).

- [ ] **Step 3: Implement**

In `TargetOptions.checkFlags`, after the `wrong.first` check and before the `DeviceID.validate` line:

```swift
        if device != nil, emulator != nil {
            throw GrantivaError.invalidArgument("--device and --emulator are mutually exclusive; pass one.")
        }
```

In `AndroidPlatform.logStream`, replace the `if let filter, !filter.isEmpty { ... }` block with:

```swift
        if let filter, !filter.isEmpty {
            if let level, let priority = level.first {
                args += ["-s", "\(filter):\(priority.uppercased())"]
            } else {
                args += ["-s", filter]
            }
        } else if let level, let priority = level.first {
            args += ["-s", "*:\(priority.uppercased())"]
        }
```

In `AndroidPlatform.resolveBinary`, replace the `let id = try? await execute(...)` statement with:

```swift
        let javaHome = await AndroidSDK.javaHome(environment: environment, execute: execute)
        let prefix = javaHome.map { "JAVA_HOME=\(shellQuoted($0)) " } ?? ""
        let id = try? await execute("\(prefix)\(shellQuoted(sdk.apkanalyzer)) manifest application-id \(shellQuoted(absolute))")
            .trimmingCharacters(in: .whitespacesAndNewlines)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter 'TargetOptionsTests|AndroidPlatformTests'`
Expected: PASS. If an existing `resolveBinary` test scripted only one shell answer, it now needs a first `.success("")` for `/usr/libexec/java_home` (an empty answer means "no JDK", and the apkanalyzer line then has no prefix); update that test's script and its expected command list accordingly.

- [ ] **Step 5: Commit**

```bash
git add Sources/GrantivaCLI/TargetOptions.swift Sources/GrantivaCore/Android/AndroidPlatform.swift Tests/GrantivaCLITests/TargetOptionsTests.swift Tests/GrantivaCoreTests/AndroidPlatformTests.swift
git commit -m "Reject --device with --emulator, honour --logs-level without a tag, run apkanalyzer with JAVA_HOME"
```

---

### Task 3: UIAutomator2 hierarchy parser

**Files:**
- Create: `Sources/GrantivaCore/Android/UIAutomator2HierarchyParser.swift`
- Test: `Tests/GrantivaCoreTests/UIAutomator2HierarchyParserTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `UIAutomator2HierarchyXMLParser(xml:scale:)` with `parse() throws -> [String: Any]` producing the same dictionary shape as `WDAHierarchyXMLParser` (`type`, `label`, `name`, `identifier`, `value`, `enabled`, `visible`, `frame` as `[String: String]` in dp, `children`), plus `clickable: Bool`, `package: String` where present, and `"platform": "android"` on the root. `UIAutomator2HierarchyXMLParser.parseBounds(_:) -> (x: Int, y: Int, width: Int, height: Int)?`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/GrantivaCoreTests/UIAutomator2HierarchyParserTests.swift`:

```swift
import XCTest
@testable import GrantivaCore

final class UIAutomator2HierarchyParserTests: XCTestCase {
    private let sample = """
    <?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
    <hierarchy index="0" class="hierarchy" rotation="0" width="1080" height="2400">
      <android.widget.FrameLayout index="0" package="dev.grantiva.example" class="android.widget.FrameLayout" text="" resource-id="" clickable="false" enabled="true" bounds="[0,0][1080,2400]" displayed="true">
        <android.view.View index="0" package="dev.grantiva.example" class="android.view.View" text="Details" content-desc="" resource-id="" clickable="false" enabled="true" bounds="[42,236][270,310]" displayed="true" />
        <android.widget.Button index="1" package="dev.grantiva.example" class="android.widget.Button" text="Settings" content-desc="Open settings" resource-id="dev.grantiva.example:id/settings" clickable="true" enabled="false" bounds="[540,2200][1080,2300]" displayed="false" />
      </android.widget.FrameLayout>
    </hierarchy>
    """

    func testParseBoundsReadsTheTwoCorners() {
        let b = UIAutomator2HierarchyXMLParser.parseBounds("[42,236][270,310]")
        XCTAssertEqual(b?.x, 42); XCTAssertEqual(b?.y, 236); XCTAssertEqual(b?.width, 228); XCTAssertEqual(b?.height, 74)
        XCTAssertNil(UIAutomator2HierarchyXMLParser.parseBounds("nonsense"))
        XCTAssertNil(UIAutomator2HierarchyXMLParser.parseBounds(""))
    }

    func testRootIsTaggedAndroidAndNodesMapOntoTheSharedShape() throws {
        let root = try UIAutomator2HierarchyXMLParser(xml: sample, scale: 2.625).parse()
        XCTAssertEqual(root["type"] as? String, "hierarchy")
        XCTAssertEqual(root["platform"] as? String, "android")
        let frame = try XCTUnwrap((root["children"] as? [[String: Any]])?.first)
        XCTAssertEqual(frame["type"] as? String, "android.widget.FrameLayout")
        XCTAssertEqual(frame["package"] as? String, "dev.grantiva.example")
        XCTAssertNil(frame["label"], "an empty text and no content-desc give no label")
        let children = try XCTUnwrap(frame["children"] as? [[String: Any]])
        XCTAssertEqual(children.count, 2)

        let text = children[0]
        XCTAssertEqual(text["label"] as? String, "Details", "label falls back to text")
        XCTAssertNil(text["name"])
        XCTAssertEqual(text["value"] as? String, "Details")
        XCTAssertEqual(text["clickable"] as? Bool, false)
        XCTAssertEqual(text["visible"] as? Bool, true)
        XCTAssertEqual(text["frame"] as? [String: String], ["x": "16", "y": "90", "width": "87", "height": "28"], "pixels / 2.625, rounded")

        let button = children[1]
        XCTAssertEqual(button["label"] as? String, "Open settings", "content-desc wins over text")
        XCTAssertEqual(button["name"] as? String, "Open settings")
        XCTAssertEqual(button["identifier"] as? String, "dev.grantiva.example:id/settings")
        XCTAssertEqual(button["value"] as? String, "Settings")
        XCTAssertEqual(button["enabled"] as? Bool, false)
        XCTAssertEqual(button["visible"] as? Bool, false)
        XCTAssertEqual(button["clickable"] as? Bool, true)
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: root))
    }

    func testScaleOneKeepsPixels() throws {
        let root = try UIAutomator2HierarchyXMLParser(xml: sample, scale: 1).parse()
        let text = try XCTUnwrap(((root["children"] as? [[String: Any]])?.first?["children"] as? [[String: Any]])?.first)
        XCTAssertEqual(text["frame"] as? [String: String], ["x": "42", "y": "236", "width": "228", "height": "74"])
    }

    func testMalformedXMLThrows() {
        XCTAssertThrowsError(try UIAutomator2HierarchyXMLParser(xml: "<hierarchy><broken>", scale: 1).parse())
    }

    func testNodeWithoutBoundsHasNoFrame() throws {
        let root = try UIAutomator2HierarchyXMLParser(xml: #"<hierarchy><android.view.View class="android.view.View" text="x"/></hierarchy>"#, scale: 1).parse()
        let child = try XCTUnwrap((root["children"] as? [[String: Any]])?.first)
        XCTAssertNil(child["frame"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter UIAutomator2HierarchyParserTests`
Expected: compile error, `UIAutomator2HierarchyXMLParser` undefined.

- [ ] **Step 3: Implement the parser**

Create `Sources/GrantivaCore/Android/UIAutomator2HierarchyParser.swift`:

```swift
import Foundation

/// Parses the UIAutomator2 page source into the same dictionary tree
/// `WDAHierarchyXMLParser` produces, so `dump-hierarchy`, the MCP tools, and
/// the a11y rules read one shape on both platforms.
///
/// Mapping: `class` → `type`; `content-desc` then `text` → `label`;
/// `content-desc` → `name`; `resource-id` → `identifier`; `text` → `value`;
/// `enabled`, `displayed` → `enabled`, `visible`; `clickable` → `clickable`;
/// `bounds="[x1,y1][x2,y2]"` (pixels) → `frame` in dp using `scale`.
public final class UIAutomator2HierarchyXMLParser: NSObject, XMLParserDelegate {
    private let xml: String
    private let scale: Double
    private var stack: [NSMutableDictionary] = []
    private var root: [String: Any] = [:]
    private var conversionFailed = false

    public init(xml: String, scale: Double) {
        self.xml = xml
        self.scale = scale > 0 ? scale : 1
    }

    public func parse() throws -> [String: Any] {
        guard let data = xml.data(using: .utf8) else {
            throw GrantivaError.commandFailed("Failed to encode UIAutomator2 hierarchy XML", 1)
        }
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), !conversionFailed, !root.isEmpty else {
            let detail = parser.parserError?.localizedDescription ?? "unexpected hierarchy structure"
            throw GrantivaError.commandFailed("Failed to parse UIAutomator2 hierarchy XML: \(detail)", 1)
        }
        return root
    }

    /// `[x1,y1][x2,y2]` → origin and size in pixels.
    public static func parseBounds(_ value: String) -> (x: Int, y: Int, width: Int, height: Int)? {
        let numbers = value.split(whereSeparator: { !$0.isNumber && $0 != "-" }).compactMap { Int($0) }
        guard numbers.count == 4 else { return nil }
        return (numbers[0], numbers[1], numbers[2] - numbers[0], numbers[3] - numbers[1])
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?,
                       attributes: [String: String]) {
        let node = NSMutableDictionary()
        node["type"] = attributes["class"].flatMap { $0.isEmpty ? nil : $0 } ?? elementName
        if stack.isEmpty { node["platform"] = "android" }

        let text = attributes["text"] ?? ""
        let desc = attributes["content-desc"] ?? ""
        if !desc.isEmpty {
            node["label"] = desc
            node["name"] = desc
        } else if !text.isEmpty {
            node["label"] = text
        }
        if let id = attributes["resource-id"], !id.isEmpty { node["identifier"] = id }
        if !text.isEmpty { node["value"] = text }
        if let package = attributes["package"], !package.isEmpty { node["package"] = package }
        if let enabled = attributes["enabled"] { node["enabled"] = enabled == "true" }
        if let displayed = attributes["displayed"] { node["visible"] = displayed == "true" }
        if let clickable = attributes["clickable"] { node["clickable"] = clickable == "true" }
        if let bounds = attributes["bounds"], let b = Self.parseBounds(bounds) {
            func dp(_ px: Int) -> String { String(Int((Double(px) / scale).rounded())) }
            node["frame"] = ["x": dp(b.x), "y": dp(b.y), "width": dp(b.width), "height": dp(b.height)]
        }
        node["children"] = NSMutableArray()

        if let parent = stack.last {
            (parent["children"] as? NSMutableArray)?.add(node)
        }
        stack.append(node)
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                       namespaceURI: String?, qualifiedName: String?) {
        if let finished = stack.popLast(), stack.isEmpty {
            guard let dictionary = finished as? [String: Any] else {
                conversionFailed = true
                return
            }
            root = dictionary
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter UIAutomator2HierarchyParserTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/GrantivaCore/Android/UIAutomator2HierarchyParser.swift Tests/GrantivaCoreTests/UIAutomator2HierarchyParserTests.swift
git commit -m "Parse the UIAutomator2 hierarchy into the shared tree shape"
```

---

### Task 4: `DriverClient` and the UIAutomator2 client

**Files:**
- Modify: `Sources/GrantivaCore/WDA/WDAClient.swift` (rename the struct, keep the file)
- Create: `Sources/GrantivaCore/Android/UIAutomator2Client.swift`
- Modify: `Sources/GrantivaMCP/MCPServer.swift`, `ToolRegistry.swift`, `Tools/UITools.swift`, `Tools/ScriptTools.swift`, `Tests/GrantivaMCPTests/MCPTestSupport.swift`, `Tests/GrantivaMCPTests/ToolErrorContractTests.swift`, `Tests/GrantivaCoreTests/WDAClientTests.swift` — spelling only (`WDAClient` → `DriverClient`, `WDAClient.live(port:)` → `DriverClient.wda(port:)`, `WDAClient.failing` → `DriverClient.failing`).
- Test: `Tests/GrantivaCoreTests/UIAutomator2ClientTests.swift`

**Interfaces:**
- Consumes: `ADB.forward/removeForward` (Task 1), `UIAutomator2HierarchyXMLParser` (Task 3), `WDAClient.elementID(from:)`.
- Produces:
  - `public struct DriverClient` (fields and init exactly as today's `WDAClient`), `public typealias WDAClient = DriverClient`, `DriverClient.wda(port:)` (body of today's `live(port:)`), `DriverClient.live(port:)` kept as a one-line forwarder, `DriverClient.failing`.
  - `public struct UIAutomator2Transport: Sendable { var send: @Sendable (URLRequest) async throws -> (Data, Int); static let live }`
  - `public struct UIAutomator2Endpoint: Sendable, Equatable { let localPort: Int; let sessionID: String; var baseURL: String }`
  - `public enum UIAutomator2 { static let devicePort = 6790; static func attach(adb:serial:transport:) async throws -> UIAutomator2Endpoint; static func endpoint(localPort:serial:transport:) async throws -> UIAutomator2Endpoint; static func sessionID(localPort:transport:) async throws -> String?; static func xpathLiteral(_:) -> String; static func labelXPath(_:) -> String }`
  - `DriverClient.uiAutomator2(endpoint:scale:transport:) -> DriverClient`

- [ ] **Step 1: Rename `WDAClient` to `DriverClient`**

In `Sources/GrantivaCore/WDA/WDAClient.swift`:
- `public struct WDAClient: Sendable {` → `public struct DriverClient: Sendable {` and update the doc comment to "HTTP client for a WebDriver-speaking UI driver: WebDriverAgent on iOS, the UIAutomator2 server on Android. Built from closures so tests substitute fakes."
- Add after the struct: `public typealias WDAClient = DriverClient`.
- `extension WDAClient { public static func live(port: UInt16) -> WDAClient {` → `extension DriverClient { public static func wda(port: UInt16) -> DriverClient {` with the same body (the returned type name inside the body changes to `DriverClient(`). Add below it:

```swift
    /// Kept for callers written against the old name.
    public static func live(port: UInt16) -> DriverClient { wda(port: port) }
```
- `extension WDAClient { public static let failing = WDAClient(` → `extension DriverClient { public static let failing = DriverClient(`.
- `static func elementID(from:)` stays where it is (it is `DriverClient.elementID` now; the WDA tests call `WDAClient.elementID`, which still resolves through the typealias).

Then in the MCP sources and tests listed above replace `WDAClient` with `DriverClient`, `WDAClient.live(port:` with `DriverClient.wda(port:`, and `WDAClient.failing` with `DriverClient.failing`. Keep parameter labels (`wda:`) as they are in this task; Task 10 renames them.

Run: `swift build && swift test --filter 'WDAClientTests|UIToolsTests|ScriptToolsTests'`
Expected: builds; tests PASS unchanged.

- [ ] **Step 2: Write the failing UIAutomator2 client tests**

Create `Tests/GrantivaCoreTests/UIAutomator2ClientTests.swift`:

```swift
import Foundation
import XCTest
@testable import GrantivaCore

/// Records every HTTP request and answers from a script. Mirrors ScriptedShell.
final class ScriptedTransport: @unchecked Sendable {
    struct Call: Equatable { let method: String; let path: String; let body: String }
    private let lock = NSLock()
    private var answers: [(Data, Int)]
    private var recorded: [Call] = []
    init(_ answers: [(String, Int)]) { self.answers = answers.map { (Data($0.0.utf8), $0.1) } }
    var calls: [Call] { lock.withLock { recorded } }
    var transport: UIAutomator2Transport {
        UIAutomator2Transport { request in
            self.lock.withLock {
                let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
                self.recorded.append(Call(method: request.httpMethod ?? "GET", path: request.url?.path ?? "", body: body))
                guard !self.answers.isEmpty else { return (Data("{}".utf8), 200) }
                return self.answers.removeFirst()
            }
        }
    }
}

final class UIAutomator2ClientTests: XCTestCase {
    private let sessions = #"{"sessionId":"None","value":[{"id":"abc-123","capabilities":{}}]}"#
    private let noSessions = #"{"sessionId":"None","value":[]}"#

    private func adb(_ shell: ScriptedShell) -> ADB { ADB(path: "/sdk/platform-tools/adb", execute: shell.execute) }

    func testAttachForwardsAPortAndReadsTheSessionID() async throws {
        let shell = ScriptedShell([.success("61211")])
        let transport = ScriptedTransport([(sessions, 200)])
        let endpoint = try await UIAutomator2.attach(adb: adb(shell), serial: "emulator-5554", transport: transport.transport)
        XCTAssertEqual(endpoint, UIAutomator2Endpoint(localPort: 61211, sessionID: "abc-123"))
        XCTAssertEqual(endpoint.baseURL, "http://127.0.0.1:61211/wd/hub")
        XCTAssertEqual(shell.commands, ["'/sdk/platform-tools/adb' -s 'emulator-5554' forward tcp:0 tcp:6790"])
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/sessions"])
    }

    /// Review Focus 1.
    func testAttachRemovesTheForwardWhenNoSessionExists() async {
        let shell = ScriptedShell([.success("61211"), .success("")])
        let transport = ScriptedTransport([(noSessions, 200)])
        do {
            _ = try await UIAutomator2.attach(adb: adb(shell), serial: "emulator-5554", transport: transport.transport)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("No UIAutomator2 session on emulator-5554"), "\(error)")
            XCTAssertTrue("\(error)".contains("grantiva run --keep-alive"), "\(error)")
        }
        XCTAssertEqual(shell.commands.last, "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211")
    }

    func testAttachRemovesTheForwardWhenTheServerDoesNotAnswer() async {
        let shell = ScriptedShell([.success("61211"), .success("")])
        let transport = UIAutomator2Transport { _ in throw URLError(.cannotConnectToHost) }
        do {
            _ = try await UIAutomator2.attach(adb: adb(shell), serial: "emulator-5554", transport: transport)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("not answering"), "\(error)")
        }
        XCTAssertEqual(shell.commands.count, 2)
    }

    func testEndpointForAKnownLocalPortSkipsTheForward() async throws {
        let shell = ScriptedShell()
        let transport = ScriptedTransport([(sessions, 200)])
        let endpoint = try await UIAutomator2.endpoint(localPort: 7000, serial: "emulator-5554", transport: transport.transport)
        XCTAssertEqual(endpoint.sessionID, "abc-123")
        XCTAssertTrue(shell.commands.isEmpty)
    }

    /// Review Focus 2.
    func testXPathLiteralHandlesBothQuoteKinds() {
        XCTAssertEqual(UIAutomator2.xpathLiteral("Sign in"), "\"Sign in\"")
        XCTAssertEqual(UIAutomator2.xpathLiteral("It's"), "\"It's\"")
        XCTAssertEqual(UIAutomator2.xpathLiteral("Say \"hi\""), "'Say \"hi\"'")
        XCTAssertEqual(UIAutomator2.xpathLiteral("It's \"ok\""), "concat(\"It's \", '\"', \"ok\", '\"', \"\")")
        XCTAssertEqual(UIAutomator2.labelXPath("Details"), "//*[@content-desc=\"Details\" or @text=\"Details\"]")
    }

    private func client(_ transport: ScriptedTransport, scale: Double = 2) -> DriverClient {
        DriverClient.uiAutomator2(endpoint: UIAutomator2Endpoint(localPort: 7000, sessionID: "abc-123"), scale: scale, transport: transport.transport)
    }

    func testHierarchyXMLUnwrapsTheValue() async throws {
        let transport = ScriptedTransport([(#"{"sessionId":"abc-123","value":"<hierarchy><android.view.View class=\"android.view.View\" text=\"Hi\" bounds=\"[0,0][20,40]\"/></hierarchy>"}"#, 200)])
        let xml = try await client(transport).hierarchyXML()
        XCTAssertTrue(xml.hasPrefix("<hierarchy>"))
        XCTAssertEqual(transport.calls, [.init(method: "GET", path: "/wd/hub/session/abc-123/source", body: "")])
    }

    func testHierarchyParsesWithTheScale() async throws {
        let transport = ScriptedTransport([(#"{"value":"<hierarchy><android.view.View class=\"android.view.View\" text=\"Hi\" bounds=\"[0,0][20,40]\"/></hierarchy>"}"#, 200)])
        let tree = try await client(transport, scale: 2).hierarchy()
        let child = try XCTUnwrap((tree["children"] as? [[String: Any]])?.first)
        XCTAssertEqual(child["frame"] as? [String: String], ["x": "0", "y": "0", "width": "10", "height": "20"])
    }

    func testTapByLabelFindsByXPathThenClicks() async throws {
        let transport = ScriptedTransport([
            (#"{"value":[{"ELEMENT":"e1","element-6066-11e4-a52e-4f735466cecf":"e1"}]}"#, 200),
            (#"{"value":null}"#, 200),
        ])
        try await client(transport).tapByLabel("Details")
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/session/abc-123/elements", "/wd/hub/session/abc-123/element/e1/click"])
        XCTAssertEqual(transport.calls[0].method, "POST")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transport.calls[0].body.utf8)) as? [String: String])
        XCTAssertEqual(body, ["strategy": "xpath", "selector": "//*[@content-desc=\"Details\" or @text=\"Details\"]"])
    }

    func testTapByLabelReportsAMissingElement() async {
        let transport = ScriptedTransport([(#"{"value":[]}"#, 200)])
        do {
            try await client(transport).tapByLabel("Nope")
            XCTFail("expected an error")
        } catch let error as GrantivaError {
            guard case .elementNotFound("Nope") = error else { return XCTFail("\(error)") }
        } catch { XCTFail("\(error)") }
    }

    func testTapByCoordinateSendsPixelPointerActions() async throws {
        let transport = ScriptedTransport([(#"{"value":null}"#, 200)])
        try await client(transport).tapByCoordinate(540, 1200)
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/session/abc-123/actions"])
        XCTAssertTrue(transport.calls[0].body.contains(#""x":540"#), transport.calls[0].body)
        XCTAssertTrue(transport.calls[0].body.contains(#""pointerType":"touch""#), transport.calls[0].body)
    }

    func testTypeTextSendsKeyActionsPerCharacter() async throws {
        let transport = ScriptedTransport([(#"{"value":null}"#, 200)])
        try await client(transport).typeText("hi")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transport.calls[0].body.utf8)) as? [String: Any])
        let actions = try XCTUnwrap((body["actions"] as? [[String: Any]])?.first)
        XCTAssertEqual(actions["type"] as? String, "key")
        let steps = try XCTUnwrap(actions["actions"] as? [[String: String]])
        XCTAssertEqual(steps, [
            ["type": "keyDown", "value": "h"], ["type": "keyUp", "value": "h"],
            ["type": "keyDown", "value": "i"], ["type": "keyUp", "value": "i"],
        ])
    }

    func testSwipeReadsTheWindowSizeInPixels() async throws {
        let transport = ScriptedTransport([(#"{"value":{"width":1080,"height":2400}}"#, 200), (#"{"value":null}"#, 200)])
        try await client(transport).swipe("up")
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/session/abc-123/window/current/size", "/wd/hub/session/abc-123/actions"])
        XCTAssertTrue(transport.calls[1].body.contains(#""y":1680"#), "0.7 * 2400: \(transport.calls[1].body)")
        XCTAssertTrue(transport.calls[1].body.contains(#""y":720"#), "0.3 * 2400: \(transport.calls[1].body)")
    }

    func testSwipeRejectsAnUnknownDirection() async {
        let transport = ScriptedTransport([(#"{"value":{"width":1080,"height":2400}}"#, 200)])
        do {
            try await client(transport).swipe("sideways")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("Invalid swipe direction"), "\(error)")
        }
    }

    func testScreenshotDecodesBase64() async throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString()
        let transport = ScriptedTransport([(#"{"value":"\#(png)"}"#, 200)])
        let data = try await client(transport).screenshot()
        XCTAssertEqual([UInt8](data), [0x89, 0x50, 0x4E, 0x47])
        XCTAssertEqual(transport.calls.map(\.path), ["/wd/hub/session/abc-123/screenshot"])
    }

    func testStatusReportsReadyAndTheSession() async throws {
        let transport = ScriptedTransport([(#"{"sessionId":"None","value":{"ready":true}}"#, 200)])
        let status = try await client(transport).status()
        XCTAssertEqual(status.sessionId, "abc-123")
        XCTAssertTrue(status.ready)
    }

    func testANon200AnswerIsAnError() async {
        let transport = ScriptedTransport([(#"{"value":{"error":"unknown command"}}"#, 404)])
        do {
            _ = try await client(transport).hierarchyXML()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("HTTP 404"), "\(error)")
        }
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter UIAutomator2ClientTests`
Expected: compile errors for `UIAutomator2`, `UIAutomator2Transport`, `UIAutomator2Endpoint`, `DriverClient.uiAutomator2`.

- [ ] **Step 4: Implement the client**

Create `Sources/GrantivaCore/Android/UIAutomator2Client.swift`:

```swift
import Foundation

/// One HTTP round trip. Injected so the client is testable without a socket.
public struct UIAutomator2Transport: Sendable {
    public var send: @Sendable (URLRequest) async throws -> (Data, Int)

    public init(send: @escaping @Sendable (URLRequest) async throws -> (Data, Int)) {
        self.send = send
    }

    public static let live = UIAutomator2Transport { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// A forwarded local port and the session the runner holds on the device.
public struct UIAutomator2Endpoint: Sendable, Equatable {
    public let localPort: Int
    public let sessionID: String

    public init(localPort: Int, sessionID: String) {
        self.localPort = localPort
        self.sessionID = sessionID
    }

    public var baseURL: String { "http://127.0.0.1:\(localPort)/wd/hub" }
}

/// Talks to the UIAutomator2 server directly: the runner does not proxy it
/// (spike result, 2026-10-07). The server listens on device port 6790; the
/// CLI forwards a local port to it and reuses the runner's session.
public enum UIAutomator2 {
    public static let devicePort = 6790

    /// Forwards a fresh local port and finds the runner's session. On any
    /// failure the forward is removed again so nothing leaks.
    public static func attach(
        adb: ADB, serial: String, transport: UIAutomator2Transport = .live
    ) async throws -> UIAutomator2Endpoint {
        let port = try await adb.forward(serial: serial, devicePort: devicePort)
        do {
            return try await endpoint(localPort: port, serial: serial, transport: transport)
        } catch {
            _ = try? await adb.removeForward(serial: serial, localPort: port)
            throw error
        }
    }

    /// For a port forwarded earlier (`runner start` records it).
    public static func endpoint(
        localPort: Int, serial: String, transport: UIAutomator2Transport = .live
    ) async throws -> UIAutomator2Endpoint {
        let sessionID: String?
        do {
            sessionID = try await self.sessionID(localPort: localPort, transport: transport)
        } catch {
            throw GrantivaError.commandFailed(
                "The UIAutomator2 server on \(serial) is not answering on local port \(localPort): \(error.localizedDescription)", 1
            )
        }
        guard let sessionID else {
            throw GrantivaError.invalidArgument(
                "No UIAutomator2 session on \(serial). Hold one with `grantiva run --keep-alive` or `grantiva runner start` first."
            )
        }
        return UIAutomator2Endpoint(localPort: localPort, sessionID: sessionID)
    }

    /// `GET /wd/hub/sessions` → the first session id, or nil when the server
    /// is up but holds none.
    public static func sessionID(localPort: Int, transport: UIAutomator2Transport = .live) async throws -> String? {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(localPort)/wd/hub/sessions")!, timeoutInterval: 10)
        request.httpMethod = "GET"
        let (data, status) = try await transport.send(request)
        guard status == 200 else {
            throw GrantivaError.commandFailed("GET /wd/hub/sessions failed (HTTP \(status))", 1)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let sessions = json["value"] as? [[String: Any]] ?? []
        return sessions.first?["id"] as? String ?? sessions.first?["sessionId"] as? String
    }

    /// An XPath 1.0 string literal for `value`: double-quoted when it has no
    /// double quote, single-quoted when it has no single quote, else a
    /// `concat()` of double-quoted pieces joined by `'"'`.
    public static func xpathLiteral(_ value: String) -> String {
        if !value.contains("\"") { return "\"\(value)\"" }
        if !value.contains("'") { return "'\(value)'" }
        let parts = value.split(separator: "\"", omittingEmptySubsequences: false).map { "\"\($0)\"" }
        return "concat(" + parts.joined(separator: ", '\"', ") + ")"
    }

    /// Matches a node by accessibility description or visible text.
    public static func labelXPath(_ label: String) -> String {
        let literal = xpathLiteral(label)
        return "//*[@content-desc=\(literal) or @text=\(literal)]"
    }
}

/// The HTTP verbs the Android driver uses, as free functions so the
/// closures in `DriverClient.uiAutomator2` stay short.
enum UIAutomator2Requests {
    static func send(
        _ transport: UIAutomator2Transport, _ method: String, _ url: String,
        _ body: [String: Any]? = nil, failure: String
    ) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: url)!, timeoutInterval: 60)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, status) = try await transport.send(request)
        guard status == 200 else {
            throw GrantivaError.commandFailed("\(failure) (HTTP \(status))", 1)
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    static func sourceXML(_ transport: UIAutomator2Transport, session: String) async throws -> String {
        let json = try await send(transport, "GET", "\(session)/source", failure: "Failed to get hierarchy from UIAutomator2")
        guard let xml = json["value"] as? String, !xml.isEmpty else {
            throw GrantivaError.commandFailed("Empty hierarchy response", 1)
        }
        return xml
    }

    static func pointer(_ transport: UIAutomator2Transport, session: String, _ steps: [[String: Any]], failure: String) async throws {
        let body: [String: Any] = [
            "actions": [
                ["type": "pointer", "id": "finger1", "parameters": ["pointerType": "touch"], "actions": steps] as [String: Any]
            ]
        ]
        _ = try await send(transport, "POST", "\(session)/actions", body, failure: failure)
    }
}

extension DriverClient {
    /// The Android driver. Coordinates are device pixels; `scale` converts
    /// hierarchy bounds to dp.
    public static func uiAutomator2(
        endpoint: UIAutomator2Endpoint, scale: Double, transport: UIAutomator2Transport = .live
    ) -> DriverClient {
        let base = endpoint.baseURL
        let session = "\(base)/session/\(endpoint.sessionID)"
        typealias R = UIAutomator2Requests

        return DriverClient(
            status: {
                let json = try await R.send(transport, "GET", "\(base)/status", failure: "UIAutomator2 not responding on port \(endpoint.localPort)")
                let ready = (json["value"] as? [String: Any])?["ready"] as? Bool ?? false
                return WDAStatus(sessionId: endpoint.sessionID, ready: ready)
            },
            hierarchy: {
                try UIAutomator2HierarchyXMLParser(xml: try await R.sourceXML(transport, session: session), scale: scale).parse()
            },
            hierarchyXML: { try await R.sourceXML(transport, session: session) },
            tapByLabel: { label in
                let found = try await R.send(
                    transport, "POST", "\(session)/elements",
                    ["strategy": "xpath", "selector": UIAutomator2.labelXPath(label)],
                    failure: "Failed to look up \"\(label)\""
                )
                guard let elements = found["value"] as? [[String: Any]], let first = elements.first,
                      let id = DriverClient.elementID(from: first) else {
                    throw GrantivaError.elementNotFound(label)
                }
                _ = try await R.send(transport, "POST", "\(session)/element/\(id)/click", [:], failure: "Failed to tap element \"\(label)\"")
            },
            tapByCoordinate: { x, y in
                try await R.pointer(transport, session: session, [
                    ["type": "pointerMove", "duration": 0, "x": Int(x), "y": Int(y)],
                    ["type": "pointerDown", "button": 0],
                    ["type": "pause", "duration": 100],
                    ["type": "pointerUp", "button": 0],
                ], failure: "Failed to tap at (\(x), \(y))")
            },
            typeText: { text in
                var steps: [[String: String]] = []
                for character in text {
                    steps.append(["type": "keyDown", "value": String(character)])
                    steps.append(["type": "keyUp", "value": String(character)])
                }
                let body: [String: Any] = ["actions": [["type": "key", "id": "kb", "actions": steps] as [String: Any]]]
                _ = try await R.send(transport, "POST", "\(session)/actions", body, failure: "Failed to type text")
            },
            swipe: { direction in
                let size = try await R.send(transport, "GET", "\(session)/window/current/size", failure: "Failed to read the window size")
                let value = size["value"] as? [String: Any] ?? [:]
                let width = (value["width"] as? NSNumber)?.doubleValue ?? 1080
                let height = (value["height"] as? NSNumber)?.doubleValue ?? 2400
                let (startX, startY, endX, endY): (Double, Double, Double, Double)
                switch direction.lowercased() {
                case "up": (startX, startY, endX, endY) = (width / 2, height * 0.7, width / 2, height * 0.3)
                case "down": (startX, startY, endX, endY) = (width / 2, height * 0.3, width / 2, height * 0.7)
                case "left": (startX, startY, endX, endY) = (width * 0.8, height / 2, width * 0.2, height / 2)
                case "right": (startX, startY, endX, endY) = (width * 0.2, height / 2, width * 0.8, height / 2)
                default:
                    throw GrantivaError.invalidArgument("Invalid swipe direction \"\(direction)\". Use: up, down, left, right")
                }
                try await R.pointer(transport, session: session, [
                    ["type": "pointerMove", "duration": 0, "x": Int(startX), "y": Int(startY)],
                    ["type": "pointerDown", "button": 0],
                    ["type": "pointerMove", "duration": 300, "x": Int(endX), "y": Int(endY)],
                    ["type": "pointerUp", "button": 0],
                ], failure: "Failed to swipe \(direction)")
            },
            screenshot: {
                let json = try await R.send(transport, "GET", "\(session)/screenshot", failure: "Failed to take screenshot via UIAutomator2")
                guard let base64 = json["value"] as? String, let data = Data(base64Encoded: base64) else {
                    throw GrantivaError.invalidImage
                }
                return data
            }
        )
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter 'UIAutomator2ClientTests|WDAClientTests'`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/GrantivaCore/WDA/WDAClient.swift Sources/GrantivaCore/Android/UIAutomator2Client.swift Sources/GrantivaMCP Tests/GrantivaMCPTests/MCPTestSupport.swift Tests/GrantivaMCPTests/ToolErrorContractTests.swift Tests/GrantivaCoreTests/WDAClientTests.swift Tests/GrantivaCoreTests/UIAutomator2ClientTests.swift
git commit -m "Rename WDAClient to DriverClient and add the UIAutomator2 driver over a forwarded port"
```

---

### Task 5: `attachDriver` and `recordVideo` on `DevicePlatform`; `resolveOrDefault`

**Files:**
- Modify: `Sources/GrantivaCore/Platform/DevicePlatform.swift`
- Modify: `Sources/GrantivaCore/Platform/IOSPlatform.swift`
- Modify: `Sources/GrantivaCore/Android/AndroidPlatform.swift`
- Create: `Sources/GrantivaCore/Runner/RecorderLifecycle.swift` (moved out of `Sources/GrantivaCLI/RecordCommand.swift`, made public)
- Modify: `Sources/GrantivaCore/Platform/PlatformResolver.swift`, `Sources/GrantivaCLI/Options.swift`
- Modify: `Tests/GrantivaCLITests/Support/FakeDevicePlatform.swift`, `Tests/GrantivaCLITests/RecordCommandTests.swift` (import)
- Test: `Tests/GrantivaCoreTests/AndroidPlatformTests.swift`, `Tests/GrantivaCoreTests/IOSPlatformTests.swift`, `Tests/GrantivaCoreTests/PlatformResolverTests.swift`

**Interfaces:**
- Consumes: `UIAutomator2.attach/endpoint`, `DriverClient.uiAutomator2/wda`, `ADB.screenrecord/pull/removeFile`, `RecorderLifecycle`.
- Produces:
  - `public struct DriverAttachment: Sendable { let client: DriverClient; let port: Int; let detach: @Sendable () async -> Void }`
  - Protocol members: `func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment` and `func recordVideo(deviceID: String, to path: String, seconds: Double) async throws`.
  - `AndroidPlatform.attachDriver(deviceID:port:transport:)` (test seam), `AndroidPlatform.maximumRecordingSeconds = 180`, `AndroidPlatform.adb` and `AndroidPlatform.emulators` become `public let`.
  - `PlatformResolver.resolveOrDefault(flag:) throws -> Platform`.
  - `public enum RecorderLifecycle` in GrantivaCore with the same three static functions.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/GrantivaCoreTests/AndroidPlatformTests.swift`:

```swift
    func testAttachDriverWithoutAPortForwardsAndDetachRemovesIt() async throws {
        let shell = ScriptedShell([
            .success("61211"),                       // forward
            .success("Physical size: 1080x2400"),    // wm size
            .success("Physical density: 420"),       // wm density
            .success(""),                            // forward --remove
        ])
        let transport = UIAutomator2Transport { _ in (Data(#"{"value":[{"id":"s1"}]}"#.utf8), 200) }
        let p = platform(shell)
        let attachment = try await p.attachDriver(deviceID: "emulator-5554", port: nil, transport: transport)
        XCTAssertEqual(attachment.port, 61211)
        await attachment.detach()
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward tcp:0 tcp:6790",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'wm size'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'wm density'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' forward --remove tcp:61211",
        ])
    }

    func testAttachDriverWithAKnownPortDoesNotForwardAndDetachIsANoOp() async throws {
        let shell = ScriptedShell([.success("Physical size: 1080x2400"), .success("Physical density: 420")])
        let transport = UIAutomator2Transport { _ in (Data(#"{"value":[{"id":"s1"}]}"#.utf8), 200) }
        let attachment = try await platform(shell).attachDriver(deviceID: "emulator-5554", port: 7000, transport: transport)
        XCTAssertEqual(attachment.port, 7000)
        await attachment.detach()
        XCTAssertEqual(shell.commands.count, 2)
    }

    func testRecordVideoRecordsPullsAndRemoves() async throws {
        let shell = ScriptedShell()
        let out = scratch.appendingPathComponent("rec.mp4").path
        try await platform(shell).recordVideo(deviceID: "emulator-5554", to: out, seconds: 4.2)
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell screenrecord --time-limit 5 '/sdcard/grantiva-record.mp4'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' pull '/sdcard/grantiva-record.mp4' \(shellQuoted(out))",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell rm -f '/sdcard/grantiva-record.mp4'",
        ])
    }

    /// Review Focus 3.
    func testRecordVideoOver180SecondsIsRefusedBeforeTouchingTheDevice() async {
        let shell = ScriptedShell()
        do {
            try await platform(shell).recordVideo(deviceID: "emulator-5554", to: "/tmp/x.mp4", seconds: 200)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("Android recordings are capped at 180 seconds"), "\(error)")
        }
        XCTAssertTrue(shell.commands.isEmpty)
    }
```

Append to `Tests/GrantivaCoreTests/IOSPlatformTests.swift` (follow that file's existing helper for building an `IOSPlatform` with a scripted `execute`; if it has none, construct `IOSPlatform(execute: shell.execute)`):

```swift
    func testAttachDriverNeedsAPortAndReturnsWDA() async throws {
        let platform = IOSPlatform(execute: ScriptedExecutor([]).execute)
        let attachment = try await platform.attachDriver(deviceID: "921A0945-7157-4533-BA1F-21E8132D3E40", port: 8100)
        XCTAssertEqual(attachment.port, 8100)
        await attachment.detach()
        do {
            _ = try await platform.attachDriver(deviceID: "921A0945-7157-4533-BA1F-21E8132D3E40", port: nil)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("WebDriverAgent port"), "\(error)")
        }
    }
```

Append to `Tests/GrantivaCoreTests/PlatformResolverTests.swift`:

```swift
    func testResolveOrDefaultFallsBackToIOSWhenNothingPointsAnywhere() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("resolver-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let resolver = PlatformResolver(directory: dir, environment: [:])
        XCTAssertEqual(try resolver.resolveOrDefault(flag: nil), .ios)
        XCTAssertThrowsError(try resolver.resolve(flag: nil))
        try "platform: android\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try resolver.resolveOrDefault(flag: nil), .android)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter 'AndroidPlatformTests|IOSPlatformTests|PlatformResolverTests'`
Expected: compile errors (`attachDriver`, `recordVideo`, `resolveOrDefault`).

- [ ] **Step 3: Move `RecorderLifecycle` into GrantivaCore**

Cut the `enum RecorderLifecycle { ... }` block (with its doc comment) out of `Sources/GrantivaCLI/RecordCommand.swift` into a new file `Sources/GrantivaCore/Runner/RecorderLifecycle.swift`, with `import Foundation` and every declaration made `public` (`public enum RecorderLifecycle`, `public static func withCleanup`, `public static func waitForStart`, `public static func stop`; `waitForExit` stays private). `Tests/GrantivaCLITests/RecordCommandTests.swift` keeps `@testable import GrantivaCLI` and adds `import GrantivaCore`.

- [ ] **Step 4: Extend the protocol**

In `Sources/GrantivaCore/Platform/DevicePlatform.swift`, add before the protocol:

```swift
/// A driver client bound to a live session, plus how to let go of whatever
/// the platform set up to reach it (a port forward on Android, nothing on iOS).
public struct DriverAttachment: Sendable {
    public let client: DriverClient
    /// The local port the client talks to.
    public let port: Int
    public let detach: @Sendable () async -> Void

    public init(client: DriverClient, port: Int, detach: @escaping @Sendable () async -> Void) {
        self.client = client
        self.port = port
        self.detach = detach
    }
}
```

and add to the protocol after `cleanupOrphans`:

```swift
    /// A driver client for the session held on `deviceID`. `port` is the
    /// local port a previous attach (or `runner start`) recorded; nil or 0
    /// means "find it", which on Android forwards a new one.
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment
    /// Records the screen for `seconds` and leaves a video file at `path`.
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws
```

- [ ] **Step 5: Implement on iOS**

In `IOSPlatform`, add:

```swift
    public func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment {
        guard let port, port > 0 else {
            throw GrantivaError.invalidArgument("A WebDriverAgent port is required to attach to an iOS session.")
        }
        return DriverAttachment(client: .wda(port: port), port: Int(port), detach: {})
    }

    /// `simctl io recordVideo`, stopped with SIGINT so simctl finalizes the file.
    public func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {
        let outputURL = URL(fileURLWithPath: path)
        let recorder = Process()
        recorder.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        recorder.arguments = ["simctl", "io", deviceID, "recordVideo", "--codec=h264", path]
        let stderrURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-record-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: stderrURL) }
        let stderr = try FileHandle(forWritingTo: stderrURL)
        recorder.standardError = stderr
        do {
            try recorder.run()
            try await RecorderLifecycle.withCleanup(for: recorder) {
                try await RecorderLifecycle.waitForStart(of: outputURL)
                try await Task.sleep(for: .seconds(seconds))
            }
            try stderr.close()
        } catch {
            try? stderr.close()
            throw error
        }
        guard FileManager.default.fileExists(atPath: path) else {
            let message = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
            throw GrantivaError.commandFailed("Grantiva recording produced no video: \(message)", recorder.terminationStatus)
        }
    }
```

- [ ] **Step 6: Implement on Android**

In `AndroidPlatform`: change `private let adb: ADB` and `private let emulators: EmulatorManager` to `public let`. Add:

```swift
    public static let maximumRecordingSeconds = 180
    static let remoteRecordingPath = "/sdcard/grantiva-record.mp4"

    public func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment {
        try await attachDriver(deviceID: deviceID, port: port, transport: .live)
    }

    /// `transport` is the seam for tests; the protocol entry point uses the live one.
    public func attachDriver(deviceID: String, port: UInt16?, transport: UIAutomator2Transport) async throws -> DriverAttachment {
        let endpoint: UIAutomator2Endpoint
        let forwarded: Bool
        if let port, port > 0 {
            endpoint = try await UIAutomator2.endpoint(localPort: Int(port), serial: deviceID, transport: transport)
            forwarded = false
        } else {
            endpoint = try await UIAutomator2.attach(adb: adb, serial: deviceID, transport: transport)
            forwarded = true
        }
        let geometry: DeviceGeometry
        do {
            geometry = try await displayGeometry(deviceID: deviceID)
        } catch {
            if forwarded { _ = try? await adb.removeForward(serial: deviceID, localPort: endpoint.localPort) }
            throw error
        }
        let adb = self.adb
        return DriverAttachment(
            client: .uiAutomator2(endpoint: endpoint, scale: geometry.scale, transport: transport),
            port: endpoint.localPort,
            detach: { if forwarded { _ = try? await adb.removeForward(serial: deviceID, localPort: endpoint.localPort) } }
        )
    }

    /// `screenrecord` caps every file at 180 s; longer requests are refused
    /// up front rather than silently truncated.
    public func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {
        let whole = Int(seconds.rounded(.up))
        guard whole <= Self.maximumRecordingSeconds else {
            throw GrantivaError.invalidArgument(
                "Android recordings are capped at \(Self.maximumRecordingSeconds) seconds per file (screenrecord --time-limit); --duration \(Int(seconds)) is too long."
            )
        }
        try await adb.screenrecord(serial: deviceID, remotePath: Self.remoteRecordingPath, seconds: max(whole, 1))
        try await adb.pull(serial: deviceID, remotePath: Self.remoteRecordingPath, to: path)
        _ = try? await adb.removeFile(serial: deviceID, remotePath: Self.remoteRecordingPath)
    }
```

- [ ] **Step 7: Move the iOS default into the resolver**

In `PlatformResolver`, add:

```swift
    /// `resolve(flag:)`, except that when nothing at all points anywhere (no
    /// flag, no GRANTIVA_PLATFORM, no config file, no project files) the
    /// answer is iOS: before Android support every command was iOS and ran
    /// fine without a project here.
    public func resolveOrDefault(flag: Platform?) throws -> Platform {
        if flag == nil,
           (environment[Self.environmentKey] ?? "").isEmpty,
           existingConfigFiles().isEmpty,
           detectFromDirectory().isEmpty {
            return .ios
        }
        return try resolve(flag: flag)
    }
```

In `Sources/GrantivaCLI/Options.swift`, the body of `PlatformOptions.resolve` becomes one line (keep its doc comment):

```swift
        try PlatformResolver(directory: directory, environment: environment).resolveOrDefault(flag: platform)
```

- [ ] **Step 8: Update the CLI fake**

In `Tests/GrantivaCLITests/Support/FakeDevicePlatform.swift` add:

```swift
    var hierarchyXML = "<hierarchy><android.view.View class=\"android.view.View\" text=\"Fake\" bounds=\"[0,0][10,10]\"/></hierarchy>"
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment {
        record("attachDriver(\(deviceID),\(port.map(String.init) ?? "-"))")
        let xml = hierarchyXML
        let client = DriverClient(
            status: { WDAStatus(sessionId: "fake", ready: true) },
            hierarchy: { try UIAutomator2HierarchyXMLParser(xml: xml, scale: 1).parse() },
            hierarchyXML: { xml },
            tapByLabel: { _ in }, tapByCoordinate: { _, _ in }, typeText: { _ in }, swipe: { _ in },
            screenshot: { Data([0x89, 0x50, 0x4E, 0x47]) }
        )
        return DriverAttachment(client: client, port: Int(port ?? 7000), detach: { self.record("detach") })
    }
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws {
        record("recordVideo(\(deviceID),\(seconds))")
        FileManager.default.createFile(atPath: path, contents: Data())
    }
```

- [ ] **Step 9: Run the tests to verify they pass**

Run: `swift build && swift test --filter 'AndroidPlatformTests|IOSPlatformTests|PlatformResolverTests|PlatformOptionTests|RecordCommandTests'`
Expected: PASS. `RecordCommand` still compiles because it reaches `RecorderLifecycle` through `import GrantivaCore` (Task 6 rewrites it anyway).

- [ ] **Step 10: Commit**

```bash
git add Sources/GrantivaCore/Platform Sources/GrantivaCore/Android/AndroidPlatform.swift Sources/GrantivaCore/Runner/RecorderLifecycle.swift Sources/GrantivaCLI/RecordCommand.swift Sources/GrantivaCLI/Options.swift Tests/GrantivaCLITests/Support/FakeDevicePlatform.swift Tests/GrantivaCLITests/RecordCommandTests.swift Tests/GrantivaCoreTests/AndroidPlatformTests.swift Tests/GrantivaCoreTests/IOSPlatformTests.swift Tests/GrantivaCoreTests/PlatformResolverTests.swift
git commit -m "Add attachDriver and recordVideo to DevicePlatform, move RecorderLifecycle to Core, default the resolver to iOS"
```

---

### Task 6: `record` on Android

**Files:**
- Modify: `Sources/GrantivaCLI/RecordCommand.swift`
- Test: `Tests/GrantivaCLITests/RecordCommandTests.swift`

**Interfaces:**
- Consumes: `DevicePlatform.recordVideo/bootDevice/displayGeometry` (Task 5), `PlatformOptions.loadConfig`, `InjectedDevicePlatform`, `AndroidPlatform.maximumRecordingSeconds`.
- Produces: `RecordCommand.defaultOutput(for:) -> String`, `RecordCommand.target(platform:simulator:emulator:device:config:) throws -> String`. Flags: `--simulator` becomes optional; `--emulator`, `--device`, `--platform` added; `--output` default depends on platform.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/GrantivaCLITests/RecordCommandTests.swift` (add `import GrantivaCore` and `import ArgumentParser` at the top if missing):

```swift
    func testSimulatorIsOptionalAndTargetResolutionIsPerPlatform() throws {
        _ = try RecordCommand.parse(["--duration", "2"])
        XCTAssertEqual(RecordCommand.defaultOutput(for: .ios), ".grantiva/recordings/recording.mov")
        XCTAssertEqual(RecordCommand.defaultOutput(for: .android), ".grantiva/recordings/recording.mp4")

        XCTAssertEqual(try RecordCommand.target(platform: .ios, simulator: "iPhone 17", emulator: nil, device: nil, config: nil), "iPhone 17")
        XCTAssertEqual(try RecordCommand.target(platform: .ios, simulator: nil, emulator: nil, device: nil, config: GrantivaConfig(simulator: "iPhone 16")), "iPhone 16")
        XCTAssertThrowsError(try RecordCommand.target(platform: .ios, simulator: nil, emulator: nil, device: nil, config: nil)) { error in
            XCTAssertTrue("\(error)".contains("--simulator"), "\(error)")
        }
        XCTAssertThrowsError(try RecordCommand.target(platform: .ios, simulator: nil, emulator: "Pixel", device: nil, config: nil)) { error in
            XCTAssertTrue("\(error)".contains("--emulator is an Android option"), "\(error)")
        }
        XCTAssertEqual(try RecordCommand.target(platform: .android, simulator: nil, emulator: "Pixel", device: "emulator-5556", config: nil), "emulator-5556")
        XCTAssertEqual(try RecordCommand.target(platform: .android, simulator: nil, emulator: nil, device: nil,
                                                config: GrantivaConfig(platform: .android, android: AndroidProject(emulator: "Pixel_8_API_35"))), "Pixel_8_API_35")
        XCTAssertEqual(try RecordCommand.target(platform: .android, simulator: nil, emulator: nil, device: nil, config: nil), "")
        XCTAssertThrowsError(try RecordCommand.target(platform: .android, simulator: "iPhone", emulator: nil, device: nil, config: nil)) { error in
            XCTAssertTrue("\(error)".contains("--simulator is an iOS option"), "\(error)")
        }
    }

    /// Review Focus 3: the cap is enforced before any device call.
    func testAndroidRecordingOver180SecondsIsRefusedBeforeTouchingTheDevice() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "200"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        do {
            try await command.run()
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("capped at 180 seconds"), "\(error)")
        }
        XCTAssertTrue(fake.calls.isEmpty, "\(fake.calls)")
    }

    func testAndroidRecordGoesThroughThePlatformAndWritesTheReport() async throws {
        let dir = try makeAndroidProject()
        defer { restoreDirectory(dir) }
        var command = try RecordCommand.parse(["--duration", "1"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run()
        XCTAssertEqual(fake.calls, ["bootDevice(Pixel_8_API_35)", "recordVideo(emulator-5598,1.0)", "displayGeometry(emulator-5598)"])
        let report = try String(contentsOfFile: ".grantiva/recordings/recording.json", encoding: .utf8)
        XCTAssertTrue(report.contains(#""simulator" : "Fake""#), report)
        XCTAssertTrue(report.contains(#""video" : ".grantiva/recordings/recording.mp4""#), report)
    }

    private func makeAndroidProject() throws -> (URL, String) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("record-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "module: app\nemulator: Pixel_8_API_35\n".write(to: dir.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(dir.path)
        unsetenv("GRANTIVA_PLATFORM")
        return (dir, previous)
    }

    private func restoreDirectory(_ state: (URL, String)) {
        FileManager.default.changeCurrentDirectoryPath(state.1)
        try? FileManager.default.removeItem(at: state.0)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter RecordCommandTests`
Expected: compile errors (`defaultOutput`, `target`, `devicePlatform`; `--duration 2` alone fails to parse because `--simulator` is required).

- [ ] **Step 3: Rewrite the command**

Replace everything in `Sources/GrantivaCLI/RecordCommand.swift` from the top through the end of `struct RecordCommand` (the `RecorderLifecycle` enum moved out in Task 5; the private `RecordReport`, `RecordFrame`, and `JSONEncoder.pretty` types below it stay) with:

```swift
import ArgumentParser
import AVFoundation
import Foundation
import GrantivaCore
import ImageIO
import UniformTypeIdentifiers

/// Grantiva-owned device recording and timestamped frame extraction.
///
/// All device selection and capture mechanics stay in Grantiva: callers never
/// invoke simctl, adb, or Device Hub directly.
struct RecordCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Record a simulator or emulator and extract PNG frames at exact requested timestamps."
    )

    @OptionGroup var options: GlobalOptions
    @OptionGroup var platformOptions: PlatformOptions

    @Option(name: .long, help: "Simulator name or UDID to record (iOS; reads simulator from grantiva.yml if omitted)")
    var simulator: String?

    @Option(name: .long, help: "AVD name to record, booting it if needed (Android; reads emulator from grantiva-android.yml if omitted)")
    var emulator: String?

    @Option(name: .long, help: "adb serial of an attached emulator or device (Android)")
    var device: String?

    @Option(name: .long, help: "Recording duration in seconds (Android caps a recording at 180)")
    var duration: Double

    @Option(name: .long, help: "Output video path (default: .grantiva/recordings/recording.mov on iOS, .mp4 on Android)")
    var output: String?

    @Option(name: .long, help: "Comma-separated frame timestamps in milliseconds, e.g. 0,150,300,600")
    var framesAt: String?

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()

    static func defaultOutput(for platform: Platform) -> String {
        platform == .ios ? ".grantiva/recordings/recording.mov" : ".grantiva/recordings/recording.mp4"
    }

    /// The device name the platform boots. iOS needs a simulator; Android
    /// may leave it empty and let the platform pick the running emulator.
    static func target(platform: Platform, simulator: String?, emulator: String?, device: String?, config: GrantivaConfig?) throws -> String {
        switch platform {
        case .ios:
            if emulator != nil { throw GrantivaError.invalidArgument("--emulator is an Android option, but this is an iOS project.") }
            if device != nil { throw GrantivaError.invalidArgument("--device is an Android option, but this is an iOS project.") }
            guard let name = simulator ?? config?.simulator else {
                throw GrantivaError.invalidArgument("No simulator named. Pass --simulator or set simulator in grantiva.yml.")
            }
            return name
        case .android:
            if simulator != nil { throw GrantivaError.invalidArgument("--simulator is an iOS option, but this is an Android project.") }
            if device != nil, emulator != nil {
                throw GrantivaError.invalidArgument("--device and --emulator are mutually exclusive; pass one.")
            }
            if let device { _ = try DeviceID.validate(device, flag: "--device") }
            return device ?? emulator ?? config?.android?.emulator ?? ""
        }
    }

    func run() async throws {
        guard duration > 0 else {
            throw GrantivaError.invalidArgument("--duration must be greater than zero")
        }
        let (platform, config) = try platformOptions.loadConfig()
        let targetName = try Self.target(platform: platform, simulator: simulator, emulator: emulator, device: device, config: config)
        if platform == .android, Int(duration.rounded(.up)) > AndroidPlatform.maximumRecordingSeconds {
            throw GrantivaError.invalidArgument(
                "Android recordings are capped at \(AndroidPlatform.maximumRecordingSeconds) seconds per file (screenrecord --time-limit); --duration \(Int(duration)) is too long."
            )
        }
        let platformDevice = try devicePlatform.make(platform)
        let outputPath = output ?? Self.defaultOutput(for: platform)

        let booted = try await platformDevice.bootDevice(named: targetName)
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: outputURL)

        try await platformDevice.recordVideo(deviceID: booted.udid, to: outputPath, seconds: duration)
        guard FileManager.default.fileExists(atPath: outputPath) else {
            throw GrantivaError.commandFailed("Grantiva recording produced no video at \(outputPath)", 1)
        }

        let requested = try parseTimestamps()
        let geometry = try await platformDevice.displayGeometry(deviceID: booted.udid)
        let frames = try await extractFrames(
            from: outputURL,
            requestedMilliseconds: requested,
            expectedPixels: geometry.dimensions
        )
        let report = RecordReport(
            simulator: booted.name,
            udid: booted.udid,
            video: outputPath,
            requestedDurationSeconds: duration,
            frames: frames
        )
        let reportURL = outputURL.deletingPathExtension().appendingPathExtension("json")
        try JSONEncoder.pretty.encode(report).write(to: reportURL)

        if options.json {
            Output.line(try JSONOutput.string(report))
        } else {
            Output.line("Recording: \(outputPath)")
            Output.line("Frame report: \(reportURL.path)")
            for frame in frames {
                Output.line("  \(frame.requestedMilliseconds)ms -> \(frame.actualMilliseconds)ms: \(frame.path)")
            }
        }
    }
```

Keep `parseTimestamps()` and `extractFrames(from:requestedMilliseconds:expectedPixels:)` exactly as they are (they follow `run()` inside the struct). Delete the `var simulatorManager: SimulatorManager = .live` property and the `recorder`/`RecorderLifecycle` block that used to live in `run()`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter 'RecordCommandTests|RunCommandTests'`
Expected: PASS. `extractFrames` with no requested frames returns `[]` without opening the empty fake video, so the Android report test completes.

- [ ] **Step 5: Commit**

```bash
git add Sources/GrantivaCLI/RecordCommand.swift Tests/GrantivaCLITests/RecordCommandTests.swift
git commit -m "Record Android emulators with screenrecord through the platform"
```

---

### Task 7: `hierarchy` and `runner dump-hierarchy` on Android

**Files:**
- Modify: `Sources/GrantivaCore/Simulator/SimulatorUDID.swift` (`DeviceID.isAndroidSerial`)
- Modify: `Sources/GrantivaCLI/HierarchyCommand.swift`
- Modify: `Sources/GrantivaCLI/DriverCommand.swift` (`DumpHierarchyCommand` only)
- Test: `Tests/GrantivaCoreTests/SimulatorUDIDTests.swift`, `Tests/GrantivaCLITests/HierarchyCommandTests.swift`, `Tests/GrantivaCLITests/DumpHierarchyCommandTests.swift` (new)

**Interfaces:**
- Consumes: `DevicePlatform.attachDriver`, `DriverAttachment`, `KeepAliveSessionStore`, `RunnerSessionInfo`, `InjectedDevicePlatform`, `FakeDevicePlatform.attachDriver`.
- Produces:
  - `DeviceID.isAndroidSerial(_:) -> Bool` — an adb serial that is not a simulator UDID.
  - `HierarchyCommand.run(store:)`, `HierarchyCommand.runAndroid(serial:)`.
  - `DumpHierarchyCommand.Target { udid: String; port: UInt16? }` and `static func resolveTarget(port:runnerSession:keepAlive:) throws -> Target`.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/GrantivaCoreTests/SimulatorUDIDTests.swift`:

```swift
    func testIsAndroidSerialExcludesSimulatorUDIDs() {
        XCTAssertTrue(DeviceID.isAndroidSerial("emulator-5554"))
        XCTAssertTrue(DeviceID.isAndroidSerial("R58M12ABCDE"))
        XCTAssertTrue(DeviceID.isAndroidSerial("192.168.1.5:5555"))
        XCTAssertFalse(DeviceID.isAndroidSerial("921A0945-7157-4533-BA1F-21E8132D3E40"))
        XCTAssertFalse(DeviceID.isAndroidSerial(""))
        XCTAssertFalse(DeviceID.isAndroidSerial("../auth"))
    }
```

Append to `Tests/GrantivaCLITests/HierarchyCommandTests.swift` (inside the class; it already has `writeRunnerSession` and `temporaryDirectory` helpers):

```swift
    func testExplicitSerialLoadsItsSession() throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "android", in: directory)
        store.recordOwner(udid: "emulator-5554", runnerPid: 100)
        let command = try HierarchyCommand.parse(["--udid", "emulator-5554"])
        XCTAssertEqual(try command.locateSession(store: store).sessionId, "android")
    }

    func testAndroidSessionReadsTheHierarchyThroughThePlatformAndDetaches() async throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "android", in: directory)
        store.recordOwner(udid: "emulator-5554", runnerPid: 100)
        var command = try HierarchyCommand.parse(["--format", "json"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.run(store: store)
        XCTAssertEqual(fake.calls, ["attachDriver(emulator-5554,-)", "detach"])
    }

    func testAndroidSessionDetachesWhenTheReadFails() async throws {
        let directory = try temporaryDirectory()
        let store = KeepAliveSessionStore(directory: directory.path, isProcessAlive: { _ in true })
        try writeRunnerSession(pid: 100, nanos: 1, sessionId: "android", in: directory)
        store.recordOwner(udid: "emulator-5554", runnerPid: 100)
        var command = try HierarchyCommand.parse(["--format", "json"])
        let fake = FakeDevicePlatform(platform: .android)
        fake.hierarchyXML = "<hierarchy><broken>"
        command.devicePlatform = InjectedDevicePlatform(fake)
        await XCTAssertThrowsErrorAsync(try await command.run(store: store))
        XCTAssertEqual(fake.calls, ["attachDriver(emulator-5554,-)", "detach"])
    }
```

If `XCTAssertThrowsErrorAsync` does not exist in the CLI test target, add this helper at the bottom of `HierarchyCommandTests.swift`:

```swift
func XCTAssertThrowsErrorAsync(_ expression: @autoclosure () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do {
        try await expression()
        XCTFail("expected an error", file: file, line: line)
    } catch {}
}
```

Create `Tests/GrantivaCLITests/DumpHierarchyCommandTests.swift`:

```swift
import Foundation
import GrantivaCore
import XCTest
@testable import GrantivaCLI

@available(macOS 15, *)
final class DumpHierarchyCommandTests: XCTestCase {
    private let simulator = "921A0945-7157-4533-BA1F-21E8132D3E40"

    func testAnExplicitPortWins() throws {
        let target = try DumpHierarchyCommand.resolveTarget(port: 8100, runnerSession: nil, keepAlive: nil)
        XCTAssertEqual(target.udid, "")
        XCTAssertEqual(target.port, 8100)
    }

    func testARunnerStartSessionCarriesItsDeviceAndPort() throws {
        let session = RunnerSessionInfo(pid: 1, wdaPort: 61211, bundleId: "x", udid: "emulator-5554", startedAt: Date())
        let target = try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: session, keepAlive: nil)
        XCTAssertEqual(target.udid, "emulator-5554")
        XCTAssertEqual(target.port, 61211)
    }

    func testAKeepAliveSessionWithPortZeroHasNoPort() throws {
        let keepAlive = KeepAliveSession(sessionId: "s", port: 0, pid: 1, udid: "emulator-5554", path: "/tmp/x")
        let target = try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: nil, keepAlive: keepAlive)
        XCTAssertEqual(target.udid, "emulator-5554")
        XCTAssertNil(target.port)
    }

    func testAnIOSKeepAliveSessionKeepsItsPort() throws {
        let keepAlive = KeepAliveSession(sessionId: "s", port: 8430, pid: 1, udid: simulator, path: "/tmp/x")
        let target = try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: nil, keepAlive: keepAlive)
        XCTAssertEqual(target.udid, simulator)
        XCTAssertEqual(target.port, 8430)
    }

    func testNothingFoundNamesBothWaysToStartASession() {
        XCTAssertThrowsError(try DumpHierarchyCommand.resolveTarget(port: nil, runnerSession: nil, keepAlive: nil)) { error in
            XCTAssertTrue("\(error)".contains("grantiva runner start"), "\(error)")
            XCTAssertTrue("\(error)".contains("--keep-alive"), "\(error)")
        }
    }

    func testAnAndroidTargetDumpsThroughThePlatform() async throws {
        var command = try DumpHierarchyCommand.parse(["--format", "tree"])
        let fake = FakeDevicePlatform(platform: .android)
        command.devicePlatform = InjectedDevicePlatform(fake)
        try await command.dump(target: .init(udid: "emulator-5554", port: 61211))
        XCTAssertEqual(fake.calls, ["attachDriver(emulator-5554,61211)", "detach"])
    }

    func testUDIDAcceptsASerial() throws {
        XCTAssertNoThrow(try DumpHierarchyCommand.parse(["--udid", "emulator-5554"]))
        XCTAssertThrowsError(try DumpHierarchyCommand.parse(["--udid", "../x"]))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter 'SimulatorUDIDTests|HierarchyCommandTests|DumpHierarchyCommandTests'`
Expected: compile errors (`isAndroidSerial`, `run(store:)`, `devicePlatform`, `resolveTarget`, `dump(target:)`).

- [ ] **Step 3: Add `isAndroidSerial`**

In `SimulatorUDID.swift`, inside `enum DeviceID`, after `isADBSerial`:

```swift
    /// An adb serial that is not also a simulator UDID (a UDID is made of hex
    /// digits and dashes, which `isADBSerial` would accept).
    public static func isAndroidSerial(_ value: String) -> Bool {
        isADBSerial(value) && !isSimulatorUDID(value)
    }
```

- [ ] **Step 4: Rewrite `HierarchyCommand`**

In `Sources/GrantivaCLI/HierarchyCommand.swift`:
- Abstract: "Dump the UI hierarchy of a booted simulator or emulator without relaunching the app."
- `--udid` help: "Simulator UDID or adb serial to target (default: newest keep-alive session)".
- `validate()`: `if let udid { _ = try DeviceID.validate(udid) }`.
- Add the property `var devicePlatform = InjectedDevicePlatform()` after `format`.
- `locateSession(store:)`: `try store.locate(udid: udid.map { try DeviceID.validate($0) })`.
- Replace `func run() async throws { let session = try locateSession() ...` with:

```swift
    func run() async throws {
        try await run(store: KeepAliveSessionStore())
    }

    /// `store` is injectable for tests.
    func run(store: KeepAliveSessionStore) async throws {
        let session = try locateSession(store: store)
        if let serial = session.udid, DeviceID.isAndroidSerial(serial) {
            try await runAndroid(serial: serial)
            return
        }
        // (the existing iOS body follows, unchanged: build the /source URL from
        // session.port, request it, unwrap, print)
```

and add:

```swift
    /// The runner's session file carries port 0 for Android (it does not
    /// proxy UIAutomator2), so the serial from the owner sidecar is all that
    /// is needed: the platform forwards a port and finds the held session.
    func runAndroid(serial: String) async throws {
        let device = try devicePlatform.make(.android)
        let attachment = try await device.attachDriver(deviceID: serial, port: nil)
        let text: String
        do {
            switch format {
            case .xml:
                text = try await attachment.client.hierarchyXML()
            case .json:
                let tree = try await attachment.client.hierarchy()
                let data = try JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys])
                text = String(decoding: data, as: UTF8.self)
            }
        } catch {
            await attachment.detach()
            throw error
        }
        await attachment.detach()
        Output.line(text)
    }
```

Update the discussion text's first sentence to "Finds the session published by `grantiva run --keep-alive` (in /tmp/grantiva-sessions, with the simulator UDID or adb serial recorded by grantiva) and reads the current page source: from GrantivaAgent on iOS, from the UIAutomator2 server on Android."

- [ ] **Step 5: Rewrite `DumpHierarchyCommand`'s target resolution**

In `Sources/GrantivaCLI/DriverCommand.swift`, inside `DumpHierarchyCommand`:
- `--udid` help: "Simulator UDID or adb serial when falling back to a `grantiva run --keep-alive` session"; `validate()` uses `DeviceID.validate`.
- Add `var devicePlatform = InjectedDevicePlatform()` after `udid`.
- Add:

```swift
    struct Target: Equatable {
        let udid: String
        let port: UInt16?
    }

    /// Flag port, then a `runner start` session, then a keep-alive session.
    /// A keep-alive port of 0 (Android) becomes nil: the platform forwards one.
    static func resolveTarget(port: UInt16?, runnerSession: RunnerSessionInfo?, keepAlive: KeepAliveSession?) throws -> Target {
        if let port { return Target(udid: "", port: port) }
        if let runnerSession { return Target(udid: runnerSession.udid, port: runnerSession.wdaPort) }
        if let keepAlive {
            return Target(udid: keepAlive.udid ?? "", port: keepAlive.port > 0 ? UInt16(exactly: keepAlive.port) : nil)
        }
        throw GrantivaError.invalidArgument(
            "No active runner session. Start one with 'grantiva runner start' or `grantiva run --keep-alive`, or pass --port."
        )
    }
```

- Replace the start of `run()` (everything up to and including the `else { throw GrantivaError.invalidArgument("No active runner session...") }` block) with:

```swift
    func run() async throws {
        let runnerSession: RunnerSessionInfo? = {
            guard let session = try? RunnerSessionInfo.load(), session.isAlive else { return nil }
            return session
        }()
        let keepAlive = try? KeepAliveSessionStore().locate(udid: udid)
        let target = try Self.resolveTarget(port: port, runnerSession: runnerSession, keepAlive: keepAlive)
        try await dump(target: target)
    }

    func dump(target: Target) async throws {
        if DeviceID.isAndroidSerial(target.udid) {
            let device = try devicePlatform.make(.android)
            let attachment = try await device.attachDriver(deviceID: target.udid, port: target.port)
            do {
                try await render(client: attachment.client)
            } catch {
                await attachment.detach()
                throw error
            }
            await attachment.detach()
            return
        }
        guard let wdaPort = target.port else {
            throw GrantivaError.invalidArgument("No WebDriverAgent port for this session. Pass --port.")
        }
        // (the existing iOS body follows, unchanged, using `wdaPort`: status,
        // session id, /session/<id>/source or /source, unwrap, then `switch format`)
```

- Pull the existing `switch format.lowercased() { case "xml"/"json"/"tree" ... }` block out into a helper so both paths share it. For iOS it is called with the XML string already fetched; for Android via the client:

```swift
    private func render(client: DriverClient) async throws {
        switch format.lowercased() {
        case "xml":
            Output.line(try await client.hierarchyXML())
        case "json":
            let data = try JSONSerialization.data(withJSONObject: try await client.hierarchy(), options: [.prettyPrinted, .sortedKeys])
            Output.line(String(data: data, encoding: .utf8) ?? "{}")
        case "tree":
            printTree(element: try await client.hierarchy(), indent: 0)
        default:
            throw GrantivaError.invalidArgument("Invalid format '\(format)'. Use: tree, json, or xml")
        }
    }
```

The iOS branch keeps its own HTTP code and its `switch format.lowercased()` over `xmlSource` exactly as today (it deliberately falls back to bare `/source` when WDA reports no session id, which `DriverClient.wda` does not).

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --filter 'SimulatorUDIDTests|HierarchyCommandTests|DumpHierarchyCommandTests|RunnerLifecycleCommandTests'`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/GrantivaCore/Simulator/SimulatorUDID.swift Sources/GrantivaCLI/HierarchyCommand.swift Sources/GrantivaCLI/DriverCommand.swift Tests/GrantivaCoreTests/SimulatorUDIDTests.swift Tests/GrantivaCLITests/HierarchyCommandTests.swift Tests/GrantivaCLITests/DumpHierarchyCommandTests.swift
git commit -m "Read the Android hierarchy from UIAutomator2 in hierarchy and runner dump-hierarchy"
```

---

### Task 8: `runner start` and `runner stop` on Android

**Files:**
- Modify: `Sources/GrantivaCLI/DriverCommand.swift` (`RunnerStartCommand`, `RunnerStopCommand`, `RunnerStopDependencies`)
- Test: `Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift`

**Interfaces:**
- Consumes: `DevicePlatform.bootDevice/runnerGlobalArguments/runnerTestArguments/runnerEnvironment/attachDriver/cleanupOrphans`, `PlatformOptions.loadConfig`, `ChildProcess.spawn(environment:)`, `SimulatorLease`.
- Produces:
  - `RunnerStartCommand.runnerArguments(platform: any DevicePlatform, deviceID: String, flowPath: String) -> [String]`
  - `RunnerStartCommand.appID(platform:bundleId:applicationId:config:) throws -> String`
  - `RunnerStartCommand.target(platform:simulator:emulator:device:config:) -> String`
  - `RunnerStartCommand.waitForUIAutomator2(attach:timeout:sleep:) async -> DriverAttachment?`
  - `RunnerStopDependencies.cleanupOrphans: @Sendable (String) async -> Void`
  - New flags on `runner start`: `--platform`, `--application-id`, `--emulator`, `--device`, `--headless`.

- [ ] **Step 1: Write the failing tests**

In `Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift`, change `makeSession()` to use a real UDID shape, and add a `cleanupOrphans` entry to the `dependencies(...)` helper:

```swift
    private func makeSession(udid: String = "921A0945-7157-4533-BA1F-21E8132D3E40") -> RunnerSessionInfo {
        RunnerSessionInfo(pid: 1234, wdaPort: 8430, bundleId: "com.example", udid: udid, startedAt: Date())
    }

    private func dependencies(session: RunnerSessionInfo, events: LockedValue<[String]>, snapshot: String) -> RunnerStopDependencies {
        RunnerStopDependencies(
            loadSession: { session }, isAlive: { _ in true },
            processSnapshot: { events.append("snapshot"); return snapshot },
            terminateGroup: { _ in events.append("terminate") },
            removeSession: { events.append("remove") },
            releaseLease: { _ in events.append("release") },
            cleanupOrphans: { _ in events.append("orphans") }
        )
    }
```

Then add these tests to the class:

```swift
    func testStopOnAnAndroidSessionCleansOrphansAfterTerminating() async throws {
        let events = LockedValue<[String]>([])
        let session = makeSession(udid: "emulator-5554")
        let dependencies = dependencies(session: session, events: events, snapshot: "\(session.pid) 1 /tmp/grantiva-runner --device emulator-5554")
        try await RunnerStopCommand.parse([]).run(dependencies: dependencies)
        XCTAssertEqual(events.value, ["snapshot", "terminate", "orphans", "remove", "release"])
    }

    func testRunnerArgumentsAreUnchangedOnIOSAndPlatformShapedOnAndroid() {
        let ios = RunnerStartCommand.runnerArguments(platform: IOSPlatform(), deviceID: "921A0945-7157-4533-BA1F-21E8132D3E40", flowPath: "/tmp/f.yaml")
        XCTAssertEqual(ios, [
            "--platform", "ios", "--device", "921A0945-7157-4533-BA1F-21E8132D3E40", "--no-ansi", "--no-app-install",
            "test", "--wait-for-idle-timeout", "0", "/tmp/f.yaml",
        ])
        let android = RunnerStartCommand.runnerArguments(platform: FakeDevicePlatform(platform: .android), deviceID: "emulator-5554", flowPath: "/tmp/f.yaml")
        XCTAssertEqual(android, ["--platform", "android", "--device", "emulator-5554", "test", "/tmp/f.yaml"])
    }

    func testAppIDAndTargetResolutionPerPlatform() throws {
        XCTAssertEqual(try RunnerStartCommand.appID(platform: .ios, bundleId: "a.b", applicationId: nil, config: nil), "a.b")
        XCTAssertEqual(try RunnerStartCommand.appID(platform: .ios, bundleId: nil, applicationId: nil, config: GrantivaConfig(bundleId: "c.d")), "c.d")
        XCTAssertThrowsError(try RunnerStartCommand.appID(platform: .ios, bundleId: nil, applicationId: nil, config: nil)) {
            XCTAssertTrue("\($0)".contains("--bundle-id"), "\($0)")
        }
        XCTAssertEqual(try RunnerStartCommand.appID(platform: .android, bundleId: nil, applicationId: "e.f", config: nil), "e.f")
        XCTAssertEqual(try RunnerStartCommand.appID(platform: .android, bundleId: nil, applicationId: nil,
                                                    config: GrantivaConfig(platform: .android, android: AndroidProject(applicationId: "g.h"))), "g.h")
        XCTAssertThrowsError(try RunnerStartCommand.appID(platform: .android, bundleId: nil, applicationId: nil, config: nil)) {
            XCTAssertTrue("\($0)".contains("--application-id"), "\($0)")
        }
        XCTAssertEqual(RunnerStartCommand.target(platform: .ios, simulator: nil, emulator: nil, device: nil, config: nil), "iPhone 16")
        XCTAssertEqual(RunnerStartCommand.target(platform: .android, simulator: nil, emulator: "P", device: "emulator-5556", config: nil), "emulator-5556")
        XCTAssertEqual(RunnerStartCommand.target(platform: .android, simulator: nil, emulator: nil, device: nil, config: nil), "")
    }

    func testWaitForUIAutomator2RetriesUntilAttachSucceeds() async {
        let attempts = LockedValue(0)
        let attachment = await RunnerStartCommand.waitForUIAutomator2(
            attach: {
                attempts.set(attempts.value + 1)
                if attempts.value < 3 { throw GrantivaError.invalidArgument("not yet") }
                return DriverAttachment(client: .failing, port: 61211, detach: {})
            },
            timeout: 5,
            sleep: {}
        )
        XCTAssertEqual(attachment?.port, 61211)
        XCTAssertEqual(attempts.value, 3)
    }

    func testWaitForUIAutomator2GivesUpAtTheTimeout() async {
        let attachment = await RunnerStartCommand.waitForUIAutomator2(
            attach: { throw GrantivaError.invalidArgument("never") },
            timeout: 0,
            sleep: {}
        )
        XCTAssertNil(attachment)
    }
```

`LockedValue` in that file must support a generic `set`; it already has `set(_:)` and `value` (used by the existing port-discovery tests).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter RunnerLifecycleCommandTests`
Expected: compile errors (`cleanupOrphans:` label, `runnerArguments`, `appID`, `target`, `waitForUIAutomator2`).

- [ ] **Step 3: Implement `runner start`**

In `RunnerStartCommand`:

Flags — replace the two existing `@Option`s with:

```swift
    @OptionGroup var platformOptions: PlatformOptions

    @Option(name: .long, help: "App bundle identifier (iOS; reads from grantiva.yml if omitted)")
    var bundleId: String?

    @Option(name: .long, help: "Simulator name or UDID (iOS; reads from grantiva.yml if omitted)")
    var simulator: String?

    @Option(name: .long, help: "Application ID (Android; reads from grantiva-android.yml if omitted)")
    var applicationId: String?

    @Option(name: .long, help: "AVD name to use, booting it if needed (Android)")
    var emulator: String?

    @Option(name: .long, help: "adb serial of an attached emulator or device (Android)")
    var device: String?

    @Flag(name: .long, help: "Boot an emulator without a window (Android)")
    var headless = false

    @Flag(name: .long, help: "Detach the runner process from this terminal. Prints the log file path on start.")
    var detach: Bool = false

    /// Empty means "make one from the resolved platform"; tests inject a fake.
    var devicePlatform = InjectedDevicePlatform()
```

Static helpers (add inside the struct):

```swift
    static func appID(platform: Platform, bundleId: String?, applicationId: String?, config: GrantivaConfig?) throws -> String {
        switch platform {
        case .ios:
            if applicationId != nil { throw GrantivaError.invalidArgument("--application-id is an Android option, but this is an iOS project.") }
            guard let id = bundleId ?? config?.bundleId else {
                throw GrantivaError.invalidArgument("No bundle ID. Pass --bundle-id or set bundle_id in grantiva.yml.")
            }
            return id
        case .android:
            if bundleId != nil { throw GrantivaError.invalidArgument("--bundle-id is an iOS option, but this is an Android project.") }
            guard let id = applicationId ?? config?.android?.applicationId else {
                throw GrantivaError.invalidArgument("No application ID. Pass --application-id or set application_id in grantiva-android.yml.")
            }
            return id
        }
    }

    static func target(platform: Platform, simulator: String?, emulator: String?, device: String?, config: GrantivaConfig?) -> String {
        switch platform {
        case .ios: return simulator ?? config?.simulator ?? "iPhone 16"
        case .android: return device ?? emulator ?? config?.android?.emulator ?? ""
        }
    }

    /// Global flags, `test`, the platform's test flags, then the flow. On iOS
    /// this is byte-for-byte the argv `runner start` has always used.
    static func runnerArguments(platform: any DevicePlatform, deviceID: String, flowPath: String) -> [String] {
        platform.runnerGlobalArguments(deviceID: deviceID, appFile: nil) + ["test"] + platform.runnerTestArguments() + [flowPath]
    }

    /// Polls `attach` until the runner has opened its UIAutomator2 session.
    /// The successful attachment is returned un-detached: its forward is the
    /// port `session.json` records and `dump-hierarchy` and the MCP server use.
    static func waitForUIAutomator2(
        attach: @Sendable () async throws -> DriverAttachment,
        timeout: TimeInterval,
        sleep: @Sendable () async -> Void = { try? await Task.sleep(for: .seconds(1)) }
    ) async -> DriverAttachment? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let attachment = try? await attach() { return attachment }
            await sleep()
        } while Date() < deadline
        return nil
    }
```

`run()` — replace from `// Resolve config` through the `simulatorLease.handOff(to: runnerPid)` lines with:

```swift
        let (platform, config) = try platformOptions.loadConfig()
        if platform == .ios {
            if emulator != nil { throw GrantivaError.invalidArgument("--emulator is an Android option, but this is an iOS project.") }
            if device != nil { throw GrantivaError.invalidArgument("--device is an Android option, but this is an iOS project.") }
            if headless { throw GrantivaError.invalidArgument("--headless is an Android option, but this is an iOS project.") }
        }
        if platform == .android, simulator != nil {
            throw GrantivaError.invalidArgument("--simulator is an iOS option, but this is an Android project.")
        }
        if device != nil, emulator != nil {
            throw GrantivaError.invalidArgument("--device and --emulator are mutually exclusive; pass one.")
        }
        if let device { _ = try DeviceID.validate(device, flag: "--device") }
        let resolvedAppID = try Self.appID(platform: platform, bundleId: bundleId, applicationId: applicationId, config: config)
        let targetName = Self.target(platform: platform, simulator: simulator, emulator: emulator, device: device, config: config)

        let platformDevice = try devicePlatform.make(platform, android: .init(headless: headless))
        let booted = try await platformDevice.bootDevice(named: targetName)
        // Held until the runner is up, then handed to the runner process: this
        // command returns immediately, but the session it started still owns
        // the device until `runner stop`.
        let simulatorLease = try SimulatorLease.acquire(udid: booted.udid)
        var handedOff = false
        defer { if !handedOff { simulatorLease.release() } }

        let deviceNoun = platform == .ios ? "Simulator" : "Device"
        options.note("Starting runner...")
        options.note("  \(platform == .ios ? "Bundle ID" : "Application ID"): \(resolvedAppID)")
        options.note("  \(deviceNoun): \(booted.name) (\(booted.udid))")

        let runner = RunnerManager.live
        try await runner.ensureAvailable()
        let runnerBin = runner.runnerPath()
        let runnerDir = runner.runnerDir()

        let flowYaml = """
        appId: \(resolvedAppID)
        ---
        - launchApp
        - waitForAnimationToEnd:
            timeout: 3600000
        """
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-session")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let flowPath = tempDir.appendingPathComponent("session-flow.yaml").path
        try flowYaml.write(toFile: flowPath, atomically: true, encoding: .utf8)

        let runnerArgs = Self.runnerArguments(platform: platformDevice, deviceID: booted.udid, flowPath: flowPath)
        let environment = platformDevice.runnerEnvironment(runnerHome: runnerDir)
        let launch = Launch(
            runnerBin: runnerBin, runnerDir: runnerDir, runnerArgs: runnerArgs,
            environment: environment.isEmpty ? nil : environment,
            appID: resolvedAppID, device: booted, platform: platform, platformDevice: platformDevice
        )
        let runnerPid: Int32
        if detach {
            runnerPid = try await startDetached(launch)
        } else {
            runnerPid = try await startForeground(launch)
        }
        simulatorLease.handOff(to: runnerPid)
        handedOff = true
```

Add the `Launch` value and change the two start functions to take it:

```swift
    struct Launch {
        let runnerBin: String
        let runnerDir: String
        let runnerArgs: [String]
        let environment: [String: String]?
        let appID: String
        let device: BootedDevice
        let platform: Platform
        let platformDevice: any DevicePlatform
    }
```

`startDetached(_ launch: Launch)`: same body as today with `runnerBin/runnerDir/runnerArgs/resolvedBundleId/device` read from `launch`, `ChildProcess.spawn(... environment: launch.environment, ...)`, and the port step replaced by:

```swift
        let port: UInt16?
        if launch.platform == .android {
            let device = launch.platformDevice
            let serial = launch.device.udid
            let attachment = await Self.waitForUIAutomator2(
                attach: { try await device.attachDriver(deviceID: serial, port: nil) }, timeout: 90
            )
            port = attachment.map { UInt16(clamping: $0.port) }
        } else {
            port = try await waitForWDAPort(logFile: logPath, timeout: 60)
        }
        guard let port else {
            child.terminateGroup(gracePeriod: 1)
            throw GrantivaError.commandFailed(
                "Timed out waiting for \(launch.platform == .android ? "the UIAutomator2 session" : "WDA") to start. Log: \(logPath)", 1
            )
        }
```

The `RunnerSessionInfo` it records uses `bundleId: launch.appID, udid: launch.device.udid`. Human output: the `"  WDA port: \(port)"` line becomes `"  \(launch.platform == .android ? "UIAutomator2 port" : "WDA port"): \(port)"`. JSON keys are unchanged (`port`, `bundle_id`, `udid`).

`startForeground(_ launch: Launch)`: same shape; spawn with `environment: launch.environment`; on Android skip the stdout-stream port discovery and use `waitForUIAutomator2` with the same 90 s timeout and the message "Timed out waiting for the UIAutomator2 session to start"; the stdout pipe is still created and drained (keep `Self.outputStream(from:)` running in a `Task` that discards chunks so the runner cannot block on a full pipe). Same output-line change as above. The final hint line "Use 'grantiva runner dump-hierarchy' to inspect the view hierarchy." stays on both platforms.

- [ ] **Step 4: Implement `runner stop`**

Add to `RunnerStopDependencies`:

```swift
    var cleanupOrphans: @Sendable (String) async -> Void
```

with the live value:

```swift
        cleanupOrphans: { serial in
            guard let platform = try? AndroidPlatform.live() else { return }
            await platform.cleanupOrphans(deviceID: serial)
        }
```

In `RunnerStopCommand.run(dependencies:)`, after the `if dependencies.isAlive(session) { ... }` block and before `dependencies.removeSession()`:

```swift
        // The runner's own teardown clears its forwards and the UIA2 server
        // when it exits cleanly; after a kill they may still be there.
        if DeviceID.isAndroidSerial(session.udid) {
            await dependencies.cleanupOrphans(session.udid)
        }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift build && swift test --filter 'RunnerLifecycleCommandTests|MCPCommandTests'`
Expected: PASS, including the four pre-existing stop/start tests.

- [ ] **Step 6: Commit**

```bash
git add Sources/GrantivaCLI/DriverCommand.swift Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift
git commit -m "Start and stop runner sessions on Android through the platform and the UIAutomator2 forward"
```

---

### Task 9: Emulator ensure, delete, sessions, teardown, and the `emulator` subcommand

**Files:**
- Modify: `Sources/GrantivaCore/Android/EmulatorManager.swift`
- Create: `Sources/GrantivaCLI/EmulatorCommand.swift`
- Modify: `Sources/GrantivaCLI/GrantivaCommand.swift` (register `EmulatorCommand.self` after `SimulatorCommand.self`)
- Test: `Tests/GrantivaCoreTests/EmulatorManagerTests.swift`, `Tests/GrantivaCLITests/EmulatorCommandTests.swift` (new)

**Interfaces:**
- Consumes: `AndroidProvenance` created-AVD ledger (Task 1), `ADB.removeForwards/forceStop/emuKill/devices/avdName`, `AndroidSDK.javaHome/sdkmanager/avdmanager`, `EmulatorManager.selectDevice/listAVDs/isAlive`.
- Produces:
  - `EmulatorProvisionResult { name: String; serial: String?; created: Bool; state: String }` (`"Booted"` or `"Shutdown"`)
  - `EmulatorSessionRecord { serial, avd: String; pid: Int32; startedAt: Date; processAlive: Bool; adbState: String }` (`"device"`, `"offline"`, …, or `"absent"`)
  - `EmulatorTeardownOutcome { serial: String; avd: String?; killed: Bool; recorded: Bool }`
  - `EmulatorManager.defaultSystemImage`, `static systemImagePath(root:image:) -> String`
  - `EmulatorManager.ensure(avd:systemImage:boot:) async throws -> EmulatorProvisionResult`
  - `EmulatorManager.deleteAVD(name:force:) async throws`
  - `EmulatorManager.sessions() async throws -> [EmulatorSessionRecord]`
  - `EmulatorManager.teardown(serial:force:) async throws -> EmulatorTeardownOutcome`, `teardownAll() async throws -> [EmulatorTeardownOutcome]`
  - `EmulatorManager.init` gains `environment: [String: String] = ProcessInfo.processInfo.environment`, `fileManager: FileManager = .default`, `killTimeout: TimeInterval = 30`.
  - CLI: `grantiva emulator ensure|delete|sessions|teardown`; `EmulatorCommand.Ensure.render(_:) -> (stdout: String, stderr: String)`.

- [ ] **Step 1: Write the failing manager tests**

In `Tests/GrantivaCoreTests/EmulatorManagerTests.swift`, change the `manager(...)` helper to:

```swift
    private func manager(_ shell: ScriptedShell, spawn: SpawnRecorder = SpawnRecorder(), headless: Bool = true, sdkRoot: String = "/sdk") -> EmulatorManager {
        EmulatorManager(
            sdk: AndroidSDK(root: sdkRoot),
            adb: ADB(path: "\(sdkRoot)/platform-tools/adb", execute: shell.execute),
            execute: shell.execute,
            spawn: spawn.spawn,
            provenance: AndroidProvenance(directory: scratch.path),
            headless: headless,
            bootTimeout: 1,
            pollInterval: 0.01,
            environment: [:],
            killTimeout: 1
        )
    }

    /// A pid that no longer exists: a child that ran and was reaped.
    private func deadPID() throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }
```

Then add these tests:

```swift
    func testEnsureCreatesAMissingAVDAndBootsIt() async throws {
        let shell = ScriptedShell([
            .success(""),                                  // emulator -list-avds: none
            .success("/jdk"),                              // java_home
            .success(""),                                  // sdkmanager
            .success(""),                                  // avdmanager create
            .success("List of devices attached"),          // selectDevice: adb devices
            .success("Pixel_8_API_35"),                    // selectDevice: list-avds
            .success("List of devices attached"),          // boot: adb devices (port choice)
            .success("1"),                                 // boot_completed
            .success("package:/system/framework/framework-res.apk"),
            .success(""),                                  // dismiss-keyguard
        ])
        let result = try await manager(shell).ensure(avd: "Pixel_8_API_35", systemImage: nil, boot: true)
        XCTAssertEqual(result, EmulatorProvisionResult(name: "Pixel_8_API_35", serial: "emulator-5554", created: true, state: "Booted"))
        XCTAssertEqual(shell.commands, [
            "'/sdk/emulator/emulator' -list-avds",
            "/usr/libexec/java_home",
            "yes 2>/dev/null | JAVA_HOME='/jdk' '/sdk/cmdline-tools/latest/bin/sdkmanager' --sdk_root='/sdk' 'system-images;android-35;google_apis;arm64-v8a'",
            "echo no | JAVA_HOME='/jdk' '/sdk/cmdline-tools/latest/bin/avdmanager' create avd -n 'Pixel_8_API_35' -k 'system-images;android-35;google_apis;arm64-v8a' -d pixel_8",
            "'/sdk/platform-tools/adb' devices -l",
            "'/sdk/emulator/emulator' -list-avds",
            "'/sdk/platform-tools/adb' devices -l",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell getprop 'sys.boot_completed'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'pm path android'",
            "'/sdk/platform-tools/adb' -s 'emulator-5554' shell 'wm dismiss-keyguard'",
        ])
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).createdAVDs(), ["Pixel_8_API_35"])
    }

    func testEnsureReusesAnExistingAVDWithoutBootingWhenAsked() async throws {
        let shell = ScriptedShell([.success("Pixel_8_API_35")])
        let result = try await manager(shell).ensure(avd: "Pixel_8_API_35", systemImage: nil, boot: false)
        XCTAssertEqual(result, EmulatorProvisionResult(name: "Pixel_8_API_35", serial: nil, created: false, state: "Shutdown"))
        XCTAssertEqual(shell.commands, ["'/sdk/emulator/emulator' -list-avds"])
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).createdAVDs(), [])
    }

    func testEnsureSkipsSdkmanagerWhenTheImageIsInstalled() async throws {
        let root = scratch.appendingPathComponent("sdk").path
        try FileManager.default.createDirectory(atPath: "\(root)/system-images/android-34/google_apis/arm64-v8a", withIntermediateDirectories: true)
        let shell = ScriptedShell([.success(""), .success("/jdk"), .success("")])
        let result = try await manager(shell, sdkRoot: root).ensure(avd: "Pixel_7_API_34", systemImage: "system-images;android-34;google_apis;arm64-v8a", boot: false)
        XCTAssertTrue(result.created)
        XCTAssertEqual(shell.commands, [
            "'\(root)/emulator/emulator' -list-avds",
            "/usr/libexec/java_home",
            "echo no | JAVA_HOME='/jdk' '\(root)/cmdline-tools/latest/bin/avdmanager' create avd -n 'Pixel_7_API_34' -k 'system-images;android-34;google_apis;arm64-v8a' -d pixel_8",
        ])
    }

    func testSystemImagePathReplacesSemicolons() {
        XCTAssertEqual(
            EmulatorManager.systemImagePath(root: "/sdk", image: "system-images;android-35;google_apis;arm64-v8a"),
            "/sdk/system-images/android-35/google_apis/arm64-v8a"
        )
    }

    func testDeleteRefusesARunningAVD() async {
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5554 device"), .success("Pixel_8_API_35\nOK")])
        do {
            try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("running as emulator-5554"), "\(error)")
            XCTAssertTrue("\(error)".contains("grantiva emulator teardown --serial emulator-5554"), "\(error)")
        }
    }

    func testDeleteRefusesAForeignAVDWithoutForce() async {
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_8_API_35")])
        do {
            try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("was not created by Grantiva"), "\(error)")
            XCTAssertTrue("\(error)".contains("--force"), "\(error)")
        }
        XCTAssertEqual(shell.commands.count, 2)
    }

    func testDeleteWithForceRemovesAForeignAVD() async throws {
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_8_API_35"), .success("/jdk"), .success("")])
        try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: true)
        XCTAssertEqual(shell.commands.last, "JAVA_HOME='/jdk' '/sdk/cmdline-tools/latest/bin/avdmanager' delete avd -n 'Pixel_8_API_35'")
    }

    func testDeleteRemovesACreatedAVDAndItsLedgerEntry() async throws {
        try AndroidProvenance(directory: scratch.path).registerCreatedAVD("Pixel_8_API_35")
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_8_API_35"), .success("/jdk"), .success("")])
        try await manager(shell).deleteAVD(name: "Pixel_8_API_35", force: false)
        XCTAssertEqual(try AndroidProvenance(directory: scratch.path).createdAVDs(), [])
    }

    func testDeleteOfAnUnknownAVDListsTheOnesThatExist() async {
        let shell = ScriptedShell([.success("List of devices attached"), .success("Pixel_7_API_34")])
        do {
            try await manager(shell).deleteAVD(name: "Nope", force: true)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("No AVD named \"Nope\""), "\(error)")
            XCTAssertTrue("\(error)".contains("Pixel_7_API_34"), "\(error)")
        }
    }

    func testSessionsReportLivenessAndPruneDeadAbsentRecords() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Live", pid: getpid()))
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5556", avd: "Gone", pid: try deadPID()))
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5554 device")])
        let sessions = try await manager(shell).sessions()
        XCTAssertEqual(sessions.map(\.serial), ["emulator-5554"])
        XCTAssertEqual(sessions.first?.processAlive, true)
        XCTAssertEqual(sessions.first?.adbState, "device")
        XCTAssertEqual(try ledger.all().map(\.serial), ["emulator-5554"], "the dead, absent record is pruned")
    }

    /// Review Focus 4.
    func testTeardownRefusesAForeignSerialWithoutForce() async {
        let shell = ScriptedShell()
        do {
            _ = try await manager(shell).teardown(serial: "emulator-5556", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("was not started by Grantiva"), "\(error)")
            XCTAssertTrue("\(error)".contains("--force"), "\(error)")
        }
        XCTAssertTrue(shell.commands.isEmpty)
    }

    /// Review Focus 4.
    func testTeardownWithForceKillsAForeignSerial() async throws {
        let shell = ScriptedShell([
            .success(""), .success(""),                              // force-stop x2
            .success(""),                                            // forward --list
            .success("List of devices attached\nemulator-5556 device"),
            .success(""),                                            // emu kill
            .success("List of devices attached"),                    // gone
        ])
        let outcome = try await manager(shell).teardown(serial: "emulator-5556", force: true)
        XCTAssertEqual(outcome, EmulatorTeardownOutcome(serial: "emulator-5556", avd: nil, killed: true, recorded: false))
        XCTAssertEqual(shell.commands, [
            "'/sdk/platform-tools/adb' -s 'emulator-5556' shell am force-stop 'io.appium.uiautomator2.server'",
            "'/sdk/platform-tools/adb' -s 'emulator-5556' shell am force-stop 'io.appium.uiautomator2.server.test'",
            "'/sdk/platform-tools/adb' -s 'emulator-5556' forward --list",
            "'/sdk/platform-tools/adb' devices -l",
            "'/sdk/platform-tools/adb' -s 'emulator-5556' emu kill",
            "'/sdk/platform-tools/adb' devices -l",
        ])
    }

    func testTeardownKillsARecordedEmulatorAndRemovesTheRecord() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: try deadPID()))
        let shell = ScriptedShell([
            .success(""), .success(""), .success(""),
            .success("List of devices attached\nemulator-5554 device"),
            .success(""),
            .success("List of devices attached"),
        ])
        let outcome = try await manager(shell).teardown(serial: "emulator-5554", force: false)
        XCTAssertEqual(outcome, EmulatorTeardownOutcome(serial: "emulator-5554", avd: "Pixel_8_API_35", killed: true, recorded: true))
        XCTAssertEqual(try ledger.all(), [])
    }

    func testTeardownOfARecordedEmulatorThatIsAlreadyGoneJustDropsTheRecord() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: try deadPID()))
        let shell = ScriptedShell([.success(""), .success(""), .success(""), .success("List of devices attached")])
        let outcome = try await manager(shell).teardown(serial: "emulator-5554", force: false)
        XCTAssertEqual(outcome.killed, false)
        XCTAssertEqual(try ledger.all(), [])
        XCTAssertFalse(shell.commands.contains { $0.hasSuffix("emu kill") })
    }

    func testTeardownTimesOutWhenTheEmulatorKeepsRunning() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "P", pid: getpid()))
        let shell = ScriptedShell([.success(""), .success(""), .success(""), .success("List of devices attached\nemulator-5554 device"), .success("")])
        shell.fallback = "List of devices attached\nemulator-5554 device"
        do {
            _ = try await manager(shell).teardown(serial: "emulator-5554", force: false)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("did not exit within 1s"), "\(error)")
        }
        XCTAssertEqual(try ledger.all().count, 1, "a record whose emulator is still up stays")
    }

    func testTeardownAllCoversEveryRecordedEmulator() async throws {
        let ledger = AndroidProvenance(directory: scratch.path)
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5554", avd: "A", pid: try deadPID()))
        try ledger.register(StartedEmulatorRecord(serial: "emulator-5556", avd: "B", pid: try deadPID()))
        let shell = ScriptedShell([.success("List of devices attached\nemulator-5554 device\nemulator-5556 device")])
        shell.fallback = "List of devices attached"
        let outcomes = try await manager(shell).teardownAll()
        XCTAssertEqual(outcomes.map(\.serial), ["emulator-5554", "emulator-5556"])
        XCTAssertEqual(try ledger.all(), [])
    }
```

- [ ] **Step 2: Write the failing command tests**

Create `Tests/GrantivaCLITests/EmulatorCommandTests.swift`:

```swift
import ArgumentParser
import XCTest
@testable import GrantivaCLI
import GrantivaCore

final class EmulatorCommandTests: XCTestCase {
    func testEnsureParsesItsFlags() throws {
        let command = try EmulatorCommand.Ensure.parse(["--name", "Pixel_8_API_35", "--system-image", "system-images;android-35;google_apis;arm64-v8a", "--no-boot", "--headless", "--json"])
        XCTAssertEqual(command.name, "Pixel_8_API_35")
        XCTAssertEqual(command.systemImage, "system-images;android-35;google_apis;arm64-v8a")
        XCTAssertFalse(command.boot)
        XCTAssertTrue(command.headless)
        XCTAssertTrue(command.options.json)
        XCTAssertTrue(try EmulatorCommand.Ensure.parse([]).boot, "boot is the default")
    }

    /// Mirrors `simulator ensure`: stdout is the identifier, context goes to stderr.
    func testEnsurePrintsTheSerialOrNameOnStdout() {
        let booted = EmulatorCommand.Ensure.render(EmulatorProvisionResult(name: "Pixel_8_API_35", serial: "emulator-5554", created: true, state: "Booted"))
        XCTAssertEqual(booted.stdout, "emulator-5554")
        XCTAssertEqual(booted.stderr, "Created Pixel_8_API_35 (emulator-5554) — Booted")
        let idle = EmulatorCommand.Ensure.render(EmulatorProvisionResult(name: "Pixel_8_API_35", serial: nil, created: false, state: "Shutdown"))
        XCTAssertEqual(idle.stdout, "Pixel_8_API_35")
        XCTAssertEqual(idle.stderr, "Reused Pixel_8_API_35 — Shutdown")
    }

    func testEnsureNameFallsBackToConfigThenFails() throws {
        XCTAssertEqual(try EmulatorCommand.Ensure.resolveName(flag: "A", config: nil), "A")
        XCTAssertEqual(try EmulatorCommand.Ensure.resolveName(flag: nil, config: GrantivaConfig(platform: .android, android: AndroidProject(emulator: "B"))), "B")
        XCTAssertThrowsError(try EmulatorCommand.Ensure.resolveName(flag: nil, config: nil)) { error in
            XCTAssertTrue("\(error)".contains("--name"), "\(error)")
        }
    }

    func testTeardownNeedsExactlyOneTarget() {
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse([]))
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse(["--serial", "emulator-5554", "--all"]))
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse(["--serial", ""]))
        XCTAssertThrowsError(try EmulatorCommand.Teardown.parse(["--serial", "921A0945-7157-4533-BA1F-21E8132D3E40"]), "a simulator UDID is not an emulator")
        XCTAssertNoThrow(try EmulatorCommand.Teardown.parse(["--serial", "emulator-5554", "--force"]))
        XCTAssertNoThrow(try EmulatorCommand.Teardown.parse(["--all"]))
    }

    func testDeleteParsesForce() throws {
        let command = try EmulatorCommand.Delete.parse(["--name", "Pixel_8_API_35", "--force"])
        XCTAssertEqual(command.name, "Pixel_8_API_35")
        XCTAssertTrue(command.force)
    }

    func testSessionsRenderOneLinePerEmulator() {
        let record = EmulatorSessionRecord(serial: "emulator-5554", avd: "Pixel_8_API_35", pid: 42, startedAt: Date(), processAlive: true, adbState: "device")
        XCTAssertEqual(EmulatorCommand.Sessions.render([record]), ["Grantiva-started emulators (1):", "  emulator-5554 (Pixel_8_API_35) — pid 42 running, adb: device"])
        XCTAssertEqual(EmulatorCommand.Sessions.render([]), ["No emulators started by Grantiva are running."])
    }

    func testEmulatorIsARootSubcommand() {
        XCTAssertTrue(GrantivaCommand.configuration.subcommands.contains { ObjectIdentifier($0) == ObjectIdentifier(EmulatorCommand.self) })
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter 'EmulatorManagerTests|EmulatorCommandTests'`
Expected: compile errors (`environment:`/`killTimeout:` init labels, `ensure`, `deleteAVD`, `sessions`, `teardown`, `EmulatorCommand`).

- [ ] **Step 4: Implement the manager**

In `Sources/GrantivaCore/Android/EmulatorManager.swift`:

Add the result types above the struct:

```swift
public struct EmulatorProvisionResult: Codable, Equatable, Sendable {
    public let name: String
    public let serial: String?
    public let created: Bool
    public let state: String

    public init(name: String, serial: String?, created: Bool, state: String) {
        self.name = name
        self.serial = serial
        self.created = created
        self.state = state
    }
}

public struct EmulatorSessionRecord: Codable, Equatable, Sendable {
    public let serial: String
    public let avd: String
    public let pid: Int32
    public let startedAt: Date
    public let processAlive: Bool
    /// adb's state for the serial, or `absent` when adb does not list it.
    public let adbState: String

    public init(serial: String, avd: String, pid: Int32, startedAt: Date, processAlive: Bool, adbState: String) {
        self.serial = serial
        self.avd = avd
        self.pid = pid
        self.startedAt = startedAt
        self.processAlive = processAlive
        self.adbState = adbState
    }
}

public struct EmulatorTeardownOutcome: Codable, Equatable, Sendable {
    public let serial: String
    public let avd: String?
    public let killed: Bool
    public let recorded: Bool

    public init(serial: String, avd: String?, killed: Bool, recorded: Bool) {
        self.serial = serial
        self.avd = avd
        self.killed = killed
        self.recorded = recorded
    }
}
```

Add stored properties `private let environment: [String: String]`, `nonisolated(unsafe) private let fileManager: FileManager`, `private let killTimeout: TimeInterval`, and the init parameters `environment: [String: String] = ProcessInfo.processInfo.environment, fileManager: FileManager = .default, killTimeout: TimeInterval = 30` (after `pollInterval`), assigned in the init body.

Add the operations:

```swift
    public static let defaultSystemImage = "system-images;android-35;google_apis;arm64-v8a"

    /// `system-images;android-35;google_apis;arm64-v8a` is installed at
    /// `<sdk>/system-images/android-35/google_apis/arm64-v8a`.
    public static func systemImagePath(root: String, image: String) -> String {
        "\(root)/" + image.replacingOccurrences(of: ";", with: "/")
    }

    private func javaPrefix() async -> String {
        let home = await AndroidSDK.javaHome(environment: environment, execute: execute)
        return home.map { "JAVA_HOME=\(shellQuoted($0)) " } ?? ""
    }

    /// Creates the AVD when missing (installing its system image first when
    /// that is missing too), then boots it unless `boot` is false.
    public func ensure(avd: String, systemImage: String?, boot: Bool) async throws -> EmulatorProvisionResult {
        var created = false
        if !(try await listAVDs()).contains(avd) {
            let image = systemImage ?? Self.defaultSystemImage
            let java = await javaPrefix()
            if !fileManager.fileExists(atPath: Self.systemImagePath(root: sdk.root, image: image)) {
                GrantivaLog.logger.info("Installing \(image) with sdkmanager")
                _ = try await execute("yes 2>/dev/null | \(java)\(shellQuoted(sdk.sdkmanager)) --sdk_root=\(shellQuoted(sdk.root)) \(shellQuoted(image))")
            }
            GrantivaLog.logger.info("Creating AVD \(avd)")
            _ = try await execute("echo no | \(java)\(shellQuoted(sdk.avdmanager)) create avd -n \(shellQuoted(avd)) -k \(shellQuoted(image)) -d pixel_8")
            try provenance.registerCreatedAVD(avd)
            created = true
        }
        guard boot else {
            return EmulatorProvisionResult(name: avd, serial: nil, created: created, state: "Shutdown")
        }
        let device = try await selectDevice(configured: avd)
        return EmulatorProvisionResult(name: avd, serial: device.udid, created: created, state: "Booted")
    }

    /// Deletes an AVD Grantiva created; others need `force`. A running AVD
    /// is never deleted.
    public func deleteAVD(name: String, force: Bool) async throws {
        for device in try await adb.devices() where device.isEmulator {
            if (try? await adb.avdName(serial: device.serial)) == name {
                throw GrantivaError.invalidArgument(
                    "AVD \"\(name)\" is running as \(device.serial). Run `grantiva emulator teardown --serial \(device.serial)` first."
                )
            }
        }
        let avds = try await listAVDs()
        guard avds.contains(name) else {
            throw GrantivaError.invalidArgument(
                "No AVD named \"\(name)\". Existing AVDs: \(avds.isEmpty ? "(none)" : avds.joined(separator: ", "))."
            )
        }
        if !force, !(try provenance.createdAVDs()).contains(name) {
            throw GrantivaError.invalidArgument(
                "AVD \"\(name)\" was not created by Grantiva (grantiva emulator ensure). Pass --force to delete it anyway."
            )
        }
        let java = await javaPrefix()
        _ = try await execute("\(java)\(shellQuoted(sdk.avdmanager)) delete avd -n \(shellQuoted(name))")
        try provenance.removeCreatedAVD(name)
    }

    /// Ledger records with their liveness. A record whose process is gone
    /// and whose serial adb no longer lists is pruned on the way out.
    public func sessions() async throws -> [EmulatorSessionRecord] {
        let devices = try await adb.devices()
        var records: [EmulatorSessionRecord] = []
        for record in try provenance.all() {
            let alive = Self.isAlive(record.pid)
            let state = devices.first { $0.serial == record.serial }?.state ?? "absent"
            if !alive, state == "absent" {
                try provenance.remove(serial: record.serial)
                continue
            }
            records.append(EmulatorSessionRecord(
                serial: record.serial, avd: record.avd, pid: record.pid, startedAt: record.startedAt,
                processAlive: alive, adbState: state
            ))
        }
        return records
    }

    /// Stops the UIAutomator2 server, drops this serial's forwards, asks the
    /// emulator to exit, and waits for both the process and the serial to go.
    public func teardown(serial: String, force: Bool) async throws -> EmulatorTeardownOutcome {
        let record = try provenance.all().first { $0.serial == serial }
        guard record != nil || force else {
            throw GrantivaError.invalidArgument(
                "\(serial) was not started by Grantiva (see `grantiva emulator sessions`). Pass --force to kill it anyway."
            )
        }
        for package in ADB.uiAutomator2Packages {
            _ = try? await adb.forceStop(serial: serial, applicationId: package)
        }
        _ = try? await adb.removeForwards(serial: serial)

        var listed = try await adb.devices().contains { $0.serial == serial }
        var killed = false
        if listed {
            _ = try? await adb.emuKill(serial: serial)
            killed = true
            let deadline = Date().addingTimeInterval(killTimeout)
            while true {
                listed = try await adb.devices().contains { $0.serial == serial }
                let processGone = record.map { !Self.isAlive($0.pid) } ?? true
                if !listed, processGone { break }
                guard Date() < deadline else {
                    throw GrantivaError.commandFailed(
                        "\(serial) did not exit within \(Int(killTimeout))s after adb emu kill. Check `adb devices` and the emulator log.", 1
                    )
                }
                try await Task.sleep(for: .seconds(pollInterval))
            }
        }
        if record != nil {
            try provenance.remove(serial: serial)
        }
        return EmulatorTeardownOutcome(serial: serial, avd: record?.avd, killed: killed, recorded: record != nil)
    }

    public func teardownAll() async throws -> [EmulatorTeardownOutcome] {
        var outcomes: [EmulatorTeardownOutcome] = []
        for record in try provenance.all() {
            outcomes.append(try await teardown(serial: record.serial, force: false))
        }
        return outcomes
    }
```

`AndroidPlatform.live` already builds the manager; it needs no change (the new init parameters have defaults). Keep `waitForBoot`'s use of `isAlive` as is.

- [ ] **Step 5: Implement the command**

Create `Sources/GrantivaCLI/EmulatorCommand.swift`:

```swift
import ArgumentParser
import Foundation
import GrantivaCore

struct EmulatorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "emulator",
        abstract: "Provision, inspect, and tear down Android emulators.",
        subcommands: [Ensure.self, Delete.self, Sessions.self, Teardown.self]
    )

    struct Ensure: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create the AVD when missing (installing its system image first) and boot it. stdout is the serial, or the AVD name with --no-boot."
        )
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "AVD name. Defaults to emulator in grantiva-android.yml.")
        var name: String?

        @Option(name: .long, help: "System image package for a new AVD, e.g. \"system-images;android-35;google_apis;arm64-v8a\". Defaults to system_image in grantiva-android.yml, then that value.")
        var systemImage: String?

        @Flag(inversion: .prefixedNo, help: "Boot the emulator and wait for it to be ready. On by default; --no-boot creates it without booting.")
        var boot = true

        @Flag(name: .long, help: "Boot without a window.")
        var headless = false

        static func resolveName(flag: String?, config: GrantivaConfig?) throws -> String {
            guard let name = flag ?? config?.android?.emulator, !name.isEmpty else {
                throw GrantivaError.invalidArgument("No AVD named. Pass --name or set emulator in grantiva-android.yml.")
            }
            return name
        }

        /// stdout is the identifier a script captures:
        ///
        ///     serial=$(grantiva emulator ensure --name Pixel_8_API_35)
        ///
        /// The prose goes to the log (stderr), as `simulator ensure` does.
        static func render(_ result: EmulatorProvisionResult) -> (stdout: String, stderr: String) {
            let verb = result.created ? "Created" : "Reused"
            let serial = result.serial.map { " (\($0))" } ?? ""
            return (stdout: result.serial ?? result.name, stderr: "\(verb) \(result.name)\(serial) — \(result.state)")
        }

        func run() async throws {
            let config = try GrantivaConfig.loadIfPresent(platform: .android)
            let avd = try Self.resolveName(flag: name, config: config)
            let platform = try AndroidPlatform.live(options: .init(headless: headless))
            let result = try await platform.emulators.ensure(avd: avd, systemImage: systemImage ?? config?.android?.systemImage, boot: boot)
            if options.json {
                Output.line(try JSONOutput.string(result))
                return
            }
            let rendered = Self.render(result)
            GrantivaLog.logger.info("\(rendered.stderr)")
            Output.line(rendered.stdout)
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete an AVD Grantiva created. Others need --force. A running AVD is never deleted.")
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "AVD name to delete.")
        var name: String

        @Flag(name: .long, help: "Delete an AVD Grantiva did not create.")
        var force = false

        func run() async throws {
            let platform = try AndroidPlatform.live()
            try await platform.emulators.deleteAVD(name: name, force: force)
            if options.json {
                let data = try JSONSerialization.data(withJSONObject: ["name": name, "deleted": true], options: [.sortedKeys])
                Output.line(String(decoding: data, as: UTF8.self))
            } else {
                Output.line("Deleted AVD \(name)")
            }
        }
    }

    struct Sessions: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List the emulators Grantiva started.")
        @OptionGroup var options: GlobalOptions

        static func render(_ sessions: [EmulatorSessionRecord]) -> [String] {
            guard !sessions.isEmpty else { return ["No emulators started by Grantiva are running."] }
            return ["Grantiva-started emulators (\(sessions.count)):"] + sessions.map {
                "  \($0.serial) (\($0.avd)) — pid \($0.pid) \($0.processAlive ? "running" : "exited"), adb: \($0.adbState)"
            }
        }

        func run() async throws {
            let sessions = try await AndroidPlatform.live().emulators.sessions()
            if options.json {
                Output.line(try JSONOutput.string(sessions))
            } else {
                Self.render(sessions).forEach(Output.line)
            }
        }
    }

    struct Teardown: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Kill emulators Grantiva started: one by serial, or all of them. Stops the UIAutomator2 server and removes the serial's adb forwards first.")
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Emulator serial to kill, e.g. emulator-5554.")
        var serial: String?

        @Flag(name: .long, help: "Kill every emulator Grantiva started.")
        var all = false

        @Flag(name: .long, help: "Kill the serial even though Grantiva did not start it.")
        var force = false

        func validate() throws {
            switch (serial, all) {
            case (nil, false):
                throw ValidationError("Pass --serial <serial> or --all.")
            case (.some, true):
                throw ValidationError("--serial and --all are mutually exclusive; pass one.")
            default:
                break
            }
            if let serial {
                do {
                    let trimmed = try DeviceID.validate(serial, flag: "--serial")
                    guard DeviceID.isAndroidSerial(trimmed) else {
                        throw GrantivaError.invalidArgument("--serial \(trimmed) is a simulator UDID, not an emulator serial. Use `grantiva simulator teardown` for simulators.")
                    }
                } catch let error as GrantivaError {
                    throw ValidationError(error.errorDescription ?? String(describing: error))
                }
            }
        }

        func run() async throws {
            let emulators = try AndroidPlatform.live().emulators
            let outcomes: [EmulatorTeardownOutcome]
            if let serial {
                outcomes = [try await emulators.teardown(serial: serial.trimmingCharacters(in: .whitespacesAndNewlines), force: force)]
            } else {
                outcomes = try await emulators.teardownAll()
            }
            if options.json {
                Output.line(try JSONOutput.string(outcomes))
            } else if outcomes.isEmpty {
                Output.line("No emulators started by Grantiva are running.")
            } else {
                for outcome in outcomes {
                    let name = outcome.avd.map { " (\($0))" } ?? ""
                    Output.line(outcome.killed ? "Killed \(outcome.serial)\(name)." : "\(outcome.serial)\(name) was already gone; dropped its record.")
                }
            }
        }
    }
}
```

Register it: in `Sources/GrantivaCLI/GrantivaCommand.swift` add `EmulatorCommand.self,` directly after `SimulatorCommand.self,`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift build && swift test --filter 'EmulatorManagerTests|EmulatorCommandTests|AndroidPlatformTests'`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/GrantivaCore/Android/EmulatorManager.swift Sources/GrantivaCLI/EmulatorCommand.swift Sources/GrantivaCLI/GrantivaCommand.swift Tests/GrantivaCoreTests/EmulatorManagerTests.swift Tests/GrantivaCLITests/EmulatorCommandTests.swift
git commit -m "Add emulator ensure, delete, sessions, and teardown over the provenance ledger"
```

---

### Task 10: MCP server on Android — platform resolution, driver, UI, script, VRT, and context tools

**Files:**
- Modify: `Sources/GrantivaMCP/MCPServer.swift`, `ToolRegistry.swift`, `Tools/UITools.swift`, `Tools/ScriptTools.swift`, `Tools/VRTTools.swift`, `Tools/ContextTool.swift`
- Modify: `Tests/GrantivaMCPTests/MCPTestSupport.swift`, `MCPServerTests.swift`, `UIToolsTests.swift`, `VRTToolsTests.swift`, `ToolDispatchTests.swift`, `ScriptToolsTests.swift`, `ToolErrorContractTests.swift` (label renames plus the new tests below)

**Interfaces:**
- Consumes: `PlatformResolver.resolveOrDefault`, `DevicePlatformFactory.make`, `DevicePlatform.attachDriver/screenshot/defaultDevice`, `DeviceID`.
- Produces:
  - `ToolRegistry(driver:platform:device:config:session:simulatorManager:buildRunner:emulators:)` — `emulators: EmulatorToolDependencies?` is declared in this task as an empty placeholder type that Task 11 fills (`struct EmulatorToolDependencies: Sendable {}` in `Tools/EmulatorTools.swift`); the registry stores it and nothing reads it yet.
  - `MCPServer.resolveProjectDirectory` accepts either config file; `loadActiveSession` validates with `DeviceID`.
  - `UITools.screenshot(driver:device:session:arguments:)`, `tap/swipe/type/a11yTree(driver:...)`, `a11yCheck(driver:config:platform:)`, `UITools.minimumTapTarget(for:) -> Double`, `UITools.isInteractive(_:) -> Bool`.
  - `ScriptTools.script(driver:arguments:)`.
  - `VRTTools.captureCommand(platform:)`, `compareCommand(platform:)`, `approveCommand(platform:screens:)`, and `capture/compare/approve(platform:arguments:)`.
  - `ContextTool.context(config:platform:device:simManager:)`.
  - `MCPTestSupport.fakeDriver(recorder:hierarchyJSON:screenshotBytes:)` (renamed from `fakeWDA`), `MCPTestSupport.registry(driver:config:session:platform:device:)`, `MCPFakeDevicePlatform` (a recording fake in the MCP test target).

- [ ] **Step 1: Write the failing tests**

In `Tests/GrantivaMCPTests/MCPTestSupport.swift`, rename `fakeWDA` to `fakeDriver` and every `registry(wda:` call to `registry(driver:` (both across all MCP test files, including `ToolSchemaTests.allTools()`), and replace `registry(...)` with:

```swift
    static func registry(
        driver: DriverClient,
        config: GrantivaConfig? = nil,
        session: RunnerSessionInfo? = nil,
        platform: Platform = .ios,
        device: any DevicePlatform = MCPFakeDevicePlatform(platform: .ios)
    ) -> ToolRegistry {
        ToolRegistry(
            driver: driver,
            platform: platform,
            device: device,
            config: config,
            session: session ?? sessionWithoutUDID(),
            simulatorManager: SimulatorManager.live,
            buildRunner: XcodeBuildRunner(),
            emulators: nil
        )
    }
```

and add the fake platform at the bottom of the file:

```swift
/// Records every call. Mirrors the CLI test target's FakeDevicePlatform; the
/// two test targets cannot share a file.
final class MCPFakeDevicePlatform: DevicePlatform, @unchecked Sendable {
    let platform: Platform
    private let lock = NSLock()
    private var recorded: [String] = []
    var calls: [String] { lock.withLock { recorded } }
    private func record(_ call: String) { lock.withLock { recorded.append(call) } }

    var bootedID = "emulator-5598"
    var bootedName = "Fake"
    var buildResult = BuildResult(success: true, duration: 0, warnings: [], errors: [], productPath: "/fake/app.apk", applicationId: "com.fake.built")
    var screenshotBytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47]

    init(platform: Platform) { self.platform = platform }

    func bootDevice(named nameOrID: String) async throws -> BootedDevice { record("bootDevice(\(nameOrID))"); return BootedDevice(udid: bootedID, name: bootedName) }
    func displayGeometry(deviceID: String) async throws -> DeviceGeometry { record("displayGeometry"); return DeviceGeometry(pixelWidth: 1080, pixelHeight: 2400, scale: 2.625) }
    func build(_ request: PlatformBuildRequest) async throws -> BuildResult {
        record("build(scheme=\(request.resolved.scheme ?? "-"),module=\(request.resolved.android?.module ?? "-"),variant=\(request.resolved.android?.variant ?? "-"))"); return buildResult
    }
    func install(appID: String, productPath: String, deviceID: String) async throws { record("install(\(appID),\(productPath))") }
    func launch(appID: String, deviceID: String) async throws { record("launch(\(appID))") }
    func terminate(appID: String, deviceID: String) async throws { record("terminate(\(appID))") }
    func uninstall(appID: String, deviceID: String) async throws { record("uninstall(\(appID))") }
    func prepareForCapture(deviceID: String) async { record("prepare") }
    func restoreAfterCapture(deviceID: String) async { record("restore") }
    func runnerGlobalArguments(deviceID: String, appFile: String?) -> [String] { ["--platform", platform.rawValue, "--device", deviceID] }
    func runnerTestArguments() -> [String] { [] }
    func resolveBinary(_ path: String) async throws -> ResolvedBinary { record("resolveBinary(\(path))"); return ResolvedBinary(appPath: path, tempDir: nil, appID: "com.fake.binary") }
    func defaultDevice() async throws -> BootedDevice { record("defaultDevice"); return BootedDevice(udid: bootedID, name: bootedName) }
    func screenshot(deviceID: String, to path: String) async throws {
        record("screenshot(\(deviceID))")
        try Data(screenshotBytes).write(to: URL(fileURLWithPath: path))
    }
    func logStream(deviceID: String, appID: String?, filter: String?, level: String?) async throws -> LogStreamCommand { LogStreamCommand(executable: "/bin/echo", arguments: []) }
    func runnerEnvironment(runnerHome: String) -> [String: String] { [:] }
    func cleanupOrphans(deviceID: String) async { record("cleanupOrphans") }
    func attachDriver(deviceID: String, port: UInt16?) async throws -> DriverAttachment {
        record("attachDriver(\(deviceID),\(port.map(String.init) ?? "-"))")
        return DriverAttachment(client: .failing, port: Int(port ?? 7000), detach: {})
    }
    func recordVideo(deviceID: String, to path: String, seconds: Double) async throws { record("recordVideo") }
}
```

Append to `Tests/GrantivaMCPTests/MCPServerTests.swift` (it has a `makeProjectDirectory()` helper that writes `grantiva.yml`; add a sibling that writes `grantiva-android.yml` instead):

```swift
    /// Review Focus 5.
    func testProjectDirectoryAcceptsAnAndroidOnlyProject() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "platform: android\nmodule: app\n".write(to: directory.appendingPathComponent("grantiva-android.yml"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try GrantivaMCPServer.resolveProjectDirectory(directory).standardizedFileURL, directory.standardizedFileURL)
    }

    /// Review Focus 5.
    func testLoadActiveSessionAcceptsAnADBSerial() throws {
        let directory = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = RunnerSessionInfo(pid: getpid(), wdaPort: 61211, bundleId: "dev.grantiva.example", udid: "emulator-5554", startedAt: Date())
        let sessionURL = directory.appendingPathComponent(RunnerSessionInfo.path)
        try FileManager.default.createDirectory(at: sessionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(session).write(to: sessionURL)
        let loaded = try GrantivaMCPServer.loadActiveSession(projectDirectory: directory)
        XCTAssertEqual(loaded.udid, "emulator-5554")
        XCTAssertEqual(loaded.wdaPort, 61211)
    }

    func testDriverPortIsNilForAKeepAliveSessionWithPortZero() {
        XCTAssertNil(GrantivaMCPServer.driverPort(for: RunnerSessionInfo(pid: 1, wdaPort: 0, bundleId: "", udid: "emulator-5554", startedAt: Date())))
        XCTAssertEqual(GrantivaMCPServer.driverPort(for: RunnerSessionInfo(pid: 1, wdaPort: 8100, bundleId: "", udid: "", startedAt: Date())), 8100)
    }
```

Append to `Tests/GrantivaMCPTests/UIToolsTests.swift`:

```swift
    func testScreenshotWithADeviceGoesThroughThePlatform() async throws {
        let recorder = WDARecorder()
        let device = MCPFakeDevicePlatform(platform: .android)
        let session = RunnerSessionInfo(pid: 0, wdaPort: 0, bundleId: "", udid: "emulator-5554", startedAt: Date())
        let result = try await UITools.screenshot(driver: MCPTestSupport.fakeDriver(recorder: recorder), device: device, session: session, arguments: [:])
        XCTAssertEqual(device.calls, ["screenshot(emulator-5554)"])
        XCTAssertTrue(recorder.calls.isEmpty, "the driver is not asked when a device is known")
        XCTAssertEqual(try imageContent(of: result).mimeType, "image/png")
    }

    func testA11yCheckFlagsAClickableAndroidNodeWithoutALabel() async throws {
        let tree = #"{"type":"hierarchy","platform":"android","children":[{"type":"android.view.View","clickable":true,"enabled":true,"frame":{"x":"0","y":"0","width":"100","height":"100"},"children":[]}]}"#
        let result = try await UITools.a11yCheck(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: tree), config: nil, platform: .android)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("missing_label"), text)
        XCTAssertFalse(text.contains("small_tap_target"), text)
    }

    func testA11yCheckUses48dpOnAndroidAnd44ptOnIOS() async throws {
        let android = #"{"type":"hierarchy","children":[{"type":"android.widget.Button","label":"Go","enabled":true,"frame":{"x":"0","y":"0","width":"46","height":"46"},"children":[]}]}"#
        let androidText = try textContent(of: try await UITools.a11yCheck(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: android), config: nil, platform: .android))
        XCTAssertTrue(androidText.contains("below the 48x48dp minimum"), androidText)
        let ios = #"{"type":"XCUIElementTypeApplication","children":[{"type":"XCUIElementTypeButton","label":"Go","enabled":true,"frame":{"x":"0","y":"0","width":"46","height":"46"},"children":[]}]}"#
        let iosText = try textContent(of: try await UITools.a11yCheck(driver: MCPTestSupport.fakeDriver(recorder: WDARecorder(), hierarchyJSON: ios), config: nil, platform: .ios))
        XCTAssertEqual(iosText, "No accessibility violations found.")
    }
```

Append to `Tests/GrantivaMCPTests/VRTToolsTests.swift`:

```swift
    func testCommandsCarryThePlatform() {
        XCTAssertEqual(VRTTools.captureCommand(platform: .ios), "grantiva diff capture --no-build --json --platform ios")
        XCTAssertEqual(VRTTools.compareCommand(platform: .android), "grantiva diff compare --json --platform android")
        XCTAssertEqual(VRTTools.approveCommand(platform: .android, screens: ["Home", "It's"]), "grantiva diff approve --json --platform android 'Home' 'It'\\''s'")
        XCTAssertEqual(VRTTools.approveCommand(platform: .ios, screens: []), "grantiva diff approve --json --platform ios")
    }
```

Create `Tests/GrantivaMCPTests/ContextToolTests.swift`:

```swift
import Foundation
import GrantivaCore
import MCP
import XCTest
@testable import GrantivaMCP

@available(macOS 15, *)
final class ContextToolTests: XCTestCase {
    func testAndroidContextNamesTheEmulatorAndTheAndroidConfig() async throws {
        let config = GrantivaConfig(platform: .android, android: AndroidProject(module: "app", variant: "debug", applicationId: "dev.grantiva.example", emulator: "Pixel_8_API_35"))
        let device = MCPFakeDevicePlatform(platform: .android)
        let result = try await ContextTool.context(config: config, platform: .android, device: device, simManager: .live)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("[Config]"), text)
        XCTAssertTrue(text.contains("module: app"), text)
        XCTAssertTrue(text.contains("application_id: dev.grantiva.example"), text)
        XCTAssertTrue(text.contains("[Emulator]"), text)
        XCTAssertTrue(text.contains("serial: emulator-5598"), text)
        XCTAssertFalse(text.contains("[Xcode]"), text)
        XCTAssertEqual(device.calls, ["defaultDevice"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter 'MCPServerTests|UIToolsTests|VRTToolsTests|ContextToolTests'`
Expected: compile errors (new labels and functions).

- [ ] **Step 3: Rewire the server**

In `Sources/GrantivaMCP/MCPServer.swift`:

```swift
    public func run() async throws {
        let projectDirectory = try Self.resolveProjectDirectory(projectDirectory)
        guard FileManager.default.changeCurrentDirectoryPath(projectDirectory.path) else {
            throw GrantivaError.invalidArgument("Cannot use project directory: \(projectDirectory.path)")
        }

        // All relative tool paths now resolve from the selected project root.
        let platform = try PlatformResolver(directory: projectDirectory).resolveOrDefault(flag: nil)
        let config = try GrantivaConfig.loadIfPresent(platform: platform)
        let session = try Self.loadActiveSession(projectDirectory: projectDirectory)
        let device = try DevicePlatformFactory.make(platform)
        let attachment = try await device.attachDriver(deviceID: session.udid, port: Self.driverPort(for: session))

        let tools = ToolRegistry(
            driver: attachment.client,
            platform: platform,
            device: device,
            config: config,
            session: session,
            simulatorManager: SimulatorManager.live,
            buildRunner: XcodeBuildRunner(),
            emulators: try? EmulatorToolDependencies.live()
        )
        // (the rest of run() is unchanged)
```

`EmulatorToolDependencies.live()` is defined in Task 11; in this task declare in `Sources/GrantivaMCP/Tools/EmulatorTools.swift`:

```swift
import Foundation
import GrantivaCore

/// Filled in by the emulator tools (next task). Declared here so the registry
/// can carry it.
struct EmulatorToolDependencies: Sendable {
    static func live() throws -> EmulatorToolDependencies { EmulatorToolDependencies() }
}
```

Server instructions text: "Grantiva MCP server for iOS simulator and Android emulator automation. Use grantiva_* tools to interact with the device: tap, swipe, type, take screenshots, inspect the accessibility tree, build and run apps, manage simulators and emulators, and run visual regression tests."

Add:

```swift
    /// The runner's keep-alive session file carries port 0 on Android (the
    /// runner does not proxy UIAutomator2); nil tells the platform to forward one.
    static func driverPort(for session: RunnerSessionInfo) -> UInt16? {
        session.wdaPort > 0 ? session.wdaPort : nil
    }
```

`resolveProjectDirectory`: replace the `grantiva.yml` guard with:

```swift
        let hasConfig = Platform.allCases.contains {
            FileManager.default.fileExists(atPath: resolved.appendingPathComponent($0.configFileName).path)
        }
        guard hasConfig else {
            throw GrantivaError.invalidArgument("No grantiva.yml or grantiva-android.yml found in project directory: \(resolved.path)")
        }
```

`loadActiveSession`: `SimulatorUDID.validate(session.udid, flag: "session UDID")` → `DeviceID.validate(session.udid, flag: "session UDID")`; `keepAlive.udid.flatMap { try? SimulatorUDID.validate($0) }` → `keepAlive.udid.flatMap { try? DeviceID.validate($0) }`. `MCPCommand`'s `--project-dir` help becomes "Project directory containing grantiva.yml or grantiva-android.yml and .grantiva/session.json."

- [ ] **Step 4: Rewire the registry**

`ToolRegistry`:

```swift
struct ToolRegistry: Sendable {
    let driver: DriverClient
    let platform: Platform
    let device: any DevicePlatform
    let config: GrantivaConfig?
    let session: RunnerSessionInfo
    let simulatorManager: SimulatorManager
    let buildRunner: XcodeBuildRunner
    let emulators: EmulatorToolDependencies?
```

Dispatch changes (Build and Emulator cases are finished in Task 11; in this task keep the three Build cases calling the existing `BuildTools` signatures):

```swift
        case "grantiva_screenshot":
            result = try await UITools.screenshot(driver: driver, device: device, session: session, arguments: arguments)
        case "grantiva_tap":
            result = try await UITools.tap(driver: driver, arguments: arguments)
        case "grantiva_swipe":
            result = try await UITools.swipe(driver: driver, arguments: arguments)
        case "grantiva_type":
            result = try await UITools.type(driver: driver, arguments: arguments)
        case "grantiva_a11y_tree":
            result = try await UITools.a11yTree(driver: driver)
        case "grantiva_a11y_check":
            result = try await UITools.a11yCheck(driver: driver, config: config, platform: platform)
        ...
        case "grantiva_context":
            result = try await ContextTool.context(config: config, platform: platform, device: device, simManager: simulatorManager)
        case "grantiva_script":
            result = try await ScriptTools.script(driver: driver, arguments: arguments)
        case "grantiva_vrt_capture":
            result = try await VRTTools.capture(platform: platform, arguments: arguments)
        case "grantiva_vrt_compare":
            result = try await VRTTools.compare(platform: platform, arguments: arguments)
        case "grantiva_vrt_approve":
            result = try await VRTTools.approve(platform: platform, arguments: arguments)
```

`readResource` uses `driver.hierarchy()` / `driver.screenshot()`.

- [ ] **Step 5: UI tools**

In `UITools`:
- Every `wda: WDAClient` parameter becomes `driver: DriverClient` (and the private `fetchHierarchyJSON(driver:)`).
- Tool descriptions: replace "iOS simulator" with "device (iOS simulator or Android emulator)" in `grantiva_screenshot`, `grantiva_swipe`, `grantiva_type`; `grantiva_tap`'s `x`/`y` descriptions gain " — points on iOS, device pixels on Android"; `grantiva_a11y_check`'s description becomes "Run accessibility audit on the current screen. Checks for missing labels on interactive elements and tap targets smaller than 44pt (iOS) or 48dp (Android)."
- `screenshot`:

```swift
    static func screenshot(
        driver: DriverClient,
        device: any DevicePlatform,
        session: RunnerSessionInfo,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let format = arguments["format"]?.stringValue ?? "base64"
        let imageData: Data
        // Prefer the platform's full-device screenshot when a device is known.
        if !session.udid.isEmpty {
            let tmpPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("grantiva-mcp-\(UUID().uuidString).png").path
            defer { try? FileManager.default.removeItem(atPath: tmpPath) }
            try await device.screenshot(deviceID: session.udid, to: tmpPath)
            imageData = try Data(contentsOf: URL(fileURLWithPath: tmpPath))
        } else {
            imageData = try await driver.screenshot()
        }
        // (file/base64 handling unchanged)
```

- `a11yCheck(driver:config:platform:)` passes `platform` into `checkViolations(element:rules:platform:violations:)`. Add:

```swift
    static let iosInteractiveTypes = [
        "XCUIElementTypeButton", "XCUIElementTypeTextField", "XCUIElementTypeSecureTextField", "XCUIElementTypeSwitch",
        "XCUIElementTypeSlider", "XCUIElementTypeStepper", "XCUIElementTypeLink", "XCUIElementTypeSegmentedControl",
    ]
    static let androidInteractiveTypes = [
        "android.widget.Button", "android.widget.ImageButton", "android.widget.EditText", "android.widget.CheckBox",
        "android.widget.Switch", "android.widget.RadioButton", "android.widget.ToggleButton", "android.widget.SeekBar",
        "android.widget.Spinner",
    ]

    /// 44 pt on iOS (HIG), 48 dp on Android (Material).
    static func minimumTapTarget(for platform: Platform) -> Double {
        platform == .ios ? 44 : 48
    }

    /// Known interactive classes on either platform, or any Android node the
    /// framework marks clickable (Compose nodes carry no widget class).
    static func isInteractive(_ element: [String: Any]) -> Bool {
        let type = element["type"] as? String ?? ""
        return iosInteractiveTypes.contains(type) || androidInteractiveTypes.contains(type) || element["clickable"] as? Bool == true
    }
```

and in `checkViolations` replace the local `interactiveTypes`/`isInteractive` with `let isInteractive = Self.isInteractive(element)`, the `44` with `let minimum = minimumTapTarget(for: platform)`, and the message with `"Tap target \"\(desc)\" is \(Int(w))x\(Int(h))\(unit), below the \(Int(minimum))x\(Int(minimum))\(unit) minimum."` where `let unit = platform == .ios ? "pt" : "dp"`.

- [ ] **Step 6: Script, VRT, and context tools**

`ScriptTools.script(driver: DriverClient, arguments:)` — label rename only.

`VRTTools`:

```swift
    static func captureCommand(platform: Platform) -> String {
        "grantiva diff capture --no-build --json --platform \(platform.rawValue)"
    }

    static func compareCommand(platform: Platform) -> String {
        "grantiva diff compare --json --platform \(platform.rawValue)"
    }

    static func approveCommand(platform: Platform, screens: [String]) -> String {
        var cmd = "grantiva diff approve --json --platform \(platform.rawValue)"
        if !screens.isEmpty {
            cmd += " " + screens.map(shellQuoted).joined(separator: " ")
        }
        return cmd
    }
```

`capture(platform:arguments:)`, `compare(platform:arguments:)`, `approve(platform:arguments:)` call these; `approve` reads `screens` from `arguments["screens"]?.arrayValue?.compactMap(\.stringValue) ?? []`. Tool descriptions: `grantiva_vrt_capture` "...Assumes the app is already running on the device."

`ContextTool.context(config:platform:device:simManager:)`:

```swift
    static func context(
        config: GrantivaConfig?,
        platform: Platform,
        device: any DevicePlatform,
        simManager: SimulatorManager
    ) async throws -> CallTool.Result {
        var sections: [String] = []

        if let config {
            var configLines = ["[Config]", "  platform: \(platform.rawValue)"]
            switch platform {
            case .ios:
                if let scheme = config.scheme { configLines.append("  scheme: \(scheme)") }
                if let workspace = config.workspace { configLines.append("  workspace: \(workspace)") }
                if let project = config.project { configLines.append("  project: \(project)") }
                if let simulator = config.simulator { configLines.append("  simulator: \(simulator)") }
                if let bundleId = config.bundleId { configLines.append("  bundle_id: \(bundleId)") }
                if let buildSettings = config.buildSettings, !buildSettings.isEmpty {
                    configLines.append("  build_settings: \(buildSettings.joined(separator: " "))")
                }
            case .android:
                let android = config.android ?? AndroidProject()
                configLines.append("  module: \(android.module)")
                configLines.append("  variant: \(android.variant)")
                if let id = android.applicationId { configLines.append("  application_id: \(id)") }
                if let emulator = android.emulator { configLines.append("  emulator: \(emulator)") }
                if !android.buildArgs.isEmpty { configLines.append("  build_args: \(android.buildArgs.joined(separator: " "))") }
            }
            configLines.append("  screens: \(config.screens.count)")
            sections.append(configLines.joined(separator: "\n"))
        } else {
            sections.append("[Config]\n  No \(platform.configFileName) found in current directory.")
        }

        switch platform {
        case .ios:
            if let booted = try? await simManager.bootedDevice() {
                sections.append("[Simulator]\n  name: \(booted.name)\n  udid: \(booted.udid)\n  runtime: \(booted.runtime)\n  state: \(booted.state)")
            } else {
                sections.append("[Simulator]\n  No simulator booted.")
            }
            if let version = try? await shell("xcodebuild -version") {
                sections.append("[Xcode]\n  \(version.replacingOccurrences(of: "\n", with: "\n  "))")
            }
        case .android:
            if let booted = try? await device.defaultDevice() {
                sections.append("[Emulator]\n  name: \(booted.name)\n  serial: \(booted.udid)")
            } else {
                sections.append("[Emulator]\n  No emulator running.")
            }
            if let sdk = AndroidSDK.locate() {
                sections.append("[Android SDK]\n  \(sdk.root)")
            } else {
                sections.append("[Android SDK]\n  \(AndroidSDK.missingMessage)")
            }
        }

        if let session = try? RunnerSessionInfo.load(), session.isAlive {
            sections.append("""
                [Runner Session]
                  pid: \(session.pid)
                  \(platform == .ios ? "wda_port" : "driver_port"): \(session.wdaPort)
                  \(platform == .ios ? "bundle_id" : "application_id"): \(session.bundleId)
                  udid: \(session.udid)
                """)
        } else {
            sections.append("[Runner Session]\n  No active session.")
        }

        return CallTool.Result(content: [.text(text: sections.joined(separator: "\n\n"), annotations: nil, _meta: nil)])
    }
```

The tool description: "Get current project context: config, booted simulator or running emulator, Xcode or Android SDK, and runner session status."

- [ ] **Step 7: Run the tests to verify they pass**

Run: `swift build && swift test --filter GrantivaMCPTests`
Expected: PASS. Every existing MCP test still passes with `fakeDriver` and the new `registry(...)` defaults (iOS, empty-UDID session, fake device).

- [ ] **Step 8: Commit**

```bash
git add Sources/GrantivaMCP Sources/GrantivaCLI/MCPCommand.swift Tests/GrantivaMCPTests
git commit -m "Resolve the platform in the MCP server, attach the driver through it, and make the UI, script, VRT, and context tools platform-aware"
```

---

### Task 11: MCP build tools through the platform and the `grantiva_emulator_*` tools

**Files:**
- Modify: `Sources/GrantivaMCP/Tools/BuildTools.swift`, `Sources/GrantivaMCP/Tools/EmulatorTools.swift` (replace the Task 10 placeholder), `Sources/GrantivaMCP/ToolRegistry.swift`
- Test: `Tests/GrantivaMCPTests/BuildToolsTests.swift` (new), `Tests/GrantivaMCPTests/EmulatorToolsTests.swift` (new), `Tests/GrantivaMCPTests/ToolRegistrationTests.swift`, `ToolAnnotationsTests.swift`, `ToolSchemaTests.swift`, `ToolErrorContractTests.swift`, `ToolDispatchTests.swift`

**Interfaces:**
- Consumes: `DevicePlatform.bootDevice/build/install/launch`, `ResolvedProject`, `AndroidProject`, `AndroidPlatform.live/emulators/adb`, `EmulatorManager.ensure/deleteAVD/listAVDs`, `ADB.devices/avdName`, `AndroidSDK.missingMessage`.
- Produces:
  - `BuildTools.resolvedProject(platform:config:arguments:) throws -> ResolvedProject`
  - `BuildTools.build(device:platform:config:arguments:)`, `run(device:platform:config:arguments:)`, `test(runner:platform:config:simManager:arguments:)`
  - `EmulatorToolDependencies { listAVDs; listDevices; avdName; boot; ensure; delete; static live() throws }`
  - `EmulatorTools.definitions` (4 tools), `list(deps:arguments:)`, `boot(deps:config:arguments:)`, `ensure(deps:arguments:)`, `delete(deps:arguments:)`, `unavailable() -> CallTool.Result`
  - The advertised tool set becomes 22 names.

- [ ] **Step 1: Write the failing tests**

Create `Tests/GrantivaMCPTests/BuildToolsTests.swift`:

```swift
import Foundation
import GrantivaCore
import MCP
import XCTest
@testable import GrantivaMCP

@available(macOS 15, *)
final class BuildToolsTests: XCTestCase {
    private let androidConfig = GrantivaConfig(platform: .android, android: AndroidProject(module: "app", variant: "debug", applicationId: nil, emulator: "Pixel_8_API_35"))

    func testBuildOnIOSWithoutASchemeIsAToolError() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        let result = try await BuildTools.build(device: device, platform: .ios, config: nil, arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("no scheme specified"))
        XCTAssertTrue(device.calls.isEmpty)
    }

    func testResolvedProjectTakesArgumentsOverConfig() throws {
        let android = try BuildTools.resolvedProject(platform: .android, config: androidConfig, arguments: ["module": .string("mobile"), "variant": .string("freeDebug"), "emulator": .string("Other")])
        XCTAssertEqual(android.android?.module, "mobile")
        XCTAssertEqual(android.android?.variant, "freeDebug")
        XCTAssertEqual(android.simulator, "Other")
        let ios = try BuildTools.resolvedProject(platform: .ios, config: GrantivaConfig(scheme: "Demo", simulator: "iPhone 17"), arguments: ["simulator": .string("iPhone 16")])
        XCTAssertEqual(ios.scheme, "Demo")
        XCTAssertEqual(ios.simulator, "iPhone 16")
        XCTAssertThrowsError(try BuildTools.resolvedProject(platform: .ios, config: nil, arguments: [:]))
    }

    func testBuildOnAndroidBootsThenBuildsThroughThePlatform() async throws {
        let device = MCPFakeDevicePlatform(platform: .android)
        let result = try await BuildTools.build(device: device, platform: .android, config: androidConfig, arguments: [:])
        XCTAssertNil(result.isError)
        XCTAssertEqual(device.calls, ["bootDevice(Pixel_8_API_35)", "build(scheme=-,module=app,variant=debug)"])
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("Build succeeded"), text)
        XCTAssertTrue(text.contains("Product: /fake/app.apk"), text)
    }

    func testRunOnAndroidInstallsAndLaunchesWithTheBuiltApplicationID() async throws {
        let device = MCPFakeDevicePlatform(platform: .android)
        let result = try await BuildTools.run(device: device, platform: .android, config: androidConfig, arguments: [:])
        XCTAssertNil(result.isError)
        XCTAssertEqual(device.calls, [
            "bootDevice(Pixel_8_API_35)", "build(scheme=-,module=app,variant=debug)",
            "install(com.fake.built,/fake/app.apk)", "launch(com.fake.built)",
        ])
        XCTAssertTrue(try textContent(of: result).contains("Application ID: com.fake.built"))
    }

    func testRunOnIOSWithoutABundleIDIsAToolError() async throws {
        let device = MCPFakeDevicePlatform(platform: .ios)
        let result = try await BuildTools.run(device: device, platform: .ios, config: GrantivaConfig(scheme: "Demo"), arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("bundle_id"))
        XCTAssertTrue(device.calls.isEmpty)
    }

    func testTestOnAndroidReturnsAnErrorResult() async throws {
        let result = try await BuildTools.test(runner: XcodeBuildRunner(), platform: .android, config: androidConfig, simManager: .live, arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("iOS-only"))
    }
}
```

Create `Tests/GrantivaMCPTests/EmulatorToolsTests.swift`:

```swift
import Foundation
import GrantivaCore
import MCP
import XCTest
@testable import GrantivaMCP

@available(macOS 15, *)
final class EmulatorToolsTests: XCTestCase {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String] = []
        func add(_ s: String) { lock.withLock { items.append(s) } }
        var value: [String] { lock.withLock { items } }
    }

    private func deps(_ log: Log) -> EmulatorToolDependencies {
        EmulatorToolDependencies(
            listAVDs: { log.add("listAVDs"); return ["Pixel_8_API_35", "Pixel_7_API_34"] },
            listDevices: { log.add("listDevices"); return [ADBDevice(serial: "emulator-5554", state: "device"), ADBDevice(serial: "R58M1", state: "device")] },
            avdName: { serial in log.add("avdName(\(serial))"); return "Pixel_8_API_35" },
            boot: { name in log.add("boot(\(name))"); return BootedDevice(udid: "emulator-5554", name: name.isEmpty ? "Pixel_8_API_35" : name) },
            ensure: { name, image, boot in log.add("ensure(\(name),\(image ?? "-"),\(boot))"); return EmulatorProvisionResult(name: name, serial: boot ? "emulator-5556" : nil, created: true, state: boot ? "Booted" : "Shutdown") },
            delete: { name, force in log.add("delete(\(name),\(force))") }
        )
    }

    func testListPairsAVDsWithRunningSerials() async throws {
        let log = Log()
        let result = try await EmulatorTools.list(deps: deps(log), arguments: [:])
        let text = try textContent(of: result)
        XCTAssertEqual(text, "Name | Serial | State\nPixel_8_API_35 | emulator-5554 | Booted\nPixel_7_API_34 | - | Shutdown")
        XCTAssertEqual(log.value, ["listAVDs", "listDevices", "avdName(emulator-5554)"])
    }

    func testBootFallsBackToTheConfiguredEmulator() async throws {
        let log = Log()
        let config = GrantivaConfig(platform: .android, android: AndroidProject(emulator: "Pixel_8_API_35"))
        let result = try await EmulatorTools.boot(deps: deps(log), config: config, arguments: [:])
        XCTAssertTrue(try textContent(of: result).contains("Emulator booted: Pixel_8_API_35 (emulator-5554)"))
        XCTAssertEqual(log.value, ["boot(Pixel_8_API_35)"])
    }

    func testEnsureRequiresANameAndReturnsJSON() async throws {
        let log = Log()
        let missing = try await EmulatorTools.ensure(deps: deps(log), arguments: [:])
        XCTAssertEqual(missing.isError, true)
        XCTAssertTrue(try textContent(of: missing).contains("'name' is required"))
        let result = try await EmulatorTools.ensure(deps: deps(log), arguments: ["name": .string("New"), "system_image": .string("img"), "boot": .bool(true)])
        XCTAssertNil(result.isError)
        XCTAssertTrue(try textContent(of: result).contains(#""serial" : "emulator-5556""#))
        XCTAssertEqual(log.value, ["ensure(New,img,true)"])
    }

    func testDeleteRequiresANameAndPassesForce() async throws {
        let log = Log()
        XCTAssertEqual(try await EmulatorTools.delete(deps: deps(log), arguments: [:]).isError, true)
        let result = try await EmulatorTools.delete(deps: deps(log), arguments: ["name": .string("Old"), "force": .bool(true)])
        XCTAssertEqual(try textContent(of: result), #"{"deleted":true,"name":"Old"}"#)
        XCTAssertEqual(log.value, ["delete(Old,true)"])
    }

    func testWithoutAnSDKEveryEmulatorToolReturnsAnErrorResult() async throws {
        let result = try await EmulatorTools.list(deps: nil, arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(try textContent(of: result).contains("Android SDK not found"))
    }

    func testEmulatorToolsDispatchThroughTheRegistry() async throws {
        let log = Log()
        let registry = ToolRegistry(
            driver: MCPTestSupport.fakeDriver(recorder: WDARecorder()), platform: .android, device: MCPFakeDevicePlatform(platform: .android),
            config: nil, session: MCPTestSupport.sessionWithoutUDID(), simulatorManager: .live, buildRunner: XcodeBuildRunner(), emulators: deps(log)
        )
        _ = try await registry.call(name: "grantiva_emulator_list", arguments: [:], server: MCPTestSupport.disconnectedServer())
        XCTAssertEqual(log.value.first, "listAVDs")
    }
}
```

Update the pinned surface:
- `ToolRegistrationTests.expectedToolNames`: add a `// Emulator` group with `"grantiva_emulator_list"`, `"grantiva_emulator_boot"`, `"grantiva_emulator_ensure"`, `"grantiva_emulator_delete"`.
- `ToolAnnotationsTests`: `allTools` gains `+ EmulatorTools.definitions`; the count assertions become `22`; `testMutatingToolsAreNotMarkedReadOnly` adds `"grantiva_emulator_boot", "grantiva_emulator_ensure", "grantiva_emulator_delete"`; `testReadOnlyToolsAreMarkedReadOnly` adds `"grantiva_emulator_list"`. If the file has a destructive-hint test listing `grantiva_sim_delete`, add `grantiva_emulator_delete` beside it.
- `ToolSchemaTests`: wherever the tools are collected, include `EmulatorTools.definitions`; in `testRequiredParametersMatchTheDocumentedContract` add `"grantiva_emulator_ensure": ["name"]` and `"grantiva_emulator_delete": ["name"]`.
- `ToolErrorContractTests`: add

```swift
    func testEmulatorEnsureAndDeleteMissingNameReturnToolErrors() async throws {
        let deps = EmulatorToolDependencies(
            listAVDs: { [] }, listDevices: { [] }, avdName: { _ in "" },
            boot: { _ in BootedDevice(udid: "", name: "") },
            ensure: { _, _, _ in XCTFail("must not run"); return EmulatorProvisionResult(name: "", serial: nil, created: false, state: "") },
            delete: { _, _ in XCTFail("must not run") }
        )
        XCTAssertEqual(try await EmulatorTools.ensure(deps: deps, arguments: [:]).isError, true)
        XCTAssertEqual(try await EmulatorTools.delete(deps: deps, arguments: ["name": .int(3)]).isError, true)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter GrantivaMCPTests`
Expected: compile errors (`BuildTools.resolvedProject`, new `build/run/test` labels, `EmulatorTools`, `EmulatorToolDependencies` init).

- [ ] **Step 3: Implement the build tools**

Replace the three handlers in `BuildTools` with:

```swift
    /// What the platform builds: scheme and simulator on iOS, module and
    /// variant on Android. Arguments win over the config file.
    static func resolvedProject(platform: Platform, config: GrantivaConfig?, arguments: [String: Value]) throws -> ResolvedProject {
        switch platform {
        case .ios:
            guard let scheme = arguments["scheme"]?.stringValue ?? config?.scheme else {
                throw GrantivaError.invalidArgument("no scheme specified. Pass 'scheme' or set it in grantiva.yml.")
            }
            return ResolvedProject(
                scheme: scheme, project: config?.project, workspace: config?.workspace,
                bundleId: config?.bundleId, buildSettings: config?.buildSettings ?? [],
                simulator: arguments["simulator"]?.stringValue ?? config?.simulator ?? "iPhone 16"
            )
        case .android:
            let configured = config?.android ?? AndroidProject()
            let android = AndroidProject(
                module: arguments["module"]?.stringValue ?? configured.module,
                variant: arguments["variant"]?.stringValue ?? configured.variant,
                applicationId: configured.applicationId,
                emulator: arguments["emulator"]?.stringValue ?? configured.emulator,
                systemImage: configured.systemImage,
                buildArgs: configured.buildArgs
            )
            return ResolvedProject(
                bundleId: configured.applicationId, buildSettings: configured.buildArgs,
                simulator: android.emulator ?? "", android: android
            )
        }
    }

    private static func toolError(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: "Error: \(message)", annotations: nil, _meta: nil)], isError: true)
    }

    static func build(
        device: any DevicePlatform,
        platform: Platform,
        config: GrantivaConfig?,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let resolved: ResolvedProject
        do {
            resolved = try resolvedProject(platform: platform, config: config, arguments: arguments)
        } catch let error as GrantivaError {
            return toolError(error.errorDescription ?? "\(error)")
        }
        let booted = try await device.bootDevice(named: resolved.simulator)
        let result = try await device.build(PlatformBuildRequest(
            config: config ?? GrantivaConfig(), resolved: resolved, deviceID: booted.udid, extraBuildSettings: resolved.buildSettings
        ))
        var summary = """
            Build \(result.success ? "succeeded" : "FAILED")
            Scheme: \(result.scheme ?? "(none)")
            Duration: \(String(format: "%.1fs", result.duration))
            Warnings: \(result.warnings.count)
            Errors: \(result.errors.count)\(result.errors.isEmpty ? "" : "\n" + result.errors.joined(separator: "\n"))
            """
        if let productPath = result.productPath {
            summary += "\nProduct: \(productPath)"
        }
        return CallTool.Result(
            content: [.text(text: summary, annotations: nil, _meta: nil)],
            isError: !result.success ? true : nil
        )
    }

    static func run(
        device: any DevicePlatform,
        platform: Platform,
        config: GrantivaConfig?,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        let resolved: ResolvedProject
        do {
            resolved = try resolvedProject(platform: platform, config: config, arguments: arguments)
        } catch let error as GrantivaError {
            return toolError(error.errorDescription ?? "\(error)")
        }
        if platform == .ios, resolved.bundleId == nil {
            return toolError("no bundle_id in grantiva.yml. Cannot launch app.")
        }

        let booted = try await device.bootDevice(named: resolved.simulator)
        let buildResult = try await device.build(PlatformBuildRequest(
            config: config ?? GrantivaConfig(), resolved: resolved, deviceID: booted.udid, extraBuildSettings: resolved.buildSettings
        ))
        guard buildResult.success else {
            return CallTool.Result(
                content: [.text(text: "Build failed:\n\(buildResult.errors.joined(separator: "\n"))", annotations: nil, _meta: nil)],
                isError: true
            )
        }
        guard let appID = resolved.bundleId ?? buildResult.applicationId else {
            return toolError("no application_id in grantiva-android.yml and the build did not report one. Cannot launch app.")
        }
        if let productPath = buildResult.productPath {
            try await device.install(appID: appID, productPath: productPath, deviceID: booted.udid)
        }
        try await device.launch(appID: appID, deviceID: booted.udid)

        let text: String
        switch platform {
        case .ios:
            text = "App built and launched.\nScheme: \(resolved.scheme ?? "")\nBundle ID: \(appID)\nSimulator: \(booted.name)"
        case .android:
            let android = resolved.android ?? AndroidProject()
            text = "App built and launched.\nModule: \(android.module) (\(android.variant))\nApplication ID: \(appID)\nDevice: \(booted.name) (\(booted.udid))"
        }
        return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)])
    }

    static func test(
        runner: XcodeBuildRunner,
        platform: Platform,
        config: GrantivaConfig?,
        simManager: SimulatorManager,
        arguments: [String: Value]
    ) async throws -> CallTool.Result {
        guard platform == .ios else {
            return toolError("grantiva_test runs xcodebuild test and is iOS-only; run ./gradlew connectedAndroidTest yourself.")
        }
        // (the existing iOS body, unchanged)
```

Schema additions on `grantiva_build` and `grantiva_run` (keep the existing `scheme` and `simulator` entries):

```swift
                    "module": .object([
                        "type": .string("string"),
                        "description": .string("Gradle module to assemble (Android; uses grantiva-android.yml, default app)"),
                    ]),
                    "variant": .object([
                        "type": .string("string"),
                        "description": .string("Gradle build variant, e.g. debug or freeDebug (Android; default debug)"),
                    ]),
                    "emulator": .object([
                        "type": .string("string"),
                        "description": .string("AVD name to use, booting it if needed (Android; uses grantiva-android.yml)"),
                    ]),
```

Descriptions: `grantiva_build` "Build the project: xcodebuild on iOS, Gradle on Android. Returns ...", `grantiva_run` "Build, install, and launch the app on the simulator or emulator.", `grantiva_test` "Run the project's test suite using xcodebuild test (iOS only). Returns pass/fail counts and output."

Registry dispatch:

```swift
        case "grantiva_build":
            result = try await BuildTools.build(device: device, platform: platform, config: config, arguments: arguments)
        case "grantiva_run":
            result = try await BuildTools.run(device: device, platform: platform, config: config, arguments: arguments)
        case "grantiva_test":
            result = try await BuildTools.test(runner: buildRunner, platform: platform, config: config, simManager: simulatorManager, arguments: arguments)
```

- [ ] **Step 4: Implement the emulator tools**

Replace `Sources/GrantivaMCP/Tools/EmulatorTools.swift` with:

```swift
import Foundation
import GrantivaCore
import MCP

/// What the emulator tools need from the Android layer, as closures so the
/// handlers are testable without an SDK. `nil` in the registry means the SDK
/// is not installed on this Mac.
struct EmulatorToolDependencies: Sendable {
    var listAVDs: @Sendable () async throws -> [String]
    var listDevices: @Sendable () async throws -> [ADBDevice]
    var avdName: @Sendable (String) async throws -> String
    var boot: @Sendable (String) async throws -> BootedDevice
    var ensure: @Sendable (String, String?, Bool) async throws -> EmulatorProvisionResult
    var delete: @Sendable (String, Bool) async throws -> Void

    static func live() throws -> EmulatorToolDependencies {
        let platform = try AndroidPlatform.live()
        return EmulatorToolDependencies(
            listAVDs: { try await platform.emulators.listAVDs() },
            listDevices: { try await platform.adb.devices() },
            avdName: { try await platform.adb.avdName(serial: $0) },
            boot: { try await platform.bootDevice(named: $0) },
            ensure: { try await platform.emulators.ensure(avd: $0, systemImage: $1, boot: $2) },
            delete: { try await platform.emulators.deleteAVD(name: $0, force: $1) }
        )
    }
}

/// Android emulator management: the `grantiva_sim_*` twins.
@available(macOS 15, *)
enum EmulatorTools {
    static let definitions: [Tool] = [
        Tool(
            name: "grantiva_emulator_list",
            description: "List Android Virtual Devices with the serial of each one that is running.",
            inputSchema: .object(["type": .string("object"), "properties": .object([:])]),
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_emulator_boot",
            description: "Boot an Android emulator by AVD name, or use it if it is already running. Defaults to emulator in grantiva-android.yml.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object(["type": .string("string"), "description": .string("AVD name (default: emulator in grantiva-android.yml)")]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_emulator_ensure",
            description: "Create an AVD when missing (installing its system image first) and optionally boot it. Only 'name' is required.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object(["type": .string("string")]),
                    "system_image": .object(["type": .string("string"), "description": .string("System image package, e.g. system-images;android-35;google_apis;arm64-v8a")]),
                    "boot": .object(["type": .string("boolean")]),
                ]),
                "required": .array([.string("name")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "grantiva_emulator_delete",
            description: "Delete an AVD Grantiva created. Pass force to delete one it did not create. A running AVD is never deleted.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object(["type": .string("string")]),
                    "force": .object(["type": .string("boolean")]),
                ]),
                "required": .array([.string("name")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false)
        ),
    ]

    static func unavailable() -> CallTool.Result {
        CallTool.Result(content: [.text(text: "Error: \(AndroidSDK.missingMessage)", annotations: nil, _meta: nil)], isError: true)
    }

    private static func toolError(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: "Error: \(message)", annotations: nil, _meta: nil)], isError: true)
    }

    static func list(deps: EmulatorToolDependencies?, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let deps else { return unavailable() }
        let avds = try await deps.listAVDs()
        var running: [String: String] = [:]
        for device in try await deps.listDevices() where device.isEmulator && device.isUsable {
            if let name = try? await deps.avdName(device.serial) { running[name] = device.serial }
        }
        let lines = avds.map { "\($0) | \(running[$0] ?? "-") | \(running[$0] == nil ? "Shutdown" : "Booted")" }
        let output = lines.isEmpty ? "No AVDs found. Create one with grantiva_emulator_ensure." : "Name | Serial | State\n" + lines.joined(separator: "\n")
        return CallTool.Result(content: [.text(text: output, annotations: nil, _meta: nil)])
    }

    static func boot(deps: EmulatorToolDependencies?, config: GrantivaConfig?, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let deps else { return unavailable() }
        let name = arguments["name"]?.stringValue ?? config?.android?.emulator ?? ""
        let device = try await deps.boot(name)
        return CallTool.Result(content: [.text(text: "Emulator booted: \(device.name) (\(device.udid))", annotations: nil, _meta: nil)])
    }

    static func ensure(deps: EmulatorToolDependencies?, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let deps else { return unavailable() }
        guard let name = arguments["name"]?.stringValue else { return toolError("'name' is required.") }
        let result = try await deps.ensure(name, arguments["system_image"]?.stringValue, arguments["boot"]?.boolValue ?? false)
        return CallTool.Result(content: [.text(text: try JSONOutput.string(result), annotations: nil, _meta: nil)])
    }

    static func delete(deps: EmulatorToolDependencies?, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let deps else { return unavailable() }
        guard let name = arguments["name"]?.stringValue else { return toolError("'name' is required.") }
        try await deps.delete(name, arguments["force"]?.boolValue ?? false)
        let data = try JSONSerialization.data(withJSONObject: ["deleted": true, "name": name], options: [.sortedKeys])
        return CallTool.Result(content: [.text(text: String(decoding: data, as: UTF8.self), annotations: nil, _meta: nil)])
    }
}
```

Registry: `allTools()` adds `+ EmulatorTools.definitions` after `SimTools.definitions`; dispatch adds:

```swift
        // Emulator Tools
        case "grantiva_emulator_list":
            result = try await EmulatorTools.list(deps: emulators, arguments: arguments)
        case "grantiva_emulator_boot":
            result = try await EmulatorTools.boot(deps: emulators, config: config, arguments: arguments)
        case "grantiva_emulator_ensure":
            result = try await EmulatorTools.ensure(deps: emulators, arguments: arguments)
        case "grantiva_emulator_delete":
            result = try await EmulatorTools.delete(deps: emulators, arguments: arguments)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter GrantivaMCPTests`
Expected: PASS, 22 tools registered.

- [ ] **Step 6: Commit**

```bash
git add Sources/GrantivaMCP Tests/GrantivaMCPTests
git commit -m "Route MCP build and run through the platform and add the grantiva_emulator tools"
```

---

### Task 12: Ship the UIAutomator2 APKs once, outside the per-arch runner tarballs

**Files:**
- Modify: `Sources/GrantivaCore/Resources/grantiva-runner-arm64.tar.gz`, `Sources/GrantivaCore/Resources/grantiva-runner-amd64.tar.gz` (repacked without `drivers/android`)
- Create: `Sources/GrantivaCore/Resources/android-drivers.tar.gz`
- Modify: `Package.swift`, `Sources/GrantivaCore/Runner/RunnerManager.swift`
- Test: `Tests/GrantivaCoreTests/RunnerManagerTests.swift`

**Interfaces:**
- Consumes: `RunnerManager.installIfNeeded`, `embeddedTarballURL(arch:)`.
- Produces: `RunnerManager.embeddedDriversTarballURL() -> URL?`, `installStamp == "1.1.18-grantiva.7+android-drivers-2"`. The installed layout is unchanged: `~/.grantiva/runner/drivers/android/*.apk` beside `drivers/ios`.

- [ ] **Step 1: Write the failing tests**

In `Tests/GrantivaCoreTests/RunnerManagerTests.swift` replace `testEmbeddedTarballContainsTheUIAutomator2APKs` and `testInstallStampChangesWhenDriversChangeButRunnerVersionDoesNot` with:

```swift
    func testArchTarballsNoLongerCarryTheAndroidDrivers() throws {
        for arch in ["arm64", "amd64"] {
            let url = try XCTUnwrap(RunnerManager.embeddedTarballURL(arch: arch))
            let listing = try listTarball(url)
            XCTAssertTrue(listing.contains("./grantiva-runner"), arch)
            XCTAssertFalse(listing.contains { $0.hasPrefix("./drivers/android/") }, "APKs ship once, in android-drivers.tar.gz: \(arch)")
            XCTAssertFalse(listing.contains { $0.contains("/._") }, "no AppleDouble entries: \(arch)")
        }
    }

    func testEmbeddedDriversTarballContainsTheUIAutomator2APKs() throws {
        let url = try XCTUnwrap(RunnerManager.embeddedDriversTarballURL())
        let listing = try listTarball(url)
        XCTAssertTrue(listing.contains("./drivers/android/appium-uiautomator2-server-v9.11.1.apk"))
        XCTAssertTrue(listing.contains("./drivers/android/appium-uiautomator2-server-debug-androidTest.apk"))
        XCTAssertEqual(listing.filter { $0.hasSuffix(".apk") }.count, 2, "only the two UIA2 APKs ship")
        XCTAssertFalse(listing.contains { $0.contains("/._") })
    }

    func testInstallStampChangesWhenDriversMoveButRunnerVersionDoesNot() {
        XCTAssertEqual(RunnerManager.runnerVersion, "1.1.18-grantiva.7")
        XCTAssertEqual(RunnerManager.installStamp, "1.1.18-grantiva.7+android-drivers-2")
    }

    func testLiveExtractionLaysOutBothTarballs() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("runner-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: base) }
        try RunnerManager.installIfNeeded(
            baseDir: base, binaryPath: "\(base)/grantiva-runner", versionFilePath: "\(base)/version",
            cacheDir: "\(base)/cache", version: RunnerManager.installStamp, extract: RunnerManager.extractEmbedded
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(base)/grantiva-runner"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(base)/drivers/android/appium-uiautomator2-server-v9.11.1.apk"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(base)/drivers/ios/WebDriverAgent/package.json"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter RunnerManagerTests`
Expected: compile errors (`embeddedDriversTarballURL`, `extractEmbedded`) and, once those exist, the arch-tarball test fails because the APKs are still inside.

- [ ] **Step 3: Repack the tarballs**

From the repository root (no `cd`; every command is a plain line):

```bash
WORK=$(mktemp -d /tmp/grantiva-repack.XXXXXX)
mkdir -p "$WORK/arm64" "$WORK/amd64" "$WORK/drivers/drivers"
tar -xzf Sources/GrantivaCore/Resources/grantiva-runner-arm64.tar.gz -C "$WORK/arm64"
tar -xzf Sources/GrantivaCore/Resources/grantiva-runner-amd64.tar.gz -C "$WORK/amd64"
cp -R "$WORK/arm64/drivers/android" "$WORK/drivers/drivers/android"
rm -r "$WORK/arm64/drivers/android" "$WORK/amd64/drivers/android"
COPYFILE_DISABLE=1 tar -czf Sources/GrantivaCore/Resources/grantiva-runner-arm64.tar.gz -C "$WORK/arm64" .
COPYFILE_DISABLE=1 tar -czf Sources/GrantivaCore/Resources/grantiva-runner-amd64.tar.gz -C "$WORK/amd64" .
COPYFILE_DISABLE=1 tar -czf Sources/GrantivaCore/Resources/android-drivers.tar.gz -C "$WORK/drivers" .
rm -r "$WORK"
ls -l Sources/GrantivaCore/Resources
tar -tzf Sources/GrantivaCore/Resources/android-drivers.tar.gz
```

Expected: both arch tarballs are about 17 MB smaller than before (arm64 ≈ 32 MB, amd64 ≈ 33 MB), `android-drivers.tar.gz` is about 17 MB, and its listing is exactly `./`, `./drivers/`, `./drivers/android/`, and the two APKs.

If the shell you run in refuses `$(mktemp ...)`, use a fixed path under your scratch directory instead of `WORK=$(mktemp -d ...)`.

- [ ] **Step 4: Teach RunnerManager about the second tarball**

In `Package.swift`, add `.copy("Resources/android-drivers.tar.gz"),` to the `GrantivaCore` resources.

In `RunnerManager`:

```swift
    public static let installStamp = runnerVersion + "+android-drivers-2"

    static func embeddedDriversTarballURL() -> URL? {
        Bundle.module.url(forResource: "android-drivers", withExtension: "tar.gz")
    }

    /// Extracts the arch runner tarball, then the shared Android drivers,
    /// into `destination`. Both unpack relative to `./`, so the result is
    /// `grantiva-runner`, `drivers/ios/…`, `drivers/android/*.apk`.
    static func extractEmbedded(into destination: String) throws {
        guard let runner = embeddedTarballURL(arch: currentArch), let drivers = embeddedDriversTarballURL() else {
            throw GrantivaError.runnerNotFound
        }
        for tarball in [runner, drivers] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xzf", tarball.path, "-C", destination]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw GrantivaError.commandFailed("Failed to extract \(tarball.lastPathComponent)", process.terminationStatus)
            }
        }
    }
```

`currentArch` becomes `static var currentArch` (drop `private`). In `live.ensureAvailable`, replace the `guard let tarURL = embeddedTarballURL(...)` and the `installIfNeeded(... ) { destination in ... }` closure with `try installIfNeeded(baseDir: baseDir, binaryPath: binaryPath, versionFilePath: versionFilePath, cacheDir: cacheDir, version: installStamp, extract: extractEmbedded)`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter RunnerManagerTests`
Expected: PASS. Then `swift build` and `git status --short Sources/GrantivaCore/Resources` shows two modified tarballs and one new one.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/GrantivaCore/Runner/RunnerManager.swift Sources/GrantivaCore/Resources Tests/GrantivaCoreTests/RunnerManagerTests.swift
git commit -m "Ship the UIAutomator2 APKs once in android-drivers.tar.gz and shrink the runner tarballs"
```

---

### Task 13: Docs, changelog, and the acceptance pass on the emulator

**Files:**
- Modify: `docs/android.md`, `CHANGELOG.md`, `README.md`
- Create: `docs/superpowers/plans/2026-10-08-android-plan3-acceptance.md`

**Interfaces:** none new. This task runs the shipped commands against the host emulator and records what happened.

- [ ] **Step 1: Documentation**

In `docs/android.md`, replace the `## Not yet` section with:

````markdown
## Hierarchy and keep-alive

    grantiva run --keep-alive            # terminal 1, holds the UIAutomator2 session
    grantiva hierarchy                   # terminal 2: the UIAutomator2 page source (XML)
    grantiva hierarchy --format json     # the same tree as JSON, frames in dp

The runner does not proxy UIAutomator2, so Grantiva forwards a local port to the
emulator's port 6790 (`adb forward tcp:0 tcp:6790`) for the duration of the command and
reads the session the runner holds. `--udid <serial>` picks a session when several are
live. `runner dump-hierarchy` reads the same tree and prints it as a tree, JSON, or XML.

## Recording

    grantiva record --duration 5 --frames-at 0,1000,3000

Records with `screenrecord` to `.grantiva/recordings/recording.mp4` and extracts frames
as PNGs. Android caps a recording at 180 seconds; longer durations are refused.
`--device <serial>` or `--emulator <AVD>` pick the target; the config's `emulator` is the
default.

## Runner sessions and the MCP server

    grantiva runner start --detach       # boots the emulator, holds a UIAutomator2 session
    grantiva runner dump-hierarchy --format tree
    grantiva mcp                         # in another terminal, or from an agent config
    grantiva runner stop

`runner start` records the forwarded local port in `.grantiva/session.json`; `runner stop`
kills the runner, stops the UIAutomator2 server, and removes the serial's forwards. The MCP
server resolves the platform like every command (a directory with only
`grantiva-android.yml` is Android) and drives the emulator through the same tools as iOS:
`grantiva_tap` takes device pixels for `x`/`y`, `grantiva_a11y_check` uses 48 dp as the
minimum tap target, and `grantiva_emulator_list|boot|ensure|delete` mirror the
`grantiva_sim_*` tools. `grantiva_test` is iOS-only.

## Emulator subcommand

    grantiva emulator ensure --name Pixel_8_API_35          # create if missing, boot, print the serial
    grantiva emulator ensure --name Pixel_8_API_35 --no-boot
    grantiva emulator sessions                              # emulators Grantiva started
    grantiva emulator teardown --serial emulator-5554       # only emulators Grantiva started; --force for others
    grantiva emulator teardown --all
    grantiva emulator delete --name Pixel_8_API_35          # only AVDs Grantiva created; --force for others

`ensure` installs the system image with `sdkmanager` when it is missing and creates the AVD
with `avdmanager create avd -d pixel_8`. The system image comes from `--system-image`, then
`system_image` in the config, then `system-images;android-35;google_apis;arm64-v8a`.
````

In `CHANGELOG.md` under `## Unreleased` → `### Added`, after the existing Android bullets, add:

```markdown
- `grantiva hierarchy`, `runner dump-hierarchy`, `record`, `runner start`, `runner stop`, and the MCP server work on Android. The CLI forwards a local port to the emulator's UIAutomator2 server (`adb forward tcp:0 tcp:6790`) and reuses the runner's session; `hierarchy --format json` reports frames in dp.
- `grantiva emulator ensure|delete|sessions|teardown`: create and boot AVDs (installing the system image first), list and kill the emulators Grantiva started, and delete the AVDs it created. `teardown --force` and `delete --force` act on emulators and AVDs Grantiva did not start or create.
- MCP tools `grantiva_emulator_list`, `grantiva_emulator_boot`, `grantiva_emulator_ensure`, and `grantiva_emulator_delete`. `grantiva_build` and `grantiva_run` accept `module`, `variant`, and `emulator` on Android. `grantiva_a11y_check` keys Android rules on `class`, `content-desc`, and `clickable`, with a 48 dp minimum tap target.
- `--logs-level` on Android without `--logs-tag` filters every tag at that priority.
```

and under `### Changed`:

```markdown
- The UIAutomator2 APKs ship once, in `android-drivers.tar.gz`, instead of inside both per-arch runner tarballs (each is ~17 MB smaller). Existing installs re-extract once on first use.
- `adb forward --remove-all` is no longer used; orphan cleanup removes only the serial's own forwards.
- `--device` together with `--emulator` is rejected.
```

In `README.md`, extend the Android paragraph's command list to include `hierarchy`, `record`, `runner start/stop`, `emulator`, and the MCP server.

- [ ] **Step 2: Build the binary used for acceptance**

Run: `swift build`
Expected: builds; `.build/debug/grantiva --help` lists `emulator` between `simulator` and `hierarchy`.

- [ ] **Step 3: Acceptance on the emulator**

Preconditions: `Pixel_8_API_35` is running as `emulator-5554` (started by hand, so it is not in Grantiva's ledger and must survive this pass). `JAVA_HOME` and `ANDROID_HOME` exported as `scripts/android-env.sh` prints. Work in `examples/android`. Use `G=$PWD/.build/debug/grantiva` from the repo root, then every command below runs with `-C`-free absolute paths (run them from `examples/android`).

Record each step's command, exit code, and the lines that prove it in `docs/superpowers/plans/2026-10-08-android-plan3-acceptance.md` as you go, in the same shape as the Plan 2 record.

1. `$G emulator sessions` → "No emulators started by Grantiva are running." (exit 0).
2. `$G emulator ensure --name Pixel_8_API_35` → stdout exactly `emulator-5554`; stderr "Reused Pixel_8_API_35 (emulator-5554) — Booted".
3. `$G build` → exit 0, `APK:` line.
4. Keep-alive and hierarchy:
   - `$G run --keep-alive --ready-file /tmp/grantiva-ready.json &` then poll until the ready file exists (`while [ ! -f /tmp/grantiva-ready.json ]; do sleep 0.2; done`).
   - `$G hierarchy > /tmp/hier.xml` → exit 0, file contains `package="dev.grantiva.example"` and at least one `bounds=`.
   - `$G hierarchy --format json | head -c 400` → begins with `{` and contains `"platform" : "android"`.
   - `$G runner dump-hierarchy --format tree | head -20` → lines like `[android.widget.FrameLayout]` and a node with `label="Details"`.
   - `$ANDROID_HOME/platform-tools/adb forward --list` → empty (every command detached its forward).
   - `kill -INT <pid of the backgrounded run>` (capture `$!` right after starting it) and `wait` for it; `adb forward --list` still empty; `.grantiva/android-settings-emulator-5554.json` absent.
5. `$G record --duration 5 --frames-at 0,1000,3000` → exit 0; `.grantiva/recordings/recording.mp4` exists; three PNGs under `.grantiva/recordings/recording-frames/` at 1080×2400 (`sips -g pixelWidth -g pixelHeight`).
6. `$G record --duration 200` → exit 1 with "capped at 180 seconds".
7. Runner session and MCP:
   - `$G runner start --detach` → prints "UIAutomator2 port: <n>", "PID:", "Session: .grantiva/session.json".
   - `$G runner dump-hierarchy --format tree | head -5` → tree output.
   - Write this script to the scratch directory as `mcp-probe.py` and run `python3 mcp-probe.py "$G"`; it speaks newline-delimited JSON-RPC over stdio to `grantiva mcp`:

     ```python
     import json, subprocess, sys
     proc = subprocess.Popen([sys.argv[1], "mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
     def call(i, method, params=None):
         proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": i, "method": method, "params": params or {}}) + "\n"); proc.stdin.flush()
         while True:
             line = proc.stdout.readline()
             if not line: raise SystemExit("server closed")
             msg = json.loads(line)
             if msg.get("id") == i: return msg
     print(call(1, "initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "probe", "version": "0"}})["result"]["serverInfo"])
     proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n"); proc.stdin.flush()
     tools = call(2, "tools/list")["result"]["tools"]; print("tools:", len(tools))
     for name, args in [("grantiva_context", {}), ("grantiva_emulator_list", {}), ("grantiva_screenshot", {"format": "file"}),
                        ("grantiva_tap", {"label": "Details"}), ("grantiva_a11y_check", {}), ("grantiva_swipe", {"direction": "up"})]:
         r = call(10 + len(name), "tools/call", {"name": name, "arguments": args})["result"]
         text = next((c["text"] for c in r["content"] if c["type"] == "text"), "")
         print(name, "isError" if r.get("isError") else "ok", text[:160].replace("\n", " | "))
     proc.stdin.close(); proc.wait(timeout=10)
     ```

     Expected: `tools: 22`; `grantiva_context` shows `[Emulator]` with `serial: emulator-5554`; `grantiva_emulator_list` shows `Pixel_8_API_35 | emulator-5554 | Booted`; `grantiva_screenshot` says "Screenshot saved to .grantiva/mcp-screenshot.png" and the file is a 1080×2400 PNG; `grantiva_tap` says `Tapped on "Details"` and the hierarchy that follows contains `"Line three."`; `grantiva_a11y_check` returns either "No accessibility violations found." or a JSON list (record which); `grantiva_swipe` says "Swiped up".
   - `$G runner stop` → "Runner stopped (pid …)"; `adb forward --list` empty; `adb shell pidof io.appium.uiautomator2.server` prints nothing.
8. Emulator lifecycle on a second AVD (the host's `Pixel_8_API_35` stays untouched):
   - `$G emulator ensure --name Grantiva_Plan3_Test --headless` → stdout `emulator-5556` (the image is already installed, so no download; AVD creation plus boot takes one to three minutes). stderr "Created Grantiva_Plan3_Test (emulator-5556) — Booted".
   - `$G emulator sessions` → one line for `emulator-5556 (Grantiva_Plan3_Test) — pid … running, adb: device`.
   - `$G emulator teardown --serial emulator-5554` → exit 1, "emulator-5554 was not started by Grantiva … Pass --force". Do not pass `--force`.
   - `$G emulator delete --name Grantiva_Plan3_Test` → exit 1, "running as emulator-5556".
   - `$G emulator teardown --serial emulator-5556` → "Killed emulator-5556 (Grantiva_Plan3_Test)."; `adb devices` no longer lists 5556; `$G emulator sessions` → none.
   - `$G emulator delete --name Pixel_8_API_35` → exit 1, "running as emulator-5554".
   - `$G emulator delete --name Grantiva_Plan3_Test` → "Deleted AVD Grantiva_Plan3_Test"; `emulator -list-avds` no longer lists it; `~/.grantiva/android/created-avds.json` is `[]`.
9. `$G ci run` → exit 1 with the local-only message (unchanged from Plan 2).
10. From the repo root: `swift test` → 0 failures; record the count.
11. iOS smoke: from `examples/ios` (or wherever the Landmarks example lives), `$G run --no-build` once. If the host still has two simulators named "iPhone 17 Pro", record the exact error and move on; it is a host problem, not a regression (Plan 2 recorded the same).
12. Leave the host as found: `emulator-5554` running, `adb forward --list` empty, no `io.appium.uiautomator2.server` process (`adb shell pidof io.appium.uiautomator2.server` empty), `~/.grantiva/android/started.json` without a 5556 record, no `Grantiva_Plan3_Test` AVD.

If a step fails because of a defect in this branch, stop, record the failure verbatim, and report BLOCKED with the step number; the controller rules on the fix. A failure caused by the host (simulator duplicates, a network-less `sdkmanager`) is recorded and the pass continues.

- [ ] **Step 4: Commit**

```bash
git add docs/android.md CHANGELOG.md README.md docs/superpowers/plans/2026-10-08-android-plan3-acceptance.md
git commit -m "Document Android hierarchy, record, runner sessions, MCP, and the emulator subcommand; record the Plan 3 acceptance pass"
```

---

## Hand-off

Deferred past Plan 3, with the reason:

- **`grantiva_test` on Android** returns an error result. There is no `grantiva test` CLI command and no result parser for `connectedAndroidTest`; adding one is a feature of its own.
- **Recordings over 180 s on Android** are refused rather than chained across files.
- **Remote Android baselines** stay blocked on the backend's platform-keyed baseline work (separate plan, unchanged from Plan 2).
- **`runner start` without `--detach` on Android** drains the runner's stdout silently while waiting for the UIAutomator2 session; iOS still echoes it for port discovery. Cosmetic.
- **A physical device with `runner start`** works through `--device <serial>` but has had no acceptance run; only emulators were exercised.
