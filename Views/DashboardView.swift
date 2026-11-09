import SwiftUI

struct DashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.mascotMotionEnabled) private var parentMotionEnabled
    @State private var showExamDateEditor = false
    @State private var showLearningGuide = false
    @State private var greeting = "いっしょに、\nはじめよう。"
    @State private var greetingReplay = 0
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let openLibrary: () -> Void
    let openSubjects: () -> Void
    let openIncorrect: () -> Void
    let openBookmarks: () -> Void
    let paywall: () -> Void
    let settings: () -> Void

    private var accent: Color { Palette.accent(catalog.qualification.accentHex) }
    private var growth: TankeiGrowth { TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked) }

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let available = SessionPlanner.available(catalog, unlocked: purchase.unlocked)
                let outlook = ReviewOutlook(questions: available, data: store.data, now: timeline.date)
                let retention = RetentionSummary(questions: available, data: store.data, now: timeline.date)
                let today = SessionPlanner.today(catalog, data: store.data, unlocked: purchase.unlocked, now: timeline.date)
                let momentum = StudyMomentum(answers: store.data.answers, now: timeline.date)
                VStack(alignment: .leading, spacing: 12) {
                    momentumChips(momentum)
                    Surface(inset: 14, spacing: 8) {
                        examSchedule(asOf: timeline.date)
                        Divider()
                        header(retention: retention, dueCount: outlook.dueCount, momentum: momentum)
                        MemoryBreakdown(summary: retention, identifier: "homeMemory", compact: true)
                    }
                    if !today.session.questions.isEmpty { todayCard(today) }
                    FootprintWeek(momentum: momentum)
                    if let balanceTitle = catalog.qualification.subjectBalanceTitle {
                        Surface(inset: 14, spacing: 12) {
                            Label(balanceTitle, systemImage: "chart.bar.doc.horizontal").font(.headline)
                            ForEach(catalog.qualification.subjects, id: \.self) { subject in
                                let items = available.filter { $0.subject == subject }
                                SubjectProgress(subject: subject, score: RetentionSummary(questions: items, data: store.data, now: timeline.date).percent)
                            }

                        }
                    }
                    HStack {
                        Text("学習メニュー").font(.headline).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if outlook.dueCount > 0 {
                            NavigationLink(value: QuestionCollectionRoute.status(.due)) {
                                Text("復習 \(outlook.dueCount)問").font(.caption.weight(.semibold))
                            }.frame(minHeight: 44)
                        }
                    }
                    StudyGrid {
                        Button(action: openSubjects) { FeatureCard(title: "分野別", symbol: "square.grid.2x2") }
                            .accessibilityIdentifier("homeSubjects")
                        Button(action: openLibrary) { FeatureCard(title: catalog.qualification.libraryTabTitle, symbol: catalog.qualification.libraryTabSymbol) }
                            .accessibilityIdentifier("homeYears")
                        Button(action: openIncorrect) {
                            FeatureCard(title: "苦手問題", symbol: "arrow.uturn.backward",
                                        detail: "\(QuestionCollections.questions(for: .incorrect, catalog: catalog, data: store.data).count)問", color: Palette.review)
                        }
                        Button(action: openBookmarks) {
                            FeatureCard(title: "ブックマーク", symbol: "bookmark", detail: "\(catalog.questions.filter { store.data.bookmarks.contains($0.id) }.count)問")
                        }
                        NavigationLink(value: StudyDestination.quiz) { FeatureCard(title: "小テスト", symbol: "bolt", detail: "Lv別にチャレンジ") }
                        NavigationLink(value: StudyDestination.records) { FeatureCard(title: "学習記録", symbol: "chart.bar.xaxis") }.accessibilityIdentifier("homeRecords")
                    }
                    Button { showLearningGuide = true } label: {
                        Label("記憶と復習のしくみ", systemImage: "info.circle").font(.subheadline).frame(minHeight: 44)
                    }
                    if !purchase.unlocked && !purchase.purchasing { AdBannerPlacement(ads: ads) }
                    if let error = store.error {
                        Surface {
                            Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                            Button("保存を再試行") { store.retrySave() }.frame(minHeight: 44)
                        }
                    }
                }
                .buttonStyle(StudyButtonStyle())
                .padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
        }
        .background(Palette.background)
        .environment(\.mascotMotionEnabled, parentMotionEnabled && !showLearningGuide && !showExamDateEditor)
        .navigationTitle(catalog.qualification.appDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showExamDateEditor = true } label: { Image(systemName: "calendar.badge.clock") }
                    .accessibilityLabel(store.data.examDay == nil ? "試験日を設定" : "試験日を変更")
                    .accessibilityValue(examCountdown(asOf: .now))
            }
            ToolbarItem(placement: .principal) {
                Group {
                    if let brand = catalog.qualification.brandName {
                        Text("\(brand)\n\(catalog.qualification.name)")
                            .font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                            .lineLimit(2).minimumScaleFactor(0.65).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    } else {
                        Text(catalog.qualification.name).font(.headline).lineLimit(2)
                    }
                }
                    .accessibilityLabel(catalog.qualification.appDisplayName)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("qualificationTitle")
            }
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

    private func header(retention: RetentionSummary, dueCount: Int, momentum: StudyMomentum) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        let goal = StudyMomentum.dailyGoal
        return layout {
            VStack(spacing: 6) {
                NavigationLink(value: StudyDestination.records) {
                    ZStack {
                        Circle().stroke(Palette.piyoTint, lineWidth: 9)
                        Circle().trim(from: 0, to: min(1, Double(momentum.todayAnswers) / Double(goal)))
                            .stroke(Palette.piyo, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        TankeiView(state: dueCount > 0 ? .review : .ready, stage: growth.stage, size: 96,
                                   animated: true, idle: true, expressive: true, eventID: greetingReplay)
                    }
                    .frame(width: 128, height: 128)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("学習記録と相棒の成長を見る")
                .accessibilityValue("今日 \(momentum.todayAnswers)問、目標 \(goal)問")
                .accessibilityIdentifier("openCompanion")
                TankeiEvolutionGaugeView(gauge: TankeiEvolutionGauge(data: store.data))
            }
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    greetingReplay += 1
                    greeting = greetingReplay.isMultiple(of: 2) ? "好きな分野から、いっしょに。" : "一問ずつ、力にしていこう。"
                } label: {
                    Text(greeting.replacingOccurrences(of: "\n", with: ""))
                        .font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(Palette.piyoTint, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityHint("別のセリフを表示").accessibilityIdentifier("homeHeading")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("今日").font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
                    Text("\(momentum.todayAnswers)").font(.title2.weight(.heavy).monospacedDigit())
                    Text("/ \(goal)問").font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
                    Spacer(minLength: 8)
                    Text("定着率 \(retention.percent)%").font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Palette.positive)
                }
                .accessibilityElement(children: .combine)
                Text("学習済み \(retention.total - retention.new)問 · 要復習 \(dueCount)問")
                    .font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// あしあと（連続日数）とはね。数字は大きく、責める言葉は使わない。
    private func momentumChips(_ momentum: StudyMomentum) -> some View {
        HStack(spacing: 8) {
            MomentumChip(value: "\(momentum.streak)日", tint: Palette.beak) { FootprintMark() }
                .accessibilityLabel("あしあと \(momentum.streak)日連続")
                .accessibilityIdentifier("homeStreak")
            MomentumChip(value: momentum.feathers.formatted(), tint: Palette.piyoDeep) { FeatherMark() }
                .accessibilityLabel("はね \(momentum.feathers)枚")
                .accessibilityIdentifier("homeFeathers")
            Spacer(minLength: 0)
        }
    }

    /// 毎日開いたときの最初の一手。何を解くかは復習の優先順で決め、利用者には量と内訳だけを見せる。
    private func todayCard(_ plan: TodayPlan) -> some View {
        let detail = [plan.reviewCount > 0 ? "復習 \(plan.reviewCount)問" : nil,
                      plan.newCount > 0 ? "新しい問題 \(plan.newCount)問" : nil].compactMap { $0 }.joined(separator: " · ")
        let eyebrow = store.data.answers.isEmpty ? "まずはここから" : "今日の学習"
        return Button { start(plan.session) } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill").font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Color.white, in: Circle()) // Sits on brand yellow in both appearances.
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(eyebrow).font(.caption.weight(.bold))
                    Text("\(plan.session.questions.count)問をはじめる").font(.title3.weight(.heavy))
                    Text(detail).font(.caption.weight(.semibold))
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).accessibilityHidden(true)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .buttonStyle(PuffyButtonStyle(minHeight: 72))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(eyebrow)、\(plan.session.questions.count)問を解く")
        .accessibilityValue(detail)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("homeTodayStudy")
    }

    private func examCountdown(asOf now: Date) -> String {
        guard let remaining = store.data.examDay?.daysRemaining(from: now) else { return "未設定" }
        return remaining > 0 ? "あと\(remaining)日" : remaining == 0 ? "試験当日" : "試験日が経過"
    }

    private func examSchedule(asOf now: Date) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return VStack(alignment: .leading, spacing: 4) {
            scheduleDateLabel("今日", date: now).font(.caption).foregroundStyle(Palette.muted)
                .accessibilityIdentifier("homeToday")
            layout {
                Label {
                    if let date = store.data.examDay?.date() {
                        scheduleDateLabel("試験日", date: date)
                    } else {
                        Text("試験日を設定")
                    }
                } icon: { Image(systemName: "calendar.badge.clock").accessibilityHidden(true) }
                .labelStyle(ScheduleLabelStyle(hideIcon: dynamicTypeSize.isAccessibilitySize))
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("homeExamDate")
                if store.data.examDay != nil {
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Text(examCountdown(asOf: now)).font(.caption.bold().monospacedDigit())
                        .foregroundStyle(Palette.positive).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Palette.positive.opacity(0.1), in: Capsule())
                        .accessibilityIdentifier("homeExamCountdown")
                }
            }
        }
        .padding(.trailing, 44)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .overlay(alignment: .trailing) {
            Button { showExamDateEditor = true } label: {
                Image(systemName: "pencil").font(.subheadline).foregroundStyle(Palette.positive)
                    .frame(width: 44, height: 44)
            }.accessibilityLabel("受験予定を編集").accessibilityIdentifier("homeExamSchedule")
        }
    }

    private func scheduleDate(_ date: Date) -> String {
        var format = Date.FormatStyle.dateTime.year().month(.twoDigits).day(.twoDigits).weekday(.abbreviated)
            .locale(Locale(identifier: "ja_JP"))
        format.calendar = ExamDay.localCalendar
        return date.formatted(format)
    }

    @ViewBuilder private func scheduleDateLabel(_ title: String, date: Date) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title) \(String(ExamDay.localCalendar.component(.year, from: date)))年")
                Text(date.formatted(Date.FormatStyle.dateTime.month().day().locale(Locale(identifier: "ja_JP"))))
            }
            .accessibilityElement(children: .ignore).accessibilityLabel("\(title) \(scheduleDate(date))")
        } else {
            Text("\(title) \(scheduleDate(date))")
        }
    }

}

private struct ScheduleLabelStyle: LabelStyle {
    let hideIcon: Bool
    func makeBody(configuration: Configuration) -> some View {
        if hideIcon { configuration.title } else {
            HStack(spacing: 4) { configuration.icon; configuration.title }
        }
    }
}

private struct MomentumChip<Icon: View>: View {
    let value: String
    let tint: Color
    @ViewBuilder let icon: Icon
    var body: some View {
        HStack(spacing: 6) {
            icon.foregroundStyle(tint).frame(width: 20, height: 20).accessibilityHidden(true)
            Text(value).font(.subheadline.weight(.heavy).monospacedDigit()).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12).frame(minHeight: 36)
        .background(Palette.surface, in: Capsule())
        .shadow(color: Palette.border, radius: 0, y: 2)
        .accessibilityElement(children: .ignore)
    }
}

/// ひよこの足あと。連続日数のしるし。
struct FootprintMark: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var path = Path()
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.92)); path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.5))
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.5)); path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.18))
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.5)); path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.08))
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.5)); path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.18))
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: max(2, w * 0.13), lineCap: .round))
        }
    }
}

/// はね。正解や復習で貯まるしるし。
struct FeatherMark: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var vane = Path()
            vane.move(to: CGPoint(x: w * 0.2, y: h * 0.8))
            vane.addCurve(to: CGPoint(x: w * 0.82, y: h * 0.12), control1: CGPoint(x: w * 0.3, y: h * 0.4),
                          control2: CGPoint(x: w * 0.55, y: h * 0.2))
            vane.addCurve(to: CGPoint(x: w * 0.2, y: h * 0.8), control1: CGPoint(x: w * 0.9, y: h * 0.45),
                          control2: CGPoint(x: w * 0.6, y: h * 0.75))
            context.fill(vane, with: .foreground)
            var quill = Path()
            quill.move(to: CGPoint(x: w * 0.12, y: h * 0.9)); quill.addLine(to: CGPoint(x: w * 0.55, y: h * 0.45))
            context.stroke(quill, with: .foreground, style: StrokeStyle(lineWidth: max(1.5, w * 0.08), lineCap: .round))
        }
    }
}

/// 今週のあしあと。学習した日・おやすみ券で守った日・今日・これからを形でも区別する。
struct FootprintWeek: View {
    let momentum: StudyMomentum
    private static let labels = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今週のあしあと").font(.subheadline.weight(.heavy))
                Spacer(minLength: 8)
                Text(momentum.restTicketAvailable ? "おやすみ券 1枚" : "おやすみ券 使用済み")
                    .font(.caption.weight(.bold)).foregroundStyle(Palette.beakText)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Palette.beak.opacity(0.14), in: Capsule())
            }
            HStack(spacing: 4) {
                ForEach(Array(momentum.week.enumerated()), id: \.element.id) { offset, day in
                    VStack(spacing: 4) {
                        Text(Self.labels[offset]).font(.caption2.weight(.bold)).foregroundStyle(Palette.muted)
                        mark(for: day)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .popCard(radius: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今週のあしあと")
        .accessibilityValue("今週 \(momentum.week.filter(\.studied).count)日学習、\(momentum.streak)日連続、" +
                            (momentum.restTicketAvailable ? "おやすみ券 1枚" : "おやすみ券 使用済み"))
        .accessibilityIdentifier("homeWeek")
    }

    @ViewBuilder private func mark(for day: StudyMomentum.Day) -> some View {
        if day.studied {
            Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(Palette.onPiyo)
                .frame(width: 30, height: 30).background(Palette.piyo, in: Circle())
        } else if day.rested {
            Image(systemName: "moon.zzz.fill").font(.caption2.weight(.bold)).foregroundStyle(Palette.beakText)
                .frame(width: 30, height: 30).background(Palette.beak.opacity(0.16), in: Circle())
        } else if day.isToday {
            Text("今日").font(.caption2.weight(.heavy)).foregroundStyle(Palette.beakText)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Palette.piyo, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
        } else {
            Circle().fill(Palette.track).frame(width: 30, height: 30)
        }
    }
}
