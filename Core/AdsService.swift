import Foundation
import Observation
import UIKit

struct AdAccess: Equatable {
    let entitlementResolved: Bool
    let unlocked: Bool
    let purchasing: Bool
    let safeScreen: Bool

    var permitsRequests: Bool { entitlementResolved && !unlocked && !purchasing }
}

struct AdBanner {
    let view: UIView
    let height: CGFloat
}

enum AdPlacement { case overview, sessionResult }

@MainActor protocol AdProvider: AnyObject {
    var privacyOptionsRequired: Bool { get }
    func prepare(isSafe: @escaping @MainActor () -> Bool) async -> Bool
    func makeBanner(width: CGFloat, unitID: String, onLoad: @escaping @MainActor (Bool) -> Void) -> AdBanner?
    func preloadInterstitial(unitID: String) async -> Bool
    func presentInterstitial() -> Bool
    func presentPrivacyOptions() async -> Bool
    func stop()
}

struct AdFrequencyState: Codable, Equatable {
    var completedSinceLastAd = 0
    var lastPresented: Date?
}

enum AdFrequencyPolicy {
    static func qualifies(_ mode: StudyMode, answered: Int, settings: AdsConfiguration) -> Bool {
        mode != .diagnostic && answered >= settings.interstitialMinimumAnsweredQuestions
    }

    static func mayPresent(_ state: AdFrequencyState, settings: AdsConfiguration, now: Date) -> Bool {
        guard state.completedSinceLastAd >= settings.interstitialMinimumSessions else { return false }
        guard let last = state.lastPresented else { return true }
        // Clock adjustments never bypass the cooldown.
        return now.timeIntervalSince(last) >= Double(settings.interstitialMinimumIntervalSeconds)
    }
}

@MainActor final class AdFrequencyStore {
    private(set) var state: AdFrequencyState
    private(set) var error: String?
    private let url: URL

    init(qualificationID: String, directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = base.appendingPathComponent("ad-frequency-\(qualificationID).json")
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            state = FileManager.default.fileExists(atPath: url.path)
                ? try JSONDecoder().decode(AdFrequencyState.self, from: Data(contentsOf: url)) : AdFrequencyState()
        } catch {
            state = AdFrequencyState()
            self.error = "広告の表示間隔を読み込めませんでした。広告の全画面表示を停止しました。"
        }
    }

    @discardableResult func complete() -> Bool {
        guard error == nil else { return false }
        state.completedSinceLastAd += 1
        return save()
    }

    @discardableResult func markPresented(at date: Date) -> Bool {
        guard error == nil else { return false }
        state.completedSinceLastAd = 0
        state.lastPresented = date
        return save()
    }

    @discardableResult private func save() -> Bool {
        do {
            try JSONEncoder().encode(state).write(to: url, options: .atomic)
            return true
        } catch {
            self.error = "広告の表示間隔を保存できませんでした。広告の全画面表示を停止しました。"
            return false
        }
    }
}

// No SDK types cross this boundary; replace AdMobProvider with a no-op or another provider.
@MainActor @Observable final class AdsService {
    private(set) var ready = false
    private(set) var privacyOptionsRequired = false
    private(set) var error: String?
    let configuration: AdsConfiguration
    @ObservationIgnored private let provider: any AdProvider
    @ObservationIgnored private let frequency: AdFrequencyStore
    @ObservationIgnored private var access = AdAccess(entitlementResolved: false, unlocked: false, purchasing: false, safeScreen: false)
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var preparing = false
    @ObservationIgnored private var interstitialLoaded = false
    @ObservationIgnored private var interstitialLoading = false

    init(configuration: AdsConfiguration, qualificationID: String, provider: any AdProvider,
         frequency: AdFrequencyStore? = nil) {
        self.configuration = configuration
        self.provider = provider
        self.frequency = frequency ?? AdFrequencyStore(qualificationID: qualificationID)
    }

    var canShowBanner: Bool { ready && access.safeScreen && configuration.bannerEnabled }
    var canShowResultBanner: Bool { ready && access.permitsRequests && configuration.bannerEnabled }
    var canShowPrivacyOptions: Bool { !access.unlocked && privacyOptionsRequired && configuration.enabled }

    func updateAccess(_ next: AdAccess) {
        access = next
        #if DEBUG
        let disabledForUITests = ProcessInfo.processInfo.arguments.contains("-UITestDisableAds")
        #else
        let disabledForUITests = false
        #endif
        guard next.permitsRequests, configuration.enabled, !disabledForUITests,
              AdUnitSelection.isConfiguredForBuild(configuration) else {
            generation += 1
            ready = false
            preparing = false
            interstitialLoaded = false
            interstitialLoading = false
            privacyOptionsRequired = false
            provider.stop()
            return
        }
        guard next.safeScreen else {
            if preparing && !ready {
                generation += 1
                preparing = false
                provider.stop()
            }
            return
        }
        if ready { preloadIfNeeded(); return }
        guard !preparing else { return }
        preparing = true
        generation += 1
        let attempt = generation
        Task { [weak self] in
            guard let self else { return }
            let permitted = await self.provider.prepare { [weak self] in
                guard let self else { return false }
                return self.generation == attempt && self.access.permitsRequests && self.access.safeScreen
            }
            guard self.generation == attempt, self.access.permitsRequests, self.access.safeScreen else { return }
            self.preparing = false
            self.privacyOptionsRequired = self.provider.privacyOptionsRequired
            self.ready = permitted
            self.error = permitted ? nil : "広告は現在表示できません。学習はそのまま続けられます。"
            if permitted { self.preloadIfNeeded() }
        }
    }

    func banner(width: CGFloat, placement: AdPlacement = .overview,
                onLoad: @escaping @MainActor (Bool) -> Void) -> AdBanner? {
        guard (placement == .overview ? canShowBanner : canShowResultBanner), width > 0 else { return nil }
        return provider.makeBanner(width: width, unitID: AdUnitSelection.banner(configuration), onLoad: onLoad)
    }

    func completedSession(mode: StudyMode, answered: Int, now: Date = .now) {
        guard ready, access.permitsRequests, access.safeScreen, configuration.interstitialEnabled,
              AdFrequencyPolicy.qualifies(mode, answered: answered, settings: configuration),
              frequency.complete() else { return }
        guard AdFrequencyPolicy.mayPresent(frequency.state, settings: configuration, now: now),
              interstitialLoaded, frequency.markPresented(at: now) else { return }
        interstitialLoaded = false
        _ = provider.presentInterstitial() // A failed/expired ad still consumes this opportunity.
        preloadIfNeeded()
    }

    func presentPrivacyOptions() async {
        // Settings is presented as a sheet; an explicit user action can show UMP over it.
        guard canShowPrivacyOptions else { return }
        let permitted = await provider.presentPrivacyOptions()
        privacyOptionsRequired = provider.privacyOptionsRequired
        ready = permitted && access.permitsRequests
        if !ready { provider.stop(); interstitialLoaded = false }
        else { preloadIfNeeded() }
    }

    func retry() {
        guard access.permitsRequests, access.safeScreen else { return }
        updateAccess(access)
    }

    private func preloadIfNeeded() {
        guard ready, access.safeScreen, configuration.interstitialEnabled, !interstitialLoaded else { return }
        guard !interstitialLoading else { return }
        interstitialLoading = true
        let attempt = generation
        Task { [weak self] in
            guard let self else { return }
            let loaded = await self.provider.preloadInterstitial(unitID: AdUnitSelection.interstitial(self.configuration))
            guard self.generation == attempt, self.ready, self.access.permitsRequests else { return }
            self.interstitialLoading = false
            self.interstitialLoaded = loaded
        }
    }
}

enum AdUnitSelection {
    static let sampleAppID = "ca-app-pub-3940256099942544~1458002511"
    static let sampleBannerID = "ca-app-pub-3940256099942544/2435281174"
    static let sampleInterstitialID = "ca-app-pub-3940256099942544/4411468910"

    static func isConfiguredForBuild(_ settings: AdsConfiguration) -> Bool {
        #if DEBUG
        return true
        #else
        return settings.adMobAppID != sampleAppID &&
            (!settings.bannerEnabled || settings.bannerAdUnitID != sampleBannerID) &&
            (!settings.interstitialEnabled || settings.interstitialAdUnitID != sampleInterstitialID)
        #endif
    }

    static func banner(_ settings: AdsConfiguration) -> String {
        #if DEBUG
        return sampleBannerID
        #else
        return settings.bannerAdUnitID
        #endif
    }

    static func interstitial(_ settings: AdsConfiguration) -> String {
        #if DEBUG
        return sampleInterstitialID
        #else
        return settings.interstitialAdUnitID
        #endif
    }
}
