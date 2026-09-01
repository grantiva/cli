import Foundation
import GrantivaCore

// MARK: - OrgClient

/// API client for `grantiva console apps`, `console claims` and
/// `console devices list|get` (the `/api/v1/org/*` surface from Phase 2 of
/// the console parity plan). Same closure-struct shape as `ConsoleClient`.
public struct OrgClient: Sendable {
    // Apps
    public var listApps: @Sendable () async throws -> [OrgApp]
    public var createApp: @Sendable (CreateOrgAppRequest) async throws -> OrgApp
    public var getApp: @Sendable (_ appRef: String) async throws -> OrgApp
    public var updateApp: @Sendable (_ appRef: String, UpdateOrgAppRequest) async throws -> OrgApp
    public var deleteApp: @Sendable (_ appRef: String) async throws -> OrgDeleteResponse
    public var activateApp: @Sendable (_ appRef: String) async throws -> OrgApp
    public var deactivateApp: @Sendable (_ appRef: String) async throws -> OrgApp
    public var setPrimaryApp: @Sendable (_ appRef: String) async throws -> OrgApp

    // Claims
    public var listClaims: @Sendable () async throws -> [OrgClaim]
    public var createClaim: @Sendable (OrgClaimDefinition) async throws -> OrgClaim
    public var getClaim: @Sendable (_ claimRef: String) async throws -> OrgClaim
    public var updateClaim: @Sendable (_ claimRef: String, UpdateOrgClaimRequest) async throws -> OrgClaim
    public var deleteClaim: @Sendable (_ claimRef: String) async throws -> OrgDeleteResponse
    public var reorderClaims: @Sendable (ReorderOrgClaimsRequest) async throws -> [OrgClaim]
    public var testClaim: @Sendable (TestOrgClaimRequest) async throws -> OrgClaimTestResponse
    public var previewClaim: @Sendable (_ claimRef: String, PreviewOrgClaimRequest) async throws -> OrgClaimTestResponse

    // Devices
    public var listDevices: @Sendable (OrgDeviceQuery) async throws -> OrgDeviceList
    public var getDevice: @Sendable (_ keyId: String) async throws -> OrgDeviceDetail

    public init(
        listApps: @escaping @Sendable () async throws -> [OrgApp],
        createApp: @escaping @Sendable (CreateOrgAppRequest) async throws -> OrgApp,
        getApp: @escaping @Sendable (String) async throws -> OrgApp,
        updateApp: @escaping @Sendable (String, UpdateOrgAppRequest) async throws -> OrgApp,
        deleteApp: @escaping @Sendable (String) async throws -> OrgDeleteResponse,
        activateApp: @escaping @Sendable (String) async throws -> OrgApp,
        deactivateApp: @escaping @Sendable (String) async throws -> OrgApp,
        setPrimaryApp: @escaping @Sendable (String) async throws -> OrgApp,
        listClaims: @escaping @Sendable () async throws -> [OrgClaim],
        createClaim: @escaping @Sendable (OrgClaimDefinition) async throws -> OrgClaim,
        getClaim: @escaping @Sendable (String) async throws -> OrgClaim,
        updateClaim: @escaping @Sendable (String, UpdateOrgClaimRequest) async throws -> OrgClaim,
        deleteClaim: @escaping @Sendable (String) async throws -> OrgDeleteResponse,
        reorderClaims: @escaping @Sendable (ReorderOrgClaimsRequest) async throws -> [OrgClaim],
        testClaim: @escaping @Sendable (TestOrgClaimRequest) async throws -> OrgClaimTestResponse,
        previewClaim: @escaping @Sendable (String, PreviewOrgClaimRequest) async throws -> OrgClaimTestResponse,
        listDevices: @escaping @Sendable (OrgDeviceQuery) async throws -> OrgDeviceList,
        getDevice: @escaping @Sendable (String) async throws -> OrgDeviceDetail
    ) {
        self.listApps = listApps
        self.createApp = createApp
        self.getApp = getApp
        self.updateApp = updateApp
        self.deleteApp = deleteApp
        self.activateApp = activateApp
        self.deactivateApp = deactivateApp
        self.setPrimaryApp = setPrimaryApp
        self.listClaims = listClaims
        self.createClaim = createClaim
        self.getClaim = getClaim
        self.updateClaim = updateClaim
        self.deleteClaim = deleteClaim
        self.reorderClaims = reorderClaims
        self.testClaim = testClaim
        self.previewClaim = previewClaim
        self.listDevices = listDevices
        self.getDevice = getDevice
    }
}

// MARK: - Convenience Init (live)

extension OrgClient {
    public init(apiKey: String, baseURL: String) {
        let baseURL = URL(string: baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL)!
        let client = NetworkClient.authorized(apiKey: apiKey)

        self.init(
            listApps: { try await client.execute(OrgAppEndpoints.list(), baseURL: baseURL) },
            createApp: { body in try await client.execute(OrgAppEndpoints.create(body: body), baseURL: baseURL) },
            getApp: { ref in try await client.execute(OrgAppEndpoints.detail(appRef: ref), baseURL: baseURL) },
            updateApp: { ref, body in try await client.execute(OrgAppEndpoints.update(appRef: ref, body: body), baseURL: baseURL) },
            deleteApp: { ref in try await client.execute(OrgAppEndpoints.delete(appRef: ref), baseURL: baseURL) },
            activateApp: { ref in try await client.execute(OrgAppEndpoints.activate(appRef: ref), baseURL: baseURL) },
            deactivateApp: { ref in try await client.execute(OrgAppEndpoints.deactivate(appRef: ref), baseURL: baseURL) },
            setPrimaryApp: { ref in try await client.execute(OrgAppEndpoints.setPrimary(appRef: ref), baseURL: baseURL) },
            listClaims: { try await client.execute(OrgClaimEndpoints.list(), baseURL: baseURL) },
            createClaim: { body in try await client.execute(OrgClaimEndpoints.create(body: body), baseURL: baseURL) },
            getClaim: { ref in try await client.execute(OrgClaimEndpoints.detail(claimRef: ref), baseURL: baseURL) },
            updateClaim: { ref, body in try await client.execute(OrgClaimEndpoints.update(claimRef: ref, body: body), baseURL: baseURL) },
            deleteClaim: { ref in try await client.execute(OrgClaimEndpoints.delete(claimRef: ref), baseURL: baseURL) },
            reorderClaims: { body in try await client.execute(OrgClaimEndpoints.reorder(body: body), baseURL: baseURL) },
            testClaim: { body in try await client.execute(OrgClaimEndpoints.test(body: body), baseURL: baseURL) },
            previewClaim: { ref, body in try await client.execute(OrgClaimEndpoints.preview(claimRef: ref, body: body), baseURL: baseURL) },
            listDevices: { query in try await client.execute(OrgDeviceEndpoints.list(query), baseURL: baseURL) },
            getDevice: { keyId in try await client.execute(OrgDeviceEndpoints.detail(keyId: keyId), baseURL: baseURL) }
        )
    }
}

// MARK: - Failing

extension OrgClient {
    public static let failing = OrgClient(
        listApps: { throw GrantivaError.notAuthenticated },
        createApp: { _ in throw GrantivaError.notAuthenticated },
        getApp: { _ in throw GrantivaError.notAuthenticated },
        updateApp: { _, _ in throw GrantivaError.notAuthenticated },
        deleteApp: { _ in throw GrantivaError.notAuthenticated },
        activateApp: { _ in throw GrantivaError.notAuthenticated },
        deactivateApp: { _ in throw GrantivaError.notAuthenticated },
        setPrimaryApp: { _ in throw GrantivaError.notAuthenticated },
        listClaims: { throw GrantivaError.notAuthenticated },
        createClaim: { _ in throw GrantivaError.notAuthenticated },
        getClaim: { _ in throw GrantivaError.notAuthenticated },
        updateClaim: { _, _ in throw GrantivaError.notAuthenticated },
        deleteClaim: { _ in throw GrantivaError.notAuthenticated },
        reorderClaims: { _ in throw GrantivaError.notAuthenticated },
        testClaim: { _ in throw GrantivaError.notAuthenticated },
        previewClaim: { _, _ in throw GrantivaError.notAuthenticated },
        listDevices: { _ in throw GrantivaError.notAuthenticated },
        getDevice: { _ in throw GrantivaError.notAuthenticated }
    )
}
