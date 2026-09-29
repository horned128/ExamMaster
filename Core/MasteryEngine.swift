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
        let questions = catalog.questions
        let grouped = Dictionary(grouping: questions, by: \.subject)
        let states = data.mastery
        stable = questions.filter { states[$0.id].map { MasteryEngine.isMastered($0, now: now) } ?? false }.count
        atRisk = questions.filter { q in
            guard let s = states[q.id] else { return false }
            return s.lastCorrect && !MasteryEngine.isMastered(s, now: now) && MasteryEngine.retention(s, now: now) < 0.8
        }.count
        due = questions.filter { q in states[q.id]?.dueAt.map { $0 <= now } ?? false }.count
        new = questions.filter { states[$0.id] == nil }.count
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
