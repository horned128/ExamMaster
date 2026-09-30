import SwiftUI

struct QuestionCollectionView: View {
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

    var body: some View {
        List {
            Section {
                Text("\(visible.count)問中\(accessible.count)問を利用できます。問題を選ぶか、表示中の問題をまとめて演習できます。")
                    .font(.subheadline).foregroundStyle(.secondary)
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
                            Image(systemName: purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? "doc.text" : "lock")
                                .foregroundStyle(.tint)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(question.stem).font(.body).foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 8) {
                                    Text("\(question.year.formatted(.number.grouping(.never))) · \(question.subject) / \(question.category)")
                                    if let status = status(for: question) { Text("· \(status)") }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .accessibilityLabel("\(question.stem)、\(purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? "利用可能" : "全問題解放が必要")")
                }
                if visible.isEmpty {
                    ContentUnavailableView("条件に合う問題がありません", systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("検索語を変えるか、別の一覧を選んでください。"))
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
                        Text("このリストに表示され、利用できる問題だけが対象です。選んだ条件に合う全問題を1回ずつ出題します。")
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

    private func launch(_ session: StudySession) {
        guard !session.questions.isEmpty else { return }
        start(session)
    }

    private func status(for question: Question) -> String? {
        guard let state = store.data.mastery[question.id] else { return "未回答" }
        if state.misconception { return "思い込み注意" }
        if state.lastCorrect == false { return "復習したい" }
        if MasteryEngine.isMastered(state, now: .now) { return "安定" }
        if state.dueAt.map({ $0 <= .now }) ?? false { return "復習時期" }
        return nil
    }
}
