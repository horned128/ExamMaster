import SwiftUI

/// Both public excerpts and full original mocks may share a year.
struct FundamentalSetLibraryView: View {
    let year: Int
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let paywall: () -> Void
    @State private var selectedSubject = "科目A"

    private func sets(subject: String, kind: QuestionKind) -> [MockSet] {
        let ids = Set(catalog.questions.filter { $0.year == year && $0.subject == subject }.compactMap(\.mockSetID))
        return catalog.mockSets.filter { ids.contains($0.id) && $0.kind == kind }.sorted { $0.id < $1.id }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Surface {
                    Text("科目ごとに取り組む").font(.headline)
                    Text("科目Aは60問・90分、科目Bは20問・100分。公開問題は抜粋なので、短い時間の演習として収録しています。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Text("正答率60%を練習の目安にします。本試験はIRT評価で各科目600点以上が必要です。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                ForEach([selectedSubject], id: \.self) { subject in
                    ForEach([QuestionKind.past, .original], id: \.self) { kind in
                        let items = sets(subject: subject, kind: kind)
                        if !items.isEmpty {
                            Text("\(subject) · \(kind == .past ? "公開過去問" : "オリジナル模試")")
                                .font(.title3.bold()).padding(.top, 8).accessibilityAddTraits(.isHeader)
                            ForEach(items) { set in
                                let free = Set(set.questionIDs).isSubset(of: Set(catalog.qualification.freeQuestionIDs))
                                if purchase.unlocked || free {
                                    NavigationLink(value: QuestionCollectionRoute.mockSet(set.id)) {
                                        card(set, locked: false)
                                    }.accessibilityIdentifier("examSet-\(set.id)")
                                } else {
                                    Button(action: paywall) { card(set, locked: true) }
                                        .accessibilityIdentifier("examSet-\(set.id)")
                                }
                            }
                        }
                    }
                }
            }
            .buttonStyle(StudyButtonStyle())
            .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("科目", selection: $selectedSubject) {
                ForEach(catalog.qualification.subjects, id: \.self) { subject in
                    Text(subject).tag(subject)
                }
            }
            .pickerStyle(.segmented).accessibilityIdentifier("examSubjectPicker")
            .padding(.horizontal, 20).padding(.vertical, 12).background(.bar)
        }
        .background(Palette.background)
        .navigationTitle("\(year.formatted(.number.grouping(.never)))年度")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ set: MockSet, locked: Bool) -> some View {
        Surface {
            HStack(spacing: 12) {
                Image(systemName: set.kind == .past ? "doc.text" : "timer")
                    .font(.title2).foregroundStyle(Palette.positive).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(set.title).font(.headline).foregroundStyle(Palette.ink)
                    Text("\(set.questionCount)問 · \(set.minutes)分").font(.subheadline).foregroundStyle(Palette.muted)
                    Text(locked ? "購入で解放" : "学習済み \(set.questionIDs.filter { store.data.mastery[$0] != nil }.count)問")
                        .font(.caption).foregroundStyle(locked ? Palette.review : Palette.positive)
                }
                Spacer(minLength: 0)
                Image(systemName: locked ? "lock.fill" : "chevron.right").foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
