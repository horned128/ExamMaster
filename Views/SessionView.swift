import SwiftUI
import Combine

struct SessionView: View {
    let session: StudySession
    let qualification: Qualification
    let store: StudyStore
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var selected: Int?
    @State private var confidence: Confidence?
    @State private var revealed = false
    @State private var submitted = false
    @State private var finished = false
    @State private var startedAt = Date()
    @State private var answers: [Answer] = []
    @State private var visibleSteps = 0
    @State private var confirmExit = false
    @State private var deadline: Date
    @State private var remaining: TimeInterval
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(session: StudySession, qualification: Qualification, store: StudyStore, onFinish: @escaping () -> Void) {
        self.session = session
        self.qualification = qualification
        self.store = store
        self.onFinish = onFinish
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
                if finished { summary }
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
        .confirmationDialog("学習を中断しますか？回答済みの履歴は保存されます。", isPresented: $confirmExit) {
            Button("中断する", role: .destructive) { dismiss() }
            Button("続ける", role: .cancel) { }
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
            ProgressView(value: Double(index), total: Double(max(1, session.questions.count)))
                .accessibilityLabel("進捗")
                .accessibilityValue("\(session.questions.count)問中\(index + 1)問目")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("\(index + 1) / \(session.questions.count)").font(.subheadline.bold())
                        Spacer()
                        Text("\(question.year) · \(question.subject) / \(question.category)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(question.stem).font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let image = question.imageName {
                        Image(image).resizable().scaledToFit()
                            .accessibilityLabel("問題図版")
                    }
                    if recallMode && !revealed {
                        Surface {
                            Label("まず、自分の答えを思い出す", systemImage: "brain.head.profile")
                                .font(.headline)
                            Text("選択肢を見る前に、何が答えになるか一度考えてみましょう。")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("選択肢を見る") { revealed = true }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(question.choices.indices, id: \.self) { choice in
                                choiceButton(choice)
                            }
                        }
                        if !submitted && !session.timed {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("自信度（任意）").font(.caption).foregroundStyle(.secondary)
                                HStack {
                                    ForEach(Confidence.allCases) { item in
                                        Button(item.title) { confidence = confidence == item ? nil : item }
                                            .buttonStyle(.bordered)
                                            .tint(confidence == item ? Palette.accent(qualification.accentHex) : .gray)
                                            .accessibilityAddTraits(confidence == item ? .isSelected : [])
                                    }
                                }
                            }
                        }
                        if submitted && !session.timed { feedback }
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            if !recallMode || revealed {
                Button {
                    if submitted { advance() } else { submit() }
                } label: {
                    Text(submitted ? (index + 1 == session.questions.count ? "結果を見る" : "次の問題へ") :
                         (session.timed && index + 1 == session.questions.count ? "回答して採点する" : "回答を確定"))
                        .frame(maxWidth: .infinity).padding(6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected == nil && !submitted)
                .padding(18)
                .background(.bar)
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
                    .frame(width: 28, height: 28)
                    .background(.tint.opacity(0.12), in: Circle())
                Text(question.choices[choice]).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if isCorrect { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if isWrong { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
            }
            .padding(15)
            .foregroundStyle(.primary)
            .background(selected == choice ? Color.accentColor.opacity(0.13) : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(selected == choice ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("選択肢 \(choice + 1)、\(question.choices[choice])")
        .accessibilityAddTraits(selected == choice ? .isSelected : [])
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(selected == question.correctIndex ? "正解です" : "もう一度確認しましょう",
                  systemImage: selected == question.correctIndex ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.headline).foregroundStyle(selected == question.correctIndex ? .green : .orange)
            if let steps = question.steps {
                Text("ステップで考える").font(.headline)
                ForEach(0..<visibleSteps, id: \.self) { step in
                    Text("\(step + 1). \(steps[step])").font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if visibleSteps < steps.count {
                    Button("次に何をするか考えて、ステップを表示") {
                        visibleSteps += 1
                    }
                    .buttonStyle(.bordered)
                }
            }
            if question.steps == nil || visibleSteps == question.steps?.count {
                Text(question.explanation).font(.body)
                Text(question.source).font(.caption).foregroundStyle(.secondary)
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
        store.record(answer, question: question)
        if session.timed { advance() } else { submitted = true }
    }

    private func advance() {
        if index + 1 == session.questions.count { finish(); return }
        index += 1
        selected = nil
        confidence = nil
        submitted = false
        revealed = false
        visibleSteps = 0
        startedAt = .now
    }

    private func finish() {
        guard !finished else { return }
        if session.timed {
            store.finishMock(SessionPlanner.mockResult(answers, questions: session.questions, qualification: qualification))
        }
        finished = true
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: session.timed ? "chart.bar.fill" : "checkmark.seal.fill")
                    .font(.system(size: 48)).foregroundStyle(.tint)
                Text(session.mode == .diagnostic ? "診断が完了しました" : "学習を終えました")
                    .font(.largeTitle.bold())
                Text("\(answers.filter(\.correct).count) / \(session.questions.count)問 正解")
                    .font(.title2.bold())
                if session.timed {
                    let result = SessionPlanner.mockResult(answers, questions: session.questions, qualification: qualification)
                    Surface {
                        Text(result.passed ? "設定した基準に到達" : "弱い分野を見直しましょう")
                            .font(.headline)
                        Text("全体 \(qualification.passingPercent)%以上・各科目 \(qualification.minimumSubjectPercent)%以上がこの架空試験の設定基準です。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if session.mode == .diagnostic {
                    let strengths = sessionSummary
                    Surface {
                        Text("得意分野：\(strengths.best)").font(.headline)
                        Text("まず取り組む分野：\(strengths.weakest)").font(.headline)
                        Text("診断は出発点です。復習を重ねるほど提案が調整されます。")
                            .font(.subheadline).foregroundStyle(.secondary)
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
                            HStack {
                                Text(subject)
                                Spacer()
                                Text("\(answers.filter { answer in items.contains { $0.id == answer.questionID } && answer.correct }.count) / \(items.count)")
                                    .monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(18)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
                Button {
                    onFinish()
                    dismiss()
                } label: {
                    Text("ホームに戻る").frame(maxWidth: .infinity).padding(6)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(22)
        }
    }

    private var sessionSummary: (best: String, weakest: String) {
        let scored = qualification.subjects.map { subject -> (String, Double) in
            let items = session.questions.filter { $0.subject == subject }
            let correct = answers.filter { answer in answer.correct && items.contains { $0.id == answer.questionID } }.count
            return (subject, Double(correct) / Double(max(1, items.count)))
        }
        return (scored.max { $0.1 < $1.1 }?.0 ?? "未判定", scored.min { $0.1 < $1.1 }?.0 ?? "未判定")
    }
}
