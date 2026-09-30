import Charts
import SwiftUI

struct InsightsView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let paywall: () -> Void
    let settings: () -> Void

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private var recentMocks: [MockResult] { Array(store.data.mocks.suffix(10)).sorted { $0.date < $1.date } }

    var body: some View {
        ScrollView {
            let stats = StudyStats(catalog: catalog, data: store.data)
            let byDay = Dictionary(grouping: store.data.answers, by: { Calendar.current.startOfDay(for: $0.date) })
            let dates = calendarDays
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Metric(title: "学習した日", value: "\(stats.studyDays)日", symbol: "calendar")
                    Metric(title: "回答履歴", value: "\(store.data.answers.count)回", symbol: "pencil.line")
                }
                Text("問題数だけでなく、日を分けた学習を大切にしましょう。")
                    .font(.caption).foregroundStyle(.secondary)

            Surface {
                Text("学習カレンダー").font(.title3.bold())
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("前の月")
                        Spacer()
                        Text(monthLabel).font(.headline)
                        Spacer()
                        Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("次の月")
                            .disabled(month >= (Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now))
                    }
                    .buttonStyle(.bordered)
                    let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(weekdays, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                        ForEach(0..<dates.count, id: \.self) { index in
                            if let date = dates[index] {
                                let count = byDay[date]?.count ?? 0
                                Button {
                                    selectedDay = date
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("\(Calendar.current.component(.day, from: date))")
                                            .font(.subheadline.weight(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? .bold : .regular))
                                        Circle().fill(count > 0 ? Color.accentColor : .clear).frame(width: 5, height: 5)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 38)
                                    .background(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? Color.accentColor.opacity(0.15) : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))、\(count > 0 ? "\(count)回回答" : "学習記録なし")")
                            } else {
                                Color.clear.frame(height: 38)
                            }
                        }
                    }
                    let answers = byDay[selectedDay] ?? []
                    HStack {
                        Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text(answers.isEmpty ? "学習記録なし" : "\(answers.count)回答 · \(answers.filter(\.correct).count)正解")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    if !answers.isEmpty {
                        NavigationLink("この日の回答を見る") {
                            StudyHistoryView(title: selectedDay.formatted(date: .complete, time: .omitted),
                                             answers: answers, catalog: catalog, purchase: purchase,
                                             start: start, paywall: paywall)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Surface {
                Text("科目別の定着度").font(.title3.bold())
                Chart(catalog.qualification.subjects, id: \.self) { subject in
                    BarMark(x: .value("定着度", stats.subjectScores[subject] ?? 0),
                            y: .value("科目", subject))
                    .foregroundStyle(Color.accentColor.gradient)
                    .accessibilityLabel("\(subject) \(stats.subjectScores[subject] ?? 0)パーセント")
                }
                .chartXScale(domain: 0...100)
                .chartXAxis { AxisMarks(values: [0, 25, 50, 75, 100]) }
                .frame(height: CGFloat(catalog.qualification.subjects.count) * 49 + 42)
                Text("未学習の問題と時間経過を含む、分野ごとの記憶定着の目安です。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Surface {
                Text("模擬試験の推移").font(.title3.bold())
                if recentMocks.isEmpty {
                    ContentUnavailableView("模擬試験の記録はまだありません", systemImage: "chart.xyaxis.line",
                                           description: Text("問題を探すタブから模擬試験に挑戦できます。"))
                } else {
                    Chart {
                        ForEach(recentMocks) { mock in
                            LineMark(x: .value("受験日", mock.date),
                                     y: .value("正答率", Double(mock.score * 100) / Double(max(mock.total, 1))))
                                .foregroundStyle(Color.accentColor)
                            PointMark(x: .value("受験日", mock.date),
                                      y: .value("正答率", Double(mock.score * 100) / Double(max(mock.total, 1))))
                                .foregroundStyle(Color.accentColor)
                        }
                        RuleMark(y: .value("全体の設定基準", catalog.qualification.passingPercent))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundStyle(.secondary)
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 210)
                    Text("直近\(recentMocks.count)回の全体正答率。科目別の基準も含めた判定は各回の結果をご確認ください。")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(store.data.mocks.suffix(5).reversed()) { mock in
                        HStack {
                            Text(mock.date, style: .date)
                            Spacer()
                            Text("\(mock.score) / \(mock.total) · \(mock.passed ? "基準到達" : "復習を続けましょう")")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Surface {
                Text("最近の回答").font(.title3.bold())
                if store.data.answers.isEmpty {
                    Text("回答履歴はまだありません。診断や演習を始めると記録されます。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(store.data.answers.suffix(5).reversed())) { answer in
                        HistoryAnswerRow(answer: answer, catalog: catalog, purchase: purchase,
                                         start: start, paywall: paywall)
                    }
                    NavigationLink("すべての回答を見る") {
                        StudyHistoryView(title: "回答履歴", answers: store.data.answers,
                                         catalog: catalog, purchase: purchase, start: start, paywall: paywall)
                    }
                }
            }
            if !purchase.unlocked && !purchase.purchasing && ads.canShowBanner {
                AdBannerPlacement(ads: ads)
            }
            }
            .padding(18)
        }
        .background(Palette.background)
        .navigationTitle("学習分析")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: settings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("設定")
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
    let title: String
    let answers: [Answer]
    let catalog: Catalog
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void

    var body: some View {
        List {
            if answers.isEmpty {
                ContentUnavailableView("この日の学習記録はありません", systemImage: "calendar")
            } else {
                Section("\(answers.count)回答 · \(answers.filter(\.correct).count)正解") {
                    ForEach(Array(answers.reversed())) { answer in
                        HistoryAnswerRow(answer: answer, catalog: catalog, purchase: purchase,
                                         start: start, paywall: paywall)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryAnswerRow: View {
    let answer: Answer
    let catalog: Catalog
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void

    var body: some View {
        if let question = catalog.questions.first(where: { $0.id == answer.questionID }) {
            Button {
                if purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) {
                    start(StudySession(title: "問題を確認", mode: .search, questions: [question], timed: false))
                } else { paywall() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: answer.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(answer.correct ? .green : .orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.stem).font(.subheadline).foregroundStyle(.primary).lineLimit(2)
                        Text("\(answer.date.formatted(date: .abbreviated, time: .shortened)) · \(question.subject)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if !purchase.unlocked && !catalog.qualification.freeQuestionIDs.contains(question.id) {
                        Image(systemName: "lock").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
