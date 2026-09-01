import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaAPI
import GrantivaCore

final class ConsoleCommandTests: XCTestCase {
    // MARK: - Parsing: flags

    func testFlagsListParses() throws {
        let command = try ConsoleFlagsCommand.ListCommand.parse(["--app", "app-1", "--env", "staging", "--json"])
        XCTAssertEqual(command.app, "app-1")
        XCTAssertEqual(command.env, "staging")
        XCTAssertTrue(command.options.json)
    }

    func testFlagsGetParses() throws {
        let command = try ConsoleFlagsCommand.GetCommand.parse(["dark_mode"])
        XCTAssertEqual(command.key, "dark_mode")
    }

    func testFlagsCreateParses() throws {
        let command = try ConsoleFlagsCommand.CreateCommand.parse([
            "dark_mode",
            "--name", "Dark Mode",
            "--type", "bool",
            "--value", "false",
            "--env-value", "staging=true",
            "--env-value", "production=false",
            "--app", "app-1",
            "--off",
        ])
        XCTAssertEqual(command.key, "dark_mode")
        XCTAssertEqual(command.name, "Dark Mode")
        XCTAssertEqual(command.type, .bool)
        XCTAssertEqual(command.value, "false")
        XCTAssertEqual(command.envValue, ["staging=true", "production=false"])
        XCTAssertEqual(command.app, "app-1")
        XCTAssertTrue(command.off)
    }

    func testFlagsCreateRejectsUnknownType() {
        XCTAssertThrowsError(
            try ConsoleFlagsCommand.CreateCommand.parse(["x", "--name", "X", "--type", "float"])
        )
    }

    func testFlagsUpdateParses() throws {
        let command = try ConsoleFlagsCommand.UpdateCommand.parse([
            "dark_mode", "--name", "New", "--description", "desc", "--env-value", "staging=true",
        ])
        XCTAssertEqual(command.name, "New")
        XCTAssertEqual(command.description, "desc")
        XCTAssertEqual(command.envValue, ["staging=true"])
    }

    func testFlagsOnOffParse() throws {
        let on = try ConsoleFlagsCommand.OnCommand.parse(["dark_mode", "--env", "staging"])
        XCTAssertEqual(on.key, "dark_mode")
        XCTAssertEqual(on.env, "staging")

        let off = try ConsoleFlagsCommand.OffCommand.parse(["dark_mode"])
        XCTAssertEqual(off.key, "dark_mode")
        XCTAssertNil(off.env)
    }

    func testFlagsDeleteParses() throws {
        let command = try ConsoleFlagsCommand.DeleteCommand.parse(["dark_mode", "--yes"])
        XCTAssertEqual(command.key, "dark_mode")
        XCTAssertTrue(command.yes)
    }

    func testFlagsEvalParses() throws {
        let command = try ConsoleFlagsCommand.EvalCommand.parse([
            "dark_mode",
            "--device-model", "iPhone16,1",
            "--os-version", "18.1.2",
            "--app-version", "2.1.0",
            "--risk-score", "12",
            "--locale", "en_US",
            "--country", "US",
            "--custom", "beta_group=internal",
            "--env", "staging",
        ])
        XCTAssertEqual(command.deviceModel, "iPhone16,1")
        XCTAssertEqual(command.osVersion, "18.1.2")
        XCTAssertEqual(command.riskScore, 12)
        XCTAssertEqual(command.custom, ["beta_group=internal"])
        XCTAssertEqual(command.env, "staging")
    }

    func testFlagsHistoryParses() throws {
        let command = try ConsoleFlagsCommand.HistoryCommand.parse(["dark_mode", "--limit", "5"])
        XCTAssertEqual(command.key, "dark_mode")
        XCTAssertEqual(command.limit, 5)
    }

    func testFlagsWatchParses() throws {
        let command = try ConsoleFlagsCommand.WatchCommand.parse(["--env", "staging"])
        XCTAssertEqual(command.env, "staging")
    }

    // MARK: - Parsing: rules

    func testRulesListParses() throws {
        let command = try ConsoleFlagsRulesCommand.ListCommand.parse(["dark_mode"])
        XCTAssertEqual(command.key, "dark_mode")
    }

    func testRulesAddParses() throws {
        let command = try ConsoleFlagsRulesCommand.AddCommand.parse([
            "dark_mode",
            "--name", "Beta users",
            "--value", "true",
            "--when", "os_version:gte:18.0",
            "--when", "country:in:US,CA",
            "--rollout", "50",
            "--inactive",
        ])
        XCTAssertEqual(command.name, "Beta users")
        XCTAssertEqual(command.value, "true")
        XCTAssertEqual(command.when, ["os_version:gte:18.0", "country:in:US,CA"])
        XCTAssertEqual(command.rollout, 50)
        XCTAssertTrue(command.inactive)
    }

    func testRulesUpdateParses() throws {
        let command = try ConsoleFlagsRulesCommand.UpdateCommand.parse([
            "dark_mode", "rule-1", "--rollout", "75", "--active",
        ])
        XCTAssertEqual(command.key, "dark_mode")
        XCTAssertEqual(command.ruleId, "rule-1")
        XCTAssertEqual(command.rollout, 75)
        XCTAssertTrue(command.active)
    }

    func testRulesDeleteParses() throws {
        let command = try ConsoleFlagsRulesCommand.DeleteCommand.parse(["dark_mode", "rule-1", "--yes"])
        XCTAssertEqual(command.ruleId, "rule-1")
        XCTAssertTrue(command.yes)
    }

    func testRulesReorderParses() throws {
        let command = try ConsoleFlagsRulesCommand.ReorderCommand.parse(["dark_mode", "rule-2", "rule-1"])
        XCTAssertEqual(command.ruleIds, ["rule-2", "rule-1"])
    }

    // MARK: - Parsing: overrides

    func testOverridesListParses() throws {
        let command = try ConsoleFlagsOverridesCommand.ListCommand.parse(["dark_mode"])
        XCTAssertEqual(command.key, "dark_mode")
    }

    func testOverridesAddParses() throws {
        let command = try ConsoleFlagsOverridesCommand.AddCommand.parse([
            "dark_mode", "--device", "device-1", "--value", "true", "--expires-at", "2026-09-01T00:00:00Z",
        ])
        XCTAssertEqual(command.device, "device-1")
        XCTAssertEqual(command.value, "true")
        XCTAssertEqual(command.expiresAt, "2026-09-01T00:00:00Z")
    }

    func testOverridesDeleteParses() throws {
        let command = try ConsoleFlagsOverridesCommand.DeleteCommand.parse(["dark_mode", "ovr-1", "--yes"])
        XCTAssertEqual(command.overrideId, "ovr-1")
        XCTAssertTrue(command.yes)
    }

    // MARK: - Parsing: envs

    func testEnvsListParses() throws {
        let command = try ConsoleEnvsCommand.ListCommand.parse(["--json"])
        XCTAssertTrue(command.options.json)
    }

    func testEnvsCreateParses() throws {
        let command = try ConsoleEnvsCommand.CreateCommand.parse(["Staging", "--color", "#f59e0b"])
        XCTAssertEqual(command.name, "Staging")
        XCTAssertEqual(command.color, "#f59e0b")
    }

    func testEnvsUpdateParses() throws {
        let command = try ConsoleEnvsCommand.UpdateCommand.parse(["staging", "--name", "QA"])
        XCTAssertEqual(command.env, "staging")
        XCTAssertEqual(command.name, "QA")
    }

    func testEnvsDeleteParses() throws {
        let command = try ConsoleEnvsCommand.DeleteCommand.parse(["staging", "--yes"])
        XCTAssertEqual(command.env, "staging")
        XCTAssertTrue(command.yes)
    }

    func testEnvsReorderParses() throws {
        let command = try ConsoleEnvsCommand.ReorderCommand.parse(["staging", "up"])
        XCTAssertEqual(command.env, "staging")
        XCTAssertEqual(command.direction, .up)
    }

    func testEnvsReorderRejectsUnknownDirection() {
        XCTAssertThrowsError(try ConsoleEnvsCommand.ReorderCommand.parse(["staging", "sideways"]))
    }

    // MARK: - Support: env-value parsing

    func testParseEnvValues() throws {
        let values = try ConsoleSupport.parseEnvValues(["staging=true", "production=a=b"])
        XCTAssertEqual(values, ["staging": "true", "production": "a=b"])
    }

    func testParseEnvValuesRejectsMissingEquals() {
        XCTAssertThrowsError(try ConsoleSupport.parseEnvValues(["staging"]))
        XCTAssertThrowsError(try ConsoleSupport.parseEnvValues(["=true"]))
    }

    // MARK: - Support: condition parsing

    func testParseWhenConditions() throws {
        let conditions = try ConsoleSupport.parseConditions(
            when: ["os_version:gte:18.0", "country:in:US,CA"],
            conditionsJSON: nil
        )
        XCTAssertEqual(conditions.count, 2)
        XCTAssertEqual(conditions[0].attribute, "os_version")
        XCTAssertEqual(conditions[0].operator, "gte")
        XCTAssertEqual(conditions[0].value, .string("18.0"))
        XCTAssertEqual(conditions[1].value, .array(["US", "CA"]))
    }

    func testParseWhenAllowsColonsInValue() throws {
        let conditions = try ConsoleSupport.parseConditions(
            when: ["custom.build:eq:release:v2"],
            conditionsJSON: nil
        )
        XCTAssertEqual(conditions[0].attribute, "custom.build")
        XCTAssertEqual(conditions[0].value, .string("release:v2"))
    }

    func testParseWhenRejectsMalformedSpec() {
        XCTAssertThrowsError(try ConsoleSupport.parseConditions(when: ["os_version"], conditionsJSON: nil))
        XCTAssertThrowsError(try ConsoleSupport.parseConditions(when: ["os_version:gte"], conditionsJSON: nil))
        XCTAssertThrowsError(try ConsoleSupport.parseConditions(when: ["os_version:sorta:18"], conditionsJSON: nil))
    }

    func testParseConditionsJSON() throws {
        let json = #"[{"attribute": "risk_score", "operator": "lte", "value": "20"}]"#
        let conditions = try ConsoleSupport.parseConditions(when: [], conditionsJSON: json)
        XCTAssertEqual(conditions.count, 1)
        XCTAssertEqual(conditions[0].attribute, "risk_score")
    }

    func testParseConditionsJSONRejectsGarbage() {
        XCTAssertThrowsError(try ConsoleSupport.parseConditions(when: [], conditionsJSON: "not json"))
    }

    // MARK: - Support: value validation

    func testValidateValue() throws {
        try ConsoleSupport.validateValue("true", type: .bool)
        try ConsoleSupport.validateValue("42", type: .int)
        try ConsoleSupport.validateValue(#"{"a": 1}"#, type: .json)
        try ConsoleSupport.validateValue("anything", type: .string)

        XCTAssertThrowsError(try ConsoleSupport.validateValue("yes", type: .bool))
        XCTAssertThrowsError(try ConsoleSupport.validateValue("4.2", type: .int))
        XCTAssertThrowsError(try ConsoleSupport.validateValue("{broken", type: .json))
    }

    func testFlagValueTypeWireValues() {
        XCTAssertEqual(FlagValueTypeArgument.bool.wireValue, "boolean")
        XCTAssertEqual(FlagValueTypeArgument.int.wireValue, "integer")
        XCTAssertEqual(FlagValueTypeArgument.string.wireValue, "string")
        XCTAssertEqual(FlagValueTypeArgument.json.wireValue, "json")
    }

    // MARK: - Support: error mapping

    func testMap403NamesTheMissingScope() {
        let mapped = ConsoleSupport.map(
            GrantivaError.networkError("Forbidden", 403),
            scope: "flags:write"
        )
        guard case GrantivaError.permissionDenied(let message) = mapped else {
            return XCTFail("expected permissionDenied, got \(mapped)")
        }
        XCTAssertTrue(message.contains("flags:write"), message)
    }

    func testMap404NamesTheFlag() {
        let mapped = ConsoleSupport.map(
            GrantivaError.networkError("Not found", 404),
            scope: "flags:read",
            flagKey: "dark_mode"
        )
        guard case GrantivaError.notFound(let message) = mapped else {
            return XCTFail("expected notFound, got \(mapped)")
        }
        XCTAssertEqual(message, "flag not found: dark_mode")
    }

    func testMapPassesOtherErrorsThrough() {
        let original = GrantivaError.networkError("boom", 500)
        let mapped = ConsoleSupport.map(original, scope: "flags:read")
        guard case GrantivaError.networkError(_, 500) = mapped else {
            return XCTFail("expected passthrough, got \(mapped)")
        }
    }

    // MARK: - Support: destructive confirmation

    func testConfirmYesFlagSkipsPrompt() throws {
        try ConsoleSupport.confirm("delete flag 'x'", yes: true, interactive: false, readAnswer: {
            XCTFail("should not prompt")
            return nil
        })
    }

    func testConfirmRefusesWithoutTTY() {
        XCTAssertThrowsError(
            try ConsoleSupport.confirm("delete flag 'x'", yes: false, interactive: false, readAnswer: { "y" })
        ) { error in
            guard case GrantivaError.invalidArgument(let message) = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
            XCTAssertTrue(message.contains("--yes"), message)
        }
    }

    func testConfirmAcceptsYesAnswer() throws {
        try ConsoleSupport.confirm("delete flag 'x'", yes: false, interactive: true, readAnswer: { "y" })
        try ConsoleSupport.confirm("delete flag 'x'", yes: false, interactive: true, readAnswer: { "YES" })
    }

    func testConfirmAbortsOnAnythingElse() {
        for answer in ["n", "", "nope"] {
            XCTAssertThrowsError(
                try ConsoleSupport.confirm("delete flag 'x'", yes: false, interactive: true, readAnswer: { answer })
            ) { error in
                guard case GrantivaError.aborted = error else {
                    return XCTFail("expected aborted, got \(error)")
                }
            }
        }
    }

    // MARK: - Behavior: flag reference resolution

    func testResolveFlagIdPassesUUIDThrough() async throws {
        let uuid = "550E8400-E29B-41D4-A716-446655440000"
        // .failing client: any network call would throw, so a passthrough
        // proves no request was made.
        let resolved = try await ConsoleSupport.resolveFlagId(uuid, client: .failing)
        XCTAssertEqual(resolved, uuid)
    }

    func testResolveFlagIdLooksUpKey() async throws {
        var client = ConsoleClient.failing
        client.getFlag = { ref in
            XCTAssertEqual(ref, "dark_mode")
            return OrgFlagDetail(id: "uuid-1", flagKey: "dark_mode", name: "Dark Mode", valueType: "boolean", isActive: true)
        }
        let resolved = try await ConsoleSupport.resolveFlagId("dark_mode", client: client)
        XCTAssertEqual(resolved, "uuid-1")
    }

    func testResolveFlagIdMaps404ToFlagNotFound() async {
        var client = ConsoleClient.failing
        client.getFlag = { _ in throw GrantivaError.networkError("Not found", 404) }
        do {
            _ = try await ConsoleSupport.resolveFlagId("missing_flag", client: client)
            XCTFail("should have thrown")
        } catch {
            guard case GrantivaError.notFound(let message) = error else {
                return XCTFail("expected notFound, got \(error)")
            }
            XCTAssertEqual(message, "flag not found: missing_flag")
        }
    }

    // MARK: - Behavior: environment reference resolution

    func testResolveEnvironmentIdBySlug() async throws {
        var client = ConsoleClient.failing
        client.listEnvironments = {
            [
                OrgFlagEnvironment(id: "env-1", name: "Production", slug: "production"),
                OrgFlagEnvironment(id: "env-2", name: "Staging", slug: "staging"),
            ]
        }
        let resolved = try await ConsoleEnvsCommand.resolveEnvironmentId("staging", client: client)
        XCTAssertEqual(resolved, "env-2")
    }

    func testResolveEnvironmentIdRejectsUnknownSlug() async {
        var client = ConsoleClient.failing
        client.listEnvironments = { [] }
        do {
            _ = try await ConsoleEnvsCommand.resolveEnvironmentId("qa", client: client)
            XCTFail("should have thrown")
        } catch {
            guard case GrantivaError.notFound(let message) = error else {
                return XCTFail("expected notFound, got \(error)")
            }
            XCTAssertTrue(message.contains("qa"), message)
        }
    }

    // MARK: - Behavior: unauthenticated client

    func testListCommandSurfacesNotAuthenticated() async throws {
        let command = try ConsoleFlagsCommand.ListCommand.parse(["--json"])
        do {
            try await command.run(client: .failing)
            XCTFail("should have thrown")
        } catch {
            guard case GrantivaError.notAuthenticated = error else {
                return XCTFail("expected notAuthenticated, got \(error)")
            }
            XCTAssertEqual(
                GrantivaError.notAuthenticated.errorDescription,
                "Not authenticated. Run: grantiva auth login"
            )
        }
    }

    func testUpdateCommandRequiresSomethingToUpdate() async throws {
        let command = try ConsoleFlagsCommand.UpdateCommand.parse(["dark_mode"])
        do {
            try await command.run(client: .failing)
            XCTFail("should have thrown")
        } catch {
            guard case GrantivaError.invalidArgument = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
    }

    func testRulesAddRequiresConditions() async throws {
        let command = try ConsoleFlagsRulesCommand.AddCommand.parse(["dark_mode", "--name", "X", "--value", "true"])
        do {
            try await command.run(client: .failing)
            XCTFail("should have thrown")
        } catch {
            guard case GrantivaError.invalidArgument(let message) = error else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
            XCTAssertTrue(message.contains("--when"), message)
        }
    }

    // MARK: - Formatting

    func testFlagsTableColumns() {
        let table = ConsoleFormat.flagsTable([
            OrgFlag(
                id: "uuid-1", flagKey: "dark_mode", name: "Dark Mode", valueType: "boolean",
                isActive: true,
                environmentValues: [
                    "production": OrgFlagEnvironmentValue(onValue: "true", offValue: "false", isActive: false),
                    "staging": OrgFlagEnvironmentValue(onValue: "true", offValue: "false", isActive: true),
                ],
                ruleCount: 2, updatedAt: "2026-08-30T12:34:56Z"
            )
        ])
        XCTAssertTrue(table.contains("KEY"), table)
        XCTAssertTrue(table.contains("dark_mode"), table)
        XCTAssertTrue(table.contains("production=false staging=true"), table)
        XCTAssertTrue(table.contains("2026-08-30 12:34"), table)
    }

    func testFlagsTableEmptyState() {
        XCTAssertEqual(ConsoleFormat.flagsTable([]), "No flags found.")
    }

    func testEvaluationTraceShowsConditionsAndMatch() {
        let result = FlagEvaluationResponse(
            flagKey: "dark_mode",
            flagId: "flag-1",
            environment: "production",
            resolvedValue: "true",
            valueType: "boolean",
            matchedRule: "Beta users",
            isDefault: false,
            trace: [
                FlagEvaluationTraceEntry(
                    ruleName: "Beta users", ruleId: "rule-1", priority: 0, matched: true,
                    rolloutPercentage: 100, passedRollout: true,
                    conditions: [
                        ConditionTraceEntry(attribute: "os_version", operator: "gte", expected: "18.0", actual: "18.1.2", passed: true)
                    ],
                    value: "true"
                ),
                FlagEvaluationTraceEntry(
                    ruleName: "High risk", ruleId: "rule-2", priority: 1, matched: false,
                    rolloutPercentage: 100, passedRollout: false,
                    conditions: [
                        ConditionTraceEntry(attribute: "risk_score", operator: "gt", expected: "75", actual: nil, passed: false)
                    ],
                    value: "false"
                ),
            ]
        )

        let trace = ConsoleFormat.evaluationTrace(result)
        XCTAssertTrue(trace.contains("Resolved value: true"), trace)
        XCTAssertTrue(trace.contains("matched rule: \"Beta users\""), trace)
        XCTAssertTrue(trace.contains("MATCHED"), trace)
        XCTAssertTrue(trace.contains("expected: 18.0"), trace)
        XCTAssertTrue(trace.contains("actual: 18.1.2"), trace)
        XCTAssertTrue(trace.contains("not matched"), trace)
        XCTAssertTrue(trace.contains("actual: (not provided)"), trace)
    }

    func testEvaluationTraceDefaultFallback() {
        let result = FlagEvaluationResponse(
            flagKey: "dark_mode", flagId: "flag-1", environment: "production",
            resolvedValue: "false", valueType: "boolean", matchedRule: nil,
            isDefault: true, trace: []
        )
        let trace = ConsoleFormat.evaluationTrace(result)
        XCTAssertTrue(trace.contains("default — no rules matched"), trace)
        XCTAssertTrue(trace.contains("No active targeting rules"), trace)
    }

    func testRulesTableShowsConditionSummary() {
        let table = ConsoleFormat.rulesTable([
            FlagRuleResponse(
                id: "rule-1", flagId: "flag-1", priority: 0, name: "Beta users",
                conditions: [
                    RuleCondition(attribute: "os_version", operator: "gte", value: .string("18.0")),
                    RuleCondition(attribute: "country", operator: "in", value: .array(["US", "CA"])),
                ],
                value: "true", rolloutPercentage: 50, isActive: true
            )
        ])
        XCTAssertTrue(table.contains("os_version gte 18.0 AND country in US,CA"), table)
        XCTAssertTrue(table.contains("50%"), table)
    }
}
