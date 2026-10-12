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
                VStack(alignment: .leading, spacing: 8) {
                    Surface(inset: 12, spacing: 6) {
                        examSchedule(asOf: timeline.date)
                        Divider()
                        header(retention: retention, dueCount: outlook.dueCount)
                        MemoryBreakdown(summary: retention, identifier: "homeMemory", compact: true)
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
                        Button(action: openLibrary) { FeatureCard(title: "年度別", symbol: "calendar") }
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

    private func header(retention: RetentionSummary, dueCount: Int) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            NavigationLink(value: StudyDestination.records) {
                TankeiView(state: dueCount > 0 ? .review : .ready, stage: growth.stage, size: 112,
                           animated: true, idle: true, expressive: true, eventID: greetingReplay)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("学習記録と相棒の成長を見る")
            .accessibilityIdentifier("openCompanion")
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("定着率").font(.headline)
                    Text("\(retention.percent)%").font(.title2.bold().monospacedDigit()).foregroundStyle(Palette.positive)
                    Spacer(minLength: 0)
                }
                Text("学習済み \(retention.total - retention.new)問 · 要復習 \(dueCount)問")
                    .font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                Button {
                    greetingReplay += 1
                    greeting = greetingReplay.isMultiple(of: 2) ? "好きな分野から、いっしょに。" : "一問ずつ、力にしていこう。"
                } label: {
                    Text(greeting.replacingOccurrences(of: "\n", with: ""))
                        .font(.caption).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityHint("別のセリフを表示").accessibilityIdentifier("homeHeading")
            }
        }
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
