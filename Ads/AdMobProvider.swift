import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

// The sole module that knows Google's types. No ad or consent call is made at initialization.
@MainActor final class AdMobProvider: NSObject, AdProvider, FullScreenContentDelegate {
    private(set) var privacyOptionsRequired = false
    private var active = false
    private var initialized = false
    private var interstitial: InterstitialAd?
    private var loadedAt: Date?
    private let banners = NSHashTable<AdMobBannerHost>.weakObjects()

    func prepare(isSafe: @escaping @MainActor () -> Bool) async -> Bool {
        guard isSafe() else { return false }
        let consent = ConsentInformation.shared
        do {
            try await consent.requestConsentInfoUpdate(with: RequestParameters())
        } catch {
            // Google's prior-session state can still allow ads after an offline update failure.
        }
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
        guard isSafe() else { return false }
        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // canRequestAds is authoritative, including after a form loading error.
        }
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
        guard isSafe(), consent.canRequestAds else { return false }
        // This app permits Google's advertising SDK to use IDFA only if Apple authorizes it.
        // A refusal never restricts studying or contextual ads.
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        guard isSafe() else { return false }
        if !initialized {
            await MobileAds.shared.start()
            initialized = true
        }
        guard isSafe() else { return false }
        active = true
        return true
    }

    func makeBanner(width: CGFloat, unitID: String, onLoad: @escaping @MainActor (Bool) -> Void) -> AdBanner? {
        guard active else { return nil }
        let size = largeAnchoredAdaptiveBanner(width: width)
        let host = AdMobBannerHost(adSize: size, unitID: unitID, onLoad: onLoad)
        banners.add(host)
        return AdBanner(view: host, height: size.size.height)
    }

    func preloadInterstitial(unitID: String) async -> Bool {
        guard active else { return false }
        do {
            let ad = try await InterstitialAd.load(with: unitID, request: Request())
            guard active else { return false }
            ad.fullScreenContentDelegate = self
            interstitial = ad
            loadedAt = .now
            return true
        } catch {
            interstitial = nil
            return false
        }
    }

    func presentInterstitial() -> Bool {
        guard active, let interstitial, let loadedAt,
              Date().timeIntervalSince(loadedAt) < 3_600,
              (try? interstitial.canPresent(from: nil)) != nil else { return false }
        self.interstitial = nil // A full-screen ad is single-use.
        interstitial.present(from: nil)
        return true
    }

    func presentPrivacyOptions() async -> Bool {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            // Remain on the free experience even if the form is unavailable offline.
        }
        let consent = ConsentInformation.shared
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
        return consent.canRequestAds
    }

    func stop() {
        active = false
        interstitial = nil
        loadedAt = nil
        for host in banners.allObjects { host.cancel() }
        banners.removeAllObjects()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitial = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
    }
}

@MainActor private final class AdMobBannerHost: UIView, BannerViewDelegate {
    private let banner: BannerView
    private let onLoad: @MainActor (Bool) -> Void

    init(adSize: AdSize, unitID: String, onLoad: @escaping @MainActor (Bool) -> Void) {
        banner = BannerView(adSize: adSize)
        self.onLoad = onLoad
        super.init(frame: CGRect(origin: .zero, size: adSize.size))
        banner.adUnitID = unitID
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: centerYAnchor),
            banner.widthAnchor.constraint(equalToConstant: adSize.size.width),
            banner.heightAnchor.constraint(equalToConstant: adSize.size.height)
        ])
        banner.load(Request())
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func cancel() {
        banner.delegate = nil
        banner.removeFromSuperview()
        onLoad(false)
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) { onLoad(true) }
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) { onLoad(false) }
}
