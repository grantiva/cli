import Foundation
import XCTest
@testable import GrantivaCore

final class AuthStoreSecurityTests: XCTestCase {
    func testSecureSaveCreatesPrivateDirectoryAndCredentialFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-auth-security-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        let path = root.appendingPathComponent("auth.json").path

        try AuthStore.saveSecurely(
            AuthCredentials(apiKey: "secret", baseURL: "https://api.example.com"),
            directory: root.path,
            path: path
        )

        let directoryMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as? NSNumber
        ).intValue
        let fileMode = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
        ).intValue
        XCTAssertEqual(directoryMode & 0o777, 0o700)
        XCTAssertEqual(fileMode & 0o777, 0o600)
        XCTAssertTrue(try String(contentsOfFile: path, encoding: .utf8).contains("secret"))
    }
}
