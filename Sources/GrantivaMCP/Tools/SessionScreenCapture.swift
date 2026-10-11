import Foundation
import GrantivaCore

/// `grantiva diff capture --no-build` on a device a live `runner start`
/// session holds: the screens are captured through the session's driver,
/// as `grantiva_vrt_capture` does, instead of starting a second runner that
/// the device lease refuses.
@available(macOS 15, *)
public enum SessionScreenCapture {
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
        expectedPixels: SimulatorProvisionResult.Dimensions?
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
            captures = try await VRTTools.captureScreens(
                screens, appID: appID, udid: udid, platform: platform, driver: driver, device: device,
                outputDir: outputDir, pause: { try? await Task.sleep(for: .seconds($0)) }
            )
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
}
