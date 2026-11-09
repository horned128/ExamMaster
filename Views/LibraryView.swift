import SwiftUI

enum StudyDestination: Hashable { case years, subjects, records, quiz, subjectCategories(String), theme(String, String) }
enum LibrarySection { case years, subjects }

struct LibraryView: View {
    var section: LibrarySection = .years
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let settings: () -> Void
    var paywall: () -> Void = {}
    private var years: [Int] { Array(Set(catalog.questions.map(\.year))).sorted(by: >) }
    private var usesSets: Bool { catalog.qualification.resolvedLibraryStyle == .sets }
    private var sets: [MockSet] { catalog.mockSets.sorted { $0.id < $1.id } }
    private var title: String { section == .years ? catalog.qualification.libraryTabTitle + "演習" : "分野別演習" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Surface(inset: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: section == .subjects ? "square.grid.2x2" : catalog.qualification.libraryTabSymbol)
                            .font(.title2).foregroundStyle(Palette.positive).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section == .subjects ? "分野から選ぶ" : usesSets ? "セットから選ぶ" : "年度から選ぶ").font(.headline)
                            Text(section == .subjects ? "苦手なテーマほど上に並びます。"
                                 : usesSets ? "1セット\(catalog.qualification.mockQuestionCount)\(catalog.qualification.unit)。練習にも模擬試験にも。"
                                 : "過去問・予想問題から選んで取り組もう。")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                        TankeiView(state: .review, stage: TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked).stage,
                                   size: 52, animated: true, idle: true, expressive: true)
                            .accessibilityHidden(true)
                    }
                }
                if section == .years {
                    StudyGrid {
                        if usesSets {
                            ForEach(sets) { set in
                                libraryCard(set.title, questions: catalog.questions.filter { $0.mockSetID == set.id },
                                            route: .mockSet(set.id), identifier: "set-\(set.id)")
                            }
                        } else {
                            ForEach(years, id: \.self) { year in
                                libraryCard(yearTitle(year), questions: catalog.questions.filter { $0.year == year },
                                            route: .year(year), identifier: "year-\(year)")
                            }
                        }
                    }
                } else if catalog.qualification.subjects.count == 1, let subject = catalog.qualification.subjects.first {
                    WeakPointMap(subject: subject, catalog: catalog, store: store, purchase: purchase,
                                 start: start, paywall: paywall)
                    NavigationLink(value: QuestionCollectionRoute.subject(subject)) {
                        FeatureCard(title: "この分野の全問題", symbol: "list.bullet",
                                    detail: "\(catalog.questions.filter { $0.subject == subject }.count)問")
                    }
                } else {
                    ForEach(catalog.qualification.subjects, id: \.self) { subject in
                        NavigationLink(value: StudyDestination.subjectCategories(subject)) {
                            progressCard(subject, questions: catalog.questions.filter { $0.subject == subject }, compact: false)
                        }.accessibilityIdentifier("subject-\(subject)")
                    }
                }
                if !purchase.unlocked && !purchase.purchasing { AdBannerPlacement(ads: ads) }
            }
            .buttonStyle(StudyButtonStyle())
            .padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: settings) { Image(systemName: "gearshape") }.accessibilityLabel("設定")
            }
        }
    }

    @ViewBuilder
    private func libraryCard(_ title: String, questions: [Question], route: QuestionCollectionRoute, identifier: String) -> some View {
        let locked = !purchase.unlocked && !questions.contains { catalog.qualification.freeQuestionIDs.contains($0.id) }
        if locked {
            Button(action: paywall) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(title).font(.title3.bold())
                        Spacer(minLength: 4)
                        Image(systemName: "lock.fill").foregroundStyle(Palette.review)
                    }
                    Text("\(countLabel(questions)) · 有料").font(.caption).foregroundStyle(Palette.muted)
                    Label("購入で解放", systemImage: "lock").font(.caption.weight(.semibold)).foregroundStyle(Palette.review)
                }
                .padding(16).frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.track, lineWidth: 1))
            }
            .accessibilityLabel("\(title)、\(countLabel(questions))、有料、ロック中")
            .accessibilityIdentifier(identifier)
        } else {
            NavigationLink(value: route) { progressCard(title, questions: questions) }
                .accessibilityIdentifier(identifier)
        }
    }

    private func yearTitle(_ year: Int) -> String {
        catalog.qualification.yearTitle(year, includesNonOfficial: catalog.questions.contains {
            $0.year == year && $0.kind?.isOfficial == false
        })
    }

    private func progressCard(_ title: String, questions: [Question], compact: Bool = true) -> some View {
        CollectionProgressCard(title: title, questions: questions, data: store.data,
                               freeIDs: Set(catalog.qualification.freeQuestionIDs), unlocked: purchase.unlocked,
                               compact: compact, countLabel: countLabel(questions))
    }

    private func countLabel(_ questions: [Question]) -> String {
        let setIDs = Set(questions.compactMap(\.mockSetID))
        let unit = catalog.qualification.unit
        let original = !questions.isEmpty && questions.allSatisfy { $0.kind?.isOfficial == false }
        if catalog.qualification.resolvedLibraryStyle == .subjectPapers, original {
            return "\(setIDs.count / catalog.qualification.subjects.count)回分 · \(questions.count)\(unit)"
        }
        return original && setIDs.count > 1 ? "\(setIDs.count)セット · \(questions.count)\(unit)" : "\(questions.count)\(unit)"
    }

}

struct PredictionLibraryView: View {
    let year: Int
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let paywall: () -> Void

    private var sets: [MockSet] {
        catalog.mockSets.filter { set in
            !set.kind.isOfficial && catalog.questions.contains { $0.year == year && $0.mockSetID == set.id }
        }.sorted { $0.id < $1.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Surface(inset: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(sets.count)セットから選ぶ", systemImage: "square.stack").font(.headline)
                        Text("各\(catalog.qualification.mockQuestionCount)問・\(catalog.qualification.examMinutes)分。問題を選んで練習、または模擬試験へ。")
                            .font(.caption).foregroundStyle(Palette.muted)
                        Text(catalog.qualification.originalContentLabel).font(.caption2).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    if purchase.unlocked {
                        NavigationLink(value: QuestionCollectionRoute.mockSet(set.id)) {
                            setCard(set, number: index + 1, locked: false)
                        }.accessibilityIdentifier("predictionSet-\(set.id)")
                    } else {
                        Button(action: paywall) { setCard(set, number: index + 1, locked: true) }
                            .accessibilityIdentifier("predictionSet-\(set.id)")
                    }
                }
            }
            .buttonStyle(StudyButtonStyle())
            .padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle("\(year.formatted(.number.grouping(.never)))年予想問題")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setCard(_ set: MockSet, number: Int, locked: Bool) -> some View {
        let learned = set.questionIDs.filter { store.data.mastery[$0] != nil }.count
        return Surface(inset: 18) {
            HStack(spacing: 14) {
                Text("\(number)").font(.title2.bold().monospacedDigit()).foregroundStyle(Palette.positive)
                    .frame(width: 48, height: 48).background(Palette.positive.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 6) {
                    Text("第\(number)回").font(.title3.bold()).foregroundStyle(Palette.ink)
                    Text("\(set.questionCount)問 · \(set.minutes)分").font(.subheadline).foregroundStyle(Palette.muted)
                    Text(locked ? "購入で解放" : "学習済み \(learned)問").font(.caption).foregroundStyle(locked ? Palette.review : Palette.positive)
                }
                Spacer(minLength: 0)
                Image(systemName: locked ? "lock.fill" : "chevron.right").foregroundStyle(locked ? Palette.review : Palette.muted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(set.title)、\(set.questionCount)問、\(set.minutes)分、\(locked ? "有料、ロック中" : "学習済み\(learned)問")")
    }
}

/// Spring/autumn (or special) administrations remain independent 80-question exams.
struct PastMockLibraryView: View {
    let year: Int
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let paywall: () -> Void
    private var sets: [MockSet] {
        catalog.mockSets.filter { set in
            set.kind.isOfficial && catalog.questions.contains { $0.year == year && $0.mockSetID == set.id }
        }.sorted { $0.id > $1.id }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Surface {
                    Label("試験の回を選ぶ", systemImage: "calendar").font(.headline)
                    Text("各回の原問と公式正答で練習。模擬試験は\(catalog.qualification.mockQuestionCount)問・\(catalog.qualification.examMinutes)分です。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                ForEach(sets) { set in
                    let free = Set(set.questionIDs).isSubset(of: Set(catalog.qualification.freeQuestionIDs))
                    if purchase.unlocked || free {
                        NavigationLink(value: QuestionCollectionRoute.mockSet(set.id)) { card(set, locked: false) }
                            .accessibilityIdentifier("pastSet-\(set.id)")
                    } else {
                        Button(action: paywall) { card(set, locked: true) }
                            .accessibilityIdentifier("pastSet-\(set.id)")
                    }
                }
            }.padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
                .buttonStyle(StudyButtonStyle())
        }
        .background(Palette.background)
        .navigationTitle("\(year.formatted(.number.grouping(.never)))年度").navigationBarTitleDisplayMode(.inline)
    }
    private func card(_ set: MockSet, locked: Bool) -> some View {
        Surface {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(set.title).font(.headline).foregroundStyle(Palette.ink)
                    Text("\(set.questionCount)問 · \(set.minutes)分").font(.subheadline).foregroundStyle(Palette.muted)
                    Text(locked ? "購入で解放" : "学習済み \(set.questionIDs.filter { store.data.mastery[$0] != nil }.count)問")
                        .font(.caption).foregroundStyle(locked ? Palette.review : Palette.positive)
                }
                Spacer()
                Image(systemName: locked ? "lock.fill" : "chevron.right").foregroundStyle(Palette.muted)
            }
        }
    }
}

struct SubjectLibraryView: View {
    let subject: String
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeakPointMap(subject: subject, catalog: catalog, store: store, purchase: purchase,
                             start: start, paywall: paywall)
                NavigationLink(value: QuestionCollectionRoute.subject(subject)) {
                    FeatureCard(title: "この分野の全問題", symbol: "list.bullet",
                                detail: "\(catalog.questions.filter { $0.subject == subject }.count)問")
                }
            }
            .buttonStyle(StudyButtonStyle()).padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Palette.background).navigationTitle(subject).navigationBarTitleDisplayMode(.inline)
    }
}

/// One theme of the 弱点マップ: how it stands, what the field is and how the exam asks it, then its subcategories.
struct ThemeDetailView: View {
    let subject: String
    let topicTitle: String
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void

    var body: some View {
        let insights = ThemeInsight.ranked(catalog.topics(subject: subject), data: store.data,
                                           freeIDs: Set(catalog.qualification.freeQuestionIDs), unlocked: purchase.unlocked)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let insight = insights.first(where: { $0.title == topicTitle }) {
                    content(insight)
                } else {
                    ContentUnavailableView("テーマが見つかりません", systemImage: "questionmark.folder")
                }
            }
            .buttonStyle(StudyButtonStyle()).padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle(topicTitle).navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func content(_ insight: ThemeInsight) -> some View {
        let topic = insight.topic
        Surface(inset: 16, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MasteryBadge(level: insight.level)
                Spacer(minLength: 8)
                ExamFrequencyDots(level: insight.examFrequency)
            }
            Text(insight.statusLine).font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
                .accessibilityIdentifier("themeStatus")
            MemoryBreakdown(summary: insight.memory, identifier: "themeMemory", compact: true)
            Button {
                if let session = insight.weakSession(data: store.data) { start(session) } else { paywall() }
            } label: {
                Label(insight.locked ? "購入で解放" : "弱点を解く", systemImage: insight.locked ? "lock" : "bolt.fill")
            }
            .buttonStyle(PuffyButtonStyle(kind: insight.locked ? .plain : .primary))
            .accessibilityIdentifier("themeWeakDrill")
        }
        if let about = topic.theme?.about {
            VStack(alignment: .leading, spacing: 8) {
                Text("どんな分野か").font(.headline).accessibilityAddTraits(.isHeader)
                MarkupText(text: about, role: .body, setsFont: true)
            }
            .accessibilityIdentifier("themeAbout")
        }
        if let exam = topic.theme?.exam {
            CalloutView(style: .exam, title: "試験での問われ方", text: exam)
        }
        if let links = topic.theme?.links, !links.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(links, id: \.self) { link in
                    if let value = link.url, let url = URL(string: value) {
                        Link(destination: url) {
                            Label(link.title, systemImage: "book")
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .accessibilityIdentifier("themeLink")
                    }
                }
            }
        }
        let subtopics = catalog.qualification.subcategoryDrill == true ? StudySubtopic.grouped(topic: topic) : []
        NavigationLink(value: QuestionCollectionRoute.subjectTopic(subject, topicTitle)) {
            FeatureCard(title: "このテーマの全問題", symbol: "list.bullet", detail: "\(topic.questions.count)問")
        }
        .accessibilityIdentifier("topic-all-\(topicTitle)")
        if subtopics.count > 1 {
            ForEach(subtopics) { subtopic in
                NavigationLink(value: QuestionCollectionRoute.subjectSubtopic(subject, topicTitle, subtopic.title)) {
                    CollectionProgressCard(title: subtopic.title, questions: subtopic.questions, data: store.data,
                                           freeIDs: Set(catalog.qualification.freeQuestionIDs), unlocked: purchase.unlocked,
                                           compact: false)
                }
                .accessibilityIdentifier("subcategory-\(subtopic.title)")
            }
            if subtopics.contains(where: { $0.title == StudySubtopic.unreviewedTitle }) {
                Text("2015年以前の未校閲問題は、誤った細分類を付けないよう、この一覧ではまとめて表示しています。")
                    .font(.caption).foregroundStyle(Palette.muted)
                    .padding(.horizontal, 4)
            }
        }
    }
}

extension MasteryLevel {
    var color: Color {
        switch self {
        case .new: Palette.muted
        case .weak: Palette.review
        case .growing: Palette.growing
        case .solid: Palette.positive
        }
    }

    var symbol: String {
        switch self {
        case .new: "circle.dashed"
        case .weak: "exclamationmark.circle.fill"
        case .growing: "circle.lefthalf.filled"
        case .solid: "checkmark.circle.fill"
        }
    }
}

struct MasteryLegend: View {
    var levels: [MasteryLevel] = MasteryLevel.allCases

    var body: some View {
        FlowLayout(spacing: 12, lineSpacing: 4) {
            ForEach(levels, id: \.self) { level in
                Label { Text(level.title) } icon: { Image(systemName: level.symbol).foregroundStyle(level.color) }
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("色の意味：" + levels.map(\.title).joined(separator: "、"))
    }
}

struct MasteryBadge: View {
    let level: MasteryLevel

    var body: some View {
        Label { Text(level.title) } icon: { Image(systemName: level.symbol) }
            .font(.caption.bold()).foregroundStyle(level.color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(level.color.opacity(0.12), in: Capsule())
            .fixedSize()
    }
}

/// 本番での出題の多さ as three dots.
struct ExamFrequencyDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            Text("出題").font(.caption).foregroundStyle(Palette.muted)
            ForEach(1...3, id: \.self) { step in
                Circle().fill(step <= level ? Palette.beak : Palette.track).frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本番での出題")
        .accessibilityValue(["少なめ", "普通", "多い"][max(0, min(2, level - 1))])
    }
}

extension ThemeInsight {
    /// Free users see how many of the theme's questions they can open.
    var countLabel: String {
        let total = topic.questions.count
        return locked || available.count == total ? "\(total)問" : "無料 \(available.count) / \(total)問"
    }

    var statusLine: String {
        guard let accuracy else { return countLabel }
        return "正答率 \(Int((accuracy * 100).rounded()))% · 復習 \(reviewCount)問 · \(countLabel)"
    }
}

/// 弱点マップ: one subject's themes coloured by mastery, the most urgent first, each one tap from a drill.
struct WeakPointMap: View {
    let subject: String
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void

    var body: some View {
        let insights = ThemeInsight.ranked(catalog.topics(subject: subject), data: store.data,
                                           freeIDs: Set(catalog.qualification.freeQuestionIDs), unlocked: purchase.unlocked)
        VStack(alignment: .leading, spacing: 12) {
            Text("弱点マップ").font(.headline).accessibilityAddTraits(.isHeader)
            MasteryLegend()
            ForEach(insights) { insight in
                ThemeCard(insight: insight, subject: subject,
                          opensDetail: catalog.qualification.subcategoryDrill == true || insight.topic.theme != nil,
                          solve: { solve(insight) })
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("subjectMap")
    }

    private func solve(_ insight: ThemeInsight) {
        guard let session = insight.weakSession(data: store.data) else { paywall(); return }
        start(session)
    }
}

struct ThemeCard: View {
    let insight: ThemeInsight
    let subject: String
    let opensDetail: Bool
    let solve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if opensDetail {
                NavigationLink(value: StudyDestination.theme(subject, insight.title)) { summary }
                    .accessibilityIdentifier("category-\(insight.title)")
            } else {
                NavigationLink(value: QuestionCollectionRoute.subjectTopic(subject, insight.title)) { summary }
                    .accessibilityIdentifier("category-\(insight.title)")
            }
            HStack {
                ExamFrequencyDots(level: insight.examFrequency)
                Spacer(minLength: 8)
                Button(action: solve) {
                    Label(insight.locked ? "購入で解放" : "弱点を解く", systemImage: insight.locked ? "lock" : "bolt.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(insight.locked ? Palette.muted : Palette.onPiyo)
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(insight.locked ? Palette.track : Palette.piyo, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(StudyButtonStyle())
                .accessibilityIdentifier("weakDrill-\(insight.title)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22)
                .fill(insight.level == .new ? Palette.border : insight.level.color).frame(width: 6).accessibilityHidden(true)
        }
        .popCard(radius: 22)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(insight.title).font(.headline).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                MasteryBadge(level: insight.level)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.muted).accessibilityHidden(true)
            }
            Text(insight.statusLine).font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
            MemoryBar(stable: insight.memory.stable, growing: insight.memory.growing, new: insight.memory.new)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(insight.title)、\(insight.level.title)、\(insight.statusLine)")
    }
}

struct QuickQuizView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    private var levels: [Int] { Array(Set(catalog.questions.map(\.difficulty))).sorted() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Lvを選んで、5問に挑戦").font(.headline)
                Text("難易度ごとに出題。問題が5問未満のLvは、ある問題をすべて出題します。")
                    .font(.caption).foregroundStyle(Palette.muted)
                ForEach(levels, id: \.self) { level in
                    let questions = QuizLevel.questions(level: level, catalog: catalog, unlocked: purchase.unlocked)
                    let learned = questions.filter { store.data.mastery[$0.id] != nil }.count
                    Button {
                        start(StudySession(title: "小テスト · Lv\(level)", mode: .random,
                                           questions: Array(questions.shuffled().prefix(5)), timed: false))
                    } label: {
                        HStack(spacing: 16) {
                            Text("Lv\(level)").font(.title2.bold().monospacedDigit()).foregroundStyle(Palette.positive)
                                .frame(width: 64, height: 64).background(Palette.positive.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(QuizLevel.title(level)).font(.headline)
                                Text(questions.isEmpty ? "利用できる問題がありません" : "\(min(5, questions.count))問出題 · 学習済み \(learned)問")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "play.fill").foregroundStyle(Palette.positive)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .disabled(questions.isEmpty).accessibilityIdentifier("quizLevel-\(level)")
                }
            }
            .buttonStyle(StudyButtonStyle()).padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Palette.background).navigationTitle("小テスト").navigationBarTitleDisplayMode(.inline)
    }
}
