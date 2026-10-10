import Foundation

struct MockSet: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let kind: QuestionKind
    let questionIDs: [String]
    let questionCount: Int
    let minutes: Int
}

struct PendingMock: Codable, Identifiable {
    let id: UUID
    let setID: String?
    let title: String
    let questionIDs: [String]
    let startedAt: Date
    let deadline: Date
    var index: Int
    var selections: [String: Int]

    init(session: StudySession, minutes: Int, now: Date = .now) {
        id = session.id
        setID = session.mockSetID
        title = session.title
        questionIDs = session.questions.map(\.id)
        startedAt = now
        deadline = now.addingTimeInterval(Double(minutes) * 60)
        index = 0
        selections = [:]
    }
    func remaining(at now: Date = .now) -> TimeInterval { max(0, deadline.timeIntervalSince(now)) }
}

struct MockQuestionResult: Codable, Identifiable {
    enum Outcome: String, Codable { case correct, incorrect, unanswered
        var title: String {
            switch self { case .correct: "正解"; case .incorrect: "誤答"; case .unanswered: "未回答" }
        }
    }
    let questionID: String
    let selectedIndex: Int?
    let correctIndex: Int
    let outcome: Outcome
    var id: String { questionID }
}

enum MockExam {
    static func session(set: MockSet, catalog: Catalog, unlocked: Bool) -> StudySession? {
        let available = Dictionary(uniqueKeysWithValues: SessionPlanner.available(catalog, unlocked: unlocked).map { ($0.id, $0) })
        let questions = set.questionIDs.compactMap { available[$0] }
        guard questions.count == set.questionCount else { return nil }
        return StudySession(title: set.title, mode: .mock, questions: questions, timed: true, mockSetID: set.id)
    }

    static func restore(_ pending: PendingMock, catalog: Catalog, unlocked: Bool) -> StudySession? {
        let available = Dictionary(uniqueKeysWithValues: SessionPlanner.available(catalog, unlocked: unlocked).map { ($0.id, $0) })
        let questions = pending.questionIDs.compactMap { available[$0] }
        guard !questions.isEmpty, questions.count == pending.questionIDs.count,
              Set(pending.questionIDs).count == questions.count, questions.indices.contains(pending.index),
              pending.deadline > pending.startedAt,
              pending.selections.allSatisfy({ id, index in available[id]?.choices.indices.contains(index) == true && pending.questionIDs.contains(id) }) else { return nil }
        return StudySession(id: pending.id, title: pending.title, mode: .mock, questions: questions, timed: true, mockSetID: pending.setID)
    }

    /// Grade only the last saved selection. Blank answers never become learning attempts.
    static func grade(_ pending: PendingMock, questions: [Question], qualification: Qualification,
                      now: Date = .now) -> (result: MockResult, answers: [Answer]) {
        let endedAt = min(max(now, pending.startedAt), pending.deadline)
        let outcomes = questions.map { question in
            let selection = pending.selections[question.id]
            return MockQuestionResult(questionID: question.id, selectedIndex: selection, correctIndex: question.correctIndex,
                                      outcome: selection.map { $0 == question.correctIndex ? .correct : .incorrect } ?? .unanswered)
        }
        let answers = outcomes.compactMap { item -> Answer? in
            guard let selection = item.selectedIndex else { return nil }
            // Per-question timing isn't measured in free-navigation mocks; zero means unmeasured.
            return Answer(questionID: item.questionID, date: endedAt, selectedIndex: selection,
                          correct: item.outcome == .correct, duration: 0, confidence: nil, mode: .mock)
        }
        var result = SessionPlanner.mockResult(answers, questions: questions, qualification: qualification, date: endedAt)
        result.id = pending.id
        result.setID = pending.setID
        result.title = pending.title
        result.startedAt = pending.startedAt
        result.duration = endedAt.timeIntervalSince(pending.startedAt)
        result.questionResults = outcomes
        return (result, answers)
    }
}
