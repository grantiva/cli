import XCTest
@testable import GrantivaCore

final class SimulatorManagerTests: XCTestCase {
    // MARK: - I02: never guess among several booted simulators

    private func device(_ name: String, _ udid: String, _ state: String = "Booted") -> SimulatorDevice {
        SimulatorDevice(name: name, udid: udid, state: state, runtime: "iOS-26-0", isAvailable: true)
    }

    func testSoleBootedReturnsTheOnlyBootedSimulator() throws {
        let devices = [device("Off", "OFF", "Shutdown"), device("qa-ios-1", "QA-1")]
        XCTAssertEqual(try SimulatorManager.soleBooted(in: devices).udid, "QA-1")
    }

    func testSoleBootedRefusesToPickAmongSeveralAndNamesThem() {
        let devices = [device("iPhone 17 Pro", "B27D7D31"), device("qa-ios-1", "QA-1")]
        XCTAssertThrowsError(try SimulatorManager.soleBooted(in: devices)) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("iPhone 17 Pro (B27D7D31)"), message)
            XCTAssertTrue(message.contains("qa-ios-1 (QA-1)"), message)
            XCTAssertTrue(message.contains("--simulator"), message)
            XCTAssertTrue(message.contains("simulator:"), message)
        }
    }

    func testSoleBootedWithNoneBootedIsSimulatorNotRunning() {
        XCTAssertThrowsError(try SimulatorManager.soleBooted(in: [device("Off", "OFF", "Shutdown")])) { error in
            guard case GrantivaError.simulatorNotRunning = error else { return XCTFail("\(error)") }
        }
    }

    func testIPhone15ProPixelMetricsConvertToExpectedPointGeometry() {
        let geometry = SimulatorManager.geometry(pixelWidth: 1179, pixelHeight: 2556, scale: 3)
        XCTAssertEqual(geometry.points, [393, 852])
        XCTAssertEqual(geometry.pixels, [1179, 2556])
        XCTAssertEqual(geometry.scale, 3)
    }

    func testCaptureTargetEncodesNamedSimulatorAndExactGeometry() throws {
        let target = CaptureSimulatorTarget(
            name: "APP-302 iPhone 393x852",
            udid: "12988233-030E-4824-A490-218913870F59",
            geometry: .init(points: [393, 852], pixels: [1179, 2556], scale: 3)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(target)) as? [String: Any])
        XCTAssertEqual(object["name"] as? String, "APP-302 iPhone 393x852")
        XCTAssertEqual((object["point_dimensions"] as? [String: Int])?["width"], 393)
        XCTAssertEqual((object["point_dimensions"] as? [String: Int])?["height"], 852)
        XCTAssertEqual((object["pixel_dimensions"] as? [String: Int])?["width"], 1179)
        XCTAssertEqual((object["pixel_dimensions"] as? [String: Int])?["height"], 2556)
    }

    // MARK: - Device type inference

    private let catalog: [(name: String, identifier: String)] = [
        ("iPhone 16", "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
        ("iPhone 17", "com.apple.CoreSimulator.SimDeviceType.iPhone-17"),
        ("iPhone 17 Pro", "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"),
        ("iPad Pro 11-inch (M4)", "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4"),
    ]

    func testInfersTheDeviceTypeFromASimulatorName() {
        // `grantiva simulator ensure --name "iPhone 17"` must work on its own.
        let inferred = SimulatorManager.inferDeviceType(fromName: "iPhone 17", in: catalog)
        XCTAssertEqual(inferred?.identifier, "com.apple.CoreSimulator.SimDeviceType.iPhone-17")
    }

    func testTheLongestMatchingDeviceTypeWins() {
        let inferred = SimulatorManager.inferDeviceType(fromName: "BLE iPhone 17 Pro", in: catalog)
        XCTAssertEqual(inferred?.name, "iPhone 17 Pro")
    }

    func testInferenceIsCaseInsensitive() {
        XCTAssertEqual(
            SimulatorManager.inferDeviceType(fromName: "app-925 iphone 16", in: catalog)?.name,
            "iPhone 16"
        )
    }

    func testInferenceFailsWhenTheNameNamesNoDevice() {
        XCTAssertNil(SimulatorManager.inferDeviceType(fromName: "APP-652 device", in: catalog))
    }

    // MARK: - newest installed iPhone (doctor and init suggest it instead of "iPhone 16")

    func testNewestIPhoneSkipsTypesNewerThanTheInstalledRuntimes() throws {
        let json = #"""
        {"devicetypes":[
          {"name":"iPhone 18 Pro","identifier":"t.18p","minRuntimeVersionString":"27.0.0","productFamily":"iPhone"},
          {"name":"iPad Pro","identifier":"t.ipad","minRuntimeVersionString":"26.0.0","productFamily":"iPad"},
          {"name":"iPhone 17 Pro","identifier":"t.17p","minRuntimeVersionString":"26.0.0","productFamily":"iPhone"},
          {"name":"iPhone 17e","identifier":"t.17e","minRuntimeVersionString":"26.3.0","productFamily":"iPhone"},
          {"name":"iPhone 16","identifier":"t.16","minRuntimeVersionString":"18.0.0","productFamily":"iPhone"}
        ],"runtimes":[
          {"name":"iOS 26.2","identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-2","version":"26.2","isAvailable":true,"platform":"iOS"},
          {"name":"iOS 27.0","identifier":"com.apple.CoreSimulator.SimRuntime.iOS-27-0","version":"27.0","isAvailable":false,"platform":"iOS"}
        ]}
        """#
        XCTAssertEqual(SimulatorManager.newestIPhone(catalogJSON: Data(json.utf8)), "iPhone 17 Pro")
    }

    func testNewestIPhoneIsNilWithoutAnIOSRuntime() {
        let json = #"{"devicetypes":[{"name":"iPhone 17","identifier":"t","minRuntimeVersionString":"26.0.0","productFamily":"iPhone"}],"runtimes":[]}"#
        XCTAssertNil(SimulatorManager.newestIPhone(catalogJSON: Data(json.utf8)))
        XCTAssertNil(SimulatorManager.newestIPhone(catalogJSON: Data("not json".utf8)))
    }
    // MARK: - Fake simctl harness

    private func makeManager(
        _ simctl: FakeSimctl,
        maximum: Int = 4,
        waitTimeout: TimeInterval = 0
    ) -> (SimulatorManager, SimulatorCapacity, SimulatorProvenance) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-manager-tests-\(UUID().uuidString)").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: directory) }
        let capacity = SimulatorCapacity(directory: directory, maximum: maximum, waitTimeout: waitTimeout, pollInterval: 0.01)
        let provenance = SimulatorProvenance(directory: directory)
        return (SimulatorManager(execute: simctl.execute, capacity: capacity, provenance: provenance), capacity, provenance)
    }

    // MARK: - I08: pre-booted devices are not Grantiva's

    func testBootingAnAlreadyBootedDeviceTakesNoSlotAndTeardownNeverShutsItDown() async throws {
        let simctl = FakeSimctl(devices: [
            .init(name: "Manual", udid: "MANUAL-1", state: "Booted", runtime: "iOS-26-0", type: FakeSimctl.iPhone17),
        ])
        let (manager, capacity, _) = makeManager(simctl)

        _ = try await manager.boot(nameOrUDID: "MANUAL-1")

        let devices = try await manager.listDevices()
        XCTAssertEqual(try capacity.sessions(devices: devices), [])
        let byUDID = try await manager.teardown(udid: "MANUAL-1")
        let bySession = try await manager.teardown(sessionId: "simulator:MANUAL-1")
        XCTAssertEqual(byUDID, [])
        XCTAssertEqual(bySession, [])
        XCTAssertFalse(simctl.commands.contains { $0.contains("simctl shutdown") }, "\(simctl.commands)")
        XCTAssertFalse(simctl.commands.contains { $0.contains("simctl boot ") })
        XCTAssertEqual(simctl.device("MANUAL-1")?.state, "Booted")
    }

    func testBootingAShutdownDeviceTakesASlotAndTeardownShutsItDown() async throws {
        let simctl = FakeSimctl(devices: [
            .init(name: "Mine", udid: "MINE-1", state: "Shutdown", runtime: "iOS-26-0", type: FakeSimctl.iPhone17),
        ])
        let (manager, capacity, _) = makeManager(simctl)

        _ = try await manager.boot(nameOrUDID: "MINE-1")
        let devices = try await manager.listDevices()
        XCTAssertEqual(try capacity.sessions(devices: devices).map(\.udid), ["MINE-1"])

        let outcomes = try await manager.teardown(udid: "MINE-1")
        XCTAssertEqual(outcomes.map(\.session.udid), ["MINE-1"])
        XCTAssertTrue(simctl.commands.contains("xcrun simctl shutdown 'MINE-1'"))
    }

    // MARK: - I10: ensure reuses by name before inferring

    func testBareEnsureReusesAModelLessNameWithItsOwnTypeAndRuntime() async throws {
        let simctl = FakeSimctl(devices: [
            .init(name: "qa-x", udid: "QAX-1", state: "Shutdown", runtime: "iOS-26-0", type: FakeSimctl.iPhone17),
        ])
        let (manager, _, _) = makeManager(simctl)

        let result = try await manager.ensure(name: "qa-x", boot: false)

        XCTAssertEqual(result.udid, "QAX-1")
        XCTAssertFalse(result.created)
        XCTAssertEqual(result.deviceType, "iPhone 17")
        XCTAssertEqual(result.runtime, "iOS 26.0")
        XCTAssertFalse(simctl.commands.contains { $0.contains("simctl create") })
    }

    func testBareEnsureReportsTheExistingRuntimeNotTheNewest() async throws {
        let simctl = FakeSimctl(devices: [
            .init(name: "QA iPhone 17 Pro", udid: "PIN-1", state: "Shutdown", runtime: "iOS-26-0", type: FakeSimctl.iPhone17Pro),
        ])
        let (manager, _, _) = makeManager(simctl)

        let result = try await manager.ensure(name: "QA iPhone 17 Pro", boot: false)
        XCTAssertEqual(result.runtime, "iOS 26.0")
        XCTAssertEqual(result.deviceType, "iPhone 17 Pro")
    }

    func testEnsureWithOnlyADeviceTypeDoesNotRejectAnOlderRuntime() async throws {
        let simctl = FakeSimctl(devices: [
            .init(name: "QA iPhone 17 Pro", udid: "PIN-1", state: "Shutdown", runtime: "iOS-26-0", type: FakeSimctl.iPhone17Pro),
        ])
        let (manager, _, _) = makeManager(simctl)

        let result = try await manager.ensure(name: "QA iPhone 17 Pro", deviceType: "iPhone 17 Pro", boot: false)
        XCTAssertEqual(result.udid, "PIN-1")
        XCTAssertEqual(result.runtime, "iOS 26.0")
    }

    func testEnsureStillRejectsAnExplicitlyMismatchedRuntime() async throws {
        let simctl = FakeSimctl(devices: [
            .init(name: "qa-x", udid: "QAX-1", state: "Shutdown", runtime: "iOS-26-0", type: FakeSimctl.iPhone17),
        ])
        let (manager, _, _) = makeManager(simctl)

        do {
            _ = try await manager.ensure(name: "qa-x", runtime: "27.0", boot: false)
            XCTFail("expected an incompatible-configuration error")
        } catch {
            XCTAssertTrue(String(describing: error).contains("incompatible configuration"), "\(error)")
        }
    }

    func testBareEnsureOfAnUnknownModelLessNameStillFailsToInfer() async throws {
        let simctl = FakeSimctl(devices: [])
        let (manager, _, _) = makeManager(simctl)

        do {
            _ = try await manager.ensure(name: "qa-new", boot: false)
            XCTFail("expected the inference error")
        } catch {
            let message = (error as? GrantivaError)?.errorDescription ?? String(describing: error)
            XCTAssertTrue(message.contains("Could not infer a device type from the name \"qa-new\""), message)
        }
        XCTAssertFalse(simctl.commands.contains { $0.contains("simctl create") })
    }
}

/// A stateful stand-in for the handful of `simctl` commands SimulatorManager issues.
final class FakeSimctl: @unchecked Sendable {
    static let iPhone17 = "com.apple.CoreSimulator.SimDeviceType.iPhone-17"
    static let iPhone17Pro = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"

    struct Device {
        var name: String
        var udid: String
        var state: String
        var runtime: String
        var type: String
    }

    private let lock = NSLock()
    private var devices: [Device]
    private var recorded: [String] = []
    private var created: [String] = []

    init(devices: [Device]) { self.devices = devices }

    var commands: [String] { lock.withLock { recorded } }
    var createdUDIDs: [String] { lock.withLock { created } }
    func device(_ udid: String) -> Device? { lock.withLock { devices.first { $0.udid == udid } } }
    func add(_ device: Device) { lock.withLock { devices.append(device) } }

    func execute(_ command: String) async throws -> String {
        try lock.withLock {
            recorded.append(command)
            let words = command.split(separator: " ").map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            switch true {
            case command == "xcrun simctl list devices --json":
                return deviceListJSON()
            case command == "xcrun simctl list devicetypes runtimes --json":
                return Self.catalogJSON
            case command.hasPrefix("xcrun simctl create "):
                let parts = command.components(separatedBy: "'")
                let udid = "CREATED-\(created.count + 1)"
                let runtime = parts[5].replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
                devices.append(Device(name: parts[1], udid: udid, state: "Shutdown", runtime: runtime, type: parts[3]))
                created.append(udid)
                return udid
            case command.hasPrefix("xcrun simctl boot "):
                setState(words[3], "Booted")
                return ""
            case command.hasPrefix("xcrun simctl shutdown "):
                setState(words[3], "Shutdown")
                return ""
            case command.hasPrefix("xcrun simctl delete "):
                devices.removeAll { $0.udid == words[3] }
                return ""
            case command.hasPrefix("xcrun simctl bootstatus "):
                return ""
            case command.hasPrefix("xcrun simctl getenv "):
                return command.hasSuffix("SCALE") ? "3" : "1000"
            default:
                throw GrantivaError.commandFailed("unexpected command: \(command)", 1)
            }
        }
    }

    private func setState(_ udid: String, _ state: String) {
        if let index = devices.firstIndex(where: { $0.udid == udid }) { devices[index].state = state }
    }

    private func deviceListJSON() -> String {
        var byRuntime: [String: [[String: Any]]] = [:]
        for device in devices {
            byRuntime["com.apple.CoreSimulator.SimRuntime.\(device.runtime)", default: []].append([
                "name": device.name, "udid": device.udid, "state": device.state,
                "isAvailable": true, "deviceTypeIdentifier": device.type,
            ])
        }
        let data = try! JSONSerialization.data(withJSONObject: ["devices": byRuntime])
        return String(decoding: data, as: UTF8.self)
    }

    static let catalogJSON = """
    {"devicetypes": [
      {"name": "iPhone 17", "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17"},
      {"name": "iPhone 17 Pro", "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"}
    ], "runtimes": [
      {"name": "iOS 26.0", "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-0", "version": "26.0", "isAvailable": true},
      {"name": "iOS 27.0", "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0", "version": "27.0", "isAvailable": true}
    ]}
    """
}
