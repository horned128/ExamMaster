import Foundation

// Conservative heuristic, not a calibrated probability of recall or passing.
enum MasteryEngine {
    static func retention(_ state: Mastery, now: Date) -> Double {
        guard let last = state.lastAnswered else { return 0 }
        let days = max(0, now.timeIntervalSince(last) / 86_400)
        return exp(-days / max(0.5, state.stabilityDays)) * (state.lastCorrect ? 1 : 0.25)
    }

    static func isMastered(_ state: Mastery, now: Date) -> Bool {
        state.distinctSuccessDays >= 3 && state.stabilityDays >= 7 &&
        !state.misconception && retention(state, now: now) >= 0.75
    }

    static func update(_ previous: Mastery, answer: Answer, difficulty: Int, calendar: Calendar = .current) -> Mastery {
        var state = previous
        let priorRetention = retention(previous, now: answer.date)
        let differentDay = previous.lastSuccessDay.map { !calendar.isDate($0, inSameDayAs: answer.date) } ?? true
        state.attempts += 1
        state.lastAnswered = answer.date
        state.lastCorrect = answer.correct
        if answer.correct {
            state.streak += 1
            if differentDay {
                state.distinctSuccessDays += 1
                state.lastSuccessDay = answer.date
            }
            // Same-day repetitions improve retrieval, but do not count as successive relearning.
            let gain = differentDay ? (priorRetention < 0.85 ? 2.2 : 1.6) : 1.08
            let confidenceFactor = answer.confidence == .unsure ? 0.85 : 1.0
            let difficultyFactor = 1.0 - Double(difficulty - 1) * 0.04
            state.stabilityDays = min(180, max(1, state.stabilityDays * gain * confidenceFactor * difficultyFactor))
            if state.streak >= 2 { state.misconception = false }
        } else {
            state.streak = 0
            state.stabilityDays = max(0.5, state.stabilityDays * 0.45)
            let count = (state.wrongChoices[answer.selectedIndex] ?? 0) + 1
            state.wrongChoices[answer.selectedIndex] = count
            if answer.confidence == .sure || count >= 2 { state.misconception = true }
        }
        // Target ~80% recall for a known item; incorrect answers return the next day.
        let interval = answer.correct ? max(1, -log(0.8) * state.stabilityDays) : 1
        state.dueAt = calendar.date(byAdding: .second, value: Int(interval * 86_400), to: answer.date)
        return state
    }
}

/// One shared partition of available questions: stable, answered-but-learning, new.
/// The stable share is the retention rate; review flags never add extra segments.
/// Unlike mascot growth, this can decrease with time or an incorrect answer.
struct RetentionSummary {
    let stable: Int
    let new: Int
    let total: Int
    var growing: Int { total - stable - new }
    var fraction: Double { total == 0 ? 0 : Double(stable) / Double(total) }
    var percent: Int { total == 0 ? 0 : stable * 100 / total }

    init(questions: [Question], data: StudyData, now: Date) {
        total = questions.count
        new = questions.filter { data.mastery[$0.id] == nil }.count
        stable = questions.filter { question in
            data.mastery[question.id].map { MasteryEngine.isMastered($0, now: now) } ?? false
        }.count
    }
}

struct StudyStats {
    let stable: Int
    let atRisk: Int
    let due: Int
    let new: Int
    let misconceptions: Int
    let readiness: Int
    let studyDays: Int
    let subjectScores: [String: Int]

    init(catalog: Catalog, data: StudyData, now: Date = .now, calendar: Calendar = .current) {
        self.init(questions: catalog.questions, data: data, now: now, calendar: calendar)
    }

    init(questions: [Question], data: StudyData, now: Date = .now, calendar: Calendar = .current) {
        let grouped = Dictionary(grouping: questions, by: \.subject)
        let states = data.mastery
        let memory = RetentionSummary(questions: questions, data: data, now: now)
        stable = memory.stable
        atRisk = questions.filter { q in
            guard let s = states[q.id] else { return false }
            return s.lastCorrect && !MasteryEngine.isMastered(s, now: now) && MasteryEngine.retention(s, now: now) < 0.8
        }.count
        due = questions.filter { q in states[q.id]?.dueAt.map { $0 <= now } ?? false }.count
        new = memory.new
        misconceptions = questions.filter { states[$0.id]?.misconception == true }.count
        studyDays = Set(data.answers.map { calendar.startOfDay(for: $0.date) }).count
        subjectScores = grouped.mapValues { items in
            guard !items.isEmpty else { return 0 }
            let sum = items.reduce(0.0) { result, q in
                guard let s = states[q.id] else { return result }
                return result + MasteryEngine.retention(s, now: now) * (s.distinctSuccessDays >= 2 ? 1 : 0.75)
            }
            return Int(100 * sum / Double(items.count))
        }
        let coverage = Double(questions.count - new) / Double(max(1, questions.count))
        let recall = Double(subjectScores.values.reduce(0, +)) / Double(max(1, subjectScores.count)) / 100
        let weakest = Double(subjectScores.values.min() ?? 0) / 100
        let recent = Array(Dictionary(grouping: data.answers.filter { $0.date >= now.addingTimeInterval(-14 * 86_400) }, by: \.questionID)
            .values.compactMap { $0.max { $0.date < $1.date } })
        let recentScore = recent.isEmpty ? 0 : Double(recent.filter(\.correct).count) / Double(recent.count)
        var mockScore = 0.0
        if let result = data.mocks.last {
            let fraction = Double(result.score) / Double(max(1, result.total))
            let age = max(0.0, now.timeIntervalSince(result.date))
            let recency = max(0.0, 1.0 - age / (90.0 * 86_400.0))
            mockScore = fraction * recency
        }
        readiness = Int((coverage * 0.20 + recall * 0.34 + weakest * 0.14 + recentScore * 0.12 + mockScore * 0.20) * 100)
    }
}

/// How well a group of questions is known, for the 弱点マップ and the 全体図 chips.
enum MasteryLevel: Int, CaseIterable, Comparable {
    case new, weak, growing, solid

    var title: String {
        switch self {
        case .new: "未学習"
        case .weak: "苦手"
        case .growing: "学習中"
        case .solid: "定着"
        }
    }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// Weak while fewer than 60% of the answered questions were last answered right;
    /// solid once 60% of all of them are mastered.
    init(questions: [Question], data: StudyData, now: Date) {
        let answered = questions.compactMap { data.mastery[$0.id] }
        guard !answered.isEmpty else { self = .new; return }
        let right = answered.filter { $0.lastCorrect && !$0.misconception }.count
        let mastered = answered.filter { MasteryEngine.isMastered($0, now: now) }.count
        if Double(right) < Double(answered.count) * 0.6 { self = .weak }
        else if Double(mastered) >= Double(questions.count) * 0.6 { self = .solid }
        else { self = .growing }
    }
}

/// One theme of the 弱点マップ with what it is ranked by.
struct ThemeInsight: Identifiable {
    let topic: StudyTopic
    /// The questions this user can open.
    let available: [Question]
    let level: MasteryLevel
    let memory: RetentionSummary
    /// Correct answers over all answers in the theme; nil before the first answer.
    let accuracy: Double?
    /// Answered questions that are due, last wrong or a misconception.
    let reviewCount: Int
    /// The theme's share of the past questions, relative to the most asked theme (0...1).
    let examShare: Double
    let priority: Double

    var id: String { topic.id }
    var title: String { topic.title }
    var locked: Bool { available.isEmpty }

    /// Three steps for display: 3 = among the most asked.
    var examFrequency: Int { examShare >= 0.67 ? 3 : examShare >= 0.34 ? 2 : 1 }

    /// Highest priority first: weak accuracy counts half, the review backlog 30%, how often the exam asks it 20%.
    static func ranked(_ topics: [StudyTopic], data: StudyData, freeIDs: Set<String>, unlocked: Bool,
                       now: Date = .now) -> [Self] {
        let answersByQuestion = Dictionary(grouping: data.answers, by: \.questionID)
        let past = topics.map { topic in topic.questions.filter { $0.kind == .past }.count }
        let counts = past.reduce(0, +) > 0 ? past : topics.map(\.questions.count)
        let most = Double(max(1, counts.max() ?? 1))
        let insights = zip(topics, counts).map { topic, count -> Self in
            let available = unlocked ? topic.questions : topic.questions.filter { freeIDs.contains($0.id) }
            let answers = available.flatMap { answersByQuestion[$0.id] ?? [] }
            let accuracy = answers.isEmpty ? nil : Double(answers.filter(\.correct).count) / Double(answers.count)
            let review = available.filter { question in
                guard let state = data.mastery[question.id] else { return false }
                return !state.lastCorrect || state.misconception || (state.dueAt.map { $0 <= now } ?? false)
            }.count
            let share = Double(count) / most
            let weakness: Double = 1 - (accuracy ?? 0.5)
            let backlog: Double = Double(review) / Double(max(1, available.count))
            let priority: Double = available.isEmpty ? -1 : weakness * 0.5 + backlog * 0.3 + share * 0.2
            let shown = available.isEmpty ? topic.questions : available
            return Self(topic: topic, available: available,
                        level: MasteryLevel(questions: shown, data: data, now: now),
                        memory: RetentionSummary(questions: shown, data: data, now: now),
                        accuracy: accuracy, reviewCount: review, examShare: share, priority: priority)
        }
        let order: [(offset: Int, element: Self)] = Array(insights.enumerated())
        return order.sorted { (a: (offset: Int, element: Self), b: (offset: Int, element: Self)) -> Bool in
            if a.element.priority != b.element.priority { return a.element.priority > b.element.priority }
            return a.offset < b.offset
        }.map { $0.element }
    }

    /// Up to `count` of the theme's questions, the most urgent first by the same order as 今日の学習.
    func weakSession(data: StudyData, now: Date = .now, count: Int = 10) -> StudySession? {
        var score: [String: Double] = [:]
        for question in available {
            score[question.id] = SessionPlanner.priority(question, state: data.mastery[question.id], now: now)
        }
        let sorted = available.sorted { (a: Question, b: Question) -> Bool in
            let pa = score[a.id] ?? 0, pb = score[b.id] ?? 0
            return pa == pb ? a.id < b.id : pa > pb
        }
        let chosen = Array(sorted.prefix(count))
        guard !chosen.isEmpty else { return nil }
        return StudySession(title: "\(title)の弱点", mode: .recommended, questions: chosen, timed: false)
    }
}
