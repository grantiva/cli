import Foundation
import XCTest
@testable import GrantivaCore

final class AuthStoreSecurityTests: XCTestCase {
    func testFileStoreRoundTripsOverwritesAndDeletesCredentials() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-auth-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("auth.json").path
        let store = AuthStore.file(directory: root.path, path: path)
        XCTAssertNil(store.load())

        try store.save(AuthCredentials(apiKey: "first", baseURL: "https://one.example.com"))
        try store.save(AuthCredentials(apiKey: "second", baseURL: "https://two.example.com", email: "dev@example.com"))
        XCTAssertEqual(store.load()?.apiKey, "second")
        XCTAssertEqual(store.load()?.email, "dev@example.com")

        try store.delete()
        XCTAssertNil(store.load())
        XCTAssertNoThrow(try store.delete())
    }

    func testFileStoreTreatsMalformedJSONAsMissingCredentials() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("grantiva-auth-malformed-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent("auth.json")
        try Data("not json".utf8).write(to: path)
        XCTAssertNil(AuthStore.file(directory: root.path, path: path.path).load())
    }

    func testEnvironmentCredentialsOverrideStoredCredentials() {
        let credentials = AuthStore.resolveCredentials(
            environment: ["GRANTIVA_API_KEY": "  env-key\n", "GRANTIVA_API_URL": "https://staging.example.com"],
            loadStored: { AuthCredentials(apiKey: "stored", baseURL: "https://stored.example.com") }
        )
        XCTAssertEqual(credentials?.apiKey, "env-key")
        XCTAssertEqual(credentials?.baseURL, "https://staging.example.com")
    }

    func testEnvironmentCredentialsUseDefaultURL() {
        let credentials = AuthStore.resolveCredentials(
            environment: ["GRANTIVA_API_KEY": "env-key"], loadStored: { nil }
        )
        XCTAssertEqual(credentials?.baseURL, GrantivaDefaults.apiBaseURL)
    }

    func testMissingOrWhitespaceEnvironmentKeyFallsBackToStore() {
        let stored = AuthCredentials(apiKey: "stored", baseURL: "https://stored.example.com", email: "dev@example.com")
        XCTAssertEqual(AuthStore.resolveCredentials(environment: [:], loadStored: { stored })?.apiKey, "stored")
        XCTAssertEqual(AuthStore.resolveCredentials(environment: ["GRANTIVA_API_KEY": " \n"], loadStored: { stored })?.email, "dev@example.com")
    }

    func testMissingAllCredentialSourcesReturnsNil() {
        XCTAssertNil(AuthStore.resolveCredentials(environment: [:], loadStored: { nil }))
    }

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

    func testSecureSaveAtomicallyReplacesExistingCredentialsWithoutTempFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-auth-replace-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent("auth.json").path
        try Data("old".utf8).write(to: URL(fileURLWithPath: path))

        let expected = AuthCredentials(apiKey: "new-secret", baseURL: "https://api.example.com", email: "dev@example.com")
        try AuthStore.saveSecurely(expected, directory: root.path, path: path)

        let decoded = try JSONDecoder().decode(AuthCredentials.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertEqual(decoded.apiKey, expected.apiKey)
        XCTAssertEqual(decoded.baseURL, expected.baseURL)
        XCTAssertEqual(decoded.email, expected.email)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["auth.json"])
    }
}
