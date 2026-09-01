import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaAPI
import GrantivaCore

final class ConsoleAnalyticsCommandTests: XCTestCase {
    // MARK: - Parsing

    func testOverviewParses() throws {
        let command = try ConsoleAnalyticsCommand.OverviewCommand.parse(["--days", "7", "--json"])
        XCTAssertEqual(command.days, 7)
        XCTAssertTrue(command.options.json)
    }

    func testOverviewRejectsZeroDays() {
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.OverviewCommand.parse(["--days", "0"]))
    }

    func testEventsParsesEveryFilter() throws {
        let command = try ConsoleAnalyticsCommand.EventsCommand.parse([
            "--page", "2", "--per-page", "25", "--from", "2026-09-01T00:00:00Z", "--to", "2026-09-02T00:00:00Z",
            "--device", "dev-1", "--type", "attestation_failed",
        ])
        XCTAssertEqual(command.page, 2)
        XCTAssertEqual(command.perPage, 25)
        XCTAssertEqual(command.from, "2026-09-01T00:00:00Z")
        XCTAssertEqual(command.to, "2026-09-02T00:00:00Z")
        XCTAssertEqual(command.device, "dev-1")
        XCTAssertEqual(command.type, "attestation_failed")
    }

    func testEventsRejectsWhatTheServerWouldSilentlyIgnore() {
        // The backend ignores an unknown eventType and clamps perPage; the CLI
        // refuses both so a typo does not quietly return everything.
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.EventsCommand.parse(["--type", "attestation_faild"]))
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.EventsCommand.parse(["--per-page", "500"]))
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.EventsCommand.parse(["--page", "0"]))
    }

    func testRiskAndComplianceAcceptOnlyServerWindows() throws {
        XCTAssertEqual(try ConsoleAnalyticsCommand.RiskCommand.parse(["--range", "90d"]).range, .quarter)
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.RiskCommand.parse(["--range", "14d"]))
        let compliance = try ConsoleAnalyticsCommand.ComplianceCommand.parse(["--period", "1d", "--all"])
        XCTAssertEqual(compliance.period, .day)
        XCTAssertTrue(compliance.all)
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.ComplianceCommand.parse(["--period", "1y"]))
    }

    func testExportParses() throws {
        let command = try ConsoleAnalyticsCommand.ExportCommand.parse(["--data", "events", "--period", "7d", "--out", "/tmp/e.csv"])
        XCTAssertEqual(command.data, .events)
        XCTAssertEqual(command.period, .week)
        XCTAssertEqual(command.out, "/tmp/e.csv")
    }

    func testExportRequiresDataAndRejectsJSONWithoutOut() {
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.ExportCommand.parse([]))
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.ExportCommand.parse(["--data", "users"]))
        // --json reports where the CSV went, so it needs somewhere to go.
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.ExportCommand.parse(["--data", "devices", "--json"]))
        XCTAssertNoThrow(try ConsoleAnalyticsCommand.ExportCommand.parse(["--data", "devices", "--json", "--out", "/tmp/d.csv"]))
    }

    func testDevicesGetParses() throws {
        let command = try ConsoleDevicesCommand.GetCommand.parse(["abc123", "--json"])
        XCTAssertEqual(command.keyId, "abc123")
        XCTAssertTrue(command.options.json)
    }

    // MARK: - Behaviour with the failing double

    func testOverviewSurfacesNotAuthenticated() async throws {
        let command = try ConsoleAnalyticsCommand.OverviewCommand.parse([])
        do {
            try await command.run(client: .failing)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notAuthenticated = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testDevicesGetMapsA404ToTheKeyId() async throws {
        var client = AnalyticsClient.failing
        client.device = { _ in throw GrantivaError.networkError("{\"error\":\"Device not found\"}", 404) }
        let command = try ConsoleDevicesCommand.GetCommand.parse(["missing-key"])
        do {
            try await command.run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertEqual(message, "device not found: missing-key")
        }
    }

    func testExportNamesTheExportScopeOn403() async throws {
        var client = AnalyticsClient.failing
        client.export = { _, _ in throw GrantivaError.networkError("Forbidden", 403) }
        let command = try ConsoleAnalyticsCommand.ExportCommand.parse(["--data", "devices"])
        do {
            try await command.run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.permissionDenied(let message) = error else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertTrue(message.contains("analytics:export"), message)
        }
    }

    // MARK: - Formatting

    func testRiskDistributionRendersInBandOrder() {
        XCTAssertEqual(
            ConsoleAnalyticsFormat.distribution(["critical": 1, "low": 5, "medium": 2]),
            "low 5 · medium 2 · high 0 · critical 1"
        )
    }

    func testPeriodLabelUsesDatesOnly() {
        XCTAssertEqual(
            ConsoleAnalyticsFormat.periodLabel(["2026-08-25T00:00:00Z", "2026-09-01T00:00:00Z"]),
            "2026-08-25 → 2026-09-01"
        )
    }

    func testComplianceHidesCompliantDevicesUnlessAsked() {
        let report = ComplianceReport(
            tenantId: "T", reportType: "summary", period: ["a", "b"], totalDevices: 2, compliantDevices: 1,
            nonCompliantDevices: 1, complianceRate: 50, violationSummary: ["jailbreakDetected": 1],
            deviceCompliance: [
                DeviceComplianceStatus(keyId: "GOOD", isCompliant: true, complianceScore: 100, violations: [], lastChecked: "x"),
                DeviceComplianceStatus(keyId: "BAD", isCompliant: false, complianceScore: 40, violations: ["jailbreakDetected"], lastChecked: "x"),
            ],
            generatedAt: "x"
        )
        let filtered = ConsoleAnalyticsFormat.compliance(report, showAll: false)
        XCTAssertTrue(filtered.contains("BAD"))
        XCTAssertFalse(filtered.contains("GOOD"))
        XCTAssertTrue(ConsoleAnalyticsFormat.compliance(report, showAll: true).contains("GOOD"))
    }
}
