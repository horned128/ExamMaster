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
    @State private var confidence: Confidence?
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
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                store.toggleBookmark(question.id)
                            } label: {
                                Image(systemName: store.data.bookmarks.contains(question.id) ? "bookmark.fill" : "bookmark")
                            }
                            .accessibilityLabel(store.data.bookmarks.contains(question.id) ? "ブックマークを解除" : "ブックマークに追加")
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(index + 1) / \(session.questions.count)問").font(.subheadline.bold().monospacedDigit())
                            Spacer(minLength: 8)
                            if !session.timed && combo >= 2 {
                                Text("\(combo)れんぞく！").font(.caption.weight(.heavy)).foregroundStyle(Palette.onPiyo)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Palette.beak, in: Capsule())
                                    .transition(.scale.combined(with: .opacity))
                                    .accessibilityIdentifier("comboChip")
                            }
                        }
                        Text(questionMeta).font(.caption).foregroundStyle(Palette.muted)
                    }
                    .id("questionTop")
                    if let kind = question.kindTitle { Text(kind).font(.caption).foregroundStyle(Palette.muted) }
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
                        if !submitted && !session.timed { confidencePicker }
                        if submitted && !session.timed { feedback.id("feedback") }
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
                  if value {
                      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                          proxy.scrollTo("feedback", anchor: .top)
                      }
                      feedbackFocused = true
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if recallMode && !revealed {
                Button("選択肢を見る") { revealed = true }
                    .buttonStyle(PuffyButtonStyle(minHeight: 50))
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity).background(.bar)
            } else {
                let unavailable = selected == nil && !submitted
                let action = Button {
                    if submitted { advance() } else { submit() }
                } label: {
                    Text(submitted ? (index + 1 == session.questions.count ? (returnsToList ? "問題一覧へ戻る" : "結果を見る") : "次の問題へ") :
                         (session.timed && index + 1 == session.questions.count ? "回答して採点する" : "回答を確定"))
                         .font(.headline)
                }
                let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) :
                    AnyLayout(HStackLayout(alignment: .center, spacing: 16))
                layout {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(index + 1) / \(session.questions.count)")
                            .font(dynamicTypeSize.isAccessibilitySize ? .caption : .subheadline.weight(.semibold)).monospacedDigit()
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text(submitted ? "解説を確認" : "回答を選択").font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    action.buttonStyle(PuffyButtonStyle(minHeight: 50))
                        .disabled(unavailable)
                        .accessibilityIdentifier("submitOrAdvance")
                }
                .padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: 672).frame(maxWidth: .infinity)
                .background(.bar)
                .accessibilityElement(children: .contain).accessibilityIdentifier("studyControls")
            }
        }
        .overlay {
            if !reduceMotion && !session.timed { FeatherBurst(trigger: featherBurst).allowsHitTesting(false) }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(trigger: submitted) { _, isSubmitted in
            // Timed sessions never reveal correctness before grading.
            guard isSubmitted, !session.timed else { return nil }
            return selected == question.correctIndex ? .success : .warning
        }
    }

    private var questionMeta: String {
        let number = question.questionNumber.map { " · 問\($0)" } ?? ""
        return "\(question.year.formatted(.number.grouping(.never))) · \(question.subject)\(number)"
    }

    /// Trailing run of correct answers in this session.
    private var combo: Int { answers.reversed().prefix { $0.correct }.count }

    private func choiceButton(_ choice: Int) -> some View {
        let isCorrect = submitted && choice == question.correctIndex
        let isWrong = submitted && choice == selected && choice != question.correctIndex
        let isSelected = !submitted && selected == choice
        let edge = isCorrect ? Palette.correct : isWrong ? Palette.oops : isSelected ? Palette.sky : Palette.border
        return Button {
            if !submitted { selected = choice }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(qualification.choiceLabel(choice))
                    .font(.subheadline.bold())
                    .frame(width: choiceMarkerSize, height: choiceMarkerSize)
                    .foregroundStyle(isCorrect || isWrong || isSelected ? Palette.surface : Palette.ink)
                    .background(isCorrect || isWrong || isSelected ? edge : Palette.piyoTint,
                                in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(question.choices[choice]).font(largeText ? .title3 : .body)
                        .fixedSize(horizontal: false, vertical: true)
                    if isCorrect { Text("正解").font(.caption.bold()) }
                    if isWrong { Text("あなたの回答").font(.caption.bold()) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if isCorrect { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.correct).accessibilityHidden(true) }
                if isWrong { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.oops).accessibilityHidden(true) }
            }
            .padding(15)
            .foregroundStyle(isCorrect ? Palette.correctText : isWrong ? Palette.oopsText : Palette.ink)
            .background(isCorrect ? Palette.correctTint : isWrong ? Palette.oopsTint :
                        isSelected ? Palette.skyTint : Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(edge, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 16).fill(edge.opacity(0.45)).offset(y: 4))
            .padding(.bottom, 4)
            .opacity(submitted && !isCorrect && !isWrong ? 0.6 : 1)
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
        .accessibilityLabel("選択肢 \(choice + 1)、\(question.choices[choice])\(isCorrect ? "、正答" : isWrong ? "、あなたの回答" : "")")
        .accessibilityAddTraits(selected == choice ? .isSelected : [])
    }

    private var confidencePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(submitted ? "解いた後の手応え · 変更できます" : "手応え · 任意").font(.caption).foregroundStyle(Palette.muted)
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                        Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(Confidence.allCases) { item in
                    let active = confidence == item
                    Button {
                        let next: Confidence? = active ? nil : item
                        if submitted, var answer = answers.last {
                            guard store.updateConfidence(next, answerID: answer.id, question: question) else { return }
                            answer.confidence = next
                            answers[answers.count - 1] = answer
                        }
                        confidence = next
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                            Text(item.title).font(.subheadline.weight(active ? .bold : .medium))
                        }
                        .frame(maxWidth: .infinity, minHeight: 54).padding(6)
                        .foregroundStyle(active ? Palette.onAccent(qualification.accentHex) : Palette.ink)
                        .background(active ? Palette.accent(qualification.accentHex) : Palette.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Palette.accent(qualification.accentHex) : Palette.track, lineWidth: 2))
                    }
                    .buttonStyle(StudyButtonStyle()).accessibilityLabel(item.title)
                    .accessibilityIdentifier("confidence-\(item.rawValue)")
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
        }
    }

    private var feedback: some View {
        let correct = selected == question.correctIndex
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return VStack(alignment: .leading, spacing: 14) {
            layout {
                HStack(spacing: 10) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 32, weight: .semibold)).accessibilityHidden(true)
                    Text(correct ? "正解です" : "答えを確認")
                        .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                        .accessibilityFocused($feedbackFocused)
                        .accessibilityIdentifier("answerOutcome")
                        #if DEBUG
                        .accessibilityValue("相棒：\(initialGrowthStage.title)")
                        #endif
                }
                .foregroundStyle(correct ? Palette.correctText : Palette.oopsText)
                .frame(maxWidth: .infinity, alignment: .leading)
                TankeiView(state: correct ? .celebrate : .recover,
                           stage: initialGrowthStage, size: 72, animated: true, idle: true, expressive: true, eventID: index)
            }
            confidencePicker
            if question.choiceExplanations != nil {
                QuestionExplanationView(question: question, qualification: qualification)
            }
            if let steps = question.steps {
                Text("解き方").font(.headline)
                ForEach(steps.indices, id: \.self) { step in
                    Text("\(step + 1). \(steps[step])").font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            }
            if question.choiceExplanations == nil {
                MarkupText(text: question.explanation)
                if let related = question.related {
                    DisclosureGroup("関連知識") { RichContentView(blocks: related).padding(.top, 8) }
                        .accessibilityIdentifier("relatedKnowledge")
                }
                if let references = question.references { QuestionReferencesView(references: references) }
                DisclosureGroup("出典") {
                    Text(qualification.displaySource(question.source)).font(.caption).foregroundStyle(Palette.muted)
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
        .background(correct ? Palette.correctTint : Palette.oopsTint, in: RoundedRectangle(cornerRadius: 24))
    }

    private func submit() {
        guard let selected else { return }
        let answer = Answer(questionID: question.id, date: .now, selectedIndex: selected,
                            correct: selected == question.correctIndex,
                            duration: max(0, Date().timeIntervalSince(startedAt)),
                            confidence: session.timed ? nil : confidence, mode: session.mode)
        answers.append(answer)
        store.record(answer, question: question)
        if session.timed { advance(); return }
        submitted = true
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
        confidence = nil
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
