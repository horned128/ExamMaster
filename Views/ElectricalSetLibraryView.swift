import SwiftUI

/// Separate papers, times and elective questions for the four electrical subjects.
struct ElectricalSetLibraryView: View {
    let year: Int
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let paywall: () -> Void
    @State private var subject = "理論"

    private var sets: [MockSet] {
        let ids = Set(catalog.questions.filter { $0.year == year && $0.subject == subject }.compactMap(\.mockSetID))
        return catalog.mockSets.filter { ids.contains($0.id) }.sorted { $0.id < $1.id }
    }
    private var hasPredictions: Bool { sets.contains { $0.kind == .prediction } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if hasPredictions {
                    Surface {
                        Text("令和8年度下期（2027年実施）対策").font(.headline)
                        Text("オリジナル予想 第1〜3回。公式問題ではありません。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }
                }
                ForEach(sets) { set in
                    let available = purchase.unlocked || Set(set.questionIDs).isSubset(of: Set(catalog.qualification.freeQuestionIDs))
                    if available {
                        NavigationLink(value: QuestionCollectionRoute.mockSet(set.id)) { card(set) }
                            .accessibilityIdentifier("electricalSet-\(set.id)")
                    } else {
                        Button(action: paywall) { card(set) }
                    }
                }
                Surface {
                    Text("\(subject)の模試").font(.headline)
                    Text(subject == "法規" ? "16解答欄・65分。6点・7点の配点で、100点満点として採点します。" :
                         "20解答欄・90分。各5点、100点満点で採点します。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    if ["理論", "機械"].contains(subject) {
                        Text("問17と問18は、模試の開始前に一方を選びます。通常の練習では両方を学べます。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }
                    DisclosureGroup("収録範囲と出典") {
                        Text(catalog.qualification.examNote).font(.subheadline).foregroundStyle(Palette.muted)
                        Link("公式の過去問・正答表", destination: URL(string: "https://www.shiken.or.jp/chief/third/qa/")!)
                            .frame(minHeight: 44)
                        Link("公式の試験概要", destination: URL(string: "https://www.shiken.or.jp/chief/third/overview/")!)
                            .frame(minHeight: 44)
                    }
                }
            }
            .buttonStyle(StudyButtonStyle())
            .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("科目", selection: $subject) {
                ForEach(catalog.qualification.subjects, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented).accessibilityIdentifier("electricalSubjectPicker")
            .padding(.horizontal, 20).padding(.vertical, 12).background(.bar)
        }
        .background(Palette.background)
        .navigationTitle(year.formatted(.number.grouping(.never)) + (hasPredictions ? "年実施向け予想" : "年度"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ set: MockSet) -> some View {
        Surface {
            HStack(spacing: 12) {
                Image(systemName: set.kind == .prediction ? "square.stack" : "doc.text").font(.title2).foregroundStyle(Palette.positive).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(set.title).font(.headline).foregroundStyle(Palette.ink)
                    Text("\(set.questionCount)解答欄を収録 · \(set.minutes)分")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Text("学習済み \(set.questionIDs.filter { store.data.mastery[$0] != nil }.count) / \(set.questionCount)")
                        .font(.caption).foregroundStyle(Palette.positive)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
            }
        }.accessibilityElement(children: .combine)
    }
}
