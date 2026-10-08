import Foundation

struct StudySession: Identifiable {
    let id: UUID
    let title: String
    let mode: StudyMode
    let questions: [Question]
    let timed: Bool

    init(id: UUID = UUID(), title: String, mode: StudyMode, questions: [Question], timed: Bool) {
        self.id = id
        self.title = title
        self.mode = mode
        self.questions = questions
        self.timed = timed
    }
}

enum SessionPlanner {
    static func available(_ catalog: Catalog, unlocked: Bool) -> [Question] {
        unlocked ? catalog.questions : catalog.questions.filter { catalog.qualification.freeQuestionIDs.contains($0.id) }
    }

    static func diagnostic(_ catalog: Catalog, unlocked: Bool) -> StudySession {
        let items = available(catalog, unlocked: unlocked)
        let selected = catalog.qualification.subjects.flatMap { subject in
            items.filter { $0.subject == subject }.prefix(2)
        }
        return StudySession(title: "はじめの診断", mode: .diagnostic, questions: selected, timed: false)
    }

    static func recommended(_ catalog: Catalog, data: StudyData, unlocked: Bool, now: Date = .now,
                            excluding questionIDs: Set<String> = []) -> StudySession {
        let items = available(catalog, unlocked: unlocked).filter { !questionIDs.contains($0.id) }
        let states = data.mastery
        var pool = items
        var chosen: [Question] = []
        while !pool.isEmpty && chosen.count < 12 {
            let ordered = pool.sorted { a, b in
                let pa = priority(a, state: states[a.id], now: now) - Double(chosen.filter { $0.subject == a.subject }.count) * 16
                let pb = priority(b, state: states[b.id], now: now) - Double(chosen.filter { $0.subject == b.subject }.count) * 16
                return pa == pb ? a.id < b.id : pa > pb
            }
            let next = ordered[0]
            chosen.append(next)
            pool.removeAll { $0.id == next.id }
        }
        return StudySession(title: "今日のノルマ", mode: .recommended,
                            questions: interleave(chosen), timed: false)
    }

    private static func priority(_ q: Question, state: Mastery?, now: Date) -> Double {
        guard let state else { return 35 + Double(q.difficulty) }
        if state.misconception { return 110 }
        if state.lastCorrect == false { return 95 }
        let recall = MasteryEngine.retention(state, now: now)
        if state.dueAt.map({ $0 <= now }) ?? false { return 80 + (1 - recall) * 10 }
        if MasteryEngine.isMastered(state, now: now) { return 5 + (1 - recall) * 5 }
        return 12 + (1 - recall) * 12
    }

    static func interleave(_ questions: [Question]) -> [Question] {
        var remaining = questions
        var result: [Question] = []
        while !remaining.isEmpty {
            let previous = result.last?.subject
            let index = remaining.firstIndex { $0.subject != previous } ?? 0
            result.append(remaining.remove(at: index))
        }
        return result
    }

    static func contrast(_ catalog: Catalog, data: StudyData, unlocked: Bool) -> StudySession {
        let items = available(catalog, unlocked: unlocked)
        let mistakes = items.filter { data.mastery[$0.id]?.misconception == true || data.mastery[$0.id]?.lastCorrect == false }
        let concepts = Set(mistakes.flatMap(\.concepts))
        let related = items.filter { q in mistakes.contains(q) || !concepts.isDisjoint(with: q.concepts) }
        return StudySession(title: "似た問題を比べる", mode: .contrast,
                            questions: interleave(Array(related.prefix(12))), timed: false)
    }

    static func mock(_ catalog: Catalog, unlocked: Bool) -> StudySession {
        let pool = available(catalog, unlocked: unlocked)
        let target = min(catalog.qualification.mockQuestionCount, pool.count)
        let groups = catalog.qualification.subjects.map { subject in pool.filter { $0.subject == subject }.shuffled() }
        var chosen: [Question] = []
        var index = 0
        while chosen.count < target {
            var added = false
            for group in groups where chosen.count < target && index < group.count {
                chosen.append(group[index]); added = true
            }
            if !added { break }
            index += 1
        }
        return StudySession(title: "模擬試験", mode: .mock, questions: chosen, timed: true)
    }

    static func mockResult(_ answers: [Answer], questions: [Question], qualification: Qualification, date: Date = .now) -> MockResult {
        let bySubject = Dictionary(grouping: questions, by: \.subject)
        let correctIDs = Set(answers.filter(\.correct).map(\.questionID))
        let subjectScores = bySubject.mapValues { $0.filter { correctIDs.contains($0.id) }.count }
        let score = questions.filter { correctIDs.contains($0.id) }.count
        let overall = questions.isEmpty ? 0 : score * 100 / questions.count
        let subjectPass = bySubject.allSatisfy { subject, items in
            (subjectScores[subject] ?? 0) * 100 >= qualification.minimumSubjectPercent * items.count
        }
        return MockResult(date: date, score: score, total: questions.count,
                          passed: !questions.isEmpty && overall >= qualification.passingPercent && subjectPass,
                           subjectScores: subjectScores)
    }

    /// A tied or untested subject must not become an arbitrary diagnostic ranking.
    static func diagnosticComparison(_ answers: [Answer], questions: [Question],
                                     subjects: [String]) -> (best: String, weakest: String)? {
        let correctIDs = Set(answers.filter(\.correct).map(\.questionID))
        let scores = subjects.compactMap { subject -> (subject: String, score: Double)? in
            let items = questions.filter { $0.subject == subject }
            guard !items.isEmpty else { return nil }
            return (subject, Double(items.filter { correctIDs.contains($0.id) }.count) / Double(items.count))
        }
        guard let best = scores.max(by: { $0.score < $1.score }),
              let weakest = scores.min(by: { $0.score < $1.score }),
              best.score > weakest.score else { return nil }
        return (best.subject, weakest.subject)
    }
}
