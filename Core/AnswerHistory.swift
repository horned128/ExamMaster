import Foundation

enum AnswerHistoryOrder: String, CaseIterable, Identifiable {
    case newest, oldest
    var id: String { rawValue }
    var title: String { self == .newest ? "新しい順" : "古い順" }
}

struct AnswerHistoryDay: Identifiable {
    let date: Date
    let answers: [Answer]
    var id: Date { date }

    static func grouped(_ answers: [Answer], order: AnswerHistoryOrder, calendar: Calendar = .current) -> [Self] {
        let grouped = Dictionary(grouping: answers, by: { calendar.startOfDay(for: $0.date) })
        return grouped.keys.sorted { order == .newest ? $0 > $1 : $0 < $1 }.map { date in
            let sorted = (grouped[date] ?? []).sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.id.uuidString < rhs.id.uuidString }
                return order == .newest ? lhs.date > rhs.date : lhs.date < rhs.date
            }
            return Self(date: date, answers: sorted)
        }
    }
}

/// App Storeのレビュー依頼は、うまく解けた学習を終えてホームへ戻った直後だけに絞る。
/// OSも表示回数を制限するが、学習の妨げにならないよう端末内でも条件と間隔を持つ。
enum ReviewPrompt {
    static let minimumStudyDays = 3
    static let minimumAnswered = 5
    static let minimumAccuracy = 0.7
    static let interval: TimeInterval = 120 * 86_400
    private static let lastRequestedKey = "ReviewPromptLastRequested"

    static func shouldRequest(mode: StudyMode, answered: Int, correct: Int, history: [Answer],
                              lastRequested: Date?, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard mode != .diagnostic, mode != .mock, answered >= minimumAnswered,
              Double(correct) >= Double(answered) * minimumAccuracy else { return false }
        if let lastRequested, now.timeIntervalSince(lastRequested) < interval { return false }
        return Set(history.map { calendar.startOfDay(for: $0.date) }).count >= minimumStudyDays
    }

    static var lastRequested: Date? {
        UserDefaults.standard.object(forKey: lastRequestedKey) as? Date
    }

    static func markRequested(at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: lastRequestedKey)
    }

    static var suppressed: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-UITest") }
        #else
        false
        #endif
    }
}

/// ホームの「あしあと」（連続学習日数）・はね・今日の目標。回答履歴だけから計算し、追加の保存はしない。
struct StudyMomentum {
    static let dailyGoal = 10
    static let feathersPerCorrect = 10
    static let feathersPerAttempt = 2

    struct Day: Identifiable {
        let date: Date
        let studied: Bool
        /// おやすみ券で連続が守られた日。
        let rested: Bool
        let isToday: Bool
        let isFuture: Bool
        var id: Date { date }
    }

    let streak: Int
    let studiedToday: Bool
    let todayAnswers: Int
    let feathers: Int
    /// 今週のおやすみ券がまだ残っているか（週1枚）。
    let restTicketAvailable: Bool
    /// 今週の月曜〜日曜。
    let week: [Day]

    init(answers: [Answer], now: Date = .now, calendar: Calendar = .current) {
        var calendar = calendar
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: now)
        let studiedDays = Set(answers.map { calendar.startOfDay(for: $0.date) })
        func weekKey(_ date: Date) -> Int {
            calendar.component(.yearForWeekOfYear, from: date) * 100 + calendar.component(.weekOfYear, from: date)
        }

        // Walk back from today (or yesterday, so an unfinished today never breaks the streak).
        // Each week forgives one missed day, but only when an earlier studied day continues the run.
        var day = studiedDays.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var streak = 0
        var forgivenWeeks = Set<Int>()
        var pending: [Date] = []
        var rested = Set<Date>()
        while true {
            if studiedDays.contains(day) {
                streak += 1
                rested.formUnion(pending)
                pending = []
            } else if !forgivenWeeks.contains(weekKey(day)) {
                forgivenWeeks.insert(weekKey(day))
                pending.append(day)
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        self.streak = streak
        studiedToday = studiedDays.contains(today)
        todayAnswers = answers.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
        feathers = answers.reduce(0) { $0 + ($1.correct ? Self.feathersPerCorrect : Self.feathersPerAttempt) }
        restTicketAvailable = !rested.contains { weekKey($0) == weekKey(today) }
        let monday = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        week = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else { return nil }
            return Day(date: date, studied: studiedDays.contains(date), rested: rested.contains(date),
                       isToday: date == today, isFuture: date > today)
        }
    }
}
