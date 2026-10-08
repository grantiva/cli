import Foundation
import XCTest
@testable import GrantivaCore

final class APKOutputMetadataTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("apk-meta-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func write(_ json: String, at relative: String) throws -> String {
        let url = scratch.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url.deletingLastPathComponent().path
    }

    private let universal = """
    {"version":3,"artifactType":{"type":"APK","kind":"Directory"},"applicationId":"com.example.app","variantName":"debug",
     "elements":[{"type":"SINGLE","filters":[],"attributes":[],"versionCode":1,"versionName":"1.0","outputFile":"app-debug.apk"}],"elementType":"File"}
    """

    private let split = """
    {"version":3,"artifactType":{"type":"APK","kind":"Directory"},"applicationId":"com.example.app","variantName":"freeDebug",
     "elements":[
       {"type":"ONE_OF_MANY","filters":[{"filterType":"ABI","value":"arm64-v8a"}],"attributes":[],"versionCode":1,"versionName":"1.0","outputFile":"app-free-arm64-v8a-debug.apk"},
       {"type":"ONE_OF_MANY","filters":[{"filterType":"ABI","value":"x86_64"}],"attributes":[],"versionCode":1,"versionName":"1.0","outputFile":"app-free-x86_64-debug.apk"}
     ],"elementType":"File"}
    """

    func testFindLocatesTheVariantAnywhereUnderOutputsApk() throws {
        let dir = try write(split, at: "outputs/apk/free/debug/output-metadata.json")
        _ = try write(universal, at: "outputs/apk/debug/output-metadata.json")
        let located = try XCTUnwrap(APKOutputMetadata.find(buildDirectory: scratch.path, variant: "freeDebug"))
        XCTAssertEqual(located.directory, dir)
        XCTAssertEqual(located.metadata.applicationId, "com.example.app")
        XCTAssertEqual(try APKOutputMetadata.find(buildDirectory: scratch.path, variant: "debug")?.metadata.elements.count, 1)
        XCTAssertNil(try APKOutputMetadata.find(buildDirectory: scratch.path, variant: "release"))
    }

    func testUniversalOrSingleOutputIsChosenRegardlessOfABI() throws {
        let metadata = try JSONDecoder().decode(APKOutputMetadata.self, from: Data(universal.utf8))
        XCTAssertEqual(try metadata.apkPath(in: "/b/debug", deviceABI: "x86_64"), "/b/debug/app-debug.apk")
    }

    func testABISplitChoosesTheDeviceABI() throws {
        let metadata = try JSONDecoder().decode(APKOutputMetadata.self, from: Data(split.utf8))
        XCTAssertEqual(try metadata.apkPath(in: "/b", deviceABI: "x86_64"), "/b/app-free-x86_64-debug.apk")
        XCTAssertEqual(try metadata.apkPath(in: "/b", deviceABI: "arm64-v8a"), "/b/app-free-arm64-v8a-debug.apk")
    }

    func testABISplitWithNoMatchNamesTheABIsPresent() throws {
        let metadata = try JSONDecoder().decode(APKOutputMetadata.self, from: Data(split.utf8))
        XCTAssertThrowsError(try metadata.apkPath(in: "/b", deviceABI: "armeabi-v7a")) { error in
            XCTAssertTrue("\(error)".contains("armeabi-v7a"), "\(error)")
            XCTAssertTrue("\(error)".contains("arm64-v8a, x86_64"), "\(error)")
        }
    }
}
