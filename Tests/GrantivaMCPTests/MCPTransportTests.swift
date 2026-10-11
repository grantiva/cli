import Foundation
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
}

private final class Replies: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Data] = []
    func append(_ data: Data) { lock.withLock { items.append(data) } }
    var all: [Data] { lock.withLock { items } }
}
