import Foundation
import GrantivaCore
import MCP

/// `grantiva_vrt_capture` while a runner session holds the device.
///
/// `grantiva diff capture` starts its own grantiva-runner, which would start a
/// second WebDriverAgent on a device the session already drives, so the device
/// lease refuses it. With a live session the capture goes through the
/// session instead: the app is relaunched on the session's device, each
/// screen's steps run through the session's driver, and the platform
/// screenshot is written where `diff capture` writes it.
@available(macOS 15, *)
extension VRTTools {
    static func captureDirectory(for platform: Platform) -> String {
        platform == .ios ? ".grantiva/captures" : ".grantiva/captures/android"
    }

    /// The longest wait for the screen to stop changing after an action and
    /// before each screenshot, as in the generated runner flow.
    static let settleTimeout = 5.0
    /// How long an `assert_visible` or `assert_not_visible` step waits.
    static let assertionTimeout = 5.0

    /// Steps only the runner can run; nil when the session's driver can.
    static func runnerOnlyStep(_ step: GrantivaConfig.Screen.Step) -> String? {
        if step.runFlow != nil { return "runFlow" }
        if step.swipeFrom != nil { return "a swipe from an element" }
        if step.swipeStart != nil || step.swipeEnd != nil { return "a swipe between points" }
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
        outputDir: String,
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
            let result = CaptureResult(
                screens: captures, directory: outputDir, duration: Date().timeIntervalSince(start), simulator: target
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
            try await device.screenshot(deviceID: udid, to: path)
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            captures.append(ScreenCapture(screenName: screen.name, path: path, sizeBytes: size, steps: results))
        }
        return captures
    }

    /// Runs the actions a step carries, in the order the runner flow does.
    private static func run(
        _ step: GrantivaConfig.Screen.Step, driver: DriverClient, pause: @escaping @Sendable (Double) async -> Void
    ) async throws {
        if let label = step.tap {
            try await driver.tapByLabel(label)
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
            guard try await waitFor(label, visible: true, byId: step.assertVisibleById, exact: step.assertVisibleExact, driver: driver, pause: pause) else {
                throw GrantivaError.notFound("\"\(label)\" is not visible after \(Int(assertionTimeout))s.")
            }
        }
        if let label = step.assertNotVisible {
            guard try await waitFor(label, visible: false, byId: step.assertNotVisibleById, exact: step.assertNotVisibleExact, driver: driver, pause: pause) else {
                throw GrantivaError.notFound("\"\(label)\" is still visible after \(Int(assertionTimeout))s.")
            }
        }
    }

    /// Polls the hierarchy until `label` is (or is not) on screen.
    private static func waitFor(
        _ label: String, visible: Bool, byId: Bool, exact: Bool, driver: DriverClient,
        pause: @escaping @Sendable (Double) async -> Void
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(assertionTimeout)
        while true {
            let found = contains(try await driver.hierarchy(), label: label, byId: byId, exact: exact)
            if found == visible { return true }
            if Date() >= deadline { return false }
            await pause(0.25)
        }
    }

    /// Whether any element carries `label`: by identifier, or by text, which
    /// matches the whole value when `exact` and any part of it otherwise.
    static func contains(_ element: [String: Any], label: String, byId: Bool, exact: Bool) -> Bool {
        let keys = byId ? ["identifier", "name"] : ["label", "name", "value", "text"]
        for key in keys {
            guard let value = element[key] as? String, !value.isEmpty else { continue }
            if value == label || (!byId && !exact && value.contains(label)) { return true }
        }
        let children = element["children"] as? [[String: Any]] ?? []
        return children.contains { contains($0, label: label, byId: byId, exact: exact) }
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
