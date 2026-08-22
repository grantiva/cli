import XCTest
@testable import GrantivaCore

final class SimulatorProvenanceTests: XCTestCase {
    private var directory: String!
    private var provenance: SimulatorProvenance!

    override func setUpWithError() throws {
        directory = NSTemporaryDirectory() + "grantiva-provenance-tests-" + UUID().uuidString
        provenance = SimulatorProvenance(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: directory)
    }

    func testRegisterContainsAndRemove() throws {
        XCTAssertFalse(try provenance.contains(udid: "UDID-1"))
        try provenance.register(udid: "UDID-1", name: "TienLen Flow APP-652")
        XCTAssertTrue(try provenance.contains(udid: "UDID-1"))
        XCTAssertEqual(try provenance.all().map(\.name), ["TienLen Flow APP-652"])

        try provenance.remove(udid: "UDID-1")
        XCTAssertFalse(try provenance.contains(udid: "UDID-1"))
        XCTAssertTrue(try provenance.all().isEmpty)
    }

    func testRegisterIsIdempotentPerUDID() throws {
        try provenance.register(udid: "UDID-1", name: "TienLen Flow APP-652")
        try provenance.register(udid: "UDID-1", name: "TienLen Flow APP-652")
        XCTAssertEqual(try provenance.all().count, 1)
    }

    func testLedgerPersistsAcrossInstances() throws {
        try provenance.register(udid: "UDID-1", name: "TienLen Flow APP-652")
        let reopened = SimulatorProvenance(directory: directory)
        XCTAssertTrue(try reopened.contains(udid: "UDID-1"))
    }

    func testProvisioningLockSerializesCriticalSections() async throws {
        // Two tasks race through the provisioning lock; both observing an
        // empty ledger inside the critical section would mean the ensure
        // look-up/create pair is not actually serialized.
        let provenance = self.provenance!
        var sawEmpty = 0
        for _ in 0..<2 {
            try await provenance.withProvisioningLock {
                if try provenance.all().isEmpty {
                    sawEmpty += 1
                    try provenance.register(udid: UUID().uuidString, name: "raced")
                }
            }
        }
        XCTAssertEqual(sawEmpty, 1)
        XCTAssertEqual(try provenance.all().count, 1)
    }
}
