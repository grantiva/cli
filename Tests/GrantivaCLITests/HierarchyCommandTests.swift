import Foundation
import XCTest
@testable import GrantivaCLI

final class HierarchyCommandTests: XCTestCase {
    func testRejectsInvalidTimeoutBeforeLookingForSessions() {
        XCTAssertThrowsError(try HierarchyCommand.parse(["--timeout", "0"]))
    }

    func testRejectsUDIDPathTraversal() {
        XCTAssertThrowsError(try HierarchyCommand.parse(["--udid", "../auth"]))
    }

    func testExplicitUDIDLoadsOnlyItsSession() throws {
        let directory = try temporaryDirectory()
        let udid = "921A0945-7157-4533-BA1F-21E8132D3E40"
        try writeSession(udid: udid, sessionId: "wanted", to: directory)
        try writeSession(udid: "11111111-2222-3333-4444-555555555555", sessionId: "other", to: directory)
        let command = try HierarchyCommand.parse(["--udid", udid])
        XCTAssertEqual(try command.locateSession(in: directory.path).sessionId, "wanted")
    }

    func testNewestCorruptSessionIsSkipped() throws {
        let directory = try temporaryDirectory()
        let valid = directory.appendingPathComponent("valid.json")
        try writeSession(udid: "valid", sessionId: "usable", to: directory)
        let corrupt = directory.appendingPathComponent("newest.json")
        try Data("not json".utf8).write(to: corrupt)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 10)], ofItemAtPath: corrupt.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -10)], ofItemAtPath: valid.path)
        XCTAssertEqual(try HierarchyCommand.parse([]).locateSession(in: directory.path).sessionId, "usable")
    }

    func testMissingOrUnreadableSessionsAreReported() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        XCTAssertThrowsError(try HierarchyCommand.parse([]).locateSession(in: missing))
        let directory = try temporaryDirectory()
        try Data("bad".utf8).write(to: directory.appendingPathComponent("bad.json"))
        XCTAssertThrowsError(try HierarchyCommand.parse([]).locateSession(in: directory.path))
    }

    private func writeSession(udid: String, sessionId: String, to directory: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: ["udid": udid, "port": 8100, "sessionId": sessionId, "appId": "com.example"])
        try data.write(to: directory.appendingPathComponent("\(udid).json"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-hierarchy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
