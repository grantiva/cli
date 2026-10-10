import Foundation
import GrantivaCore

/// The runner session and driver the UI tools act on. The session is
/// resolved on every use and the driver attached on first use, so the server
/// starts without a session, picks one up once it is started, and re-attaches
/// when it is replaced.
@available(macOS 15, *)
actor RunnerConnection {
    struct Current: Sendable {
        let driver: DriverClient
        let session: RunnerSessionInfo
    }

    private let resolveSession: @Sendable () throws -> RunnerSessionInfo
    private let attach: @Sendable (RunnerSessionInfo) async throws -> DriverAttachment
    private var attached: (session: RunnerSessionInfo, attachment: DriverAttachment)?
    /// The attach in progress. The server handles requests concurrently and
    /// this actor suspends while attaching, so concurrent first calls share
    /// one attach instead of each attaching (and leaking an adb forward).
    private var inFlight: (session: RunnerSessionInfo, task: Task<DriverAttachment, Error>)?
    /// Attaches that `detach()` took over while they were in flight; their
    /// callers must not store the result.
    private var claimed: Set<Task<DriverAttachment, Error>> = []

    init(
        resolveSession: @escaping @Sendable () throws -> RunnerSessionInfo,
        attach: @escaping @Sendable (RunnerSessionInfo) async throws -> DriverAttachment
    ) {
        self.resolveSession = resolveSession
        self.attach = attach
    }

    /// A connection that always yields `driver` and `session`; for tests.
    static func fixed(driver: DriverClient, session: RunnerSessionInfo) -> RunnerConnection {
        RunnerConnection(
            resolveSession: { session },
            attach: { _ in DriverAttachment(client: driver, port: Int(session.wdaPort), detach: {}) }
        )
    }

    /// The live session, if any, without attaching a driver.
    func session() -> RunnerSessionInfo? {
        try? resolveSession()
    }

    /// The live session and an attached driver. Throws the "No active runner
    /// session" error when there is none.
    func current() async throws -> Current {
        let session: RunnerSessionInfo
        do {
            session = try resolveSession()
        } catch {
            await detach()
            throw error
        }
        if let attached, Self.isSame(attached.session, session) {
            return Current(driver: attached.attachment.client, session: attached.session)
        }
        if let inFlight, Self.isSame(inFlight.session, session) {
            return Current(driver: try await inFlight.task.value.client, session: session)
        }

        let attach = self.attach
        let task = Task { try await attach(session) }
        inFlight = (session, task)
        let attachment: DriverAttachment
        do {
            attachment = try await task.value
        } catch {
            if inFlight?.task == task { inFlight = nil }
            claimed.remove(task)
            throw error
        }
        if inFlight?.task == task { inFlight = nil }
        if claimed.remove(task) != nil {
            // detach() ran while this attach was in flight and released it.
            throw GrantivaError.invalidArgument("The runner connection was closed while attaching.")
        }
        let stale = attached
        attached = (session, attachment)
        if let stale { await stale.attachment.detach() }
        return Current(driver: attachment.client, session: session)
    }

    /// Releases the attachment, including one still being attached.
    func detach() async {
        if let pending = inFlight {
            inFlight = nil
            claimed.insert(pending.task)
            if let attachment = try? await pending.task.value {
                await attachment.detach()
            }
        }
        guard let attached else { return }
        self.attached = nil
        await attached.attachment.detach()
    }

    private static func isSame(_ a: RunnerSessionInfo, _ b: RunnerSessionInfo) -> Bool {
        a.pid == b.pid && a.wdaPort == b.wdaPort && a.udid == b.udid
    }
}
