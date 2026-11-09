import SwiftUI

/// Where a textbook link leads inside the app.
enum TextbookRoute: Hashable, Identifiable {
    case book(String)
    case chapter(String, section: String?)
    case map
    case chip(String)
    case journey(String)
    case glossary
    case term(String)

    var id: Self { self }

    /// `exammaster://textbook/<chapter>#<section>`; nil when this app has no such page.
    init?(url: URL, textbook: Textbook? = .main, map: LayerMap? = .main) {
        guard let location = TextbookLocation(url: url) else { return nil }
        if location.chapter == LayerMap.chapterID {
            guard let map else { return nil }
            if let anchor = location.section, map.chip(anchor) != nil {
                self = .chip(anchor)
            } else if let anchor = location.section, let journey = map.journey(anchor: anchor) {
                self = .journey(journey.id)
            } else {
                self = .map
            }
        } else {
            guard textbook?.chapter(id: location.chapter) != nil else { return nil }
            self = .chapter(location.chapter, section: location.section)
        }
    }
}

/// What textbook pages need from the app around them.
@MainActor
struct TextbookContext {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    /// Opens one question in a sheet. nil inside a running session, which cannot start another.
    let start: ((StudySession) -> Void)?
    let backlinks: TextbookBacklinks

    var canSolve: Bool { start != nil }

    func isLocked(_ question: Question) -> Bool {
        !purchase.unlocked && !catalog.qualification.freeQuestionIDs.contains(question.id)
    }

    func solve(_ question: Question) {
        start?(StudySession(title: "問題を確認", mode: .search, questions: [question], timed: false))
    }

    func questions(ids: [String]) -> [Question] {
        let byID = Dictionary(catalog.questions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }
}

/// Questions whose explanations link to a textbook page, so the page can list them as 関連問題.
struct TextbookBacklinks {
    /// Keyed by `chapter#section`, plus `chapter` for links without a section.
    private(set) var questionIDs: [String: [String]] = [:]

    init(questions: [Question], textbook: Textbook? = .main, map: LayerMap? = .main) {
        guard textbook != nil || map != nil else { return }
        // Swift 5 language mode has no bare regex literals.
        let pattern = try! Regex(#"exammaster://textbook/[A-Za-z0-9_\-]+(#[A-Za-z0-9_\-]+)?"#)
        for question in questions {
            let texts = question.allBlocks.flatMap { [$0.text, $0.answer] }.compactMap { $0 } +
                (question.choiceExplanations ?? []) + (question.references ?? []).compactMap(\.url)
            var keys: [String] = []
            for text in texts {
                for match in text.matches(of: pattern) {
                    guard let url = URL(string: String(text[match.range])), let location = TextbookLocation(url: url) else { continue }
                    let key = Self.key(location, textbook: textbook)
                    if !keys.contains(key) { keys.append(key) }
                }
            }
            for key in keys { questionIDs[key, default: []].append(question.id) }
        }
    }

    static func key(_ location: TextbookLocation, textbook: Textbook?) -> String {
        guard let anchor = location.section else { return location.chapter }
        let section = textbook?.chapter(id: location.chapter)?.section(anchor: anchor)?.id ?? anchor
        return location.chapter + "#" + section
    }

    func ids(chapter: String, section: String) -> [String] { questionIDs[chapter + "#" + section] ?? [] }
}

/// A navigation stack for textbook pages; links inside push onto it.
struct TextbookStack: View {
    let context: TextbookContext
    var root: TextbookRoute? = nil
    var close: (() -> Void)? = nil
    @State private var path: [TextbookRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let root {
                    TextbookDestination(route: root, context: context)
                } else {
                    TextbookHomeView(context: context)
                }
            }
            .toolbar {
                if let close {
                    ToolbarItem(placement: .topBarTrailing) { Button("閉じる", action: close) }
                }
            }
            .navigationDestination(for: TextbookRoute.self) { route in
                TextbookDestination(route: route, context: context)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard let route = TextbookRoute(url: url) else { return .systemAction }
            path.append(route)
            return .handled
        })
    }
}

extension View {
    /// Textbook links open in a sheet over the current screen, so practice is not interrupted.
    func textbookLinks(_ context: TextbookContext) -> some View { modifier(TextbookLinkSheet(context: context)) }
}

private struct TextbookLinkSheet: ViewModifier {
    let context: TextbookContext
    @State private var route: TextbookRoute?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let target = TextbookRoute(url: url) else { return .systemAction }
                route = target
                return .handled
            })
            .sheet(item: $route) { target in
                TextbookStack(context: context, root: target, close: { route = nil })
                    .tint(Palette.linkAccent(context.catalog.qualification.accentHex))
            }
    }
}

struct TextbookDestination: View {
    let route: TextbookRoute
    let context: TextbookContext

    var body: some View {
        switch route {
        case .book(let id):
            if let book = Textbook.main?.books.first(where: { $0.id == id }) {
                TextbookBookView(book: book)
            } else { missing }
        case .chapter(let id, let section):
            if let textbook = Textbook.main, let chapter = textbook.chapter(id: id) {
                TextbookChapterView(chapter: chapter, book: textbook.book(containing: id), anchor: section, context: context)
            } else { missing }
        case .map:
            if let map = LayerMap.main { LayerMapView(map: map) } else { missing }
        case .chip(let id):
            if let map = LayerMap.main, let chip = map.chip(id) { LayerChipView(map: map, chip: chip, context: context) } else { missing }
        case .journey(let id):
            if let map = LayerMap.main, let journey = map.journeys.first(where: { $0.id == id }) {
                LayerJourneyView(map: map, journey: journey)
            } else { missing }
        case .glossary:
            if let glossary = Glossary.main { GlossaryListView(glossary: glossary) } else { missing }
        case .term(let id):
            if let term = Glossary.main?.terms.first(where: { $0.id == id }) {
                GlossaryTermView(term: term, context: context)
            } else { missing }
        }
    }

    private var missing: some View {
        ContentUnavailableView("ページが見つかりません", systemImage: "book.closed")
    }
}

// MARK: - 教科書タブ

struct TextbookHomeView: View {
    let context: TextbookContext
    @State private var query = ""
    @State private var results: (questions: [StudySearchResult], terms: [StudySearchResult], textbook: [StudySearchResult]) = ([], [], [])

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if query.isBlank {
                    shelf
                } else {
                    TextbookSearchResultsView(results: results, context: context)
                }
            }
            .padding(20)
            .readingWidth()
        }
        .background(Palette.background)
        .navigationTitle("教科書")
        .searchable(text: $query, prompt: "問題・用語・教科書を検索")
        .task(id: query) {
            guard !query.isBlank else { return }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            results = StudySearch.run(query, questions: context.catalog.questions, glossary: Glossary.main,
                                      textbook: Textbook.main, map: LayerMap.main)
        }
    }

    @ViewBuilder private var shelf: some View {
        if let map = LayerMap.main {
            NavigationLink(value: TextbookRoute.map) {
                FeatureCard(title: map.title, symbol: "square.stack.3d.up", detail: map.summary, color: Palette.sky)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("textbookShelf-overview")
        }
        ForEach(Textbook.main?.books ?? []) { book in
            NavigationLink(value: TextbookRoute.book(book.id)) {
                FeatureCard(title: book.title, symbol: book.symbol ?? "book", detail: book.summary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("textbookShelf-\(book.id)")
        }
        if let glossary = Glossary.main {
            NavigationLink(value: TextbookRoute.glossary) {
                FeatureCard(title: "用語集", symbol: "character.book.closed", detail: "\(glossary.terms.count)語",
                            color: Palette.review)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("textbookShelf-glossary")
        }
    }
}

struct TextbookSearchResultsView: View {
    let results: (questions: [StudySearchResult], terms: [StudySearchResult], textbook: [StudySearchResult])
    let context: TextbookContext

    var body: some View {
        if results.questions.isEmpty && results.terms.isEmpty && results.textbook.isEmpty {
            ContentUnavailableView.search
        }
        if !results.textbook.isEmpty {
            group("教科書") {
                ForEach(results.textbook) { result in
                    switch result {
                    case .section(let chapter, let section):
                        NavigationLink(value: TextbookRoute.chapter(chapter.id, section: section?.id)) {
                            resultRow(section?.title ?? chapter.displayTitle, detail: section == nil ? nil : chapter.displayTitle, symbol: "book")
                        }
                    case .chip(let chip):
                        NavigationLink(value: TextbookRoute.chip(chip.id)) {
                            resultRow(chip.term, detail: "全体図", symbol: "square.stack.3d.up")
                        }
                    default: EmptyView()
                    }
                }
            }
        }
        if !results.terms.isEmpty {
            group("用語") {
                ForEach(results.terms) { result in
                    if case .term(let term) = result {
                        NavigationLink(value: TextbookRoute.term(term.id)) {
                            resultRow(term.term, detail: term.english, symbol: "character.book.closed")
                        }
                    }
                }
            }
        }
        if !results.questions.isEmpty && context.canSolve {
            group("問題") {
                RelatedQuestionList(questions: results.questions.compactMap {
                    if case .question(let q) = $0 { return q } else { return nil }
                }, context: context, showsTitle: false)
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).textRole(.heading).padding(.top, 8)
            content()
        }
    }

    private func resultRow(_ title: String, detail: String?, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Palette.muted).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                if let detail { Text(detail).textRole(.note).foregroundStyle(Palette.muted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.muted).accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - 本・章

struct TextbookBookView: View {
    let book: TextbookBook

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let intro = book.intro {
                    RichContentView(blocks: intro, definitionTables: true).textRole(.body)
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(book.chapters) { chapter in
                        NavigationLink(value: TextbookRoute.chapter(chapter.id, section: nil)) {
                            HStack(alignment: .top, spacing: 12) {
                                if let number = chapter.number {
                                    Text(number).font(.subheadline.bold()).fontDesign(.rounded)
                                        .foregroundStyle(Palette.muted).frame(minWidth: 44, alignment: .leading)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(chapter.title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                                    if !chapter.sections.isEmpty {
                                        Text(chapter.sections.map(\.title).joined(separator: "／"))
                                            .textRole(.note).foregroundStyle(Palette.muted).lineLimit(2)
                                    }
                                }
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.muted)
                                    .accessibilityHidden(true)
                            }
                            .padding(14)
                            .popCard(radius: 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("textbookChapter-\(chapter.id)")
                    }
                }
            }
            .padding(20)
            .readingWidth()
        }
        .background(Palette.background)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TextbookChapterView: View {
    let chapter: TextbookChapter
    let book: TextbookBook?
    let anchor: String?
    let context: TextbookContext

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let number = chapter.number {
                            Text(number).font(.subheadline.bold()).fontDesign(.rounded).foregroundStyle(Palette.muted)
                        }
                        Text(chapter.title).font(.title2.bold()).fontDesign(.rounded)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let blocks = chapter.blocks {
                        RichContentView(blocks: blocks, definitionTables: true).textRole(.body)
                    }
                    ForEach(chapter.sections) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(section.title).font(.title3.bold()).fontDesign(.rounded)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                                .accessibilityAddTraits(.isHeader)
                            RichContentView(blocks: section.blocks, definitionTables: true).textRole(.body)
                            let related = context.questions(ids: context.backlinks.ids(chapter: chapter.id, section: section.id))
                            if !related.isEmpty && context.canSolve {
                                RelatedQuestionList(questions: related, context: context)
                            }
                        }
                        .id(section.id)
                    }
                    neighbours
                }
                .padding(20)
                .readingWidth()
            }
            .background(Palette.background)
            .navigationTitle(book?.title ?? chapter.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if chapter.sections.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(chapter.sections) { section in
                                Button(section.title) { withAnimation { proxy.scrollTo(section.id, anchor: .top) } }
                            }
                        } label: {
                            Label("目次", systemImage: "list.bullet")
                        }
                        .accessibilityIdentifier("chapterContents")
                    }
                }
            }
            .task {
                guard let anchor, let section = chapter.section(anchor: anchor) else { return }
                try? await Task.sleep(for: .milliseconds(150))
                proxy.scrollTo(section.id, anchor: .top)
            }
        }
    }

    @ViewBuilder private var neighbours: some View {
        if let book, let index = book.chapters.firstIndex(where: { $0.id == chapter.id }) {
            HStack(spacing: 12) {
                if index > 0 {
                    let previous = book.chapters[index - 1]
                    NavigationLink(value: TextbookRoute.chapter(previous.id, section: nil)) {
                        Label(previous.number ?? "前の章", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                if index + 1 < book.chapters.count {
                    let next = book.chapters[index + 1]
                    NavigationLink(value: TextbookRoute.chapter(next.id, section: nil)) {
                        HStack { Text(next.number ?? "次の章"); Image(systemName: "chevron.right") }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityIdentifier("nextChapter")
                }
            }
            .buttonStyle(.bordered)
            .padding(.top, 12)
        }
    }
}

/// 関連問題: each opens a one-question sheet whose answer counts toward history and mastery.
struct RelatedQuestionList: View {
    let questions: [Question]
    let context: TextbookContext
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsTitle {
                Label("関連問題", systemImage: "checklist").textRole(.heading)
            }
            ForEach(questions) { question in
                Button { context.solve(question) } label: { row(question) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("relatedQuestion-\(question.id)")
            }
        }
    }

    private func row(_ question: Question) -> some View {
        let state = context.store.data.mastery[question.id]
        let locked = context.isLocked(question)
        return HStack(spacing: 12) {
            Group {
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(Palette.muted)
                } else if let state {
                    Image(systemName: state.lastCorrect ? "circle" : "xmark")
                        .foregroundStyle(state.lastCorrect ? Palette.correct : Palette.oops)
                } else {
                    Image(systemName: "minus").foregroundStyle(Palette.muted)
                }
            }
            .font(.body.weight(.bold)).frame(width: 24)
            .accessibilityLabel(locked ? "ロック中" : state.map { $0.lastCorrect ? "前回正解" : "前回不正解" } ?? "未回答")
            VStack(alignment: .leading, spacing: 2) {
                Text(context.catalog.qualification.displaySource(question.source)).textRole(.note).foregroundStyle(Palette.muted)
                Text(question.stem).foregroundStyle(Palette.ink).lineLimit(2).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(Palette.positive).accessibilityHidden(true)
        }
        .padding(12)
        .popCard(radius: 14)
        .contentShape(Rectangle())
    }
}

// MARK: - 用語集

struct GlossaryListView: View {
    let glossary: Glossary
    @State private var query = ""

    private var sorted: [GlossaryTerm] {
        glossary.terms.sorted { $0.term.localizedStandardCompare($1.term) == .orderedAscending }
    }
    private var shown: [GlossaryTerm] {
        let words = StudySearch.words(query)
        guard !words.isEmpty else { return sorted }
        return sorted.filter { StudySearch.matches(([$0.term, $0.english ?? ""] + $0.keys).joined(separator: " "), words: words) }
    }

    var body: some View {
        List(shown) { term in
            NavigationLink(value: TextbookRoute.term(term.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(term.term).foregroundStyle(Palette.ink)
                    if let english = term.english, !english.isEmpty {
                        Text(english).textRole(.note).foregroundStyle(Palette.muted)
                    }
                }
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .overlay { if shown.isEmpty { ContentUnavailableView.search } }
        .navigationTitle("用語集")
        .searchable(text: $query, prompt: "用語を検索")
        .accessibilityIdentifier("glossaryList")
    }
}

struct GlossaryTermView: View {
    let term: GlossaryTerm
    let context: TextbookContext

    var body: some View {
        let related = context.catalog.questions.filter { $0.glossaryTermIDs?.contains(term.id) == true }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(term.term).font(.title2.bold()).fontDesign(.rounded)
                    if let english = term.english, !english.isEmpty {
                        Text(english).textRole(.reason).foregroundStyle(Palette.muted)
                    }
                }
                MarkupText(text: term.description, role: .body, setsFont: true)
                if !related.isEmpty && context.canSolve {
                    RelatedQuestionList(questions: Array(related.prefix(10)), context: context)
                }
            }
            .padding(20)
            .readingWidth()
        }
        .background(Palette.background)
        .navigationTitle(term.term)
        .navigationBarTitleDisplayMode(.inline)
    }
}
