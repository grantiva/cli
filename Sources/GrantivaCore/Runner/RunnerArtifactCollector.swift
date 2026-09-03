import Foundation

/// Collects screenshots using the runner's report index as the source of truth.
/// Physical directory enumeration is deliberately avoided: a preserved report
/// directory can contain unrelated entries, and directory order does not encode
/// flow order.
enum RunnerArtifactCollector {
    struct AttributedFlow {
        let index: Int
        let id: String
        let sourceFile: String
        let assetsURL: URL
        let userName: String
    }

    private struct Report: Decodable {
        let flows: [Flow]
    }

    private struct Flow: Decodable {
        let index: Int
        let id: String
        let name: String
        let sourceFile: String
        let assetsDir: String
    }

    static func collect(
        reportDir: String,
        outputDir: String,
        requestedFlowPaths: [String],
        stagedPathMap: [String: String]
    ) throws -> [ScreenCapture] {
        let fileManager = FileManager.default
        let attributedFlows = try attributedFlows(
            reportDir: reportDir,
            requestedFlowPaths: requestedFlowPaths,
            stagedPathMap: stagedPathMap
        )

        var captures: [ScreenCapture] = []
        var assignedDestinations: Set<String> = []

        try fileManager.createDirectory(
            at: URL(fileURLWithPath: outputDir, isDirectory: true),
            withIntermediateDirectories: true
        )

        for flow in attributedFlows {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: flow.assetsURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let screenshotFiles = try fileManager.contentsOfDirectory(atPath: flow.assetsURL.path)
                .filter { $0.lowercased().hasSuffix(".png") }
                .sorted()

            for file in screenshotFiles {
                let sourceURL = try confinedURL(
                    relativePath: file,
                    beneath: flow.assetsURL,
                    description: "screenshot for \(flow.id)"
                )
                let artifactName = sourceURL.deletingPathExtension().lastPathComponent
                let screenshotName = "\(flow.userName)-\(artifactName)"
                let destinationURL = URL(fileURLWithPath: outputDir, isDirectory: true)
                    .appendingPathComponent("\(screenshotName).png")
                    .standardizedFileURL

                guard assignedDestinations.insert(destinationURL.path).inserted else {
                    throw invalidReport("multiple artifacts resolve to \(destinationURL.lastPathComponent)")
                }
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                let data = try Data(contentsOf: destinationURL)
                captures.append(ScreenCapture(
                    screenName: screenshotName,
                    path: destinationURL.path,
                    sizeBytes: data.count,
                    steps: [
                        StepResult(
                            action: "Run flow \"\(flow.userName)\"",
                            status: .passed,
                            duration: 0
                        ),
                    ]
                ))
            }
        }

        return captures
    }

    static func attributedFlows(
        reportDir: String,
        requestedFlowPaths: [String],
        stagedPathMap: [String: String]
    ) throws -> [AttributedFlow] {
        let reportURL = URL(fileURLWithPath: reportDir, isDirectory: true).standardizedFileURL
        let reportFile = reportURL.appendingPathComponent("report.json")
        let report: Report
        do {
            report = try JSONDecoder().decode(Report.self, from: Data(contentsOf: reportFile))
        } catch {
            throw GrantivaError.commandFailed("Could not read runner artifact index: \(error)", 1)
        }
        return try attributedFlows(
            reportDir: reportDir,
            requestedFlowPaths: requestedFlowPaths,
            stagedPathMap: stagedPathMap,
            report: report
        )
    }

    static func artifactURL(named name: String, in flow: AttributedFlow) throws -> URL {
        try confinedURL(
            relativePath: name,
            beneath: flow.assetsURL,
            description: "artifact for \(flow.id)"
        )
    }

    private static func attributedFlows(
        reportDir: String,
        requestedFlowPaths: [String],
        stagedPathMap: [String: String],
        report: Report
    ) throws -> [AttributedFlow] {
        let reportURL = URL(fileURLWithPath: reportDir, isDirectory: true).standardizedFileURL
        guard report.flows.count == requestedFlowPaths.count else {
            throw invalidReport(
                "expected \(requestedFlowPaths.count) flows, found \(report.flows.count)"
            )
        }

        let orderedFlows = report.flows.sorted { $0.index < $1.index }
        guard orderedFlows.map(\.index) == Array(requestedFlowPaths.indices) else {
            throw invalidReport("flow indices are missing, duplicated, or out of range")
        }
        guard Set(orderedFlows.map(\.id)).count == orderedFlows.count,
              orderedFlows.allSatisfy({ !$0.id.isEmpty }) else {
            throw invalidReport("flow IDs are empty or duplicated")
        }
        guard Set(orderedFlows.map(\.assetsDir)).count == orderedFlows.count else {
            throw invalidReport("asset directories are duplicated")
        }

        let baseNames = requestedFlowPaths.map(flowBaseName)
        let nameCounts = Dictionary(grouping: baseNames, by: nameKey).mapValues(\.count)
        // Preserve established names for unique basenames. Duplicate names get
        // the first available numeric suffix, skipping names already claimed
        // by another requested flow (for example login-1.yaml alongside two
        // flows named login.yaml).
        let reservedNames = Set(baseNames.filter { nameCounts[nameKey($0)] == 1 }.map(nameKey))
        var nextSuffix: [String: Int] = [:]
        var assignedFlowNames: Set<String> = []
        var assignedAssetDirectories: Set<String> = []
        var attributed: [AttributedFlow] = []

        for flow in orderedFlows {
            let expectedPath = requestedFlowPaths[flow.index]
            guard let attributedPath = stagedPathMap[flow.sourceFile],
                  attributedPath == expectedPath else {
                throw invalidReport(
                    "flow \(flow.id) source does not match requested flow at index \(flow.index)"
                )
            }

            let baseName = baseNames[flow.index]
            let baseKey = nameKey(baseName)
            let flowName: String
            if nameCounts[baseKey] == 1 {
                flowName = baseName
                assignedFlowNames.insert(baseKey)
            } else {
                var suffix = nextSuffix[baseKey, default: 1]
                var candidate = "\(baseName)-\(suffix)"
                while reservedNames.contains(nameKey(candidate))
                        || assignedFlowNames.contains(nameKey(candidate)) {
                    suffix += 1
                    candidate = "\(baseName)-\(suffix)"
                }
                nextSuffix[baseKey] = suffix + 1
                assignedFlowNames.insert(nameKey(candidate))
                flowName = candidate
            }

            let assetsURL = try confinedURL(
                relativePath: flow.assetsDir,
                beneath: reportURL,
                description: "asset directory for \(flow.id)"
            )
            guard assignedAssetDirectories.insert(assetsURL.path).inserted else {
                throw invalidReport("asset directories resolve to the same location")
            }
            attributed.append(AttributedFlow(
                index: flow.index,
                id: flow.id,
                sourceFile: flow.sourceFile,
                assetsURL: assetsURL,
                userName: flowName
            ))
        }
        return attributed
    }

    private static func flowBaseName(_ path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    private static func nameKey(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.lowercased()
    }

    private static func confinedURL(
        relativePath: String,
        beneath root: URL,
        description: String
    ) throws -> URL {
        guard !relativePath.isEmpty, !NSString(string: relativePath).isAbsolutePath else {
            throw invalidReport("\(description) is not a relative path")
        }

        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let candidate = root.appendingPathComponent(relativePath)
            .resolvingSymlinksInPath().standardizedFileURL
        let rootPrefix = resolvedRoot.path.hasSuffix("/")
            ? resolvedRoot.path
            : resolvedRoot.path + "/"
        guard candidate.path.hasPrefix(rootPrefix) else {
            throw invalidReport("\(description) escapes the report directory")
        }
        return candidate
    }

    private static func invalidReport(_ reason: String) -> GrantivaError {
        .commandFailed("Invalid runner artifact index: \(reason)", 1)
    }
}
