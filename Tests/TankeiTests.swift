import XCTest
@testable import ExamMaster

final class TankeiTests: XCTestCase {
    func testAmbientMotionIsBoundedAndContinuousAtSixtySamplesPerSecond() {
        var previous = TankeiFrame.ambient(at: 0)
        for tick in 1...1_800 {
            let frame = TankeiFrame.ambient(at: Double(tick) / 60)
            XCTAssertTrue((-1.81...0.01).contains(frame.lift))
            XCTAssertLessThanOrEqual(abs(frame.squash), 0.0071)
            XCTAssertLessThanOrEqual(abs(frame.wing), 1.81)
            XCTAssertLessThanOrEqual(abs(frame.sway), 0.451)
            XCTAssertTrue((0.119...1.001).contains(frame.eyeScale))
            XCTAssertLessThan(abs(frame.wing - previous.wing), 0.05)
            XCTAssertLessThan(abs(frame.lift - previous.lift), 0.03)
            previous = frame
        }
        XCTAssertEqual(TankeiFrame.ambient(at: .nan), TankeiFrame())
        XCTAssertEqual(TankeiFrame.ambient(at: 4.5, resting: true).eyeScale, 1)
    }

    func testMotionStopsForAccessibilityPowerVisibilityAndCoveredScreens() {
        XCTAssertTrue(TankeiMotionPolicy.allowsMotion(requested: true, reduceMotion: false, lowPower: false, active: true, visible: true, enabled: true))
        XCTAssertFalse(TankeiMotionPolicy.allowsMotion(requested: true, reduceMotion: true, lowPower: false, active: true, visible: true, enabled: true))
        XCTAssertFalse(TankeiMotionPolicy.allowsMotion(requested: true, reduceMotion: false, lowPower: true, active: true, visible: true, enabled: true))
        XCTAssertFalse(TankeiMotionPolicy.allowsMotion(requested: true, reduceMotion: false, lowPower: false, active: false, visible: true, enabled: true))
        XCTAssertFalse(TankeiMotionPolicy.allowsMotion(requested: true, reduceMotion: false, lowPower: false, active: true, visible: false, enabled: true))
        XCTAssertFalse(TankeiMotionPolicy.allowsMotion(requested: true, reduceMotion: false, lowPower: false, active: true, visible: true, enabled: false))
        XCTAssertFalse(TankeiMotionPolicy.allowsMotion(requested: false, reduceMotion: false, lowPower: false, active: true, visible: true, enabled: true))
    }

    func testExpressiveMotionHasMoreEnergyWithoutDiscontinuities() {
        var previous = TankeiFrame.ambient(at: 0, expressive: true)
        for tick in 1...1_800 {
            let time = Double(tick) / 60
            let frame = TankeiFrame.ambient(at: time, expressive: true)
            let quiet = TankeiFrame.ambient(at: time)
            XCTAssertEqual(frame.wing, quiet.wing * 3, accuracy: 0.0001)
            XCTAssertTrue((-5.41...0.01).contains(frame.lift))
            XCTAssertLessThanOrEqual(abs(frame.squash), 0.0211)
            XCTAssertLessThan(abs(frame.wing - previous.wing), 0.14)
            XCTAssertLessThan(abs(frame.lift - previous.lift), 0.08)
            XCTAssertEqual(frame.eyeScale, quiet.eyeScale)
            previous = frame
        }
    }

    func testDailyGoalCountsTodaysDistinctAvailableAnswersEvenWhenIncorrect() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 10))!
        let midnight = calendar.startOfDay(for: now)
        let yesterday = midnight.addingTimeInterval(-1)
        func dated(_ id: String, _ date: Date, correct: Bool = false) -> Answer {
            Answer(questionID: id, date: date, selectedIndex: 0, correct: correct,
                   duration: 10, confidence: nil, mode: .search)
        }
        var data = StudyData()
        data.answers = [dated("a", now), dated("a", now, correct: true), dated("b", yesterday),
                        dated("c", midnight), dated("locked", now)]
        let ids: Set<String> = ["a", "b", "c", "d", "e", "f"]
        let goal = TankeiDailyGoal(questionIDs: ids, data: data, short: true, now: now, calendar: calendar)
        XCTAssertEqual(goal.target, 5)
        XCTAssertEqual(goal.answeredIDs, ["a", "c"])
        XCTAssertEqual(goal.remaining, 3)
        XCTAssertFalse(goal.completed)
        data.answers += [dated("b", now), dated("d", now), dated("e", now)]
        XCTAssertTrue(TankeiDailyGoal(questionIDs: ids, data: data, short: true, now: now, calendar: calendar).completed)
        XCTAssertEqual(TankeiDailyGoal(questionIDs: ids, data: data, short: false, now: now, calendar: calendar).remaining, 1)
        XCTAssertFalse(TankeiDailyGoal(questionIDs: [], data: data, short: true, now: now).completed)
    }

    func testDailyRecommendationFillsFromQuestionsNotYetAnsweredToday() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let initial = SessionPlanner.recommended(catalog, data: StudyData(), unlocked: true)
        let excluded = Set(initial.questions.map(\.id))
        let next = SessionPlanner.recommended(catalog, data: StudyData(), unlocked: true, excluding: excluded)
        XCTAssertEqual(next.questions.count, 12)
        XCTAssertTrue(excluded.isDisjoint(with: next.questions.map(\.id)))
    }

    func testGreetingReflectsStudyStateAndRandomChoiceAvoidsImmediateRepeat() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let ids: Set<String> = ["a", "b"]
        var data = StudyData()
        func context(_ due: Int = 0) -> TankeiGreetingContext {
            .current(data: data, dailyGoal: TankeiDailyGoal(questionIDs: ids, data: data, short: true), dueCount: due)
        }
        XCTAssertEqual(context(), .firstStep)
        data.answers = [answer("a", correct: false)]
        XCTAssertEqual(context(), .retry)
        data.answers = [answer("a", correct: true)]
        XCTAssertEqual(context(1), .review)
        XCTAssertEqual(context(), .returning)
        data.answers.append(answer("b", correct: false))
        XCTAssertEqual(context(), .dailyDone)
        data.pending = PendingStudy(session: SessionPlanner.recommended(catalog, data: data, unlocked: false))
        XCTAssertEqual(context(), .resume)
        for item in TankeiGreetingContext.allCases {
            var previous = item.lines[0]
            for _ in 0..<20 {
                let chosen = item.choose(excluding: previous)
                XCTAssertTrue(item.lines.contains(chosen))
                XCTAssertNotEqual(chosen, previous)
                previous = chosen
            }
        }
    }

    private func answer(_ id: String, correct: Bool, at date: Date = .now) -> Answer {
        Answer(questionID: id, date: date, selectedIndex: 0, correct: correct,
               duration: 10, confidence: nil, mode: .recommended)
    }

    func testGrowthUsesRetentionAndReadinessRatherThanFirstSuccesses() throws {
        XCTAssertEqual(TankeiGrowth(retention: 0.5, readiness: 50).score, 0.5, accuracy: 0.0001)
        XCTAssertEqual(TankeiGrowth(retention: 1, readiness: 0).score, 0.4, accuracy: 0.0001)
        XCTAssertEqual(TankeiGrowth(retention: 0, readiness: 100).score, 0.6, accuracy: 0.0001)
        XCTAssertEqual(TankeiGrowth(retention: 1, readiness: 80).stage, .chicken)
        let catalog = try Catalog.load(id: "demo-safety")
        let free = SessionPlanner.available(catalog, unlocked: false)
        let now = Date()
        var data = StudyData()
        for question in free {
            let result = answer(question.id, correct: true, at: now)
            data.answers.append(result)
            data.mastery[question.id] = MasteryEngine.update(Mastery(), answer: result, difficulty: question.difficulty)
        }
        XCTAssertEqual(RetentionSummary(questions: free, data: data, now: now).stable, 0)
        XCTAssertNotEqual(TankeiGrowth(questions: free, data: data, now: now).stage, .chicken)
        let original = TankeiGrowth(questions: free, data: data, now: now).score
        let locked = try XCTUnwrap(catalog.questions.first { !catalog.qualification.freeQuestionIDs.contains($0.id) })
        data.answers += [answer(locked.id, correct: false, at: now), answer("removed", correct: false, at: now)]
        data.mastery[locked.id] = Mastery(attempts: 1, lastCorrect: false)
        XCTAssertEqual(TankeiGrowth(questions: free, data: data, now: now).score, original)
    }

    func testGrowthThresholdsAndEmptyScopeAreConservative() {
        XCTAssertEqual(TankeiStage.at(0), .chick)
        XCTAssertEqual(TankeiStage.at(0.2499), .chick)
        XCTAssertEqual(TankeiStage.at(0.25), .growingChick)
        XCTAssertEqual(TankeiStage.at(0.5999), .growingChick)
        XCTAssertEqual(TankeiStage.at(0.60), .youngChicken)
        XCTAssertEqual(TankeiStage.at(0.8499), .youngChicken)
        XCTAssertEqual(TankeiStage.at(0.85), .chicken)
        XCTAssertEqual(TankeiStage.at(.nan), .chick)
        let empty = TankeiGrowth(questions: [], data: StudyData())
        XCTAssertEqual(empty.score, 0)
        XCTAssertEqual(empty.stage, .chick)
        XCTAssertEqual(TankeiGrowth(retention: .nan, readiness: -100).score, 0)
        XCTAssertEqual(TankeiGrowth(retention: .infinity, readiness: 0).score, 0)
        XCTAssertEqual(TankeiGrowth(retention: -.infinity, readiness: 0).score, 0)
        XCTAssertEqual(TankeiGrowth(retention: 5, readiness: 500).score, 1)
    }

    func testFreeQuestionsCanCompleteGrowthWithoutPaying() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        let free = SessionPlanner.available(catalog, unlocked: false)
        let now = Date()
        var data = StudyData()
        for day in [-4.0, -2.0, 0.0] {
            for question in free {
                let result = answer(question.id, correct: true, at: now.addingTimeInterval(day * 86_400))
                data.answers.append(result)
                data.mastery[question.id] = MasteryEngine.update(data.mastery[question.id] ?? Mastery(), answer: result, difficulty: question.difficulty)
            }
        }
        let growth = TankeiGrowth(questions: free, data: data, now: now)
        XCTAssertEqual(growth.stage, .chicken)
        XCTAssertTrue(data.mocks.isEmpty)
        XCTAssertEqual(RetentionSummary(questions: free, data: data, now: now).stable, free.count)
    }

    func testSavedGrowthDoesNotRegressWhenMoreQuestionsAreUnlocked() {
        var data = StudyData()
        data.answers = [answer("a", correct: true), answer("b", correct: true)]
        data.mascotHighestStage = TankeiStage.chicken.rawValue
        let expanded = TankeiGrowth(retention: 0, readiness: 0, highestStage: data.mascotHighestStage)
        XCTAssertEqual(expanded.score, 0)
        XCTAssertEqual(expanded.stage, .chicken)
        data.mascotHighestStage = 999
        XCTAssertEqual(TankeiGrowth(retention: 0, readiness: 50, highestStage: data.mascotHighestStage).stage, .growingChick)
    }

    func testEarnedStageStaysFixedUntilGrowthIsCommitted() {
        XCTAssertEqual(TankeiGrowth(retention: 1, readiness: 100, earnedOnly: true).stage, .chick)
        XCTAssertEqual(TankeiGrowth(retention: 1, readiness: 100).stage, .chicken)
        XCTAssertEqual(TankeiGrowth(retention: 0, readiness: 0, highestStage: TankeiStage.youngChicken.rawValue,
                                    earnedOnly: true).stage, .youngChicken)
    }

    func testLegacyHistoryWithoutGrowthFieldKeepsItsAnswers() throws {
        var data = StudyData()
        data.answers = [answer("a", correct: true)]
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as? [String: Any])
        dictionary.removeValue(forKey: "mascotHighestStage")
        let restored = try JSONDecoder().decode(StudyData.self, from: JSONSerialization.data(withJSONObject: dictionary))
        XCTAssertEqual(restored.answers.count, 1)
        XCTAssertEqual(restored.mascotHighestStage, 0)
        XCTAssertTrue(restored.mascotNeedsMigration)
        XCTAssertEqual(TankeiGrowth(questions: [], data: restored).stage, .chick)
    }

    @MainActor func testGrowthPersistsPerQualificationAndResetsWithLearning() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = try Catalog.load(id: "demo-safety")
        let first = catalog.questions[0]
        let store = StudyStore(qualificationID: "growth-a", directory: directory)
        let now = Date()
        for day in [-4.0, -2.0, 0.0] {
            store.record(answer(first.id, correct: true, at: now.addingTimeInterval(day * 86_400)), question: first)
        }
        XCTAssertEqual(store.data.mascotHighestStage, TankeiStage.chick.rawValue)
        store.updateMascotGrowth(questions: [first], now: now)
        XCTAssertEqual(store.data.mascotHighestStage, TankeiStage.chicken.rawValue)
        let restored = StudyStore(qualificationID: "growth-a", directory: directory)
        XCTAssertEqual(restored.data.mascotHighestStage, TankeiStage.chicken.rawValue)
        XCTAssertEqual(StudyStore(qualificationID: "growth-b", directory: directory).data.mascotHighestStage, 0)
        restored.updateMascotGrowth(questions: catalog.questions, now: now.addingTimeInterval(60 * 86_400))
        XCTAssertEqual(restored.data.mascotHighestStage, TankeiStage.chicken.rawValue)
        XCTAssertTrue(restored.resetLearning())
        XCTAssertEqual(restored.data.mascotHighestStage, 0)
        XCTAssertTrue(restored.data.answers.isEmpty)
        XCTAssertEqual(StudyStore(qualificationID: "growth-a", directory: directory).data.mascotHighestStage, 0)
    }

    @MainActor func testLegacyGrowthMigrationWaitsForPendingStudyAndPreservesSavedStages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let catalog = try Catalog.load(id: "demo-safety")
        let free = SessionPlanner.available(catalog, unlocked: false)
        let now = Date()
        var legacy = StudyData()
        for question in free.prefix(8) {
            let result = answer(question.id, correct: true, at: now)
            legacy.answers.append(result)
            legacy.mastery[question.id] = MasteryEngine.update(Mastery(), answer: result, difficulty: question.difficulty)
        }
        legacy.pending = PendingStudy(session: StudySession(title: "演習", mode: .recommended, questions: free, timed: false))
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        dictionary.removeValue(forKey: "mascotHighestStage")
        let url = directory.appendingPathComponent("study-legacy-growth.json")
        try JSONSerialization.data(withJSONObject: dictionary).write(to: url)
        let original = try Data(contentsOf: url)
        let store = StudyStore(qualificationID: "legacy-growth", directory: directory)
        store.migrateMascotGrowthIfNeeded(questions: free, now: now)
        XCTAssertEqual(store.data.mascotHighestStage, 0)
        XCTAssertTrue(store.data.mascotNeedsMigration)
        XCTAssertEqual(try Data(contentsOf: url), original)
        store.clearPending()
        store.migrateMascotGrowthIfNeeded(questions: free, now: now)
        XCTAssertEqual(store.data.mascotHighestStage, TankeiStage.growingChick.rawValue)
        XCTAssertFalse(store.data.mascotNeedsMigration)
        XCTAssertEqual(store.data.answers.map(\.id), legacy.answers.map(\.id))
        let restored = StudyStore(qualificationID: "legacy-growth", directory: directory)
        XCTAssertFalse(restored.data.mascotNeedsMigration)
        XCTAssertEqual(restored.data.mascotHighestStage, TankeiStage.growingChick.rawValue)
        legacy.pending = nil
        legacy.mascotHighestStage = TankeiStage.youngChicken.rawValue
        try JSONEncoder().encode(legacy).write(to: url)
        let previouslyEarned = StudyStore(qualificationID: "legacy-growth", directory: directory)
        previouslyEarned.migrateMascotGrowthIfNeeded(questions: free, now: now)
        previouslyEarned.updateMascotGrowth(questions: free, now: now.addingTimeInterval(180 * 86_400))
        XCTAssertEqual(previouslyEarned.data.mascotHighestStage, TankeiStage.youngChicken.rawValue)
    }

    @MainActor func testCrossingThresholdDoesNotChangeStageUntilCompletionEvenAfterRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = try Catalog.load(id: "demo-safety")
        let free = SessionPlanner.available(catalog, unlocked: false)
        let store = StudyStore(qualificationID: "deferred-growth", directory: directory)
        let session = StudySession(title: "演習", mode: .recommended, questions: free, timed: false)
        store.setPending(PendingStudy(session: session))
        for question in free.prefix(8) { store.record(answer(question.id, correct: true), question: question) }
        XCTAssertEqual(TankeiGrowth(questions: free, data: store.data).stage, .growingChick)
        XCTAssertEqual(TankeiGrowth(questions: free, data: store.data, earnedOnly: true).stage, .chick)
        let restored = StudyStore(qualificationID: "deferred-growth", directory: directory)
        XCTAssertFalse(restored.data.mascotNeedsMigration)
        XCTAssertNotNil(restored.data.pending)
        XCTAssertEqual(TankeiGrowth(questions: free, data: restored.data, earnedOnly: true).stage, .chick)
        restored.clearPending()
        restored.updateMascotGrowth(questions: free)
        XCTAssertEqual(TankeiGrowth(questions: free, data: restored.data, earnedOnly: true).stage, .growingChick)
        XCTAssertEqual(StudyStore(qualificationID: "deferred-growth", directory: directory).data.mascotHighestStage,
                       TankeiStage.growingChick.rawValue)
    }

    func testDefaultChickenColorMatchesTheOriginal() throws {
        let catalog = try Catalog.load(id: "demo-safety")
        XCTAssertEqual(TankeiPalette.defaultChickenHex, "#FFF3DA")
        XCTAssertEqual(catalog.qualification.mascotColorHex, "#FFF3DA")
        XCTAssertEqual(catalog.qualification.iconDisplayTitle, catalog.qualification.name)
    }

    func testAllTwentyAutomaticGesturesAreFiniteDistinctAndStateAppropriate() {
        XCTAssertEqual(TankeiIdleAction.allCases.count, 20)
        var signatures: [TankeiFrame] = []
        for action in TankeiIdleAction.allCases {
            XCTAssertEqual(action.frame(at: 0, expressive: true), TankeiFrame())
            XCTAssertEqual(action.frame(at: 2.8, expressive: true), TankeiFrame())
            XCTAssertEqual(action.frame(at: .nan, expressive: true), TankeiFrame())
            let signature = action.frame(at: 1.0, expressive: true)
            XCTAssertFalse(signatures.contains(signature))
            signatures.append(signature)
            var previous = TankeiFrame()
            for tick in 1...168 {
                let frame = action.frame(at: Double(tick) / 60, expressive: true)
                XCTAssertLessThan(abs(frame.wing - previous.wing), 6)
                XCTAssertLessThan(abs(frame.lift - previous.lift), 3)
                XCTAssertLessThanOrEqual(abs(frame.wing), 40.01)
                XCTAssertLessThanOrEqual(abs(frame.sway), 9)
                XCTAssertGreaterThanOrEqual(frame.eyeScale, 0.14)
                XCTAssertEqual(frame.burst, 0)
                previous = frame
            }
        }
        var reachable: Set<TankeiIdleAction> = []
        for state in TankeiState.allCases {
            for stage in TankeiStage.allCases {
                let options = TankeiIdleAction.candidates(state: state, stage: stage)
                reachable.formUnion(options)
                var previous: TankeiIdleAction? = nil
                for _ in 0..<40 {
                    let next = TankeiIdleAction.choose(state: state, stage: stage, excluding: previous)
                    XCTAssertTrue(options.contains(next))
                    XCTAssertNotEqual(next, previous)
                    previous = next
                }
                if stage.isChick { XCTAssertFalse(options.contains(.flex)) }
                if state == .rest || state == .review || state == .recover {
                    XCTAssertFalse(options.contains(.bounce))
                    XCTAssertFalse(options.contains(.dance))
                }
            }
        }
        XCTAssertEqual(reachable, Set(TankeiIdleAction.allCases))
    }

    func testAnswerHistoryGroupsEveryAnswerByLocalDateInBothOrders() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 0))!
        let results = [answer("old", correct: false, at: today.addingTimeInterval(-1)),
                       answer("first", correct: true, at: today),
                       answer("last", correct: true, at: today.addingTimeInterval(60)),
                       answer("removed", correct: false, at: today.addingTimeInterval(-86_400 * 3))]
        let newest = AnswerHistoryDay.grouped(results, order: .newest, calendar: calendar)
        XCTAssertEqual(newest.count, 3)
        XCTAssertEqual(newest[0].answers.map(\.questionID), ["last", "first"])
        XCTAssertEqual(newest[1].answers.map(\.questionID), ["old"])
        XCTAssertEqual(newest.flatMap(\.answers).count, results.count)
        let oldest = AnswerHistoryDay.grouped(results, order: .oldest, calendar: calendar)
        XCTAssertEqual(oldest.map(\.date), newest.map(\.date).reversed())
        XCTAssertEqual(oldest[2].answers.map(\.questionID), ["first", "last"])
        XCTAssertTrue(AnswerHistoryDay.grouped([], order: .newest).isEmpty)
    }

    func testAnswerHistoryHandlesDaylightSavingAndEqualTimestampsWithoutLosingAnswers() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        XCTAssertEqual(tomorrow.timeIntervalSince(day), 25 * 3600)
        let results = [answer("before", correct: true, at: day.addingTimeInterval(-1)),
                       answer("tie-a", correct: true, at: day.addingTimeInterval(5_400)),
                       answer("tie-b", correct: false, at: day.addingTimeInterval(5_400)),
                       answer("late", correct: true, at: tomorrow.addingTimeInterval(-1)),
                       answer("next", correct: false, at: tomorrow)]
        let groups = AnswerHistoryDay.grouped(results, order: .newest, calendar: calendar)
        XCTAssertEqual(groups.map { $0.answers.count }, [1, 3, 1])
        XCTAssertEqual(groups.map(\.date), [tomorrow, day, calendar.startOfDay(for: day.addingTimeInterval(-1))])
        XCTAssertEqual(groups.flatMap(\.answers).count, results.count)
        let reordered = AnswerHistoryDay.grouped(results.reversed(), order: .newest, calendar: calendar)
        XCTAssertEqual(groups.flatMap(\.answers).map(\.id), reordered.flatMap(\.answers).map(\.id))
    }

    func testCompletedEffortIsAcknowledgedWithoutClaimingMastery() {
        XCTAssertEqual(TankeiState.completion(mode: .recommended, answered: 5, correct: 5, total: 5), .celebrate)
        XCTAssertEqual(TankeiState.completion(mode: .recommended, answered: 5, correct: 2, total: 5), .encourage)
        XCTAssertEqual(TankeiState.completion(mode: .recommended, answered: 5, correct: 0, total: 5), .recover)
        XCTAssertEqual(TankeiState.completion(mode: .recommended, answered: 0, correct: 0, total: 5), .rest)
        XCTAssertEqual(TankeiState.completion(mode: .recommended, answered: 2, correct: 2, total: 5), .rest)
        XCTAssertEqual(TankeiState.completion(mode: .recommended, answered: 0, correct: 0, total: 0), .rest)
    }

    func testDiagnosisAndMockRespectActualOutcome() {
        XCTAssertEqual(TankeiState.completion(mode: .diagnostic, answered: 8, correct: 0, total: 8), .ready)
        // A high overall score must not override the per-subject passing criteria.
        XCTAssertEqual(TankeiState.completion(mode: .mock, answered: 12, correct: 11, total: 12, mockPassed: false), .recover)
        XCTAssertEqual(TankeiState.completion(mode: .mock, answered: 12, correct: 10, total: 12, mockPassed: true), .celebrate)
        XCTAssertEqual(TankeiState.completion(mode: .mock, answered: 0, correct: 0, total: 12, mockPassed: true), .rest)
    }
}
