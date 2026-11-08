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
    let onFinish: (_ answered: Int, _ correct: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var choiceMarkerSize: CGFloat = 28
    @AccessibilityFocusState private var feedbackFocused: Bool
    @State private var index = 0
    @State private var selected: Int?
    @State private var revealed = false
    @State private var submitted = false
    @State private var finished = false
    @State private var showGrowthCelebration = false
    @State private var startedAt = Date()
    @State private var answers: [Answer] = []
    @State private var confirmExit = false
    @State private var largeText = false
    @State private var choicesJump = 0
    @State private var deadline: Date
    @State private var remaining: TimeInterval
    @State private var featherBurst = 0
    @State private var wrongShake = 0
    @State private var initialStreak: Int
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: StudySession, qualification: Qualification, store: StudyStore, purchase: PurchaseManager, ads: AdsService,
         growthQuestions: [Question],
         onFinish: @escaping (_ answered: Int, _ correct: Int) -> Void) {
        self.session = session
        self.qualification = qualification
        self.store = store
        self.purchase = purchase
        self.ads = ads
        self.growthQuestions = growthQuestions
        _initialGrowthStage = State(initialValue: TankeiGrowth(questions: growthQuestions, data: store.data, earnedOnly: true).stage)
        _initialStreak = State(initialValue: StudyMomentum(answers: store.data.answers).streak)
        self.onFinish = onFinish
        let seconds = TimeInterval(qualification.examMinutes * 60)
        _deadline = State(initialValue: .now.addingTimeInterval(seconds))
        _remaining = State(initialValue: seconds)
    }

    private var question: Question { session.questions[index] }
    private var recallMode: Bool {
        store.data.recallFirst && [.recommended, .misconception, .contrast, .incorrect, .bookmarked].contains(session.mode)
    }

    private var returnsToList: Bool { session.returnsToQuestionList || session.mode == .search }

    var body: some View {
        NavigationStack {
            Group {
                if showGrowthCelebration {
                    TankeiGrowthCelebration(initialStage: initialGrowthStage, stage: growth.stage, accentHex: qualification.accentHex,
                                            buttonTitle: returnsToList ? "一覧へ戻る" : "結果を見る") {
                        if returnsToList { closeSession() }
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
                            Button { largeText.toggle() } label: { Image(systemName: "textformat.size") }
                                .accessibilityLabel(largeText ? "文字を標準サイズにする" : "文字を大きくする")
                                .accessibilityIdentifier("questionTextSize")
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(!finished)
        .confirmationDialog("問題の途中ですが、中断しますか？", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("問題一覧へ戻る", role: .destructive) {
                store.clearInterruptedStudy()
                dismiss()
            }
            Button("学習を続ける", role: .cancel) { }
        } message: {
            Text("途中の出題位置は削除します。回答済みの学習記録は残ります。")
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
            SessionProgressBar(total: session.questions.count, results: session.timed ? nil : answers.map(\.correct),
                               answered: answers.count)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Palette.background)
                .zIndex(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("進捗")
                .accessibilityValue("\(session.questions.count)問中\(index + 1)問目")
            ScrollViewReader { proxy in
              ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    questionHeader.id("questionTop")
                    QuestionBodyView(question: question, largeText: largeText)
                        .fontDesign(.default)
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
                                if let blocks = question.choiceBlocks { RichContentView(blocks: blocks[choice], wrapsTables: question.subject == "科目B") }
                            }
                        }
                        .id("answerChoices")
                        if showsFeedback {
                            QuestionExplanationView(question: question, qualification: qualification, listsChoiceReasons: false)
                                .id("explanation")
                                .transition(.opacity)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
              }
              .accessibilityIdentifier("studyQuestionScroll")
              .onChange(of: index) { _, _ in proxy.scrollTo("questionTop", anchor: .top) }
              .onChange(of: choicesJump) { _, _ in proxy.scrollTo("answerChoices", anchor: .top) }
              .onChange(of: submitted) { _, value in
                  guard value, !session.timed else { return }
                  feedbackFocused = true
                  // Wait for the panel's inset, otherwise the scroll is dropped while the layout changes.
                  Task { @MainActor in
                      try? await Task.sleep(for: .milliseconds(120))
                      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                          proxy.scrollTo("answerChoices", anchor: .top)
                      }
                  }
              }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if question.subject == "科目B" {
                LongQuestionQuickActions(question: question, largeText: largeText) {
                    revealed = true
                    choicesJump += 1
                }.id(question.id)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .overlay {
            if !reduceMotion && !session.timed { FeatherBurst(trigger: featherBurst).allowsHitTesting(false) }
        }
        // Untimed answers are graded on the tap, so only timed sessions get a separate selection tick.
        .sensoryFeedback(trigger: selected) { _, value in
            session.timed && value != nil ? .selection : nil
        }
        .sensoryFeedback(trigger: submitted) { _, isSubmitted in
            // Timed sessions never reveal correctness before grading.
            guard isSubmitted, !session.timed else { return nil }
            return selected == question.correctIndex ? .success : .warning
        }
    }

    /// Untimed answers show the result and explanation right after the tap.
    private var showsFeedback: Bool { submitted && !session.timed }

    @ViewBuilder private var bottomBar: some View {
        if recallMode && !revealed {
            Button("選択肢を見る") { revealed = true }
                .buttonStyle(PuffyButtonStyle(minHeight: 50))
                .frame(maxWidth: 640)
                .padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity).background(.bar)
        } else if showsFeedback {
            answerPanel
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        } else if session.timed {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) :
                AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            layout {
                Text("\(index + 1) / \(session.questions.count)")
                    .font(dynamicTypeSize.isAccessibilitySize ? .caption : .subheadline.weight(.semibold)).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: submit) {
                    Text(index + 1 == session.questions.count ? "回答して採点する" : "回答を確定").font(.headline)
                }
                .buttonStyle(PuffyButtonStyle(minHeight: 50))
                .disabled(selected == nil)
                .accessibilityIdentifier("submitOrAdvance")
            }
            .padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: 672).frame(maxWidth: .infinity)
            .background(.bar)
            .accessibilityElement(children: .contain).accessibilityIdentifier("studyControls")
        }
    }

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("\(index + 1) / \(session.questions.count)問").font(.subheadline.bold().monospacedDigit())
                if !session.timed && combo >= 2 {
                    Text("\(combo)れんぞく！").font(.caption.weight(.heavy)).foregroundStyle(Palette.onPiyo)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Palette.beak, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityIdentifier("comboChip")
                }
                Spacer(minLength: 8)
                if !session.timed { bookmarkButton }
            }
            Text(questionMeta).font(.caption).foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("questionMeta")
            if let history {
                HStack(spacing: 6) {
                    Text(history.lastCorrect ? "前回○" : "前回×").font(.caption.weight(.heavy))
                        .foregroundStyle(history.lastCorrect ? Palette.correctText : Palette.oopsText)
                    Text("\(history.count)回解答・\(history.misses)回ミス").font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("前回\(history.lastCorrect ? "正解" : "不正解")、\(history.count)回解答、\(history.misses)回ミス")
                .accessibilityIdentifier("questionHistory")
            }
        }
    }

    private var bookmarkButton: some View {
        let marked = store.data.bookmarks.contains(question.id)
        return Button { store.toggleBookmark(question.id) } label: {
            Image(systemName: marked ? "bookmark.fill" : "bookmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(marked ? Palette.piyoDeep : Palette.muted)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(StudyButtonStyle())
        .padding(.vertical, -10)
        .accessibilityLabel(marked ? "ブックマークを解除" : "ブックマークに追加")
    }

    /// Kind and source on one line.
    private var questionMeta: String {
        [question.kindTitle, qualification.displaySource(question.source)].compactMap { $0 }.joined(separator: " · ")
    }

    /// Earlier attempts at this question, not counting the one being made now.
    private var history: (count: Int, misses: Int, lastCorrect: Bool)? {
        let past = store.data.answers.filter { $0.questionID == question.id && $0.date < startedAt }
        guard let last = past.max(by: { $0.date < $1.date }) else { return nil }
        return (past.count, past.filter { !$0.correct }.count, last.correct)
    }

    /// Trailing run of correct answers in this session.
    private var combo: Int { answers.reversed().prefix { $0.correct }.count }

    private func choiceButton(_ choice: Int) -> some View {
        let graded = showsFeedback
        let isCorrect = graded && choice == question.correctIndex
        let isWrong = graded && choice == selected && choice != question.correctIndex
        let picked = graded && choice == selected
        let isSelected = !graded && selected == choice
        let reason = graded ? question.choiceExplanations.flatMap { $0.indices.contains(choice) ? $0[choice] : nil } : nil
        let edge = isCorrect ? Palette.correct : isWrong ? Palette.oops : isSelected ? Palette.sky : Palette.border
        let reasonLabel = reason.map { "、理由：\(InlineMarkup.plainText($0))" } ?? ""
        return Button { choose(choice) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Text(qualification.choiceLabel(choice))
                        .font(.subheadline.bold())
                        .frame(width: choiceMarkerSize, height: choiceMarkerSize)
                        .foregroundStyle(isCorrect || isWrong || isSelected ? Palette.surface : Palette.ink)
                        .background(isCorrect || isWrong || isSelected ? edge : Palette.piyoTint,
                                    in: RoundedRectangle(cornerRadius: 9))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.choices[choice]).font(largeText ? .title3 : .body)
                            .fixedSize(horizontal: false, vertical: true)
                        if picked { Text("あなたの回答").font(.caption.bold()) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if graded {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : isWrong ? "xmark.circle.fill" : "xmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(isCorrect ? Palette.correct : isWrong ? Palette.oops : Palette.muted)
                            .accessibilityHidden(true)
                    }
                }
                if let reason {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(isCorrect ? "○" : "×").font(.subheadline.weight(.heavy))
                            .foregroundStyle(isCorrect ? Palette.correctText : isWrong ? Palette.oopsText : Palette.muted)
                            .accessibilityHidden(true)
                        MarkupText(text: reason, role: .reason, setsFont: true)
                            .foregroundStyle(Palette.ink)
                    }
                    .padding(.top, 10)
                    .overlay(alignment: .top) { Rectangle().fill(edge.opacity(0.4)).frame(height: 1) }
                    .padding(.leading, choiceMarkerSize + 12)
                }
            }
            .padding(15)
            .foregroundStyle(isCorrect ? Palette.correctText : isWrong ? Palette.oopsText : Palette.ink)
            .background(isCorrect ? Palette.correctTint : isWrong ? Palette.oopsTint :
                        isSelected ? Palette.skyTint : Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(edge, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 16).fill(edge.opacity(0.45)).offset(y: 4))
            .padding(.bottom, 4)
            .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.5), value: isSelected)
            .keyframeAnimator(initialValue: 0.0, trigger: wrongShake) { content, offset in
                content.offset(x: isWrong ? offset : 0)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-7, duration: 0.08)
                    LinearKeyframe(6, duration: 0.08)
                    LinearKeyframe(-3, duration: 0.08)
                    LinearKeyframe(0, duration: 0.08)
                }
            }
        }
        .buttonStyle(StudyButtonStyle())
        .disabled(submitted)
        .accessibilityLabel("選択肢 \(choice + 1)、\(question.choices[choice])\(isCorrect ? "、正答" : "")\(picked ? "、あなたの回答" : "")\(reasonLabel)")
        .accessibilityAddTraits(selected == choice ? .isSelected : [])
    }

    /// Untimed sessions grade on the tap; timed ones keep the choice until the answer is confirmed.
    private func choose(_ choice: Int) {
        guard !submitted else { return }
        selected = choice
        if !session.timed { submit() }
    }

    /// Slides up from the bottom after grading: the mascot's reaction, one short line and the next button.
    private var answerPanel: some View {
        let correct = selected == question.correctIndex
        let label = qualification.choiceLabel(question.correctIndex)
        let lines = correct ? Self.correctLines : Self.wrongLines
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                TankeiView(state: correct ? .celebrate : .recover, stage: initialGrowthStage,
                           size: dynamicTypeSize.isAccessibilitySize ? 56 : 76,
                           animated: true, idle: true, expressive: true, eventID: index)
                VStack(alignment: .leading, spacing: 2) {
                    Text(correct ? "正解！" : "正解は「\(label)」")
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(correct ? "正解" : "不正解。正解は \(label)")
                        .accessibilityFocused($feedbackFocused)
                        .accessibilityIdentifier("answerOutcome")
                        #if DEBUG
                        .accessibilityValue("相棒：\(initialGrowthStage.title)")
                        #endif
                    Text(lines[index % lines.count])
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(correct ? Palette.correctText : Palette.oopsText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(action: advance) {
                Text(index + 1 == session.questions.count ? (returnsToList ? "問題一覧へ戻る" : "結果を見る") : "次へ")
                    .font(.headline)
            }
            .buttonStyle(PuffyButtonStyle(kind: correct ? .correct : .oops, minHeight: 50))
            .accessibilityIdentifier("submitOrAdvance")
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
        .frame(maxWidth: 672)
        .frame(maxWidth: .infinity)
        .background(correct ? Palette.correctTint : Palette.oopsTint, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) { Rectangle().fill(correct ? Palette.correct : Palette.oops).frame(height: 3) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("studyControls")
    }

    private static let correctLines = ["その調子！", "さすが！", "バッチリ覚えてる！", "いい流れ！"]
    private static let wrongLines = ["理由を見れば次は取れる！", "ここで覚えればOK！", "おしい！ 見直そう"]

    private func submit() {
        guard let selected, !submitted else { return }
        let answer = Answer(questionID: question.id, date: .now, selectedIndex: selected,
                            correct: selected == question.correctIndex,
                            duration: max(0, Date().timeIntervalSince(startedAt)),
                            confidence: nil, mode: session.mode)
        answers.append(answer)
        store.record(answer, question: question)
        if session.timed { advance(); return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.25)) { submitted = true }
        if answer.correct { featherBurst += 1 } else { wrongShake += 1 }
    }

    private func advance() {
        if returnsToList && index + 1 == session.questions.count {
            finish()
            if !showGrowthCelebration { closeSession() }
            return
        }
        if index + 1 == session.questions.count { finish(); return }
        index += 1
        selected = nil
        submitted = false
        revealed = false
        startedAt = .now

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
        onFinish(answers.count, answers.filter(\.correct).count)
        dismiss()
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryHeading
                if !session.timed && session.mode != .diagnostic { momentumSummary }
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
                                Text(qualification.displaySource(item.source)).font(.caption).foregroundStyle(.secondary)
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
                }
                .buttonStyle(PuffyButtonStyle())
            }
            .padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
    }

    /// はね・あしあとの獲得をその場で見せる。あしあとは今日初めての学習なら「+1」のスタンプ。
    private var momentumSummary: some View {
        let momentum = StudyMomentum(answers: store.data.answers)
        let earned = answers.reduce(0) { $0 + ($1.correct ? StudyMomentum.feathersPerCorrect : StudyMomentum.feathersPerAttempt) }
        let grew = momentum.streak > initialStreak
        return HStack(spacing: 10) {
            momentumTile("はね", value: "+\(earned)", tint: Palette.beakText)
                .accessibilityIdentifier("resultFeathers")
            momentumTile("あしあと", value: "\(momentum.streak)日", tint: Palette.ink)
                .overlay(alignment: .topTrailing) {
                    if grew {
                        Text("+1").font(.caption.weight(.heavy)).foregroundStyle(Palette.onPiyo)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Palette.beak, in: Capsule())
                            .offset(x: 6, y: -10)
                            .transition(.scale(scale: 2.2).combined(with: .opacity))
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityValue(grew ? "今日で1日のびました" : "")
                .accessibilityIdentifier("resultStreak")
        }
    }

    private func momentumTile(_ title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
            Text(value).font(.title2.weight(.heavy).monospacedDigit()).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .popCard(radius: 20)
        .accessibilityElement(children: .combine)
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
