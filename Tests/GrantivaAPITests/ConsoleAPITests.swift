import XCTest
@testable import GrantivaAPI

final class ConsoleAPITests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!

    // MARK: - Org Flag Endpoints

    func testListFlagsEndpoint() {
        let endpoint = OrgFlagEndpoints.list(appId: nil, environment: nil)
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/flags")
    }

    func testListFlagsEndpointWithFilters() {
        let endpoint = OrgFlagEndpoints.list(appId: "app-1", environment: "staging")
        let url = endpoint.url(relativeTo: base).absoluteString
        XCTAssertTrue(url.hasPrefix("https://api.example.com/api/v1/org/flags?"))
        XCTAssertTrue(url.contains("app_id=app-1"))
        XCTAssertTrue(url.contains("environment=staging"))
    }

    func testCreateFlagEndpoint() {
        let body = CreateOrgFlagRequest(flagKey: "dark_mode", name: "Dark Mode", valueType: "boolean")
        let endpoint = OrgFlagEndpoints.create(body: body)
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/flags")
    }

    func testDetailEndpointAcceptsFlagKey() {
        let endpoint = OrgFlagEndpoints.detail(flagRef: "dark_mode")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(
            endpoint.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flags/dark_mode"
        )
    }

    func testDetailEndpointAcceptsUUID() {
        let endpoint = OrgFlagEndpoints.detail(flagRef: "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(
            endpoint.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flags/550e8400-e29b-41d4-a716-446655440000"
        )
    }

    func testFlagRefIsPercentEncoded() {
        let endpoint = OrgFlagEndpoints.detail(flagRef: "weird/key")
        XCTAssertTrue(endpoint.url(relativeTo: base).absoluteString.contains("weird%2Fkey"))
    }

    func testUpdateFlagEndpoint() {
        let endpoint = OrgFlagEndpoints.update(flagRef: "dark_mode", body: UpdateOrgFlagRequest(name: "New"))
        XCTAssertEqual(endpoint.method, .put)
        XCTAssertEqual(
            endpoint.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flags/dark_mode"
        )
    }

    func testDeleteFlagEndpoint() {
        let endpoint = OrgFlagEndpoints.delete(flagRef: "dark_mode")
        XCTAssertEqual(endpoint.method, .delete)
        XCTAssertEqual(
            endpoint.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flags/dark_mode"
        )
    }

    func testToggleFlagEndpoint() {
        let endpoint = OrgFlagEndpoints.toggle(flagRef: "dark_mode", body: ToggleOrgFlagRequest(isActive: true))
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(
            endpoint.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flags/dark_mode/toggle"
        )
    }

    func testHistoryEndpoint() {
        let endpoint = OrgFlagEndpoints.history(flagRef: "dark_mode", limit: 10, offset: 20)
        XCTAssertEqual(endpoint.method, .get)
        let url = endpoint.url(relativeTo: base).absoluteString
        XCTAssertTrue(url.hasPrefix("https://api.example.com/api/v1/org/flags/dark_mode/history?"))
        XCTAssertTrue(url.contains("limit=10"))
        XCTAssertTrue(url.contains("offset=20"))
    }

    func testOverrideEndpoints() {
        let list = OrgFlagEndpoints.listOverrides(flagRef: "dark_mode")
        XCTAssertEqual(list.method, .get)
        XCTAssertEqual(
            list.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flags/dark_mode/overrides"
        )

        let create = OrgFlagEndpoints.createOverride(
            flagRef: "dark_mode",
            body: CreateFlagOverrideRequest(deviceKeyId: "device-1", forcedValue: "true")
        )
        XCTAssertEqual(create.method, .post)
        XCTAssertEqual(
            create.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flags/dark_mode/overrides"
        )

        let delete = OrgFlagEndpoints.deleteOverride(flagRef: "dark_mode", overrideId: "ovr-1")
        XCTAssertEqual(delete.method, .delete)
        XCTAssertEqual(
            delete.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flags/dark_mode/overrides/ovr-1"
        )
    }

    // MARK: - Flag Environment Endpoints

    func testEnvironmentEndpoints() {
        let list = FlagEnvironmentEndpoints.list()
        XCTAssertEqual(list.method, .get)
        XCTAssertEqual(
            list.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flag-environments"
        )

        let create = FlagEnvironmentEndpoints.create(body: CreateFlagEnvironmentRequest(name: "Staging"))
        XCTAssertEqual(create.method, .post)
        XCTAssertEqual(
            create.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flag-environments"
        )

        let update = FlagEnvironmentEndpoints.update(envId: "env-1", body: UpdateFlagEnvironmentRequest(reorder: "up"))
        XCTAssertEqual(update.method, .put)
        XCTAssertEqual(
            update.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flag-environments/env-1"
        )

        let delete = FlagEnvironmentEndpoints.delete(envId: "env-1")
        XCTAssertEqual(delete.method, .delete)
        XCTAssertEqual(
            delete.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/org/flag-environments/env-1"
        )
    }

    // MARK: - Flag Rule Endpoints (existing SDK API — UUID-addressed)

    func testRuleEndpoints() {
        let flagId = "550e8400-e29b-41d4-a716-446655440000"

        let list = FlagRuleEndpoints.list(flagId: flagId)
        XCTAssertEqual(list.method, .get)
        XCTAssertEqual(
            list.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/flags/\(flagId)/rules"
        )

        let create = FlagRuleEndpoints.create(
            flagId: flagId,
            body: CreateFlagRuleRequest(name: "Beta", conditions: [], value: "true")
        )
        XCTAssertEqual(create.method, .post)
        XCTAssertEqual(
            create.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/flags/\(flagId)/rules"
        )

        let update = FlagRuleEndpoints.update(flagId: flagId, ruleId: "rule-1", body: UpdateFlagRuleRequest(name: "New"))
        XCTAssertEqual(update.method, .put)
        XCTAssertEqual(
            update.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/flags/\(flagId)/rules/rule-1"
        )

        let delete = FlagRuleEndpoints.delete(flagId: flagId, ruleId: "rule-1")
        XCTAssertEqual(delete.method, .delete)
        XCTAssertEqual(
            delete.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/flags/\(flagId)/rules/rule-1"
        )

        let reorder = FlagRuleEndpoints.reorder(flagId: flagId, body: ReorderFlagRulesRequest(ruleIds: ["a", "b"]))
        XCTAssertEqual(reorder.method, .patch)
        XCTAssertEqual(
            reorder.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/flags/\(flagId)/rules/reorder"
        )
    }

    // MARK: - Evaluation + Stream Endpoints

    func testEvaluateEndpoint() {
        let flagId = "550e8400-e29b-41d4-a716-446655440000"
        let endpoint = FlagEvaluationEndpoints.evaluate(flagId: flagId, body: FlagEvaluationRequest())
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(
            endpoint.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/flags/\(flagId)/evaluate"
        )
    }

    func testStreamEndpoint() {
        let plain = FlagEvaluationEndpoints.stream(environment: nil)
        XCTAssertEqual(
            plain.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/flags/stream"
        )

        let scoped = FlagEvaluationEndpoints.stream(environment: "staging")
        XCTAssertEqual(
            scoped.url(relativeTo: base).absoluteString,
            "https://api.example.com/api/v1/flags/stream?environment=staging"
        )
    }

    // MARK: - Model Serialization (org endpoints — snake_case)

    func testOrgFlagDecodesSnakeCase() throws {
        let json = """
        {
            "id": "uuid-1",
            "flag_key": "dark_mode",
            "name": "Dark Mode",
            "description": "Enables dark mode",
            "app_id": null,
            "value_type": "boolean",
            "is_active": true,
            "environment_values": {"production": "false", "staging": "true"},
            "rule_count": 2,
            "updated_at": "2026-08-30T12:00:00Z"
        }
        """.data(using: .utf8)!

        let flag = try JSONDecoder().decode(OrgFlag.self, from: json)
        XCTAssertEqual(flag.flagKey, "dark_mode")
        XCTAssertEqual(flag.valueType, "boolean")
        XCTAssertTrue(flag.isActive)
        XCTAssertEqual(flag.environmentValues?["staging"], "true")
        XCTAssertEqual(flag.ruleCount, 2)
    }

    func testOrgFlagDetailDecodesWithSummaries() throws {
        let json = """
        {
            "id": "uuid-1",
            "flag_key": "dark_mode",
            "name": "Dark Mode",
            "value_type": "boolean",
            "is_active": true,
            "rules": [
                {"id": "rule-1", "priority": 0, "name": "Beta", "value": "true", "rollout_percentage": 50, "is_active": true}
            ],
            "overrides": [
                {"id": "ovr-1", "device_key_id": "device-1", "forced_value": "true", "expires_at": null}
            ]
        }
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(OrgFlagDetail.self, from: json)
        XCTAssertEqual(detail.rules?.count, 1)
        XCTAssertEqual(detail.rules?.first?.rolloutPercentage, 50)
        XCTAssertEqual(detail.overrides?.first?.deviceKeyId, "device-1")
        XCTAssertEqual(detail.summary.flagKey, "dark_mode")
    }

    func testCreateOrgFlagRequestEncodesSnakeCase() throws {
        let request = CreateOrgFlagRequest(
            flagKey: "dark_mode", name: "Dark Mode", appId: "app-1",
            valueType: "boolean", environmentValues: ["production": "false"], isActive: false
        )
        let data = try JSONEncoder().encode(request)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["flag_key"] as? String, "dark_mode")
        XCTAssertEqual(dict["app_id"] as? String, "app-1")
        XCTAssertEqual(dict["value_type"] as? String, "boolean")
        XCTAssertEqual(dict["is_active"] as? Bool, false)
        XCTAssertEqual((dict["environment_values"] as? [String: String])?["production"], "false")
    }

    func testToggleRequestEncodesSnakeCase() throws {
        let data = try JSONEncoder().encode(ToggleOrgFlagRequest(isActive: false, environment: "staging"))
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["is_active"] as? Bool, false)
        XCTAssertEqual(dict["environment"] as? String, "staging")
    }

    func testCreateOverrideRequestEncodesSnakeCase() throws {
        let data = try JSONEncoder().encode(
            CreateFlagOverrideRequest(deviceKeyId: "device-1", forcedValue: "true", expiresAt: "2026-09-01T00:00:00Z")
        )
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["device_key_id"] as? String, "device-1")
        XCTAssertEqual(dict["forced_value"] as? String, "true")
        XCTAssertEqual(dict["expires_at"] as? String, "2026-09-01T00:00:00Z")
    }

    func testOrgFlagEnvironmentDecodesSnakeCase() throws {
        let json = """
        {"id": "env-1", "name": "Staging", "slug": "staging", "color": "#f59e0b", "is_default": false, "sort_order": 1}
        """.data(using: .utf8)!
        let env = try JSONDecoder().decode(OrgFlagEnvironment.self, from: json)
        XCTAssertEqual(env.slug, "staging")
        XCTAssertEqual(env.isDefault, false)
        XCTAssertEqual(env.sortOrder, 1)
    }

    // MARK: - Model Serialization (existing endpoints — camelCase)

    func testFlagRuleResponseDecodesCamelCase() throws {
        let json = """
        {
            "id": "rule-1",
            "flagId": "flag-1",
            "priority": 0,
            "name": "Beta users",
            "conditions": [
                {"attribute": "os_version", "operator": "gte", "value": "18.0"},
                {"attribute": "country", "operator": "in", "value": ["US", "CA"]}
            ],
            "value": "true",
            "rolloutPercentage": 50,
            "isActive": true,
            "createdAt": "2026-08-30T12:00:00Z"
        }
        """.data(using: .utf8)!

        let rule = try JSONDecoder().decode(FlagRuleResponse.self, from: json)
        XCTAssertEqual(rule.flagId, "flag-1")
        XCTAssertEqual(rule.rolloutPercentage, 50)
        XCTAssertEqual(rule.conditions.count, 2)
        XCTAssertEqual(rule.conditions[0].value, .string("18.0"))
        XCTAssertEqual(rule.conditions[1].value, .array(["US", "CA"]))
    }

    func testConditionValueRoundTrips() throws {
        let string = try JSONDecoder().decode(
            RuleCondition.self,
            from: Data(#"{"attribute": "country", "operator": "eq", "value": "US"}"#.utf8)
        )
        XCTAssertEqual(string.value.displayValue, "US")

        let encoded = try JSONEncoder().encode(
            RuleCondition(attribute: "country", operator: "in", value: .array(["US", "CA"]))
        )
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(dict["value"] as? [String], ["US", "CA"])
    }

    func testEvaluationResponseDecodesCamelCase() throws {
        let json = """
        {
            "flagKey": "dark_mode",
            "flagId": "flag-1",
            "environment": "production",
            "resolvedValue": "true",
            "valueType": "boolean",
            "matchedRule": "Beta users",
            "isDefault": false,
            "trace": [
                {
                    "ruleName": "Beta users",
                    "ruleId": "rule-1",
                    "priority": 0,
                    "matched": true,
                    "rolloutPercentage": 100,
                    "passedRollout": true,
                    "conditions": [
                        {"attribute": "os_version", "operator": "gte", "expected": "18.0", "actual": "18.1.2", "passed": true}
                    ],
                    "value": "true"
                }
            ]
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(FlagEvaluationResponse.self, from: json)
        XCTAssertEqual(result.resolvedValue, "true")
        XCTAssertEqual(result.matchedRule, "Beta users")
        XCTAssertEqual(result.trace.first?.conditions.first?.actual, "18.1.2")
    }

    func testEvaluationRequestEncodesCamelCase() throws {
        let request = FlagEvaluationRequest(osVersion: "18.1", riskScore: 12, environment: "staging")
        let data = try JSONEncoder().encode(request)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(dict["osVersion"] as? String, "18.1")
        XCTAssertEqual(dict["riskScore"] as? Int, 12)
        XCTAssertEqual(dict["environment"] as? String, "staging")
        XCTAssertNil(dict["os_version"])
    }

    // MARK: - SSE Parser

    func testSSEParserDispatchesNamedEvent() {
        var parser = SSEParser()
        XCTAssertNil(parser.feed(line: "event: flags"))
        XCTAssertNil(parser.feed(line: "data: {\"flags\":{\"dark_mode\":true}}"))
        let event = parser.feed(line: "")
        XCTAssertEqual(event, FlagStreamEvent(event: "flags", data: "{\"flags\":{\"dark_mode\":true}}"))
    }

    func testSSEParserIgnoresKeepaliveComments() {
        var parser = SSEParser()
        XCTAssertNil(parser.feed(line: ": keepalive"))
        XCTAssertNil(parser.feed(line: ""))
    }

    func testSSEParserJoinsMultilineData() {
        var parser = SSEParser()
        XCTAssertNil(parser.feed(line: "data: line one"))
        XCTAssertNil(parser.feed(line: "data: line two"))
        let event = parser.feed(line: "")
        XCTAssertEqual(event, FlagStreamEvent(event: "message", data: "line one\nline two"))
    }

    func testSSEParserResetsBetweenEvents() {
        var parser = SSEParser()
        _ = parser.feed(line: "event: flags")
        _ = parser.feed(line: "data: first")
        _ = parser.feed(line: "")
        XCTAssertNil(parser.feed(line: "data: second"))
        let event = parser.feed(line: "")
        XCTAssertEqual(event?.event, "message")
        XCTAssertEqual(event?.data, "second")
    }

    // MARK: - ConsoleClient Failing

    func testFailingConsoleClientThrows() async {
        do {
            _ = try await ConsoleClient.failing.listFlags(nil, nil)
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }
        do {
            _ = try await ConsoleClient.failing.streamFlags(nil)
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }
    }
}
