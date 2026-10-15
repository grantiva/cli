import ArgumentParser
import Foundation
import GrantivaCore

struct EmulatorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "emulator",
        abstract: "Provision, inspect, and tear down Android emulators.",
        subcommands: [Ensure.self, Delete.self, Sessions.self, Teardown.self]
    )

    struct Ensure: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create the AVD when missing (installing its system image first) and boot it. stdout is the serial, or with --no-boot the AVD name (the serial when it is already running)."
        )
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "AVD name. Defaults to emulator in grantiva-android.yml.")
        var name: String?

        @Option(name: .long, help: "System image package for a new AVD, e.g. \"system-images;android-35;google_apis;arm64-v8a\". Defaults to system_image in grantiva-android.yml, then that value.")
        var systemImage: String?

        @Flag(inversion: .prefixedNo, help: "Boot the emulator and wait for it to be ready. On by default; --no-boot creates it without booting.")
        var boot = true

        @Flag(name: .long, help: "Boot without a window. GRANTIVA_EMULATOR_HEADLESS=1 or CI=true does the same; otherwise the emulator gets a window, even when stdout is not a terminal.")
        var headless = false

        static func resolveName(flag: String?, config: GrantivaConfig?) throws -> String {
            guard let name = flag ?? config?.android?.emulator, !name.isEmpty else {
                throw GrantivaError.invalidArgument("No AVD named. Pass --name or set emulator in grantiva-android.yml.")
            }
            return name
        }

        /// stdout is the identifier a script captures:
        ///
        ///     serial=$(grantiva emulator ensure --name Pixel_8_API_35)
        ///
        /// The prose goes to the log (stderr), as `simulator ensure` does.
        static func render(_ result: EmulatorProvisionResult) -> (stdout: String, stderr: String) {
            let verb = result.created ? "Created" : "Reused"
            let serial = result.serial.map { " (\($0))" } ?? ""
            return (stdout: result.serial ?? result.name, stderr: "\(verb) \(result.name)\(serial) — \(result.state)")
        }

        func run() async throws {
            let config = try GrantivaConfig.loadIfPresent(platform: .android)
            let avd = try Self.resolveName(flag: name, config: config)
            let platform = try AndroidPlatform.live(options: .init(headless: headless))
            let result = try await platform.emulators.ensure(avd: avd, systemImage: systemImage ?? config?.android?.systemImage, boot: boot)
            if options.json {
                Output.line(try JSONOutput.string(result))
                return
            }
            let rendered = Self.render(result)
            GrantivaLog.logger.info("\(rendered.stderr)")
            Output.line(rendered.stdout)
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete an AVD Grantiva created. Others need --force. A running AVD is never deleted.")
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "AVD name to delete.")
        var name: String

        @Flag(name: .long, help: "Delete an AVD Grantiva did not create.")
        var force = false

        static func renderJSON(name: String) throws -> String {
            try JSONOutput.string(EmulatorDeleteResult(name: name, deleted: true))
        }

        func run() async throws {
            let platform = try AndroidPlatform.live()
            try await platform.emulators.deleteAVD(name: name, force: force)
            if options.json {
                Output.line(try Self.renderJSON(name: name))
            } else {
                Output.line("Deleted AVD \(name)")
            }
        }
    }

    struct Sessions: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List the emulators Grantiva started.")
        @OptionGroup var options: GlobalOptions

        static func render(_ sessions: [EmulatorSessionRecord]) -> [String] {
            guard !sessions.isEmpty else { return ["No emulators started by Grantiva are running."] }
            return ["Grantiva-started emulators (\(sessions.count)):"] + sessions.map {
                "  \($0.serial) (\($0.avd)) — pid \($0.pid) \($0.processAlive ? "running" : "exited"), adb: \($0.adbState)"
            }
        }

        /// The live sessions, then housekeeping: forget created AVDs that
        /// are gone from disk.
        static func sessions(_ emulators: EmulatorManager) async throws -> [EmulatorSessionRecord] {
            let sessions = try await emulators.sessions()
            _ = try? await emulators.pruneCreatedAVDs()
            return sessions
        }

        func run() async throws {
            let sessions = try await Self.sessions(AndroidPlatform.live().emulators)
            if options.json {
                Output.line(try JSONOutput.string(sessions))
            } else {
                Self.render(sessions).forEach(Output.line)
            }
        }
    }

    struct Teardown: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Kill emulators Grantiva started: one by serial, or all of them. Stops the UIAutomator2 server and removes the serial's adb forwards first.",
            discussion: "A runner session on a torn-down serial (`grantiva runner start` or `grantiva run --keep-alive`) is stopped too, and its session files are removed; --json reports it as runnerSessionStopped. The guest's writes are flushed (`adb shell sync`) before the emulator is killed, so an app installed just before survives the next boot. Session files of a runner that had already died, and the temp directories of every killed run on the serial, are removed and listed (sessionFilesRemoved, temporaryDirectoriesRemoved)."
        )
        @OptionGroup var options: GlobalOptions

        @Option(name: .long, help: "Emulator serial to kill, e.g. emulator-5554.")
        var serial: String?

        @Flag(name: .long, help: "Kill every emulator Grantiva started.")
        var all = false

        @Flag(name: .long, help: "Kill the serial even though Grantiva did not start it.")
        var force = false

        /// One serial, or every recorded emulator when `serial` is nil. Then
        /// housekeeping: forget created AVDs that are gone from disk. The AVDs
        /// just stopped stay recorded, so `emulator delete` still knows
        /// Grantiva created them.
        /// `stopRunners` stops the runner sessions on one serial (nil: leave
        /// them, for callers that only want the emulator bookkeeping).
        static func teardown(
            _ emulators: EmulatorManager, serial: String?, force: Bool,
            stopRunners: (@Sendable (String) async -> [RunnerSessionStopper.Outcome])? = nil,
            removeDeadSessions: (@Sendable (String) -> [String])? = nil,
            markStops: (@Sendable (String) -> [Int32])? = nil,
            unmarkStops: (@Sendable ([Int32]) -> Void)? = nil,
            sweepStops: (@Sendable () -> Void)? = nil,
            waitForExit: @escaping @Sendable (Int32) async -> Bool = { await DeviceRunnerSessions.waitForExit($0) }
        ) async throws -> [EmulatorTeardownOutcome] {
            // However the teardown ends, markers nobody will read go.
            defer { sweepStops?() }
            // Runners on the serials die with their emulator, before
            // `stopRunners` gets to them: mark them first so a foreground
            // `runner start` holding one ends in order (L36). A serial that
            // is refused or not torn down gets its markers back.
            var marked: [String: [Int32]] = [:]
            if let markStops {
                var serials: [String] = []
                if let serial {
                    serials = [serial]
                } else {
                    serials = (try? await emulators.sessions())?.map(\.serial) ?? []
                }
                for target in serials { marked[target] = markStops(target) }
            }
            // The prune runs on a refusal too (`defer` cannot await).
            var outcomes: [EmulatorTeardownOutcome]
            do {
                outcomes = if let serial {
                    [try await emulators.teardown(serial: serial, force: force)]
                } else {
                    try await emulators.teardownAll()
                }
            } catch {
                let all = marked.values.flatMap { $0 }
                if !all.isEmpty { unmarkStops?(all) }
                _ = try? await emulators.pruneCreatedAVDs()
                throw error
            }
            let tornDown = Set(outcomes.map(\.serial))
            let untouched = marked.filter { !tornDown.contains($0.key) }.values.flatMap { $0 }
            if !untouched.isEmpty { unmarkStops?(untouched) }
            _ = try? await emulators.pruneCreatedAVDs()
            // After the kill, so a refused teardown touches nothing; the
            // runner's own adb cleanup has nothing left to do by then.
            // A runner marked above counts as stopped by this teardown even
            // when it was gone before `stopRunners` got to it (it died with
            // its emulator, or its `runner start` read the marker, L54), but
            // only once it has exited (bounded wait), as on a simulator.
            if let stopRunners {
                for index in outcomes.indices {
                    let serial = outcomes[index].serial
                    let stopped = await stopRunners(serial)
                    var markedGone = false
                    for pid in marked[serial] ?? [] where !stopped.contains(where: { $0.runnerPid == pid }) {
                        if await waitForExit(pid) { markedGone = true }
                    }
                    outcomes[index].runnerSessionStopped = !stopped.isEmpty || markedGone
                }
            }
            // A runner that died on its own left its session file (L12).
            if let removeDeadSessions {
                for index in outcomes.indices {
                    outcomes[index].sessionFilesRemoved = removeDeadSessions(outcomes[index].serial)
                }
            }
            return outcomes
        }

        /// What the teardown cleaned up besides the emulator, one line each.
        static func cleanupLines(_ outcome: EmulatorTeardownOutcome) -> [String] {
            var lines: [String] = []
            if !outcome.sessionFilesRemoved.isEmpty {
                lines.append("Removed \(outcome.sessionFilesRemoved.count) stale keep-alive session file(s) of runners that are no longer running.")
            }
            for directory in outcome.temporaryDirectoriesRemoved {
                lines.append("Removed the killed run's temp directory \(directory).")
            }
            return lines
        }

        static func render(_ outcome: EmulatorTeardownOutcome) -> String {
            let name = outcome.avd.map { " (\($0))" } ?? ""
            if outcome.killed { return "Killed \(outcome.serial)\(name)." }
            if outcome.recorded { return "\(outcome.serial)\(name) was already gone; dropped its record." }
            return "\(outcome.serial) is not attached and has no record; nothing to do."
        }

        func validate() throws {
            switch (serial, all) {
            case (nil, false):
                throw ValidationError("Pass --serial <serial> or --all.")
            case (.some, true):
                throw ValidationError(ExclusiveFlags.message("--serial", "--all"))
            default:
                break
            }
            if let serial {
                try usageCheck {
                    let trimmed = try DeviceID.validate(serial, flag: "--serial")
                    guard DeviceID.isAndroidSerial(trimmed) else {
                        throw GrantivaError.invalidArgument("--serial \(trimmed) is a simulator UDID, not an emulator serial. Use `grantiva simulator teardown` for simulators.")
                    }
                }
            }
        }

        func run() async throws {
            let json = options.json
            let outcomes = try await Self.teardown(
                AndroidPlatform.live().emulators,
                serial: serial?.trimmingCharacters(in: .whitespacesAndNewlines), force: force,
                stopRunners: { serial in
                    let stopped = await DeviceRunnerSessions.live.stop(udid: serial)
                    if !json { stopped.map(DeviceRunnerSessions.render).forEach(Output.line) }
                    return stopped
                },
                removeDeadSessions: { KeepAliveSessionStore().removeSessions(udid: $0) },
                markStops: { DeviceRunnerSessions.markLive(udid: $0) },
                unmarkStops: { pids in pids.forEach { RunnerStopMarker().remove(runnerPid: $0) } },
                sweepStops: { RunnerStopMarker().sweep() }
            )
            if options.json {
                Output.line(try JSONOutput.string(outcomes))
            } else if outcomes.isEmpty {
                Output.line("No emulators started by Grantiva are running.")
            } else {
                outcomes.flatMap { [Self.render($0)] + Self.cleanupLines($0) }.forEach(Output.line)
            }
        }
    }
}

/// `emulator delete --json`.
struct EmulatorDeleteResult: Codable, Equatable {
    let name: String
    let deleted: Bool
}
