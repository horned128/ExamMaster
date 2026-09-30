import Foundation

enum ReviewStatus: String, Hashable {
    case stable, due, risk, new, misconception
}

enum QuestionCollectionRoute: Hashable {
    case all, year(Int), subject(String), category(String), status(ReviewStatus), incorrect, favorites, contrast

    var title: String {
        switch self {
        case .all: "すべての問題"
        case .year(let year): "\(year)年の問題"
        case .subject(let subject): subject
        case .category(let category): category
        case .status(.stable): "安定して記憶"
        case .status(.due): "復習の目安"
        case .status(.risk): "忘却リスク"
        case .status(.new): "未学習"
        case .status(.misconception): "危険な思い込み"
        case .incorrect: "間違えた問題"
        case .favorites: "お気に入り"
        case .contrast: "混同しやすい概念"
        }
    }

    var studyMode: StudyMode {
        switch self {
        case .year: .year
        case .incorrect: .incorrect
        case .favorites: .bookmarked
        case .contrast: .contrast
        case .status(.due), .status(.risk), .status(.misconception), .status(.stable): .recommended
        case .all, .subject, .category, .status(.new): .subject
        }
    }
}

enum QuestionCollections {
    static func questions(for route: QuestionCollectionRoute, catalog: Catalog, data: StudyData,
                          now: Date = .now) -> [Question] {
        let questions = catalog.questions
        let mastery = data.mastery
        let indexed = Dictionary(uniqueKeysWithValues: questions.enumerated().map { ($0.element.id, $0.offset) })
        let sourceOrder: (Question, Question) -> Bool = { (indexed[$0.id] ?? 0) < (indexed[$1.id] ?? 0) }
        switch route {
        case .year(let year):
            return questions.filter { $0.year == year }.sorted { a, b in
                let aNumber = a.questionNumber ?? inferredNumber(a.source)
                let bNumber = b.questionNumber ?? inferredNumber(b.source)
                return aNumber == bNumber ? sourceOrder(a, b) : aNumber < bNumber
            }
        case .subject(let subject):
            return newestFirst(questions.filter { $0.subject == subject }, sourceOrder: sourceOrder)
        case .category(let category):
            return newestFirst(questions.filter { $0.category == category }, sourceOrder: sourceOrder)
        case .all:
            return newestFirst(questions, sourceOrder: sourceOrder)
        case .incorrect:
            return questions.filter { mastery[$0.id]?.lastCorrect == false }
                .sorted { (mastery[$0.id]?.lastAnswered ?? .distantFuture) < (mastery[$1.id]?.lastAnswered ?? .distantFuture) }
        case .favorites:
            return newestFirst(questions.filter { data.bookmarks.contains($0.id) }, sourceOrder: sourceOrder)
        case .contrast:
            let mistakes = questions.filter { mastery[$0.id]?.misconception == true || mastery[$0.id]?.lastCorrect == false }
            let concepts = Set(mistakes.flatMap(\.concepts))
            return newestFirst(questions.filter { mistakes.contains($0) || !concepts.isDisjoint(with: $0.concepts) }, sourceOrder: sourceOrder)
        case .status(let status):
            let selected = questions.filter { question in
                guard let state = mastery[question.id] else { return status == .new }
                switch status {
                case .stable: return MasteryEngine.isMastered(state, now: now)
                case .due: return state.dueAt.map { $0 <= now } ?? false
                case .risk:
                    return state.lastCorrect && !MasteryEngine.isMastered(state, now: now) &&
                        MasteryEngine.retention(state, now: now) < 0.8
                case .new: return false
                case .misconception: return state.misconception
                }
            }
            return selected.sorted { a, b in
                if status == .due { return (mastery[a.id]?.dueAt ?? .distantFuture) < (mastery[b.id]?.dueAt ?? .distantFuture) }
                if status == .risk || status == .stable {
                    let lhs = mastery[a.id].map { MasteryEngine.retention($0, now: now) } ?? 0
                    let rhs = mastery[b.id].map { MasteryEngine.retention($0, now: now) } ?? 0
                    if lhs != rhs { return lhs < rhs }
                }
                return sourceOrder(a, b)
            }
        }
    }

    private static func newestFirst(_ questions: [Question], sourceOrder: (Question, Question) -> Bool) -> [Question] {
        questions.sorted { a, b in a.year == b.year ? sourceOrder(a, b) : a.year > b.year }
    }

    private static func inferredNumber(_ source: String) -> Int {
        guard let range = source.range(of: "問[0-9]+", options: .regularExpression) else { return Int.max }
        return Int(source[range].dropFirst()) ?? Int.max
    }

    static func resumedSession(_ pending: PendingStudy, catalog: Catalog, unlocked: Bool) -> StudySession? {
        guard pending.mode != .diagnostic, pending.mode != .mock, pending.mode != .search,
              !pending.questionIDs.isEmpty, pending.questionIDs.indices.contains(pending.index),
              Set(pending.questionIDs).count == pending.questionIDs.count else { return nil }
        let available = Dictionary(uniqueKeysWithValues: SessionPlanner.available(catalog, unlocked: unlocked).map { ($0.id, $0) })
        let ordered = pending.questionIDs.compactMap { available[$0] }
        guard ordered.count == pending.questionIDs.count else { return nil }
        return StudySession(id: pending.id, title: pending.title, mode: pending.mode, questions: ordered, timed: false)
    }
}
