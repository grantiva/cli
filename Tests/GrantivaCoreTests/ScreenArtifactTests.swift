import Foundation
import XCTest
@testable import GrantivaCore

/// Capture, baseline and diff files are named after the screen. Only what
/// cannot appear in one path component is encoded (`/`, `:`, NUL) plus `%`
/// itself, so decoding stays unambiguous.
final class ScreenArtifactTests: XCTestCase {
    func testPlainScreenNamesAreNotEncoded() {
        XCTAssertEqual(ScreenArtifact.fileName(for: "Deep Links"), "Deep Links.png")
        XCTAssertEqual(ScreenArtifact.fileName(for: "Café & Menu (1)"), "Café & Menu (1).png")
    }

    func testSeparatorsAndPercentAreEncodedToKeepOneComponent() {
        XCTAssertEqual(ScreenArtifact.fileName(for: "a/b"), "a%2Fb.png")
        XCTAssertFalse(ScreenArtifact.fileName(for: "a/b").contains("/"))
        XCTAssertEqual(ScreenArtifact.fileName(for: "a:b"), "a%3Ab.png")
        XCTAssertEqual(ScreenArtifact.fileName(for: "100%"), "100%25.png")
        XCTAssertEqual(ScreenArtifact.fileName(for: "nul\u{0}byte"), "nul%00byte.png")
    }

    func testRoundTripHoldsForCurrentAndLegacyNames() {
        for name in ["Deep Links", "a/b", "a:b", "100%", "literal%2Fvalue", "../../outside", "Café"] {
            XCTAssertEqual(ScreenArtifact.screenName(from: ScreenArtifact.fileName(for: name)), name, name)
            XCTAssertEqual(ScreenArtifact.screenName(from: ScreenArtifact.legacyFileName(for: name)), name, name)
        }
        XCTAssertEqual(ScreenArtifact.legacyFileName(for: "Deep Links"), "Deep%20Links.png")
        XCTAssertEqual(ScreenArtifact.screenName(from: "Deep%20Links.png"), "Deep Links")
    }

    func testALegacyPercentEncodedBaselineIsStillFoundAndMigratedOnSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-artifact-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacy = root.appendingPathComponent("Deep%20Links.png")
        try Data("old".utf8).write(to: legacy)
        let store = BaselineStore.local(directory: root.path)

        let listed = try await store.list()
        XCTAssertEqual(listed, ["Deep Links"])
        let loaded = try await store.load("Deep Links")
        XCTAssertEqual(loaded, Data("old".utf8))
        XCTAssertEqual(ScreenArtifact.existingFileName(for: "Deep Links", in: root.path), "Deep%20Links.png")

        // `diff approve` saves through the store: the new name replaces the old.
        let saved = try await store.save("Deep Links", Data("new".utf8))
        XCTAssertEqual(URL(fileURLWithPath: saved).lastPathComponent, "Deep Links.png")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path), "legacy file is migrated, not left beside the new one")
        let reloaded = try await store.load("Deep Links")
        XCTAssertEqual(reloaded, Data("new".utf8))
        let relisted = try await store.list()
        XCTAssertEqual(relisted, ["Deep Links"])
    }

    func testNamesThatDifferOnlyByEncodingKeepSeparateBaselines() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-artifact-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BaselineStore.local(directory: root.path)
        _ = try await store.save("A B", Data("space".utf8))
        _ = try await store.save("A%20B", Data("literal".utf8))
        let names = try await store.list()
        XCTAssertEqual(names, ["A B", "A%20B"])
        let space = try await store.load("A B")
        let literal = try await store.load("A%20B")
        XCTAssertEqual(space, Data("space".utf8))
        XCTAssertEqual(literal, Data("literal".utf8))
    }

    func testDeleteRemovesBothCurrentAndLegacyFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-artifact-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: root.appendingPathComponent("Deep%20Links.png"))
        try Data("new".utf8).write(to: root.appendingPathComponent("Deep Links.png"))
        let store = BaselineStore.local(directory: root.path)
        try await store.delete("Deep Links")
        let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(remaining, [])
        do {
            try await store.delete("Deep Links")
            XCTFail("deleting a missing baseline still fails")
        } catch {}
    }

    func testDeleteRemovesALegacyBaseline() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-artifact-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacy = root.appendingPathComponent("Deep%20Links.png")
        try Data("old".utf8).write(to: legacy)
        try await BaselineStore.local(directory: root.path).delete("Deep Links")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
    }
}
