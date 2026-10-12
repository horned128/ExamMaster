import XCTest
import UIKit
import StoreKitTest
@testable import NetworkSpecialist

/// Uses the real local StoreKit product and a recording provider, not AdMob.
@MainActor private final class RecordingNetworkAdProvider: AdProvider {
    var privacyOptionsRequired = true
    private(set) var preparations = 0
    private(set) var banners = 0
    private(set) var loads = 0
    private(set) var presentations = 0
    private(set) var stops = 0

    func prepare(isSafe: @escaping @MainActor () -> Bool) async -> Bool {
        preparations += 1
        return isSafe()
    }

    func makeBanner(width: CGFloat, unitID: String, onLoad: @escaping @MainActor (Bool) -> Void) -> AdBanner? {
        banners += 1
        onLoad(true)
        return AdBanner(view: UIView(), height: 50)
    }

    func preloadInterstitial(unitID: String) async -> Bool { loads += 1; return true }
    func presentInterstitial() -> Bool { presentations += 1; return true }
    func presentPrivacyOptions() async -> Bool { true }
    func stop() { stops += 1 }
}

@MainActor final class NetworkPurchaseAdsTests: XCTestCase {
    func testLocalPurchaseAndRestoreStopAllAdRequestsWithRealPaidCatalog() async throws {
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let catalog = try Catalog.load(id: "network-specialist")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = RecordingNetworkAdProvider()
        let service = AdsService(configuration: catalog.qualification.ads, qualificationID: catalog.qualification.id,
                                 provider: provider,
                                 frequency: AdFrequencyStore(qualificationID: catalog.qualification.id, directory: directory))
        let purchase = PurchaseManager(productID: catalog.qualification.productID)
        // Match the app's access snapshot, with the home screen available.
        func access(_ manager: PurchaseManager) -> AdAccess {
            .init(entitlementResolved: manager.entitlementResolved, unlocked: manager.unlocked,
                  purchasing: manager.purchasing, safeScreen: true)
        }
        service.updateAccess(.init(entitlementResolved: false, unlocked: false, purchasing: false, safeScreen: true))
        XCTAssertEqual(provider.preparations, 0)
        XCTAssertNil(service.banner(width: 320) { _ in })
        await purchase.refresh()
        XCTAssertFalse(purchase.unlocked)
        XCTAssertEqual(purchase.product?.price, 480)
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: purchase.unlocked).count, 75)
        service.updateAccess(access(purchase))
        for _ in 0..<100 {
            if service.ready && provider.loads > 0 { break }
            await Task.yield()
        }
        XCTAssertTrue(service.canShowBanner)
        XCTAssertTrue(service.canShowResultBanner)
        XCTAssertNotNil(service.banner(width: 320) { _ in })
        XCTAssertNotNil(service.banner(width: 320, placement: .sessionResult) { _ in })
        XCTAssertEqual(provider.banners, 2)
        XCTAssertGreaterThan(provider.loads, 0)

        // The purchase sheet suppresses requests before entitlement changes.
        service.updateAccess(.init(entitlementResolved: true, unlocked: false, purchasing: true, safeScreen: false))
        XCTAssertFalse(service.ready)
        XCTAssertNil(service.banner(width: 320, placement: .sessionResult) { _ in })
        await purchase.buy()
        await purchase.refreshEntitlement()
        XCTAssertTrue(purchase.unlocked)
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: purchase.unlocked).count, catalog.questions.count)
        service.updateAccess(access(purchase))
        let preparations = provider.preparations
        let loads = provider.loads
        let stopped = provider.stops
        for mode in [StudyMode.year, .recommended, .mock] {
            XCTAssertNil(service.banner(width: 320) { _ in })
            XCTAssertNil(service.banner(width: 320, placement: .sessionResult) { _ in })
            service.completedSession(mode: mode, answered: 25)
        }
        XCTAssertFalse(service.canShowBanner)
        XCTAssertFalse(service.canShowResultBanner)
        XCTAssertFalse(service.canShowPrivacyOptions)
        XCTAssertEqual(provider.banners, 2)
        XCTAssertEqual(provider.presentations, 0)

        let restored = PurchaseManager(productID: catalog.qualification.productID)
        await restored.restore()
        XCTAssertTrue(restored.unlocked)
        service.updateAccess(access(restored))
        await Task.yield()
        XCTAssertEqual(provider.preparations, preparations)
        XCTAssertEqual(provider.loads, loads)
        XCTAssertGreaterThan(provider.stops, stopped)
        XCTAssertNil(service.banner(width: 320) { _ in })
        XCTAssertFalse(service.canShowResultBanner)
        XCTAssertEqual(AdFrequencyStore(qualificationID: catalog.qualification.id, directory: directory).state.completedSinceLastAd, 0)
    }
}
