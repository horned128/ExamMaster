import SwiftUI

/// Placed only on overview and completed-result screens, never on question/feedback screens.
struct AdBannerPlacement: View {
    let ads: AdsService
    var placement: AdPlacement = .overview
    @State private var banner: AdBanner?
    @State private var loaded = false
    @State private var failed = false

    var body: some View {
        if placement == .overview ? ads.canShowBanner : ads.canShowResultBanner {
            VStack(spacing: 4) {
                if loaded { Text("広告").font(.caption2).foregroundStyle(.secondary) }
                GeometryReader { geometry in
                    if let banner {
                        BannerUIView(view: banner.view)
                            .frame(width: geometry.size.width, height: banner.height)
                    }
                    else { Color.clear }
                    Color.clear.frame(width: 0, height: 0)
                        .task(id: Int(geometry.size.width)) {
                            guard geometry.size.width > 0, banner == nil, !failed else { return }
                            banner = ads.banner(width: geometry.size.width, placement: placement) { succeeded in
                                loaded = succeeded
                                failed = !succeeded
                                if !succeeded { banner = nil }
                            }
                        }
                }
                .frame(height: failed ? 0 : (banner?.height ?? 60))
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("広告")
            .onChange(of: ads.canShowBanner) { wasVisible, isVisible in
                if isVisible && !wasVisible {
                    failed = false
                    loaded = false
                    banner = nil
                }
            }
        }
    }
}

private struct BannerUIView: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
