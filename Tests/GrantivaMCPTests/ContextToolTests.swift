import Foundation
import GrantivaCore
import MCP
import XCTest
@testable import GrantivaMCP

@available(macOS 15, *)
final class ContextToolTests: XCTestCase {
    func testAndroidContextNamesTheEmulatorAndTheAndroidConfig() async throws {
        let config = GrantivaConfig(platform: .android, android: AndroidProject(module: "app", variant: "debug", applicationId: "dev.grantiva.example", emulator: "Pixel_8_API_35"))
        let device = MCPFakeDevicePlatform(platform: .android)
        let result = try await ContextTool.context(config: config, platform: .android, device: device, simManager: .live)
        let text = try textContent(of: result)
        XCTAssertTrue(text.contains("[Config]"), text)
        XCTAssertTrue(text.contains("module: app"), text)
        XCTAssertTrue(text.contains("application_id: dev.grantiva.example"), text)
        XCTAssertTrue(text.contains("[Emulator]"), text)
        XCTAssertTrue(text.contains("serial: emulator-5598"), text)
        XCTAssertFalse(text.contains("[Xcode]"), text)
        XCTAssertEqual(device.calls, ["defaultDevice"])
    }
}
