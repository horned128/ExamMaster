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

    func testQualificationBrandingIsDataDrivenAndBackwardsCompatible() throws {
        let sample = try Catalog.load(id: "demo-safety")
        var config = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(sample.qualification)) as? [String: Any])
        config["id"] = "another-qualification"
        config["name"] = "別の資格名"
        config["mascotBaseHex"] = "#D7E8FF"
        let custom = try JSONDecoder().decode(Qualification.self, from: JSONSerialization.data(withJSONObject: config))
        XCTAssertNoThrow(try Catalog(qualification: custom, bank: QuestionBank(version: 1, questions: sample.questions)))
        XCTAssertEqual(custom.mascotColorHex, "#D7E8FF")
        XCTAssertEqual(custom.iconDisplayTitle, "別の資格名")
        config.removeValue(forKey: "mascotBaseHex")
        config["iconTitle"] = "別の\n資格"
        let legacy = try JSONDecoder().decode(Qualification.self, from: JSONSerialization.data(withJSONObject: config))
        XCTAssertEqual(legacy.mascotColorHex, TankeiPalette.defaultChickenHex)
        XCTAssertEqual(legacy.iconDisplayTitle, "別の\n資格")
        XCTAssertNoThrow(try Catalog(qualification: legacy, bank: QuestionBank(version: 1, questions: sample.questions)))
    }

    func testQualificationRejectsInvalidMascotColorsAndEmptyIconTitles() throws {
        let sample = try Catalog.load(id: "demo-safety")
        var config = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(sample.qualification)) as? [String: Any])
        for hex in ["#FFF", "#GGEEFF", ""] {
            config["mascotBaseHex"] = hex
            let qualification = try JSONDecoder().decode(Qualification.self, from: JSONSerialization.data(withJSONObject: config))
            XCTAssertThrowsError(try Catalog(qualification: qualification, bank: QuestionBank(version: 1, questions: sample.questions)))
        }
        config["mascotBaseHex"] = "#FFF3DA"
        config["iconTitle"] = " \n "
        let qualification = try JSONDecoder().decode(Qualification.self, from: JSONSerialization.data(withJSONObject: config))
        XCTAssertThrowsError(try Catalog(qualification: qualification, bank: QuestionBank(version: 1, questions: sample.questions)))
    }

    func testHomeRetentionUsesOnlyAvailableStableQuestions() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let free = SessionPlanner.available(catalog, unlocked: false)
        let paid = try XCTUnwrap(catalog.questions.first { !catalog.qualification.freeQuestionIDs.contains($0.id) })
        var data = StudyData()
        let stable = Mastery(attempts: 3, distinctSuccessDays: 3, lastAnswered: start, stabilityDays: 7, lastCorrect: true)
        for question in free.prefix(3) { data.mastery[question.id] = stable }
        data.mastery[paid.id] = stable
        data.mastery["removed-question"] = stable
        let summary = RetentionSummary(questions: free, data: data, now: start)
        XCTAssertEqual(summary.total, 12)
        XCTAssertEqual(summary.stable, 3)
        XCTAssertEqual(summary.growing, 0)
        XCTAssertEqual(summary.new, 9)
        XCTAssertEqual(summary.stable + summary.growing + summary.new, summary.total)
        XCTAssertEqual(summary.percent, 25)
        XCTAssertEqual(summary.fraction, 0.25)
        XCTAssertEqual(RetentionSummary(questions: catalog.questions, data: data, now: start).stable, 4)
        XCTAssertEqual(RetentionSummary(questions: free, data: data, now: start).stable,
                       QuestionCollections.questions(for: .status(.stable), catalog: catalog, data: data, now: start)
                        .filter { catalog.qualification.freeQuestionIDs.contains($0.id) }.count)
    }

    func testRetentionIsNotFirstSuccessGrowthAndDecays() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let free = SessionPlanner.available(catalog, unlocked: false)
        var data = StudyData()
        for question in free {
            let result = answer(question.id, at: start, correct: true)
            data.answers.append(result)
            data.mastery[question.id] = MasteryEngine.update(Mastery(), answer: result, difficulty: 1)
        }
        XCTAssertNotEqual(TankeiGrowth(questions: free, data: data, now: start).stage, .chicken)
        XCTAssertEqual(RetentionSummary(questions: free, data: data, now: start).percent, 0)
        for question in free {
            data.mastery[question.id] = Mastery(attempts: 3, distinctSuccessDays: 3, lastAnswered: start,
                                               stabilityDays: 7, lastCorrect: true)
        }
        XCTAssertEqual(RetentionSummary(questions: free, data: data, now: start).percent, 100)
        data.mastery[free[0].id]?.lastCorrect = false
        XCTAssertEqual(RetentionSummary(questions: free, data: data, now: start).stable, 11)
        XCTAssertEqual(RetentionSummary(questions: free, data: data, now: start.addingTimeInterval(day * 30)).percent, 0)
        let empty = RetentionSummary(questions: [], data: data, now: start)
        XCTAssertEqual(empty.percent, 0)
        XCTAssertEqual(empty.fraction, 0)
        XCTAssertEqual(empty.growing, 0)
        XCTAssertEqual(empty.new, 0)
    }

    func testMemoryBreakdownIsExclusiveAndIncludesMistakesAsLearning() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let free = SessionPlanner.available(catalog, unlocked: false)
        var data = StudyData()
        for question in free.prefix(2) {
            data.mastery[question.id] = Mastery(attempts: 3, distinctSuccessDays: 3, lastAnswered: start,
                                               stabilityDays: 7, dueAt: start, lastCorrect: true)
        }
        data.mastery[free[2].id] = MasteryEngine.update(Mastery(), answer: answer(free[2].id, at: start, correct: true), difficulty: 1)
        data.mastery[free[3].id] = MasteryEngine.update(Mastery(), answer: answer(free[3].id, at: start, correct: false,
                                                                            confidence: .sure), difficulty: 1)
        data.mastery["removed-question"] = Mastery(attempts: 1)
        let memory = RetentionSummary(questions: free, data: data, now: start)
        XCTAssertEqual(memory.stable, 2)
        XCTAssertEqual(memory.growing, 2)
        XCTAssertEqual(memory.new, 8)
        XCTAssertEqual(memory.stable + memory.growing + memory.new, 12)
        let expired = RetentionSummary(questions: free, data: data, now: start.addingTimeInterval(30 * day))
        XCTAssertEqual(expired.stable, 0)
        XCTAssertEqual(expired.growing, 4)
        XCTAssertEqual(expired.new, 8)
        let subjects = catalog.qualification.subjects.map { subject in
            RetentionSummary(questions: free.filter { $0.subject == subject }, data: data, now: start)
        }
        XCTAssertEqual(subjects.reduce(0) { $0 + $1.stable }, memory.stable)
        XCTAssertEqual(subjects.reduce(0) { $0 + $1.growing }, memory.growing)
        XCTAssertEqual(subjects.reduce(0) { $0 + $1.new }, memory.new)
        XCTAssertEqual(subjects.reduce(0) { $0 + $1.total }, memory.total)
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
        store.setExamDay(ExamDay(date: start))
        let restored = StudyStore(qualificationID: "demo-safety", directory: directory)
        XCTAssertEqual(restored.data.pending?.questionIDs, session.questions.map(\.id))
        XCTAssertEqual(restored.data.pending?.answers.count, 1)
        XCTAssertEqual(restored.data.pending?.selectedIndex, 0)
        XCTAssertNotNil(restored.data.examDay)
        XCTAssertTrue(restored.resetLearning())
        XCTAssertTrue(restored.data.answers.isEmpty)
        XCTAssertNil(restored.data.pending)
        XCTAssertTrue(restored.data.bookmarks.isEmpty)
        XCTAssertFalse(restored.data.onboardingCompleted)
        XCTAssertFalse(restored.data.recallFirst)
        XCTAssertEqual(restored.data.randomScope, .unanswered)
        XCTAssertNil(restored.data.examDay)
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
        dictionary.removeValue(forKey: "examDay")
        let legacy = try JSONSerialization.data(withJSONObject: dictionary)
        let restored = try JSONDecoder().decode(StudyData.self, from: legacy)
        XCTAssertEqual(restored.answers.count, 1)
        XCTAssertEqual(restored.bookmarks, ["p01"])
        XCTAssertNil(restored.pending)
        XCTAssertNil(restored.examDay)
        XCTAssertEqual(restored.randomScope, .mixed)
    }

    func testExamCountdownUsesCalendarDaysAcrossDaylightSavingAndTimeZones() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        let examDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9)))
        let exam = ExamDay(date: examDate, calendar: calendar)
        XCTAssertEqual(exam.daysRemaining(from: start, calendar: calendar), 3)
        XCTAssertEqual(exam.daysRemaining(from: examDate, calendar: calendar), 0)
        let next = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 11)))
        XCTAssertEqual(exam.daysRemaining(from: next, calendar: calendar), -1)
        let restored = try JSONDecoder().decode(ExamDay.self, from: JSONEncoder().encode(exam))
        XCTAssertEqual(restored, exam)
        var japan = Calendar(identifier: .gregorian)
        japan.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        XCTAssertEqual(restored.date(calendar: japan).map { japan.component(.day, from: $0) }, 10)
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

    func testReviewOutlookCountsOnlyAvailableQuestionsAndGroupsNextDay() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let free = SessionPlanner.available(catalog, unlocked: false)
        let paid = try XCTUnwrap(catalog.questions.first { !catalog.qualification.freeQuestionIDs.contains($0.id) })
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 12)))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
        var data = StudyData()
        data.mastery[free[0].id] = Mastery(dueAt: now.addingTimeInterval(-day))
        data.mastery[free[1].id] = Mastery(dueAt: now)
        data.mastery[free[2].id] = Mastery(dueAt: tomorrow)
        data.mastery[free[3].id] = Mastery(dueAt: tomorrow.addingTimeInterval(3600))
        data.mastery[free[4].id] = Mastery(dueAt: tomorrow.addingTimeInterval(day))
        data.mastery[paid.id] = Mastery(dueAt: now)
        data.mastery["removed-question"] = Mastery(dueAt: now)
        let outlook = ReviewOutlook(questions: free, data: data, now: now, calendar: calendar)
        XCTAssertEqual(outlook.dueCount, 2)
        XCTAssertEqual(outlook.nextDate, tomorrow)
        XCTAssertEqual(outlook.nextCount, 2)
        XCTAssertEqual(ReviewOutlook.label(for: tomorrow, now: now, calendar: calendar), "明日")
        XCTAssertEqual(ReviewOutlook(questions: catalog.questions, data: data, now: now, calendar: calendar).dueCount, 3)
    }

    func testReviewOutlookHandlesEmptyAndSameDayWithoutPretendingTomorrow() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let empty = ReviewOutlook(questions: catalog.questions, data: StudyData(), now: start)
        XCTAssertEqual(empty.dueCount, 0)
        XCTAssertNil(empty.nextDate)
        XCTAssertEqual(empty.nextCount, 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12)))
        XCTAssertEqual(ReviewOutlook.label(for: now, now: now, calendar: calendar), "今")
        XCTAssertEqual(ReviewOutlook.label(for: now.addingTimeInterval(3600), now: now, calendar: calendar), "今日中")
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
        XCTAssertEqual(ReviewOutlook.label(for: nextDay, now: now, calendar: calendar), "明日")
        let twoDays = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: now))
        XCTAssertEqual(ReviewOutlook.label(for: twoDays, now: now, calendar: calendar), "明後日")
    }

    func testDiagnosticComparisonDoesNotInventRankingForTiesOrMissingSubjects() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let questions = SessionPlanner.diagnostic(catalog, unlocked: false).questions
        let allWrong = questions.map { answer($0.id, at: start, correct: false) }
        let allCorrect = questions.map { answer($0.id, at: start, correct: true) }
        XCTAssertNil(SessionPlanner.diagnosticComparison(allWrong, questions: questions, subjects: catalog.qualification.subjects))
        XCTAssertNil(SessionPlanner.diagnosticComparison(allCorrect, questions: questions, subjects: catalog.qualification.subjects))
        XCTAssertNil(SessionPlanner.diagnosticComparison([], questions: [], subjects: catalog.qualification.subjects))
        let singleSubject = questions.filter { $0.subject == catalog.qualification.subjects[0] }
        XCTAssertNil(SessionPlanner.diagnosticComparison(allCorrect, questions: singleSubject, subjects: catalog.qualification.subjects))
    }

    func testDiagnosticComparisonReflectsOnlyTestedSubjectResults() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let questions = SessionPlanner.diagnostic(catalog, unlocked: false).questions
            .filter { catalog.qualification.subjects.prefix(2).contains($0.subject) }
        let best = catalog.qualification.subjects[0]
        let weakest = catalog.qualification.subjects[1]
        let answers = questions.map { answer($0.id, at: start, correct: $0.subject == best) }
        let comparison = try XCTUnwrap(SessionPlanner.diagnosticComparison(answers, questions: questions, subjects: catalog.qualification.subjects))
        XCTAssertEqual(comparison.best, best)
        XCTAssertEqual(comparison.weakest, weakest)
    }
}
