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
        await detach()
        let attachment = try await attach(session)
        attached = (session, attachment)
        return Current(driver: attachment.client, session: session)
    }

    func detach() async {
        guard let attached else { return }
        self.attached = nil
        await attached.attachment.detach()
    }

    private static func isSame(_ a: RunnerSessionInfo, _ b: RunnerSessionInfo) -> Bool {
        a.pid == b.pid && a.wdaPort == b.wdaPort && a.udid == b.udid
    }
}
