import Foundation
import Yams

public struct GrantivaConfig: Sendable, Codable {
    public var scheme: String?
    public var workspace: String?
    public var project: String?
    public var simulator: String?
    public var bundleId: String?
    public var buildSettings: [String]?
    public var screens: [Screen]
    /// Paths to external Maestro YAML flow files to run in addition to `screens`.
    public var flows: [String]
    public var diff: DiffConfig
    public var a11y: A11yConfig
    /// Which platform this file describes. `.ios` for grantiva.yml and
    /// Maestro-format input; `.android` for grantiva-android.yml.
    public var platform: Platform = .ios
    /// Gradle-side settings. Present only when `platform == .android`.
    public var android: AndroidProject?
    /// A Maestro-format file's header `env:` block: `${VAR}` values for its
    /// steps, also passed to the app at every launch. Empty otherwise.
    public var environment: [String: String] = [:]
    /// Non-fatal problems found while loading the file, such as unknown keys.
    /// Each is a complete line naming the file and line number.
    public var warnings: [String] = []

    public struct Screen: Sendable, Codable {
        public var name: String
        public var path: ScreenPath

        public struct Step: Sendable, Codable {
            public var tap: String?
            public var swipe: String?
            public var type: String?
            public var wait: Double?
            public var assertVisible: String?
            public var assertNotVisible: String?
            public var runFlow: String?
            /// Set when the step selects by `id:` (`tap: {id: "clock"}` in the
            /// native form, or `id:` in a Maestro source): the label is an
            /// accessibility identifier (iOS) or resource id / test tag
            /// (Android), not text.
            public var tapById: Bool = false
            public var assertVisibleById: Bool = false
            public var assertNotVisibleById: Bool = false
            /// Maestro `swipe: {from: ...}`: the element the swipe starts on.
            public var swipeFrom: String? = nil
            public var swipeFromById: Bool = false
            /// Maestro `swipe: {start: "x%, y%", end: "x%, y%"}`: exact points,
            /// emitted instead of `direction`.
            public var swipeStart: String? = nil
            public var swipeEnd: String? = nil
            /// Maestro `swipe: {duration: ms}`.
            public var swipeDuration: Int? = nil
            /// Maestro `waitForAnimationToEnd`: wait until the screen is still,
            /// for at most this many seconds. Unlike `wait`, it returns early.
            public var settle: Double? = nil
            /// Maestro `extendedWaitUntil: {visible|notVisible, timeout}`: the
            /// assertion waits up to this many milliseconds. Set only by the
            /// Maestro parser; emitted as `extendedWaitUntil`.
            public var waitTimeout: Int? = nil
            /// Maestro `scrollUntilVisible`: scroll until `assertVisible`'s
            /// element is on screen. Emitted as `scrollUntilVisible`, with
            /// `scrollDirection` and `waitTimeout` when the source gave them.
            public var scrollUntilVisible: Bool = false
            public var scrollDirection: String? = nil
            /// Maestro `doubleTapOn` / `longPressOn`: how `tap`'s element is
            /// touched. Set only by the Maestro parser.
            public var tapGesture: TapGesture = .tap
            /// Maestro `stopApp`, `killApp`, or a `launchApp` after the first
            /// command: an app lifecycle step. Set only by the Maestro parser.
            public var app: AppCommand? = nil

            public enum TapGesture: String, Sendable, Codable {
                case tap = "tapOn"
                case doubleTap = "doubleTapOn"
                case longPress = "longPressOn"
            }

            public enum AppCommand: String, Sendable, Codable {
                case launchApp, stopApp, killApp
            }

            public init(app: AppCommand) {
                self.init()
                self.app = app
            }

            /// The directions a swipe step takes, lowercased.
            static let swipeDirectionNames = ["up", "down", "left", "right"]

            /// Set by the mapping form `{text: "...", exact: true}`: the label
            /// must equal the element's full text, not merely occur in it.
            public var tapExact: Bool
            public var assertVisibleExact: Bool
            public var assertNotVisibleExact: Bool

            public init(
                tap: String? = nil, swipe: String? = nil, type: String? = nil,
                wait: Double? = nil, assertVisible: String? = nil,
                assertNotVisible: String? = nil, runFlow: String? = nil,
                tapById: Bool = false, assertVisibleById: Bool = false,
                assertNotVisibleById: Bool = false,
                swipeFrom: String? = nil, swipeFromById: Bool = false,
                settle: Double? = nil,
                tapExact: Bool = false, assertVisibleExact: Bool = false,
                assertNotVisibleExact: Bool = false
            ) {
                self.tap = tap
                self.swipe = swipe
                self.type = type
                self.wait = wait
                self.assertVisible = assertVisible
                self.assertNotVisible = assertNotVisible
                self.runFlow = runFlow
                self.tapById = tapById
                self.assertVisibleById = assertVisibleById
                self.assertNotVisibleById = assertNotVisibleById
                self.swipeFrom = swipeFrom
                self.swipeFromById = swipeFromById
                self.settle = settle
                self.tapExact = tapExact
                self.assertVisibleExact = assertVisibleExact
                self.assertNotVisibleExact = assertNotVisibleExact
            }

            enum CodingKeys: String, CodingKey, CaseIterable {
                case tap, swipe, type, wait
                case assertVisible = "assert_visible"
                case assertNotVisible = "assert_not_visible"
                case runFlow = "run_flow"
            }

            /// `tap:`, `assert_visible:` and `assert_not_visible:` take a bare
            /// label, `{text: "Label", exact: true}`, or `{id: "identifier"}`
            /// (L42-a). A mapping names exactly one of `text` and `id`.
            struct Label: Codable {
                var text: String?
                var id: String?
                var exact: Bool?

                enum CodingKeys: String, CodingKey, CaseIterable {
                    case text, id, exact
                }

                /// What a label mapping accepts, for config errors.
                static let acceptedForms = #"a label, {text: "…", exact: true} or {id: "…"}"#

                init(text: String? = nil, id: String? = nil, exact: Bool? = nil) {
                    self.text = text
                    self.id = id
                    self.exact = exact
                }

                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    text = try c.decodeIfPresent(String.self, forKey: .text)
                    id = try c.decodeIfPresent(String.self, forKey: .id)
                    exact = try c.decodeIfPresent(Bool.self, forKey: .exact)
                    if text != nil, id != nil {
                        throw DecodingError.dataCorrupted(.init(
                            codingPath: decoder.codingPath, debugDescription: "takes text or id, not both"
                        ))
                    }
                    if id != nil, exact != nil {
                        throw DecodingError.dataCorrupted(.init(
                            codingPath: decoder.codingPath, debugDescription: "`exact` applies to `text` steps only"
                        ))
                    }
                    if text == nil, id == nil {
                        throw DecodingError.dataCorrupted(.init(
                            codingPath: decoder.codingPath, debugDescription: "takes \(Self.acceptedForms)"
                        ))
                    }
                }

                func encode(to encoder: Encoder) throws {
                    var c = encoder.container(keyedBy: CodingKeys.self)
                    try c.encodeIfPresent(text, forKey: .text)
                    try c.encodeIfPresent(id, forKey: .id)
                    try c.encodeIfPresent(exact, forKey: .exact)
                }
            }

            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                func label(_ key: CodingKeys) throws -> (String?, Bool, Bool) {
                    guard c.contains(key), try !c.decodeNil(forKey: key) else { return (nil, false, false) }
                    if let text = try? c.decode(String.self, forKey: key) { return (text, false, false) }
                    let mapped = try c.decode(Label.self, forKey: key)
                    if let id = mapped.id { return (id, false, true) }
                    return (mapped.text, mapped.exact ?? false, false)
                }
                (tap, tapExact, tapById) = try label(.tap)
                (assertVisible, assertVisibleExact, assertVisibleById) = try label(.assertVisible)
                (assertNotVisible, assertNotVisibleExact, assertNotVisibleById) = try label(.assertNotVisible)
                swipe = try c.decodeIfPresent(String.self, forKey: .swipe)
                type = try c.decodeIfPresent(String.self, forKey: .type)
                wait = try c.decodeIfPresent(Double.self, forKey: .wait)
                runFlow = try c.decodeIfPresent(String.self, forKey: .runFlow)
            }

            public func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                func label(_ text: String?, exact: Bool, byId: Bool, _ key: CodingKeys) throws {
                    guard let text else { return }
                    if byId {
                        try c.encode(Label(id: text), forKey: key)
                    } else if exact {
                        try c.encode(Label(text: text, exact: true), forKey: key)
                    } else {
                        try c.encode(text, forKey: key)
                    }
                }
                try label(tap, exact: tapExact, byId: tapById, .tap)
                try c.encodeIfPresent(swipe, forKey: .swipe)
                try c.encodeIfPresent(type, forKey: .type)
                try c.encodeIfPresent(wait, forKey: .wait)
                try label(assertVisible, exact: assertVisibleExact, byId: assertVisibleById, .assertVisible)
                try label(assertNotVisible, exact: assertNotVisibleExact, byId: assertNotVisibleById, .assertNotVisible)
                try c.encodeIfPresent(runFlow, forKey: .runFlow)
            }
        }

        public init(name: String, path: ScreenPath) {
            self.name = name
            self.path = path
        }
    }

    public enum ScreenPath: Sendable {
        case launch
        case steps([Screen.Step])
    }

    public struct DiffConfig: Sendable, Codable {
        public var threshold: Double
        public var perceptualThreshold: Double

        public init(threshold: Double = 0.02, perceptualThreshold: Double = 5.0) {
            self.threshold = threshold
            self.perceptualThreshold = perceptualThreshold
        }

        enum CodingKeys: String, CodingKey, CaseIterable {
            case threshold
            case perceptualThreshold = "perceptual_threshold"
        }
    }

    public struct A11yConfig: Sendable, Codable {
        public var rules: [String]

        public init(rules: [String] = ["missing_label", "small_tap_target"]) {
            self.rules = rules
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case scheme, workspace, project, simulator
        case bundleId = "bundle_id"
        case buildSettings = "build_settings"
        case screens, flows, diff, a11y
        case platform
    }

    public init(
        scheme: String? = nil,
        workspace: String? = nil,
        project: String? = nil,
        simulator: String? = nil,
        bundleId: String? = nil,
        buildSettings: [String]? = nil,
        screens: [Screen] = [],
        flows: [String] = [],
        diff: DiffConfig = .init(),
        a11y: A11yConfig = .init(),
        platform: Platform = .ios,
        android: AndroidProject? = nil
    ) {
        self.scheme = scheme
        self.workspace = workspace
        self.project = project
        self.simulator = simulator
        self.bundleId = bundleId
        self.buildSettings = buildSettings
        self.screens = screens
        self.flows = flows
        self.diff = diff
        self.a11y = a11y
        self.platform = platform
        self.android = android
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheme = try container.decodeIfPresent(String.self, forKey: .scheme)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        simulator = try container.decodeIfPresent(String.self, forKey: .simulator)
        bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId)
        buildSettings = try container.decodeIfPresent([String].self, forKey: .buildSettings)
        screens = try container.decodeIfPresent([Screen].self, forKey: .screens) ?? []
        flows = try container.decodeIfPresent([String].self, forKey: .flows) ?? []
        diff = try container.decodeIfPresent(DiffConfig.self, forKey: .diff) ?? .init()
        a11y = try container.decodeIfPresent(A11yConfig.self, forKey: .a11y) ?? .init()
        platform = try container.decodeIfPresent(Platform.self, forKey: .platform) ?? .ios
        android = nil
    }

    public static func load(
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> GrantivaConfig {
        try load(platform: .ios, from: directory)
    }

    /// Loads the config file for `platform`, or throws `configNotFound`.
    /// A file that exists but does not parse is an error carrying the file
    /// name and the YAML diagnostic; it never falls through.
    public static func load(
        platform: Platform,
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> GrantivaConfig {
        guard let config = try loadIfPresent(platform: platform, from: directory) else {
            throw GrantivaError.configNotFound
        }
        return config
    }

    /// What a command that needs the config file says when there is none:
    /// the file, where it was looked for, and how to create it.
    public static func missingFileMessage(platform: Platform, directory: URL) -> String {
        let path = directory.appendingPathComponent(platform.configFileName).path
        let initCommand = platform == .ios ? "grantiva init" : "grantiva init --platform \(platform.rawValue)"
        return "\(platform.configFileName) not found at \(path). Create one with \(initCommand)."
    }

    /// Like `load(platform:from:)` but returns nil when no file exists.
    /// `includeMaestroDirectory: false` skips the `.maestro/` fallback, for a
    /// run that names its own flow and must not parse unrelated files.
    public static func loadIfPresent(
        platform: Platform,
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        includeMaestroDirectory: Bool = true,
        emitWarnings: Bool = true
    ) throws -> GrantivaConfig? {
        let fm = FileManager.default
        let configURL = directory.appendingPathComponent(platform.configFileName)

        if fm.fileExists(atPath: configURL.path) {
            let contents = try String(contentsOf: configURL, encoding: .utf8)
            let config = try parse(contents, platform: platform, fileName: platform.configFileName, directory: directory)
            if emitWarnings {
                for warning in config.warnings {
                    GrantivaLog.logger.warning("\(warning)")
                }
            }
            return config
        }

        // The .maestro/ fallback is an iOS-era convention; Android has none.
        guard platform == .ios, includeMaestroDirectory else { return nil }
        // An Android-only directory (grantiva-android.yml or Gradle, no Xcode
        // project) keeps Android flows in .maestro/; their appId is not an
        // iOS bundle ID.
        let resolver = PlatformResolver(directory: directory)
        let detected = resolver.detectFromDirectory()
        if !detected.contains(.ios), resolver.existingConfigFiles().contains(.android) || detected.contains(.android) {
            return nil
        }
        let maestroDir = directory.appendingPathComponent(".maestro")
        if fm.fileExists(atPath: maestroDir.path) {
            return try MaestroFlowParser.loadDirectory(maestroDir)
        }
        return nil
    }

    static func parse(_ contents: String, platform: Platform, fileName: String, directory: URL? = nil) throws -> GrantivaConfig {
        // An empty, whitespace-only, or comments-only file has no YAML
        // document; treat it as "all defaults". Only the first document is
        // read, since Maestro-format files carry several (`Yams.load` throws
        // on a multi-document stream).
        let firstDocument: Node?
        do {
            firstDocument = try Parser(yaml: contents).nextRoot()
        } catch {
            throw GrantivaError.configuration("\(fileName) could not be parsed: \(error)")
        }
        if firstDocument == nil {
            return GrantivaConfig(platform: platform, android: platform == .android ? AndroidProject() : nil)
        }
        // Both platforms read the Maestro form. On Android the header's
        // `appId:` is the application ID and the Gradle side takes its
        // defaults (module `app`, variant `debug`).
        if MaestroFlowParser.isMaestroFormat(contents) {
            do {
                var config = try MaestroFlowParser.parse(contents, sourceName: fileName, baseDirectory: directory)
                config.platform = platform
                if platform == .android {
                    config.android = AndroidProject(applicationId: config.bundleId)
                }
                return config
            } catch let error as GrantivaError {
                // Already names the file and line.
                throw error
            } catch {
                throw GrantivaError.configuration("\(fileName) could not be parsed: \(error)")
            }
        }
        // Unknown keys are dropped by the decoder; report them, and fold them
        // into a decoding error since a misspelled key is often its cause.
        let unknownKeys = firstDocument.map {
            ConfigKeyValidator.unknownKeys(in: $0, platform: platform, fileName: fileName)
        } ?? []
        let warnings = unknownKeys.map(\.message)
        var config: GrantivaConfig
        do {
            config = try YAMLDecoder().decode(GrantivaConfig.self, from: contents)
        } catch {
            // A plain config error naming the file, line and key (L42-b).
            throw GrantivaError.configuration(ConfigDecodingErrorRenderer.message(
                for: error, root: firstDocument, fileName: fileName, unknownKeys: unknownKeys,
                decodeOutsideScreens: { node in
                    _ = try YAMLDecoder().decode(GrantivaConfig.self, from: node)
                    if platform == .android { _ = try YAMLDecoder().decode(AndroidProject.self, from: node) }
                }
            ))
        }
        config.warnings = warnings
        if let declared = (try? YAMLDecoder().decode(DeclaredPlatform.self, from: contents))?.platform,
           declared != platform {
            throw GrantivaError.invalidArgument(
                "\(fileName) declares `platform: \(declared.rawValue)` but it is the \(platform.displayName) config file."
            )
        }
        try validateSwipeDirections(config.screens, fileName: fileName)
        config.platform = platform
        if platform == .android {
            do {
                config.android = try YAMLDecoder().decode(AndroidProject.self, from: contents)
            } catch {
                throw GrantivaError.configuration(ConfigDecodingErrorRenderer.message(
                    for: error, root: firstDocument, fileName: fileName, unknownKeys: unknownKeys
                ))
            }
        }
        return config
    }

    /// `swipe:` is a free string in the YAML; an unknown direction must fail
    /// here, before any device work, not when the runner reaches the step.
    static func validateSwipeDirections(_ screens: [Screen], fileName: String) throws {
        for screen in screens {
            guard case .steps(let steps) = screen.path else { continue }
            for direction in steps.compactMap(\.swipe)
            where !Screen.Step.swipeDirectionNames.contains(direction.lowercased()) {
                throw GrantivaError.invalidArgument(
                    "\(fileName): screen \"\(screen.name)\": swipe direction \"\(direction)\" is not one of "
                        + Screen.Step.swipeDirectionNames.joined(separator: ", ")
                )
            }
        }
    }

    private struct DeclaredPlatform: Decodable {
        var platform: Platform?
    }
}

// MARK: - Screen Helpers

extension Array where Element == GrantivaConfig.Screen {
    /// True if any screen requires navigation steps (taps/swipes) to reach.
    public var hasNavigationSteps: Bool {
        contains { screen in
            if case .steps(let steps) = screen.path, !steps.isEmpty {
                return true
            }
            return false
        }
    }
}

// MARK: - ScreenPath Codable

extension GrantivaConfig.ScreenPath: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self), str == "launch" {
            self = .launch
        } else {
            let steps = try container.decode([GrantivaConfig.Screen.Step].self)
            self = .steps(steps)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .launch:
            try container.encode("launch")
        case .steps(let steps):
            try container.encode(steps)
        }
    }
}
