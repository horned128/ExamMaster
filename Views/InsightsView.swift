import SwiftUI

struct InsightsView: View {
    let catalog: Catalog
    let store: StudyStore
    private var stats: StudyStats { StudyStats(catalog: catalog, data: store.data) }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Metric(title: "学習した日", value: "\(stats.studyDays)日", symbol: "calendar")
                    Metric(title: "回答履歴", value: "\(store.data.answers.count)回", symbol: "pencil.line")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("積み重ね")
            } footer: {
                Text("同じ日に何度も解くより、日を分けた想起を重視します。")
            }
            Section("分野別Mastery") {
                ForEach(catalog.qualification.subjects, id: \.self) { subject in
                    let answered = store.data.answers.filter { a in catalog.questions.contains { $0.id == a.questionID && $0.subject == subject } }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(subject).font(.headline)
                            Spacer()
                            Text("\(stats.subjectScores[subject] ?? 0)%").monospacedDigit()
                        }
                        ProgressView(value: Double(stats.subjectScores[subject] ?? 0), total: 100)
                        Text("\(answered.count)回答 · 直近14日 \(recentAccuracy(answered))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
            Section("復習の現在地") {
                Label("安定して覚えている  \(stats.stable)問", systemImage: "checkmark.seal")
                Label("復習のタイミング  \(stats.due)問", systemImage: "arrow.clockwise")
                Label("忘却リスク  \(stats.atRisk)問", systemImage: "waveform.path")
                Label("危険な思い込み  \(stats.misconceptions)問", systemImage: "exclamationmark.bubble")
            }
            Section("模擬試験の履歴") {
                if store.data.mocks.isEmpty {
                    Text("まだ模擬試験の記録がありません。問題を探すタブから受けられます。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.data.mocks.reversed()) { mock in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mock.passed ? "基準到達" : "復習が必要").font(.headline)
                                Text(mock.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(mock.score) / \(mock.total)").monospacedDigit()
                        }
                    }
                }
            }
            Section("直近の回答") {
                if store.data.answers.isEmpty {
                    Text("回答履歴はまだありません。診断や演習を始めると、ここに記録されます。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(store.data.answers.suffix(50).reversed())) { answer in
                        if let question = catalog.questions.first(where: { $0.id == answer.questionID }) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: answer.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(answer.correct ? .green : .orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(question.stem).font(.subheadline).lineLimit(2)
                                    Text(answer.date, style: .date).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                Text("学習準備度はアプリ内の問題集に対する目安です。過去の高得点のみでは上がらず、未学習や時間経過を反映します。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("学習分析")
    }

    private func recentAccuracy(_ answers: [Answer]) -> String {
        let recent = answers.filter { $0.date >= Date().addingTimeInterval(-14 * 86_400) }
        guard !recent.isEmpty else { return "記録なし" }
        return "\(recent.filter(\.correct).count * 100 / recent.count)%正解"
    }
}
