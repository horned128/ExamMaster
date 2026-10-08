import Foundation

/// The original chicken color is the fallback for existing qualification files.
enum TankeiPalette {
    static let defaultChickenHex = "#FFF3DA"
}

enum TankeiState: String, CaseIterable, Identifiable {
    case ready, encourage, celebrate, review, recover, rest
    var id: String { rawValue }

    var title: String {
        switch self {
        case .ready: "応援"
        case .encourage: "ひと区切り"
        case .celebrate: "達成"
        case .review: "復習"
        case .recover: "再挑戦"
        case .rest: "ひと休み"
        }
    }

    /// Celebrate only a real completed outcome, never infer exam success from a score.
    static func completion(mode: StudyMode, answered: Int, correct: Int, total: Int,
                           mockPassed: Bool? = nil) -> TankeiState {
        guard total > 0, answered > 0 else { return .rest }
        if mode == .diagnostic { return .ready }
        if mode == .mock { return mockPassed == true ? .celebrate : .recover }
        guard answered >= total else { return .rest }
        if correct >= total { return .celebrate }
        return correct == 0 ? .recover : .encourage
    }
}

enum TankeiStage: Int, Codable, CaseIterable, Identifiable {
    case chick, growingChick, youngChicken, chicken
    var id: Int { rawValue }
    var isChick: Bool { self == .chick || self == .growingChick }

    var title: String {
        switch self {
        case .chick: "ひよこ"
        case .growingChick: "育ちざかり"
        case .youngChicken: "若鶏"
        case .chicken: "チキン"
        }
    }

    var companionMessage: String {
        switch self {
        case .chick: "いっしょに、ひとつずつ。"
        case .growingChick: "少しずつ、たくましく。"
        case .youngChicken: "今日もいっしょに学ぼう。"
        case .chicken: "これからも、いっしょに。"
        }
    }

    static func at(_ fraction: Double) -> TankeiStage {
        guard fraction.isFinite else { return .chick }
        // A mock exam is optional: stable learning alone must allow full growth.
        if fraction >= 0.85 { return .chicken }
        if fraction >= 0.6 { return .youngChicken }
        if fraction >= 0.25 { return .growingChick }
        return .chick
    }
}

/// An internal blend of the existing retention and readiness metrics, never a UI score.
/// Both use available questions so locked content cannot gate growth. Earned stages persist.
struct TankeiGrowth {
    let score: Double
    let stage: TankeiStage

    init(retention: Double, readiness: Int, highestStage: Int = 0, earnedOnly: Bool = false) {
        let stableShare = retention.isFinite ? min(1, max(0, retention)) : 0
        let preparation = Double(min(100, max(0, readiness))) / 100
        score = stableShare * 0.4 + preparation * 0.6
        let observed = TankeiStage.at(score)
        let saved = TankeiStage(rawValue: highestStage) ?? .chick
        stage = earnedOnly ? saved : (TankeiStage(rawValue: max(observed.rawValue, saved.rawValue)) ?? .chick)
    }

    init(questions: [Question], data: StudyData, now: Date = .now, earnedOnly: Bool = false) {
        let ids = Set(questions.map(\.id))
        var scoped = data
        scoped.answers = data.answers.filter { ids.contains($0.questionID) }
        let retention = RetentionSummary(questions: questions, data: scoped, now: now)
        let readiness = questions.isEmpty ? 0 : StudyStats(questions: questions, data: scoped, now: now).readiness
        self.init(retention: retention.fraction, readiness: readiness,
                  highestStage: data.mascotHighestStage, earnedOnly: earnedOnly)
    }

    init(catalog: Catalog, data: StudyData, unlocked: Bool) {
        self.init(questions: SessionPlanner.available(catalog, unlocked: unlocked), data: data, earnedOnly: true)
    }
}

/// Today's effort, independent of correctness. Repeating a question cannot fill the goal.
struct TankeiDailyGoal {
    let target: Int
    let answeredIDs: Set<String>
    var remaining: Int { max(0, target - answeredIDs.count) }
    var completed: Bool { target > 0 && remaining == 0 }

    init(questionIDs: Set<String>, data: StudyData, short: Bool, now: Date = .now, calendar: Calendar = .current) {
        target = min(short ? 5 : 12, questionIDs.count)
        answeredIDs = Set(data.answers.filter { calendar.isDate($0.date, inSameDayAs: now) }.map(\.questionID))
            .intersection(questionIDs)
    }
}

enum TankeiGreetingContext: CaseIterable, Equatable {
    case firstStep, resume, dailyDone, review, retry, returning

    static func current(data: StudyData, dailyGoal: TankeiDailyGoal, dueCount: Int) -> Self {
        if data.pending != nil { return .resume }
        if dailyGoal.completed { return .dailyDone }
        if data.answers.isEmpty { return .firstStep }
        if data.answers.last?.correct == false { return .retry }
        if dueCount > 0 { return .review }
        return .returning
    }

    var lines: [String] {
        switch self {
        case .firstStep: ["まずは1問、\nいってみよう！", "いっしょに、\nはじめよう。", "小さな一歩、\n大きな力こぶ。"]
        case .resume: ["続きから、\nいこうか。", "続きは、\nここから！", "ひとつずつ、\n進めよう。"]
        case .dailyDone: ["今日のノルマ、\nおつかれさま！", "今日はもう、\nいいひと区切り。", "がんばったね。\nひと休みしよう。"]
        case .review: ["思い出す練習、\nいっしょに。", "復習で、\n力をつけよう！", "前の問題に、\nもう一度。"]
        case .retry: ["間違いも、\n次の一歩。", "大丈夫。\nまたいっしょに。", "答えを見直して、\nもう一歩！"]
        case .returning: ["今日の一歩、\nいっしょに！", "一問ずつ、\n力をつけよう。", "力こぶは大きく、\n歩幅は小さく。"]
        }
    }

    var pose: TankeiState {
        switch self {
        case .dailyDone: .rest
        case .review: .review
        case .retry: .recover
        default: .encourage
        }
    }

    func choose(excluding previous: String?) -> String {
        lines.filter { $0 != previous }.randomElement() ?? lines[0]
    }
}
