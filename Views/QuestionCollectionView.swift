import SwiftUI

struct QuestionCollectionView: View {
    @Environment(\.mascotMotionEnabled) private var parentMotionEnabled
    let route: QuestionCollectionRoute
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let paywall: () -> Void

    @State private var query = ""
    @State private var showRandomOptions = false
    @State private var pendingRandomSession: StudySession?
    @State private var randomScope: RandomScope

    init(route: QuestionCollectionRoute, catalog: Catalog, store: StudyStore, purchase: PurchaseManager,
         ads: AdsService, start: @escaping (StudySession) -> Void, paywall: @escaping () -> Void) {
        self.route = route
        self.catalog = catalog
        self.store = store
        self.purchase = purchase
        self.ads = ads
        self.start = start
        self.paywall = paywall
        _randomScope = State(initialValue: store.data.randomScope)
    }

    private var candidates: [Question] {
        QuestionCollections.questions(for: route, catalog: catalog, data: store.data)
    }
    private var visible: [Question] {
        candidates.filter { query.isEmpty || $0.searchText.localizedStandardContains(query) }
    }
    private var accessible: [Question] {
        visible.filter { purchase.unlocked || catalog.qualification.freeQuestionIDs.contains($0.id) }
    }
    private var unanswered: [Question] {
        accessible.filter { store.data.mastery[$0.id] == nil }
    }
    private var growth: TankeiGrowth { TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked) }

    var body: some View {
        List {
            Section {
                HStack {
                    StudyBadge(title: "\(accessible.count)問を利用可能", symbol: "doc.text", color: Palette.positive)
                    Spacer(minLength: 8)
                    if accessible.count < visible.count {
                        StudyBadge(title: "\(visible.count - accessible.count)問", symbol: "lock")
                    }
                }
                Button {
                    launch(StudySession(title: route.title, mode: route.studyMode, questions: accessible, timed: false))
                } label: {
                    Label("順番に回答 · \(accessible.count)問", systemImage: "list.number")
                }
                .disabled(accessible.isEmpty)
                Button { showRandomOptions = true } label: {
                    Label("ランダム出題", systemImage: "shuffle")
                }
                .disabled(accessible.isEmpty)
                if accessible.isEmpty && !visible.isEmpty && !purchase.unlocked {
                    Button("全問題を解放する", action: paywall)
                }
            }
            if showAds {
                Section { AdBannerPlacement(ads: ads) }
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(visible) { question in
                    Button {
                        if purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) {
                            launch(StudySession(title: "問題を確認", mode: .search, questions: [question], timed: false))
                        } else { paywall() }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? statusSymbol(for: question) : "lock")
                                .foregroundStyle(statusColor(for: question))
                                .frame(width: 22)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(question.stem).font(.body).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(metadata(for: question))
                                    .font(.caption).foregroundStyle(Palette.muted)
                                if let status = status(for: question) {
                                    Text(status).font(.caption.weight(.medium)).foregroundStyle(statusColor(for: question))
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .accessibilityLabel("\(question.stem)、\(status(for: question) ?? "学習中")、\(purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? "利用可能" : "全問題解放が必要")")
                }
                if visible.isEmpty {
                    ContentUnavailableView {
                        TankeiView(state: .review, stage: growth.stage, size: 96, animated: true, idle: true)
                        Text("条件に合う問題がありません")
                    } description: {
                        Text("検索語を変えるか、別の一覧を選んでください。")
                    }
                }
            } header: {
                Text("問題リスト · \(visible.count)問")
            }
            if showAds {
                Section { AdBannerPlacement(ads: ads) }
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .environment(\.mascotMotionEnabled, parentMotionEnabled && !showRandomOptions)
        .navigationTitle(route.title)
        .searchable(text: $query, prompt: "このリスト内を検索")
        .sheet(isPresented: $showRandomOptions, onDismiss: {
            if let pendingRandomSession {
                start(pendingRandomSession)
                self.pendingRandomSession = nil
            }
        }) {
            NavigationStack {
                Form {
                    Section {
                        ForEach(RandomScope.allCases) { option in
                            Button {
                                randomScope = option
                            } label: {
                                HStack {
                                    Text(option.title).foregroundStyle(.primary)
                                    Spacer()
                                    if randomScope == option { Image(systemName: "checkmark").foregroundStyle(.tint) }
                                }
                            }
                            .accessibilityLabel(option.title)
                            .accessibilityAddTraits(randomScope == option ? .isSelected : [])
                        }
                    } header: {
                        Text("ランダム演習の設定")
                    } footer: {
                        Text("表示中の問題を、1問ずつ。")
                    }
                    Section {
                        let count = randomScope == .unanswered ? unanswered.count : accessible.count
                        if count == 0 {
                            ContentUnavailableView("未回答の問題がありません", systemImage: "checkmark.circle",
                                                   description: Text("「ごちゃまぜ」に切り替えると復習できます。"))
                        } else {
                            Button("\(count)問の演習を始める") {
                                store.setRandomScope(randomScope)
                                let pool = randomScope == .unanswered ? unanswered : accessible
                                pendingRandomSession = StudySession(title: "\(route.title) · ランダム", mode: .random,
                                                                    questions: pool.shuffled(), timed: false)
                                showRandomOptions = false
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .navigationTitle("ランダム出題")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showRandomOptions = false } }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var showAds: Bool { !purchase.unlocked && !purchase.purchasing && ads.canShowBanner }

    private func metadata(for question: Question) -> String {
        if case .year = route { return question.subject }
        return "\(question.year.formatted(.number.grouping(.never))) · \(question.subject)"
    }

    private func launch(_ session: StudySession) {
        guard !session.questions.isEmpty else { return }
        start(session)
    }

    private func status(for question: Question) -> String? {
        guard let state = store.data.mastery[question.id] else { return "これから" }
        if state.misconception { return "勘違いをほどく" }
        if state.dueAt.map({ $0 <= .now }) ?? false { return "今、復習にいい頃" }
        if MasteryEngine.isMastered(state, now: .now) { return "定着" }
        if let date = state.dueAt { return "次は\(ReviewOutlook.label(for: date))" }
        if state.lastCorrect == false { return "もう一度" }
        return nil
    }

    private func statusSymbol(for question: Question) -> String {
        guard let state = store.data.mastery[question.id] else { return "circle.dashed" }
        if state.misconception { return "square.on.square" }
        if state.dueAt.map({ $0 <= .now }) ?? false { return "arrow.clockwise.circle" }
        if MasteryEngine.isMastered(state, now: .now) { return "checkmark.circle" }
        return "circle.lefthalf.filled"
    }

    private func statusColor(for question: Question) -> Color {
        guard let state = store.data.mastery[question.id] else { return Palette.muted }
        if state.misconception || (state.dueAt.map { $0 <= .now } ?? false) { return Palette.review }
        return Palette.positive
    }
}
