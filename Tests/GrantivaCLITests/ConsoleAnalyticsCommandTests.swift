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

    func testOverviewAcceptsCanonicalPeriodAndKeepsDaysAlias() throws {
        XCTAssertEqual(try ConsoleAnalyticsCommand.OverviewCommand.parse(["--period", "7d"]).period, .week)
        XCTAssertEqual(try ConsoleAnalyticsCommand.OverviewCommand.parse(["--days", "7"]).days, 7)
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.OverviewCommand.parse(["--period", "7d", "--days", "7"]))
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

    func testEventsAcceptsCanonicalPerAndLegacyPerPage() throws {
        XCTAssertEqual(try ConsoleAnalyticsCommand.EventsCommand.parse(["--per", "20"]).perPage, 20)
        XCTAssertEqual(try ConsoleAnalyticsCommand.EventsCommand.parse(["--per-page", "30"]).perPage, 30)
    }

    func testEventsRejectsWhatTheServerWouldSilentlyIgnore() {
        // The backend ignores an unknown eventType and clamps perPage; the CLI
        // refuses both so a typo does not quietly return everything.
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.EventsCommand.parse(["--type", "attestation_faild"]))
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.EventsCommand.parse(["--per-page", "500"]))
        XCTAssertThrowsError(try ConsoleAnalyticsCommand.EventsCommand.parse(["--page", "0"]))
    }

    func testDeviceFetchesTheRequestedKey() async throws {
        var client = AnalyticsClient.failing
        let captured = AnalyticsCapture<String>()
        client.device = { keyId in
            await captured.set(keyId)
            return DeviceDetailsResponse(
                keyId: keyId,
                deviceProfile: DeviceProfile(
                    id: "D1", keyId: keyId, firstSeen: "2026-08-01T00:00:00Z",
                    lastAttestation: "2026-09-01T00:00:00Z", attestationCount: 1,
                    riskScore: 0, jailbreakDetected: false, suspiciousEvents: 0
                ),
                recentEvents: [],
                complianceStatus: ComplianceResult(
                    isCompliant: true, score: 100, violations: [], lastChecked: "2026-09-01T00:00:00Z"
                ),
                lastUpdated: "2026-09-01T00:00:00Z"
            )
        }

        try await ConsoleAnalyticsCommand.DeviceCommand.parse(["KEY-1", "--json"]).run(client: client)
        let keyId = await captured.value
        XCTAssertEqual(keyId, "KEY-1")
    }

    func testDeviceMapsNotFound() async throws {
        var client = AnalyticsClient.failing
        client.device = { _ in throw GrantivaError.networkError("", 404) }
        do {
            try await ConsoleAnalyticsCommand.DeviceCommand.parse(["missing"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "analytics device not found: missing")
        }
    }

    func testRiskAndComplianceAcceptOnlyServerWindows() throws {
        XCTAssertEqual(try ConsoleAnalyticsCommand.RiskCommand.parse(["--period", "30d"]).range, .month)
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

private actor AnalyticsCapture<T: Sendable> {
    private(set) var value: T?
    func set(_ newValue: T) { value = newValue }
}
