import Darwin
import Foundation
import XCTest
@testable import GrantivaCore

/// L04: `runner stop` ends the device helpers its runner started. Every
/// process here is a fake row; the reaper's signals are recorded, never sent.
final class RunnerHelperReaperTests: XCTestCase {
    private let udid = "AD257930-C4D0-4C0F-9DAA-DAA6C335AF8F"
    private let base = "/tmp/grantiva-l04-tests/runner-home"

    private var runner: String { "100     1   100 \(base)/versions/1.1.28/grantiva-runner --platform ios --device \(udid) --no-ansi server" }
    private var xcodebuild: String { "101   100   100 /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -xctestrun /tmp/wda.xctestrun -destination id=\(udid)" }
    private var orphanedXcodebuild: String { "101     1   100 /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -xctestrun /tmp/wda.xctestrun -destination id=\(udid)" }

    /// The command line the L04 repro captured (pid 4806, parent xcodebuild 4743), with the runner pid 100.
    private func diagnose(pid: Int32 = 102, ppid: Int32, runPid: Int32 = 100, base: String? = nil) -> String {
        "\(pid) \(ppid) \(pid) /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/Resources/bin/simctl diagnose -l -b --timeout=600 --log-option=--last --log-option=2m "
            + "--output=\(base ?? self.base)/versions/1.1.28/devices/\(udid)/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8-r1/devices/\(udid)/run-\(runPid)-1791728323714722000/attempt-1.xcresult/Staging/1_Test/Diagnostics/simctl_diagnostics --no-archive --udid=\(udid)"
    }

    private func reaper(
        table: Locked<String>, signals: Locked<[String]>, alive: Locked<Set<Int32>>
    ) -> RunnerHelperReaper {
        RunnerHelperReaper(
            snapshot: { table.value },
            signal: { pid, signal in
                signals.append("\(signal == SIGKILL ? "KILL" : signal == SIGINT ? "INT" : "\(signal)") \(pid)")
                if signal == SIGINT || signal == SIGKILL { alive.mutate { $0.remove(abs(pid)) } }
            },
            isAlive: { alive.value.contains($0) },
            runnerBases: [base],
            gracePeriod: 0.5,
            pollInterval: .milliseconds(10)
        )
    }

    /// The repro's sequence: xcodebuild (the runner's child, in its group)
    /// starts `simctl diagnose` in a group of its own after SIGINT, then dies,
    /// and diagnose is reparented to launchd.
    func testReapsTheDiagnoseTheRunnersXcodebuildStartedAfterItWasReparented() async throws {
        let table = Locked("\(runner)\n\(xcodebuild)")
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([102])
        let reaper = reaper(table: table, signals: signals, alive: alive)
        // runPid 999: only the lineage, not the run directory, proves ownership.
        let interrupted = "\(orphanedXcodebuild)\n\(diagnose(ppid: 101, runPid: 999))"
        let afterSIGTERM = diagnose(ppid: 1, runPid: 999)

        let (value, reaped) = await reaper.stopping(runnerPid: 100, udid: udid) { () async -> String in
            table.mutate { $0 = interrupted }
            try? await Task.sleep(for: .milliseconds(200))
            // xcodebuild took SIGTERM; diagnose (its own group) survived.
            table.mutate { $0 = afterSIGTERM }
            return "interrupted"
        }

        XCTAssertEqual(value, "interrupted")
        XCTAssertEqual(reaped.map(\.pid), [102])
        XCTAssertEqual(reaped.first?.kind, .diagnose)
        XCTAssertEqual(reaped.first?.killed, true)
        XCTAssertTrue(signals.value.contains("INT 102"), "\(signals.value)")
        XCTAssertFalse(alive.value.contains(102))
    }

    /// The parent was never seen (it spawned diagnose and died between
    /// samples), but the result bundle diagnose writes into is this runner's
    /// own run directory under the runner home's device directory.
    func testReapsADiagnoseWritingIntoTheStoppedRunnersRunDirectory() async {
        let table = Locked(diagnose(ppid: 1))
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([102])
        let reaped = await reaper(table: table, signals: signals, alive: alive).sweep(exitedRunnerPid: 100, udid: udid)
        XCTAssertEqual(reaped.map(\.pid), [102])
    }

    func testLeavesADiagnoseTheRunnerDidNotStartAlone() async {
        // Same device, but someone's own `xcrun simctl diagnose`, another
        // runner's run directory, and a run directory outside the runner home.
        let table = Locked([
            "300     1   300 /usr/bin/xcrun simctl diagnose --udid=\(udid) --no-archive",
            diagnose(pid: 301, ppid: 1, runPid: 777),
            diagnose(pid: 302, ppid: 1, base: "/Users/someone/elsewhere"),
        ].joined(separator: "\n"))
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([300, 301, 302])
        let reaper = reaper(table: table, signals: signals, alive: alive)

        let (_, reaped) = await reaper.stopping(runnerPid: 100, udid: udid) { () async -> Int in 0 }
        XCTAssertEqual(reaped, [])
        let swept = await reaper.sweep(exitedRunnerPid: 100, udid: udid)
        XCTAssertEqual(swept, [])
        XCTAssertEqual(signals.value, [])
    }

    func testLeavesTheRunnersChildrenForOtherDevicesAndUnrelatedChildrenAlone() async {
        let table = Locked([
            runner,
            "103   100   100 /usr/bin/xcrun simctl diagnose --udid=DEAD-BEEF --no-archive",
            "104   100   100 /bin/sleep 60",
        ].joined(separator: "\n"))
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([103, 104])
        let (_, reaped) = await reaper(table: table, signals: signals, alive: alive)
            .stopping(runnerPid: 100, udid: udid) { () async -> Int in 0 }
        XCTAssertEqual(reaped, [])
        XCTAssertEqual(signals.value, [])
    }

    /// A descendant's pid reused by an unrelated process that happens to name
    /// the device is not the descendant.
    func testAReusedDescendantPidIsNotReaped() async {
        let table = Locked("\(runner)\n\(xcodebuild)")
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([101])
        let reaper = reaper(table: table, signals: signals, alive: alive)
        let reused = "101   555   555 /usr/bin/xcrun simctl diagnose --udid=\(udid) --no-archive"
        let (_, reaped) = await reaper.stopping(runnerPid: 100, udid: udid) { () async -> Int in
            table.mutate { $0 = reused }
            return 0
        }
        XCTAssertEqual(reaped, [])
        XCTAssertEqual(signals.value, [])
    }

    /// A descendant's pid reused by an unrelated process does not make that
    /// process's children the runner's: the parent link counts only while
    /// the parent still runs the command it had as a member.
    func testAChildOfAReusedDescendantPidIsNotReaped() async {
        let table = Locked("\(runner)\n\(xcodebuild)")
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([102])
        let reaper = reaper(table: table, signals: signals, alive: alive)
        let reused = [
            "101   555   555 /bin/zsh -l",
            "102   101   102 /usr/bin/xcrun simctl diagnose --udid=\(udid) --no-archive",
        ].joined(separator: "\n")
        let (_, reaped) = await reaper.stopping(runnerPid: 100, udid: udid) { () async -> Int in
            table.mutate { $0 = reused }
            return 0
        }
        XCTAssertEqual(reaped, [])
        XCTAssertEqual(signals.value, [])
    }

    /// A helper that ignores SIGINT gets SIGKILL once the grace period ends,
    /// and the reaper waits for it to go.
    func testEscalatesToSIGKILLAndWaits() async {
        let table = Locked(diagnose(ppid: 1))
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([102])
        var reaper = reaper(table: table, signals: signals, alive: alive)
        reaper.signal = { pid, signal in
            signals.append("\(signal == SIGKILL ? "KILL" : signal == SIGINT ? "INT" : "\(signal)") \(pid)")
            if signal == SIGKILL { alive.mutate { $0.remove(abs(pid)) } }
        }
        let started = Date()
        let reaped = await reaper.sweep(exitedRunnerPid: 100, udid: udid)
        XCTAssertEqual(reaped.map(\.pid), [102])
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.4)
        // Diagnose leads its own group: the group is signalled with it.
        XCTAssertEqual(signals.value, ["INT 102", "INT -102", "KILL 102", "KILL -102"])
        XCTAssertFalse(alive.value.contains(102))
    }

    /// B4-L72.3: Ctrl-C while `runner start` (or `run`) is still starting.
    /// The runner is gone, but WebDriverAgent's xcodebuild, in a group of its
    /// own, was reparented to launchd and later starts a diagnose. The
    /// interrupt reap ends it with SIGKILL at once (SIGINT is what makes it
    /// start the diagnose) and takes a diagnose already running with it,
    /// blocking because the signal relay's cleanups are synchronous.
    func testAnInterruptReapKillsTheOrphanedXcodebuildAtOnceAndItsDiagnose() {
        let run = "\(base)/versions/1.1.28/devices/\(udid)/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8-r1/devices/\(udid)/run-100-1792089048161055000"
        let orphan = "101     1   101 /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building "
            + "-xctestrun \(run)/Products/WebDriverAgentRunner_iphonesimulator27.0-arm64.xctestrun "
            + "-destination platform=iOS Simulator,arch=arm64,id=\(udid) -derivedDataPath \(run)/DerivedData"
        let otherRun = orphan.replacingOccurrences(of: "run-100-", with: "run-200-").replacingOccurrences(of: "101 ", with: "103 ")
        let table = Locked([orphan, diagnose(ppid: 101), otherRun].joined(separator: "\n"))
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([101, 102, 103])
        let reaper = reaper(table: table, signals: signals, alive: alive)

        let reaped = reaper.reapAfterInterrupt(runnerPid: 100, udid: udid)

        XCTAssertEqual(reaped.map(\.pid), [101, 102])
        XCTAssertTrue(signals.value.contains("KILL 101"), "\(signals.value)")
        XCTAssertTrue(signals.value.contains("KILL -101"), "\(signals.value)")
        XCTAssertFalse(signals.value.contains("INT 101"), "xcodebuild must not get SIGINT: \(signals.value)")
        XCTAssertFalse(signals.value.contains { $0.hasSuffix(" 103") }, "another run's xcodebuild is not ours: \(signals.value)")
        XCTAssertEqual(alive.value, [103])
    }

    /// Side finding 7: `runner stop` after the runner was `kill -9`'d. Its
    /// WebDriverAgent xcodebuild, orphaned, starts a 600 s `simctl diagnose`
    /// when it gets SIGINT, after the reap has looked. The sweep of an exited
    /// runner kills that xcodebuild at once, and looks again for a diagnose.
    func testTheSweepOfAnExitedRunnerKillsItsXcodebuildAtOnceAndReapsALateDiagnose() async {
        let run = "\(base)/versions/1.1.28/devices/\(udid)/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8-r1/devices/\(udid)/run-100-1792089048161055000"
        let orphan = "101     1   101 /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building "
            + "-xctestrun \(run)/Products/WebDriverAgentRunner_iphonesimulator27.0-arm64.xctestrun "
            + "-destination platform=iOS Simulator,arch=arm64,id=\(udid) -derivedDataPath \(run)/DerivedData"
        let table = Locked(orphan)
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([101, 102])
        var reaper = reaper(table: table, signals: signals, alive: alive)
        let late = diagnose(ppid: 1)
        reaper.signal = { pid, signal in
            signals.append("\(signal == SIGKILL ? "KILL" : signal == SIGINT ? "INT" : "\(signal)") \(pid)")
            alive.mutate { $0.remove(abs(pid)) }
            // The dying xcodebuild leaves a diagnose behind.
            if abs(pid) == 101 { table.mutate { $0 = late } }
        }

        let reaped = await reaper.sweep(exitedRunnerPid: 100, udid: udid)

        XCTAssertEqual(reaped.map(\.pid), [101, 102])
        XCTAssertFalse(signals.value.contains("INT 101"), "xcodebuild must not get SIGINT: \(signals.value)")
        XCTAssertTrue(signals.value.contains("KILL 101"), "\(signals.value)")
        XCTAssertTrue(alive.value.isEmpty, "\(alive.value)")
    }

    /// `runner stop` of a live runner: once the runner is gone its xcodebuild
    /// takes SIGINT, and the diagnose that starts in that window is reaped by
    /// a second look, as the exited-runner sweep does.
    func testStoppingALiveRunnerReapsTheDiagnoseItsXcodebuildStartsAfterSIGINT() async {
        let table = Locked("\(runner)\n\(xcodebuild)")
        let signals = Locked<[String]>([])
        let alive = Locked<Set<Int32>>([101, 102])
        var reaper = reaper(table: table, signals: signals, alive: alive)
        let late = diagnose(ppid: 1)
        let orphan = orphanedXcodebuild
        reaper.signal = { pid, signal in
            signals.append("\(signal == SIGKILL ? "KILL" : signal == SIGINT ? "INT" : "\(signal)") \(pid)")
            alive.mutate { $0.remove(abs(pid)) }
            if abs(pid) == 101 { table.mutate { $0 = late } }
        }

        let (_, reaped) = await reaper.stopping(runnerPid: 100, udid: udid) { () async -> Int in
            // The runner's group stopped; its xcodebuild, reparented, lives on.
            table.mutate { $0 = orphan }
            return 0
        }

        XCTAssertEqual(reaped.map(\.pid), [101, 102])
        XCTAssertTrue(signals.value.contains("INT 102"), "\(signals.value)")
        XCTAssertTrue(alive.value.isEmpty, "\(alive.value)")
    }

    /// xcodebuild spells a `/private/tmp` runner home `/tmp` in the
    /// diagnose it starts; the live reaper knows both spellings.
    func testTheLiveReaperMatchesBothSpellingsOfAPrivateRunnerHome() {
        let live = RunnerHelperReaper.live(runnerBase: "/private/tmp/grantiva-l04-tests/runner-home")
        XCTAssertTrue(live.writesIntoRunDirectory(diagnose(ppid: 1), runnerPid: 100, udid: udid))
        let tmp = RunnerHelperReaper.live(runnerBase: base)
        XCTAssertTrue(tmp.writesIntoRunDirectory(
            diagnose(ppid: 1, base: "/private/tmp/grantiva-l04-tests/runner-home"), runnerPid: 100, udid: udid
        ))
    }

    func testParsesPidParentGroupAndCommand() {
        let rows = HostProcess.parse("  101   100   100 /usr/bin/xcodebuild test-without-building\nnot a row\n")
        XCTAssertEqual(rows, [HostProcess(pid: 101, ppid: 100, pgid: 100, command: "/usr/bin/xcodebuild test-without-building")])
    }
}
