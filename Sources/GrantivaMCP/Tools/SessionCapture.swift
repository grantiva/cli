import Foundation
import GrantivaCore
import MCP

/// `grantiva_vrt_capture` while a runner session holds the device.
///
/// `grantiva diff capture` starts its own grantiva-runner, which would start a
/// second WebDriverAgent on a device the session already drives, so the device
/// lease refuses it. With a live session the capture goes through the
/// session instead: the app is relaunched on the session's device, each
/// screen's steps run through the session's driver, and the driver's
/// screenshot is written where `diff capture` writes it.
@available(macOS 15, *)
extension VRTTools {
    static func captureDirectory(for platform: Platform) -> String {
        platform == .ios ? ".grantiva/captures" : ".grantiva/captures/android"
    }

    /// The longest wait for the screen to stop changing after an action and
    /// before each screenshot, as in the generated runner flow.
    static let settleTimeout = 5.0
    /// How long a tap, `assert_visible` or `assert_not_visible` step waits
    /// for its element.
    static let lookupTimeout = 5.0

    /// Steps only the runner can run; nil when the session's driver can.
    static func runnerOnlyStep(_ step: GrantivaConfig.Screen.Step) -> String? {
        if step.runFlow != nil { return "runFlow" }
        if step.swipeFrom != nil { return "a swipe from an element" }
        if step.swipeStart != nil || step.swipeEnd != nil { return "a swipe between points" }
        if step.swipeDuration != nil { return "a swipe with a duration" }
        return nil
    }

    struct StepFailure: Error {
        let screen: String
        let step: Int
        let action: String
        let reason: String
    }

    static func captureThroughSession(
        config: GrantivaConfig?,
        missingConfig: String,
        platform: Platform,
        session: RunnerSessionInfo,
        driver attach: @Sendable () async throws -> DriverClient,
        device: any DevicePlatform,
        projectDirectory: URL,
        pause: @escaping @Sendable (Double) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) async -> CallTool.Result {
        guard let config else { return captureFailure(missingConfig) }
        guard !config.screens.isEmpty else {
            return captureFailure("No screens configured in \(platform.configFileName)")
        }
        let configuredID = platform == .ios ? config.bundleId : config.android?.applicationId
        guard let appID = configuredID ?? (session.bundleId.isEmpty ? nil : session.bundleId) else {
            return captureFailure(platform == .ios
                ? "Bundle ID is required for screen capture. Set bundle_id in grantiva.yml."
                : "Application ID is required for screen capture. Set application_id in grantiva-android.yml.")
        }
        guard !session.udid.isEmpty else {
            return captureFailure(
                "The runner session does not record which device it holds. Restart it with grantiva runner stop and grantiva runner start."
            )
        }
        for screen in config.screens {
            guard case .steps(let steps) = screen.path else { continue }
            for (index, step) in steps.enumerated() {
                if let kind = runnerOnlyStep(step) {
                    return captureFailure(
                        "Screen \"\(screen.name)\" step \(index + 1) is \(kind), which only grantiva-runner can run, and the live runner session holds the device. "
                            + "Stop the session with grantiva runner stop and call grantiva_vrt_capture again, or run grantiva diff capture."
                    )
                }
            }
        }

        let driver: DriverClient
        do {
            driver = try await attach()
        } catch {
            return captureFailure(describe(error))
        }

        let udid = session.udid
        let start = Date()
        // Written under the project, reported relative to it as `diff capture --json` does.
        let relativeDir = captureDirectory(for: platform)
        let outputDir = projectDirectory.appendingPathComponent(relativeDir).path
        do {
            let booted = try await device.bootDevice(named: udid)
            let target = CaptureSimulatorTarget(
                name: booted.name, udid: udid,
                geometry: SimulatorDisplayGeometry(try await device.displayGeometry(deviceID: udid))
            )
            try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
            try RunnerSession.invalidateCaptures(of: config.screens, in: outputDir)

            await device.prepareForCapture(deviceID: udid)
            let captures: [ScreenCapture]
            do {
                captures = try await captureScreens(
                    config.screens, appID: appID, udid: udid, driver: driver, device: device,
                    outputDir: outputDir, pause: pause
                )
            } catch {
                await device.restoreAfterCapture(deviceID: udid)
                throw error
            }
            await device.restoreAfterCapture(deviceID: udid)

            try ScreenshotNormalizer.normalize(captures: captures, expectedPixels: target.pixelDimensions)
            let reported = captures.map {
                ScreenCapture(
                    screenName: $0.screenName, path: "\(relativeDir)/\(ScreenArtifact.fileName(for: $0.screenName))",
                    sizeBytes: $0.sizeBytes, timestamp: $0.timestamp, steps: $0.steps
                )
            }
            let result = CaptureResult(
                screens: reported, directory: relativeDir, duration: Date().timeIntervalSince(start), simulator: target
            )
            return CallTool.Result(content: [.text(text: try JSONOutput.string(result), annotations: nil, _meta: nil)])
        } catch let failure as StepFailure {
            return captureFailure("Screen \"\(failure.screen)\", step \(failure.step) (\(failure.action)): \(failure.reason)")
        } catch {
            return captureFailure(describe(error))
        }
    }

    /// One continuous pass, like the generated runner flow: launch the app
    /// once, then each screen's steps followed by its screenshot.
    private static func captureScreens(
        _ screens: [GrantivaConfig.Screen], appID: String, udid: String, driver: DriverClient,
        device: any DevicePlatform, outputDir: String, pause: @escaping @Sendable (Double) async -> Void
    ) async throws -> [ScreenCapture] {
        try? await device.terminate(appID: appID, deviceID: udid)
        try await device.launch(appID: appID, deviceID: udid)
        await settle(driver: driver, timeout: settleTimeout, pause: pause)

        var captures: [ScreenCapture] = []
        for screen in screens {
            var results: [StepResult] = []
            if case .steps(let steps) = screen.path {
                for (index, step) in steps.enumerated() {
                    let action = RunnerSession.stepAction(for: step)
                    let stepStart = Date()
                    do {
                        try await run(step, driver: driver, pause: pause)
                    } catch {
                        throw StepFailure(screen: screen.name, step: index + 1, action: action, reason: describe(error))
                    }
                    results.append(StepResult(action: action, status: .passed, duration: Date().timeIntervalSince(stepStart)))
                }
            } else {
                results.append(StepResult(action: "Launch app", status: .passed, duration: 0))
            }
            await settle(driver: driver, timeout: settleTimeout, pause: pause)
            let path = "\(outputDir)/\(ScreenArtifact.fileName(for: screen.name))"
            // From the driver, as the runner's takeScreenshot does: the
            // platform screenshot (simctl) differs in its corner pixels, so
            // it would not compare clean against runner-made baselines.
            let image = try await driver.screenshot()
            try image.write(to: URL(fileURLWithPath: path))
            let size = image.count
            captures.append(ScreenCapture(screenName: screen.name, path: path, sizeBytes: size, steps: results))
        }
        return captures
    }

    /// Runs the actions a step carries, in the order the runner flow does.
    private static func run(
        _ step: GrantivaConfig.Screen.Step, driver: DriverClient, pause: @escaping @Sendable (Double) async -> Void
    ) async throws {
        if let label = step.tap {
            let selector = Selector(pattern: label, byId: step.tapById, exact: step.tapExact)
            guard let element = try await waitForElement(selector, driver: driver, pause: pause) else {
                throw GrantivaError.elementNotFound(label)
            }
            guard let point = center(of: element) else {
                throw GrantivaError.notFound("\"\(label)\" has no frame to tap.")
            }
            try await driver.tapByCoordinate(point.x, point.y)
            await settle(driver: driver, timeout: settleTimeout, pause: pause)
        }
        if let direction = step.swipe {
            try await driver.swipe(direction)
            await settle(driver: driver, timeout: settleTimeout, pause: pause)
        }
        if let text = step.type {
            try await driver.typeText(text)
            await settle(driver: driver, timeout: settleTimeout, pause: pause)
        }
        if let seconds = step.wait {
            await pause(seconds)
        }
        if let seconds = step.settle {
            await settle(driver: driver, timeout: seconds, pause: pause)
        }
        if let label = step.assertVisible {
            let selector = Selector(pattern: label, byId: step.assertVisibleById, exact: step.assertVisibleExact)
            guard try await waitForElement(selector, driver: driver, pause: pause) != nil else {
                throw GrantivaError.notFound("\"\(label)\" is not visible after \(Int(lookupTimeout))s.")
            }
        }
        if let label = step.assertNotVisible {
            let selector = Selector(pattern: label, byId: step.assertNotVisibleById, exact: step.assertNotVisibleExact)
            guard try await waitForAbsence(selector, driver: driver, pause: pause) else {
                throw GrantivaError.notFound("\"\(label)\" is still visible after \(Int(lookupTimeout))s.")
            }
        }
    }

    /// A step's element selector, matched as grantiva-runner matches it:
    /// text is a case-insensitive regex over the whole value (literal
    /// equality also matches); `exact` is the whole value in its own case;
    /// an id is the accessibility identifier.
    struct Selector {
        let pattern: String
        let byId: Bool
        let exact: Bool

        func matches(_ element: [String: Any]) -> Bool {
            if byId {
                if let identifier = element["identifier"] as? String, SelectorMatch.id(pattern, identifier) { return true }
                // WDA reports the accessibility identifier as `name`; the
                // runner looks it up with an exact name predicate.
                return element["name"] as? String == pattern
            }
            return ["label", "name", "value", "text"].contains { key in
                guard let value = element[key] as? String, !value.isEmpty else { return false }
                return exact ? SelectorMatch.exactText(pattern, value) : SelectorMatch.text(pattern, value)
            }
        }
    }

    /// The first visible element `selector` matches, waiting
    /// up to `lookupTimeout` for it to appear. Of several, one written in
    /// the selector's own case wins.
    static func waitForElement(
        _ selector: Selector, driver: DriverClient, pause: @escaping @Sendable (Double) async -> Void
    ) async throws -> [String: Any]? {
        let deadline = Date().addingTimeInterval(lookupTimeout)
        while true {
            let found = visibleMatches(selector, in: try await driver.hierarchy())
            let preferred = found.first { element in
                ["label", "name", "value", "text"].contains { element[$0] as? String == selector.pattern }
            } ?? found.first
            if let preferred { return preferred }
            if Date() >= deadline { return nil }
            await pause(0.25)
        }
    }

    /// Whether no visible element matches `selector`, waiting up to
    /// `lookupTimeout` for the last one to go.
    static func waitForAbsence(
        _ selector: Selector, driver: DriverClient, pause: @escaping @Sendable (Double) async -> Void
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(lookupTimeout)
        while true {
            if visibleMatches(selector, in: try await driver.hierarchy()).isEmpty { return true }
            if Date() >= deadline { return false }
            await pause(0.25)
        }
    }

    /// Matching elements in document order, skipping hidden ones and the
    /// application element (its label is the app's name).
    static func visibleMatches(_ selector: Selector, in element: [String: Any]) -> [[String: Any]] {
        var found: [[String: Any]] = []
        let isApplication = element["type"] as? String == "XCUIElementTypeApplication"
        if !isApplication, element["visible"] as? Bool != false, selector.matches(element) {
            found.append(element)
        }
        for child in element["children"] as? [[String: Any]] ?? [] {
            found += visibleMatches(selector, in: child)
        }
        return found
    }

    /// The middle of an element's frame, in the unit the driver taps in.
    static func center(of element: [String: Any]) -> (x: Double, y: Double)? {
        guard let frame = element["frame"] as? [String: Any],
              let x = number(frame["x"]), let y = number(frame["y"]),
              let width = number(frame["width"]), let height = number(frame["height"]) else { return nil }
        return (x + width / 2, y + height / 2)
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let string as String: return Double(string)
        default: return nil
        }
    }

    /// Waits until two consecutive driver screenshots match, for at most
    /// `timeout` seconds. A screenshot error ends the wait; the step after
    /// it reports the driver problem.
    static func settle(driver: DriverClient, timeout: Double, pause: @escaping @Sendable (Double) async -> Void) async {
        let deadline = Date().addingTimeInterval(timeout)
        var previous: Data?
        while true {
            guard let shot = try? await driver.screenshot() else { return }
            if shot == previous || Date() >= deadline { return }
            previous = shot
            await pause(0.25)
        }
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private static func captureFailure(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: "Capture failed:\n\(message)", annotations: nil, _meta: nil)], isError: true)
    }
}

/// grantiva-runner's selector text rules, so a capture through the session
/// finds the same elements a `diff capture` run does.
enum SelectorMatch {
    /// A text selector: a regex that must match the whole value, ignoring
    /// case, with `.` matching line breaks; a value equal to the pattern
    /// matches too, and each value is also tried with line breaks as spaces.
    /// A pattern that is not a valid regex matches literally.
    static func text(_ pattern: String, _ value: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        let flat = value.replacingOccurrences(of: "\n", with: " ")
        if value == pattern || flat == pattern { return true }
        let regex = wholeRegex(pattern)
        return wholeMatch(regex, value) || wholeMatch(regex, flat)
    }

    /// `exact: true`: the whole value in the selector's own case.
    static func exactText(_ pattern: String, _ value: String) -> Bool {
        value == pattern || value.replacingOccurrences(of: "\n", with: " ") == pattern
    }

    /// An id selector: the same regex over the whole identifier, or over
    /// the part after its last `/` (`login` finds `com.app:id/login`).
    static func id(_ pattern: String, _ identifier: String) -> Bool {
        guard !pattern.isEmpty, !identifier.isEmpty else { return false }
        let regex = wholeRegex(pattern)
        let suffix = identifier.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? identifier
        return wholeMatch(regex, identifier) || wholeMatch(regex, suffix)
    }

    private static func wholeRegex(_ pattern: String) -> NSRegularExpression {
        let options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators, .anchorsMatchLines]
        if let regex = try? NSRegularExpression(pattern: "\\A(?:\(pattern))\\z", options: options) { return regex }
        let literal = NSRegularExpression.escapedPattern(for: pattern)
        // An escaped pattern always compiles.
        return try! NSRegularExpression(pattern: "\\A(?:\(literal))\\z", options: options)
    }

    private static func wholeMatch(_ regex: NSRegularExpression, _ value: String) -> Bool {
        regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }
}
