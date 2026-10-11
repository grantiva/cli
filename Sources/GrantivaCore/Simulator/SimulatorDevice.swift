import Foundation

public struct SimulatorDevice: Sendable, Codable, Equatable {
    public let name: String
    public let udid: String
    public let state: String
    public let runtime: String
    public let isAvailable: Bool
    public let deviceTypeIdentifier: String?

    public var isBooted: Bool { state == "Booted" }

    public init(name: String, udid: String, state: String, runtime: String, isAvailable: Bool, deviceTypeIdentifier: String? = nil) {
        self.name = name
        self.udid = udid
        self.state = state
        self.runtime = runtime
        self.isAvailable = isAvailable
        self.deviceTypeIdentifier = deviceTypeIdentifier
    }
}

public struct SimulatorDisplayGeometry: Sendable, Codable, Equatable {
    public let points: [Int]
    public let pixels: [Int]
    public let scale: Double

    public init(points: [Int], pixels: [Int], scale: Double) {
        self.points = points
        self.pixels = pixels
        self.scale = scale
    }
}

extension SimulatorDisplayGeometry {
    /// Points derived from a device's pixels and scale.
    public init(_ geometry: DeviceGeometry) {
        self.init(
            points: [
                Int((Double(geometry.pixelWidth) / geometry.scale).rounded()),
                Int((Double(geometry.pixelHeight) / geometry.scale).rounded()),
            ],
            pixels: [geometry.pixelWidth, geometry.pixelHeight],
            scale: geometry.scale
        )
    }
}

public struct SimulatorProvisionResult: Sendable, Codable, Equatable {
    public struct Dimensions: Sendable, Codable, Equatable {
        public let width: Int
        public let height: Int
        public init(width: Int, height: Int) { self.width = width; self.height = height }
    }
    public let name: String
    public let udid: String
    public let deviceType: String
    public let runtime: String
    public let created: Bool
    public let state: String
    public let pointDimensions: Dimensions?
    public let pixelDimensions: Dimensions?
    public let displayScale: Double?

    public init(name: String, udid: String, deviceType: String, runtime: String, created: Bool, state: String, pointWidth: Int?, pointHeight: Int?, pixelWidth: Int?, pixelHeight: Int?, displayScale: Double?) {
        self.name = name; self.udid = udid; self.deviceType = deviceType; self.runtime = runtime
        self.created = created; self.state = state
        self.pointDimensions = pointWidth.map { Dimensions(width: $0, height: pointHeight!) }
        self.pixelDimensions = pixelWidth.map { Dimensions(width: $0, height: pixelHeight!) }
        self.displayScale = displayScale
    }

    enum CodingKeys: String, CodingKey {
        case name, udid, created, state, runtime
        case deviceType = "device_type"
        case pointDimensions = "point_dimensions"
        case pixelDimensions = "pixel_dimensions"
        case displayScale = "display_scale"
    }

    /// camelCase keys, plus the snake_case aliases listed in
    /// `LegacyJSONKeys.renamed` for existing consumers. Decoding still reads
    /// the snake_case keys.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: LegacyJSONKeys.self)
        try c.encodeWithAlias(name, "name")
        try c.encodeWithAlias(udid, "udid")
        try c.encodeWithAlias(deviceType, "deviceType")
        try c.encodeWithAlias(runtime, "runtime")
        try c.encodeWithAlias(created, "created")
        try c.encodeWithAlias(state, "state")
        try c.encodeIfPresentWithAlias(pointDimensions, "pointDimensions")
        try c.encodeIfPresentWithAlias(pixelDimensions, "pixelDimensions")
        try c.encodeIfPresentWithAlias(displayScale, "displayScale")
    }
}

extension SimulatorDevice {
    /// simctl's runtime identifier tail as people read it: `iOS-26-0` becomes
    /// `iOS 26.0`. The one spelling every runtime Grantiva shows uses.
    public static func runtimeDisplayName(_ runtime: String) -> String {
        let short = runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
        guard let dash = short.firstIndex(of: "-") else { return short }
        let version = short[short.index(after: dash)...].replacingOccurrences(of: "-", with: ".")
        return "\(short[..<dash]) \(version)"
    }

    /// This device's runtime, spelled as `runtimeDisplayName` spells it.
    public var runtimeName: String { Self.runtimeDisplayName(runtime) }
}
