import XCTest
import UIKit
@testable import ExamMaster

@MainActor private final class FakeAdProvider: AdProvider {
    var prepareCalls = 0
    var bannerRequests = 0
    var interstitialLoads = 0
    var presentations = 0
    var stopCalls = 0
    var allowAds = true
    var loadSucceeds = true
    var privacyOptionsRequired = false

    func prepare(isSafe: @escaping @MainActor () -> Bool) async -> Bool {
        prepareCalls += 1
        return allowAds && isSafe()
    }
    func makeBanner(width: CGFloat, unitID: String, onLoad: @escaping @MainActor (Bool) -> Void) -> AdBanner? {
        bannerRequests += 1
        onLoad(loadSucceeds)
        return loadSucceeds ? AdBanner(view: UIView(), height: 50) : nil
    }
    func preloadInterstitial(unitID: String) async -> Bool {
        interstitialLoads += 1
        return loadSucceeds
    }
    func presentInterstitial() -> Bool {
        guard loadSucceeds else { return false }
        presentations += 1
        return true
    }
    func presentPrivacyOptions() async -> Bool { allowAds }
    func stop() { stopCalls += 1 }
}

@MainActor final class AdsServiceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private let allowed = AdAccess(entitlementResolved: true, unlocked: false, purchasing: false, safeScreen: true)

    private func makeService(_ provider: FakeAdProvider, directory: URL) throws -> AdsService {
        let config = try Catalog.load(id: "demo-safety").qualification.ads
        return AdsService(configuration: config, qualificationID: "demo-safety", provider: provider,
                          frequency: AdFrequencyStore(qualificationID: "demo-safety", directory: directory))
    }

    private func waitForActivation(_ service: AdsService) async {
        for _ in 0..<50 { if service.ready { return }; await Task.yield() }
    }

    func testNoRequestsBeforeEntitlementOrForPurchaserAndRestorationStopsAds() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = FakeAdProvider()
        let service = try makeService(provider, directory: directory)
        service.updateAccess(.init(entitlementResolved: false, unlocked: false, purchasing: false, safeScreen: true))
        XCTAssertFalse(service.canShowBanner)
        XCTAssertEqual(provider.prepareCalls, 0)
        service.updateAccess(allowed)
        await waitForActivation(service)
        XCTAssertTrue(service.canShowBanner)
        service.updateAccess(.init(entitlementResolved: true, unlocked: false, purchasing: true, safeScreen: true))
        XCTAssertFalse(service.ready)
        XCTAssertNil(service.banner(width: 320) { _ in })
        service.updateAccess(.init(entitlementResolved: true, unlocked: true, purchasing: false, safeScreen: true))
        XCTAssertFalse(service.ready)
        XCTAssertFalse(service.canShowBanner)
        XCTAssertNil(service.banner(width: 320) { _ in })
        service.completedSession(mode: .recommended, answered: 12, now: start)
        XCTAssertEqual(provider.presentations, 0)
        XCTAssertGreaterThan(provider.stopCalls, 0)
        XCTAssertEqual(provider.bannerRequests, 0)
    }

    func testFailedConsentAndBannerDoNotBlockStudying() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = FakeAdProvider()
        provider.allowAds = false
        let service = try makeService(provider, directory: directory)
        service.updateAccess(allowed)
        for _ in 0..<30 { await Task.yield() }
        XCTAssertFalse(service.ready)
        XCTAssertNotNil(service.error)
        XCTAssertNil(service.banner(width: 300) { _ in })
        provider.allowAds = true
        provider.loadSucceeds = false
        service.retry()
        await waitForActivation(service)
        XCTAssertTrue(service.ready)
        var loaded = true
        XCTAssertNil(service.banner(width: 320) { loaded = $0 })
        XCTAssertFalse(loaded)
        XCTAssertEqual(provider.bannerRequests, 1)
        service.completedSession(mode: .recommended, answered: 12, now: start)
        XCTAssertEqual(provider.presentations, 0)
    }

    func testCooldownAndCompletedSessionsPersistAcrossRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = FakeAdProvider()
        let service = try makeService(provider, directory: directory)
        service.updateAccess(allowed)
        await waitForActivation(service)
        for _ in 0..<20 { await Task.yield() } // Let the interstitial pre-load finish.
        service.completedSession(mode: .diagnostic, answered: 12, now: start)
        service.completedSession(mode: .recommended, answered: 3, now: start)
        XCTAssertEqual(provider.presentations, 0)
        service.completedSession(mode: .recommended, answered: 10, now: start)
        service.completedSession(mode: .mock, answered: 10, now: start)
        XCTAssertEqual(provider.presentations, 0)
        service.completedSession(mode: .recommended, answered: 10, now: start)
        XCTAssertEqual(provider.presentations, 1)
        let state = AdFrequencyStore(qualificationID: "demo-safety", directory: directory).state
        XCTAssertEqual(state.completedSinceLastAd, 0)
        XCTAssertEqual(state.lastPresented, start)
        service.completedSession(mode: .recommended, answered: 10, now: start.addingTimeInterval(10))
        service.completedSession(mode: .recommended, answered: 10, now: start.addingTimeInterval(20))
        service.completedSession(mode: .recommended, answered: 10, now: start.addingTimeInterval(30))
        XCTAssertEqual(provider.presentations, 1)
        let restored = AdFrequencyStore(qualificationID: "demo-safety", directory: directory)
        XCTAssertEqual(restored.state.completedSinceLastAd, 3)
        XCTAssertFalse(AdFrequencyPolicy.mayPresent(restored.state, settings: service.configuration, now: start.addingTimeInterval(1_799)))
        XCTAssertTrue(AdFrequencyPolicy.mayPresent(restored.state, settings: service.configuration, now: start.addingTimeInterval(1_800)))
        XCTAssertFalse(AdFrequencyPolicy.mayPresent(restored.state, settings: service.configuration, now: start.addingTimeInterval(-100)))
    }

    func testConfigAndSampleIdentifiers() throws {
        let demo = try Catalog.load(id: "demo-safety").qualification.ads
        XCTAssertTrue(demo.isValid)
        XCTAssertTrue(demo.interstitialEnabled)
        XCTAssertEqual(AdUnitSelection.banner(demo), AdUnitSelection.sampleBannerID)
        XCTAssertEqual(AdUnitSelection.interstitial(demo), AdUnitSelection.sampleInterstitialID)
        XCTAssertTrue(AdUnitSelection.isConfiguredForBuild(demo))
        let invalid = AdsConfiguration(enabled: true, bannerEnabled: true, interstitialEnabled: true,
                                       interstitialMinimumIntervalSeconds: 0,
                                       interstitialMinimumSessions: 1, interstitialMinimumAnsweredQuestions: 1,
                                       adMobAppID: demo.adMobAppID, bannerAdUnitID: demo.bannerAdUnitID,
                                       interstitialAdUnitID: demo.interstitialAdUnitID)
        XCTAssertFalse(invalid.isValid)
    }

    func testRevokedPrivacyConsentRemovesBannerAndInterstitial() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = FakeAdProvider()
        provider.privacyOptionsRequired = true
        let service = try makeService(provider, directory: directory)
        service.updateAccess(allowed)
        await waitForActivation(service)
        XCTAssertTrue(service.canShowPrivacyOptions)
        provider.allowAds = false
        await service.presentPrivacyOptions()
        XCTAssertFalse(service.canShowBanner)
        XCTAssertFalse(service.ready)
        service.completedSession(mode: .recommended, answered: 12, now: start)
        XCTAssertEqual(provider.presentations, 0)
    }

    func testCorruptFrequencyDataFailsClosedWithoutTouchingStudyData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("ad-frequency-demo-safety.json")
        let broken = Data("invalid".utf8)
        try broken.write(to: url)
        let store = AdFrequencyStore(qualificationID: "demo-safety", directory: directory)
        XCTAssertNotNil(store.error)
        XCTAssertFalse(store.complete())
        XCTAssertEqual(try Data(contentsOf: url), broken)
    }
}
