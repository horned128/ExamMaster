import SwiftUI

struct DashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showExamDateEditor = false
    @State private var showLearningGuide = false
    @AppStorage("shortDailyStudy") private var shortSession = true
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let paywall: () -> Void
    let resume: () -> Void
    let openAnalysis: () -> Void
    let settings: () -> Void

    private var stats: StudyStats { StudyStats(catalog: catalog, data: store.data) }
    private var accent: Color { Palette.accent(catalog.qualification.accentHex) }

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let available = SessionPlanner.available(catalog, unlocked: purchase.unlocked)
                let outlook = ReviewOutlook(questions: available, data: store.data, now: timeline.date)
                let recommended = SessionPlanner.recommended(catalog, data: store.data, unlocked: purchase.unlocked, now: timeline.date)
                let selectedQuestions = Array(recommended.questions.prefix(shortSession ? 5 : 12))
                VStack(alignment: .leading, spacing: 24) {
                    header(asOf: timeline.date)
                    if let pending = store.data.pending {
                        Button(action: resume) {
                            Surface {
                                HStack(spacing: 12) {
                                    Image(systemName: "play.circle").font(.title2).foregroundStyle(accent)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("続きから").font(.headline).foregroundStyle(Palette.ink)
                                        Text("\(pending.answers.count) / \(pending.questionIDs.count)問 · \(pending.title)")
                                            .font(.caption).foregroundStyle(Palette.muted)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .buttonStyle(StudyButtonStyle())
                        .accessibilityIdentifier("resumeStudy")
                    }
                    studyCard(recommended: recommended, questions: selectedQuestions)
                    reviewCard(outlook: outlook, available: available)
                    memoryCard
                    if let mock = store.data.mocks.last {
                        Surface {
                            HStack {
                                Text("前回の模試").font(.headline)
                                Spacer()
                                Text("\(mock.score) / \(mock.total)問").font(.headline.monospacedDigit())
                            }
                            StudyBadge(title: mock.passed ? "基準到達" : "見直すところが見つかりました",
                                       symbol: mock.passed ? "checkmark.circle" : "pencil", color: Palette.positive)
                        }
                    }
                    if !purchase.unlocked {
                        Button(action: paywall) {
                            Label("全\(catalog.questions.count)問で学ぶ", systemImage: "lock.open")
                                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(StudyButtonStyle())
                    }
                    if !purchase.unlocked && !purchase.purchasing { AdBannerPlacement(ads: ads) }
                    if let error = store.error {
                        Surface {
                            Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                            Button("保存を再試行") { store.retrySave() }
                                .frame(minHeight: 44)
                        }
                    }
                }
                .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
        }
        .background(Palette.background)
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: settings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("設定")
            }
        }
        .sheet(isPresented: $showLearningGuide) { LearningGuideView() }
        .sheet(isPresented: $showExamDateEditor) {
            NavigationStack {
                ExamDateEditor(store: store)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showExamDateEditor = false } }
                    }
            }
            .tint(Palette.linkAccent(catalog.qualification.accentHex))
        }
    }

    private func header(asOf now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(catalog.qualification.name).font(.subheadline.weight(.medium)).foregroundStyle(Palette.muted)
            Text("自分のペースで、\nひとつずつ。")
                .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("homeHeading")
            Button { showExamDateEditor = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").accessibilityHidden(true)
                    if let remaining = store.data.examDay?.daysRemaining(from: now) {
                        Text(remaining > 0 ? "あと\(remaining)日" : remaining == 0 ? "試験当日" : "試験日が経過")
                            .monospacedDigit()
                    } else {
                        Text("試験日を設定")
                    }
                    Image(systemName: "chevron.right").font(.caption2).accessibilityHidden(true)
                }
                .font(.subheadline).foregroundStyle(Palette.muted).frame(minHeight: 44)
            }
            .buttonStyle(StudyButtonStyle())
            .accessibilityLabel(store.data.examDay == nil ? "試験日を設定" : "試験日を変更")
            .accessibilityValue(examCountdown(asOf: now))
        }
    }

    private func examCountdown(asOf now: Date) -> String {
        guard let remaining = store.data.examDay?.daysRemaining(from: now) else { return "未設定" }
        return remaining > 0 ? "あと\(remaining)日" : remaining == 0 ? "試験当日" : "試験日が経過"
    }

    private func studyCard(recommended: StudySession, questions: [Question]) -> some View {
        let newCount = questions.filter { store.data.mastery[$0.id] == nil }.count
        return Surface {
            HStack {
                Text("今日のひと区切り").font(.title3.bold())
                Spacer(minLength: 8)
                Image(systemName: "pencil.line").foregroundStyle(.tint).accessibilityHidden(true)
            }
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                        [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                amountOption("少なめ · \(min(5, recommended.questions.count))問", short: true)
                amountOption("いつもの · \(recommended.questions.count)問", short: false)
            }
            .accessibilityLabel("学習する量")
            .accessibilityIdentifier("studyAmount")
            studyMix(newCount: newCount, total: questions.count)
            Button {
                start(StudySession(title: recommended.title, mode: recommended.mode, questions: questions, timed: false))
            } label: {
                HStack {
                    Text(dynamicTypeSize.isAccessibilitySize ? "始める" : "この\(questions.count)問を始める")
                    Spacer()
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                }
                .font(.headline).foregroundStyle(Palette.onAccent(catalog.qualification.accentHex))
                .padding(16).frame(maxWidth: .infinity, minHeight: 52)
                .background(accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(questions.isEmpty)
            .opacity(questions.isEmpty ? 0.5 : 1)
            .buttonStyle(StudyButtonStyle())
            .accessibilityLabel("\(questions.count)問の学習を始める")
            .accessibilityIdentifier("startDailyStudy")
        }
    }

    private func amountOption(_ title: String, short: Bool) -> some View {
        let selected = shortSession == short
        return Button { shortSession = short } label: {
            HStack(spacing: 6) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                Text(title).fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? Palette.linkAccent(catalog.qualification.accentHex) : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(selected ? accent.opacity(0.09) : Palette.background, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(StudyButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(short ? "shortStudy" : "regularStudy")
    }

    private func studyMix(newCount: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if total > newCount { StudyBadge(title: "復習 \(total - newCount)問", symbol: "arrow.clockwise", color: Palette.positive) }
            if newCount > 0 { StudyBadge(title: "新しい問題 \(newCount)問", symbol: "plus") }
        }
    }

    private func reviewCard(outlook: ReviewOutlook, available: [Question]) -> some View {
        Surface {
            HStack {
                Text("復習のタイミング").font(.headline)
                Spacer()
                Button { showLearningGuide = true } label: {
                    Image(systemName: "info.circle").frame(width: 44, height: 44)
                }
                .buttonStyle(StudyButtonStyle()).foregroundStyle(Palette.muted)
                .accessibilityLabel("記憶と復習のしくみ")
            }
            if outlook.dueCount > 0 {
                NavigationLink(value: QuestionCollectionRoute.status(.due)) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise.circle").font(.title).foregroundStyle(Palette.review)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("今、復習にいい頃").font(.headline).foregroundStyle(Palette.ink)
                            Text("\(outlook.dueCount)問").font(.subheadline).foregroundStyle(Palette.review)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted).accessibilityHidden(true)
                    }
                    .frame(minHeight: 52)
                }
                .buttonStyle(StudyButtonStyle())
            } else {
                Label("今の復習はありません", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(Palette.positive)
            }
            if let next = outlook.nextDate {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text("次の目安").foregroundStyle(Palette.muted)
                    Spacer()
                    Text("\(ReviewOutlook.label(for: next)) · \(outlook.nextCount)問").fontWeight(.medium)
                }
                .font(.subheadline).accessibilityElement(children: .combine)
            } else if store.data.answers.isEmpty {
                Text("解いた問題に、次の目安がつきます。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            let reviewLinks: [(QuestionCollectionRoute, String, String, Int)] = [
                (.status(.risk), "思い出しておきたい", "clock", available.filter { q in
                    guard let state = store.data.mastery[q.id] else { return false }
                    return state.lastCorrect && !MasteryEngine.isMastered(state, now: .now) && MasteryEngine.retention(state, now: .now) < 0.8
                }.count),
                (.status(.misconception), "勘違いをほどく", "square.on.square", available.filter { store.data.mastery[$0.id]?.misconception == true }.count)
            ]
            ForEach(reviewLinks.indices, id: \.self) { index in
                let item = reviewLinks[index]
                if item.3 > 0 {
                    NavigationLink(value: item.0) {
                        HStack {
                            Label(item.1, systemImage: item.2)
                            Spacer()
                            Text("\(item.3)問").monospacedDigit()
                        }
                        .font(.subheadline).frame(minHeight: 44)
                    }
                    .buttonStyle(StudyButtonStyle())
                }
            }
        }
    }

    private var memoryCard: some View {
        Surface {
            HStack(alignment: .firstTextBaseline) {
                Text("育っている記憶").font(.headline)
                Spacer()
                Button("記録を見る", action: openAnalysis).font(.subheadline).frame(minHeight: 44)
            }
            MemoryBar(stable: stats.stable, growing: catalog.questions.count - stats.new - stats.stable, new: stats.new)
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                        Array(repeating: GridItem(.flexible()), count: 3), alignment: .leading, spacing: 8) {
                NavigationLink(value: QuestionCollectionRoute.status(.stable)) {
                    memoryLegend("定着", count: stats.stable, symbol: "checkmark.circle", color: Palette.positive)
                }
                memoryLegend("学習中", count: catalog.questions.count - stats.new - stats.stable, symbol: "circle.lefthalf.filled", color: Palette.muted)
                NavigationLink(value: QuestionCollectionRoute.status(.new)) {
                    memoryLegend("これから", count: stats.new, symbol: "circle.dashed", color: Palette.muted)
                }
            }
            .buttonStyle(StudyButtonStyle())
            Divider()
            ForEach(catalog.qualification.subjects, id: \.self) { subject in
                NavigationLink(value: QuestionCollectionRoute.subject(subject)) {
                    SubjectProgress(subject: subject, score: stats.subjectScores[subject] ?? 0)
                        .foregroundStyle(Palette.ink).frame(minHeight: 44)
                }
                .buttonStyle(StudyButtonStyle())
            }
        }
    }

    private func memoryLegend(_ title: String, count: Int, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(color)
            Text("\(count)問").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
