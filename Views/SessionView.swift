import SwiftUI
import Combine

struct SessionView: View {
    let session: StudySession
    let qualification: Qualification
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let growthQuestions: [Question]
    @State private var initialGrowthStage: TankeiStage
    let resume: PendingStudy?
    let onFinish: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var choiceMarkerSize: CGFloat = 28
    @AccessibilityFocusState private var feedbackFocused: Bool
    @State private var index = 0
    @State private var selected: Int?
    @State private var confidence: Confidence?
    @State private var revealed = false
    @State private var submitted = false
    @State private var finished = false
    @State private var showGrowthCelebration = false
    @State private var startedAt = Date()
    @State private var answers: [Answer] = []
    @State private var visibleSteps = 0
    @State private var confirmExit = false
    @State private var deadline: Date
    @State private var remaining: TimeInterval
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: StudySession, qualification: Qualification, store: StudyStore, purchase: PurchaseManager, ads: AdsService,
         growthQuestions: [Question],
         resume: PendingStudy? = nil,
         onFinish: @escaping (Int) -> Void) {
        self.session = session
        self.qualification = qualification
        self.store = store
        self.purchase = purchase
        self.ads = ads
        self.growthQuestions = growthQuestions
        _initialGrowthStage = State(initialValue: TankeiGrowth(questions: growthQuestions, data: store.data, earnedOnly: true).stage)
        self.resume = resume
        self.onFinish = onFinish
        _index = State(initialValue: min(max(0, resume?.index ?? 0), max(0, session.questions.count - 1)))
        _answers = State(initialValue: resume?.answers ?? [])
        _selected = State(initialValue: resume?.selectedIndex)
        _submitted = State(initialValue: resume?.submitted ?? false)
        _revealed = State(initialValue: resume?.submitted ?? false)
        let seconds = TimeInterval(qualification.examMinutes * 60)
        _deadline = State(initialValue: .now.addingTimeInterval(seconds))
        _remaining = State(initialValue: seconds)
    }

    private var question: Question { session.questions[index] }
    private var recallMode: Bool {
        store.data.recallFirst && [.recommended, .misconception, .contrast, .incorrect, .bookmarked].contains(session.mode)
    }

    var body: some View {
        NavigationStack {
            Group {
                if showGrowthCelebration {
                    TankeiGrowthCelebration(initialStage: initialGrowthStage, stage: growth.stage, accentHex: qualification.accentHex,
                                            buttonTitle: session.mode == .search ? "一覧へ戻る" : "結果を見る") {
                        if session.mode == .search { closeSession() }
                        else { showGrowthCelebration = false }
                    }
                } else if finished { summary }
                else { questionScreen }
            }
            .background(Palette.background)
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !finished {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("閉じる", systemImage: "xmark") { confirmExit = true }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("学習を中断")
                    }
                    if session.timed {
                        ToolbarItem(placement: .topBarTrailing) {
                            Label(timeString, systemImage: "timer")
                                .monospacedDigit()
                                .foregroundStyle(remaining < 60 ? .red : .primary)
                                .accessibilityLabel("残り時間 \(timeString)")
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                store.toggleBookmark(question.id)
                            } label: {
                                Image(systemName: store.data.bookmarks.contains(question.id) ? "bookmark.fill" : "bookmark")
                            }
                            .accessibilityLabel(store.data.bookmarks.contains(question.id) ? "お気に入りを解除" : "お気に入りに追加")
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(!finished)
        .confirmationDialog("問題の途中ですが、中断しますか？", isPresented: $confirmExit, titleVisibility: .visible) {
            Button(session.timed ? "模試を中断する" : (session.mode == .diagnostic ? "診断を中断する" :
                   (session.mode == .search ? "問題を閉じる" : "中断して後で再開")), role: .destructive) { dismiss() }
            Button("学習を続ける", role: .cancel) { }
        } message: {
            if session.timed {
                Text("\(session.questions.count)問中\(index + 1)問目。模試の途中位置・結果は保存されず、再開できません。回答済みの学習履歴は残ります。")
            } else if session.mode == .diagnostic {
                Text("回答済みの履歴は残ります。診断は次回、最初から受け直せます。")
            } else if session.mode == .search {
                Text("回答済みの場合は学習履歴に記録されています。元の問題リストに戻ります。")
            } else {
                Text("\(session.questions.count)問中\(index + 1)問目。回答済みの\(answers.count)問と出題順を保存し、ホームの「続きから」で再開できます。")
            }
        }
        .onReceive(timer) { _ in
            guard session.timed, !finished else { return }
            remaining = max(0, deadline.timeIntervalSinceNow)
            if remaining == 0 { finish() }
        }
    }

    private var timeString: String {
        let seconds = Int(max(0, remaining))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var questionScreen: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(index + (submitted ? 1 : 0)), total: Double(max(1, session.questions.count)))
                .accessibilityLabel("進捗")
                .accessibilityValue("\(session.questions.count)問中\(index + 1)問目")
            ScrollViewReader { proxy in
              ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(index + 1) / \(session.questions.count)問").font(.subheadline.bold().monospacedDigit())
                        Text("\(question.year.formatted(.number.grouping(.never))) · \(question.subject)")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    .id("questionTop")
                    Text(question.stem).font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let image = question.imageName {
                        Image(image).resizable().scaledToFit()
                            .accessibilityLabel("問題図版")
                    }
                    if recallMode && !revealed {
                        Surface {
                            Label("答えを思い浮かべる", systemImage: "bubble.left")
                                .font(.headline)
                            Text("難しいときは、すぐ開いても大丈夫。")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(question.choices.indices, id: \.self) { choice in
                                choiceButton(choice)
                            }
                        }
                        if !submitted && !session.timed {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("手応え · 任意").font(.caption).foregroundStyle(Palette.muted)
                                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                                            Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                    ForEach(Confidence.allCases) { item in
                                        Button { confidence = confidence == item ? nil : item } label: {
                                            Text(item.title).font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                                        }
                                            .buttonStyle(.bordered)
                                            .tint(confidence == item ? Palette.linkAccent(qualification.accentHex) : Palette.muted)
                                            .accessibilityAddTraits(confidence == item ? .isSelected : [])
                                    }
                                }
                            }
                        }
                        if submitted && !session.timed { feedback.id("feedback") }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
              }
              .onChange(of: index) { _, _ in proxy.scrollTo("questionTop", anchor: .top) }
              .onChange(of: submitted) { _, value in
                  if value {
                      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                          proxy.scrollTo("feedback", anchor: .top)
                      }
                      feedbackFocused = true
                  }
              }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if recallMode && !revealed {
                Button("選択肢を見る") { revealed = true }
                    .font(.headline).frame(maxWidth: 640, minHeight: 44)
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .tint(Palette.accent(qualification.accentHex)).foregroundStyle(Palette.onAccent(qualification.accentHex))
                    .padding(16).frame(maxWidth: .infinity).background(.bar)
            } else {
                Button {
                    if submitted { advance() } else { submit() }
                } label: {
                    Text(submitted ? (session.mode == .search ? "一覧へ戻る" : (index + 1 == session.questions.count ? "結果を見る" : "次の問題へ")) :
                         (session.timed && index + 1 == session.questions.count ? "回答して採点する" : "回答を確定"))
                         .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent(qualification.accentHex)).foregroundStyle(Palette.onAccent(qualification.accentHex))
                .disabled(selected == nil && !submitted)
                .padding(16).frame(maxWidth: 672).frame(maxWidth: .infinity)
                .background(.bar)
                .accessibilityIdentifier("submitOrAdvance")
            }
        }
    }

    private func choiceButton(_ choice: Int) -> some View {
        let isCorrect = submitted && choice == question.correctIndex
        let isWrong = submitted && choice == selected && choice != question.correctIndex
        return Button {
            if !submitted { selected = choice }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(String(UnicodeScalar(65 + choice)!))
                    .font(.subheadline.bold())
                    .frame(width: choiceMarkerSize, height: choiceMarkerSize)
                    .background(.tint.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                Text(question.choices[choice]).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if isCorrect { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.positive).accessibilityHidden(true) }
                if isWrong { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.review).accessibilityHidden(true) }
            }
            .padding(15)
            .foregroundStyle(Palette.ink)
            .background(selected == choice ? Palette.linkAccent(qualification.accentHex).opacity(0.13) : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(selected == choice ? Palette.linkAccent(qualification.accentHex) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(StudyButtonStyle())
        .disabled(submitted)
        .accessibilityLabel("選択肢 \(choice + 1)、\(question.choices[choice])\(isCorrect ? "、正答" : isWrong ? "、あなたの回答" : "")")
        .accessibilityAddTraits(selected == choice ? .isSelected : [])
    }

    private var feedback: some View {
        let correct = selected == question.correctIndex
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return VStack(alignment: .leading, spacing: 14) {
            layout {
                HStack(spacing: 10) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 32, weight: .semibold)).accessibilityHidden(true)
                    Text(correct ? "正解です" : "答えを確認")
                        .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                        .accessibilityFocused($feedbackFocused)
                        .accessibilityIdentifier("answerOutcome")
                        #if DEBUG
                        .accessibilityValue("相棒：\(initialGrowthStage.title)")
                        #endif
                }
                .foregroundStyle(correct ? Palette.positive : Palette.review)
                .frame(maxWidth: .infinity, alignment: .leading)
                TankeiView(state: correct ? .celebrate : .recover,
                           stage: initialGrowthStage, size: 120, animated: true, idle: true, expressive: true, eventID: index)
            }
            if let steps = question.steps {
                Text("解き方").font(.headline)
                ForEach(0..<visibleSteps, id: \.self) { step in
                    Text("\(step + 1). \(steps[step])").font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if visibleSteps < steps.count {
                    Button("次のステップ") {
                        visibleSteps += 1
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                }
            }
            if question.steps == nil || visibleSteps == question.steps?.count {
                Text(question.explanation).font(.body)
                DisclosureGroup("出典") {
                    Text(question.source).font(.caption).foregroundStyle(Palette.muted)
                }
                .font(.caption)
            }
            if let due = store.data.mastery[question.id]?.dueAt {
                Divider()
                StudyBadge(title: "復習の目安 · \(ReviewOutlook.label(for: due))", symbol: "calendar", color: Palette.positive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func submit() {
        guard let selected else { return }
        let answer = Answer(questionID: question.id, date: .now, selectedIndex: selected,
                            correct: selected == question.correctIndex,
                            duration: max(0, Date().timeIntervalSince(startedAt)),
                            confidence: session.timed ? nil : confidence, mode: session.mode)
        answers.append(answer)
        var progress = store.data.pending
        if progress?.id == session.id {
            progress?.answers = answers
            progress?.index = index
            progress?.submitted = true
            progress?.selectedIndex = selected
        } else { progress = nil }
        store.record(answer, question: question, pending: progress)
        if session.timed { advance() } else { submitted = true }
    }

    private func advance() {
        if session.mode == .search {
            finish()
            if !showGrowthCelebration { closeSession() }
            return
        }
        if index + 1 == session.questions.count { finish(); return }
        index += 1
        selected = nil
        confidence = nil
        submitted = false
        revealed = false
        visibleSteps = 0
        startedAt = .now
        if var progress = store.data.pending, progress.id == session.id {
            progress.index = index
            progress.submitted = false
            progress.selectedIndex = nil
            store.setPending(progress)
        }
    }

    private func finish() {
        guard !finished else { return }
        if store.data.pending?.id == session.id { store.clearPending() }
        if session.timed {
            store.finishMock(SessionPlanner.mockResult(answers, questions: session.questions, qualification: qualification))
        }
        store.updateMascotGrowth(questions: growthQuestions)
        showGrowthCelebration = growth.stage.rawValue > initialGrowthStage.rawValue
        finished = true
    }

    private func closeSession() {
        onFinish(answers.count)
        dismiss()
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryHeading
                Surface {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(answers.filter(\.correct).count)")
                            .font(.system(.largeTitle, design: .rounded).bold()).monospacedDigit()
                        Text("/ \(session.questions.count)問 正解").font(.headline).foregroundStyle(Palette.muted)
                    }
                    ProgressView(value: Double(answers.filter(\.correct).count), total: Double(max(1, session.questions.count)))
                        .tint(Palette.positive)
                    if answers.count < session.questions.count {
                        Text("未回答 \(session.questions.count - answers.count)問").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                if !session.timed { nextReviewSummary }
                if session.timed {
                    let result = SessionPlanner.mockResult(answers, questions: session.questions, qualification: qualification)
                    Surface {
                        Text(result.passed ? "設定した基準に到達" : "見直すところが見つかりました")
                            .font(.headline)
                        Text("全体 \(qualification.passingPercent)% · 各科目 \(qualification.minimumSubjectPercent)%")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        Text("架空試験の設定基準").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                if session.mode == .diagnostic,
                   let strengths = SessionPlanner.diagnosticComparison(answers, questions: session.questions, subjects: qualification.subjects) {
                    Surface {
                        Label("得意 · \(strengths.best)", systemImage: "checkmark.circle").font(.headline)
                        Label("伸びしろ · \(strengths.weakest)", systemImage: "pencil.line").font(.headline)
                    }
                }
                if session.timed {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("問題ごとの振り返り").font(.headline)
                        ForEach(session.questions) { item in
                            DisclosureGroup {
                                Text("正答: \(item.choices[item.correctIndex])").font(.subheadline.bold())
                                Text(item.explanation).font(.subheadline)
                                Text(item.source).font(.caption).foregroundStyle(.secondary)
                            } label: {
                                let answer = answers.first { $0.questionID == item.id }
                                Label(item.stem, systemImage: answer == nil ? "minus.circle" : (answer?.correct == true ? "checkmark.circle" : "xmark.circle"))
                                    .font(.subheadline).lineLimit(2)
                            }
                        }
                    }
                    .padding(18)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("分野別の結果").font(.headline)
                    ForEach(qualification.subjects, id: \.self) { subject in
                        let items = session.questions.filter { $0.subject == subject }
                        if !items.isEmpty {
                            let correct = answers.filter { answer in items.contains { $0.id == answer.questionID } && answer.correct }.count
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(subject).font(.subheadline)
                                    Spacer()
                                    Text("\(correct) / \(items.count)")
                                        .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
                                }
                                ProgressView(value: Double(correct), total: Double(items.count)).tint(Palette.positive)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(18)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
                if !purchase.unlocked && !purchase.purchasing {
                    AdBannerPlacement(ads: ads, placement: .sessionResult)
                }
                Button(action: closeSession) {
                    Text(session.mode == .diagnostic ? "ホームへ進む" : "学習を終える")
                        .frame(maxWidth: .infinity).padding(6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent(qualification.accentHex)).foregroundStyle(Palette.onAccent(qualification.accentHex))
            }
            .padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
    }

    private var completionState: TankeiState {
        return TankeiState.completion(mode: session.mode, answered: answers.count,
                               correct: answers.filter(\.correct).count, total: session.questions.count,
                               mockPassed: session.timed ? SessionPlanner.mockResult(answers, questions: session.questions,
                                                                                    qualification: qualification).passed : nil)
    }

    private var summaryHeading: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        return layout {
            Text(session.mode == .diagnostic ? "診断が完了しました" : "おつかれさま")
                .font(.title.bold()).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            TankeiView(state: completionState, stage: growth.stage,
                       size: dynamicTypeSize.isAccessibilitySize ? 96 : 120, animated: true, idle: true, expressive: true)
        }
    }

    private var nextReviewSummary: some View {
        let answeredIDs = Set(answers.map(\.questionID))
        let outlook = ReviewOutlook(questions: session.questions.filter { answeredIDs.contains($0.id) }, data: store.data)
        return Surface {
            Label("次に出会う目安", systemImage: "calendar").font(.headline)
            if let next = outlook.nextDate {
                Text("\(ReviewOutlook.label(for: next)) · \(outlook.nextCount)問")
                    .font(.title3.bold()).foregroundStyle(Palette.positive)
            }
            if outlook.dueCount > 0 {
                Text("今、復習にいい頃 · \(outlook.dueCount)問").font(.subheadline).foregroundStyle(Palette.review)
            }
        }
    }

    private var growth: TankeiGrowth { TankeiGrowth(questions: growthQuestions, data: store.data, earnedOnly: true) }

}
