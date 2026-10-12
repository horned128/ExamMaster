import Foundation

enum ReviewStatus: String, Hashable {
    case stable, due, risk, new, misconception
}

enum QuestionCollectionRoute: Hashable {
    case all, year(Int), mockSet(String), subject(String), category(String), subjectCategory(String, String), subjectTopic(String, String), status(ReviewStatus), incorrect, favorites

    var title: String {
        switch self {
        case .all: "すべての問題"
        case .year(let year): "\(year)年の問題"
        case .mockSet: "予想問題"
        case .subject(let subject): subject
        case .category(let category), .subjectCategory(_, let category), .subjectTopic(_, let category): category
        case .status(.stable): "定着した問題"
        case .status(.due): "今の復習"
        case .status(.risk): "思い出しておきたい問題"
        case .status(.new): "これからの問題"
        case .status(.misconception): "勘違いをほどく"
        case .incorrect: "苦手問題"
        case .favorites: "ブックマーク"
        }
    }

    var studyMode: StudyMode {
        switch self {
        case .year, .mockSet: .year
        case .incorrect: .incorrect
        case .favorites: .bookmarked
        case .status(.due), .status(.risk), .status(.misconception), .status(.stable): .recommended
        case .all, .subject, .category, .subjectCategory, .subjectTopic, .status(.new): .subject
        }
    }
}

/// Presentation of existing due dates; never changes the scheduling model.
/// Only available questions are counted, so the home action matches the displayed count.
struct ReviewOutlook {
    let dueCount: Int
    let nextDate: Date?
    let nextCount: Int

    init(questions: [Question], data: StudyData, now: Date = .now, calendar: Calendar = .current) {
        let dates = questions.compactMap { data.mastery[$0.id]?.dueAt }
        dueCount = dates.filter { $0 <= now }.count
        let next = dates.filter { $0 > now }.min()
        nextDate = next
        nextCount = next.map { date in dates.filter { $0 > now && calendar.isDate($0, inSameDayAs: date) }.count } ?? 0
    }

    static func label(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if date <= now { return "今" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "今日中"
        case 1: return "明日"
        case 2: return "明後日"
        default: return date.formatted(.dateTime.month().day())
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
        case .mockSet(let id):
            guard let set = catalog.mockSets.first(where: { $0.id == id }) else { return [] }
            let byID = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
            return set.questionIDs.compactMap { byID[$0] }
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
        case .subjectCategory(let subject, let category):
            return newestFirst(questions.filter { $0.subject == subject && $0.category == category }, sourceOrder: sourceOrder)
        case .subjectTopic(let subject, let title):
            return newestFirst(StudyTopic.grouped(subject: subject, questions: questions).first { $0.title == title }?.questions ?? [], sourceOrder: sourceOrder)
        case .all:
            return newestFirst(questions, sourceOrder: sourceOrder)
        case .incorrect:
            return questions.filter { mastery[$0.id]?.lastCorrect == false }
                .sorted { (mastery[$0.id]?.lastAnswered ?? .distantFuture) < (mastery[$1.id]?.lastAnswered ?? .distantFuture) }
        case .favorites:
            return newestFirst(questions.filter { data.bookmarks.contains($0.id) }, sourceOrder: sourceOrder)
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


}

/// Broader learning themes keep sparse source categories useful without changing question metadata.
struct StudyTopic: Identifiable {
    let title: String
    let questions: [Question]
    var id: String { title }

    static func grouped(subject: String, questions: [Question]) -> [Self] {
        let items = questions.filter { $0.subject == subject }
        let grouped = Dictionary(grouping: items, by: { theme(subject: subject, category: $0.category) })
        return grouped.keys.sorted().map { Self(title: $0, questions: grouped[$0] ?? []) }
    }

    private static func theme(subject: String, category: String) -> String {
        let rules: [(String, [String])]
        switch subject {
        case "ネットワーク": rules = [
            ("IP・アドレス設計", ["ARP", "RARP", "IPアドレス", "IPv", "サブネット", "CIDR", "VLSM", "ホスト部", "ICMP", "DHCP"]),
            ("経路制御・冗長化", ["BGP", "OSPF", "RIP", "経路", "ルーティング", "STP", "スパニング", "冗長", "MPLS", "SDN", "アグリゲーション"]),
            ("アプリケーション通信", ["DNS", "ドメイン", "HTTP", "Web", "URL", "FTP", "SMTP", "メール", "MIME", "LDAP", "認証", "VPN", "IPsec"]),
            ("無線・伝送媒体", ["無線", "IoT", "5G", "光通信", "PLC", "ケーブル", "配線", "物理接続"]),
            ("性能・運用設計", ["QoS", "RSVP", "予約", "容量", "トラフィック", "呼量", "音声", "最大流", "管理", "送信間隔", "ビット誤り"])
        ]
        case "セキュリティ": rules = [
            ("認証・暗号", ["802.1X", "RADIUS", "SAML", "TLS", "証明", "認証", "鍵", "暗号", "MAC", "IPsec", "WPA", "HSTS"]),
            ("メール・DNS対策", ["メール", "OP25B", "DNS"]),
            ("攻撃・脆弱性", ["攻撃", "注入", "脆弱", "Cookie", "妨害", "NTP", "偽装"]),
            ("検知・対応", ["マルウェア", "検知", "CSIRT", "インシデント", "フォレンジック", "観測"])
        ]
        case "コンピュータシステム": rules = [
            ("CPU・メモリ", ["CPU", "メモリ", "記憶", "割込み", "量子", "パイプライン"]),
            ("性能・待ち行列", ["待ち行列", "時間", "アムダール", "並列", "タイムアウト"]),
            ("信頼性・保守", ["信頼性", "保守", "冗長", "RAID"])
        ]
        case "システム開発技術": rules = [
            ("設計・モデリング", ["SOA", "UML", "モデリング", "アーキテクチャ", "is-a", "Web"]),
            ("テスト・品質", ["テスト", "信頼性", "安全性", "使用性", "エラー"]),
            ("開発・保守", ["開発", "XP", "保守", "リファクタリング", "リバース"])
        ]
        default: return category
        }
        for (title, words) in rules where words.contains(where: { category.localizedCaseInsensitiveContains($0) }) { return title }
        switch subject {
        case "ネットワーク": return "通信の基礎・プロトコル"
        case "セキュリティ": return "防御・可用性"
        case "コンピュータシステム": return "システム構成・運用"
        default: return "権利・管理"
        }
    }
}

enum QuizLevel {
    static func questions(level: Int, catalog: Catalog, unlocked: Bool) -> [Question] {
        SessionPlanner.available(catalog, unlocked: unlocked).filter { $0.difficulty == level }
    }
    static func title(_ level: Int) -> String {
        switch level { case 1: "入門"; case 2: "基本"; case 3: "応用"; case 4: "発展"; default: "挑戦" }
    }
}
