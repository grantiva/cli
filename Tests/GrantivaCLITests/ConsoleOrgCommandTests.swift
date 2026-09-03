import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaAPI
import GrantivaCore

final class ConsoleOrgCommandTests: XCTestCase {
    // MARK: - Apps parsing

    func testAppsRegisterParsesAndValidatesTeamId() throws {
        let command = try ConsoleAppsCommand.RegisterCommand.parse(["com.example.app", "--team-id", "A1B2C3D4E5", "--name", "Example", "--primary", "--json"])
        XCTAssertEqual(command.bundleId, "com.example.app")
        XCTAssertEqual(command.teamId, "A1B2C3D4E5")
        XCTAssertEqual(command.name, "Example")
        XCTAssertTrue(command.primary)
        XCTAssertThrowsError(try ConsoleAppsCommand.RegisterCommand.parse(["com.example.app", "--team-id", "short"]))
        XCTAssertThrowsError(try ConsoleAppsCommand.RegisterCommand.parse(["com.example.app"]))
    }

    func testAppsUpdateRequiresSomethingToChange() throws {
        XCTAssertThrowsError(try ConsoleAppsCommand.UpdateCommand.parse(["com.example.app"]))
        let command = try ConsoleAppsCommand.UpdateCommand.parse(["com.example.app", "--no-analytics", "--name", "N"])
        XCTAssertEqual(command.analytics, false)
        XCTAssertEqual(command.name, "N")
    }

    func testAppsRegisterDefaultsNameAndUppercasesTeam() async throws {
        var client = OrgClient.failing
        let captured = Capture<CreateOrgAppRequest>()
        client.createApp = { request in
            await captured.set(request)
            return OrgApp(id: "1", appName: request.appName, bundleId: request.bundleId, teamId: request.teamId, isActive: true, isPrimary: true)
        }
        let command = try ConsoleAppsCommand.RegisterCommand.parse(["com.example.myapp", "--team-id", "a1b2c3d4e5", "--json"])
        try await command.run(client: client)
        let request = await captured.value
        XCTAssertEqual(request?.appName, "myapp")
        XCTAssertEqual(request?.teamId, "A1B2C3D4E5")
        XCTAssertNil(request?.isPrimary, "--primary not passed means server default")
    }

    func testAppsDeleteRefusesWithoutYesOffTTY() async throws {
        let command = try ConsoleAppsCommand.DeleteCommand.parse(["com.example.app"])
        do {
            try await command.run(client: .failing)
            XCTFail("expected refusal")
        } catch {
            guard case GrantivaError.invalidArgument(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertTrue(message.contains("--yes"), message)
        }
    }

    func testAppsGetMapsNotFoundToTheRef() async throws {
        var client = OrgClient.failing
        client.getApp = { _ in throw GrantivaError.networkError("{\"error\":\"App not found\"}", 404) }
        let command = try ConsoleAppsCommand.GetCommand.parse(["com.missing"])
        do {
            try await command.run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "app not found: com.missing")
        }
    }

    func testAppsListInvokesClientAndOrdersPrimaryFirst() async throws {
        var client = OrgClient.failing
        let calls = Capture<Int>()
        let secondary = app(id: "secondary", bundleId: "com.example.secondary")
        let primary = app(id: "primary", bundleId: "com.example.primary", isPrimary: true)
        client.listApps = {
            await calls.set(1)
            return [secondary, primary]
        }

        try await ConsoleAppsCommand.ListCommand.parse(["--json"]).run(client: client)

        let callCount = await calls.value
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(ConsoleAppsCommand.primaryFirst([secondary, primary]).map(\.id), ["primary", "secondary"])
    }

    func testAppsListPreservesServerOrderWithinPrimaryGroups() {
        let apps = [
            app(id: "regular-1", bundleId: "one"),
            app(id: "primary-1", bundleId: "two", isPrimary: true),
            app(id: "regular-2", bundleId: "three"),
            app(id: "primary-2", bundleId: "four", isPrimary: true),
        ]

        XCTAssertEqual(
            ConsoleAppsCommand.primaryFirst(apps).map(\.id),
            ["primary-1", "primary-2", "regular-1", "regular-2"]
        )
    }

    func testAppsLifecycleCommandsForwardExactReferenceToMatchingClientCall() async throws {
        let reference = "com.example.app"
        let calls = Capture<[String]>()
        var client = OrgClient.failing
        client.activateApp = { ref in
            await calls.append("activate:\(ref)")
            return OrgApp(id: "1", appName: "App", bundleId: ref, teamId: "A1B2C3D4E5", isActive: true, isPrimary: false)
        }
        client.deactivateApp = { ref in
            await calls.append("deactivate:\(ref)")
            return OrgApp(id: "1", appName: "App", bundleId: ref, teamId: "A1B2C3D4E5", isActive: false, isPrimary: false)
        }
        client.setPrimaryApp = { ref in
            await calls.append("set-primary:\(ref)")
            return OrgApp(id: "1", appName: "App", bundleId: ref, teamId: "A1B2C3D4E5", isActive: true, isPrimary: true)
        }

        try await ConsoleAppsCommand.ActivateCommand.parse([reference, "--json"]).run(client: client)
        try await ConsoleAppsCommand.DeactivateCommand.parse([reference, "--json"]).run(client: client)
        try await ConsoleAppsCommand.SetPrimaryCommand.parse([reference, "--json"]).run(client: client)

        let recordedCalls = await calls.value
        XCTAssertEqual(
            recordedCalls,
            ["activate:\(reference)", "deactivate:\(reference)", "set-primary:\(reference)"]
        )
    }

    func testAppsLifecycleMapsNotFoundToRequestedReference() async throws {
        var client = OrgClient.failing
        client.deactivateApp = { _ in throw GrantivaError.networkError("{}", 404) }

        do {
            try await ConsoleAppsCommand.DeactivateCommand.parse(["missing-app"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "app not found: missing-app")
        }
    }

    func testAppsListAndLifecycleMapTheirRequiredScopes() async throws {
        var listClient = OrgClient.failing
        listClient.listApps = { throw GrantivaError.networkError("{}", 403) }
        await assertPermissionScope("apps:read") {
            try await ConsoleAppsCommand.ListCommand.parse([]).run(client: listClient)
        }

        var lifecycleClient = OrgClient.failing
        lifecycleClient.setPrimaryApp = { _ in throw GrantivaError.networkError("{}", 403) }
        await assertPermissionScope("apps:write") {
            try await ConsoleAppsCommand.SetPrimaryCommand.parse(["app-id"]).run(client: lifecycleClient)
        }
    }

    private func app(id: String, bundleId: String, isPrimary: Bool = false) -> OrgApp {
        OrgApp(
            id: id,
            appName: id,
            bundleId: bundleId,
            teamId: "A1B2C3D4E5",
            isActive: true,
            isPrimary: isPrimary
        )
    }

    private func assertPermissionScope(
        _ scope: String,
        operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("expected throw", file: file, line: line)
        } catch {
            guard case GrantivaError.permissionDenied(let message) = error else {
                return XCTFail("unexpected \(error)", file: file, line: line)
            }
            XCTAssertTrue(message.contains("'\(scope)'"), message, file: file, line: line)
        }
    }

    // MARK: - Claims parsing

    func testClaimsCreateRequiresTheConfigurationForItsType() throws {
        XCTAssertNoThrow(try ConsoleClaimsCommand.CreateCommand.parse(["plan", "--type", "static", "--value", "gold"]))
        XCTAssertThrowsError(try ConsoleClaimsCommand.CreateCommand.parse(["plan", "--type", "static"]))
        XCTAssertThrowsError(try ConsoleClaimsCommand.CreateCommand.parse(["region", "--type", "conditional"]))
        XCTAssertThrowsError(try ConsoleClaimsCommand.CreateCommand.parse(["score", "--type", "dynamic"]))
        XCTAssertThrowsError(try ConsoleClaimsCommand.CreateCommand.parse(["x", "--type", "magic", "--value", "v"]))
        let command = try ConsoleClaimsCommand.CreateCommand.parse(["score", "--type", "dynamic", "--data-type", "number", "--expression", "risk_score * 2", "--priority", "3", "--inactive"])
        XCTAssertEqual(command.definition.dataType, .number)
        XCTAssertEqual(command.priority, 3)
        XCTAssertTrue(command.inactive)
    }

    func testClaimsCreateSendsInlineRulesAsJSON() async throws {
        var client = OrgClient.failing
        let captured = Capture<OrgClaimDefinition>()
        client.createClaim = { definition in
            await captured.set(definition)
            return OrgClaim(id: "1", claimKey: definition.claimKey, claimName: definition.claimName, claimType: definition.claimType, dataType: definition.dataType, isActive: true, priority: 0, conditionalRules: definition.conditionalRules)
        }
        let rules = #"[{"id":"R1","priority":0,"operator":"AND","value":"ca","conditions":[{"field":"country","operator":"equals","value":"CA"}]}]"#
        let command = try ConsoleClaimsCommand.CreateCommand.parse(["region", "--type", "conditional", "--rules", rules, "--json"])
        try await command.run(client: client)
        let sent = await captured.value
        XCTAssertEqual(sent?.conditionalRules, try JSONValue.parse(rules))
        XCTAssertEqual(sent?.claimName, "region", "name defaults to the key")
    }

    func testClaimsRulesFromFileAndInvalidJSON() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("rules.json")
        try #"[{"id":"R1","priority":0,"operator":"AND","value":"v","conditions":[]}]"#.write(to: file, atomically: true, encoding: .utf8)

        let parsed = try ConsoleClaimsCommand.json("@\(file.path)", option: "--rules")
        if case .array(let rules) = parsed { XCTAssertEqual(rules.count, 1) } else { XCTFail("expected array") }

        XCTAssertThrowsError(try ConsoleClaimsCommand.json("{not json", option: "--rules"))
        XCTAssertThrowsError(try ConsoleClaimsCommand.json("@/nonexistent/rules.json", option: "--rules"))
    }

    func testClaimsTestBuildsDeviceContext() async throws {
        var client = OrgClient.failing
        let captured = Capture<TestOrgClaimRequest>()
        client.testClaim = { request in
            await captured.set(request)
            return OrgClaimTestResponse(claimKey: request.claim.claimKey, evaluatedValue: "canadian", dataType: "string", evaluationTimeMs: 0.1)
        }
        let command = try ConsoleClaimsCommand.TestCommand.parse([
            "region", "--type", "static", "--value", "x", "--country", "CA", "--risk-score", "12", "--jailbroken", "--data", "plan=gold", "--json",
        ])
        try await command.run(client: client)
        let sent = await captured.value
        XCTAssertEqual(sent?.context?.device?.country, "CA")
        XCTAssertEqual(sent?.context?.device?.riskScore, 12)
        XCTAssertEqual(sent?.context?.device?.jailbreakDetected, true)
        XCTAssertEqual(sent?.context?.additionalData, ["plan": "gold"])
        XCTAssertThrowsError(try ConsoleClaimsCommand.TestCommand.parse(["r", "--type", "static", "--value", "x", "--risk-score", "150"]))
        XCTAssertThrowsError(try ConsoleClaimsCommand.TestCommand.parse(["r", "--type", "static", "--value", "x", "--data", "novalue"]))
    }

    func testClaimsPreviewWithNoDeviceSendsNoContext() async throws {
        var client = OrgClient.failing
        let captured = Capture<PreviewOrgClaimRequest>()
        client.previewClaim = { _, request in
            await captured.set(request)
            return OrgClaimTestResponse(claimKey: "plan", evaluatedValue: "gold", dataType: "string", evaluationTimeMs: 0.1)
        }
        try await ConsoleClaimsCommand.PreviewCommand.parse(["plan", "--json"]).run(client: client)
        let sent = await captured.value
        XCTAssertNil(sent?.context)
    }

    func testClaimsReorderAndUpdateValidation() throws {
        XCTAssertThrowsError(try ConsoleClaimsCommand.ReorderCommand.parse([]))
        XCTAssertEqual(try ConsoleClaimsCommand.ReorderCommand.parse(["a", "b"]).claims, ["a", "b"])
        XCTAssertThrowsError(try ConsoleClaimsCommand.ReorderCommand.parse(["a", "a"]))
        XCTAssertThrowsError(try ConsoleClaimsCommand.ReorderCommand.parse(["a", " "]))
        XCTAssertThrowsError(try ConsoleClaimsCommand.UpdateCommand.parse(["plan"]))
        XCTAssertEqual(try ConsoleClaimsCommand.UpdateCommand.parse(["plan", "--no-active"]).active, false)
    }

    func testClaimsReorderSendsEachReferenceInRequestedOrder() async throws {
        var client = OrgClient.failing
        let captured = Capture<ReorderOrgClaimsRequest>()
        client.reorderClaims = { request in
            await captured.set(request)
            return []
        }

        try await ConsoleClaimsCommand.ReorderCommand.parse(["region", "plan", "score", "--json"])
            .run(client: client)

        let request = await captured.value
        XCTAssertEqual(request?.claimRefs, ["region", "plan", "score"])
    }

    func testClaimsDeleteRequiresConfirmationBeforeCallingClient() async throws {
        XCTAssertThrowsError(try ConsoleClaimsCommand.DeleteCommand.parse([" ", "--yes"]))

        let calls = Capture<[String]>()
        var client = OrgClient.failing
        client.deleteClaim = { claim in
            await calls.set([claim])
            return OrgDeleteResponse(deleted: true, id: claim)
        }

        do {
            try await ConsoleClaimsCommand.DeleteCommand.parse(["plan"]).run(client: client)
            XCTFail("expected non-TTY refusal")
        } catch {
            guard case GrantivaError.invalidArgument(let message) = error else {
                return XCTFail("unexpected \(error)")
            }
            XCTAssertTrue(message.contains("--yes"), message)
        }
        let callsBeforeConfirmation = await calls.value
        XCTAssertNil(callsBeforeConfirmation, "refusal must happen before the destructive request")

        try await ConsoleClaimsCommand.DeleteCommand.parse(["plan", "--yes", "--json"])
            .run(client: client)
        let callsAfterConfirmation = await calls.value
        XCTAssertEqual(callsAfterConfirmation, ["plan"])
    }

    // MARK: - Devices parsing

    func testDevicesListValidatesFilters() throws {
        let command = try ConsoleDevicesCommand.ListCommand.parse(["--risk-min", "76", "--jailbroken", "--search", "ipad", "--per", "50", "--page", "2"])
        XCTAssertEqual(command.riskMin, 76)
        XCTAssertEqual(command.jailbroken, true)
        XCTAssertEqual(command.search, "ipad")
        XCTAssertEqual(try ConsoleDevicesCommand.ListCommand.parse(["--no-jailbroken"]).jailbroken, false)
        XCTAssertThrowsError(try ConsoleDevicesCommand.ListCommand.parse(["--risk-min", "60", "--risk-max", "20"]))
        XCTAssertThrowsError(try ConsoleDevicesCommand.ListCommand.parse(["--per", "500"]))
        XCTAssertThrowsError(try ConsoleDevicesCommand.ListCommand.parse(["--risk-max", "101"]))
    }

    func testDevicesListResolvesABundleIdToAnAppId() async throws {
        var client = OrgClient.failing
        client.getApp = { ref in OrgApp(id: "APP-UUID", appName: "A", bundleId: ref, teamId: "T", isActive: true, isPrimary: true) }
        let captured = Capture<OrgDeviceQuery>()
        client.listDevices = { query in
            await captured.set(query)
            return OrgDeviceList(items: [], page: 1, per: 20, total: 0)
        }
        try await ConsoleDevicesCommand.ListCommand.parse(["--app", "com.example.app", "--json"]).run(client: client)
        let query = await captured.value
        XCTAssertEqual(query?.appId, "APP-UUID")
    }

    func testDevicesGetMapsNotFound() async throws {
        var client = OrgClient.failing
        client.getDevice = { _ in throw GrantivaError.networkError("", 404) }
        do {
            try await ConsoleDevicesCommand.GetCommand.parse(["nope"]).run(client: client)
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notFound(let message) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(message, "device not found: nope")
        }
    }

    // MARK: - Formatting

    func testClaimsTableSummarisesConfiguration() throws {
        let claims = [
            OrgClaim(id: "1", claimKey: "plan", claimName: "Plan", claimType: "static", dataType: "string", isActive: true, priority: 0, staticValue: "gold"),
            OrgClaim(id: "2", claimKey: "region", claimName: "Region", claimType: "conditional", dataType: "string", isActive: false, priority: 1, conditionalRules: try JSONValue.parse("[{},{}]")),
        ]
        let table = ConsoleOrgFormat.claimsTable(claims)
        XCTAssertTrue(table.contains("= gold"), table)
        XCTAssertTrue(table.contains("2 rules"), table)
        XCTAssertTrue(table.contains("inactive"), table)
    }

    func testDevicesListShowsRiskBandAndPaging() {
        let list = OrgDeviceList(items: [OrgDevice(id: "1", keyId: "K1", riskScore: 88, jailbreakDetected: true, attestationCount: 4, suspiciousEvents: 1, firstSeen: "2026-08-01T00:00:00Z", lastAttestation: "2026-09-01T10:00:00Z")], page: 2, per: 1, total: 3)
        let text = ConsoleOrgFormat.devicesList(list)
        XCTAssertTrue(text.contains("88 critical"), text)
        XCTAssertTrue(text.contains("Page 2 of 3 · 3 devices"), text)
    }
}

/// Records the last value a closure was called with, safely across the
/// `@Sendable` boundary.
private actor Capture<T: Sendable> {
    private(set) var value: T?
    func set(_ new: T) { value = new }
}

private extension Capture where T == [String] {
    func append(_ item: String) {
        value = (value ?? []) + [item]
    }
}

final class ClaimsTestDataOptionTests: XCTestCase {
    private func parse(_ data: [String]) throws -> ConsoleClaimsCommand.TestCommand {
        var args = ["plan", "--type", "static", "--value", "gold"]
        for pair in data { args += ["--data", pair] }
        return try ConsoleClaimsCommand.TestCommand.parse(args)
    }

    func testDataPairsSplitOnTheFirstEqualsOnly() throws {
        let command = try parse(["tier=gold", "query=a=b", "empty="])
        XCTAssertEqual(command.device.context()?.additionalData, ["tier": "gold", "query": "a=b", "empty": ""])
    }

    func testDataWithoutAKeyIsRejectedInsteadOfCrashing() {
        XCTAssertThrowsError(try parse(["="]))
        XCTAssertThrowsError(try parse(["=value"]))
        XCTAssertThrowsError(try parse(["novalue"]))
    }
}
