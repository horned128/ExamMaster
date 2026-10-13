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
    private enum MainTab: Hashable { case home, years, subjects, incorrect, bookmarks }
    let catalog: Catalog
    @State private var store: StudyStore
    @State private var purchase: PurchaseManager
    @State private var ads: AdsService
    @State private var session: StudySession?
    @State private var completedForAds: (mode: StudyMode, answered: Int)?
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var homePath = NavigationPath()
    @State private var queuedRecords = false
    @State private var queuedPaywall = false
    @State private var selectedTab: MainTab = .home

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
                    NavigationStack(path: $homePath) {
                        DashboardView(catalog: catalog, store: store, purchase: purchase, ads: ads, start: start,
                                      openLibrary: { selectedTab = .years },
                                      openSubjects: { selectedTab = .subjects }, openIncorrect: { selectedTab = .incorrect },
                                      openBookmarks: { selectedTab = .bookmarks }, paywall: openPaywall,
                                      settings: { showSettings = true })
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                            .navigationDestination(for: StudyDestination.self) { destination in destinationView(destination) }
                    }
                    .tabItem { Label("ホーム", systemImage: "house") }.tag(MainTab.home)
                    NavigationStack {
                        destinationView(.years)
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                    }
                    .tabItem { Label("年度別", systemImage: "calendar") }.tag(MainTab.years)
                    NavigationStack {
                        destinationView(.subjects)
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                            .navigationDestination(for: StudyDestination.self) { destination in destinationView(destination) }
                    }
                    .tabItem { Label("分野別", systemImage: "square.grid.2x2") }.tag(MainTab.subjects)
                    NavigationStack {
                        collection(.incorrect)
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                    }
                    .tabItem { Label("苦手問題", systemImage: "arrow.uturn.backward") }.tag(MainTab.incorrect)
                    NavigationStack {
                        collection(.favorites)
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                    }
                    .tabItem { Label("ブックマーク", systemImage: "bookmark") }.tag(MainTab.bookmarks)
                }
            }
        }
        .environment(\.mascotMotionEnabled, session == nil && !showPaywall && !showSettings)
        .task(id: adAccess) {
            ads.updateAccess(adAccess)
            if purchase.entitlementResolved {
                store.migrateMascotGrowthIfNeeded(questions: SessionPlanner.available(catalog, unlocked: purchase.unlocked))
            }
        }
        .onChange(of: purchase.unlocked) { wasUnlocked, unlocked in
            if wasUnlocked && !unlocked, let active = session,
               active.questions.contains(where: { !catalog.qualification.freeQuestionIDs.contains($0.id) }) {
                session = nil
            }
        }
        .sheet(item: $session, onDismiss: {
            store.clearInterruptedStudy()
            ads.updateAccess(adAccess)
            if let completedForAds {
                ads.completedSession(mode: completedForAds.mode, answered: completedForAds.answered)
                self.completedForAds = nil
            }
        }) { active in
            if active.timed {
                MockExamSessionView(session: active, catalog: catalog, store: store, purchase: purchase) { answered in
                    completedForAds = (active.mode, answered)
                    session = nil
                }
            } else {
              SessionView(session: active, qualification: catalog.qualification, store: store, purchase: purchase,
                        ads: ads, growthQuestions: SessionPlanner.available(catalog, unlocked: purchase.unlocked)) { answered in
                if active.mode == .diagnostic { store.completeOnboarding(diagnostic: true) }
                completedForAds = (active.mode, answered)
                session = nil
            }
            .environment(\.mascotMotionEnabled, true)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(catalog: catalog, purchase: purchase) }
        .sheet(isPresented: $showSettings, onDismiss: {
            if queuedPaywall { queuedPaywall = false; showPaywall = true }
            else if queuedRecords { queuedRecords = false; openRecords() }
        }) {
            NavigationStack {
                PreferencesView(catalog: catalog, store: store, purchase: purchase, ads: ads,
                                paywall: openPaywall, onReset: { showSettings = false }, openCompanion: openRecords)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showSettings = false } }
                    }
            }
            .tint(Palette.linkAccent(catalog.qualification.accentHex))
        }
        .tint(Palette.linkAccent(catalog.qualification.accentHex))
        .environment(\.mascotBaseColor, Palette.accent(catalog.qualification.mascotColorHex))
        .environment(\.mascotChickColor, catalog.qualification.chickBaseHex.map(Palette.accent))
    }

    private func start(_ newSession: StudySession) {
        if newSession.questions.isEmpty { return }
        guard newSession.questions.allSatisfy({ purchase.unlocked || catalog.qualification.freeQuestionIDs.contains($0.id) }) else {
            openPaywall(); return
        }
        startImmediately(newSession)
    }

    private func startImmediately(_ newSession: StudySession) {
        if newSession.timed, store.data.pendingMock?.id != newSession.id {
            let minutes = catalog.mockSets.first { $0.id == newSession.mockSetID }?.minutes ?? catalog.qualification.examMinutes
            guard store.beginMock(session: newSession, minutes: minutes) else { return }
        }
        ads.updateAccess(AdAccess(entitlementResolved: purchase.entitlementResolved, unlocked: purchase.unlocked,
                                  purchasing: purchase.purchasing, safeScreen: false))
        session = newSession
    }

    @ViewBuilder
    private func destinationView(_ destination: StudyDestination) -> some View {
        switch destination {
        case .years, .subjects:
            LibraryView(section: destination == .years ? .years : .subjects, catalog: catalog, store: store,
                        purchase: purchase, ads: ads, start: start, settings: { showSettings = true }, paywall: openPaywall)
        case .records:
            InsightsView(catalog: catalog, store: store, purchase: purchase, ads: ads, start: start,
                         paywall: openPaywall, settings: { showSettings = true })
        case .subjectCategories(let subject):
            SubjectLibraryView(subject: subject, catalog: catalog, store: store, purchase: purchase)
        case .quiz:
            QuickQuizView(catalog: catalog, store: store, purchase: purchase, start: start)
        }
    }

    @ViewBuilder private func collection(_ route: QuestionCollectionRoute) -> some View {
        if case .year(let year) = route,
           catalog.mockSets.filter({ set in set.kind == .prediction && catalog.questions.contains { $0.year == year && $0.mockSetID == set.id } }).count > 1 {
            PredictionLibraryView(year: year, catalog: catalog, store: store, purchase: purchase, paywall: openPaywall)
        } else if case .year(let year) = route,
                  catalog.mockSets.filter({ set in set.kind == .past && catalog.questions.contains { $0.year == year && $0.mockSetID == set.id } }).count > 1 {
            PastMockLibraryView(year: year, catalog: catalog, store: store, purchase: purchase, paywall: openPaywall)
        } else {
            QuestionCollectionView(route: route, catalog: catalog, store: store, purchase: purchase,
                                   ads: ads, start: start, paywall: openPaywall)
        }
    }

    private func openPaywall() {
        ads.updateAccess(AdAccess(entitlementResolved: purchase.entitlementResolved, unlocked: purchase.unlocked,
                                  purchasing: purchase.purchasing, safeScreen: false))
        if showSettings { queuedPaywall = true; showSettings = false }
        else { showPaywall = true }
    }

    private func openRecords() {
        if showSettings { queuedRecords = true; showSettings = false }
        else {
            selectedTab = .home
            homePath = NavigationPath()
            homePath.append(StudyDestination.records)
        }
    }
}
