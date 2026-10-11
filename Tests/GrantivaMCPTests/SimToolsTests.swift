import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// K96: `grantiva_sim_list` lists iOS simulators with name, UDID, simctl's
/// state, the runtime as people read it, and availability.
@available(macOS 15, *)
final class SimToolsTests: XCTestCase {
    private let devices = [
        SimulatorDevice(name: "fix2-10-ios", udid: "A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF", state: "Booted", runtime: "iOS-26-0", isAvailable: true),
        SimulatorDevice(name: "old", udid: "C2C8E2D3-F7E6-4FBF-A2FE-7A25B9363961", state: "Shutdown", runtime: "iOS-18-2", isAvailable: false),
        SimulatorDevice(name: "starting", udid: "D3E7E498-2E80-469C-A465-4757C8995ACC", state: "Booting", runtime: "iOS-27-0", isAvailable: true),
        SimulatorDevice(name: "Apple Watch Series 12 (42mm)", udid: "85FE83E3-D690-4DA8-BEEC-210AF5ECE8D5", state: "Shutdown", runtime: "watchOS-27-0", isAvailable: true),
    ]

    func testRuntimeIdentifiersReadAsVersions() {
        XCTAssertEqual(SimTools.runtimeName("iOS-26-0"), "iOS 26.0")
        XCTAssertEqual(SimTools.runtimeName("iOS-18-2-1"), "iOS 18.2.1")
        XCTAssertEqual(SimTools.runtimeName("iOS 26.0"), "iOS 26.0")
    }

    func testAllListsEveryIOSSimulatorWithStateRuntimeAndAvailability() {
        XCTAssertEqual(SimTools.render(devices: devices, filter: "all"), """
            Name | UDID | State | Runtime | Available
            fix2-10-ios | A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF | Booted | iOS 26.0 | yes
            old | C2C8E2D3-F7E6-4FBF-A2FE-7A25B9363961 | Shutdown | iOS 18.2 | no
            starting | D3E7E498-2E80-469C-A465-4757C8995ACC | Booting | iOS 27.0 | yes
            """)
    }

    func testBootedAndShutdownFilters() {
        XCTAssertEqual(SimTools.render(devices: devices, filter: "booted"), """
            Name | UDID | State | Runtime | Available
            fix2-10-ios | A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF | Booted | iOS 26.0 | yes
            """)
        XCTAssertEqual(SimTools.render(devices: devices, filter: "shutdown"), """
            Name | UDID | State | Runtime | Available
            old | C2C8E2D3-F7E6-4FBF-A2FE-7A25B9363961 | Shutdown | iOS 18.2 | no
            """)
        XCTAssertEqual(SimTools.render(devices: [], filter: "booted"), "No iOS simulators found matching filter 'booted'.")
    }

    func testContextUsesTheSameRuntimeSpelling() async {
        let section = await ContextTool.simulatorSection(session: nil, configured: nil, listSimulators: { [devices] in devices })
        XCTAssertTrue(section.contains("runtime: iOS 26.0"), section)
    }
}
