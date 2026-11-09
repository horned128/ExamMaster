import Foundation

/// 教科書: books of chapters whose sections are written in ContentBlocks, read from textbook.json.
/// The 全体図 lives in layermap.json and answers the chapter ID `overview`.
struct Textbook: Codable {
    let version: Int
    let books: [TextbookBook]

    static let main: Textbook? = load()

    static func load(bundle: Bundle = .main) -> Textbook? {
        guard let url = bundle.url(forResource: "textbook", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Textbook.self, from: data)
    }

    var chapters: [TextbookChapter] { books.flatMap(\.chapters) }

    func chapter(id: String) -> TextbookChapter? { chapters.first { $0.id == id } }

    func book(containing chapterID: String) -> TextbookBook? {
        books.first { $0.chapters.contains { $0.id == chapterID } }
    }

    /// Whether a link target exists, in this book or in the 全体図.
    func resolves(_ location: TextbookLocation, map: LayerMap?) -> Bool {
        if location.chapter == LayerMap.chapterID {
            guard let map else { return false }
            return location.section.map(map.resolves) ?? true
        }
        guard let chapter = chapter(id: location.chapter) else { return false }
        return location.section.map { chapter.section(anchor: $0) != nil } ?? true
    }

    var isValid: Bool {
        let ids = chapters.map(\.id)
        return !books.isEmpty && Set(ids).count == ids.count && ids.allSatisfy { $0 != LayerMap.chapterID } &&
            books.allSatisfy { !$0.title.isBlank && !$0.chapters.isEmpty } && chapters.allSatisfy(\.isValid)
    }
}

struct TextbookBook: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    /// One line under the title in the book list.
    let summary: String
    var symbol: String? = nil
    /// Shown above the chapter list, e.g. how to read the book.
    var intro: [ContentBlock]? = nil
    let chapters: [TextbookChapter]
}

struct TextbookChapter: Codable, Identifiable, Hashable {
    let id: String
    /// 「第1章」「①」; nil when the title stands alone.
    var number: String? = nil
    let title: String
    /// Text before the first section.
    var blocks: [ContentBlock]? = nil
    let sections: [TextbookSection]

    var displayTitle: String { number.map { "\($0)　\(title)" } ?? title }

    func section(anchor: String) -> TextbookSection? {
        sections.first { $0.id == anchor || ($0.anchors ?? []).contains(anchor) }
    }

    var allBlocks: [ContentBlock] { (blocks ?? []) + sections.flatMap(\.blocks) }

    var isValid: Bool {
        let anchors = sections.flatMap { [$0.id] + ($0.anchors ?? []) }
        return !id.isBlank && !title.isBlank && (!sections.isEmpty || !(blocks ?? []).isEmpty) &&
            Set(anchors).count == anchors.count && allBlocks.allSatisfy(\.isValid) &&
            sections.allSatisfy { !$0.title.isBlank && !$0.blocks.isEmpty }
    }
}

struct TextbookSection: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    /// Other link anchors inside the section, such as a sub-heading.
    var anchors: [String]? = nil
    let blocks: [ContentBlock]
}

/// 全体図: the layers of an embedded system as rows, terms as chips on them, and journeys that walk
/// the rows step by step. Generic enough for other stacks such as the OSI layers.
struct LayerMap: Codable {
    static let chapterID = "overview"

    let version: Int
    let title: String
    let summary: String
    var intro: [ContentBlock]? = nil
    let zones: [Zone]
    let rows: [Row]
    let chips: [Chip]
    let journeys: [Journey]

    struct Zone: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        let rows: [String]
        let colorHex: String
    }

    struct Row: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        var short: String? = nil
        /// What happens in this layer, one line.
        let example: String
        /// Topics that run across every layer (testing, security, safety…).
        var crossCutting: Bool? = nil
        let colorHex: String
    }

    struct Chip: Codable, Identifiable, Hashable {
        let id: String
        let term: String
        let row: String
        let description: String
        /// How the exam asks about it.
        var exam: String? = nil
        var questionIDs: [String]? = nil
        /// `exammaster://textbook/…` for a deeper explanation.
        var textbook: String? = nil
    }

    struct Journey: Codable, Identifiable, Hashable {
        let id: String
        let title: String
        let intro: String
        let steps: [Step]
        /// 物理的には: what happens electrically, with timing charts.
        var physical: [ContentBlock]? = nil

        var anchor: String { "j-" + id }
    }

    struct Step: Codable, Hashable {
        let row: String
        let title: String
        let text: String
        var chipIDs: [String]? = nil
    }

    static let main: LayerMap? = load()

    static func load(bundle: Bundle = .main) -> LayerMap? {
        guard let url = bundle.url(forResource: "layermap", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LayerMap.self, from: data)
    }

    func row(_ id: String) -> Row? { rows.first { $0.id == id } }
    func chip(_ id: String) -> Chip? { chips.first { $0.id == id } }
    func chips(in row: String) -> [Chip] { chips.filter { $0.row == row } }
    func journey(anchor: String) -> Journey? { journeys.first { $0.anchor == anchor } }
    func resolves(_ anchor: String) -> Bool { chip(anchor) != nil || journey(anchor: anchor) != nil }

    var isValid: Bool {
        let rowIDs = Set(rows.map(\.id))
        let chipIDs = chips.map(\.id)
        let colors = rows.map(\.colorHex) + zones.map(\.colorHex)
        return !rows.isEmpty && rowIDs.count == rows.count && Set(chipIDs).count == chipIDs.count &&
            colors.allSatisfy(QualificationTheme.validHex) &&
            zones.allSatisfy { $0.rows.allSatisfy(rowIDs.contains) } &&
            chips.allSatisfy { rowIDs.contains($0.row) && !$0.term.isBlank && !$0.description.isBlank } &&
            journeys.allSatisfy { journey in
                !journey.steps.isEmpty && (journey.physical ?? []).allSatisfy(\.isValid) &&
                    journey.steps.allSatisfy { step in
                        rowIDs.contains(step.row) && (step.chipIDs ?? []).allSatisfy { chip($0) != nil }
                    }
            }
    }
}

/// One hit of the 教科書 tab's search, which covers questions, glossary terms and the textbook.
enum StudySearchResult: Identifiable, Hashable {
    case question(Question)
    case term(GlossaryTerm)
    case section(chapter: TextbookChapter, section: TextbookSection?)
    case chip(LayerMap.Chip)

    var id: String {
        switch self {
        case .question(let q): "q:" + q.id
        case .term(let t): "t:" + t.id
        case .section(let chapter, let section): "s:" + chapter.id + "#" + (section?.id ?? "")
        case .chip(let chip): "c:" + chip.id
        }
    }
}

enum StudySearch {
    /// Every word must appear; case and width differences are ignored.
    static func matches(_ text: String, words: [String]) -> Bool {
        let haystack = normalize(text)
        return words.allSatisfy { haystack.contains($0) }
    }

    static func words(_ query: String) -> [String] {
        normalize(query).split(whereSeparator: { $0 == " " || $0 == "　" }).map(String.init)
    }

    static func normalize(_ text: String) -> String {
        (text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text).lowercased()
    }

    static func run(_ query: String, questions: [Question], glossary: Glossary?, textbook: Textbook?,
                    map: LayerMap?, limit: Int = 30) -> (questions: [StudySearchResult], terms: [StudySearchResult], textbook: [StudySearchResult]) {
        let words = words(query)
        guard !words.isEmpty else { return ([], [], []) }
        let questionHits = questions.lazy
            .filter { matches($0.searchText + " " + ($0.choiceExplanations ?? []).joined(separator: " "), words: words) }
            .prefix(limit).map(StudySearchResult.question)
        let termHits = (glossary?.terms ?? []).lazy
            .filter { matches(([$0.term, $0.english ?? "", $0.description] + $0.keys).joined(separator: " "), words: words) }
            .prefix(limit).map(StudySearchResult.term)
        var textbookHits: [StudySearchResult] = []
        for chapter in textbook?.chapters ?? [] {
            if matches(chapter.title + " " + (chapter.blocks ?? []).map(\.searchText).joined(separator: " "), words: words) {
                textbookHits.append(.section(chapter: chapter, section: nil))
            }
            for section in chapter.sections
            where matches(section.title + " " + section.blocks.map(\.searchText).joined(separator: " "), words: words) {
                textbookHits.append(.section(chapter: chapter, section: section))
            }
        }
        for chip in map?.chips ?? [] where matches([chip.term, chip.description, chip.exam ?? ""].joined(separator: " "), words: words) {
            textbookHits.append(.chip(chip))
        }
        return (Array(questionHits), Array(termHits), Array(textbookHits.prefix(limit)))
    }
}
