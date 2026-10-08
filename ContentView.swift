import SwiftUI

struct ContentView: View {
    private let catalog: Catalog?
    private let loadError: String?

    init() {
        do {
            guard let id = Bundle.main.object(forInfoDictionaryKey: "QualificationID") as? String else {
                throw CatalogError.invalid("アプリの資格IDが設定されていません")
            }
            catalog = try Catalog.load(id: id)
            loadError = nil
        } catch {
            catalog = nil
            loadError = error.localizedDescription
        }
    }

    var body: some View {
        if let catalog {
            StudyAppView(catalog: catalog)
        } else {
            ContentUnavailableView("問題集を開けません", systemImage: "exclamationmark.triangle",
                                   description: Text(loadError ?? "資格データを確認してください"))
        }
    }
}

struct StudyAppView: View {
    private enum MainTab: Hashable { case home, finder, insights }
    let catalog: Catalog
    @State private var store: StudyStore
    @State private var purchase: PurchaseManager
    @State private var ads: AdsService
    @State private var session: StudySession?
    @State private var completedForAds: (mode: StudyMode, answered: Int)?
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var queuedPaywall = false
    @State private var selectedTab: MainTab = .home
    @State private var replacement: StudySession?
    @State private var confirmReplacement = false
    @State private var resumeUnavailable = false

    init(catalog: Catalog) {
        self.catalog = catalog
        _store = State(initialValue: StudyStore(qualificationID: catalog.qualification.id))
        _purchase = State(initialValue: PurchaseManager(productID: catalog.qualification.productID))
        _ads = State(initialValue: AdsService(configuration: catalog.qualification.ads,
                                              qualificationID: catalog.qualification.id,
                                              provider: AdMobProvider()))
    }

    private var adAccess: AdAccess {
        AdAccess(entitlementResolved: purchase.entitlementResolved, unlocked: purchase.unlocked,
                 purchasing: purchase.purchasing,
                 safeScreen: store.data.onboardingCompleted && !store.readOnly && session == nil && !showPaywall && !showSettings)
    }

    var body: some View {
        Group {
            if store.readOnly {
                ContentUnavailableView("学習履歴を読み込めません", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(store.error ?? "端末の保存状態を確認してください"))
            } else if !store.data.onboardingCompleted {
                WelcomeView(catalog: catalog, start: { start(SessionPlanner.diagnostic(catalog, unlocked: purchase.unlocked)) },
                            skip: { store.completeOnboarding(diagnostic: false) })
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        DashboardView(catalog: catalog, store: store, purchase: purchase, ads: ads, start: start,
                                      paywall: openPaywall, resume: resumePending,
                                      openAnalysis: { selectedTab = .insights }, settings: { showSettings = true })
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                    }
                    .tabItem { Label("ホーム", systemImage: "house") }.tag(MainTab.home)
                    NavigationStack {
                        LibraryView(catalog: catalog, store: store, purchase: purchase, ads: ads, start: start,
                                    settings: { showSettings = true })
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                    }
                    .tabItem { Label("問題を探す", systemImage: "square.grid.2x2") }.tag(MainTab.finder)
                    NavigationStack {
                        InsightsView(catalog: catalog, store: store, purchase: purchase, ads: ads,
                                     start: start, paywall: openPaywall,
                                     settings: { showSettings = true })
                    }
                    .tabItem { Label("記録", systemImage: "chart.bar.xaxis") }.tag(MainTab.insights)
                }
            }
        }
        .task(id: adAccess) { ads.updateAccess(adAccess) }
        .sheet(item: $session, onDismiss: {
            ads.updateAccess(adAccess)
            if let completedForAds {
                ads.completedSession(mode: completedForAds.mode, answered: completedForAds.answered)
                self.completedForAds = nil
            }
        }) { active in
            SessionView(session: active, qualification: catalog.qualification, store: store, purchase: purchase,
                        ads: ads, resume: store.data.pending?.id == active.id ? store.data.pending : nil) { answered in
                if active.mode == .diagnostic { store.completeOnboarding(diagnostic: true) }
                completedForAds = (active.mode, answered)
                session = nil
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(catalog: catalog, purchase: purchase) }
        .sheet(isPresented: $showSettings, onDismiss: {
            if queuedPaywall { queuedPaywall = false; showPaywall = true }
        }) {
            NavigationStack {
                PreferencesView(catalog: catalog, store: store, purchase: purchase, ads: ads,
                                paywall: openPaywall, onReset: { showSettings = false })
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showSettings = false } }
                    }
            }
            .tint(Palette.linkAccent(catalog.qualification.accentHex))
        }
        .confirmationDialog("保存中の演習があります", isPresented: $confirmReplacement, titleVisibility: .visible) {
            Button("続きから再開") { replacement = nil; resumePending() }
            Button("新しい演習に切り替える", role: .destructive) {
                if let replacement {
                    store.clearPending()
                    startImmediately(replacement)
                }
                replacement = nil
            }
            Button("キャンセル", role: .cancel) { replacement = nil }
        } message: {
            Text("新しい演習に切り替えると、途中の出題順と現在位置は消えます。回答済みの学習履歴は残ります。")
        }
        .alert("前回の演習を開けません", isPresented: $resumeUnavailable) {
            Button("確認") { }
        } message: {
            Text("問題データが更新されたため、途中位置を復元できませんでした。回答済みの学習履歴は残っています。")
        }
        .tint(Palette.linkAccent(catalog.qualification.accentHex))
    }

    private func start(_ newSession: StudySession) {
        if newSession.questions.isEmpty { return }
        if newSession.mode != .search && newSession.mode != .diagnostic && newSession.mode != .mock,
           let pending = store.data.pending, pending.id != newSession.id {
            replacement = newSession
            confirmReplacement = true
            return
        }
        startImmediately(newSession)
    }

    private func startImmediately(_ newSession: StudySession) {
        if newSession.mode != .search && newSession.mode != .diagnostic && newSession.mode != .mock,
           store.data.pending?.id != newSession.id {
            store.setPending(PendingStudy(session: newSession))
            if store.error != nil { return }
        }
        ads.updateAccess(AdAccess(entitlementResolved: purchase.entitlementResolved, unlocked: purchase.unlocked,
                                  purchasing: purchase.purchasing, safeScreen: false))
        session = newSession
    }

    private func resumePending() {
        guard let pending = store.data.pending else { return }
        let allIDs = Set(catalog.questions.map(\.id))
        guard Set(pending.questionIDs).isSubset(of: allIDs) else {
            store.clearPending()
            resumeUnavailable = true
            return
        }
        if !purchase.unlocked && pending.questionIDs.contains(where: { !catalog.qualification.freeQuestionIDs.contains($0) }) {
            openPaywall()
            return
        }
        guard let restored = QuestionCollections.resumedSession(pending, catalog: catalog, unlocked: purchase.unlocked) else {
            store.clearPending()
            resumeUnavailable = true
            return
        }
        startImmediately(restored)
    }

    private func collection(_ route: QuestionCollectionRoute) -> some View {
        QuestionCollectionView(route: route, catalog: catalog, store: store, purchase: purchase,
                               ads: ads, start: start, paywall: openPaywall)
    }

    private func openPaywall() {
        ads.updateAccess(AdAccess(entitlementResolved: purchase.entitlementResolved, unlocked: purchase.unlocked,
                                  purchasing: purchase.purchasing, safeScreen: false))
        if showSettings { queuedPaywall = true; showSettings = false }
        else { showPaywall = true }
    }
}
