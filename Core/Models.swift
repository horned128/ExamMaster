import Foundation

struct Qualification: Codable {
    let id: String
    let name: String
    let subtitle: String
    let examMinutes: Int
    let mockQuestionCount: Int
    let passingPercent: Int
    let minimumSubjectPercent: Int
    let subjects: [String]
    let freeQuestionIDs: [String]
    let productID: String
    let accentHex: String
    let mascotBaseHex: String?
    let iconTitle: String?
    let examNote: String
    let privacyPolicyURL: String?
    let ads: AdsConfiguration
    var choiceLabels: [String]? = nil
    var mockPassTitle: String? = nil
    var usesFixedMocks: Bool? = nil
    var contentCredit: String? = nil
    var brandName: String? = nil
    var chickBaseHex: String? = nil
    var theme: QualificationTheme? = nil

    var appDisplayName: String { (brandName ?? "") + name }
    var originalContentLabel: String { "\(brandName ?? "ExamMaster") オリジナル" }
    func displaySource(_ source: String) -> String {
        guard let brandName, source.hasPrefix("ExamMaster オリジナル") else { return source }
        return brandName + String(source.dropFirst("ExamMaster".count))
    }
    var mascotColorHex: String { mascotBaseHex ?? TankeiPalette.defaultChickenHex }
    var iconDisplayTitle: String { iconTitle ?? name }
    func choiceLabel(_ index: Int) -> String {
        if let labels = choiceLabels, labels.indices.contains(index) { return labels[index] }
        return String(UnicodeScalar(65 + index)!)
    }
}

struct AdsConfiguration: Codable {
    let enabled: Bool
    let bannerEnabled: Bool
    let interstitialEnabled: Bool
    let interstitialMinimumIntervalSeconds: Int
    let interstitialMinimumSessions: Int
    let interstitialMinimumAnsweredQuestions: Int
    let adMobAppID: String
    let bannerAdUnitID: String
    let interstitialAdUnitID: String

    var isValid: Bool {
        guard adMobAppID.range(of: "^ca-app-pub-[0-9]+~[0-9]+$", options: .regularExpression) != nil,
              interstitialMinimumIntervalSeconds >= 600,
              interstitialMinimumSessions >= 2,
              interstitialMinimumAnsweredQuestions >= 5 else { return false }
        return !enabled ||
            ((!bannerEnabled || bannerAdUnitID.range(of: "^ca-app-pub-[0-9]+/[0-9]+$", options: .regularExpression) != nil) &&
             (!interstitialEnabled || interstitialAdUnitID.range(of: "^ca-app-pub-[0-9]+/[0-9]+$", options: .regularExpression) != nil))
    }
}

struct QuestionBank: Codable {
    let version: Int
    let questions: [Question]
    var mockSets: [MockSet]? = nil
    /// Partial coverage during development, never a claim of a complete bank.
    var isDraft: Bool? = nil
}

struct Question: Codable, Identifiable, Hashable {
    let id: String
    let year: Int
    let subject: String
    let category: String
    let stem: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
    let source: String
    let questionNumber: Int?
    let imageName: String?
    let difficulty: Int
    let tags: [String]
    let concepts: [String]
    let steps: [String]?
    var administration: String? = nil
    var kind: QuestionKind? = nil
    var mockSetID: String? = nil
    var bodyBlocks: [ContentBlock]? = nil
    var choiceBlocks: [[ContentBlock]]? = nil
    var explanationBlocks: [ContentBlock]? = nil
    var choiceExplanations: [String]? = nil
    /// Official points for exams whose answer fields carry unequal weights.
    var points: Int? = nil

    var searchText: String { ([stem, explanation, source, subject, category] + choices + tags + concepts +
        (bodyBlocks ?? []).map(\.searchText)).joined(separator: " ") }
    var kindTitle: String? { kind?.title }
}

enum CatalogError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return "問題データを確認してください: \(message)" }
    }
}

struct Catalog {
    let qualification: Qualification
    let questions: [Question]
    let mockSets: [MockSet]

    static func load(id: String) throws -> Catalog {
        guard let config = Bundle.main.url(forResource: "qualification", withExtension: "json"),
              let bank = Bundle.main.url(forResource: "questions", withExtension: "json") else {
            throw CatalogError.invalid("資格 \(id) のファイルがありません")
        }
        let qualification = try JSONDecoder().decode(Qualification.self, from: Data(contentsOf: config))
        guard qualification.id == id else { throw CatalogError.invalid("資格ID \(id) と同梱データが一致しません") }
        guard qualification.ads.adMobAppID == Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String else {
            throw CatalogError.invalid("AdMobアプリIDと資格設定が一致しません")
        }
        let catalog = try Catalog(qualification: qualification,
                                  bank: JSONDecoder().decode(QuestionBank.self, from: Data(contentsOf: bank)))
        for question in catalog.questions {
            for block in question.allBlocks where block.type == .image {
                guard let name = block.assetName, ContentAsset.url(name: name) != nil else {
                    throw CatalogError.invalid("図版がありません: \(question.id)")
                }
            }
        }
        return catalog
    }

    init(qualification: Qualification, bank: QuestionBank) throws {
        guard [1, 2].contains(bank.version), !qualification.id.isEmpty, !qualification.name.isEmpty,
              qualification.examMinutes > 0,
              qualification.mockQuestionCount >= qualification.subjects.count,
              (qualification.mockQuestionCount <= bank.questions.count || (bank.version == 2 && bank.isDraft == true)),
              (1...100).contains(qualification.passingPercent),
              (0...100).contains(qualification.minimumSubjectPercent),
              qualification.minimumSubjectPercent <= qualification.passingPercent,
              qualification.accentHex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil,
              qualification.mascotColorHex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil,
              qualification.chickBaseHex.map(QualificationTheme.validHex) ?? true,
              qualification.theme?.isValid ?? true,
              !qualification.iconDisplayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !qualification.subjects.isEmpty, Set(qualification.subjects).count == qualification.subjects.count,
              !qualification.productID.isEmpty, qualification.ads.isValid,
              qualification.choiceLabels.map({ labels in
                  (2...16).contains(labels.count) && Set(labels).count == labels.count && labels.allSatisfy { !$0.isBlank }
              }) ?? true,
              qualification.privacyPolicyURL.map({ URL(string: $0)?.scheme == "https" }) ?? true else {
            throw CatalogError.invalid("資格設定・広告設定・プライバシーポリシーURL")
        }
        let ids = bank.questions.map(\.id)
        guard Set(ids).count == ids.count, !ids.isEmpty,
              Set(qualification.freeQuestionIDs).isSubset(of: Set(ids)),
              qualification.freeQuestionIDs.count > 0,
              Set(qualification.freeQuestionIDs).count == qualification.freeQuestionIDs.count,
              qualification.subjects.allSatisfy({ subject in bank.questions.contains { $0.subject == subject } }),
              qualification.subjects.allSatisfy({ subject in bank.questions.contains { $0.subject == subject && qualification.freeQuestionIDs.contains($0.id) } }),
              bank.questions.allSatisfy({ q in
                  !q.id.isBlank && !q.stem.isBlank && !q.explanation.isBlank && !q.source.isBlank &&
                  qualification.subjects.contains(q.subject) && !q.category.isEmpty &&
                  (1...5).contains(q.difficulty) && (2...16).contains(q.choices.count) &&
                  q.choices.indices.contains(q.correctIndex) && Set(q.choices).count == q.choices.count && q.choices.allSatisfy { !$0.isBlank } &&
                  (q.points.map { (1...100).contains($0) } ?? true) &&
                  (q.steps == nil || (!(q.steps?.isEmpty ?? true) && q.steps!.allSatisfy { !$0.isBlank })) &&
                  (qualification.choiceLabels.map { $0.count >= q.choices.count } ?? true) && q.validContent
              }) else { throw CatalogError.invalid("問題ID・科目・正答・無料範囲") }
        let sets = bank.mockSets ?? []
        guard Set(sets.map(\.id)).count == sets.count else { throw CatalogError.invalid("模試セットID重複") }
        for set in sets {
            guard !set.id.isBlank, !set.title.isBlank, set.minutes > 0, set.questionCount > 0,
                  set.questionIDs.count == set.questionCount,
                  Set(set.questionIDs).count == set.questionCount,
                  Set(set.questionIDs).isSubset(of: Set(ids)),
                  set.questionIDs.allSatisfy({ id in bank.questions.first { $0.id == id }?.mockSetID == set.id }) else {
                throw CatalogError.invalid("模試セット構成: \(set.id)")
            }
        }
        self.qualification = qualification
        self.questions = bank.questions
        self.mockSets = sets
    }
}

/// Optional per-qualification colours keep existing apps' appearance intact.
/// Per-qualification colours. Since the series-wide Piyo Pop redesign only the state colours
/// (positive / review / growing) are applied; the surface keys are still decoded so existing files stay valid.
struct QualificationTheme: Codable {
    let backgroundLight: String
    let backgroundDark: String
    let surfaceLight: String
    let surfaceDark: String
    let borderLight: String
    let borderDark: String
    let trackLight: String
    let trackDark: String
    let mutedLight: String
    let mutedDark: String
    var positiveLight: String? = nil
    var positiveDark: String? = nil
    var reviewLight: String? = nil
    var reviewDark: String? = nil
    var growingLight: String? = nil
    var growingDark: String? = nil

    static func validHex(_ value: String) -> Bool {
        value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }
    var isValid: Bool {
        [backgroundLight, backgroundDark, surfaceLight, surfaceDark, borderLight, borderDark,
         trackLight, trackDark, mutedLight, mutedDark].allSatisfy(Self.validHex) &&
        [positiveLight, positiveDark, reviewLight, reviewDark, growingLight, growingDark]
            .compactMap { $0 }.allSatisfy(Self.validHex)
    }
}

enum Confidence: String, Codable, CaseIterable, Identifiable {
    case unsure, somewhat, sure
    var id: String { rawValue }
    var title: String {
        switch self { case .unsure: "自信なし"; case .somewhat: "迷った"; case .sure: "自信あり" }
    }
}

enum StudyMode: String, Codable { case diagnostic, recommended, misconception, contrast, year, subject, random, incorrect, bookmarked, mock, search }

enum RandomScope: String, Codable, CaseIterable, Identifiable {
    case unanswered, mixed
    var id: String { rawValue }
    var title: String { self == .unanswered ? "未回答のみ" : "ごちゃまぜ" }
}

/// Calendar date, not a timestamp: travelling across time zones must not change the exam day.
struct ExamDay: Codable, Equatable {
    let year: Int
    let month: Int
    let day: Int

    static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    init(date: Date, calendar: Calendar = ExamDay.localCalendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 0
        month = components.month ?? 0
        day = components.day ?? 0
    }

    func date(calendar: Calendar = ExamDay.localCalendar) -> Date? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        return date
    }

    func daysRemaining(from now: Date = .now, calendar: Calendar = ExamDay.localCalendar) -> Int? {
        guard let date = date(calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                       to: calendar.startOfDay(for: date)).day
    }
}

struct Answer: Codable, Identifiable {
    var id = UUID()
    let questionID: String
    let date: Date
    let selectedIndex: Int
    let correct: Bool
    let duration: TimeInterval
    var confidence: Confidence?
    let mode: StudyMode
}

struct MockResult: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let score: Int
    let total: Int
    let passed: Bool
    let subjectScores: [String: Int]
    var setID: String? = nil
    var title: String? = nil
    var startedAt: Date? = nil
    var duration: TimeInterval? = nil
    var questionResults: [MockQuestionResult]? = nil
    var earnedPoints: Int? = nil
    var possiblePoints: Int? = nil
    var percent: Int {
        if let earnedPoints, let possiblePoints, possiblePoints > 0 { return earnedPoints * 100 / possiblePoints }
        return total == 0 ? 0 : score * 100 / total
    }
}

struct Mastery: Codable {
    var attempts = 0
    var streak = 0
    var distinctSuccessDays = 0
    var lastSuccessDay: Date?
    var lastAnswered: Date?
    var stabilityDays = 1.0
    var dueAt: Date?
    var misconception = false
    var wrongChoices: [Int: Int] = [:]
    var lastCorrect = false
}

struct PendingStudy: Codable {
    let id: UUID
    let title: String
    let mode: StudyMode
    let questionIDs: [String]
    var index: Int
    var answers: [Answer]
    var submitted: Bool
    var selectedIndex: Int?
    var createdAt: Date

    init(session: StudySession, createdAt: Date = .now) {
        id = session.id
        title = session.title
        mode = session.mode
        questionIDs = session.questions.map(\.id)
        index = 0
        answers = []
        submitted = false
        selectedIndex = nil
        self.createdAt = createdAt
    }
}

struct StudyData: Codable {
    var schemaVersion = 1
    var answers: [Answer] = []
    var mastery: [String: Mastery] = [:]
    var bookmarks: Set<String> = []
    var mocks: [MockResult] = []
    var onboardingCompleted = false
    var diagnosticCompleted = false
    var recallFirst = true
    var randomScope: RandomScope = .mixed
    var pending: PendingStudy?
    var pendingMock: PendingMock?
    var examDay: ExamDay?
    var mascotHighestStage = TankeiStage.chick.rawValue
    var mascotNeedsMigration = false

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, answers, mastery, bookmarks, mocks, onboardingCompleted, diagnosticCompleted, recallFirst, randomScope, pending, pendingMock, examDay, mascotHighestStage
    }

    init() {}

    // Existing version-1 files lack the new keys. Decode them without resetting user history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        answers = try c.decode([Answer].self, forKey: .answers)
        mastery = try c.decode([String: Mastery].self, forKey: .mastery)
        bookmarks = try c.decode(Set<String>.self, forKey: .bookmarks)
        mocks = try c.decode([MockResult].self, forKey: .mocks)
        onboardingCompleted = try c.decode(Bool.self, forKey: .onboardingCompleted)
        diagnosticCompleted = try c.decode(Bool.self, forKey: .diagnosticCompleted)
        recallFirst = try c.decode(Bool.self, forKey: .recallFirst)
        randomScope = try c.decodeIfPresent(RandomScope.self, forKey: .randomScope) ?? .mixed
        pending = try c.decodeIfPresent(PendingStudy.self, forKey: .pending)
        pendingMock = try c.decodeIfPresent(PendingMock.self, forKey: .pendingMock)
        examDay = try c.decodeIfPresent(ExamDay.self, forKey: .examDay)
        mascotHighestStage = try c.decodeIfPresent(Int.self, forKey: .mascotHighestStage) ?? TankeiStage.chick.rawValue
        mascotNeedsMigration = !c.contains(.mascotHighestStage)
    }
}
