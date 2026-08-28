import Foundation
import GrantivaCore
import MCP
import XCTest

@testable import GrantivaMCP

/// A malformed input schema is silently accepted by the server but makes the tool
/// unusable (or misused) by every client, so each schema is validated structurally.
final class ToolSchemaTests: XCTestCase {

    /// Tools that declare required parameters, and which ones.
    static let expectedRequired: [String: Set<String>] = [
        "grantiva_swipe": ["direction"],
        "grantiva_type": ["text"],
        "grantiva_script": ["steps"],
        "grantiva_sim_ensure": ["name", "device_type", "runtime"],
        "grantiva_sim_delete": ["name"],
    ]

    private func allTools() -> [Tool] {
        MCPTestSupport.registry(wda: MCPTestSupport.fakeWDA(recorder: WDARecorder())).allTools()
    }

    // MARK: - Structural validation

    func testEverySchemaIsAJSONSchemaObjectWithAPropertiesMap() throws {
        for tool in allTools() {
            let schema = try XCTUnwrap(object(tool.inputSchema), "\(tool.name): schema is not an object")
            XCTAssertEqual(string(schema["type"]), "object", "\(tool.name): schema type must be \"object\"")
            XCTAssertNotNil(object(schema["properties"]), "\(tool.name): schema has no properties map")
        }
    }

    func testEveryDeclaredPropertyHasATypeAndAValidJSONSchemaType() throws {
        let validTypes: Set<String> = ["string", "number", "integer", "boolean", "array", "object", "null"]
        for tool in allTools() {
            let properties = try XCTUnwrap(object(object(tool.inputSchema)?["properties"]))
            for (key, value) in properties {
                let property = try XCTUnwrap(object(value), "\(tool.name).\(key): property is not an object")
                let type = try XCTUnwrap(string(property["type"]), "\(tool.name).\(key): missing \"type\"")
                XCTAssertTrue(validTypes.contains(type), "\(tool.name).\(key): invalid JSON Schema type \"\(type)\"")
                if type == "array" {
                    XCTAssertNotNil(object(property["items"]), "\(tool.name).\(key): array property must declare \"items\"")
                }
            }
        }
    }

    func testRequiredEntriesAlwaysReferenceDeclaredProperties() throws {
        for tool in allTools() {
            let schema = try XCTUnwrap(object(tool.inputSchema))
            guard let required = array(schema["required"]) else { continue }
            let properties = try XCTUnwrap(object(schema["properties"]))
            for entry in required {
                let name = try XCTUnwrap(string(entry), "\(tool.name): non-string entry in \"required\"")
                XCTAssertNotNil(properties[name], "\(tool.name): required parameter \"\(name)\" is not declared in properties")
            }
        }
    }

    func testRequiredParametersMatchTheDocumentedContract() throws {
        for tool in allTools() {
            let schema = try XCTUnwrap(object(tool.inputSchema))
            let required = Set((array(schema["required"]) ?? []).compactMap { string($0) })
            XCTAssertEqual(
                required, Self.expectedRequired[tool.name] ?? [],
                "\(tool.name): required parameter set changed"
            )
        }
    }

    func testEnumConstraintsListOnlyStringsAndMatchTheHandlers() throws {
        let byName = Dictionary(uniqueKeysWithValues: allTools().map { ($0.name, $0) })

        func enumValues(_ tool: String, _ property: String) throws -> [String] {
            let schema = try XCTUnwrap(object(byName[tool]?.inputSchema))
            let properties = try XCTUnwrap(object(schema["properties"]))
            let target = try XCTUnwrap(object(properties[property]), "\(tool).\(property) missing")
            let values = try XCTUnwrap(array(target["enum"]), "\(tool).\(property) has no enum")
            return values.compactMap { string($0) }
        }

        XCTAssertEqual(try enumValues("grantiva_swipe", "direction"), ["up", "down", "left", "right"])
        XCTAssertEqual(try enumValues("grantiva_screenshot", "format"), ["base64", "file"])
        // The handler compares against exactly these three filter values.
        XCTAssertEqual(try enumValues("grantiva_sim_list", "filter"), ["all", "booted", "shutdown"])
    }

    func testParameterlessToolsDeclareAnEmptyPropertiesMap() throws {
        for name in ["grantiva_a11y_tree", "grantiva_a11y_check", "grantiva_context", "grantiva_vrt_compare"] {
            let tool = try XCTUnwrap(allTools().first { $0.name == name })
            let properties = try XCTUnwrap(object(object(tool.inputSchema)?["properties"]))
            XCTAssertTrue(properties.isEmpty, "\(name) should declare no parameters, has \(properties.keys.sorted())")
        }
    }

    func testSchemasSerializeToValidJSON() throws {
        for tool in allTools() {
            let data = try JSONEncoder().encode(tool.inputSchema)
            let reparsed = try JSONSerialization.jsonObject(with: data)
            XCTAssertTrue(reparsed is [String: Any], "\(tool.name): schema did not serialize to a JSON object")
        }
    }

    // MARK: - Local Value accessors
    //
    // Deliberately pattern-matched here rather than using `Value.objectValue` etc., so
    // these assertions test the schema and not whichever accessor overload resolves.

    private func object(_ value: Value?) -> [String: Value]? {
        if case .object(let object) = value { return object }
        return nil
    }

    private func array(_ value: Value?) -> [Value]? {
        if case .array(let array) = value { return array }
        return nil
    }

    private func string(_ value: Value?) -> String? {
        if case .string(let string) = value { return string }
        return nil
    }
}
