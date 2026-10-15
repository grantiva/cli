import Foundation
import GrantivaCore

/// `grantiva diff capture --no-build` on a device a live `runner start`
/// session holds: the screens are captured through the session's driver,
/// as `grantiva_vrt_capture` does, instead of starting a second runner that
/// the device lease refuses.
@available(macOS 15, *)
public enum SessionScreenCapture {
    /// As `RunnerSession.run`'s default `--timeout` for a screens run.
    public static let defaultTimeoutSeconds: UInt64 = 300

    /// Captures `screens` into `outputDir` through `driver` on `udid` and
    /// returns them as `RunnerSession.run` would. Throws, naming the screen
    /// and step, when a step fails or only the runner can run it.
    public static func capture(
        screens: [GrantivaConfig.Screen],
        appID: String,
        udid: String,
        platform: Platform,
        driver: DriverClient,
        device: any DevicePlatform,
        outputDir: String,
        expectedPixels: SimulatorProvisionResult.Dimensions?,
        environment: [String: String] = [:],
        timeoutSeconds: UInt64 = defaultTimeoutSeconds
    ) async throws -> [ScreenCapture] {
        for screen in screens {
            guard case .steps(let steps) = screen.path else { continue }
            for (index, step) in steps.enumerated() {
                if let kind = VRTTools.runnerOnlyStep(step) {
                    throw GrantivaError.invalidArgument(
                        "Screen \"\(screen.name)\" step \(index + 1) is \(kind), which only grantiva-runner can run, and a `grantiva runner start` session holds \(udid). "
                            + "Stop the session with `grantiva runner stop` and run `grantiva diff capture` again."
                    )
                }
            }
        }
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        try RunnerSession.invalidateCaptures(of: screens, in: outputDir)
        await device.prepareForCapture(deviceID: udid)
        let captures: [ScreenCapture]
        do {
            captures = try await withTimeout(seconds: timeoutSeconds) {
                try await VRTTools.captureScreens(
                    screens, appID: appID, udid: udid, platform: platform, driver: driver, device: device,
                    outputDir: outputDir, environment: environment, pause: { try? await Task.sleep(for: .seconds($0)) }
                )
            }
        } catch let failure as VRTTools.StepFailure {
            await device.restoreAfterCapture(deviceID: udid)
            throw GrantivaError.commandFailed(
                "Screen \"\(failure.screen)\", step \(failure.step) (\(failure.action)): \(failure.reason)", 1
            )
        } catch {
            await device.restoreAfterCapture(deviceID: udid)
            throw error
        }
        await device.restoreAfterCapture(deviceID: udid)
        if let expectedPixels {
            try ScreenshotNormalizer.normalize(captures: captures, expectedPixels: expectedPixels)
        }
        return captures
    }

    /// Runs `body`, failing once `seconds` pass: a wedged driver must not
    /// hang the capture forever.
    static func withTimeout<T: Sendable>(
        seconds: UInt64, _ body: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw GrantivaError.commandFailed(
                    "Capturing through the runner session timed out after \(seconds)s.", 1
                )
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw CancellationError() }
            return first
        }
    }
}
