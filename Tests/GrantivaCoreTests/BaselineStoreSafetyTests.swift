import Foundation
import XCTest
@testable import GrantivaCore

final class BaselineStoreSafetyTests: XCTestCase {
    func testArtifactFilenameRoundTripsLogicalScreenName() {
        for name in ["Checkout complete", "../../outside", "literal%2Fvalue"] {
            XCTAssertEqual(
                ScreenArtifact.screenName(from: ScreenArtifact.fileName(for: name)),
                name
            )
        }
    }

    func testTraversalScreenNameStaysInsideBaselineDirectory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-baseline-safety-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let baselineDirectory = root.appendingPathComponent("baselines")
        let store = BaselineStore.local(directory: baselineDirectory.path)

        let saved = try await store.save("../../outside", Data("image".utf8))

        XCTAssertEqual(
            URL(fileURLWithPath: saved).deletingLastPathComponent().standardizedFileURL.path,
            baselineDirectory.standardizedFileURL.path
        )
        XCTAssertEqual(URL(fileURLWithPath: saved).lastPathComponent, "..%2F..%2Foutside.png")
        let loaded = try await store.load("../../outside")
        XCTAssertEqual(loaded, Data("image".utf8))
        let names = try await store.list()
        XCTAssertEqual(names, ["../../outside"])
        try await store.delete("../../outside")
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved))
    }
}
