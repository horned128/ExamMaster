import XCTest
import StoreKitTest
@testable import ExamMaster

final class StoreKitTests: XCTestCase {
    func testLocalNonConsumableConfigurationMatchesQualification() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "products", withExtension: "storekit"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let products = try XCTUnwrap(json["products"] as? [[String: Any]])
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?["productID"] as? String, catalog.qualification.productID)
        XCTAssertEqual(products.first?["type"] as? String, "NonConsumable")
        let session = try SKTestSession(configurationFileNamed: "products")
        XCTAssertTrue(session.allTransactions().isEmpty)
    }

    @MainActor func testPurchaseAndRestoreFromLocalStoreKitSession() async throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        session.clearTransactions()
        let id = "jp.example.exammaster.demo.unlock"
        let manager = PurchaseManager(productID: id)
        await manager.refresh()
        XCTAssertNotNil(manager.product)
        XCTAssertFalse(manager.unlocked)
        await manager.buy()
        await manager.refreshEntitlement()
        XCTAssertTrue(manager.unlocked, manager.error ?? "購入状態が反映されませんでした")
        let restored = PurchaseManager(productID: id)
        await restored.restore()
        XCTAssertTrue(restored.unlocked, restored.error ?? "購入を復元できませんでした")
        session.clearTransactions()
        await restored.refreshEntitlement()
        XCTAssertFalse(restored.unlocked)
    }
}
