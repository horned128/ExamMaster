import StoreKit
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    private enum MainTab: Hashable { case home, years, subjects, review, textbook }
    let catalog: Catalog
    @State private var store: StudyStore
    @State private var purchase: PurchaseManager
    @State private var ads: AdsService
    @State private var session: StudySession?
    @State private var completedForAds: (mode: StudyMode, answered: Int, correct: Int?)?
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var homePath = NavigationPath()
    @State private var queuedRecords = false
    @State private var queuedPaywall = false
    @State private var selectedTab: MainTab = .home
    @State private var reviewList: ReviewList = .incorrect
    private let backlinks: TextbookBacklinks

    init(catalog: Catalog) {
        self.catalog = catalog
        _store = State(initialValue: StudyStore(qualificationID: catalog.qualification.id))
        backlinks = TextbookBacklinks(questions: catalog.questions)
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
                                      openSubjects: { selectedTab = .subjects },
                                      openIncorrect: { reviewList = .incorrect; selectedTab = .review },
                                      openBookmarks: { reviewList = .bookmarks; selectedTab = .review }, paywall: openPaywall,
                                      settings: { showSettings = true })
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                            .navigationDestination(for: StudyDestination.self) { destination in destinationView(destination) }
                    }
                    .tabItem { Label("ホーム", systemImage: "house") }.tag(MainTab.home)
                    NavigationStack {
                        destinationView(.years)
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                    }
                    .tabItem { Label(catalog.qualification.libraryTabTitle, systemImage: catalog.qualification.libraryTabSymbol) }.tag(MainTab.years)
                    NavigationStack {
                        destinationView(.subjects)
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                            .navigationDestination(for: StudyDestination.self) { destination in destinationView(destination) }
                    }
                    .tabItem { Label("分野別", systemImage: "square.grid.2x2") }.tag(MainTab.subjects)
                    NavigationStack {
                        collection(reviewList.route)
                            .id(reviewList)
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    Picker("復習", selection: $reviewList) {
                                        ForEach(ReviewList.allCases) { Text($0.title).tag($0) }
                                    }
                                    .pickerStyle(.segmented)
                                    .fixedSize()
                                    .accessibilityIdentifier("reviewListPicker")
                                }
                            }
                            .navigationDestination(for: QuestionCollectionRoute.self) { route in collection(route) }
                    }
                    .tabItem { Label("復習", systemImage: "arrow.uturn.backward") }.tag(MainTab.review)
                    if let shelf = TextbookShelf.current {
                        TextbookStack(context: textbookContext(start: start), root: shelf.root)
                            .tabItem { Label(shelf.title, systemImage: shelf.symbol) }.tag(MainTab.textbook)
                    }
                }
                .textbookLinks(textbookContext(start: start))
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
                let showedAd = ads.completedSession(mode: completedForAds.mode, answered: completedForAds.answered)
                if !showedAd, let correct = completedForAds.correct {
                    requestReviewIfEarned(completedForAds.mode, answered: completedForAds.answered, correct: correct)
                }
                self.completedForAds = nil
            }
        }) { active in
            if active.timed {
                MockExamSessionView(session: active, catalog: catalog, store: store, purchase: purchase) { answered in
                    completedForAds = (active.mode, answered, nil)
                    session = nil
                }
                .textbookLinks(textbookContext(start: nil))
            } else {
              SessionView(session: active, qualification: catalog.qualification, store: store, purchase: purchase,
                        ads: ads, growthQuestions: SessionPlanner.available(catalog, unlocked: purchase.unlocked)) { answered, correct in
                if active.mode == .diagnostic { store.completeOnboarding(diagnostic: true) }
                completedForAds = (active.mode, answered, correct)
                session = nil
            }
            .environment(\.mascotMotionEnabled, true)
            .textbookLinks(textbookContext(start: nil))
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
        .fontDesign(.rounded)
        .environment(\.mascotBaseColor, Palette.accent(catalog.qualification.mascotColorHex))
        .environment(\.mascotChickColor, catalog.qualification.chickBaseHex.map(Palette.accent))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await purchase.refreshIfNeeded() } }
        }
    }

    private func textbookContext(start: ((StudySession) -> Void)?) -> TextbookContext {
        TextbookContext(catalog: catalog, store: store, purchase: purchase, start: start, backlinks: backlinks)
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
            SubjectLibraryView(subject: subject, catalog: catalog, store: store, purchase: purchase,
                               start: start, paywall: openPaywall)
        case .theme(let subject, let topic):
            ThemeDetailView(subject: subject, topicTitle: topic, catalog: catalog, store: store, purchase: purchase,
                            start: start, paywall: openPaywall)
        case .quiz:
            QuickQuizView(catalog: catalog, store: store, purchase: purchase, start: start)
        }
    }

    @ViewBuilder private func collection(_ route: QuestionCollectionRoute) -> some View {
        if case .year(let year) = route, catalog.qualification.resolvedLibraryStyle == .subjectPapers {
            ElectricalSetLibraryView(year: year, catalog: catalog, store: store, purchase: purchase, paywall: openPaywall)
        } else if case .year(let year) = route, catalog.qualification.resolvedLibraryStyle == .subjectKinds {
            FundamentalSetLibraryView(year: year, catalog: catalog, store: store, purchase: purchase, paywall: openPaywall)
        } else if case .year(let year) = route,
           catalog.mockSets.filter({ set in !set.kind.isOfficial && catalog.questions.contains { $0.year == year && $0.mockSetID == set.id } }).count > 1 {
            PredictionLibraryView(year: year, catalog: catalog, store: store, purchase: purchase, paywall: openPaywall)
        } else if case .year(let year) = route,
                  catalog.mockSets.filter({ set in set.kind.isOfficial && catalog.questions.contains { $0.year == year && $0.mockSetID == set.id } }).count > 1 {
            PastMockLibraryView(year: year, catalog: catalog, store: store, purchase: purchase, paywall: openPaywall)
        } else {
            QuestionCollectionView(route: route, catalog: catalog, store: store, purchase: purchase,
                                   ads: ads, start: start, paywall: openPaywall)
        }
    }

    private func requestReviewIfEarned(_ mode: StudyMode, answered: Int, correct: Int) {
        guard !ReviewPrompt.suppressed,
              ReviewPrompt.shouldRequest(mode: mode, answered: answered, correct: correct, history: store.data.answers,
                                         lastRequested: ReviewPrompt.lastRequested) else { return }
        ReviewPrompt.markRequested()
        requestReview()
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

/// 復習 tab: one list at a time, switched at the top.
enum ReviewList: String, CaseIterable, Identifiable {
    case incorrect, bookmarks
    var id: Self { self }
    var title: String { self == .incorrect ? "苦手問題" : "ブックマーク" }
    var route: QuestionCollectionRoute { self == .incorrect ? .incorrect : .favorites }
}

/// The fifth tab: the textbook when the app has one, otherwise the glossary, otherwise none.
struct TextbookShelf {
    let title: String
    let symbol: String
    let root: TextbookRoute?

    static let current: TextbookShelf? = {
        if Textbook.main != nil || LayerMap.main != nil { return TextbookShelf(title: "教科書", symbol: "book", root: nil) }
        if Glossary.main != nil { return TextbookShelf(title: "用語集", symbol: "character.book.closed", root: .glossary) }
        return nil
    }()
}
