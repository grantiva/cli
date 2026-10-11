import Foundation
import Logging
import MCP

/// What to do with one incoming line before the MCP server sees it.
enum JSONRPCScreen: Equatable {
    /// A well-formed JSON-RPC message (or batch): the server handles it.
    case forward
    /// A malformed message without an id: a notification is never answered.
    case drop
    /// A malformed message the transport answers itself.
    case reply(Data)

    /// JSON-RPC 2.0 §4-5: text that is not JSON is `-32700` with `"id": null`;
    /// JSON that is not a valid request is `-32600`, echoing the id when it
    /// has one; a malformed message without an id is not answered. The SDK
    /// (0.12.1, the latest release) answers all three with `-32700` and an
    /// invented UUID id, so they are handled here.
    static func screen(_ data: Data) -> JSONRPCScreen {
        guard let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return .reply(errorResponse(code: -32700, message: "Parse error: the message is not valid JSON.", id: NSNull()))
        }
        if parsed is [Any] { return .forward }
        guard let object = parsed as? [String: Any] else {
            return .reply(errorResponse(code: -32600, message: "Invalid Request: expected a JSON-RPC object.", id: NSNull()))
        }
        let isRequestOrNotification = object["method"] is String
        let isResponse = object["id"] != nil && (object["result"] != nil || object["error"] != nil)
        if object["jsonrpc"] as? String == "2.0", isRequestOrNotification || isResponse {
            return .forward
        }
        let id: Any? = {
            switch object["id"] {
            case let string as String: return string
            case let number as NSNumber where !(number === kCFBooleanTrue || number === kCFBooleanFalse): return number
            default: return nil
            }
        }()
        guard let id else { return .drop }
        return .reply(errorResponse(
            code: -32600, message: #"Invalid Request: a JSON-RPC 2.0 message needs "jsonrpc": "2.0" and a "method"."#, id: id
        ))
    }

    /// The SDK prefixes a server error's message with `Server error: `. The
    /// no-session answer to a resource read (`ToolRegistry`'s code) reads as
    /// the session tools' text, so that prefix is removed on the way out.
    static func outgoing(_ data: Data, code: Int = ToolRegistry.noSessionResourceErrorCode) -> Data {
        guard data.count < 65_536,
              String(decoding: data, as: UTF8.self).contains("\(code)"),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var error = object["error"] as? [String: Any], error["code"] as? Int == code,
              let message = error["message"] as? String, message.hasPrefix("Server error: ") else { return data }
        error["message"] = String(message.dropFirst("Server error: ".count))
        object["error"] = error
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? data
    }

    private static func errorResponse(code: Int, message: String, id: Any) -> Data {
        let response: [String: Any] = ["jsonrpc": "2.0", "error": ["code": code, "message": message], "id": id]
        return (try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys])) ?? Data()
    }
}

/// Wraps the server's transport and screens each incoming message (see
/// `JSONRPCScreen`), so a malformed line never gets a reply the client
/// cannot correlate.
actor ValidatingTransport: Transport {
    nonisolated let logger: Logger
    private let inner: any Transport

    init(wrapping inner: any Transport) {
        self.inner = inner
        self.logger = Logger(label: "grantiva.mcp.transport")
    }

    func connect() async throws { try await inner.connect() }

    func disconnect() async { await inner.disconnect() }

    func send(_ data: Data) async throws { try await inner.send(JSONRPCScreen.outgoing(data)) }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        let inner = self.inner
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in await inner.receive() {
                        switch JSONRPCScreen.screen(data) {
                        case .forward: continuation.yield(data)
                        case .drop: continue
                        case .reply(let reply): try? await inner.send(reply)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
