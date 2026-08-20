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
}
