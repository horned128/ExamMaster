import SwiftUI

struct LibraryView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let start: (StudySession) -> Void
    let settings: () -> Void

    private var years: [Int] { Array(Set(catalog.questions.map(\.year))).sorted(by: >) }
    private var categories: [String] { Array(Set(catalog.questions.map(\.category))).sorted() }

    var body: some View {
        List {
            Section {
                NavigationLink(value: QuestionCollectionRoute.all) {
                    Label("問題を検索", systemImage: "magnifyingglass")
                }
            }
            Section("学習モード") {
                Button {
                    start(SessionPlanner.mock(catalog, unlocked: purchase.unlocked))
                } label: {
                    Label("模擬試験 · \(catalog.qualification.examMinutes)分", systemImage: "timer")
                }
                NavigationLink(value: QuestionCollectionRoute.incorrect) {
                    Label("間違えた問題", systemImage: "arrow.uturn.backward")
                }
                NavigationLink(value: QuestionCollectionRoute.favorites) {
                    Label("お気に入り", systemImage: "bookmark")
                }
                NavigationLink(value: QuestionCollectionRoute.contrast) {
                    Label("似た問題を比べる", systemImage: "square.on.square")
                }
            }
            Section("年度から選ぶ") {
                ForEach(years, id: \.self) { year in
                    NavigationLink(value: QuestionCollectionRoute.year(year)) {
                        HStack {
                            Text(year.formatted(.number.grouping(.never)) + "年")
                            Spacer()
                            Text("\(catalog.questions.filter { $0.year == year }.count)問")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("分野から選ぶ") {
                ForEach(catalog.qualification.subjects, id: \.self) { subject in
                    NavigationLink(value: QuestionCollectionRoute.subject(subject)) {
                        HStack {
                            Text(subject)
                            Spacer()
                            Text("\(catalog.questions.filter { $0.subject == subject }.count)問")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("カテゴリから選ぶ") {
                ForEach(categories, id: \.self) { category in
                    NavigationLink(value: QuestionCollectionRoute.category(category)) {
                        HStack {
                            Text(category)
                            Spacer()
                            Text("\(catalog.questions.filter { $0.category == category }.count)問")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !purchase.unlocked && !purchase.purchasing && ads.canShowBanner {
                Section { AdBannerPlacement(ads: ads) }
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("問題を探す")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: settings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("設定")
            }
        }
    }
}
