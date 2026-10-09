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
