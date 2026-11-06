import Foundation

struct StudySession: Identifiable {
    let id: UUID
    let title: String
    let mode: StudyMode
    let questions: [Question]
    let timed: Bool
    let mockSetID: String?
    let returnsToQuestionList: Bool

    init(id: UUID = UUID(), title: String, mode: StudyMode, questions: [Question], timed: Bool, mockSetID: String? = nil,
         returnsToQuestionList: Bool = false) {
        self.id = id
        self.title = title
        self.mode = mode
        self.questions = questions
        self.timed = timed
        self.mockSetID = mockSetID
        self.returnsToQuestionList = returnsToQuestionList
    }
}

struct TodayPlan {
    let session: StudySession
    /// 一度でも回答した問題（要復習・前回不正解・おさらい）。
    let reviewCount: Int
    let newCount: Int
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
                            excluding questionIDs: Set<String> = [], count: Int = 12,
                            subjectCaps: [String: Int] = [:], title: String = "復習") -> StudySession {
        let items = available(catalog, unlocked: unlocked).filter { !questionIDs.contains($0.id) }
        // Home re-plans on every refresh, so score each question once instead of re-sorting the bank per pick.
        let base = Dictionary(items.map { ($0.id, priority($0, state: data.mastery[$0.id], now: now)) },
                              uniquingKeysWith: { first, _ in first })
        var pool = items
        var chosen: [Question] = []
        var perSubject: [String: Int] = [:]
        while chosen.count < count {
            func score(_ q: Question) -> Double { (base[q.id] ?? 0) - Double(perSubject[q.subject, default: 0]) * 16 }
            guard let next = pool.min(by: { a, b in
                let pa = score(a), pb = score(b)
                return pa == pb ? a.id < b.id : pa > pb
            }) else { break }
            chosen.append(next)
            perSubject[next.subject, default: 0] += 1
            pool.removeAll { $0.id == next.id }
            if let cap = subjectCaps[next.subject], perSubject[next.subject, default: 0] >= cap {
                pool.removeAll { $0.subject == next.subject }
            }
        }
        return StudySession(title: title, mode: .recommended,
                            questions: interleave(chosen), timed: false)
    }

    /// ホームの「今日の学習」。復習の優先順は`recommended`と同じで、毎日開いて終えられる量に絞る。
    static func today(_ catalog: Catalog, data: StudyData, unlocked: Bool, now: Date = .now) -> TodayPlan {
        // 科目Bは1問が長文読解なので、1日のセットでは2問までにする。
        let session = recommended(catalog, data: data, unlocked: unlocked, now: now, count: 10,
                                  subjectCaps: ["科目B": 2], title: "今日の学習")
        let newCount = session.questions.filter { data.mastery[$0.id] == nil }.count
        return TodayPlan(session: session, reviewCount: session.questions.count - newCount, newCount: newCount)
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
        let weighted = questions.contains { $0.points != nil }
        let possiblePoints = questions.reduce(0) { $0 + ($1.points ?? 1) }
        let earnedPoints = questions.filter { correctIDs.contains($0.id) }.reduce(0) { $0 + ($1.points ?? 1) }
        let overall = possiblePoints == 0 ? 0 : earnedPoints * 100 / possiblePoints
        let subjectPass = bySubject.allSatisfy { subject, items in
            let possible = items.reduce(0) { $0 + ($1.points ?? 1) }
            let earned = items.filter { correctIDs.contains($0.id) }.reduce(0) { $0 + ($1.points ?? 1) }
            return earned * 100 >= qualification.minimumSubjectPercent * possible
        }
        return MockResult(date: date, score: score, total: questions.count,
                          passed: !questions.isEmpty && overall >= qualification.passingPercent && subjectPass,
                           subjectScores: subjectScores,
                           earnedPoints: weighted ? earnedPoints : nil,
                           possiblePoints: weighted ? possiblePoints : nil)
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
