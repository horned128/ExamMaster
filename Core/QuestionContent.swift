import Foundation

enum QuestionKind: String, Codable {
    case past, prediction, original
    var title: String {
        switch self {
        case .past: "公式過去問"
        case .prediction: "予想問題"
        case .original: "オリジナル"
        }
    }
    /// Official exam questions, as opposed to app-written predictions and originals.
    var isOfficial: Bool { self == .past }
}

/// A source the explanation relies on, shown as 参考資料.
struct QuestionReference: Codable, Hashable {
    let title: String
    var url: String? = nil

    var isValid: Bool {
        !title.isBlank && (url.map { URL(string: $0).map(ContentLink.isAllowed) ?? false } ?? true)
    }
}

/// Links that content may carry: web pages and in-app textbook sections.
enum ContentLink {
    static let scheme = "exammaster"

    static func isAllowed(_ url: URL) -> Bool {
        url.scheme == "https" || TextbookLocation(url: url) != nil
    }
}

/// `exammaster://textbook/<chapter>#<section>`
struct TextbookLocation: Hashable {
    let chapter: String
    let section: String?

    init?(url: URL) {
        guard url.scheme == ContentLink.scheme, url.host == "textbook" else { return nil }
        let chapter = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !chapter.isEmpty, !chapter.contains("/") else { return nil }
        self.chapter = chapter
        section = url.fragment.flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// The small markup subset text blocks accept: `**bold**`, `[label](url)`, `==mark==`
/// (a confusable word shown in red) and lines starting with `- ` as bullets.
/// Single `*` and `_` stay literal so code and formulas in existing data are not reinterpreted.
enum InlineMarkup {
    struct Run: Equatable {
        var text: String
        var bold = false
        var marked = false
        var link: URL? = nil
    }
    enum Line: Equatable {
        case paragraph([Run])
        case bullet([Run])
        var runs: [Run] {
            switch self { case .paragraph(let runs), .bullet(let runs): runs }
        }
    }

    /// Consecutive plain lines stay in one paragraph so authored line breaks are kept.
    static func parse(_ text: String) -> [Line] {
        var lines: [Line] = []
        var paragraph: [String] = []
        func flush() {
            guard !paragraph.isEmpty else { return }
            lines.append(.paragraph(runs(paragraph.joined(separator: "\n"))))
            paragraph = []
        }
        for raw in text.components(separatedBy: "\n") {
            if raw.hasPrefix("- ") {
                flush()
                lines.append(.bullet(runs(String(raw.dropFirst(2)))))
            } else {
                paragraph.append(raw)
            }
        }
        flush()
        return lines
    }

    /// Text with the markup removed, for search and accessibility.
    static func plainText(_ text: String) -> String {
        parse(text).map { line in
            let body = line.runs.map(\.text).joined()
            if case .bullet = line { return "・" + body }
            return body
        }.joined(separator: "\n")
    }

    static func runs(_ text: String) -> [Run] {
        var result: [Run] = []
        var bold = false
        var marked = false
        var buffer = ""
        var index = text.startIndex
        func emit(link: URL? = nil, override: String? = nil) {
            let value = override ?? buffer
            guard !value.isEmpty else { return }
            if link == nil, let last = result.last, last.link == nil, last.bold == bold, last.marked == marked {
                result[result.count - 1].text += value
            } else {
                result.append(Run(text: value, bold: bold, marked: marked, link: link))
            }
            if override == nil { buffer = "" }
        }
        while index < text.endIndex {
            let rest = text[index...]
            if rest.hasPrefix("**"), bold || rest.dropFirst(2).contains("**") {
                emit(); bold.toggle()
                index = text.index(index, offsetBy: 2)
            } else if rest.hasPrefix("=="), marked || rest.dropFirst(2).contains("==") {
                emit(); marked.toggle()
                index = text.index(index, offsetBy: 2)
            } else if rest.hasPrefix("["), let link = linkMatch(rest) {
                emit()
                emit(link: link.url, override: link.label)
                index = link.end
            } else {
                buffer.append(text[index])
                index = text.index(after: index)
            }
        }
        emit()
        return result
    }

    private static func linkMatch(_ text: Substring) -> (label: String, url: URL, end: String.Index)? {
        guard let close = text.firstIndex(of: "]"),
              text.index(after: close) < text.endIndex, text[text.index(after: close)] == "(",
              let end = text[close...].firstIndex(of: ")") else { return nil }
        let label = String(text[text.index(after: text.startIndex)..<close])
        let target = String(text[text.index(close, offsetBy: 2)..<end])
        guard !label.isEmpty, !label.contains("\n"), let url = URL(string: target), ContentLink.isAllowed(url) else { return nil }
        return (label, url, text.index(after: end))
    }
}

/// Ordered blocks preserve the relationship between prose, diagrams and tables.
struct ContentBlock: Codable, Hashable {
    enum Kind: String, Codable { case text, image, table, monospace, formula }
    let type: Kind
    var text: String? = nil
    var assetName: String? = nil
    var altText: String? = nil
    var caption: String? = nil
    var headers: [String]? = nil
    var rows: [[String]]? = nil

    var searchText: String {
        ([text.map(InlineMarkup.plainText), altText, caption].compactMap { $0 } + (headers ?? []) + (rows ?? []).flatMap { $0 }).joined(separator: " ")
    }
    var isValid: Bool {
        switch type {
        case .text, .monospace, .formula: return text.map { !$0.isBlank } ?? false
        case .image:
            return (assetName.map { !$0.isBlank && !$0.contains("/") && !$0.contains("..") } ?? false) &&
                (altText.map { !$0.isBlank } ?? false)
        case .table:
            guard let headers, let rows, !headers.isEmpty, !rows.isEmpty else { return false }
            return headers.allSatisfy { !$0.isBlank } && rows.allSatisfy { $0.count == headers.count }
        }
    }
}

enum ContentAsset {
    static func url(name: String, bundle: Bundle = .main) -> URL? {
        guard !name.contains("/"), !name.contains("..") else { return nil }
        let path = name as NSString
        return bundle.url(forResource: path.deletingPathExtension, withExtension: path.pathExtension, subdirectory: "Figures")
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

extension Question {
    var allBlocks: [ContentBlock] {
        (bodyBlocks ?? []) + (choiceBlocks ?? []).flatMap { $0 } + (explanationBlocks ?? []) + (related ?? [])
    }
    var validContent: Bool {
        allBlocks.allSatisfy(\.isValid) &&
        (bodyBlocks.map { !$0.isEmpty } ?? true) &&
        (related.map { !$0.isEmpty } ?? true) &&
        (references.map { !$0.isEmpty && $0.allSatisfy(\.isValid) } ?? true) &&
        (glossaryTermIDs.map { ids in !ids.isEmpty && Set(ids).count == ids.count && ids.allSatisfy { !$0.isBlank } } ?? true) &&
        (choiceBlocks.map { $0.count == choices.count && $0.allSatisfy { !$0.isEmpty } } ?? true) &&
        (choiceExplanations.map { $0.count == choices.count && $0.allSatisfy { !$0.isBlank } } ?? true)
    }
}
