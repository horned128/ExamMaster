import SwiftUI

/// Separate papers, times and elective questions for the four electrical subjects.
struct ElectricalSetLibraryView: View {
    let year: Int
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let paywall: () -> Void
    @State private var subject = "理論"
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var sets: [MockSet] {
        let ids = Set(catalog.questions.filter { $0.year == year && $0.subject == subject }.compactMap(\.mockSetID))
        return catalog.mockSets.filter { ids.contains($0.id) }.sorted { $0.id > $1.id }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Surface {
                    Label("4科目を、ひとつずつ。", systemImage: "bolt.circle").font(.headline)
                    Text("理論・電力・機械は90分、法規は65分。各科目100点満点で採点します。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Text("理論・機械の問17と問18は、模試の開始前に一方を選びます。通常の練習では両方を学べます。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
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
                    Text("収録範囲と出典").font(.headline)
                    Text(catalog.qualification.examNote).font(.subheadline).foregroundStyle(Palette.muted)
                    Link("公式の過去問・正答表", destination: URL(string: "https://www.shiken.or.jp/chief/third/qa/")!)
                        .frame(minHeight: 44)
                    Link("公式の試験概要", destination: URL(string: "https://www.shiken.or.jp/chief/third/overview/")!)
                        .frame(minHeight: 44)
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
        .navigationTitle("\(year.formatted(.number.grouping(.never)))年度")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ set: MockSet) -> some View {
        Surface {
            HStack(spacing: 12) {
                Image(systemName: "doc.text").font(.title2).foregroundStyle(Palette.positive).accessibilityHidden(true)
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
