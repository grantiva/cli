import Foundation
import GrantivaCore
import MCP

/// Script tool: execute a batch of UI actions sequentially.
@available(macOS 15, *)
enum ScriptTools {

    // MARK: - Tool Definition

    static let definitions: [Tool] = [
        Tool(
            name: "grantiva_script",
            description: """
                Execute a batch of UI actions sequentially. Each step is an object with one action key. \
                Supported actions: tap (by label), tap_xy (by coordinates), swipe (direction), type (text), wait (seconds). \
                Every step is validated before any step runs: if a step is not an object or has no valid action, \
                nothing runs and the result is an error naming each invalid step. \
                Returns the final accessibility tree after all steps complete.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "steps": .object([
                        "type": .string("array"),
                        "description": .string("Array of step objects. Each has one key: tap, tap_xy, swipe, type, or wait."),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "tap": .object([
                                    "type": .string("string"),
                                    "description": .string("Accessibility label to tap"),
                                ]),
                                "tap_xy": .object([
                                    "type": .string("object"),
                                    "description": .string("Coordinates to tap: {x, y}, in the same unit as the hierarchy frames (points on iOS, dp on Android)"),
                                    "properties": .object([
                                        "x": .object(["type": .string("number")]),
                                        "y": .object(["type": .string("number")]),
                                    ]),
                                ]),
                                "swipe": .object([
                                    "type": .string("string"),
                                    "description": .string("Swipe direction: up, down, left, right"),
                                ]),
                                "type": .object([
                                    "type": .string("string"),
                                    "description": .string("Text to type into focused field"),
                                ]),
                                "wait": .object([
                                    "type": .string("number"),
                                    "description": .string("Seconds to wait"),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
                "required": .array([.string("steps")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
    ]

    // MARK: - Handler

    static func script(driver: DriverClient, arguments: [String: Value]) async throws -> CallTool.Result {
        guard let stepsValue = arguments["steps"]?.arrayValue else {
            return CallTool.Result(
                content: [.text(text: "Error: 'steps' array is required.", annotations: nil, _meta: nil)],
                isError: true
            )
        }

        // Validate every step before running any, so a bad script never
        // half-runs and the caller sees an error result.
        var steps: [Step] = []
        var invalid: [String] = []
        for (index, stepValue) in stepsValue.enumerated() {
            switch Step.parse(stepValue) {
            case .success(let step): steps.append(step)
            case .failure(let reason): invalid.append("Step \(index + 1): \(reason.message)")
            }
        }
        guard invalid.isEmpty else {
            let text = "Error: invalid script steps; no steps were run.\n" + invalid.joined(separator: "\n")
                + "\nEach step must be an object with one of: tap, tap_xy {x, y}, swipe, type, wait."
            return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: true)
        }

        var log: [String] = []

        for (index, step) in steps.enumerated() {
            let stepNum = index + 1
            switch step {
            case .tap(let label):
                try await driver.tapByLabel(label)
                try await Task.sleep(nanoseconds: 500_000_000)
                log.append("Step \(stepNum): tapped \"\(label)\"")
            case .tapXY(let x, let y):
                try await driver.tapByCoordinate(x, y)
                try await Task.sleep(nanoseconds: 500_000_000)
                log.append("Step \(stepNum): tapped at (\(Int(x)), \(Int(y)))")
            case .swipe(let direction):
                try await driver.swipe(direction)
                try await Task.sleep(nanoseconds: 500_000_000)
                log.append("Step \(stepNum): swiped \(direction)")
            case .type(let text):
                try await driver.typeText(text)
                try await Task.sleep(nanoseconds: 300_000_000)
                log.append("Step \(stepNum): typed \"\(text)\"")
            case .wait(let seconds):
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                log.append("Step \(stepNum): waited \(seconds)s")
            }
        }

        // Fetch final hierarchy
        let tree = try await driver.hierarchy()
        let jsonData = try JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let output = log.joined(separator: "\n") + "\n\nFinal hierarchy:\n" + jsonString
        return CallTool.Result(
            content: [.text(text: output, annotations: nil, _meta: nil)]
        )
    }

    // MARK: - Step parsing

    enum Step: Equatable {
        case tap(String)
        case tapXY(Double, Double)
        case swipe(String)
        case type(String)
        case wait(Double)

        struct Invalid: Error { let message: String }

        static let actions = ["tap", "tap_xy", "swipe", "type", "wait"]

        /// A step has exactly one action key, and nothing else.
        static func parse(_ value: Value) -> Result<Step, Invalid> {
            guard let step = value.objectValue else {
                return .failure(Invalid(message: "not an object"))
            }
            let unknown = step.keys.filter { !actions.contains($0) }.sorted()
            guard unknown.isEmpty else {
                return .failure(Invalid(message: "unknown action \(unknown.map { "'\($0)'" }.joined(separator: ", "))"))
            }
            let present = actions.filter { step[$0] != nil }
            guard let action = present.first else {
                return .failure(Invalid(message: "no action"))
            }
            guard present.count == 1 else {
                return .failure(Invalid(message: "more than one action (\(present.joined(separator: ", "))); use one action per step"))
            }
            let argument = step[action]!
            func string() -> Result<String, Invalid> {
                argument.stringValue.map { .success($0) } ?? .failure(Invalid(message: "'\(action)' must be a string"))
            }
            switch action {
            case "tap":
                return string().map(Step.tap)
            case "swipe":
                return string().map(Step.swipe)
            case "type":
                return string().map(Step.type)
            case "tap_xy":
                guard let point = argument.objectValue,
                      let x = point["x"]?.doubleValue,
                      let y = point["y"]?.doubleValue else {
                    return .failure(Invalid(message: "tap_xy needs numeric x and y"))
                }
                return .success(.tapXY(x, y))
            default: // wait
                guard let seconds = argument.doubleValue, seconds >= 0, seconds.isFinite else {
                    return .failure(Invalid(message: "wait must be a non-negative number of seconds"))
                }
                return .success(.wait(seconds))
            }
        }
    }
}
