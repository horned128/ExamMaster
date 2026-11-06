import SwiftUI
import Combine

struct MockExamSessionView: View {
    let session: StudySession
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let onFinish: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var now = Date()
    @State private var showNavigator = false
    @State private var confirmFinish = false
    @State private var confirmExit = false
    @State private var result: MockResult?
    @State private var choicesJump = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var pending: PendingMock? { store.data.pendingMock?.id == session.id ? store.data.pendingMock : nil }
    private var index: Int { min(pending?.index ?? 0, session.questions.count - 1) }
    private var question: Question { session.questions[index] }
    private var unanswered: Int { session.questions.count - (pending?.selections.count ?? 0) }

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    MockResultDetailView(result: result, catalog: catalog, purchase: purchase)
                        .safeAreaInset(edge: .bottom) {
                            Button("学習を終える") {
                                onFinish(result.questionResults?.filter { $0.selectedIndex != nil }.count ?? 0)
                                dismiss()
                            }.buttonStyle(PuffyButtonStyle())
                                .padding(.horizontal, 16)
                                .accessibilityIdentifier("mockResultFinish")
                                .padding().frame(maxWidth: .infinity).background(.bar)
                        }
                } else if pending != nil { exam }
                else {
                    ContentUnavailableView("模試を開けません", systemImage: "exclamationmark.triangle")
                }
            }
            .background(Palette.background)
            .navigationTitle(session.title).navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                if result == nil, pending != nil, dynamicTypeSize.isAccessibilitySize {
                    HStack {
                        Text("残り時間").font(.caption)
                        Spacer(minLength: 8)
                        remainingTime.font(.body)
                    }.padding(.horizontal, 20).padding(.vertical, 8).background(.bar)
                }
            }
            .toolbar {
                if result == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("閉じる", systemImage: "xmark") { confirmExit = true }.labelStyle(.iconOnly)
                            .accessibilityLabel("模試を中断").accessibilityIdentifier("mockSuspend")
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        ToolbarItem(placement: .topBarTrailing) { remainingTime }
                    }
                }
            }
        }
        .interactiveDismissDisabled(result == nil)
        .sheet(isPresented: $showNavigator) { navigator }
        .confirmationDialog("模試を終了して採点しますか？", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("終了して採点", role: .destructive) { finish() }.accessibilityIdentifier("mockConfirmFinish")
            Button("続ける", role: .cancel) { }
        } message: { Text("未回答 \(unanswered)問。未回答は得点上は不正解ですが、習熟度は変わりません。") }
        .confirmationDialog("模試を中断しますか？", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("問題一覧へ戻る", role: .destructive) { store.clearInterruptedStudy(); dismiss() }
            Button("続ける", role: .cancel) { }
        } message: { Text("途中の回答と出題位置を削除します。採点済みの学習記録は残ります。") }
        .onReceive(timer) { date in now = date; expireIfNeeded() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now; expireIfNeeded() } }
        .onAppear { expireIfNeeded() }
    }

    private var remainingTime: some View {
        let seconds = Int(pending?.remaining(at: now) ?? 0)
        let clock = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        return Text(clock).monospacedDigit().fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(seconds < 60 ? .red : .primary)
            .accessibilityLabel("残り時間 \(seconds / 60)分\(seconds % 60)秒")
            .accessibilityValue(clock)
            .accessibilityIdentifier("mockRemainingTime")
    }

    private var exam: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("\(index + 1) / \(session.questions.count)問 · 未回答 \(unanswered)問").font(.subheadline.monospacedDigit()).id("top")
                        Text(catalog.qualification.displaySource(question.source)).font(.caption).foregroundStyle(Palette.muted)
                        QuestionBodyView(question: question)
                        ForEach(question.choices.indices, id: \.self) { choice in
                            Button {
                                if pending?.remaining() == 0 { finish() }
                                else { store.selectMock(choice, question: question, attemptID: session.id) }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: pending?.selections[question.id] == choice ? "largecircle.fill.circle" : "circle")
                                    Text(catalog.qualification.choiceLabel(choice)).bold()
                                    Text(question.choices[choice]).frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(16).foregroundStyle(Palette.ink).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(StudyButtonStyle())
                                .id(choice == 0 ? "answerChoices" : "answerChoice-\(choice)")
                                .accessibilityIdentifier("mockChoice-\(choice)")
                                .accessibilityAddTraits(pending?.selections[question.id] == choice ? .isSelected : [])
                            if let blocks = question.choiceBlocks { RichContentView(blocks: blocks[choice], wrapsTables: question.subject == "科目B") }
                        }
                        if pending?.selections[question.id] != nil {
                            Button("回答を取り消す") { store.selectMock(nil, question: question, attemptID: session.id) }
                                .frame(minHeight: 44)
                        }
                        if let error = store.error {
                            Text(error).foregroundStyle(Palette.review)
                            Button("保存・採点を再試行") { if pending?.remaining() == 0 { finish() } else { store.retrySave() } }
                        }
                    }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
                }.accessibilityIdentifier("mockQuestionScroll")
                    .onChange(of: index) { _, _ in proxy.scrollTo("top", anchor: .top) }
                    .onChange(of: choicesJump) { _, _ in proxy.scrollTo("answerChoices", anchor: .top) }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if question.subject == "科目B" {
                LongQuestionQuickActions(question: question) { choicesJump += 1 }.id(question.id)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        previousButton
                        Spacer()
                        navigatorButton
                        Spacer()
                        nextButton
                    }
                    VStack(spacing: 8) {
                        HStack { previousButton; Spacer(); nextButton }
                        navigatorButton
                    }
                }
                Button { confirmFinish = true } label: {
                    Text("終了して採点")
                }.buttonStyle(PuffyButtonStyle(minHeight: 50))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("mockFinish")
            }.padding(.horizontal, 20).padding(.vertical, 8).background(.bar)
                .accessibilityElement(children: .contain).accessibilityIdentifier("mockControls")
        }
    }

    private var previousButton: some View {
        Button { move(index - 1) } label: {
            Text("前へ").frame(minHeight: 44).contentShape(Rectangle())
        }.disabled(index == 0).fixedSize()
    }
    private var navigatorButton: some View {
        Button { showNavigator = true } label: {
            Text("問題一覧").frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityIdentifier("mockNavigator").fixedSize()
    }
    private var nextButton: some View {
        Button { move(index + 1) } label: {
            Text("次へ").frame(minHeight: 44).contentShape(Rectangle())
        }.disabled(index + 1 == session.questions.count).fixedSize()
    }

    private var navigator: some View {
        NavigationStack {
            List(session.questions.indices, id: \.self) { position in
                let item = session.questions[position]
                Button { move(position); showNavigator = false } label: {
                    HStack {
                        Text("問\(position + 1)")
                        Spacer()
                        Text(pending?.selections[item.id].map { "回答: \(catalog.qualification.choiceLabel($0))" } ?? "未回答")
                    }.frame(minHeight: 44)
                }.accessibilityIdentifier("mockJump-\(position)")
            }.navigationTitle("問題一覧 · 未回答 \(unanswered)問")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showNavigator = false } } }
        }
    }
    private func move(_ index: Int) { if pending?.remaining() == 0 { finish() } else { store.moveMock(to: index, attemptID: session.id) } }
    private func expireIfNeeded() { if result == nil, pending?.remaining() == 0 { finish() } }
    private func finish() {
        guard result == nil else { return }
        showNavigator = false
        result = store.completeMock(attemptID: session.id, catalog: catalog)
        if result != nil { store.updateMascotGrowth(questions: SessionPlanner.available(catalog, unlocked: purchase.unlocked)) }
    }
}

struct MockResultHistoryView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    var body: some View {
        List {
            ForEach(store.data.mocks.reversed()) { result in
                NavigationLink { MockResultDetailView(result: result, catalog: catalog, purchase: purchase) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title ?? "模擬試験")
                        Text("\(result.date.formatted(date: .abbreviated, time: .shortened)) · \(result.score) / \(result.total)")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
        }.navigationTitle("模試の成績履歴").navigationBarTitleDisplayMode(.inline)
    }
}

struct MockResultDetailView: View {
    let result: MockResult
    let catalog: Catalog
    let purchase: PurchaseManager
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(result.earnedPoints.map { "\($0) / \(result.possiblePoints ?? 100)点 · \(result.score) / \(result.total)問正解" } ??
                     "\(result.score) / \(result.total)問 · \(result.percent)%").font(.title.bold()).monospacedDigit()
                Text(result.passed ? (catalog.qualification.mockPassTitle ?? "設定した基準に到達") : "基準点未到達").font(.headline)
                Text(catalog.qualification.id == "denken3" ?
                     "科目別に公式配点で採点。60点を学習の目安にしています。実際の合格基準は各回の公式発表を確認してください。" :
                     catalog.qualification.id == "fundamental-information" ?
                     "練習の目安：正答率60%。本試験のIRT評価点（各科目600点）とは異なります。" :
                     "全体 \(catalog.qualification.passingPercent)%" + (catalog.qualification.minimumSubjectPercent > 0 ? " · 各科目 \(catalog.qualification.minimumSubjectPercent)%" : " · 分野別足切りなし"))
                    .font(.subheadline).foregroundStyle(Palette.muted)
                if let duration = result.duration { Text("所要時間 \(Int(duration) / 60)分\(Int(duration) % 60)秒").font(.subheadline.monospacedDigit()) }
                if let items = result.questionResults {
                    Text("未回答 \(items.filter { $0.outcome == .unanswered }.count)問").font(.subheadline)
                    ForEach(items) { item in
                        if let question = catalog.questions.first(where: { $0.id == item.questionID }) {
                            DisclosureGroup {
                                if purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) {
                                    QuestionBodyView(question: question)
                                    ForEach(question.choices.indices, id: \.self) { index in
                                        Text("\(catalog.qualification.choiceLabel(index)) · \(question.choices[index])")
                                        if let blocks = question.choiceBlocks { RichContentView(blocks: blocks[index], wrapsTables: question.subject == "科目B") }
                                    }
                                    QuestionExplanationView(question: question, qualification: catalog.qualification)
                                    if let steps = question.steps { ForEach(steps.indices, id: \.self) { Text("\($0 + 1). \(steps[$0])") } }
                                } else { Label("解説の閲覧には全問題解放が必要です", systemImage: "lock") }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(item.outcome.title) · 回答 \(item.selectedIndex.map { catalog.qualification.choiceLabel($0) } ?? "なし")")
                                        .font(.subheadline.bold())
                                    Text(catalog.qualification.displaySource(question.source)).font(.caption).foregroundStyle(Palette.muted)
                                }.padding(.vertical, 8)
                            }
                        }
                    }
                } else { Text("旧バージョンの結果には問題別の記録がありません").font(.caption).foregroundStyle(Palette.muted) }
                Text("分野別の結果").font(.headline)
                ForEach(result.subjectScores.keys.sorted(), id: \.self) { subject in
                    Text("\(subject): \(result.subjectScores[subject] ?? 0)問正解").font(.subheadline)
                }
            }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("mockResultScroll")
            .background(Palette.background).navigationTitle("模試の結果").navigationBarTitleDisplayMode(.inline)
    }
}
