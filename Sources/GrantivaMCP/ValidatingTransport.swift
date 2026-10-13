import Foundation
import Logging
import MCP

/// What to do with one incoming line before the MCP server sees it.
enum JSONRPCScreen: Equatable {
    /// A well-formed JSON-RPC message (or batch): the server handles it.
    case forward
    /// Malformed input nobody may answer: a message without an id, or a
    /// response (one with `result` or `error`; a response is never answered).
    case drop
    /// Malformed input the transport answers itself.
    case reply(Data)
    /// A batch with some malformed members: the server gets the valid ones
    /// (`forward`), the transport answers the malformed ones (`reply`).
    case split(forward: Data, reply: Data?)

    /// JSON-RPC 2.0 §4-6: text that is not JSON is `-32700` with `"id": null`;
    /// JSON that is not a valid request is `-32600`, echoing the id when it
    /// has one (`null` otherwise, as for an empty batch or a non-object batch
    /// member); a malformed message without an id, and any response, is not
    /// answered. Batch members are screened one by one. The SDK (0.12.1,
    /// the latest release) answers all of these with `-32700` and an
    /// invented UUID id, so they are handled here.
    static func screen(_ data: Data) -> JSONRPCScreen {
        guard let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return .reply(encode(errorObject(code: -32700, message: "Parse error: the message is not valid JSON.", id: NSNull())))
        }
        guard let batch = parsed as? [Any] else {
            switch member(parsed) {
            case .valid: return .forward
            case .silent: return .drop
            case .invalid(let error): return .reply(encode(error))
            }
        }
        guard !batch.isEmpty else {
            return .reply(encode(errorObject(code: -32600, message: "Invalid Request: an empty batch.", id: NSNull())))
        }
        var valid: [Any] = []
        var errors: [Any] = []
        for item in batch {
            switch member(item) {
            case .valid: valid.append(item)
            case .silent: break
            case .invalid(let error): errors.append(error)
            }
        }
        if valid.count == batch.count { return .forward }
        if valid.isEmpty { return errors.isEmpty ? .drop : .reply(encode(errors)) }
        return .split(forward: encode(valid), reply: errors.isEmpty ? nil : encode(errors))
    }

    private enum Member {
        case valid
        case silent
        case invalid([String: Any])
    }

    private static func member(_ value: Any) -> Member {
        guard let object = value as? [String: Any] else {
            return .invalid(errorObject(code: -32600, message: "Invalid Request: expected a JSON-RPC object.", id: NSNull()))
        }
        let isRequestOrNotification = object["method"] is String
        let isResponse = object["result"] != nil || object["error"] != nil
        if object["jsonrpc"] as? String == "2.0", isRequestOrNotification || (isResponse && object["id"] != nil) {
            return .valid
        }
        if isResponse { return .silent }
        let id: Any? = {
            switch object["id"] {
            case let string as String: return string
            case let number as NSNumber where !(number === kCFBooleanTrue || number === kCFBooleanFalse): return number
            default: return nil
            }
        }()
        guard let id else { return .silent }
        return .invalid(errorObject(
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
        return (try? JSONSerialization.data(withJSONObject: object, options: encoding)) ?? data
    }

    private static func errorObject(code: Int, message: String, id: Any) -> [String: Any] {
        ["jsonrpc": "2.0", "error": ["code": code, "message": message], "id": id]
    }

    static let encoding: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]

    private static func encode(_ value: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: value, options: encoding)) ?? Data()
    }
}

/// Wraps the server's transport and screens each incoming message (see
/// `JSONRPCScreen`), so a malformed line never gets a reply the client
/// cannot correlate, and a cancelled request gets no reply at all
/// (`CancellationTracker`).
actor ValidatingTransport: Transport {
    nonisolated let logger: Logger
    private let inner: any Transport
    private var cancellations = CancellationTracker()
    private var sending = false
    private var sendWaiters: [CheckedContinuation<Void, Never>] = []
    /// When a cancel is handed to the SDK again, after the request's task has
    /// had time to register (milliseconds after the first delivery).
    private let cancelRetries: [UInt64]

    init(wrapping inner: any Transport, cancelRetries: [UInt64] = [50, 250, 1000]) {
        self.inner = inner
        self.cancelRetries = cancelRetries
        self.logger = Logger(label: "grantiva.mcp.transport")
    }

    func connect() async throws { try await inner.connect() }

    func disconnect() async { await inner.disconnect() }

    func send(_ data: Data) async throws {
        guard let kept = cancellations.outgoing(data) else { return }
        try await sendWholeMessage(JSONRPCScreen.outgoing(kept))
    }

    /// Actor isolation alone does not serialize an async send: StdioTransport
    /// yields when a partial write fills stdout. Keep ownership until the
    /// entire encoded message (including its newline) has been written.
    /// Validation replies use this same gate as SDK responses/notifications.
    private func sendWholeMessage(_ data: Data) async throws {
        if sending {
            await withCheckedContinuation { sendWaiters.append($0) }
        } else {
            sending = true
        }
        defer {
            if sendWaiters.isEmpty {
                sending = false
            } else {
                sendWaiters.removeFirst().resume()
            }
        }
        try Task.checkCancellation()
        try await inner.send(data)
    }

    /// Notes `data`, then forwards it; a cancel for an unanswered request is
    /// forwarded again on `cancelRetries` while that request is unanswered.
    private func forward(_ data: Data, to continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation) {
        let notes = cancellations.incoming(data)
        continuation.yield(data)
        for case .cancelled(let id, let cancel) in notes {
            let retries = cancelRetries
            Task {
                var elapsed: UInt64 = 0
                for delay in retries {
                    try? await Task.sleep(nanoseconds: (delay - elapsed) * 1_000_000)
                    elapsed = delay
                    guard self.cancellations.isCancelled(id) else { return }
                    continuation.yield(cancel)
                }
                // A grace period for a tool that returns after its task was
                // cancelled (the handler then throws), then let it go.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.forgetCancelled(id)
            }
        }
    }

    private func forgetCancelled(_ id: String) { cancellations.forget(id) }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        let inner = self.inner
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in await inner.receive() {
                        switch JSONRPCScreen.screen(data) {
                        case .forward: self.forward(data, to: continuation)
                        case .drop: continue
                        case .reply(let reply): try? await self.sendWholeMessage(reply)
                        case .split(let valid, let reply):
                            self.forward(valid, to: continuation)
                            if let reply { try? await self.sendWholeMessage(reply) }
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
