import Darwin
import Foundation
import XCTest
@testable import GrantivaCore

/// `simulator ensure` waited 10.6 minutes on one `xcrun simctl list devices
/// --json` under load: list calls on the ensure and boot path had no bound.
final class SimctlListBoundTests: XCTestCase {
    /// A list child that exits with `stdout` once started, or never (`stdout` nil).
    final class FakeList: SimctlListChild, @unchecked Sendable {
        private let lock = NSLock()
        private var status: Int32?
        private var terminations = 0
        private let stdout: String
        private let failure: String
        let pid: pid_t

        init(pid: pid_t = 5151, stdout: String?, exitStatus: Int32 = 0, failure: String = "") {
            self.pid = pid
            self.stdout = stdout ?? ""
            self.failure = failure
            status = stdout == nil ? nil : exitStatus
        }

        var terminated: Bool { lock.withLock { terminations > 0 } }
        func poll() -> Int32? { lock.withLock { status } }
        func output() -> String { failure }
        func standardOutput() -> String { stdout }
        func terminate() {
            lock.withLock {
                terminations += 1
                if status == nil { status = SIGTERM }
            }
        }
    }

    private final class Starts: @unchecked Sendable {
        private let lock = NSLock()
        private var made: [FakeList] = []
        private var arguments: [[String]] = []
        private let script: [String?]

        /// `script[i]` is the i-th child's stdout; nil stalls; past the end, the last entry.
        init(_ script: [String?]) { self.script = script }

        func start(_ args: [String]) -> FakeList {
            lock.withLock {
                let entry = script[min(made.count, script.count - 1)]
                let child = FakeList(pid: pid_t(6000 + made.count), stdout: entry)
                made.append(child)
                arguments.append(args)
                return child
            }
        }

        var children: [FakeList] { lock.withLock { made } }
        var calls: [[String]] { lock.withLock { arguments } }
    }

    private let fast = SimctlListBound(timeout: 0.15, pollInterval: 0.01, environment: [:])

    // MARK: - The bound

    func testAStalledListIsEndedRetriedOnceThenFailsNamingTheSetting() async throws {
        let starts = Starts([nil])
        let began = Date()
        do {
            _ = try await fast.run(command: "xcrun simctl list devices --json", start: { starts.start([]) })
            XCTFail("a list that never returns must fail")
        } catch GrantivaError.commandFailed(let message, let code) {
            XCTAssertEqual(code, 1)
            XCTAssertTrue(message.contains("xcrun simctl list devices --json"), message)
            XCTAssertTrue(message.contains(SimctlListBound.timeoutVariable), message)
        }
        XCTAssertEqual(starts.children.count, 2, "one run and one retry")
        XCTAssertTrue(starts.children.allSatisfy(\.terminated), "each stalled child is ended")
        XCTAssertLessThan(Date().timeIntervalSince(began), 5)
    }

    func testAStallThenAnAnswerReturnsTheAnswer() async throws {
        let starts = Starts([nil, #"{"devices":{}}"#])
        let output = try await fast.run(command: "xcrun simctl list devices --json", start: { starts.start([]) })
        XCTAssertEqual(output, #"{"devices":{}}"#)
        XCTAssertEqual(starts.children.count, 2)
        XCTAssertTrue(starts.children[0].terminated)
        XCTAssertFalse(starts.children[1].terminated)
    }

    func testAPromptAnswerIsNotRetried() async throws {
        let starts = Starts(["{}"])
        let output = try await fast.run(command: "c", start: { starts.start([]) })
        XCTAssertEqual(output, "{}")
        XCTAssertEqual(starts.children.count, 1)
    }

    func testAFailingListThrowsItsOutputWithoutARetry() async throws {
        var made = 0
        do {
            _ = try await fast.run(command: "c", start: {
                made += 1
                return FakeList(stdout: "", exitStatus: 2, failure: "CoreSimulatorService connection invalid")
            })
            XCTFail("expected the exit status")
        } catch GrantivaError.commandFailed(let message, let code) {
            XCTAssertEqual(code, 2)
            XCTAssertEqual(message, "CoreSimulatorService connection invalid")
        }
        XCTAssertEqual(made, 1)
    }

    func testTheBoundIsConfigurable() {
        XCTAssertEqual(SimctlListBound(environment: [:]).timeout, 120)
        XCTAssertEqual(SimctlListBound(environment: [SimctlListBound.timeoutVariable: "7.5"]).timeout, 7.5)
        XCTAssertEqual(SimctlListBound(environment: [SimctlListBound.timeoutVariable: "0"]).timeout, 120)
        XCTAssertEqual(SimctlListBound(environment: [SimctlListBound.timeoutVariable: "soon"]).timeout, 120)
    }

    // MARK: - The manager's list calls

    private func makeManager(_ simctl: FakeSimctl, starts: Starts) -> SimulatorManager {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("grantiva-listbound-tests-\(UUID().uuidString)").path
        addTeardownBlock { try? FileManager.default.removeItem(atPath: directory) }
        return SimulatorManager(
            execute: simctl.execute,
            capacity: SimulatorCapacity(directory: directory, maximum: 4, waitTimeout: 0, pollInterval: 0.01),
            provenance: SimulatorProvenance(directory: directory),
            runnerHome: "\(directory)/runner",
            startList: { starts.start($0) },
            listBound: fast
        )
    }

    func testEnsureFailsClearlyWhenSimctlListNeverReturns() async throws {
        let simctl = FakeSimctl(devices: [])
        let starts = Starts([nil])
        let manager = makeManager(simctl, starts: starts)
        do {
            _ = try await manager.ensure(name: "cov iPhone 17", boot: true)
            XCTFail("ensure must fail when simctl list stalls")
        } catch GrantivaError.commandFailed(let message, _) {
            XCTAssertTrue(message.contains("xcrun simctl list"), message)
            XCTAssertTrue(message.contains(SimctlListBound.timeoutVariable), message)
        }
        XCTAssertEqual(starts.calls.first?.first, "list")
        XCTAssertTrue(starts.children.allSatisfy(\.terminated))
        XCTAssertFalse(simctl.commands.contains { $0.hasPrefix("xcrun simctl create") }, "nothing is created after a stalled list")
    }

    func testListDevicesGoesThroughTheBound() async throws {
        let simctl = FakeSimctl(devices: [
            .init(name: "cov-a", udid: "PRE-1", state: "Booted", runtime: "iOS-26-0", type: FakeSimctl.iPhone17),
        ])
        let json = try await simctl.execute("xcrun simctl list devices --json")
        let starts = Starts([nil, json])
        let manager = makeManager(simctl, starts: starts)
        let devices = try await manager.listDevices()
        XCTAssertEqual(devices.map(\.udid), ["PRE-1"])
        XCTAssertEqual(starts.calls, [["list", "devices", "--json"], ["list", "devices", "--json"]])
    }

    // MARK: - The live child

    func testTheLiveListChildKeepsStdoutApartFromStderr() async throws {
        let child = try LiveBootStatusChild.start(
            executable: "/bin/sh", arguments: ["-c", #"echo '{"devices":{}}'; echo 'warning: slow' >&2"#],
            separateStandardError: true
        )
        let output = try await fast.run(command: "sh", start: { child })
        XCTAssertEqual(output, #"{"devices":{}}"#)
    }

    func testAStalledLiveListIsEndedByItsRecordedPid() async throws {
        var pids: [pid_t] = []
        do {
            _ = try await fast.run(command: "sleep", start: {
                let child = try LiveBootStatusChild.start(
                    executable: "/bin/sleep", arguments: ["30"], separateStandardError: true
                )
                pids.append(child.pid)
                return child
            })
            XCTFail("expected the timeout")
        } catch GrantivaError.commandFailed {}
        XCTAssertEqual(pids.count, 2)
        for pid in pids {
            XCTAssertFalse(ShellChildren.shared.running.contains(pid))
            XCTAssertNotEqual(kill(pid, 0), 0, "pid \(pid) still running")
        }
    }
}
