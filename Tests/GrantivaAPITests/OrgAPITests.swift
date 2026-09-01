import XCTest
@testable import GrantivaAPI
import GrantivaCore

final class OrgAPITests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!

    // MARK: - Endpoint shapes

    func testAppEndpoints() {
        XCTAssertEqual(OrgAppEndpoints.list().url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/apps")
        XCTAssertEqual(OrgAppEndpoints.create(body: CreateOrgAppRequest(appName: "A", bundleId: "com.a", teamId: "T")).method, .post)
        XCTAssertEqual(OrgAppEndpoints.detail(appRef: "com.example.app").url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/apps/com.example.app")
        XCTAssertEqual(OrgAppEndpoints.update(appRef: "x", body: UpdateOrgAppRequest(appName: "N")).method, .put)
        XCTAssertEqual(OrgAppEndpoints.delete(appRef: "x").method, .delete)
        XCTAssertEqual(OrgAppEndpoints.setPrimary(appRef: "x").url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/apps/x/set-primary")
        XCTAssertEqual(OrgAppEndpoints.activate(appRef: "x").url(relativeTo: base).lastPathComponent, "activate")
        XCTAssertEqual(OrgAppEndpoints.deactivate(appRef: "x").url(relativeTo: base).lastPathComponent, "deactivate")
    }

    func testClaimEndpoints() {
        XCTAssertEqual(OrgClaimEndpoints.list().url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/claims")
        XCTAssertEqual(OrgClaimEndpoints.detail(claimRef: "plan").url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/claims/plan")
        XCTAssertEqual(OrgClaimEndpoints.reorder(body: ReorderOrgClaimsRequest(claimRefs: ["a"])).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/claims/reorder")
        XCTAssertEqual(OrgClaimEndpoints.reorder(body: ReorderOrgClaimsRequest(claimRefs: ["a"])).method, .put)
        XCTAssertEqual(OrgClaimEndpoints.test(body: TestOrgClaimRequest(claim: OrgClaimDefinition(claimKey: "k", claimName: "k", claimType: "static", dataType: "string", staticValue: "v"))).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/claims/test")
        XCTAssertEqual(OrgClaimEndpoints.preview(claimRef: "plan", body: PreviewOrgClaimRequest()).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/claims/plan/preview")
    }

    func testDeviceEndpointsCarryEveryFilter() {
        let query = OrgDeviceQuery(page: 2, per: 50, riskMin: 21, riskMax: 50, jailbroken: false, appId: "APP", search: "ipad")
        let url = OrgDeviceEndpoints.list(query).url(relativeTo: base).absoluteString
        for fragment in ["page=2", "per=50", "risk_min=21", "risk_max=50", "jailbroken=false", "app_id=APP", "search=ipad"] {
            XCTAssertTrue(url.contains(fragment), url)
        }
        XCTAssertEqual(OrgDeviceEndpoints.list(OrgDeviceQuery()).url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/devices")
        XCTAssertEqual(OrgDeviceEndpoints.detail(keyId: "a/b").url(relativeTo: base).absoluteString, "https://api.example.com/api/v1/org/devices/a%2Fb")
    }

    // MARK: - Wire encoding

    func testCreateAppRequestEncodesSnakeCaseAndOmitsNils() throws {
        let json = String(decoding: try JSONEncoder().encode(CreateOrgAppRequest(appName: "A", bundleId: "com.a", teamId: "T")), as: UTF8.self)
        XCTAssertTrue(json.contains("\"app_name\":\"A\""), json)
        XCTAssertTrue(json.contains("\"bundle_id\":\"com.a\""), json)
        XCTAssertFalse(json.contains("is_primary"), json)
    }

    func testClaimDefinitionCarriesOpaqueRulesVerbatim() throws {
        let rules = try JSONValue.parse(#"[{"id":"R1","priority":0,"operator":"AND","value":"canadian","conditions":[{"field":"country","operator":"equals","value":"CA"}]}]"#)
        let definition = OrgClaimDefinition(claimKey: "region", claimName: "Region", claimType: "conditional", dataType: "string", conditionalRules: rules)
        let encoded = try JSONEncoder().encode(definition)
        let decoded = try JSONDecoder().decode(OrgClaimDefinition.self, from: encoded)
        XCTAssertEqual(decoded.conditionalRules, rules)
        let json = String(decoding: encoded, as: UTF8.self)
        XCTAssertTrue(json.contains("\"conditional_rules\""), json)
        XCTAssertTrue(json.contains("\"priority\":0"), "integers stay integers: \(json)")
    }

    func testJSONValueRoundTripsAllShapes() throws {
        let text = #"{"a":[1,2.5,true,null,"s"],"b":{"c":{}}}"#
        let value = try JSONValue.parse(text)
        let again = try JSONDecoder().decode(JSONValue.self, from: try JSONEncoder().encode(value))
        XCTAssertEqual(value, again)
        XCTAssertThrowsError(try JSONValue.parse("not json"))
    }

    // MARK: - Decoding fixtures (mirror the backend DTOs)

    func testDecodesApp() throws {
        let json = #"{"id":"A1","app_name":"My App","bundle_id":"com.example.app","team_id":"TEAM123456","description":null,"is_active":true,"is_primary":true,"analytics_enabled":true,"webhook_enabled":false,"created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z"}"#
        let app = try JSONDecoder().decode(OrgApp.self, from: Data(json.utf8))
        XCTAssertEqual(app.bundleId, "com.example.app")
        XCTAssertTrue(app.isPrimary)
        XCTAssertFalse(app.webhookEnabled)
    }

    func testDecodesClaimAndTestResponse() throws {
        let claim = #"{"id":"C1","claim_key":"plan","claim_name":"Plan","claim_type":"static","data_type":"string","description":null,"is_active":true,"priority":0,"static_value":"gold","conditional_rules":null,"dynamic_expression":null,"external_config":null,"validation_rules":null,"created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-01T00:00:00Z"}"#
        let decoded = try JSONDecoder().decode(OrgClaim.self, from: Data(claim.utf8))
        XCTAssertEqual(decoded.staticValue, "gold")
        XCTAssertNil(decoded.conditionalRules)

        let result = #"{"claim_key":"region","evaluated_value":"canadian","data_type":"string","evaluation_time_ms":0.42,"errors":null}"#
        let evaluation = try JSONDecoder().decode(OrgClaimTestResponse.self, from: Data(result.utf8))
        XCTAssertEqual(evaluation.evaluatedValue, "canadian")
    }

    func testDecodesDeviceListAndDetail() throws {
        let list = #"{"items":[{"id":"D1","key_id":"K1","app_id":null,"app_name":null,"device_model":"iPhone16,1","os_version":"18.0","app_version":null,"risk_score":12,"jailbreak_detected":false,"is_development_build":false,"app_store_receipt":true,"attestation_count":3,"suspicious_events":0,"last_country":"US","first_seen":"2026-08-01T00:00:00Z","last_attestation":"2026-09-01T00:00:00Z"}],"page":1,"per":20,"total":1}"#
        let decoded = try JSONDecoder().decode(OrgDeviceList.self, from: Data(list.utf8))
        XCTAssertEqual(decoded.items.first?.deviceModel, "iPhone16,1")
        XCTAssertEqual(decoded.total, 1)

        let detail = #"{"id":"D1","key_id":"K1","app_id":null,"app_name":null,"device_model":null,"os_version":null,"app_version":null,"first_app_version":null,"risk_score":0,"jailbreak_detected":false,"is_development_build":false,"app_store_receipt":true,"attestation_count":1,"suspicious_events":0,"last_suspicious_event_at":null,"consecutive_clean_attestations":0,"permissions":["basic"],"last_country":null,"subject_id":null,"first_seen":"2026-08-01T00:00:00Z","last_attestation":"2026-09-01T00:00:00Z","created_at":null,"updated_at":null,"recent_events":[{"id":"E1","event_type":"token_issued","key_id":"K1","device_id":null,"ip_address":"1.2.3.4","success":true,"error_reason":null,"risk_score":0,"created_at":"2026-09-01T00:00:00Z"}]}"#
        let device = try JSONDecoder().decode(OrgDeviceDetail.self, from: Data(detail.utf8))
        XCTAssertEqual(device.recentEvents.first?.eventType, "token_issued")
        XCTAssertEqual(device.permissions, ["basic"])
    }

    func testFailingClientThrowsNotAuthenticated() async {
        do {
            _ = try await OrgClient.failing.listApps()
            XCTFail("expected throw")
        } catch {
            guard case GrantivaError.notAuthenticated = error else { return XCTFail("unexpected \(error)") }
        }
    }
}
