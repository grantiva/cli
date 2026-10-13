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
                    config.screens, appID: appID, udid: udid, platform: platform, driver: driver, device: device,
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
                screens: reported, directory: relativeDir, duration: Date().timeIntervalSince(start),
                target: target, platform: platform
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
    static func captureScreens(
        _ screens: [GrantivaConfig.Screen], appID: String, udid: String, platform: Platform, driver: DriverClient,
        device: any DevicePlatform, outputDir: String, pause: @escaping @Sendable (Double) async -> Void
    ) async throws -> [ScreenCapture] {
        // The one launch is timed (terminate, launch, settle): the first
        // launch-only screen reports it; a later one reports null, since the
        // app was not launched again for it. Never 0 (L23).
        let launchStart = Date()
        try? await device.terminate(appID: appID, deviceID: udid)
        try await device.launch(appID: appID, deviceID: udid)
        await settle(driver: driver, timeout: settleTimeout, pause: pause)
        var launchDuration: Double? = Date().timeIntervalSince(launchStart)
        let rules = try await SelectorRules.current(platform: platform, screens: screens, driver: driver)

        var captures: [ScreenCapture] = []
        for screen in screens {
            var results: [StepResult] = []
            if case .steps(let steps) = screen.path {
                for (index, step) in steps.enumerated() {
                    let action = RunnerSession.stepAction(for: step)
                    let stepStart = Date()
                    do {
                        try await run(step, rules: rules, driver: driver, pause: pause)
                    } catch {
                        throw StepFailure(screen: screen.name, step: index + 1, action: action, reason: describe(error))
                    }
                    results.append(StepResult(action: action, status: .passed, duration: Date().timeIntervalSince(stepStart)))
                }
            } else {
                results.append(StepResult(action: "Launch app", status: .passed, duration: launchDuration))
                launchDuration = nil
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
        _ step: GrantivaConfig.Screen.Step, rules: SelectorRules, driver: DriverClient,
        pause: @escaping @Sendable (Double) async -> Void
    ) async throws {
        if let label = step.tap {
            let selector = Selector(pattern: label, byId: step.tapById, exact: step.tapExact, rules: rules)
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
            let selector = Selector(pattern: label, byId: step.assertVisibleById, exact: step.assertVisibleExact, rules: rules)
            guard try await waitForElement(selector, driver: driver, pause: pause) != nil else {
                throw GrantivaError.notFound("\"\(label)\" is not visible after \(Int(lookupTimeout))s.")
            }
        }
        if let label = step.assertNotVisible {
            let selector = Selector(pattern: label, byId: step.assertNotVisibleById, exact: step.assertNotVisibleExact, rules: rules)
            guard try await waitForAbsence(selector, driver: driver, pause: pause) else {
                throw GrantivaError.notFound("\"\(label)\" is still visible after \(Int(lookupTimeout))s.")
            }
        }
    }

    /// Which element attributes a selector reads on this device, as the
    /// bundled grantiva-runner (1.1.28-grantiva.15) reads them.
    struct SelectorRules: Sendable {
        let platform: Platform
        /// iOS: the agent reports the `identifier` attribute (on every
        /// element, empty when unset). Without it an `id:` reads WDA's
        /// `name`, which falls back to the label.
        let identifierReported: Bool

        /// Reads the page source only when an iOS screen has an `id:` step;
        /// a source that cannot be read fails the capture with its reason.
        static func current(platform: Platform, screens: [GrantivaConfig.Screen], driver: DriverClient) async throws -> SelectorRules {
            var firstIDStep: (screen: String, index: Int, step: GrantivaConfig.Screen.Step)?
            for screen in screens where firstIDStep == nil {
                guard case .steps(let steps) = screen.path else { continue }
                if let index = steps.firstIndex(where: { step in
                    (step.tap != nil && step.tapById) || (step.assertVisible != nil && step.assertVisibleById)
                        || (step.assertNotVisible != nil && step.assertNotVisibleById)
                }) {
                    firstIDStep = (screen.name, index, steps[index])
                }
            }
            guard platform == .ios, let firstIDStep else { return SelectorRules(platform: platform, identifierReported: true) }
            let source: String
            do {
                source = try await driver.hierarchyXML()
            } catch {
                throw StepFailure(
                    screen: firstIDStep.screen, step: firstIDStep.index + 1,
                    action: RunnerSession.stepAction(for: firstIDStep.step),
                    reason: "could not read the page source to match id: selectors: \(describe(error))"
                )
            }
            let reported = source.contains(" identifier=\"")
            if !reported {
                GrantivaLog.logger.warning(
                    "WebDriverAgent does not report accessibility identifiers; id: selectors match WDA's name, which is the label when an element has no identifier."
                )
            }
            return SelectorRules(platform: platform, identifierReported: reported)
        }
    }

    /// A step's element selector, matched per platform as grantiva-runner
    /// matches it. iOS: text reads label, value and placeholder; `id:` reads the
    /// accessibility identifier, ignoring case. Android: text reads text,
    /// content-desc and hint (and the error text, without `exact`); `id:` reads the resource id, whole or after its last
    /// `/`. Text is a case-insensitive regex over the whole value; `exact`
    /// is the whole value as written.
    struct Selector {
        let pattern: String
        let byId: Bool
        let exact: Bool
        let rules: SelectorRules

        func matches(_ element: [String: Any]) -> Bool {
            if byId {
                switch rules.platform {
                case .ios:
                    let key = rules.identifierReported ? "identifier" : "name"
                    return SelectorMatch.iosID(pattern, element[key] as? String ?? "")
                case .android:
                    return SelectorMatch.androidID(pattern, element["identifier"] as? String ?? "")
                }
            }
            // UIAutomator2HierarchyParser puts text in `value` and
            // content-desc in `name`. Android's error text counts only
            // without `exact`: it is a message about the field.
            let keys: [String]
            switch rules.platform {
            case .ios: keys = ["label", "value", "placeholderValue"]
            case .android: keys = exact ? ["value", "name", "hint"] : ["value", "name", "hint", "error"]
            }
            return keys.contains { key in
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
                ["label", "name", "value"].contains { element[$0] as? String == selector.pattern }
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
        VRTTools.failure(message)
    }
}

/// grantiva-runner's selector rules (1.1.28-grantiva.15), so a capture
/// through the session finds the elements a `diff capture` run finds.
enum SelectorMatch {
    /// A text selector, on both platforms: a regex that must match the whole
    /// value, ignoring case, with `.` matching line breaks; a value equal to
    /// the pattern matches too, and each value is also tried with line
    /// breaks as spaces. A pattern that is not a valid regex matches
    /// literally. Both sides are NFC-normalized.
    static func text(_ pattern: String, _ value: String) -> Bool {
        guard !pattern.isEmpty, !value.isEmpty else { return false }
        let pattern = pattern.precomposedStringWithCanonicalMapping
        let value = value.precomposedStringWithCanonicalMapping
        let flat = value.replacingOccurrences(of: "\n", with: " ")
        if value == pattern || flat == pattern { return true }
        let regex = wholeRegex(pattern, options: [.caseInsensitive, .dotMatchesLineSeparators, .anchorsMatchLines])
        return wholeMatch(regex, value) || wholeMatch(regex, flat)
    }

    /// `exact: true`: the whole value as written, case and all, never a regex.
    static func exactText(_ pattern: String, _ value: String) -> Bool {
        !value.isEmpty && value.precomposedStringWithCanonicalMapping == pattern.precomposedStringWithCanonicalMapping
    }

    /// iOS `id:`: the accessibility identifier, ignoring case; an id that is
    /// a regex must match the whole identifier. An element without one
    /// matches no id.
    static func iosID(_ pattern: String, _ identifier: String) -> Bool {
        guard !pattern.isEmpty, !identifier.isEmpty else { return false }
        if pattern.caseInsensitiveCompare(identifier) == .orderedSame { return true }
        guard NSRegularExpression.escapedPattern(for: pattern) != pattern,
              let regex = try? NSRegularExpression(pattern: "\\A(?:\(pattern))\\z", options: [.caseInsensitive])
        else { return false }
        return wholeMatch(regex, identifier)
    }

    /// Android `id:`: the text rule's regex over the whole resource id, or
    /// over the part after its last `/` (`login` finds `com.app:id/login`).
    static func androidID(_ pattern: String, _ identifier: String) -> Bool {
        guard !pattern.isEmpty, !identifier.isEmpty else { return false }
        let regex = wholeRegex(pattern, options: [.caseInsensitive, .dotMatchesLineSeparators, .anchorsMatchLines])
        let suffix = identifier.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? identifier
        return wholeMatch(regex, identifier) || wholeMatch(regex, suffix)
    }

    private static func wholeRegex(_ pattern: String, options: NSRegularExpression.Options) -> NSRegularExpression {
        if let regex = try? NSRegularExpression(pattern: "\\A(?:\(pattern))\\z", options: options) { return regex }
        let literal = NSRegularExpression.escapedPattern(for: pattern)
        // An escaped pattern always compiles.
        return try! NSRegularExpression(pattern: "\\A(?:\(literal))\\z", options: options)
    }

    private static func wholeMatch(_ regex: NSRegularExpression, _ value: String) -> Bool {
        regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }
}
