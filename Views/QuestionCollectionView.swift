import SwiftUI

struct QuestionCollectionView: View {
    @Environment(\.mascotMotionEnabled) private var parentMotionEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let route: QuestionCollectionRoute
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let paywall: () -> Void

    @State private var showPracticeOptions = false
    @State private var pendingPracticeSession: StudySession?

    private var candidates: [Question] {
        QuestionCollections.questions(for: route, catalog: catalog, data: store.data)
    }
    private var accessible: [Question] {
        candidates.filter { purchase.unlocked || catalog.qualification.freeQuestionIDs.contains($0.id) }
    }
    private var growth: TankeiGrowth { TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked) }
    private var title: String {
        if case .mockSet(let id) = route, let set = catalog.mockSets.first(where: { $0.id == id }) {
            return set.title
        }
        if case .year(let year) = route, candidates.contains(where: { $0.kind == .prediction }) {
            return "\(year.formatted(.number.grouping(.never)))年予想問題"
        }
        return route.title
    }

    private var isYear: Bool {
        switch route { case .year, .mockSet: return true; default: return false }
    }
    private var groups: [(title: String, questions: [Question])] {
        if isYear {
            return catalog.qualification.subjects.compactMap { subject in
                let items = accessible.filter { $0.subject == subject }
                return items.isEmpty ? nil : (subject, items)
            }
        }
        return [("問題リスト", accessible)]
    }
    private var orderedQuestions: [Question] { groups.flatMap(\.questions) }
    private var lockedCount: Int { candidates.filter { !purchase.unlocked && !catalog.qualification.freeQuestionIDs.contains($0.id) }.count }

    var body: some View {
        List {
            Section {
                HStack {
                    StudyBadge(title: "\(accessible.count)問を利用可能", symbol: "doc.text", color: Palette.positive)
                    Spacer(minLength: 8)
                    if lockedCount > 0 {
                        StudyBadge(title: "\(lockedCount)問はロック中", symbol: "lock")
                    }
                }
                if isYear {
                    Button {
                        let pool = candidates.filter { purchase.unlocked || catalog.qualification.freeQuestionIDs.contains($0.id) }
                        let ids = Set(pool.map(\.id))
                        if let set = catalog.mockSets.first(where: { Set($0.questionIDs) == ids }),
                           let session = MockExam.session(set: set, catalog: catalog, unlocked: purchase.unlocked) {
                            launch(session)
                        } else {
                            launch(StudySession(title: "\(title) · 模擬試験", mode: .mock, questions: pool, timed: true))
                        }
                    } label: { Label("模擬試験", systemImage: "timer") }
                    .disabled(accessible.isEmpty)
                    Text("問題を選んで練習、または時間を測って模擬試験。")
                        .font(.caption).foregroundStyle(Palette.muted)
                } else {
                    Button { showPracticeOptions = true } label: { Label("問題を解く", systemImage: "play.fill") }
                        .accessibilityIdentifier("solveQuestions")
                        .disabled(accessible.isEmpty)
                }
                if lockedCount > 0 { Button("有料問題を解放する", action: paywall) }

            }
            if showAds {
                Section { AdBannerPlacement(ads: ads) }
                    .listRowBackground(Color.clear)
            }
            ForEach(groups, id: \.title) { group in
                Section {
                    ForEach(group.questions) { question in
                        Button {
                            guard let index = orderedQuestions.firstIndex(where: { $0.id == question.id }) else { return }
                            launch(StudySession(title: title, mode: .search, questions: Array(orderedQuestions[index...]), timed: false))
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: statusSymbol(for: question)).foregroundStyle(statusColor(for: question))
                                    .frame(width: 22).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(question.stem).font(.body).foregroundStyle(Palette.ink).lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(metadata(for: question)).font(.caption).foregroundStyle(Palette.muted)
                                    if let status = status(for: question) {
                                        Text(status).font(.caption.weight(.medium)).foregroundStyle(statusColor(for: question))
                                    }
                                }
                            }.padding(.vertical, 5)
                        }
                        .accessibilityIdentifier("question-\(question.id)")
                        .accessibilityLabel("\(question.stem)、\(status(for: question) ?? "学習中")、利用可能")
                    }
                } header: { Text("\(group.title) · \(group.questions.count)問") }
            }
            if accessible.isEmpty {
                Section {
                    ContentUnavailableView {
                        TankeiView(state: .review, stage: growth.stage, size: 96, animated: true, idle: true)
                        Text(lockedCount > 0 ? "有料問題はロック中です" : "条件に合う問題がありません")
                    } description: { Text(lockedCount > 0 ? "購入すると、この一覧の問題を利用できます。" : "別の一覧を選んでください。") }
                }
            }
            if showAds {
                Section { AdBannerPlacement(ads: ads) }
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .environment(\.mascotMotionEnabled, parentMotionEnabled && !showPracticeOptions)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPracticeOptions, onDismiss: {
            if let pendingPracticeSession {
                self.pendingPracticeSession = nil
                start(pendingPracticeSession)
            }
        }) {
            NavigationStack {
                List {
                    Section {
                        practiceOption("順番に解く", symbol: "list.number", random: false)
                        practiceOption("ランダムに解く", symbol: "shuffle", random: true)
                    } header: { Text("\(accessible.count)問の解き方を選ぶ") }
                }
                .scrollContentBackground(.hidden).background(Palette.background)
                .navigationTitle("問題を解く")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showPracticeOptions = false } }
                }
            }
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        }
    }

    private func practiceOption(_ optionTitle: String, symbol: String, random: Bool) -> some View {
        Button {
            pendingPracticeSession = StudySession(title: title + (random ? " · ランダム" : ""),
                                                 mode: random ? .random : route.studyMode,
                                                 questions: random ? orderedQuestions.shuffled() : orderedQuestions, timed: false,
                                                 returnsToQuestionList: true)
            showPracticeOptions = false
        } label: {
            Label(optionTitle, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
    }

    private var showAds: Bool { !purchase.unlocked && !purchase.purchasing && ads.canShowBanner }

    private func metadata(for question: Question) -> String {
        if question.kind != nil { return "\(question.kindTitle ?? "") · \(question.source)" }
        if case .year = route { return "\(question.category) · Lv\(question.difficulty)" }
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
