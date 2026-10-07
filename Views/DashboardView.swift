import SwiftUI

struct DashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showExamDateEditor = false
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日、覚えるべきこと。").font(.largeTitle.bold())
                    Text(catalog.qualification.name + "  ·  " + catalog.qualification.subtitle)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Surface {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 16) {
                                readinessValue
                                examCountdown(asOf: timeline.date)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 16) {
                                readinessValue
                                Spacer(minLength: 0)
                                examCountdown(asOf: timeline.date)
                            }
                        }
                    }
                    ProgressView(value: Double(stats.readiness), total: 100)
                        .accessibilityLabel("学習準備度")
                        .accessibilityValue("100中\(stats.readiness)")
                    Text("記憶の安定・未学習範囲・分野の偏り・直近の演習と模試から見積もる学習指標です。合格を保証する数値ではありません。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        showExamDateEditor = true
                    } label: {
                        Label(store.data.examDay == nil ? "試験日を設定" : "試験日を変更", systemImage: "calendar")
                    }
                    .font(.subheadline.weight(.medium))
                }
                if let pending = store.data.pending {
                    Button(action: resume) {
                        HStack(spacing: 14) {
                            Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("続きから · \(pending.title)").font(.headline)
                                Text("\(pending.questionIDs.count)問中\(pending.index + 1)問目 · \(pending.answers.count)問回答済み")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
                Button { start(SessionPlanner.recommended(catalog, data: store.data, unlocked: purchase.unlocked)) } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("今日のおすすめ学習", systemImage: "sparkle.magnifyingglass")
                            .font(.title3.bold())
                        Text("復習が必要な問題と新しい問題を、分野を混ぜて約12問。")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        HStack {
                            Text("学習を始める").font(.headline)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(Palette.accent(catalog.qualification.accentHex), in: RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)

                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
                           [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    NavigationLink(value: QuestionCollectionRoute.status(.stable)) {
                        Metric(title: "安定して記憶", value: "\(stats.stable)", symbol: "checkmark.seal")
                    }
                    NavigationLink(value: QuestionCollectionRoute.status(.due)) {
                        Metric(title: "復習の目安", value: "\(stats.due)", symbol: "arrow.clockwise")
                    }
                    NavigationLink(value: QuestionCollectionRoute.status(.risk)) {
                        Metric(title: "忘却リスク", value: "\(stats.atRisk)", symbol: "waveform.path")
                    }
                    NavigationLink(value: QuestionCollectionRoute.status(.new)) {
                        Metric(title: "未学習", value: "\(stats.new)", symbol: "square.dashed")
                    }
                    NavigationLink(value: QuestionCollectionRoute.status(.misconception)) {
                        Metric(title: "危険な思い込み", value: "\(stats.misconceptions)", symbol: "exclamationmark.bubble")
                    }
                    Button(action: openAnalysis) {
                        Metric(title: "学習した日", value: "\(stats.studyDays)日", symbol: "calendar")
                    }
                }
                .buttonStyle(.plain)

                if !SessionPlanner.contrast(catalog, data: store.data, unlocked: purchase.unlocked).questions.isEmpty {
                    NavigationLink(value: QuestionCollectionRoute.contrast) {
                        Label("混同しやすい概念を比べる", systemImage: "square.on.square")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("分野別の定着度").font(.title3.bold())
                    ForEach(catalog.qualification.subjects, id: \.self) { subject in
                        HStack {
                            Text(subject).font(.subheadline)
                            Spacer()
                            Text("\(stats.subjectScores[subject] ?? 0)%").monospacedDigit().foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(stats.subjectScores[subject] ?? 0), total: 100)
                    }
                }
                .padding(18)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))

                if let mock = store.data.mocks.last {
                    Surface {
                        Text("直近の模擬試験").font(.headline)
                        Text("\(mock.score) / \(mock.total)問  ·  \(mock.passed ? "基準到達" : "復習を続けましょう")")
                        Text(mock.date, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !purchase.unlocked {
                    Button(action: paywall) {
                        Label("全問題を解放する · \(catalog.questions.count - catalog.qualification.freeQuestionIDs.count)問を追加", systemImage: "lock.open")
                    }
                    .font(.subheadline).padding(.vertical, 8)
                }
                if !purchase.unlocked && !purchase.purchasing {
                    AdBannerPlacement(ads: ads)
                }
                if let error = store.error {
                    Surface {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        Button("保存を再試行") { store.retrySave() }
                    }
                }
            }
            .padding(18)
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
        .sheet(isPresented: $showExamDateEditor) {
            NavigationStack {
                ExamDateEditor(store: store)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { showExamDateEditor = false } }
                    }
            }
            .tint(Palette.accent(catalog.qualification.accentHex))
        }
    }

    private var readinessValue: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("学習準備度").font(.subheadline.weight(.semibold))
            Text("\(stats.readiness) / 100")
                .font(.title.bold()).foregroundStyle(.tint).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func examCountdown(asOf now: Date) -> some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 6) {
            Text("試験日まで").font(.subheadline.weight(.semibold))
            if let remaining = store.data.examDay?.daysRemaining(from: now) {
                Text(remaining > 0 ? "あと\(remaining)日" : remaining == 0 ? "試験当日" : "試験日が経過")
                    .font(remaining < 0 ? .headline : .title.bold())
                    .foregroundStyle(remaining < 0 ? .secondary : .primary)
                    .monospacedDigit()
            } else {
                Text("未設定").font(.title3.bold()).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
