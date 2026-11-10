import Charts
import SwiftUI

struct InsightsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.mascotMotionEnabled) private var parentMotionEnabled
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let paywall: () -> Void
    var settings: (() -> Void)? = nil

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var showLearningGuide = false

    private var recentMocks: [MockResult] { Array(store.data.mocks.suffix(10)).sorted { $0.date < $1.date } }

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let stats = StudyStats(catalog: catalog, data: store.data, now: timeline.date)
                let available = SessionPlanner.available(catalog, unlocked: purchase.unlocked)
                let retention = RetentionSummary(questions: available, data: store.data, now: timeline.date)
                let growth = TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked)
                let byDay = Dictionary(grouping: store.data.answers, by: { Calendar.current.startOfDay(for: $0.date) })
                VStack(alignment: .leading, spacing: 20) {
                    learningSummary(stats: stats, retention: retention, available: available, now: timeline.date)
                    TankeiRecordCompanion(growth: growth)
                    studyHistory(stats: stats, byDay: byDay)
                    mockHistory
                    if !purchase.unlocked && !purchase.purchasing && ads.canShowBanner {
                        AdBannerPlacement(ads: ads)
                    }
                }
                .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
        }
        .background(Palette.background)
        .environment(\.mascotMotionEnabled, parentMotionEnabled && !showLearningGuide)
        .navigationTitle("学習記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let settings { ToolbarItem(placement: .topBarTrailing) {
                Button(action: settings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("設定")
            } }
        }
        .sheet(isPresented: $showLearningGuide) {
            LearningGuideView(stage: TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked).stage,
                              initialSection: .metrics)
                .environment(\.mascotMotionEnabled, true)
        }
    }

    private func learningSummary(stats: StudyStats, retention: RetentionSummary, available: [Question], now: Date) -> some View {
        Surface {
            HStack {
                Text("学習の状態").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button { showLearningGuide = true } label: {
                    Image(systemName: "info.circle").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(StudyButtonStyle()).accessibilityLabel("学習指標の見方")
            }
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) :
                AnyLayout(HStackLayout(alignment: .top, spacing: 20))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text("学習準備度").font(.subheadline)
                    Text("\(stats.readiness) / 100").font(.title2.bold().monospacedDigit())
                    Text("問題集全体").font(.caption).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore).accessibilityLabel("学習準備度")
                .accessibilityValue("100中\(stats.readiness)、問題集全体の総合目安")
                .accessibilityIdentifier("recordReadiness")
                VStack(alignment: .leading, spacing: 4) {
                    Text("定着率").font(.subheadline)
                    Text("\(retention.percent)%").font(.title2.bold().monospacedDigit())
                    Text("\(retention.stable) / \(retention.total)問").font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore).accessibilityLabel("定着率")
                .accessibilityValue("\(retention.percent)パーセント、利用できる\(retention.total)問のうち\(retention.stable)問が定着")
                .accessibilityIdentifier("recordRetention")
            }
            MemoryBreakdown(summary: retention, identifier: "recordMemory")
            DisclosureGroup {
                ForEach(catalog.qualification.subjects, id: \.self) { subject in
                    let summary = RetentionSummary(questions: available.filter { $0.subject == subject }, data: store.data, now: now)
                    SubjectProgress(subject: subject, score: summary.percent).padding(.vertical, 6)
                        .accessibilityIdentifier("subjectRetention-\(subject)")
                }
            } label: {
                Text("科目別の定着率").font(.subheadline).frame(minHeight: 44)
            }
        }
    }

    private func studyHistory(stats: StudyStats, byDay: [Date: [Answer]]) -> some View {
        Surface(inset: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("学習履歴").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                Text("学習 \(stats.studyDays)日 · 回答 \(store.data.answers.count)回")
                    .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("studyHistorySummary")
            }
            .padding(.horizontal, 8)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { changeMonth(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("前の月")
                    Spacer()
                    Text(monthLabel).font(.headline)
                    Spacer()
                    Button { changeMonth(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("次の月")
                    .disabled(month >= (Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now))
                    .opacity(month >= (Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now) ? 0.35 : 1)
                }
                .buttonStyle(StudyButtonStyle())
                studyCalendar(byDay: byDay)
                let answers = byDay[selectedDay] ?? []
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                    Text(answers.isEmpty ? "学習記録なし" : "\(answers.count)回答 · \(answers.filter(\.correct).count)正解")
                        .foregroundStyle(Palette.muted)
                }
                .font(.subheadline)
                if !answers.isEmpty {
                    ForEach(Array(answers.suffix(3).reversed())) { answer in
                        HistoryAnswerRow(answer: answer, catalog: catalog, purchase: purchase,
                                         start: start, paywall: paywall)
                    }
                    NavigationLink("この日の回答を見る") {
                        StudyHistoryView(title: selectedDay.formatted(date: .complete, time: .omitted),
                                         answers: answers, catalog: catalog, purchase: purchase,
                                         start: start, paywall: paywall)
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("selectedDayHistory")
                }
                if !store.data.answers.isEmpty {
                    Divider()
                    NavigationLink("すべての回答を見る") {
                        StudyHistoryView(title: "回答履歴", answers: store.data.answers, catalog: catalog, purchase: purchase,
                                         start: start, paywall: paywall)
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("allAnswerHistory")
                }
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder private func studyCalendar(byDay: [Date: [Answer]]) -> some View {
        let dates = calendarDays
        if dynamicTypeSize.isAccessibilitySize {
            LazyVStack(spacing: 8) {
                ForEach(dates.compactMap { $0 }, id: \.self) { date in
                    let count = byDay[date]?.count ?? 0
                    Button { selectedDay = date } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(date, format: .dateTime.month().day().weekday()).foregroundStyle(Palette.ink)
                            Text(count > 0 ? "\(count)回回答" : "記録なし")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(8)
                        .background(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? Palette.linkAccent(catalog.qualification.accentHex).opacity(0.1) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(StudyButtonStyle())
                    .accessibilityAddTraits(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? .isSelected : [])
                }
            }
        } else {
            let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(weekdays, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                ForEach(0..<dates.count, id: \.self) { index in
                    if let date = dates[index] {
                        let count = byDay[date]?.count ?? 0
                        Button { selectedDay = date } label: {
                            VStack(spacing: 4) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.subheadline.weight(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? .bold : .regular))
                                Circle().fill(count > 0 ? Palette.positive : .clear).frame(width: 5, height: 5)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? Palette.linkAccent(catalog.qualification.accentHex).opacity(0.15) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(StudyButtonStyle())
                        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))、\(count > 0 ? "\(count)回回答" : "学習記録なし")")
                        .accessibilityAddTraits(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? .isSelected : [])
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    private var mockHistory: some View {
        Surface {
            Text("模擬試験の推移").font(.title3.bold())
            if recentMocks.isEmpty {
                Label("記録はこれから", systemImage: "chart.xyaxis.line")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                Text("「\(catalog.qualification.libraryTabTitle)」タブから始められます。")
                    .font(.caption).foregroundStyle(Palette.muted)
            } else {
                Chart {
                    ForEach(recentMocks) { mock in
                        LineMark(x: .value("受験日", mock.date),
                                 y: .value("正答率", Double(mock.score * 100) / Double(max(mock.total, 1))))
                            .foregroundStyle(Palette.linkAccent(catalog.qualification.accentHex))
                        PointMark(x: .value("受験日", mock.date),
                                  y: .value("正答率", Double(mock.score * 100) / Double(max(mock.total, 1))))
                            .foregroundStyle(Palette.linkAccent(catalog.qualification.accentHex))
                    }
                    RuleMark(y: .value("全体の設定基準", catalog.qualification.passingPercent))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 210)
                Text("破線：全体の基準 \(catalog.qualification.passingPercent)%")
                    .font(.caption).foregroundStyle(Palette.muted)
                ForEach(store.data.mocks.suffix(5).reversed()) { mock in
                    NavigationLink { MockResultDetailView(result: mock, catalog: catalog, purchase: purchase) } label: { HStack {
                        Text(mock.date, style: .date)
                        Spacer()
                        Text("\(mock.score) / \(mock.total) · \(mock.passed ? "基準到達" : "見直し")")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }
                    }
                }
                NavigationLink("すべての模試結果") { MockResultHistoryView(catalog: catalog, store: store, purchase: purchase) }
            }
        }
    }

    private var monthLabel: String {
        let format = DateFormatter()
        format.locale = Locale(identifier: "ja_JP")
        format.dateFormat = "yyyy年M月"
        return format.string(from: month)
    }

    private var calendarDays: [Date?] {
        let cal = Calendar.current
        let weekday = (cal.component(.weekday, from: month) + 5) % 7 // Monday first.
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 0
        let days = (0..<count).map { cal.date(byAdding: .day, value: $0, to: month) }
        return Array(repeating: Optional<Date>.none, count: weekday) + days
    }

    private func changeMonth(_ offset: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: month) else { return }
        month = newMonth
        let today = Calendar.current.startOfDay(for: .now)
        selectedDay = Calendar.current.isDate(today, equalTo: newMonth, toGranularity: .month) ? today : newMonth
    }
}

struct StudyHistoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let answers: [Answer]
    let catalog: Catalog
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void
    @State private var order: AnswerHistoryOrder = .newest

    private var orderPicker: some View {
        Picker("回答履歴の並び順", selection: $order) {
            ForEach(AnswerHistoryOrder.allCases) { item in Text(item.title).tag(item) }
        }.accessibilityIdentifier("historyOrder")
    }

    var body: some View {
        List {
            Section {
                Text("\(answers.count)回答 · \(answers.filter(\.correct).count)正解").font(.subheadline)
                if dynamicTypeSize.isAccessibilitySize { orderPicker.pickerStyle(.menu) }
                else { orderPicker.pickerStyle(.segmented) }
            }
            if answers.isEmpty { ContentUnavailableView("学習記録はありません", systemImage: "calendar") }
            ForEach(AnswerHistoryDay.grouped(answers, order: order)) { day in
                Section {
                    ForEach(day.answers) { answer in
                        HistoryAnswerRow(answer: answer, catalog: catalog, purchase: purchase,
                                         start: start, paywall: paywall, showDate: false)
                    }
                } header: {
                    Text(day.date, format: .dateTime.year().month().day().weekday())
                        .accessibilityIdentifier("historyDay")
                }
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct HistoryAnswerRow: View {
    let answer: Answer
    let catalog: Catalog
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void
    var showDate = true

    var body: some View {
        if let question = catalog.questions.first(where: { $0.id == answer.questionID }) {
            Button {
                if purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) {
                    start(StudySession(title: "問題を確認", mode: .search, questions: [question], timed: false))
                } else { paywall() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: answer.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                         .foregroundStyle(answer.correct ? Palette.positive : Palette.review)
                         .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? question.stem : "有料問題").font(.subheadline).foregroundStyle(Palette.ink).lineLimit(2)
                        Text("\(answer.date.formatted(date: showDate ? .abbreviated : .omitted, time: .shortened)) · \(question.subject)")
                             .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    if !purchase.unlocked && !catalog.qualification.freeQuestionIDs.contains(question.id) {
                        Image(systemName: "lock").foregroundStyle(.secondary)
                    }
                }
                 .padding(.vertical, 4).frame(minHeight: 44)
            }
            .buttonStyle(StudyButtonStyle())
            .accessibilityIdentifier("historyAnswer-\(answer.id.uuidString)")
            .accessibilityLabel("\(answer.correct ? "正解" : "見直し")、\(purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? question.stem : "有料問題")、\(answer.date.formatted(date: .abbreviated, time: .shortened))")
            .accessibilityHint(purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? "この問題を開きます" : "全問題解放の購入画面を開きます")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("更新前の問題 · \(answer.questionID)").font(.subheadline)
                Text("\(answer.correct ? "正解" : "見直し") · \(answer.date.formatted(date: showDate ? .abbreviated : .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            .padding(.vertical, 4).accessibilityElement(children: .combine)
            .accessibilityIdentifier("historyAnswer-\(answer.id.uuidString)")
        }
    }
}
