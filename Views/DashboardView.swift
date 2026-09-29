import SwiftUI

struct DashboardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void

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
                    HStack(alignment: .firstTextBaseline) {
                        Text("学習準備度").font(.headline)
                        Spacer()
                        Text("\(stats.readiness) / 100").font(.title.bold()).foregroundStyle(.tint)
                    }
                    ProgressView(value: Double(stats.readiness), total: 100)
                        .accessibilityLabel("学習準備度")
                        .accessibilityValue("100中\(stats.readiness)")
                    Text("記憶の安定・未学習範囲・分野の偏り・直近の演習と模試から見積もる学習指標です。合格を保証する数値ではありません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

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
                    Metric(title: "安定して記憶", value: "\(stats.stable)", symbol: "checkmark.seal")
                    Metric(title: "復習の目安", value: "\(stats.due)", symbol: "arrow.clockwise")
                    Metric(title: "忘却リスク", value: "\(stats.atRisk)", symbol: "waveform.path")
                    Metric(title: "未学習", value: "\(stats.new)", symbol: "square.dashed")
                    Metric(title: "危険な思い込み", value: "\(stats.misconceptions)", symbol: "exclamationmark.bubble")
                    Metric(title: "学習した日", value: "\(stats.studyDays)日", symbol: "calendar")
                }

                if stats.misconceptions > 0 {
                    Button { start(StudySession(title: "危険な思い込みを潰す", mode: .misconception,
                                                questions: SessionPlanner.interleave(SessionPlanner.available(catalog, unlocked: purchase.unlocked).filter { store.data.mastery[$0.id]?.misconception == true }), timed: false)) } label: {
                        Label("危険な思い込みを潰す", systemImage: "exclamationmark.triangle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                if !SessionPlanner.contrast(catalog, data: store.data, unlocked: purchase.unlocked).questions.isEmpty {
                    Button { start(SessionPlanner.contrast(catalog, data: store.data, unlocked: purchase.unlocked)) } label: {
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
        .navigationTitle("今日")
        .toolbar(.hidden, for: .navigationBar)
    }
}
