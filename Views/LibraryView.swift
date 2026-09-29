import SwiftUI

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "すべて", new = "未学習", due = "復習", incorrect = "間違い", bookmarked = "お気に入り"
    var id: String { rawValue }
}

struct LibraryView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let start: (StudySession) -> Void
    let paywall: () -> Void

    @State private var query = ""
    @State private var subject = "すべて"
    @State private var year = 0
    @State private var filter: LibraryFilter = .all

    private var available: [Question] { SessionPlanner.available(catalog, unlocked: purchase.unlocked) }
    private var years: [Int] { Array(Set(catalog.questions.map(\.year))).sorted(by: >) }
    private var filtered: [Question] {
        catalog.questions.filter { q in
            (query.isEmpty || q.searchText.localizedStandardContains(query)) &&
            (subject == "すべて" || q.subject == subject) && (year == 0 || q.year == year) &&
            (filter == .all || (filter == .new && store.data.mastery[q.id] == nil) ||
             (filter == .due && (store.data.mastery[q.id]?.dueAt.map { $0 <= .now } ?? false)) ||
             (filter == .incorrect && store.data.mastery[q.id]?.lastCorrect == false) ||
             (filter == .bookmarked && store.data.bookmarks.contains(q.id)))
        }
    }

    var body: some View {
        List {
            Section("学習モード") {
                action("ランダム演習", symbol: "shuffle", detail: "分野を混ぜて10問") {
                    launch("ランダム演習", mode: .random, questions: Array(available.shuffled().prefix(10)))
                }
                action("模擬試験", symbol: "timer", detail: "\(catalog.qualification.examMinutes)分 · \(min(catalog.qualification.mockQuestionCount, available.count))問") {
                    start(SessionPlanner.mock(catalog, unlocked: purchase.unlocked))
                }
                if available.contains(where: { store.data.mastery[$0.id]?.lastCorrect == false }) {
                    action("間違えた問題", symbol: "arrow.uturn.backward", detail: "苦手を集中して復習") {
                        launch("間違えた問題", mode: .incorrect, questions: available.filter { store.data.mastery[$0.id]?.lastCorrect == false })
                    }
                }
                if available.contains(where: { store.data.bookmarks.contains($0.id) }) {
                    action("お気に入り", symbol: "bookmark", detail: "保存した問題を復習") {
                        launch("お気に入り", mode: .bookmarked, questions: available.filter { store.data.bookmarks.contains($0.id) })
                    }
                }
                if !SessionPlanner.contrast(catalog, data: store.data, unlocked: purchase.unlocked).questions.isEmpty {
                    action("混同しやすい概念", symbol: "square.on.square", detail: "関連する問題を交互に") {
                        start(SessionPlanner.contrast(catalog, data: store.data, unlocked: purchase.unlocked))
                    }
                }
            }
            Section("年度から選ぶ") {
                ForEach(years, id: \.self) { year in
                    action("\(year)年", symbol: "calendar", detail: "\(catalog.questions.filter { $0.year == year }.count)問") {
                        launch("\(year)年の問題", mode: .year, questions: available.filter { $0.year == year })
                    }
                }
            }
            Section("分野から選ぶ") {
                ForEach(catalog.qualification.subjects, id: \.self) { name in
                    action(name, symbol: "square.grid.2x2", detail: "\(catalog.questions.filter { $0.subject == name }.count)問") {
                        launch(name, mode: .subject, questions: available.filter { $0.subject == name })
                    }
                }
            }
            Section("カテゴリから選ぶ") {
                ForEach(Array(Set(catalog.questions.map(\.category))).sorted(), id: \.self) { category in
                    action(category, symbol: "square.stack.3d.up", detail: "\(catalog.questions.filter { $0.category == category }.count)問") {
                        launch(category, mode: .subject, questions: available.filter { $0.category == category })
                    }
                }
            }
            Section {
                HStack {
                    Menu(subject) {
                        Button("すべて") { subject = "すべて" }
                        ForEach(catalog.qualification.subjects, id: \.self) { item in Button(item) { subject = item } }
                    }
                    Spacer()
                    Menu(year == 0 ? "全年度" : "\(year)年") {
                        Button("全年度") { year = 0 }
                        ForEach(years, id: \.self) { item in Button("\(item)年") { year = item } }
                    }
                }
                Picker("絞り込み", selection: $filter) {
                    ForEach(LibraryFilter.allCases) { item in Text(item.rawValue).tag(item) }
                }
                ForEach(filtered) { question in
                    Button {
                        if purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) {
                            launch("問題を確認", mode: .search, questions: [question])
                        } else { paywall() }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? "doc.text" : "lock")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(question.stem).font(.subheadline).foregroundStyle(.primary)
                                    .lineLimit(2)
                                Text("\(question.year) · \(question.subject) / \(question.category)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .accessibilityLabel("\(question.stem)、\(purchase.unlocked || catalog.qualification.freeQuestionIDs.contains(question.id) ? "利用可能" : "全問題解放が必要")")
                }
                if filtered.isEmpty {
                    ContentUnavailableView("条件に合う問題がありません", systemImage: "line.3.horizontal.decrease.circle",
                                           description: Text("検索語や絞り込みを変更してください。"))
                }
            } header: {
                Text("問題一覧 · \(filtered.count)問")
            } footer: {
                Text("問題文は一覧で確認できます。解答と解説は演習後に表示します。")
            }
            if !purchase.unlocked {
                Section {
                    Button("全問題を解放する", action: paywall)
                } footer: {
                    Text("\(catalog.qualification.freeQuestionIDs.count)問は無料で何度でも学習できます。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("問題を探す")
        .searchable(text: $query, prompt: "問題文・解説・キーワード")
    }

    private func launch(_ title: String, mode: StudyMode, questions: [Question]) {
        guard !questions.isEmpty else {
            if !purchase.unlocked && (mode == .year || mode == .subject) { paywall() }
            return
        }
        start(StudySession(title: title, mode: mode, questions: questions, timed: false))
    }

    private func action(_ title: String, symbol: String, detail: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.title3).frame(width: 28).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
