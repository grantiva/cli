import Foundation
import GrantivaCore
import MCP
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
