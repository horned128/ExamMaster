import SwiftUI

struct DashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.mascotMotionEnabled) private var parentMotionEnabled
    @State private var showExamDateEditor = false
    @State private var showLearningGuide = false
    @State private var greeting = "いっしょに、\nはじめよう。"
    @State private var greetingReplay = 0
    @AppStorage("shortDailyStudy") private var shortSession = true
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let resume: () -> Void
    let openLibrary: () -> Void
    let settings: () -> Void
    let openCompanion: () -> Void

    private var accent: Color { Palette.accent(catalog.qualification.accentHex) }
    private var growth: TankeiGrowth { TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked) }

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let available = SessionPlanner.available(catalog, unlocked: purchase.unlocked)
                let outlook = ReviewOutlook(questions: available, data: store.data, now: timeline.date)
                let retention = RetentionSummary(questions: available, data: store.data, now: timeline.date)
                let goal = TankeiDailyGoal(questionIDs: Set(available.map(\.id)), data: store.data, short: shortSession, now: timeline.date)
                let recommended = SessionPlanner.recommended(catalog, data: store.data, unlocked: purchase.unlocked,
                                                           now: timeline.date, excluding: goal.answeredIDs)
                let selectedQuestions = Array(recommended.questions.prefix(goal.remaining))
                VStack(alignment: .leading, spacing: 24) {
                    header(asOf: timeline.date, goal: goal, dueCount: outlook.dueCount)
                    MemoryBreakdown(summary: retention, identifier: "homeMemory")
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
                    if !goal.completed && goal.target > 0 {
                        studyCard(goal: goal, questions: selectedQuestions, availableCount: available.count)
                    } else {
                        Button(action: openLibrary) {
                            Label("問題を探す", systemImage: "magnifyingglass")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                    }
                    HStack {
                        if outlook.dueCount > 0 {
                            NavigationLink(value: QuestionCollectionRoute.status(.due)) {
                                Label("復習 \(outlook.dueCount)問", systemImage: "arrow.clockwise")
                            }
                        }
                        Spacer(minLength: 8)
                        Button { showLearningGuide = true } label: {
                            Image(systemName: "info.circle").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("記憶と復習のしくみ")
                    }
                    .font(.subheadline).buttonStyle(StudyButtonStyle())
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
        .environment(\.mascotMotionEnabled, parentMotionEnabled && !showLearningGuide && !showExamDateEditor)
        .navigationTitle("ホーム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: settings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("設定")
            }
        }
        .sheet(isPresented: $showLearningGuide) { LearningGuideView(stage: growth.stage).environment(\.mascotMotionEnabled, true) }
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

    private func header(asOf now: Date, goal: TankeiDailyGoal, dueCount: Int) -> some View {
        let context = TankeiGreetingContext.current(data: store.data, dailyGoal: goal, dueCount: dueCount)
        let titleLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        let heroLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 0))
        return VStack(alignment: .leading, spacing: 8) {
            titleLayout {
                Text(catalog.qualification.name).font(.title.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("qualificationTitle")
                Button { showExamDateEditor = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").accessibilityHidden(true)
                        if let remaining = store.data.examDay?.daysRemaining(from: now) {
                            Text(remaining > 0 ? "あと\(remaining)日" : remaining == 0 ? "試験当日" : "試験日が経過").monospacedDigit()
                        } else { Text("試験日") }
                    }
                    .font(.caption).foregroundStyle(Palette.muted).frame(minHeight: 44)
                }
                .buttonStyle(StudyButtonStyle())
                .accessibilityLabel(store.data.examDay == nil ? "試験日を設定" : "試験日を変更")
                .accessibilityValue(examCountdown(asOf: now))
            }
            heroLayout {
                Button {
                    greeting = context.choose(excluding: greeting)
                    greetingReplay += 1
                } label: {
                    Text(greeting).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(Palette.ink)
                }
                .buttonStyle(StudyButtonStyle()).accessibilityHint("別のセリフを表示")
                .accessibilityIdentifier("homeHeading")
                Button(action: openCompanion) {
                    TankeiView(state: context.pose, stage: growth.stage, size: dynamicTypeSize.isAccessibilitySize ? 128 : 176,
                               animated: true, idle: true, expressive: true, eventID: greetingReplay)
                        .contentShape(Rectangle())
                }
                .buttonStyle(StudyButtonStyle())
                .accessibilityLabel("相棒の成長を見る、\(growth.stage.title)")
                .accessibilityIdentifier("openCompanion")
            }
        }
        .task(id: context) { greeting = context.choose(excluding: greeting) }
    }

    private func examCountdown(asOf now: Date) -> String {
        guard let remaining = store.data.examDay?.daysRemaining(from: now) else { return "未設定" }
        return remaining > 0 ? "あと\(remaining)日" : remaining == 0 ? "試験当日" : "試験日が経過"
    }

    private func studyCard(goal: TankeiDailyGoal, questions: [Question], availableCount: Int) -> some View {
        return Surface {
            HStack {
                Text("今日のノルマ").font(.title3.bold()).accessibilityIdentifier("dailyGoalCard")
                Spacer(minLength: 8)
                if !goal.answeredIDs.isEmpty {
                    Text("\(goal.answeredIDs.count) / \(goal.target)問")
                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                }
            }
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                        [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                amountOption("\(min(5, availableCount))問", short: true)
                amountOption("\(min(12, availableCount))問", short: false)
            }
            .accessibilityLabel("学習する量")
            .accessibilityIdentifier("studyAmount")
            Button {
                start(StudySession(title: "今日のノルマ", mode: .recommended, questions: questions, timed: false))
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

}
