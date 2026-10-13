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

    private var home: String { "\(base.path)/versions/1.1.28-grantiva.14/devices/\(udid)" }

    /// A stand-in for the diagnose xcodebuild starts when the runner's group
    /// is signalled: its command line is diagnose's (it names the device and
    /// writes under the device home), it ignores SIGINT, SIGTERM and SIGHUP,
    /// and 30 ms in it writes into the device home every 10 ms, re-creating a
    /// removed one. Only zsh builtins write and wait, so no child of its
    /// outlives it.
    private static func startFakeDiagnose(home: String, udid: String, runnerPid: Int32, started: TeardownReapBox<[Process]>) throws -> Process {
        let output = "\(home)/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8-r1/devices/\(udid)/run-\(runnerPid)-1791790261185038000/attempt-1.xcresult/Staging/1_Test/Diagnostics/simctl_diagnostics"
        let script = "zmodload zsh/files zsh/zselect; "
            + ": simctl diagnose -l -b --timeout=600 --output=\(output) --no-archive --udid=\(udid); "
            + "trap '' INT TERM HUP; zselect -t 3; while :; do mkdir -p '\(output)'; print > '\(output)/log'; zselect -t 1; done"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-fc", script]
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
        reaper.gracePeriod = 0.1
        reaper.pollInterval = .milliseconds(10)
        let helperReaper = reaper
        let sessions = DeviceRunnerSessions(
            loadSession: { nil }, removeSession: {},
            stopSessions: { [home, started] udid, _, _ in
                // The runner's group is signalled; its interrupted xcodebuild
                // starts simctl diagnose in a group of its own, then exits.
                diagnose.value = try? Self.startFakeDiagnose(home: home, udid: udid, runnerPid: runnerPid, started: started)
                return [.terminated(runnerPid: runnerPid, udid: udid, killed: false)]
            },
            reapHelpers: { udid, deadline in
                var reaper = helperReaper
                reaper.deadline = deadline
                return await reaper.reapDeviceHome(udid: udid)
            }
        )

        let result = await SimulatorCommand.Teardown.stopRunnerSessions(udids: [udid]) { await sessions.stop(udid: $0) }
        // The teardown removes the device home only after the reap.
        let removal = WDADeviceHome.removeAll(runnerBase: base.path, deviceID: udid)

        let pid = try XCTUnwrap(diagnose.value?.processIdentifier)
        XCTAssertEqual(removal.removed, [home])
        // Ten of the fake's write intervals, then the two checks that matter
        // first: XCTest may end an async test soon after its first failure.
        usleep(100_000)
        XCTAssertFalse(KeepAliveSessionStore.processIsAlive(pid), "the diagnose outlived the teardown")
        XCTAssertFalse(FileManager.default.fileExists(atPath: home), "the device home came back")

        XCTAssertEqual(result.stopped, [udid])
        XCTAssertEqual(result.reaped[udid]?.map(\.pid), [pid])
        XCTAssertEqual(result.reaped[udid]?.map(\.kind), [.diagnose])
        XCTAssertEqual(result.reaped[udid]?.map(\.killed), [true])
        XCTAssertEqual(result.lines, [
            "Stopped runner session (pid \(runnerPid)) for \(udid).",
            "Also stopped diagnose pid \(pid), which the runner left running for \(udid).",
        ])

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

    private func row(_ pid: Int32, _ command: String) -> String { "\(pid)     1   \(pid) \(command)" }
    private var xcodebuild: String {
        "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -xctestrun \(home)/run-1-1/Products/WDA.xctestrun -destination platform=iOS Simulator,id=\(udid)"
    }
    private var diagnoseCommand: String {
        "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl diagnose --output=\(home)/run-1-1/attempt-1.xcresult --udid=\(udid)"
    }

    /// The run's xcodebuild takes SIGKILL at once (SIGINT is what makes it
    /// start a diagnose); a diagnose found in the first round gets SIGINT
    /// first; one found in a later round takes SIGKILL at once.
    func testXcodebuildAndLaterRoundsTakeSIGKILLAtOnce() async {
        let table = TeardownReapBox("\(row(600, xcodebuild))\n\(row(601, diagnoseCommand))")
        let alive = TeardownReapBox<Set<Int32>>([600, 601])
        let signals = TeardownReapBox<[String]>([])
        let second = row(602, diagnoseCommand.replacingOccurrences(of: "--udid", with: "-b --udid"))
        let reaper = RunnerHelperReaper(
            snapshot: { table.value },
            signal: { pid, sig in
                signals.value.append("\(sig == SIGKILL ? "KILL" : sig == SIGINT ? "INT" : "\(sig)") \(pid)")
                // The killed xcodebuild had already started a second diagnose.
                if abs(pid) == 600 { table.value = second }
                if sig == SIGKILL || sig == SIGINT { alive.value.remove(abs(pid)); if pid == 600 { alive.value.insert(602) } }
            },
            isAlive: { alive.value.contains($0) },
            runnerBases: [base.path], gracePeriod: 0.05, pollInterval: .milliseconds(5)
        )
        let reaped = await reaper.reapDeviceHome(udid: udid)
        XCTAssertEqual(reaped.map(\.pid), [600, 601, 602])
        XCTAssertEqual(reaped.map(\.killed), [true, true, true])
        XCTAssertEqual(signals.value.filter { $0.hasSuffix(" 600") || $0.hasSuffix(" -600") }.first, "KILL 600")
        XCTAssertFalse(signals.value.contains("INT 600"), "\(signals.value)")
        XCTAssertTrue(signals.value.contains("INT 601"), "\(signals.value)")
        XCTAssertFalse(signals.value.contains("INT 602"), "\(signals.value)")
        XCTAssertTrue(signals.value.contains("KILL 602"), "\(signals.value)")
    }

    /// The stopper's lineage reap, in a teardown, SIGKILLs the stopped run's
    /// xcodebuild at once; `runner stop` (the default) still sends SIGINT.
    func testATeardownsLineageReapSIGKILLsTheRunsXcodebuild() async {
        let runner = "100     1   100 \(base.path)/versions/1/grantiva-runner --platform ios --device \(udid) server"
        let child = "101   100   100 \(xcodebuild)"
        let orphan = "101     1   100 \(xcodebuild)"
        for teardown in [true, false] {
            let table = TeardownReapBox("\(runner)\n\(child)")
            let alive = TeardownReapBox<Set<Int32>>([101])
            let signals = TeardownReapBox<[String]>([])
            var reaper = RunnerHelperReaper(
                snapshot: { table.value },
                signal: { pid, sig in
                    signals.value.append("\(sig == SIGKILL ? "KILL" : sig == SIGINT ? "INT" : "\(sig)") \(pid)")
                    alive.value.remove(abs(pid))
                },
                isAlive: { alive.value.contains($0) },
                runnerBases: [base.path], gracePeriod: 0.05, pollInterval: .milliseconds(5)
            )
            reaper.killsXcodebuildAtOnce = teardown
            let (_, reaped) = await reaper.stopping(runnerPid: 100, udid: udid) { () async -> Int in
                table.value = orphan
                return 0
            }
            XCTAssertEqual(reaped.map(\.pid), [101])
            XCTAssertEqual(signals.value.first, teardown ? "KILL 101" : "INT 101", "teardown \(teardown)")
        }
    }

    /// A helper that ignores every signal (even SIGKILL, as far as the reaper
    /// can tell) does not hold the teardown past its single deadline: the
    /// sessions, the marked runners and the reap share it.
    func testTheTeardownStopEndsByItsDeadlineWhateverAHelperIgnores() async {
        let signals = TeardownReapBox<[String]>([])
        let table = row(700, diagnoseCommand)
        let stubborn = RunnerHelperReaper(
            snapshot: { table },
            signal: { pid, sig in signals.value.append("\(sig == SIGKILL ? "KILL" : sig == SIGINT ? "INT" : "\(sig)") \(pid)") },
            isAlive: { _ in true },
            runnerBases: [base.path], gracePeriod: 3, pollInterval: .milliseconds(10)
        )
        let deadlines = TeardownReapBox<[Date]>([])
        var sessions = DeviceRunnerSessions(
            loadSession: { nil }, removeSession: {},
            stopSessions: { udid, _, deadline in
                deadlines.value.append(deadline)
                return [.terminated(runnerPid: 4242, udid: udid, killed: false)]
            },
            markStops: { _ in [4343] },
            waitForExit: { _, deadline in
                deadlines.value.append(deadline)
                return false
            },
            reapHelpers: { udid, deadline in
                deadlines.value.append(deadline)
                var reaper = stubborn
                reaper.deadline = deadline
                return await reaper.reapDeviceHome(udid: udid)
            }
        )
        sessions.budget = 0.1
        let begin = Date()
        let outcomes = await sessions.stop(udid: udid)
        let elapsed = Date().timeIntervalSince(begin)

        XCTAssertLessThan(elapsed, 0.6, "a 3 s grace and three rounds outlasted the 0.1 s deadline")
        XCTAssertEqual(deadlines.value.count, 3)
        XCTAssertEqual(Set(deadlines.value).count, 1, "every step got the same deadline")
        XCTAssertEqual(outcomes.flatMap(\.reaped).map(\.pid), [700])
        XCTAssertEqual(signals.value.first, "INT 700")
        XCTAssertTrue(signals.value.contains("KILL 700"), "\(signals.value)")
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
            stopSessions: { udid, _, _ in udid == "emulator-5554" ? [.terminated(runnerPid: 9, udid: udid, killed: false)] : [] },
            reapHelpers: { udid, _ in calls.value.append(udid); return [] }
        )
        _ = await sessions.stop(udid: "emulator-5554")
        _ = await sessions.stop(udid: udid)
        XCTAssertEqual(calls.value, [])
    }

    /// A `--udid` typed in lowercase still gets the helpers the stop ended,
    /// with and without `--force`.
    func testReapedHelpersMatchAUdidInAnyCase() async {
        let lower = udid.lowercased()
        let helper = ReapedProcess(pid: 77, processGroup: 77, kind: .diagnose, command: "simctl diagnose", killed: true)
        let result = await SimulatorCommand.Teardown.stopRunnerSessions(udids: [lower]) { udid in
            [.terminated(runnerPid: 5, udid: udid, killed: false, reaped: [helper])]
        }
        let outcome = SimulatorTeardownOutcome(udid: udid, session: nil, deleted: true)
        XCTAssertEqual(SimulatorCommand.Teardown.marking([outcome], stopped: [udid], reaped: result.reaped).first?.reapedProcesses, [helper])
        let lowerOutcome = SimulatorTeardownOutcome(udid: lower, session: nil, deleted: true)
        XCTAssertEqual(SimulatorCommand.Teardown.marking([lowerOutcome], stopped: [lower], reaped: result.reaped).first?.reapedProcesses, [helper])
        let force = ForceTeardownResult(udid: lower, processes: [], leaseReleased: false, capacityRecordsCleared: 0)
        let forced = SimulatorCommand.Teardown.addingReaped(result.reaped, to: [force]).first
        XCTAssertEqual(forced?.reapedProcesses, [helper])
        XCTAssertEqual(forced?.reclaimed, true)
    }

    /// `adding(reaped:)` skips a helper it already lists (same pid and
    /// command), keeps one whose pid was reused by another command.
    func testAddingReapedDeduplicatesByPidAndCommand() {
        let first = ReapedProcess(pid: 9, processGroup: 9, kind: .diagnose, command: "a", killed: true)
        let same = ReapedProcess(pid: 9, processGroup: 9, kind: .diagnose, command: "a", killed: true)
        let reused = ReapedProcess(pid: 9, processGroup: 9, kind: .webDriverAgent, command: "b", killed: true)
        let outcome = RunnerSessionStopper.Outcome.terminated(runnerPid: 1, udid: udid, killed: false, reaped: [first])
        XCTAssertEqual(outcome.adding(reaped: [same, reused]).reaped, [first, reused])
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
