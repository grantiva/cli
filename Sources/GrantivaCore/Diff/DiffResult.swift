import Foundation

// MARK: - Step Verification

public enum StepStatus: String, Sendable, Codable {
    case passed
    case failed
}

public struct StepResult: Sendable, Codable {
    public let action: String
    public let status: StepStatus
    public let duration: Double
    public let message: String?

    public init(action: String, status: StepStatus, duration: Double, message: String? = nil) {
        self.action = action
        self.status = status
        self.duration = duration
        self.message = message
    }
}

// MARK: - Capture Types

public struct ScreenCapture: Sendable, Codable {
    public let screenName: String
    public let path: String
    public let sizeBytes: Int
    public let timestamp: Date
    public let steps: [StepResult]

    public init(screenName: String, path: String, sizeBytes: Int, timestamp: Date = Date(), steps: [StepResult] = []) {
        self.screenName = screenName
        self.path = path
        self.sizeBytes = sizeBytes
        self.timestamp = timestamp
        self.steps = steps
    }

    enum CodingKeys: String, CodingKey {
        case screenName = "screen_name"
        case path
        case sizeBytes = "size_bytes"
        case timestamp
        case steps
    }
}

public struct CaptureResult: Sendable, Codable {
    public let screens: [ScreenCapture]
    public let directory: String
    public let duration: Double
    public let simulator: CaptureSimulatorTarget?
    /// Android only: the same target as `simulator`, under the platform's
    /// own name. `simulator` stays for compatibility.
    public let emulator: CaptureSimulatorTarget?

    public init(
        screens: [ScreenCapture], directory: String, duration: Double,
        simulator: CaptureSimulatorTarget? = nil, emulator: CaptureSimulatorTarget? = nil
    ) {
        self.screens = screens
        self.directory = directory
        self.duration = duration
        self.simulator = simulator
        self.emulator = emulator
    }

    /// The one shape `diff capture --json` and the MCP live-session capture
    /// both report: the device under `simulator`, and on Android the same
    /// object again under `emulator`.
    public init(
        screens: [ScreenCapture], directory: String, duration: Double, target: CaptureSimulatorTarget, platform: Platform
    ) {
        self.init(
            screens: screens, directory: directory, duration: duration,
            simulator: target, emulator: platform == .android ? target : nil
        )
    }
}

public struct CaptureSimulatorTarget: Sendable, Codable, Equatable {
    public let name: String
    public let udid: String
    public let pointDimensions: SimulatorProvisionResult.Dimensions
    public let pixelDimensions: SimulatorProvisionResult.Dimensions
    public let displayScale: Double

    public init(name: String, udid: String, geometry: SimulatorDisplayGeometry) {
        self.name = name
        self.udid = udid
        self.pointDimensions = .init(width: geometry.points[0], height: geometry.points[1])
        self.pixelDimensions = .init(width: geometry.pixels[0], height: geometry.pixels[1])
        self.displayScale = geometry.scale
    }

    enum CodingKeys: String, CodingKey {
        case name, udid
        case pointDimensions = "point_dimensions"
        case pixelDimensions = "pixel_dimensions"
        case displayScale = "display_scale"
    }
}

// MARK: - Diff Types

public enum DiffStatus: String, Sendable, Codable {
    case passed
    case failed
    case newScreen = "new_screen"
    case error
}

public struct ScreenDiff: Sendable, Codable {
    public let screenName: String
    public let status: DiffStatus
    public let pixelDiffPercent: Double?
    public let perceptualDistance: Double?
    public let pixelThreshold: Double
    public let perceptualThreshold: Double
    public let baselinePath: String?
    public let capturePath: String
    public let diffImagePath: String?
    public let message: String

    public init(
        screenName: String,
        status: DiffStatus,
        pixelDiffPercent: Double? = nil,
        perceptualDistance: Double? = nil,
        pixelThreshold: Double,
        perceptualThreshold: Double,
        baselinePath: String? = nil,
        capturePath: String,
        diffImagePath: String? = nil,
        message: String
    ) {
        self.screenName = screenName
        self.status = status
        self.pixelDiffPercent = pixelDiffPercent
        self.perceptualDistance = perceptualDistance
        self.pixelThreshold = pixelThreshold
        self.perceptualThreshold = perceptualThreshold
        self.baselinePath = baselinePath
        self.capturePath = capturePath
        self.diffImagePath = diffImagePath
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case screenName = "screen_name"
        case status
        case pixelDiffPercent = "pixel_diff_percent"
        case perceptualDistance = "perceptual_distance"
        case pixelThreshold = "pixel_threshold"
        case perceptualThreshold = "perceptual_threshold"
        case baselinePath = "baseline_path"
        case capturePath = "capture_path"
        case diffImagePath = "diff_image_path"
        case message
    }
}

/// The two checks a compared screen must pass, and the line that says which
/// one it failed. Shared by `diff compare` and `ci run`.
public enum DiffVerdict {
    public static func passes(pixelDiffPercent: Double, perceptualDistance: Double, pixelThreshold: Double, perceptualThreshold: Double) -> Bool {
        pixelDiffPercent <= pixelThreshold && perceptualDistance <= perceptualThreshold
    }

    /// `Passed`, or `Failed:` naming each exceeded threshold and its limit,
    /// with the other measurement in parentheses. The pixel share and its
    /// threshold print as percent, as `pixel=` always has.
    public static func message(pixelDiffPercent: Double, perceptualDistance: Double, pixelThreshold: Double, perceptualThreshold: Double) -> String {
        let pixel = "pixel=\(percent(pixelDiffPercent))"
        let pixelLimit = "threshold \(percent(pixelThreshold))"
        let perceptual = "perceptual=\(String(format: "%.1f", perceptualDistance))"
        let perceptualLimit = "perceptual_threshold \(String(format: "%.1f", perceptualThreshold))"
        let pixelFailed = pixelDiffPercent > pixelThreshold
        let perceptualFailed = perceptualDistance > perceptualThreshold
        switch (pixelFailed, perceptualFailed) {
        case (true, true):
            return "Failed: \(pixel) exceeds \(pixelLimit) and \(perceptual) exceeds \(perceptualLimit)"
        case (true, false):
            return "Failed: \(pixel) exceeds \(pixelLimit) (\(perceptual), \(perceptualLimit))"
        case (false, true):
            return "Failed: \(perceptual) exceeds \(perceptualLimit) (\(pixel), \(pixelLimit))"
        case (false, false):
            return "Passed"
        }
    }

    private static func percent(_ fraction: Double) -> String {
        String(format: "%.2f%%", fraction * 100)
    }
}

public struct CompareResult: Sendable, Codable {
    public let screens: [ScreenDiff]
    public let passed: Bool
    public let duration: Double
    /// Files in the capture directory that are not configured screens and
    /// were left out of the comparison; absent when there were none.
    public let ignored: [String]?

    public init(screens: [ScreenDiff], passed: Bool, duration: Double, ignored: [String] = []) {
        self.screens = screens
        self.passed = passed
        self.duration = duration
        self.ignored = ignored.isEmpty ? nil : ignored
    }
}

// MARK: - Approve Types

public struct ApproveResult: Sendable, Codable {
    public let approvedScreens: [String]
    public let baselineDirectory: String
    /// Files in the capture directory that are not configured screens and
    /// were not approved; absent when there were none.
    public let ignored: [String]?

    public init(approvedScreens: [String], baselineDirectory: String, ignored: [String] = []) {
        self.approvedScreens = approvedScreens
        self.baselineDirectory = baselineDirectory
        self.ignored = ignored.isEmpty ? nil : ignored
    }

    enum CodingKeys: String, CodingKey {
        case approvedScreens = "approved_screens"
        case baselineDirectory = "baseline_directory"
        case ignored
    }
}
