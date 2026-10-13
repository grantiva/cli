import Foundation
import MCP

/// Which requests the client cancelled with `notifications/cancelled`, so
/// none of them is answered (L14).
///
/// The SDK cancels a request's task only when that task has already
/// registered itself; a cancel that arrives right behind its request finds
/// nothing and is ignored, and the request is answered anyway. The transport
/// sees both lines in order, so it keeps the books here: a cancelled id's
/// response is dropped on the way out, and the cancel is handed to the SDK
/// again shortly after, by which time the request's task has registered and
/// is stopped. Only ids of requests that are still unanswered count: a
/// cancel for an unknown or finished id changes nothing.
struct CancellationTracker: Sendable {
    private var pending: Set<String> = []
    private var cancelled: Set<String> = []
    private var queuedResponses: [String: Int] = [:]

    enum Incoming: Equatable {
        case none
        /// A cancel for an unanswered request (its id, and the notification
        /// alone, even when it came in a batch): hand it to the SDK again later.
        case cancelled(String, Data)
    }

    /// Notes one incoming message (or each member of a batch).
    mutating func incoming(_ data: Data) -> [Incoming] {
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let members = (parsed as? [Any]) ?? [parsed]
        return members.compactMap { member in
            guard let object = member as? [String: Any], let method = object["method"] as? String else { return nil }
            if let id = Self.key(object["id"]) {
                pending.insert(id)
                return Incoming.none
            }
            guard method == CancelledNotification.name,
                  let params = object["params"] as? [String: Any],
                  let id = Self.key(params["requestId"]), pending.contains(id) else { return nil }
            cancelled.insert(id)
            let alone = (try? JSONSerialization.data(withJSONObject: object, options: JSONRPCScreen.encoding)) ?? data
            return .cancelled(id, alone)
        }
    }

    /// The outgoing message with every response to a cancelled request
    /// removed; nil when nothing is left to send.
    mutating func outgoing(_ data: Data) -> Data? {
        guard !pending.isEmpty || !cancelled.isEmpty,
              let parsed = try? JSONSerialization.jsonObject(with: data) else { return data }
        func keep(_ member: Any) -> Bool {
            guard let object = member as? [String: Any], object["method"] == nil,
                  let id = Self.key(object["id"]) else { return true }
            pending.remove(id)
            return cancelled.remove(id) == nil
        }
        guard let batch = parsed as? [Any] else { return keep(parsed) ? data : nil }
        let kept = batch.filter(keep)
        if kept.count == batch.count { return data }
        guard !kept.isEmpty else { return nil }
        return try? JSONSerialization.data(withJSONObject: kept, options: JSONRPCScreen.encoding)
    }

    /// Whether `id` is still a cancelled, unanswered request.
    func isCancelled(_ id: String) -> Bool { cancelled.contains(id) }

    /// A completed handler's response may wait behind stdout backpressure
    /// longer than the SDK cancellation grace period. Own its bookkeeping
    /// until the write gate can screen it, including responses in a batch.
    mutating func retainQueuedResponse(_ data: Data) -> [String] {
        guard !pending.isEmpty,
              let parsed = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let members = (parsed as? [Any]) ?? [parsed]
        let ids = members.compactMap { member -> String? in
            guard let object = member as? [String: Any], object["method"] == nil,
                  let id = Self.key(object["id"]), pending.contains(id) else { return nil }
            return id
        }
        for id in ids { queuedResponses[id, default: 0] += 1 }
        return ids
    }

    /// Release on every gate outcome, including task cancellation/failure
    /// before outgoing screening. No response is left to clear those IDs.
    mutating func releaseQueuedResponse(_ ids: [String]) {
        for id in ids {
            guard let count = queuedResponses[id] else { continue }
            if count > 1 { queuedResponses[id] = count - 1 }
            else {
                queuedResponses.removeValue(forKey: id)
                forget(id)
            }
        }
    }

    /// Drops `id` once the SDK has had every chance to stop it: a request
    /// it cancelled is never answered, so no response would remove it.
    mutating func forget(_ id: String) {
        guard queuedResponses[id] == nil else { return }
        pending.remove(id)
        cancelled.remove(id)
    }

    /// A JSON-RPC id as one string: numbers and strings never collide.
    static func key(_ value: Any?) -> String? {
        switch value {
        case let string as String: return "s:\(string)"
        case let number as NSNumber where !(number === kCFBooleanTrue || number === kCFBooleanFalse): return "n:\(number)"
        default: return nil
        }
    }
}

@available(macOS 15, *)
extension GrantivaMCPServer {
    /// Registers the `tools/call` handler. A call whose task the SDK
    /// cancelled while it ran ends with `CancellationError` (so the SDK sends
    /// nothing) even when the tool itself returned a result; the transport
    /// drops whatever else a cancelled request would get (`CancellationTracker`).
    static func registerToolCalls(
        on server: Server,
        call: @escaping @Sendable (String, [String: Value]) async throws -> CallTool.Result
    ) async {
        await server.withMethodHandler(CallTool.self) { params in
            try Task.checkCancellation()
            let result = try await call(params.name, params.arguments ?? [:])
            try Task.checkCancellation()
            return result
        }
    }
}
