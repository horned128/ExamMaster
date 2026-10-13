import XCTest
import StoreKit
import StoreKitTest
@testable import NetworkSpecialist

@MainActor final class NetworkProductLoadingTests: XCTestCase {
    func testFailedLoadCanRecoverWithoutRelaunchAndClearsError() async throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        session.clearTransactions()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let id = try Catalog.load(id: "network-specialist").qualification.productID
        let manager = PurchaseManager(productID: id)
        await manager.refresh()
        XCTAssertNil(manager.product)
        XCTAssertNotNil(manager.error)
        XCTAssertFalse(manager.loading)
        XCTAssertFalse(manager.unlocked)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await manager.refresh()
        XCTAssertEqual(manager.product?.id, id)
        XCTAssertEqual(manager.product?.price, 300)
        XCTAssertNil(manager.error)
        XCTAssertFalse(manager.loading)
        session.clearTransactions()
    }

    func testUnavailableProductDoesNotOfferFakePriceOrUnlock() async throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.clearTransactions()
        let manager = PurchaseManager(productID: "jp.test.unavailable.unlock")
        await manager.refresh()
        XCTAssertNil(manager.product)
        XCTAssertNotNil(manager.error)
        XCTAssertFalse(manager.loading)
        XCTAssertFalse(manager.unlocked)
        await manager.buy()
        XCTAssertTrue(session.allTransactions().isEmpty)
    }

    func testVerifiedPurchaseSurvivesProductMetadataFailure() async throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let id = try Catalog.load(id: "network-specialist").qualification.productID
        let manager = PurchaseManager(productID: id)
        await manager.refresh()
        await manager.buy()
        XCTAssertTrue(manager.unlocked)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        await manager.refresh()
        XCTAssertTrue(manager.unlocked)
        XCTAssertNil(manager.product)
        XCTAssertNil(manager.error)
        XCTAssertFalse(manager.loading)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
    }
}
