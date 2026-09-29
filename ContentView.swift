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
    let catalog: Catalog
    @State private var store: StudyStore
    @State private var purchase: PurchaseManager
    @State private var session: StudySession?
    @State private var showPaywall = false

    init(catalog: Catalog) {
        self.catalog = catalog
        _store = State(initialValue: StudyStore(qualificationID: catalog.qualification.id))
        _purchase = State(initialValue: PurchaseManager(productID: catalog.qualification.productID))
    }

    var body: some View {
        Group {
            if store.readOnly {
                ContentUnavailableView("学習履歴を読み込めません", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(store.error ?? "端末の保存状態を確認してください"))
            } else if !store.data.onboardingCompleted {
                WelcomeView(catalog: catalog, start: { session = SessionPlanner.diagnostic(catalog, unlocked: purchase.unlocked) },
                            skip: { store.completeOnboarding(diagnostic: false) })
            } else {
                TabView {
                    NavigationStack {
                        DashboardView(catalog: catalog, store: store, purchase: purchase, start: start, paywall: { showPaywall = true })
                    }
                    .tabItem { Label("今日", systemImage: "sun.max") }
                    NavigationStack {
                        LibraryView(catalog: catalog, store: store, purchase: purchase, start: start, paywall: { showPaywall = true })
                    }
                    .tabItem { Label("問題を探す", systemImage: "square.grid.2x2") }
                    NavigationStack {
                        InsightsView(catalog: catalog, store: store)
                    }
                    .tabItem { Label("分析", systemImage: "chart.bar.xaxis") }
                    NavigationStack {
                        PreferencesView(catalog: catalog, store: store, purchase: purchase, paywall: { showPaywall = true })
                    }
                    .tabItem { Label("設定", systemImage: "gearshape") }
                }
            }
        }
        .tint(Palette.accent(catalog.qualification.accentHex))
        .sheet(item: $session) { active in
            SessionView(session: active, qualification: catalog.qualification, store: store) {
                if active.mode == .diagnostic { store.completeOnboarding(diagnostic: true) }
                session = nil
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(catalog: catalog, purchase: purchase) }
    }

    private func start(_ newSession: StudySession) {
        if newSession.questions.isEmpty { return }
        session = newSession
    }
}
