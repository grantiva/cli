import XCTest
@testable import GrantivaCore

final class TableFormatterTests: XCTestCase {
    func testEmptyDeviceListHasExplicitMessage() {
        XCTAssertEqual(TableFormatter().formatDevices([]), "No simulators found.")
    }

    func testDeviceDividerSpansTheLongestRenderedLine() {
        let output = TableFormatter().formatDevices([
            device(name: "Phone", runtime: "iOS 27.0 (24A123)"),
        ])
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[1].count, max(lines[0].count, lines[2].count))
        XCTAssertEqual(lines[1], String(repeating: "─", count: lines[1].count))
    }

    func testDeviceValuesCannotInjectAdditionalRowsOrTerminalControls() {
        let output = TableFormatter().formatDevices([
            device(name: "Phone\nforged\u{001B}[31m", runtime: "iOS\t27"),
        ])
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[2].contains("Phone forged�[31m"), output)
        XCTAssertTrue(lines[2].contains("iOS 27"), output)
        XCTAssertFalse(output.contains("\u{001B}"), output)
    }

    private func device(name: String, runtime: String) -> SimulatorDevice {
        SimulatorDevice(
            name: name,
            udid: "00000000-0000-0000-0000-000000000000",
            state: "Booted",
            runtime: runtime,
            isAvailable: true
        )
    }
}
