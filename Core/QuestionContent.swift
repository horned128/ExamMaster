import Foundation

enum QuestionKind: String, Codable { case past, prediction
    var title: String { self == .past ? "公式過去問" : "オリジナル問題" }
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
        ([text, altText, caption].compactMap { $0 } + (headers ?? []) + (rows ?? []).flatMap { $0 }).joined(separator: " ")
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
    var allBlocks: [ContentBlock] { (bodyBlocks ?? []) + (choiceBlocks ?? []).flatMap { $0 } + (explanationBlocks ?? []) }
    var validContent: Bool {
        allBlocks.allSatisfy(\.isValid) &&
        (bodyBlocks.map { !$0.isEmpty } ?? true) &&
        (choiceBlocks.map { $0.count == choices.count && $0.allSatisfy { !$0.isEmpty } } ?? true) &&
        (choiceExplanations.map { $0.count == choices.count && $0.allSatisfy { !$0.isBlank } } ?? true)
    }
}
