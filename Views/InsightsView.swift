import Charts
import SwiftUI

struct InsightsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let paywall: () -> Void
    let settings: () -> Void

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var showLearningGuide = false

    private var recentMocks: [MockResult] { Array(store.data.mocks.suffix(10)).sorted { $0.date < $1.date } }

    var body: some View {
        ScrollView {
            let stats = StudyStats(catalog: catalog, data: store.data)
            let byDay = Dictionary(grouping: store.data.answers, by: { Calendar.current.startOfDay(for: $0.date) })
            let dates = calendarDays
            VStack(alignment: .leading, spacing: 20) {
                Text("学んだぶんが、\n見えてくる。")
                    .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                Surface {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 20) { ReadinessRing(value: stats.readiness); readinessDescription }
                    } else {
                        HStack(spacing: 20) { ReadinessRing(value: stats.readiness); readinessDescription }
                    }
                }
                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                            [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    Metric(title: "学習した日", value: "\(stats.studyDays)日", symbol: "calendar")
                    Metric(title: "回答履歴", value: "\(store.data.answers.count)回", symbol: "pencil.line")
                }

            Surface(inset: 12) {
                Text("学習カレンダー").font(.title3.bold())
                    .padding(.horizontal, 8)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                            .accessibilityLabel("前の月")
                        Spacer()
                        Text(monthLabel).font(.headline)
                        Spacer()
                        Button { changeMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                            .accessibilityLabel("次の月")
                            .disabled(month >= (Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now))
                            .opacity(month >= (Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now) ? 0.35 : 1)
                    }
                    .buttonStyle(StudyButtonStyle())
                    if dynamicTypeSize.isAccessibilitySize {
                        LazyVStack(spacing: 8) {
                            ForEach(dates.compactMap { $0 }, id: \.self) { date in
                                let count = byDay[date]?.count ?? 0
                                Button { selectedDay = date } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(date, format: .dateTime.month().day().weekday())
                                             .foregroundStyle(Palette.ink)
                                        Text(count > 0 ? "\(count)回回答" : "記録なし")
                                            .font(.caption).foregroundStyle(Palette.muted)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(8)
                                    .background(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? Palette.linkAccent(catalog.qualification.accentHex).opacity(0.1) : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
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
                                Button {
                                    selectedDay = date
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("\(Calendar.current.component(.day, from: date))")
                                            .font(.subheadline.weight(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? .bold : .regular))
                                        Circle().fill(count > 0 ? Palette.positive : .clear).frame(width: 5, height: 5)
                                            .accessibilityHidden(true)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Calendar.current.isDate(date, inSameDayAs: selectedDay) ? Palette.linkAccent(catalog.qualification.accentHex).opacity(0.15) : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
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
                    let answers = byDay[selectedDay] ?? []
                     VStack(alignment: .leading, spacing: 6) {
                         Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                        Text(answers.isEmpty ? "学習記録なし" : "\(answers.count)回答 · \(answers.filter(\.correct).count)正解")
                             .foregroundStyle(Palette.muted)
                    }
                    .font(.subheadline)
                    if !answers.isEmpty {
                        NavigationLink("この日の回答を見る") {
                            StudyHistoryView(title: selectedDay.formatted(date: .complete, time: .omitted),
                                             answers: answers, catalog: catalog, purchase: purchase,
                                             start: start, paywall: paywall)
                        }
                        .frame(minHeight: 44)
                    }
                }
                .padding(.vertical, 6)
            }

            Surface {
                Text("科目別の定着度").font(.title3.bold())
                 ForEach(catalog.qualification.subjects, id: \.self) { subject in
                     SubjectProgress(subject: subject, score: stats.subjectScores[subject] ?? 0)
                 }
                 Text("回答と時間経過からの目安").font(.caption).foregroundStyle(Palette.muted)
            }

            Surface {
                Text("模擬試験の推移").font(.title3.bold())
                if recentMocks.isEmpty {
                     Label("記録はこれから", systemImage: "chart.xyaxis.line")
                         .font(.subheadline).foregroundStyle(Palette.muted)
                     Button("模擬試験を試す") { start(SessionPlanner.mock(catalog, unlocked: purchase.unlocked)) }
                         .frame(minHeight: 44)
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
                        HStack {
                            Text(mock.date, style: .date)
                            Spacer()
                             Text("\(mock.score) / \(mock.total) · \(mock.passed ? "基準到達" : "見直し")")
                                 .font(.subheadline).foregroundStyle(Palette.muted)
                        }
                    }
                }
            }

            Surface {
                Text("最近の回答").font(.title3.bold())
                if store.data.answers.isEmpty {
                     Text("最初の1問から、ここに記録。")
                         .font(.subheadline).foregroundStyle(Palette.muted)
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
            .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle("学習の記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: settings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("設定")
            }
        }
        .sheet(isPresented: $showLearningGuide) { LearningGuideView() }
    }

    private var readinessDescription: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("学習準備度").font(.headline)
            Text("合格確率ではありません").font(.caption).foregroundStyle(Palette.muted)
            Button("目安の見方") { showLearningGuide = true }
                .font(.subheadline).frame(minHeight: 44)
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
                         .foregroundStyle(answer.correct ? Palette.positive : Palette.review)
                         .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.stem).font(.subheadline).foregroundStyle(Palette.ink).lineLimit(2)
                        Text("\(answer.date.formatted(date: .abbreviated, time: .shortened)) · \(question.subject)")
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
            .accessibilityLabel("\(answer.correct ? "正解" : "見直し")、\(question.stem)、\(answer.date.formatted(date: .abbreviated, time: .shortened))")
            .accessibilityHint(purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? "この問題を開きます" : "全問題解放の購入画面を開きます")
        }
    }
}
