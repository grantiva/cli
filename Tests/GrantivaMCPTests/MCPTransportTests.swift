import Foundation
import GrantivaCore
import MCP
import Logging
import XCTest

@testable import GrantivaMCP

/// K101: malformed input never gets a reply with an invented id. A message
/// without an id is not answered; a line that is not JSON gets -32700 with
/// `"id": null`; a malformed request that carries an id gets -32600 echoing it.
@available(macOS 15, *)
final class MCPTransportTests: XCTestCase {
    private func json(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func testScreeningOfEachKindOfLine() throws {
        XCTAssertEqual(JSONRPCScreen.screen(Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8)), .forward)
        XCTAssertEqual(JSONRPCScreen.screen(Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#.utf8)), .forward)
        XCTAssertEqual(JSONRPCScreen.screen(Data(#"{"jsonrpc":"2.0","id":"a","result":{}}"#.utf8)), .forward)
        XCTAssertEqual(JSONRPCScreen.screen(Data(#"[{"jsonrpc":"2.0","id":3,"method":"ping"}]"#.utf8)), .forward)
        XCTAssertEqual(JSONRPCScreen.screen(Data(#"{"method":"notifications/initialized"}"#.utf8)), .drop)

        guard case .reply(let parse) = JSONRPCScreen.screen(Data("this is not json".utf8)) else { return XCTFail("expected a reply") }
        let parseError = try XCTUnwrap(json(parse))
        XCTAssertTrue(parseError["id"] is NSNull, "\(parseError)")
        XCTAssertEqual((parseError["error"] as? [String: Any])?["code"] as? Int, -32700)
        XCTAssertEqual(parseError["jsonrpc"] as? String, "2.0")

        guard case .reply(let invalid) = JSONRPCScreen.screen(Data(#"{"id":7,"method":"tools/list"}"#.utf8)) else { return XCTFail("expected a reply") }
        let invalidRequest = try XCTUnwrap(json(invalid))
        XCTAssertEqual(invalidRequest["id"] as? Int, 7)
        XCTAssertEqual((invalidRequest["error"] as? [String: Any])?["code"] as? Int, -32600)

        guard case .reply(let stringID) = JSONRPCScreen.screen(Data(#"{"id":"q","params":{}}"#.utf8)) else { return XCTFail("expected a reply") }
        XCTAssertEqual(json(stringID)?["id"] as? String, "q")
    }

    /// The repro's four lines plus a malformed request with an id, through a
    /// real server: exactly the expected replies, none with an id the client
    /// did not send.
    func testTheServerAnswersOnlyWhatItShould() async throws {
        let (clientSide, serverSide) = await InMemoryTransport.createConnectedPair()
        let server = Server(name: "grantiva-test", version: "0.0.0", capabilities: .init(tools: .init(listChanged: false)))
        await server.withMethodHandler(ListTools.self) { _ in ListTools.Result(tools: []) }
        try await server.start(transport: ValidatingTransport(wrapping: serverSide))
        try await clientSide.connect()

        let replies = Replies()
        let stream = await clientSide.receive()
        let reader = Task {
            for try await data in stream { replies.append(data) }
        }
        defer { reader.cancel() }

        for line in [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}"#,
            #"{"method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#,
            "this is not json",
            #"{"id":7,"method":"tools/list"}"#,
            #"{"jsonrpc":"2.0","id":3,"method":"tools/list"}"#,
        ] {
            try await clientSide.send(Data(line.utf8))
        }

        let deadline = Date().addingTimeInterval(5)
        while replies.all.count < 5, Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        try await Task.sleep(nanoseconds: 300_000_000)  // anything extra would arrive now
        await server.stop()

        let objects = replies.all.compactMap(json)
        XCTAssertEqual(objects.count, 5, "\(objects)")
        func id(_ object: [String: Any]) -> String {
            object["id"] is NSNull ? "null" : "\(object["id"] ?? "missing")"
        }
        XCTAssertEqual(Set(objects.map(id)), ["1", "2", "3", "7", "null"])
        let byID = Dictionary(objects.map { (id($0), $0) }, uniquingKeysWith: { a, _ in a })
        XCTAssertEqual((byID["null"]?["error"] as? [String: Any])?["code"] as? Int, -32700)
        XCTAssertEqual((byID["7"]?["error"] as? [String: Any])?["code"] as? Int, -32600)
        XCTAssertNotNil(byID["2"]?["result"])
        XCTAssertNotNil(byID["3"]?["result"], "valid traffic still works after malformed lines")
    }

    /// Exercise the same validation boundary used by the stdio server with
    /// a byte sink that yields between writes, as a full OS pipe does.
    func testConcurrentLargeResourceAndToolResponsesAreWholeLines() async throws {
        try await exerciseChunkedResponses(includeSmallMessages: false)
    }

    func testConcurrentSmallResponsesNotificationsAndValidationErrorsAreWholeLines() async throws {
        try await exerciseChunkedResponses(includeSmallMessages: true)
    }

    private func exerciseChunkedResponses(includeSmallMessages: Bool) async throws {
        let (clientSide, serverSide) = await InMemoryTransport.createConnectedPair()
        let sink = PartialWriteTransport(wrapping: serverSide)
        let server = Server(name: "chunk-test", version: "1", capabilities: .init(
            resources: .init(listChanged: true), tools: .init(listChanged: false)
        ))
        let x = String(repeating: "x", count: 70_000)
        let y = String(repeating: "y", count: 70_000)
        await server.withMethodHandler(ReadResource.self) { params in
            ReadResource.Result(contents: [.text(x, uri: params.uri)])
        }
        await server.withMethodHandler(CallTool.self) { _ in
            CallTool.Result(content: [.text(text: y, annotations: nil, _meta: nil)])
        }
        await server.withMethodHandler(ListTools.self) { _ in ListTools.Result(tools: []) }
        try await server.start(transport: ValidatingTransport(wrapping: sink))
        try await clientSide.connect()
        let replies = Replies()
        let stream = await clientSide.receive()
        let reader = Task {
            var pending = Data()
            for try await chunk in stream {
                pending.append(chunk)
                while let newline = pending.firstIndex(of: 10) {
                    replies.append(Data(pending[..<newline]))
                    pending.removeSubrange(...newline)
                }
            }
            XCTAssertTrue(pending.isEmpty, "trailing bytes without a newline")
        }
        defer { reader.cancel() }
        try await clientSide.send(Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}"#.utf8))
        let initializedDeadline = Date().addingTimeInterval(5)
        while replies.all.isEmpty, Date() < initializedDeadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(replies.all.count, 1)
        try await clientSide.send(Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8))

        for pair in 0..<10 {
            let id = 10 + pair * 2
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await clientSide.send(Data("{\"jsonrpc\":\"2.0\",\"id\":\(id),\"method\":\"resources/read\",\"params\":{\"uri\":\"grantiva://hierarchy\"}}".utf8))
                }
                group.addTask {
                    try await clientSide.send(Data("{\"jsonrpc\":\"2.0\",\"id\":\(id + 1),\"method\":\"tools/call\",\"params\":{\"name\":\"large\",\"arguments\":{}}}".utf8))
                }
                if includeSmallMessages {
                    group.addTask {
                        try await clientSide.send(Data("{\"jsonrpc\":\"2.0\",\"id\":\(100 + pair),\"method\":\"tools/list\"}".utf8))
                    }
                    group.addTask {
                        try await clientSide.send(Data("{\"id\":\(200 + pair),\"method\":\"tools/list\"}".utf8))
                    }
                    group.addTask { try await server.notify(ResourceListChangedNotification.message()) }
                }
                try await group.waitForAll()
            }
        }
        let expectedCount = includeSmallMessages ? 50 : 20
        let deadline = Date().addingTimeInterval(10)
        while replies.all.count < expectedCount + 1, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        await server.stop()
        let lines = Array(replies.all.dropFirst())
        let objects = try lines.map { try XCTUnwrap(JSONSerialization.jsonObject(with: $0) as? [String: Any]) }
        XCTAssertEqual(objects.count, expectedCount)
        XCTAssertTrue(objects.allSatisfy { $0["jsonrpc"] as? String == "2.0" })
        let ids = objects.compactMap { $0["id"] as? Int }
        let expectedIDs = Set(10..<30).union(includeSmallMessages ? Set(100..<110).union(200..<210) : [])
        XCTAssertEqual(Set(ids), expectedIDs)
        XCTAssertEqual(ids.count, expectedIDs.count, "each ID must arrive exactly once; order is unconstrained")
        for object in objects {
            guard let id = object["id"] as? Int, (10..<30).contains(id) else { continue }
            let result = try XCTUnwrap(object["result"] as? [String: Any])
            let contents = try XCTUnwrap(result[id.isMultiple(of: 2) ? "contents" : "content"] as? [[String: Any]])
            XCTAssertEqual(contents.first?["text"] as? String, id.isMultiple(of: 2) ? x : y)
        }
        if includeSmallMessages {
            XCTAssertEqual(objects.filter { $0["method"] as? String == ResourceListChangedNotification.name }.count, 10)
            XCTAssertEqual(objects.filter { ($0["error"] as? [String: Any])?["code"] as? Int == -32600 }.count, 10)
        }
        let largestWrite = await sink.largestWrite
        XCTAssertEqual(largestWrite, 4096)
    }

    func testCancellingAnActiveWriteFinishesItsFrameBeforeTheNextMessage() async throws {
        let started = expectation(description: "first partial write")
        let completed = expectation(description: "both senders returned")
        completed.expectedFulfillmentCount = 2
        let sink = SuspendedWriteTransport(started: { started.fulfill() })
        let transport = ValidatingTransport(wrapping: sink)
        let first = Data(#"{"jsonrpc":"2.0","id":1,"result":"first"}"#.utf8)
        let second = Data(#"{"jsonrpc":"2.0","id":2,"result":"second"}"#.utf8)
        let active = Task { defer { completed.fulfill() }; try? await transport.send(first) }
        await fulfillment(of: [started], timeout: 2)
        let pending = Task { defer { completed.fulfill() }; try? await transport.send(second) }
        active.cancel()
        await sink.resumeWrite()
        await fulfillment(of: [completed], timeout: 2)
        pending.cancel()
        let bytes = await sink.bytes
        XCTAssertEqual(bytes, first + Data([10]) + second + Data([10]))
    }

    func testCancellingAPendingWriteDoesNotStartItsFrameOrStrandTheNextSender() async throws {
        let started = expectation(description: "first partial write")
        let queued = expectation(description: "pending sender started")
        let completed = expectation(description: "all senders returned")
        completed.expectedFulfillmentCount = 3
        let sink = SuspendedWriteTransport(started: { started.fulfill() })
        let transport = ValidatingTransport(wrapping: sink)
        let first = Data(#"{"jsonrpc":"2.0","id":1,"result":{}}"#.utf8)
        let skipped = Data(#"{"jsonrpc":"2.0","id":2,"result":{}}"#.utf8)
        let third = Data(#"{"jsonrpc":"2.0","id":3,"result":{}}"#.utf8)
        let active = Task { defer { completed.fulfill() }; try? await transport.send(first) }
        await fulfillment(of: [started], timeout: 2)
        let pending = Task {
            defer { completed.fulfill() }
            queued.fulfill()
            do { try await transport.send(skipped); XCTFail("cancelled frame was sent") }
            catch is CancellationError {} catch { XCTFail("unexpected error: \(error)") }
        }
        await fulfillment(of: [queued], timeout: 2)
        pending.cancel()
        let last = Task { defer { completed.fulfill() }; try? await transport.send(third) }
        await sink.resumeWrite()
        await fulfillment(of: [completed], timeout: 2)
        active.cancel(); last.cancel()
        let bytes = await sink.bytes
        XCTAssertEqual(bytes, first + Data([10]) + third + Data([10]))
    }

    func testAProtocolCancellationDropsAResponseWaitingBehindAnotherFrame() async throws {
        let started = expectation(description: "first partial write")
        let requestSeen = expectation(description: "request forwarded")
        let cancelSeen = expectation(description: "cancel forwarded")
        let completed = expectation(description: "senders returned")
        completed.expectedFulfillmentCount = 2
        let sink = SuspendedWriteTransport(started: { started.fulfill() })
        let transport = ValidatingTransport(wrapping: sink, cancelRetries: [])
        let stream = await transport.receive()
        let reader = Task {
            for try await data in stream {
                let text = String(decoding: data, as: UTF8.self)
                if text.contains("notifications/cancelled") { cancelSeen.fulfill() }
                else { requestSeen.fulfill() }
            }
        }
        defer { reader.cancel() }
        let first = Data(#"{"jsonrpc":"2.0","id":1,"result":{}}"#.utf8)
        let second = Data(#"{"jsonrpc":"2.0","id":2,"result":{}}"#.utf8)
        await sink.deliver(Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"x"}}"#.utf8))
        await fulfillment(of: [requestSeen], timeout: 2)
        let active = Task { defer { completed.fulfill() }; try? await transport.send(first) }
        await fulfillment(of: [started], timeout: 2)
        let pending = Task { defer { completed.fulfill() }; try? await transport.send(second) }
        // Let the second send reach the gate before delivering its protocol
        // cancellation; the underlying first write remains explicitly blocked.
        try await Task.sleep(for: .milliseconds(20))
        await sink.deliver(Data(#"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":2}}"#.utf8))
        await fulfillment(of: [cancelSeen], timeout: 2)
        await sink.resumeWrite()
        await fulfillment(of: [completed], timeout: 2)
        active.cancel(); pending.cancel()
        let bytes = await sink.bytes
        XCTAssertEqual(bytes, first + Data([10]))
        await transport.disconnect()
    }

    func testQueuedProtocolCancellationSurvivesExpiryAndReleasesTheNextSender() async throws {
        let started = expectation(description: "first partial write")
        let requestSeen = expectation(description: "request forwarded")
        let cancelSeen = expectation(description: "cancel forwarded")
        let completed = expectation(description: "senders returned")
        completed.expectedFulfillmentCount = 3
        let sink = SuspendedWriteTransport(started: { started.fulfill() })
        let transport = ValidatingTransport(wrapping: sink)
        let stream = await transport.receive()
        let reader = Task {
            var cancelled = false
            for try await data in stream {
                let text = String(decoding: data, as: UTF8.self)
                if text.contains("notifications/cancelled") {
                    if !cancelled { cancelled = true; cancelSeen.fulfill() }
                } else { requestSeen.fulfill() }
            }
        }
        defer { reader.cancel() }
        let first = Data(#"{"jsonrpc":"2.0","id":1,"result":{}}"#.utf8)
        let second = Data(#"{"jsonrpc":"2.0","id":2,"result":{}}"#.utf8)
        await sink.deliver(Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"x"}}"#.utf8))
        await fulfillment(of: [requestSeen], timeout: 2)
        let active = Task { defer { completed.fulfill() }; try? await transport.send(first) }
        await fulfillment(of: [started], timeout: 2)
        let pending = Task { defer { completed.fulfill() }; try? await transport.send(second) }
        // Let the second send reach the gate before delivering its protocol
        // cancellation; the underlying first write remains explicitly blocked.
        try await Task.sleep(for: .milliseconds(20))
        await sink.deliver(Data(#"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":2}}"#.utf8))
        await fulfillment(of: [cancelSeen], timeout: 2)
        // The production retry schedule and cleanup grace expire after two
        // seconds. Keep the first frame blocked past that expiry.
        try await Task.sleep(for: .milliseconds(2200))
        let third = Data(#"{"jsonrpc":"2.0","id":3,"result":{}}"#.utf8)
        let last = Task { defer { completed.fulfill() }; try? await transport.send(third) }
        await sink.resumeWrite()
        await fulfillment(of: [completed], timeout: 2)
        active.cancel(); pending.cancel(); last.cancel()
        let bytes = await sink.bytes
        XCTAssertEqual(bytes, first + Data([10]) + third + Data([10]))
        await transport.disconnect()
    }

    func testFailedPartialWriteClosesTransportAndReleasesQueuedSenders() async throws {
        try await assertPartialWriteStopsQueue(disconnect: false)
    }

    func testDisconnectStopsTheOwnedWriteAndReleasesQueuedSenders() async throws {
        try await assertPartialWriteStopsQueue(disconnect: true)
    }

    private func assertPartialWriteStopsQueue(disconnect: Bool) async throws {
        let started = expectation(description: "first partial write")
        let completed = expectation(description: "both failed senders returned")
        completed.expectedFulfillmentCount = 2
        let sink = SuspendedWriteTransport(failWrite: !disconnect, started: { started.fulfill() })
        let transport = ValidatingTransport(wrapping: sink)
        let message = Data(#"{"jsonrpc":"2.0","id":1,"result":{}}"#.utf8)
        let active = Task {
            defer { completed.fulfill() }
            do { try await transport.send(message); XCTFail("expected write failure") } catch {}
        }
        await fulfillment(of: [started], timeout: 2)
        let pending = Task {
            defer { completed.fulfill() }
            do { try await transport.send(message); XCTFail("queued send must fail after framing is lost") } catch {}
        }
        if disconnect { await transport.disconnect() } else { await sink.resumeWrite() }
        await fulfillment(of: [completed], timeout: 2)
        active.cancel(); pending.cancel()
        let bytes = await sink.bytes
        let attempts = await sink.attempts
        let closed = await sink.closed
        XCTAssertEqual(bytes, Data(message.prefix(8)), "never append another frame after a failed partial write")
        XCTAssertEqual(attempts, 1)
        XCTAssertTrue(closed)
    }

    func testBatchMembersAreScreenedOneByOne() throws {
        guard case .reply(let empty) = JSONRPCScreen.screen(Data("[]".utf8)) else { return XCTFail("expected a reply") }
        let emptyError = try XCTUnwrap(json(empty))
        XCTAssertTrue(emptyError["id"] is NSNull)
        XCTAssertEqual((emptyError["error"] as? [String: Any])?["code"] as? Int, -32600)

        let mixed = #"[{"jsonrpc":"2.0","id":1,"method":"ping"},{"id":2,"method":"ping"},{"method":"x"},5]"#
        guard case .split(let forward, let reply) = JSONRPCScreen.screen(Data(mixed.utf8)) else { return XCTFail("expected a split") }
        let forwarded = try XCTUnwrap(JSONSerialization.jsonObject(with: forward) as? [[String: Any]])
        XCTAssertEqual(forwarded.map { $0["id"] as? Int }, [1])
        let errors = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(reply)) as? [[String: Any]])
        XCTAssertEqual(errors.count, 2)
        XCTAssertEqual(errors[0]["id"] as? Int, 2)
        XCTAssertTrue(errors[1]["id"] is NSNull)
        XCTAssertTrue(errors.allSatisfy { ($0["error"] as? [String: Any])?["code"] as? Int == -32600 })

        XCTAssertEqual(JSONRPCScreen.screen(Data(#"[{"jsonrpc":"2.0","id":1,"method":"ping"}]"#.utf8)), .forward)
        XCTAssertEqual(JSONRPCScreen.screen(Data(#"[{"method":"x"}]"#.utf8)), .drop)
    }

    /// A response is never answered, even a malformed one with an id.
    func testAMalformedResponseIsDroppedNotAnswered() {
        XCTAssertEqual(JSONRPCScreen.screen(Data(#"{"id":4,"result":{}}"#.utf8)), .drop)
        XCTAssertEqual(JSONRPCScreen.screen(Data(#"{"id":4,"error":{"code":1,"message":"x"}}"#.utf8)), .drop)
    }

    func testRepliesDoNotEscapeSlashes() throws {
        let rewritten = JSONRPCScreen.outgoing(Data(#"{"jsonrpc":"2.0","id":1,"error":{"code":-32002,"message":"Server error: No session at /tmp/x/.grantiva/session.json"}}"#.utf8))
        let text = String(decoding: rewritten, as: UTF8.self)
        XCTAssertTrue(text.contains(#""message":"No session at /tmp/x/.grantiva/session.json""#), text)
    }

    /// K100 end to end: a resource read with no session, through a real
    /// server and the transport, reads as the session tools' text.
    func testANoSessionResourceReadReachesTheClientWithoutTheSDKPrefix() async throws {
        let registry = ToolRegistry(
            connection: RunnerConnection(
                resolveSession: { throw GrantivaError.invalidArgument("No active runner session at /p/.grantiva/session.json.") },
                attach: { _ in throw GrantivaError.invalidArgument("unreachable") }
            ),
            platform: .ios, device: MCPFakeDevicePlatform(platform: .ios), config: nil,
            simulatorManager: .live, buildRunner: XcodeBuildRunner(), emulators: nil
        )
        let (clientSide, serverSide) = await InMemoryTransport.createConnectedPair()
        let server = Server(name: "grantiva-test", version: "0.0.0", capabilities: .init(resources: .init(subscribe: true, listChanged: false)))
        await server.withMethodHandler(ReadResource.self) { params in
            ReadResource.Result(contents: try await registry.readResource(uri: params.uri))
        }
        try await server.start(transport: ValidatingTransport(wrapping: serverSide))
        try await clientSide.connect()
        let replies = Replies()
        let stream = await clientSide.receive()
        let reader = Task { for try await data in stream { replies.append(data) } }
        defer { reader.cancel() }

        for line in [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}"#,
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"grantiva://hierarchy"}}"#,
        ] {
            try await clientSide.send(Data(line.utf8))
        }
        let deadline = Date().addingTimeInterval(5)
        while replies.all.count < 2, Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        await server.stop()

        let read = try XCTUnwrap(replies.all.compactMap(json).first { $0["id"] as? Int == 2 })
        let error = try XCTUnwrap(read["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? Int, -32002)
        XCTAssertEqual(error["message"] as? String, "No active runner session at /p/.grantiva/session.json.")
    }
}

/// L14: a `tools/call` cancelled with `notifications/cancelled` gets no
/// response, whether the cancel arrives before the request's task starts or
/// while the tool runs; a cancel for an unknown id changes nothing.
@available(macOS 15, *)
final class MCPCancellationTests: XCTestCase {
    private func json(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Sends `lines` (each after its delay) to a server whose one tool sleeps
    /// 1 s and then returns an isError result, and returns the reply ids.
    private func replyIDs(
        _ lines: [(delay: UInt64, line: String)], expect: Int, toolSleeps: UInt64 = 1_000_000_000
    ) async throws -> [String] {
        let (clientSide, serverSide) = await InMemoryTransport.createConnectedPair()
        let server = Server(name: "grantiva-test", version: "0.0.0", capabilities: .init(tools: .init(listChanged: false)))
        await server.withMethodHandler(ListTools.self) { _ in ListTools.Result(tools: []) }
        await GrantivaMCPServer.registerToolCalls(on: server) { _, _ in
            if toolSleeps > 0 { try? await Task.sleep(nanoseconds: toolSleeps) }
            return CallTool.Result(content: [.text(text: "Error: late", annotations: nil, _meta: nil)], isError: true)
        }
        try await server.start(transport: ValidatingTransport(wrapping: serverSide))
        try await clientSide.connect()
        let replies = Replies()
        let stream = await clientSide.receive()
        let reader = Task { for try await data in stream { replies.append(data) } }
        defer { reader.cancel() }

        try await clientSide.send(Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}"#.utf8))
        try await clientSide.send(Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8))
        for (delay, line) in lines {
            if delay > 0 { try await Task.sleep(nanoseconds: delay * 1_000_000) }
            try await clientSide.send(Data(line.utf8))
        }
        let deadline = Date().addingTimeInterval(5)
        while replies.all.count < expect, Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        try await Task.sleep(nanoseconds: 1_500_000_000)  // a late result would arrive now
        await server.stop()
        return replies.all.compactMap(json).map { "\($0["id"] ?? "none")" }
    }

    private let call10 = #"{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"grantiva_build","arguments":{}}}"#
    private let cancel10 = #"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":10,"reason":"test"}}"#
    private let list11 = #"{"jsonrpc":"2.0","id":11,"method":"tools/list"}"#

    func testACancelRightBehindTheRequestYieldsNoResponse() async throws {
        let ids = try await replyIDs([(0, call10), (0, cancel10), (0, list11)], expect: 2)
        XCTAssertEqual(ids.sorted(), ["1", "11"])
    }

    func testACancelWhileTheToolRunsYieldsNoResponse() async throws {
        let ids = try await replyIDs([(0, call10), (200, cancel10), (0, list11)], expect: 2)
        XCTAssertEqual(ids.sorted(), ["1", "11"])
    }

    /// A tool that fails in milliseconds and never sees the cancellation:
    /// the SDK handles a batch's request before its cancel, so only the
    /// transport's drop keeps the answer from the client.
    func testTheTransportDropsTheAnswerOfAFastToolCancelledInTheSameBatch() async throws {
        let batch = "[" + call10 + "," + cancel10 + "]"
        let ids = try await replyIDs([(0, batch), (0, list11)], expect: 2, toolSleeps: 0)
        XCTAssertEqual(ids.sorted(), ["1", "11"])
    }

    func testTheTrackerDropsOnlyACancelledPendingRequestsAnswer() {
        var tracker = CancellationTracker()
        XCTAssertEqual(tracker.incoming(Data(call10.utf8)), [.none])
        XCTAssertEqual(tracker.incoming(Data(#"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":"10"}}"#.utf8)), [])
        let notes = tracker.incoming(Data(cancel10.utf8))
        XCTAssertEqual(notes.count, 1)
        let answer10 = Data(#"{"jsonrpc":"2.0","id":10,"result":{"content":[],"isError":true}}"#.utf8)
        let answer11 = Data(#"{"jsonrpc":"2.0","id":11,"result":{"tools":[]}}"#.utf8)
        XCTAssertNil(tracker.outgoing(answer10))
        XCTAssertEqual(tracker.outgoing(answer11), answer11)
        // Answered (dropped) once: a later id 10 is no longer cancelled.
        XCTAssertEqual(tracker.outgoing(answer10), answer10)
    }

    func testQueuedResponseOwnershipRetainsBatchCancellationUntilScreened() {
        var tracker = CancellationTracker()
        _ = tracker.incoming(Data(call10.utf8))
        let batch = Data(#"[{"jsonrpc":"2.0","id":10,"result":{}},{"jsonrpc":"2.0","id":11,"result":{}}]"#.utf8)
        let ids = tracker.retainQueuedResponse(batch)
        _ = tracker.incoming(Data(cancel10.utf8))
        tracker.forget("n:10")
        XCTAssertTrue(tracker.isCancelled("n:10"))
        let kept = tracker.outgoing(batch)
        tracker.releaseQueuedResponse(ids)
        XCTAssertEqual(String(decoding: kept ?? Data(), as: UTF8.self), #"[{"id":11,"jsonrpc":"2.0","result":{}}]"#)
        XCTAssertFalse(tracker.isCancelled("n:10"))
        // No stale ownership or marker affects a new request using this ID.
        _ = tracker.incoming(Data(call10.utf8))
        _ = tracker.incoming(Data(cancel10.utf8))
        tracker.forget("n:10")
        XCTAssertFalse(tracker.isCancelled("n:10"))
    }

    func testReleasingUnscreenedQueuedResponseCleansCancellationBookkeeping() {
        var tracker = CancellationTracker()
        _ = tracker.incoming(Data(call10.utf8))
        let answer = Data(#"{"jsonrpc":"2.0","id":10,"result":{}}"#.utf8)
        let ids = tracker.retainQueuedResponse(answer)
        _ = tracker.incoming(Data(cancel10.utf8))
        tracker.forget("n:10")
        XCTAssertTrue(tracker.isCancelled("n:10"))
        // The sender was cancelled or the transport failed before screening.
        tracker.releaseQueuedResponse(ids)
        XCTAssertFalse(tracker.isCancelled("n:10"))
        XCTAssertEqual(tracker.incoming(Data(cancel10.utf8)), [])
    }

    func testACancelForAnUnknownIDIsIgnored() async throws {
        let cancel99 = #"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":99}}"#
        let ids = try await replyIDs([(0, cancel99), (0, call10), (0, list11)], expect: 3)
        XCTAssertEqual(ids.sorted(), ["1", "10", "11"])
    }
}

private final class Replies: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Data] = []
    func append(_ data: Data) { lock.withLock { items.append(data) } }
    var all: [Data] { lock.withLock { items } }
}

/// Model StdioTransport's partial writes and suspension on a full pipe.
/// There is intentionally no whole-message lock in this underlying sink.
private actor PartialWriteTransport: Transport {
    nonisolated let logger = Logger(label: "test.partial-writes")
    private let inner: any Transport
    private(set) var largestWrite = 0

    init(wrapping inner: any Transport) { self.inner = inner }
    func connect() async throws { try await inner.connect() }
    func disconnect() async { await inner.disconnect() }
    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in await inner.receive() { continuation.yield(data) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    func send(_ data: Data) async throws {
        var remaining = data + Data([10])
        while !remaining.isEmpty {
            let chunk = Data(remaining.prefix(4096))
            largestWrite = max(largestWrite, chunk.count)
            try await inner.send(chunk)
            remaining.removeFirst(chunk.count)
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

/// Suspend after a partial write, without depending on pipe sizes or timing.
private actor SuspendedWriteTransport: Transport {
    nonisolated let logger = Logger(label: "test.suspended-write")
    private let started: @Sendable () -> Void
    private let failWrite: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private let incoming: AsyncThrowingStream<Data, Swift.Error>
    private let incomingContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation
    private(set) var bytes = Data()
    private(set) var attempts = 0
    private(set) var closed = false

    init(failWrite: Bool = false, started: @escaping @Sendable () -> Void) {
        self.failWrite = failWrite
        self.started = started
        (incoming, incomingContinuation) = AsyncThrowingStream.makeStream()
    }
    func connect() {}
    func receive() -> AsyncThrowingStream<Data, Swift.Error> { incoming }
    func deliver(_ data: Data) { incomingContinuation.yield(data) }
    func disconnect() { closed = true; resumeWrite(); incomingContinuation.finish() }
    func resumeWrite() { continuation?.resume(); continuation = nil }
    func send(_ data: Data) async throws {
        guard !closed else { throw MCPError.connectionClosed }
        attempts += 1
        if attempts == 1 {
            bytes.append(data.prefix(8))
            await withCheckedContinuation { continuation = $0; started() }
            try Task.checkCancellation()
            guard !closed, !failWrite else { throw MCPError.connectionClosed }
            bytes.append(data.dropFirst(8))
        } else {
            bytes.append(data)
        }
        bytes.append(10)
    }
}
