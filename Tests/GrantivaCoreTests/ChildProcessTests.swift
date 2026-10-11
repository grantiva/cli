import Darwin
import Foundation
import XCTest
@testable import GrantivaCore

/// Covers the spawn behaviour that lets a cancelled run reap everything it
/// started. The full simulator path (grantiva-runner → WebDriverAgent's
/// xcodebuild → simctl diagnose) cannot run in a unit test, but the property
/// that makes reaping work — one process group per runner, signalled as a unit —
/// is exercised here with a stand-in process tree.
final class ChildProcessTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-child-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func devNullOutput() throws -> Int32 {
        let descriptor = Darwin.open("/dev/null", O_WRONLY)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        return descriptor
    }

    func testChildIsLeaderOfItsOwnProcessGroup() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }

        let child = try ChildProcess.spawn(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 30"],
            stdout: output,
            stderr: output
        )
        defer { child.terminateGroup(gracePeriod: 1) }

        // Own group, not grantiva's: `kill(-pgid, …)` can therefore target the
        // runner tree without also signalling grantiva itself.
        XCTAssertEqual(getpgid(child.pid), child.pid)
        XCTAssertNotEqual(child.processGroup, getpgrp())
    }

    func testTerminateGroupReapsGrandchildren() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }

        // Stands in for grantiva-runner starting WebDriverAgent's xcodebuild:
        // a grandchild that outlives the direct child unless the whole group is
        // signalled.
        let pidFile = scratch.appendingPathComponent("grandchild.pid").path
        let child = try ChildProcess.spawn(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 60 & echo $! > \(pidFile); sleep 60"],
            stdout: output,
            stderr: output
        )

        var grandchild: pid_t = 0
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let text = try? String(contentsOfFile: pidFile, encoding: .utf8),
               let parsed = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                grandchild = parsed
                break
            }
            usleep(50_000)
        }
        XCTAssertGreaterThan(grandchild, 0, "grandchild never started")
        XCTAssertEqual(kill(grandchild, 0), 0, "grandchild should be alive before teardown")

        child.terminateGroup(gracePeriod: 2)
        child.wait()

        let gone = Date().addingTimeInterval(5)
        while Date() < gone, kill(grandchild, 0) == 0 {
            usleep(50_000)
        }
        XCTAssertNotEqual(kill(grandchild, 0), 0, "grandchild survived the group teardown")
    }

    func testExitStatusIsReported() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }

        let child = try ChildProcess.spawn(
            executable: "/bin/sh",
            arguments: ["-c", "exit 7"],
            stdout: output,
            stderr: output
        )
        XCTAssertEqual(child.wait(), 7)
    }

    func testTerminationStatusDecoding() {
        XCTAssertEqual(ChildProcess.terminationStatus(raw: 7 << 8), 7) // exit(7)
        XCTAssertEqual(ChildProcess.terminationStatus(raw: SIGTERM), SIGTERM) // killed
    }

    func testWorkingDirectoryIsApplied() throws {
        let outPath = scratch.appendingPathComponent("cwd.txt").path
        FileManager.default.createFile(atPath: outPath, contents: nil)
        let outFD = Darwin.open(outPath, O_WRONLY)
        defer { Darwin.close(outFD) }

        let child = try ChildProcess.spawn(
            executable: "/bin/sh",
            arguments: ["-c", "pwd"],
            workingDirectory: "/tmp",
            stdout: outFD,
            stderr: outFD
        )
        XCTAssertEqual(child.wait(), 0)
        let text = try String(contentsOfFile: outPath, encoding: .utf8)
        XCTAssertTrue(text.contains("/tmp"), text)
    }
    /// CI hands the test process SIGINT/SIGTERM blocked; posix_spawn would
    /// pass that mask on, and the runner could never be interrupted.
    func testAChildStartsWithTerminationSignalsDeliverableWhateverTheParentBlocks() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        var blocked = sigset_t(), previous = sigset_t()
        sigemptyset(&blocked)
        sigaddset(&blocked, SIGINT)
        sigaddset(&blocked, SIGTERM)
        pthread_sigmask(SIG_BLOCK, &blocked, &previous)
        let child: ChildProcess
        do {
            child = try ChildProcess.spawn(executable: "/bin/sleep", arguments: ["30"], stdout: output, stderr: output)
        } catch {
            pthread_sigmask(SIG_SETMASK, &previous, nil)
            throw error
        }
        pthread_sigmask(SIG_SETMASK, &previous, nil)
        defer { child.terminateGroup(gracePeriod: 1) }
        child.signalGroup(SIGINT)
        XCTAssertEqual(child.wait(), SIGINT)
    }

    // MARK: - K79: the runner's lifetime is bound to grantiva's

    /// Closing the watchdog's pipe is exactly what the kernel does when
    /// grantiva dies, however it dies (`kill -9` included): the watchdog then
    /// interrupts the runner's whole group.
    func testTheWatchdogInterruptsTheGroupWhenItsParentGoesAway() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let child = try ChildProcess.spawn(
            executable: "/bin/sh", arguments: ["-c", "sleep 30"], stdout: output, stderr: output
        )
        defer { child.terminateGroup(gracePeriod: 1) }
        let lifeline = try XCTUnwrap(child.bindLifetimeToParent())
        usleep(200_000)
        XCTAssertTrue(child.isRunning, "the watchdog must not fire while the parent lives")

        Darwin.close(lifeline)
        let started = Date()
        let status = child.wait()
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        XCTAssertEqual(status, SIGINT)
    }

    func testTheWatchdogRemovesTheRunnersSessionFilesOnceItIsGone() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let sessions = scratch.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let child = try ChildProcess.spawn(
            executable: "/bin/sh", arguments: ["-c", "sleep 30"], stdout: output, stderr: output
        )
        defer { child.terminateGroup(gracePeriod: 1) }
        let mine = ["\(child.pid)-1.grantiva", "\(child.pid).owner.json"]
        let other = "1\(child.pid)-1.grantiva"
        for name in mine + [other] {
            FileManager.default.createFile(atPath: sessions.appendingPathComponent(name).path, contents: Data("{}".utf8))
        }
        let lifeline = try XCTUnwrap(child.bindLifetimeToParent(sessionDirectory: sessions.path))
        Darwin.close(lifeline)
        child.wait()
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, FileManager.default.fileExists(atPath: sessions.appendingPathComponent(mine[0]).path) {
            usleep(50_000)
        }
        for name in mine {
            XCTAssertFalse(FileManager.default.fileExists(atPath: sessions.appendingPathComponent(name).path), name)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessions.appendingPathComponent(other).path))
    }

    /// A runner that ignores SIGINT and SIGTERM is SIGKILLed, and its files
    /// are removed anyway.
    func testTheWatchdogEscalatesToSIGKILLAndStillRemovesTheFiles() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let sessions = scratch.appendingPathComponent("sessions-kill")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let child = try ChildProcess.spawn(
            executable: "/bin/sh", arguments: ["-c", "trap '' INT TERM; while :; do sleep 0.1; done"],
            stdout: output, stderr: output
        )
        defer { child.terminateGroup(gracePeriod: 1) }
        let file = sessions.appendingPathComponent("\(child.pid)-1.grantiva")
        FileManager.default.createFile(atPath: file.path, contents: Data("{}".utf8))
        let lifeline = try XCTUnwrap(child.bindLifetimeToParent(sessionDirectory: sessions.path, graceTicks: 3))
        usleep(200_000)
        Darwin.close(lifeline)
        XCTAssertEqual(child.wait(), SIGKILL)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, FileManager.default.fileExists(atPath: file.path) { usleep(50_000) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    /// A hang-up while grantiva is alive ends the watchdog, not the runner.
    func testAHangUpEndsTheWatchdogWithoutTouchingTheRunner() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let child = try ChildProcess.spawn(
            executable: "/bin/sh", arguments: ["-c", "trap '' HUP; sleep 30"], stdout: output, stderr: output
        )
        defer { child.terminateGroup(gracePeriod: 1); child.wait() }
        let lifeline = try XCTUnwrap(child.bindLifetimeToParent())
        defer { Darwin.close(lifeline) }
        usleep(300_000)
        child.signalGroup(SIGHUP)
        usleep(500_000)
        XCTAssertTrue(child.isRunning, "SIGHUP to the group must not take the runner down via the watchdog")
    }

    func testTheWatchdogJoinsTheRunnersProcessGroup() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let child = try ChildProcess.spawn(
            executable: "/bin/sh", arguments: ["-c", "sleep 30"], stdout: output, stderr: output
        )
        let lifeline = try XCTUnwrap(child.bindLifetimeToParent())
        defer { Darwin.close(lifeline) }
        // Terminating the group also takes the watchdog down, so a normal exit
        // never leaves it behind.
        XCTAssertEqual(child.terminateGroup(gracePeriod: 1), .interrupted)
        child.wait()
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, kill(-child.pid, 0) == 0 { usleep(50_000) }
        XCTAssertNotEqual(kill(-child.pid, 0), 0, "the watchdog outlived its group")
    }

    // MARK: - K87: terminateGroup says how it ended

    func testTerminateGroupReportsWhenItHadToKill() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let child = try ChildProcess.spawn(
            executable: "/bin/sh", arguments: ["-c", "trap '' INT TERM; while :; do sleep 0.1; done"],
            stdout: output, stderr: output
        )
        usleep(200_000)
        XCTAssertEqual(child.terminateGroup(gracePeriod: 0.3), .killed)
        XCTAssertEqual(child.wait(), SIGKILL)
    }

    func testTerminateGroupOfAGoneGroupSaysSo() {
        XCTAssertEqual(ChildProcess.terminateGroup(999_999, gracePeriod: 0.1), .alreadyGone)
    }

    // MARK: - K33: --verbose names every long-running subprocess

    func testSpawnAndWaitAreLoggedLikeShell() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let lines = try SubprocessLog.capturing {
            let child = try ChildProcess.spawn(
                executable: "/bin/sh", arguments: ["-c", "exit 3"], stdout: output, stderr: output
            )
            child.wait()
        }
        XCTAssertEqual(lines, ["$ /bin/sh -c 'exit 3'", "exit 3: /bin/sh -c 'exit 3'"])
    }

    func testASignalledChildIsLoggedAsStopped() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let lines = try SubprocessLog.capturing {
            let child = try ChildProcess.spawn(
                executable: "/bin/sleep", arguments: ["30"], stdout: output, stderr: output
            )
            child.signalGroup(SIGINT)
            child.wait()
        }
        XCTAssertEqual(lines, ["$ /bin/sleep 30", "stopped by SIGINT: /bin/sleep 30"])
    }

    // MARK: - L11: an ignored SIGHUP (nohup) is handed on to the runner

    /// Runs `body` with `signalNumber` set to `handler` in this process,
    /// restoring the previous disposition afterwards.
    private func withDisposition<T>(_ signalNumber: Int32, _ handler: sig_t?, _ body: () throws -> T) rethrows -> T {
        var previous = sigaction()
        sigaction(signalNumber, nil, &previous)
        signal(signalNumber, handler)
        defer { sigaction(signalNumber, &previous, nil) }
        return try body()
    }

    /// How a child spawned now sees SIGHUP: perl reports `IGNORE` for a
    /// signal ignored at exec, and nothing for one at its default. (macOS
    /// `ps` has no ignored-signal column.)
    private func hangUpDispositionInAChild() throws -> String {
        let pipe = Pipe()
        let child = try ChildProcess.spawn(
            executable: "/usr/bin/perl", arguments: ["-e", "print $SIG{HUP} // 'DEFAULT'"],
            stdout: pipe.fileHandleForWriting.fileDescriptor, stderr: pipe.fileHandleForWriting.fileDescriptor
        )
        try pipe.fileHandleForWriting.close()
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        child.wait()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testAnIgnoredHangUpStaysIgnoredInTheChildAndItSurvivesSIGHUP() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let child = try withDisposition(SIGHUP, SIG_IGN) {
            try ChildProcess.spawn(executable: "/bin/sleep", arguments: ["30"], stdout: output, stderr: output)
        }
        defer { child.terminateGroup(gracePeriod: 1); child.wait() }
        XCTAssertEqual(try withDisposition(SIGHUP, SIG_IGN) { try hangUpDispositionInAChild() }, "IGNORE", "SIGHUP must stay ignored in the child")
        usleep(200_000)
        kill(child.pid, SIGHUP)
        usleep(300_000)
        XCTAssertTrue(child.isRunning, "a child of a nohup'd grantiva must survive a hang-up")
    }

    func testADefaultHangUpStillEndsTheChild() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let child = try withDisposition(SIGHUP, SIG_DFL) {
            try ChildProcess.spawn(executable: "/bin/sleep", arguments: ["30"], stdout: output, stderr: output)
        }
        defer { child.terminateGroup(gracePeriod: 1) }
        XCTAssertEqual(try withDisposition(SIGHUP, SIG_DFL) { try hangUpDispositionInAChild() }, "DEFAULT")
        usleep(200_000)
        kill(child.pid, SIGHUP)
        XCTAssertEqual(child.wait(), SIGHUP)
    }

    func testInterruptAndTerminateAreResetEvenWhenIgnoredHere() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        for signalNumber in [SIGINT, SIGTERM] {
            let child = try withDisposition(signalNumber, SIG_IGN) {
                try ChildProcess.spawn(executable: "/bin/sleep", arguments: ["30"], stdout: output, stderr: output)
            }
            usleep(200_000)
            kill(child.pid, signalNumber)
            XCTAssertEqual(child.wait(), signalNumber, "signal \(signalNumber) must be at its default in the child")
        }
    }

    func testOnlySignalsNotIgnoredHereAreReset() {
        XCTAssertEqual(ChildProcess.signalsToReset(isIgnored: { _ in false }), [SIGINT, SIGTERM, SIGHUP, SIGQUIT, SIGPIPE])
        XCTAssertEqual(ChildProcess.signalsToReset(isIgnored: { _ in true }), [SIGINT, SIGTERM])
        XCTAssertEqual(ChildProcess.signalsToReset(isIgnored: { $0 == SIGHUP }), [SIGINT, SIGTERM, SIGQUIT, SIGPIPE])
    }

    // MARK: - L48: a child that has exited is seen without blocking

    func testPollReportsAnExitWithoutBlockingAndWaitAgrees() throws {
        let output = try devNullOutput()
        defer { Darwin.close(output) }
        let child = try ChildProcess.spawn(executable: "/bin/sh", arguments: ["-c", "exit 4"], stdout: output, stderr: output)
        let deadline = Date().addingTimeInterval(5)
        var status: Int32?
        while status == nil, Date() < deadline {
            status = child.poll()
            if status == nil { usleep(20_000) }
        }
        XCTAssertEqual(status, 4)
        XCTAssertFalse(child.isRunning)
        XCTAssertEqual(child.wait(), 4)
        XCTAssertNil(child.terminatingSignal)

        let sleeper = try ChildProcess.spawn(executable: "/bin/sleep", arguments: ["30"], stdout: output, stderr: output)
        XCTAssertNil(sleeper.poll())
        kill(sleeper.pid, SIGHUP)
        XCTAssertEqual(sleeper.wait(), SIGHUP)
        XCTAssertEqual(sleeper.terminatingSignal, SIGHUP)
    }
}
