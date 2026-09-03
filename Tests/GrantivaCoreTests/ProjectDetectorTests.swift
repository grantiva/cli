import Foundation
import XCTest
@testable import GrantivaCore

private actor ProjectDetectorShell {
    private var commands: [String] = []
    let responses: [String: Result<String, Error>]

    init(responses: [String: Result<String, Error>]) {
        self.responses = responses
    }

    func run(_ command: String) throws -> String {
        commands.append(command)
        guard let response = responses[command] else {
            throw GrantivaError.commandFailed("Unexpected command: \(command)", 1)
        }
        return try response.get()
    }

    func recordedCommands() -> [String] { commands }
}

final class ProjectDetectorTests: XCTestCase {
    func testDetectPrefersVisibleWorkspaceAndReadsBundleIdentifier() async throws {
        let list = "xcodebuild -list -json -workspace 'A Workspace.xcworkspace'"
        let settings = "xcodebuild -scheme 'Main App' -showBuildSettings -workspace 'A Workspace.xcworkspace'"
        let shell = ProjectDetectorShell(responses: [
            list: .success(#"{"workspace":{"schemes":["Main App","Tests"]}}"#),
            settings: .success("OTHER = value\n    PRODUCT_BUNDLE_IDENTIFIER = com.example.main\n"),
        ])

        let project = try await ProjectDetector.detect(
            contents: ["Z.xcodeproj", ".hidden.xcworkspace", "A Workspace.xcworkspace"],
            runShell: { try await shell.run($0) }
        )

        XCTAssertEqual(project.scheme, "Main App")
        XCTAssertEqual(project.workspace, "A Workspace.xcworkspace")
        XCTAssertEqual(project.project, "Z.xcodeproj")
        XCTAssertEqual(project.bundleId, "com.example.main")
        let commands = await shell.recordedCommands()
        XCTAssertEqual(commands, [list, settings])
    }

    func testDetectUsesSortedVisibleProjectAndToleratesBuildSettingsFailure() async throws {
        let list = "xcodebuild -list -json -project 'A.xcodeproj'"
        let settings = "xcodebuild -scheme 'App' -showBuildSettings -project 'A.xcodeproj'"
        let shell = ProjectDetectorShell(responses: [
            list: .success(#"{"project":{"schemes":["App"]}}"#),
            settings: .failure(GrantivaError.commandFailed("settings failed", 1)),
        ])

        let project = try await ProjectDetector.detect(
            contents: ["Z.xcodeproj", ".Hidden.xcodeproj", "A.xcodeproj"],
            runShell: { try await shell.run($0) }
        )

        XCTAssertEqual(project.scheme, "App")
        XCTAssertEqual(project.project, "A.xcodeproj")
        XCTAssertNil(project.workspace)
        XCTAssertNil(project.bundleId)
        let commands = await shell.recordedCommands()
        XCTAssertEqual(commands, [list, settings])
    }

    func testDetectRejectsDirectoryWithoutVisibleXcodeContainer() async {
        do {
            _ = try await ProjectDetector.detect(
                contents: [".Hidden.xcodeproj", "README.md"],
                runShell: { _ in XCTFail("shell should not run"); return "" }
            )
            XCTFail("Expected missing-project error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("No .xcworkspace or .xcodeproj"))
        }
    }

    func testDetectRejectsXcodeListWithoutSchemes() async {
        do {
            _ = try await ProjectDetector.detect(
                contents: ["App.xcodeproj"],
                runShell: { _ in #"{"project":{"schemes":[]}}"# }
            )
            XCTFail("Expected missing-scheme error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("No schemes found"))
        }
    }

    func testCacheRoundTripRemainsValidWhenProjectContainersAreOlder() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cacheURL = root.appendingPathComponent(".grantiva/config.json")
        let projectURL = root.appendingPathComponent("App.xcodeproj")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: projectURL.path
        )
        let project = DetectedProject(
            scheme: "App", project: "App.xcodeproj", bundleId: "com.example.app",
            detectedAt: Date(timeIntervalSince1970: 123)
        )

        try ProjectDetector.writeCache(project, cacheURL: cacheURL)
        let loaded = ProjectDetector.loadCache(cacheURL: cacheURL, projectDirectory: root)

        XCTAssertEqual(loaded?.scheme, "App")
        XCTAssertEqual(loaded?.bundleId, "com.example.app")
        XCTAssertEqual(loaded?.detectedAt, project.detectedAt)
    }

    func testNewerWorkspaceInvalidatesCache() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cacheURL = root.appendingPathComponent(".grantiva/config.json")
        try ProjectDetector.writeCache(DetectedProject(scheme: "Old"), cacheURL: cacheURL)
        let workspaceURL = root.appendingPathComponent("App.xcworkspace")
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: 60)], ofItemAtPath: workspaceURL.path
        )

        XCTAssertNil(ProjectDetector.loadCache(cacheURL: cacheURL, projectDirectory: root))
    }

    func testHiddenNewerContainerDoesNotInvalidateCache() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cacheURL = root.appendingPathComponent(".grantiva/config.json")
        try ProjectDetector.writeCache(DetectedProject(scheme: "App"), cacheURL: cacheURL)
        let hiddenURL = root.appendingPathComponent(".Hidden.xcodeproj")
        try FileManager.default.createDirectory(at: hiddenURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: 60)], ofItemAtPath: hiddenURL.path
        )

        XCTAssertEqual(
            ProjectDetector.loadCache(cacheURL: cacheURL, projectDirectory: root)?.scheme,
            "App"
        )
    }

    func testMalformedCacheIsIgnored() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cacheURL = root.appendingPathComponent(".grantiva/config.json")
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: cacheURL)

        XCTAssertNil(ProjectDetector.loadCache(cacheURL: cacheURL, projectDirectory: root))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-project-cache-\(UUID().uuidString)", isDirectory: true)
    }
}
