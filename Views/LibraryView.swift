import SwiftUI

enum StudyDestination: Hashable { case years, subjects, records, quiz, subjectCategories(String), topicSubcategories(String, String) }
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
    private var title: String { section == .years ? "年度別演習" : "分野別演習" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Surface(inset: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: section == .years ? "calendar" : "square.grid.2x2")
                            .font(.title2).foregroundStyle(Palette.positive).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section == .years ? "年度から選ぶ" : "分野から選ぶ").font(.headline)
                            Text(section == .years ? "過去問・予想問題から選んで取り組もう。" : "分野のマップから、学びたいテーマへ。")
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
                        ForEach(years, id: \.self) { year in
                            let questions = catalog.questions.filter { $0.year == year }
                            let locked = !purchase.unlocked && !questions.contains { catalog.qualification.freeQuestionIDs.contains($0.id) }
                            if locked {
                                Button(action: paywall) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(yearTitle(year)).font(.title3.bold())
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
                                .accessibilityLabel("\(yearTitle(year))、\(countLabel(questions))、有料、ロック中")
                                .accessibilityIdentifier("year-\(year)")
                            } else {
                                NavigationLink(value: QuestionCollectionRoute.year(year)) {
                                    progressCard(yearTitle(year), questions: questions)
                                }.accessibilityIdentifier("year-\(year)")
                            }
                        }
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

    private func yearTitle(_ year: Int) -> String {
        if catalog.qualification.id == "fundamental-information" {
            return year.formatted(.number.grouping(.never)) +
                (catalog.questions.contains { $0.year == year && $0.kind == .prediction } ? "年 過去問・練習" : "年 公開過去問")
        }
        let suffix = catalog.questions.contains { $0.year == year && $0.kind == .prediction } ? "年予想問題" : "年"
        return year.formatted(.number.grouping(.never)) + suffix
    }

    private func progressCard(_ title: String, questions: [Question], compact: Bool = true) -> some View {
        CollectionProgressCard(title: title, questions: questions, data: store.data,
                               freeIDs: Set(catalog.qualification.freeQuestionIDs), unlocked: purchase.unlocked,
                               compact: compact, countLabel: countLabel(questions))
    }

    private func countLabel(_ questions: [Question]) -> String {
        let setIDs = Set(questions.compactMap(\.mockSetID))
        return !questions.isEmpty && questions.allSatisfy { $0.kind == .prediction } && setIDs.count > 1
            ? "\(setIDs.count)セット · \(questions.count)問" : "\(questions.count)問"
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
            set.kind == .prediction && catalog.questions.contains { $0.year == year && $0.mockSetID == set.id }
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
            set.kind == .past && catalog.questions.contains { $0.year == year && $0.mockSetID == set.id }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let subject: String
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    @State private var zoom: CGFloat = 1
    @State private var gestureZoom: CGFloat = 1
    private var questions: [Question] { catalog.questions.filter { $0.subject == subject } }
    private var topics: [StudyTopic] { StudyTopic.grouped(subject: subject, questions: questions) }
    private var mapHeight: CGFloat { topics.count <= 2 ? 320 : 480 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("学びのマップ").font(.headline)
                        Text(["applied-information", "fundamental-information"].contains(catalog.qualification.id) ? "テーマをタップして、さらに絞り込む" : "テーマをタップして問題へ")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    if !dynamicTypeSize.isAccessibilitySize {
                        Button { zoom = max(1, zoom - 0.25); gestureZoom = zoom } label: { Image(systemName: "minus.magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("マップを縮小")
                        Button { zoom = min(2, zoom + 0.25); gestureZoom = zoom } label: { Image(systemName: "plus.magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("マップを拡大")
                    }
                }
                if dynamicTypeSize.isAccessibilitySize {
                    ForEach(topics) { topic in topicLink(topic) }
                } else {
                    GeometryReader { geometry in
                        let width = max(340, geometry.size.width)
                        ScrollView([.horizontal, .vertical]) {
                            map(width: width)
                                .scaleEffect(zoom, anchor: .topLeading)
                                .frame(width: width * zoom, height: mapHeight * zoom, alignment: .topLeading)
                        }
                        .simultaneousGesture(MagnificationGesture().onChanged { zoom = min(2, max(1, gestureZoom * $0)) }.onEnded { _ in gestureZoom = zoom })
                    }
                    .frame(height: mapHeight)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityIdentifier("subjectMap")
                }
                NavigationLink(value: QuestionCollectionRoute.subject(subject)) {
                    FeatureCard(title: "この分野の全問題", symbol: "list.bullet", detail: "\(questions.count)問")
                }
            }
            .buttonStyle(StudyButtonStyle()).padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Palette.background).navigationTitle(subject).navigationBarTitleDisplayMode(.inline)
    }

    private func position(_ index: Int, width: CGFloat) -> CGPoint {
        let center = width / 2
        let positions: [CGPoint]
        switch topics.count {
        case 1: positions = [CGPoint(x: center, y: 56)]
        case 2: positions = [CGPoint(x: center, y: 52), CGPoint(x: center, y: mapHeight - 52)]
        case 3: positions = [CGPoint(x: center, y: 56), CGPoint(x: width - 64, y: 350), CGPoint(x: 64, y: 350)]
        case 4: positions = [CGPoint(x: center, y: 56), CGPoint(x: width - 64, y: 240), CGPoint(x: center, y: 424), CGPoint(x: 64, y: 240)]
        case 5: positions = [CGPoint(x: center, y: 56), CGPoint(x: width - 64, y: 166), CGPoint(x: width - 64, y: 350), CGPoint(x: 64, y: 350), CGPoint(x: 64, y: 166)]
        default: positions = [CGPoint(x: center, y: 56), CGPoint(x: width - 64, y: 166), CGPoint(x: width - 64, y: 314), CGPoint(x: center, y: 424), CGPoint(x: 64, y: 314), CGPoint(x: 64, y: 166)]
        }
        // Dense catalogs are grouped into at most six themes. Generic subjects may use more categories.
        if positions.indices.contains(index) { return positions[index] }
        let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(topics.count)
        return CGPoint(x: center + cos(angle) * width * 0.30, y: mapHeight / 2 + sin(angle) * (mapHeight / 2 - 56))
    }

    private func map(width: CGFloat) -> some View {
        ZStack {
            Canvas { context, size in
                // Subtle graph dots establish space; links show the real subject/theme hierarchy.
                for x in stride(from: 12.0, through: size.width, by: 20) {
                    for y in stride(from: 12.0, through: size.height, by: 20) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(Palette.track.opacity(0.55)))
                    }
                }
                for index in topics.indices {
                    var path = Path()
                    path.move(to: CGPoint(x: width / 2, y: mapHeight / 2))
                    path.addLine(to: position(index, width: width))
                    context.stroke(path, with: .color(Palette.positive.opacity(0.35)), lineWidth: 2)
                }
            }.accessibilityHidden(true)
            VStack(spacing: 6) {
                Image(systemName: "point.3.connected.trianglepath.dotted").font(.title2)
                Text(subject).font(.caption.bold()).multilineTextAlignment(.center)
            }
            .foregroundStyle(Palette.positive).padding(10).frame(width: 82, height: 82)
            .background(Palette.background, in: Circle())
            .overlay(Circle().stroke(Palette.positive.opacity(0.5), lineWidth: 2))
            .position(x: width / 2, y: mapHeight / 2)
            ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                topicLink(topic).frame(width: 122).position(position(index, width: width))
            }
        }
        .frame(width: width, height: mapHeight)
    }

    @ViewBuilder private func topicLink(_ topic: StudyTopic) -> some View {
        if ["applied-information", "fundamental-information"].contains(catalog.qualification.id) {
            NavigationLink(value: StudyDestination.topicSubcategories(subject, topic.title)) {
                topicCard(topic)
            }
            .accessibilityLabel("\(topic.title)、\(topic.questions.count)問")
            .accessibilityIdentifier("category-\(topic.title)")
        } else {
            NavigationLink(value: QuestionCollectionRoute.subjectTopic(subject, topic.title)) {
                topicCard(topic)
            }
            .accessibilityLabel("\(topic.title)、\(topic.questions.count)問")
            .accessibilityIdentifier("category-\(topic.title)")
        }
    }

    private func topicCard(_ topic: StudyTopic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(topic.title).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            let available = topic.questions.filter { purchase.unlocked || catalog.qualification.freeQuestionIDs.contains($0.id) }
            let answered = available.filter { store.data.mastery[$0.id] != nil }.count
            Text("\(topic.questions.count)問").font(.caption).foregroundStyle(Palette.muted)
            if available.isEmpty { Label("有料", systemImage: "lock").font(.caption).foregroundStyle(Palette.review) }
            else { Text("学習済み \(answered)問").font(.caption2).foregroundStyle(Palette.positive) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.positive.opacity(0.4), lineWidth: 1.5))
    }
}

struct StudySubtopicLibraryView: View {
    let subject: String
    let topicTitle: String
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager

    private var topic: StudyTopic? {
        StudyTopic.grouped(subject: subject, questions: catalog.questions).first { $0.title == topicTitle }
    }
    private var subtopics: [StudySubtopic] {
        topic.map { StudySubtopic.grouped(topic: $0) } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Surface(inset: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("サブカテゴリから選ぶ", systemImage: "square.grid.2x2").font(.headline)
                        Text("\(topic?.questions.count ?? 0)問を、もう一段階テーマで絞れます。")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if let topic {
                    NavigationLink(value: QuestionCollectionRoute.subjectTopic(subject, topicTitle)) {
                        FeatureCard(title: "このテーマの全問題", symbol: "list.bullet", detail: "\(topic.questions.count)問")
                    }
                    .accessibilityIdentifier("topic-all-\(topicTitle)")
                }
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
            .buttonStyle(StudyButtonStyle()).padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle(topicTitle).navigationBarTitleDisplayMode(.inline)
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
