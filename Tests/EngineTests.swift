import XCTest
@testable import ExamMaster

final class EngineTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    private func answer(_ id: String = "p01", at date: Date, correct: Bool, choice: Int = 0,
                        confidence: Confidence? = nil) -> Answer {
        Answer(questionID: id, date: date, selectedIndex: choice, correct: correct,
               duration: 14, confidence: confidence, mode: .recommended)
    }

    func testSuccessiveRelearningRequiresDifferentDaysAndDecays() {
        var state = Mastery()
        for n in 0..<5 {
            state = MasteryEngine.update(state, answer: answer(at: start.addingTimeInterval(Double(n) * 20), correct: true), difficulty: 1)
        }
        XCTAssertEqual(state.distinctSuccessDays, 1)
        XCTAssertFalse(MasteryEngine.isMastered(state, now: start))
        for n in 1...3 {
            state = MasteryEngine.update(state, answer: answer(at: start.addingTimeInterval(Double(n) * day), correct: true), difficulty: 1)
        }
        XCTAssertTrue(MasteryEngine.isMastered(state, now: start.addingTimeInterval(3 * day)))
        XCTAssertLessThan(MasteryEngine.retention(state, now: start.addingTimeInterval(100 * day)), 0.75)
        XCTAssertFalse(MasteryEngine.isMastered(state, now: start.addingTimeInterval(100 * day)))
    }

    func testMisconceptionAndWrongAnswerReschedule() {
        let first = MasteryEngine.update(Mastery(), answer: answer(at: start, correct: false, choice: 2), difficulty: 2)
        XCTAssertFalse(first.misconception)
        let second = MasteryEngine.update(first, answer: answer(at: start.addingTimeInterval(day), correct: false, choice: 2), difficulty: 2)
        XCTAssertTrue(second.misconception)
        XCTAssertEqual(second.dueAt, start.addingTimeInterval(2 * day))
        let certain = MasteryEngine.update(Mastery(), answer: answer(at: start, correct: false, choice: 3, confidence: .sure), difficulty: 2)
        XCTAssertTrue(certain.misconception)
        var recovered = second
        for n in 2...3 {
            recovered = MasteryEngine.update(recovered, answer: answer(at: start.addingTimeInterval(Double(n) * day), correct: true), difficulty: 2)
        }
        XCTAssertFalse(recovered.misconception)
    }

    func testCatalogValidationAndSessionCoverage() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "QualificationID") as? String, catalog.qualification.id)
        XCTAssertEqual(catalog.questions.count, 32)
        XCTAssertEqual(Set(catalog.questions.map(\.correctIndex)), Set(0...3))
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: false).count, 12)
        let diagnostic = SessionPlanner.diagnostic(catalog, unlocked: false)
        XCTAssertEqual(diagnostic.questions.count, 8)
        XCTAssertEqual(Set(diagnostic.questions.map(\.subject)).count, 4)
        let mock = SessionPlanner.mock(catalog, unlocked: true)
        XCTAssertEqual(mock.questions.count, 12)
        XCTAssertEqual(Set(mock.questions.map(\.id)).count, 12)
        XCTAssertEqual(Set(mock.questions.map(\.subject)).count, 4)
        let freeMock = SessionPlanner.mock(catalog, unlocked: false)
        XCTAssertEqual(freeMock.questions.count, 12)
    }

    func testRecommendedPrioritizesMisconceptionAndInterleaves() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        var data = StudyData()
        data.mastery["r01"] = Mastery(attempts: 2, misconception: true)
        let session = SessionPlanner.recommended(catalog, data: data, unlocked: true, now: start)
        XCTAssertTrue(session.questions.contains { $0.id == "r01" })
        XCTAssertEqual(session.questions.count, 12)
        for pair in zip(session.questions, session.questions.dropFirst()) {
            XCTAssertNotEqual(pair.0.subject, pair.1.subject)
        }
        XCTAssertTrue(SessionPlanner.contrast(catalog, data: data, unlocked: true).questions.contains { $0.id == "r01" })
    }

    func testMockRequiresTotalAndEachSubject() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let items = SessionPlanner.mock(catalog, unlocked: true).questions
        let answers = items.filter { $0.subject != "点検計画" }.map { answer($0.id, at: start, correct: true) }
        let result = SessionPlanner.mockResult(answers, questions: items, qualification: catalog.qualification)
        XCTAssertGreaterThanOrEqual(result.score * 100 / result.total, catalog.qualification.passingPercent)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(SessionPlanner.mockResult(items.map { answer($0.id, at: start, correct: true) }, questions: items, qualification: catalog.qualification).passed)
    }

    @MainActor func testPersistenceAndStatistics() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = try Catalog.load(id: "demo-safety")
        let store = StudyStore(qualificationID: catalog.qualification.id, directory: directory)
        store.record(answer(at: start, correct: true), question: catalog.questions[0])
        store.toggleBookmark("p01")
        store.completeOnboarding(diagnostic: true)
        let restored = StudyStore(qualificationID: catalog.qualification.id, directory: directory)
        XCTAssertEqual(restored.data.answers.count, 1)
        XCTAssertTrue(restored.data.bookmarks.contains("p01"))
        XCTAssertTrue(restored.data.diagnosticCompleted)
        let stats = StudyStats(catalog: catalog, data: restored.data, now: start)
        XCTAssertEqual(stats.new, 31)
        XCTAssertEqual(stats.studyDays, 1)
        XCTAssertLessThan(stats.readiness, 30)
    }

    func testPurchaseEntitlementRequiresExactVerifiedActivePermanentProduct() {
        let id = "qualification.unlock"
        let valid = PurchaseEntitlement(productID: id, verified: true, revoked: false, nonConsumable: true)
        XCTAssertFalse(PurchasePolicy.isUnlocked(productID: id, entitlements: []))
        XCTAssertFalse(PurchasePolicy.isUnlocked(productID: "other.unlock", entitlements: [valid]))
        XCTAssertFalse(PurchasePolicy.isUnlocked(productID: id, entitlements: [PurchaseEntitlement(productID: id, verified: false, revoked: false, nonConsumable: true)]))
        XCTAssertFalse(PurchasePolicy.isUnlocked(productID: id, entitlements: [PurchaseEntitlement(productID: id, verified: true, revoked: true, nonConsumable: true)]))
        XCTAssertFalse(PurchasePolicy.isUnlocked(productID: id, entitlements: [PurchaseEntitlement(productID: id, verified: true, revoked: false, nonConsumable: false)]))
        XCTAssertTrue(PurchasePolicy.isUnlocked(productID: id, entitlements: [valid]))
    }

    func testCatalogRejectsUnsupportedDataVersion() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        XCTAssertThrowsError(try Catalog(qualification: catalog.qualification,
                                         bank: QuestionBank(version: 2, questions: catalog.questions)))
    }

    func testSecondQualificationHasIndependentCatalog() throws {
        let folder = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "harbor-record", withExtension: nil))
        let qualification = try JSONDecoder().decode(Qualification.self, from: Data(contentsOf: folder.appendingPathComponent("qualification.json")))
        let bank = try JSONDecoder().decode(QuestionBank.self, from: Data(contentsOf: folder.appendingPathComponent("questions.json")))
        let catalog = try Catalog(qualification: qualification, bank: bank)
        XCTAssertEqual(catalog.qualification.name, "港湾安全記録士")
        XCTAssertEqual(catalog.questions.count, 12)
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: false).count, 6)
        XCTAssertEqual(SessionPlanner.mock(catalog, unlocked: true).questions.count, 6)
        XCTAssertEqual(SessionPlanner.diagnostic(catalog, unlocked: false).questions.count, 4)
        let storeKit = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("products.storekit"))) as? [String: Any])
        let products = try XCTUnwrap(storeKit["products"] as? [[String: Any]])
        XCTAssertEqual(products.first?["productID"] as? String, qualification.productID)
        XCTAssertEqual(products.first?["type"] as? String, "NonConsumable")
    }

    @MainActor func testCorruptHistoryRemainsUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("study-demo-safety.json")
        let corrupt = Data("broken history".utf8)
        try corrupt.write(to: url)
        let store = StudyStore(qualificationID: "demo-safety", directory: directory)
        XCTAssertTrue(store.readOnly)
        let catalog = try Catalog.load(id: "demo-safety")
        store.record(answer(at: start, correct: true), question: catalog.questions[0])
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testStatisticsRemainUsableWithLargeHistory() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        var data = StudyData()
        data.answers = (0..<20_000).map { n in
            answer(catalog.questions[n % 32].id, at: start.addingTimeInterval(Double(n) * 60), correct: n.isMultiple(of: 3))
        }
        let stats = StudyStats(catalog: catalog, data: data, now: start.addingTimeInterval(20_000 * 60))
        XCTAssertTrue((14...15).contains(stats.studyDays))
        XCTAssertEqual(stats.new, 32)
        XCTAssertLessThan(stats.readiness, 20)
    }

    @MainActor func testLargeHistoryPersistsAfterNewAnswer() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = try Catalog.load(id: "demo-safety")
        var history = StudyData()
        history.answers = (0..<10_000).map { n in
            answer(catalog.questions[n % 32].id, at: start.addingTimeInterval(Double(n)), correct: true)
        }
        try JSONEncoder().encode(history).write(to: directory.appendingPathComponent("study-demo-safety.json"))
        let store = StudyStore(qualificationID: "demo-safety", directory: directory)
        XCTAssertNil(store.error)
        store.record(answer(at: .now, correct: false, choice: 1), question: catalog.questions[0])
        XCTAssertNil(store.error)
        let restored = StudyStore(qualificationID: "demo-safety", directory: directory)
        XCTAssertEqual(restored.data.answers.count, 10_001)
        XCTAssertEqual(restored.data.mastery["p01"]?.attempts, 1)
    }

    @MainActor func testPendingSessionSurvivesRelaunchAndResetKeepsPreferences() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = try Catalog.load(id: "demo-safety")
        let store = StudyStore(qualificationID: "demo-safety", directory: directory)
        let session = StudySession(title: "2025年", mode: .year, questions: Array(catalog.questions.prefix(3)), timed: false)
        var progress = PendingStudy(session: session, createdAt: start)
        store.setPending(progress)
        let first = answer(at: start, correct: true)
        progress.answers = [first]
        progress.submitted = true
        progress.selectedIndex = 0
        store.record(first, question: session.questions[0], pending: progress)
        store.toggleBookmark("p01")
        store.setRecallFirst(false)
        store.setRandomScope(.unanswered)
        let restored = StudyStore(qualificationID: "demo-safety", directory: directory)
        XCTAssertEqual(restored.data.pending?.questionIDs, session.questions.map(\.id))
        XCTAssertEqual(restored.data.pending?.answers.count, 1)
        XCTAssertEqual(restored.data.pending?.selectedIndex, 0)
        XCTAssertTrue(restored.resetLearning())
        XCTAssertTrue(restored.data.answers.isEmpty)
        XCTAssertNil(restored.data.pending)
        XCTAssertTrue(restored.data.bookmarks.isEmpty)
        XCTAssertFalse(restored.data.onboardingCompleted)
        XCTAssertFalse(restored.data.recallFirst)
        XCTAssertEqual(restored.data.randomScope, .unanswered)
        XCTAssertNil(StudyStore(qualificationID: "demo-safety", directory: directory).data.pending)
    }

    func testExistingVersionOneHistoryDecodesWithoutNewKeys() throws {
        var history = StudyData()
        history.answers = [answer(at: start, correct: true)]
        history.bookmarks = ["p01"]
        let encoded = try JSONEncoder().encode(history)
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        dictionary.removeValue(forKey: "randomScope")
        dictionary.removeValue(forKey: "pending")
        let legacy = try JSONSerialization.data(withJSONObject: dictionary)
        let restored = try JSONDecoder().decode(StudyData.self, from: legacy)
        XCTAssertEqual(restored.answers.count, 1)
        XCTAssertEqual(restored.bookmarks, ["p01"])
        XCTAssertNil(restored.pending)
        XCTAssertEqual(restored.randomScope, .mixed)
    }

    func testSharedListsUseAppropriateOrderingAndDashboardCounts() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        var data = StudyData()
        let now = start.addingTimeInterval(day * 4)
        data.mastery["p01"] = Mastery(attempts: 1, lastAnswered: start, stabilityDays: 1,
                                        dueAt: start.addingTimeInterval(day), lastCorrect: true)
        data.mastery["w01"] = Mastery(attempts: 1, misconception: true, lastCorrect: false)
        let year = QuestionCollections.questions(for: .year(2025), catalog: catalog, data: data, now: now)
        XCTAssertEqual(year.count, 8)
        XCTAssertTrue(year.prefix(4).allSatisfy { $0.source.hasSuffix("問1") })
        XCTAssertEqual(QuestionCollections.questions(for: .status(.due), catalog: catalog, data: data, now: now).map(\.id), ["p01"])
        let stats = StudyStats(catalog: catalog, data: data, now: now)
        XCTAssertEqual(QuestionCollections.questions(for: .status(.new), catalog: catalog, data: data, now: now).count, stats.new)
        XCTAssertEqual(QuestionCollections.questions(for: .status(.misconception), catalog: catalog, data: data, now: now).count, stats.misconceptions)
        XCTAssertEqual(QuestionCollections.questions(for: .category("日常点検"), catalog: catalog, data: data, now: now).map(\.year), [2025, 2024, 2023, 2022])
    }

    func testResumptionRejectsPaidItemsWhenPurchaseMissingAndKeepsOrder() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let items = [catalog.questions[0], catalog.questions[12], catalog.questions[1]]
        let original = StudySession(title: "ランダム", mode: .random, questions: items, timed: false)
        var pending = PendingStudy(session: original)
        pending.index = 1
        XCTAssertEqual(QuestionCollections.resumedSession(pending, catalog: catalog, unlocked: true)?.questions.map(\.id), items.map(\.id))
        XCTAssertNil(QuestionCollections.resumedSession(pending, catalog: catalog, unlocked: false))
    }
}
