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
}
