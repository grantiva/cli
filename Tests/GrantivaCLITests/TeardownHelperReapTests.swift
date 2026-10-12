import Darwin
import Foundation
import XCTest
@testable import GrantivaCLI
import GrantivaCore

/// L63: tearing down a simulator whose foreground `runner start` is mid-run
/// ends the `simctl diagnose` WebDriverAgent's interrupted xcodebuild starts,
/// before the device home is removed, so the home stays removed.
final class TeardownHelperReapTests: XCTestCase {
    private let udid = "6E3A1C63-0B2D-4E8F-9A63-63C0FFEE0063"
    private var base: URL!
    private let started = TeardownReapBox<[Process]>([])

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-l63-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    override func tearDown() {
        // Only the processes this test started.
        for process in started.value where process.isRunning { kill(process.processIdentifier, SIGKILL) }
        try? FileManager.default.removeItem(at: base)
    }

    private var home: String { "\(base.path)/versions/1.1.28-grantiva.13/devices/\(udid)" }

    /// A stand-in for the diagnose xcodebuild starts when the runner's group
    /// is signalled: its command line is diagnose's (it names the device and
    /// writes under the device home), it ignores SIGINT, and after a moment
    /// it writes into the device home, re-creating a removed one.
    private static func startFakeDiagnose(home: String, udid: String, runnerPid: Int32, started: TeardownReapBox<[Process]>) throws -> Process {
        let output = "\(home)/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8-r1/devices/\(udid)/run-\(runnerPid)-1791790261185038000/attempt-1.xcresult/Staging/1_Test/Diagnostics/simctl_diagnostics"
        let script = ": simctl diagnose -l -b --timeout=600 --output=\(output) --no-archive --udid=\(udid); "
            + "trap '' INT; sleep 0.4; while :; do mkdir -p '\(output)'; : > '\(output)/log'; sleep 0.05; done"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        started.value.append(process)
        return process
    }

    func testTeardownReapsTheDiagnoseTheStoppedRunStartedBeforeRemovingTheDeviceHome() async throws {
        try FileManager.default.createDirectory(atPath: "\(home)/cache/wda-builds", withIntermediateDirectories: true)
        let runnerPid: Int32 = 4242
        let diagnose = TeardownReapBox<Process?>(nil)
        var reaper = RunnerHelperReaper.live(runnerBase: base.path)
        reaper.gracePeriod = 0.5
        let helperReaper = reaper
        let sessions = DeviceRunnerSessions(
            loadSession: { nil }, removeSession: {},
            stopSessions: { [home, started] udid, _ in
                // The runner's group is signalled; its interrupted xcodebuild
                // starts simctl diagnose in a group of its own, then exits.
                diagnose.value = try? Self.startFakeDiagnose(home: home, udid: udid, runnerPid: runnerPid, started: started)
                return [.terminated(runnerPid: runnerPid, udid: udid, killed: false)]
            },
            reapHelpers: { await helperReaper.reapDeviceHome(udid: $0) }
        )

        let result = await SimulatorCommand.Teardown.stopRunnerSessions(udids: [udid]) { await sessions.stop(udid: $0) }
        // The teardown removes the device home only after the reap.
        let removal = WDADeviceHome.removeAll(runnerBase: base.path, deviceID: udid)

        let pid = try XCTUnwrap(diagnose.value?.processIdentifier)
        XCTAssertEqual(result.stopped, [udid])
        XCTAssertEqual(result.reaped[udid]?.map(\.pid), [pid])
        XCTAssertEqual(result.reaped[udid]?.map(\.kind), [.diagnose])
        XCTAssertEqual(result.reaped[udid]?.map(\.killed), [true])
        XCTAssertEqual(result.lines, [
            "Stopped runner session (pid \(runnerPid)) for \(udid).",
            "Also stopped diagnose pid \(pid), which the runner left running for \(udid).",
        ])
        XCTAssertEqual(removal.removed, [home])
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertFalse(KeepAliveSessionStore.processIsAlive(pid), "the diagnose outlived the teardown")
        XCTAssertFalse(FileManager.default.fileExists(atPath: home), "the device home came back")

        // Nothing is left for the leftover check to warn about.
        let leftovers = SimulatorCommand.Teardown.leftoverProcesses(
            udids: [udid], psOutput: (try? await SimulatorReaper.processSnapshot()) ?? "", excludingPID: getpid()
        )
        XCTAssertEqual(leftovers[udid] ?? [], [])
        let outcome = SimulatorTeardownOutcome(udid: udid, session: nil, deleted: true)
        let marked = SimulatorCommand.Teardown.marking([outcome], stopped: result.stopped, leftovers: leftovers, reaped: result.reaped)
        XCTAssertEqual(marked.first?.reapedProcesses.map(\.pid), [pid])
        XCTAssertEqual(marked.first?.leftoverProcesses, [])
    }

    /// A diagnose for another device, or one writing outside this runner
    /// home, is not the teardown's: it stays, and the leftover check names it.
    func testTeardownLeavesHelpersOutsideTheDeviceHomeAlone() async throws {
        let signals = TeardownReapBox<[Int32]>([])
        let other = "/Users/someone/elsewhere/devices/\(udid)/run-1-1/x"
        let table = [
            "500     1   500 /usr/bin/xcrun simctl diagnose --udid=\(udid) --no-archive",
            "501     1   501 /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl diagnose --output=\(other) --udid=\(udid)",
            "502     1   502 /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl diagnose --output=\(base.path)/versions/1/devices/DEAD-BEEF/x --udid=DEAD-BEEF",
            "503     1   503 /bin/zsh -c grantiva simulator ensure && echo \(base.path)/versions/1/devices/\(udid)",
        ].joined(separator: "\n")
        let reaper = RunnerHelperReaper(
            snapshot: { table }, signal: { pid, _ in signals.value.append(pid) }, isAlive: { _ in true },
            runnerBases: [base.path], gracePeriod: 0.1, pollInterval: .milliseconds(10)
        )
        let reaped = await reaper.reapDeviceHome(udid: udid)
        XCTAssertEqual(reaped, [])
        XCTAssertEqual(signals.value, [])
    }

    /// Android serials have no WebDriverAgent helpers; nothing is reaped, and
    /// a teardown that stopped no runner reaps nothing either.
    func testTheReapRunsOnlyAfterTheTeardownStoppedASimulatorRunner() async {
        let calls = TeardownReapBox<[String]>([])
        let sessions = DeviceRunnerSessions(
            loadSession: { nil }, removeSession: {},
            stopSessions: { udid, _ in udid == "emulator-5554" ? [.terminated(runnerPid: 9, udid: udid, killed: false)] : [] },
            reapHelpers: { calls.value.append($0); return [] }
        )
        _ = await sessions.stop(udid: "emulator-5554")
        _ = await sessions.stop(udid: udid)
        XCTAssertEqual(calls.value, [])
    }
}

final class TeardownReapBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    var value: Value {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}
