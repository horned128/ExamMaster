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
