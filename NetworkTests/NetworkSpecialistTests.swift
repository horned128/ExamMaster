import XCTest
import StoreKitTest
@testable import NetworkSpecialist

final class NetworkSpecialistTests: XCTestCase {
    private func questionsForEntitlement(_ catalog: Catalog, unlocked: Bool) -> [String] {
        SessionPlanner.available(catalog, unlocked: unlocked).map(\.id)
    }

    func testNetworkTopicMapUsesBroadThemesWithoutDuplicates() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        for subject in catalog.qualification.subjects {
            let topics = StudyTopic.grouped(subject: subject, questions: catalog.questions)
            XCTAssertLessThanOrEqual(topics.count, 6)
            let ids = topics.flatMap { $0.questions.map(\.id) }
            XCTAssertEqual(ids.count, Set(ids).count)
            XCTAssertEqual(Set(ids), Set(catalog.questions.filter { $0.subject == subject }.map(\.id)))
        }
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    func testPracticeStateFiltersKeepSourceOrderAndTreatZeroAttemptsAsUnlearned() throws {
        let pool = Array(try Catalog.load(id: "network-specialist").questions.prefix(6))
        var data = StudyData()
        data.mastery[pool[1].id] = Mastery()
        data.mastery[pool[2].id] = Mastery(attempts: 1, lastAnswered: start,
                                          dueAt: start.addingTimeInterval(86_400), lastCorrect: true)
        data.mastery[pool[3].id] = Mastery(attempts: 1, lastAnswered: start, lastCorrect: false)
        data.mastery[pool[4].id] = Mastery(attempts: 2, lastAnswered: start,
                                          dueAt: start.addingTimeInterval(-1), lastCorrect: true)
        data.mastery[pool[5].id] = Mastery(attempts: 3, distinctSuccessDays: 3, lastAnswered: start,
                                          stabilityDays: 14, dueAt: start.addingTimeInterval(86_400), lastCorrect: true)
        let expected: [(PracticeQuestionFilter, [Int])] = [
            (.all, [0, 1, 2, 3, 4, 5]), (.unlearned, [0, 1]), (.answered, [2, 3, 4, 5]),
            (.incorrect, [3]), (.needsReview, [3, 4]), (.mastered, [5])
        ]
        for (filter, indices) in expected {
            XCTAssertEqual(filter.questions(in: pool, data: data, now: start).map(\.id),
                           indices.map { pool[$0].id }, filter.title)
        }
        XCTAssertEqual(data.mastery[pool[1].id]?.attempts, 0)
        XCTAssertTrue(data.answers.isEmpty)
    }

    func testYearPracticeFilteringDoesNotAlterTheFixedMock() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let pool = QuestionCollections.questions(for: .year(2025), catalog: catalog, data: StudyData())
        var data = StudyData()
        for index in [19, 2] { data.mastery[pool[index].id] = Mastery(attempts: 1, lastCorrect: false) }
        let filtered = PracticeQuestionFilter.incorrect.questions(in: pool, data: data, now: start)
        XCTAssertEqual(filtered.map(\.questionNumber), [3, 20])
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "nw-2025-spring" })
        let mock = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: false))
        XCTAssertEqual(mock.questions.count, 25)
        XCTAssertEqual(mock.questions.map(\.questionNumber), Array(1...25))
        XCTAssertTrue(mock.timed)
        XCTAssertTrue(PracticeQuestionFilter.unlearned.questions(in: [], data: data, now: start).isEmpty)
    }

    func testVerified2025CatalogAndResources() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let questions = catalog.questions.filter { $0.year == 2025 && $0.kind == .past }
        XCTAssertEqual(questions.count, 25)
        XCTAssertEqual(questions.map(\.questionNumber), Array(1...25))
        XCTAssertTrue(Set(questions.map(\.id)).isSubset(of: Set(SessionPlanner.available(catalog, unlocked: false).map(\.id))))
        XCTAssertEqual(catalog.qualification.mockQuestionCount, 25)
        XCTAssertEqual(catalog.qualification.minimumSubjectPercent, 0)
        XCTAssertEqual(catalog.qualification.choiceLabel(0), "ア")
        XCTAssertEqual(catalog.qualification.choiceLabel(3), "エ")
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "nw-2025-spring" })
        XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: false)?.questions.map(\.id), questions.map(\.id))
        XCTAssertEqual(set.questionCount, 25)
        XCTAssertEqual(set.minutes, 40)
        XCTAssertTrue(catalog.questions.allSatisfy { $0.choiceExplanations?.count == 4 && $0.steps?.isEmpty == false })
        XCTAssertEqual(questions.flatMap(\.allBlocks).filter { $0.type == .image }.count, 6)
        let correct = [3, 1, 3, 1, 3, 1, 0, 2, 3, 3, 0, 0, 2, 2, 2, 2, 1, 2, 3, 1, 1, 1, 0, 3, 3]
        XCTAssertEqual(questions.map(\.correctIndex), correct)
    }

    func testReviewed2024OfficialMockAndHistoricalAnswerCaveat() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let questions = catalog.questions.filter { $0.year == 2024 && $0.kind == .past }
        XCTAssertEqual(questions.map(\.questionNumber), Array(1...25))
        XCTAssertEqual(questions.map(\.correctIndex), [2, 0, 1, 1, 3, 1, 3, 3, 0, 3, 2, 1, 1, 1, 1, 0, 3, 1, 3, 3, 0, 0, 0, 0, 3])
        XCTAssertTrue(Set(questions.map(\.id)).isSubset(of: Set(catalog.qualification.freeQuestionIDs)))
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "nw-2024-spring" })
        XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: false)?.questions.map(\.id), questions.map(\.id))
        let historical = try XCTUnwrap(questions.first { $0.questionNumber == 22 })
        XCTAssertTrue(historical.explanation.contains("当時の公式正答で採点"))
        XCTAssertTrue(historical.explanation.contains("32レーン"))
        XCTAssertEqual(questions.flatMap(\.allBlocks).filter { $0.type == .image }.count, 1)
        let table = try XCTUnwrap(questions.first { $0.questionNumber == 3 }?.bodyBlocks?.first { $0.type == .table })
        XCTAssertEqual(table.rows, [["3", "1.271"], ["4", "2.045"], ["5", "2.881"], ["6", "3.758"]])
        let bitChoices = try XCTUnwrap(questions.first { $0.questionNumber == 11 }?.choiceBlocks)
        XCTAssertTrue(bitChoices.allSatisfy { $0.first?.type == .monospace })
    }

    func testReviewed2023CatalogFiguresAndFreeOfficialMock() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let questions = catalog.questions.filter { $0.year == 2023 && $0.kind == .past }
        XCTAssertEqual(questions.map(\.questionNumber), Array(1...25))
        XCTAssertEqual(questions.map(\.correctIndex), [2, 2, 0, 0, 2, 3, 1, 3, 2, 2, 1, 2, 1, 3, 2, 1, 0, 3, 2, 1, 0, 3, 3, 1, 3])
        XCTAssertTrue(Set(questions.map(\.id)).isSubset(of: Set(catalog.qualification.freeQuestionIDs)))
        XCTAssertEqual(questions.flatMap(\.allBlocks).filter { $0.type == .image }.map(\.assetName),
                       ["nw-2023-q05-frame.png", "nw-2023-q09-esp.png", "nw-2023-q11-vlan.png"])
        let tableChoices = try XCTUnwrap(questions.first { $0.questionNumber == 15 }?.choiceBlocks)
        XCTAssertEqual(tableChoices.count, 4)
        XCTAssertEqual(tableChoices[2].first?.headers, ["IEEE 802.11n", "IEEE 802.11ac"])
        XCTAssertEqual(tableChoices[2].first?.rows, [["2.4GHz帯，5GHz帯", "5GHz帯"]])
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "nw-2023-spring" })
        XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: false)?.questions.map(\.id), questions.map(\.id))
        XCTAssertEqual(catalog.questions.count, 375)
        XCTAssertEqual(catalog.qualification.freeQuestionIDs.count, 75)
        XCTAssertEqual(Set(catalog.mockSets.map(\.id)), ["nw-2026-pred-01", "nw-2026-pred-02", "nw-2026-pred-03", "nw-2025-spring", "nw-2024-spring", "nw-2023-spring", "nw-2022-spring", "nw-2021-spring", "nw-2019-autumn", "nw-2018-autumn", "nw-2017-autumn", "nw-2016-autumn", "nw-2015-autumn", "nw-2014-autumn", "nw-2013-autumn"])
        let bankURL = try XCTUnwrap(Bundle.main.url(forResource: "questions", withExtension: "json"))
        XCTAssertEqual(try JSONDecoder().decode(QuestionBank.self, from: Data(contentsOf: bankURL)).isDraft, false)
    }

    func testOriginal2026PredictionIsCompleteAndPaid() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let questions = catalog.questions.filter { $0.year == 2026 }
        XCTAssertEqual(questions.count, 75)
        XCTAssertTrue(questions.allSatisfy { $0.kind == .prediction && $0.source.contains("ExamMaster オリジナル") })
        XCTAssertTrue(Set(questions.map(\.id)).isDisjoint(with: Set(catalog.qualification.freeQuestionIDs)))
        for number in 1...3 {
            let id = String(format: "nw-2026-pred-%02d", number)
            let set = try XCTUnwrap(catalog.mockSets.first { $0.id == id })
            let members = questions.filter { $0.mockSetID == id }
            XCTAssertEqual(members.count, 25)
            XCTAssertEqual(members.map(\.questionNumber), Array(1...25))
            XCTAssertEqual(members.filter { $0.difficulty <= 2 }.count, 5)
            XCTAssertEqual(members.filter { $0.difficulty == 3 }.count, 15)
            XCTAssertEqual(members.filter { $0.difficulty >= 4 }.count, 5)
            XCTAssertEqual(set.title, "2026年予想問題 第\(number)回")
            XCTAssertEqual(set.minutes, 40)
            XCTAssertNil(MockExam.session(set: set, catalog: catalog, unlocked: false))
            let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: true))
            XCTAssertEqual(session.questions.map(\.id), members.map(\.id))
            XCTAssertEqual(session.mockSetID, set.id)
        }
    }

    @MainActor func testPredictionSetCollectionsAndResultsStaySeparate() async throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(qualificationID: "forecast-three-sets", directory: directory)
        for number in 1...3 {
            let id = String(format: "nw-2026-pred-%02d", number)
            let set = try XCTUnwrap(catalog.mockSets.first { $0.id == id })
            let collection = QuestionCollections.questions(for: .mockSet(id), catalog: catalog, data: store.data)
            XCTAssertEqual(collection.map(\.id), set.questionIDs)
            let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: true))
            XCTAssertTrue(store.beginMock(session: session, minutes: set.minutes, now: start))
            for question in session.questions.prefix(number) {
                XCTAssertTrue(store.selectMock(question.correctIndex, question: question, attemptID: session.id, now: start))
            }
            let result = try XCTUnwrap(store.completeMock(attemptID: session.id, catalog: catalog, now: start.addingTimeInterval(60)))
            XCTAssertEqual(result.score, number)
            XCTAssertEqual(result.total, 25)
            XCTAssertEqual(result.setID, id)
            XCTAssertEqual(result.questionResults?.filter { $0.outcome == .unanswered }.count, 25-number)
            XCTAssertEqual(Set(result.questionResults?.map(\.questionID) ?? []), Set(set.questionIDs))
        }
        XCTAssertEqual(store.data.mocks.count, 3)
        XCTAssertEqual(store.data.answers.count, 6)
        XCTAssertEqual(Set(store.data.answers.map(\.questionID)).count, 6)
        XCTAssertTrue(QuestionCollections.questions(for: .mockSet("missing"), catalog: catalog, data: store.data).isEmpty)
    }

    @MainActor func testRemovedYearPreservesExistingAnswerHistory() async throws {
        let catalog = try Catalog.load(id: "network-specialist")
        XCTAssertTrue(catalog.questions.filter { $0.kind == .past }.allSatisfy { (2013...2025).contains($0.year) })
        XCTAssertFalse(catalog.questions.contains { $0.year == 2010 || $0.year == 2020 })
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var data = StudyData()
        let answer = Answer(questionID: "nw-2010-autumn-q23", date: start, selectedIndex: 3,
                            correct: true, duration: 10, confidence: .sure, mode: .year)
        data.answers = [answer]
        data.bookmarks.insert(answer.questionID)
        try JSONEncoder().encode(data).write(to: directory.appendingPathComponent("study-network-specialist.json"))
        let store = StudyStore(qualificationID: "network-specialist", directory: directory)
        XCTAssertEqual(store.data.answers.map(\.id), [answer.id])
        XCTAssertTrue(store.data.bookmarks.contains(answer.questionID))
        XCTAssertTrue(QuestionCollections.questions(for: .favorites, catalog: catalog, data: store.data).isEmpty)
    }

    func testReviewedPaidCatalogAndWholeMockGates() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let free = SessionPlanner.available(catalog, unlocked: false)
        let all = SessionPlanner.available(catalog, unlocked: true)
        XCTAssertEqual(free.count, 75)
        XCTAssertEqual(all.count, 375)
        let expected: [Int: [Int]] = [
            2013: [1, 3, 3, 1, 3, 1, 3, 1, 1, 3, 2, 3, 0, 1, 3, 2, 3, 1, 1, 1, 0, 1, 1, 1, 1],
            2014: [3, 1, 3, 1, 3, 0, 0, 1, 1, 2, 0, 3, 0, 2, 1, 1, 1, 1, 2, 3, 2, 3, 3, 0, 2],
            2016: [3, 2, 2, 1, 0, 0, 2, 3, 3, 3, 2, 1, 0, 1, 3, 3, 0, 0, 0, 2, 1, 1, 2, 2, 2],
            2017: [2, 3, 1, 2, 3, 0, 1, 3, 3, 0, 2, 1, 0, 2, 1, 3, 0, 3, 1, 1, 0, 2, 2, 0, 3],
            2019: [0, 1, 1, 3, 0, 0, 3, 1, 1, 3, 2, 1, 2, 3, 2, 3, 2, 0, 2, 0, 0, 3, 0, 2, 1],
            2021: [3, 1, 3, 2, 0, 0, 2, 0, 1, 2, 3, 2, 3, 1, 2, 1, 1, 0, 0, 1, 1, 1, 2, 1, 0],
            2022: [3, 0, 0, 3, 0, 1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 3, 1, 2, 1, 3, 0, 3, 0, 0, 3]
        ]
        for year in [2013, 2014, 2016, 2017, 2019, 2021, 2022] {
            let questions = catalog.questions.filter { $0.year == year }
            XCTAssertEqual(questions.count, 25)
            XCTAssertEqual(questions.map(\.questionNumber), Array(1...25))
            XCTAssertEqual(questions.map(\.correctIndex), expected[year])
            XCTAssertTrue(questions.allSatisfy { !free.contains($0) && all.contains($0) })
            XCTAssertTrue(questions.allSatisfy { !catalog.qualification.freeQuestionIDs.contains($0.id) })
            let period = year < 2020 ? "autumn" : "spring"
            let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "nw-\(year)-\(period)" })
            XCTAssertEqual(set.questionCount, 25)
            XCTAssertEqual(set.minutes, 40)
            XCTAssertNil(MockExam.session(set: set, catalog: catalog, unlocked: false))
            let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: true))
            XCTAssertEqual(session.questions.map(\.id), questions.map(\.id))
            XCTAssertEqual(session.questions.map(\.choices), questions.map(\.choices))
            let pending = PendingMock(session: session, minutes: 40, now: start)
            XCTAssertNil(MockExam.restore(pending, catalog: catalog, unlocked: false))
            XCTAssertEqual(MockExam.restore(pending, catalog: catalog, unlocked: true)?.id, session.id)
            let study = PendingStudy(session: StudySession(title: "\(year)年", mode: .year, questions: questions, timed: false))
            XCTAssertFalse(Set(questionsForEntitlement(catalog, unlocked: false)).isSuperset(of: Set(study.questionIDs)))
            XCTAssertTrue(Set(questionsForEntitlement(catalog, unlocked: true)).isSuperset(of: Set(study.questionIDs)))
            for figure in questions.flatMap(\.allBlocks).filter({ $0.type == .image }) {
                XCTAssertNotNil(figure.assetName.flatMap { ContentAsset.url(name: $0) })
            }
        }
        let q2021 = catalog.questions.filter { $0.year == 2021 }
        XCTAssertEqual(q2021.flatMap(\.allBlocks).filter { $0.type == .image }.count, 3)
        XCTAssertEqual(q2021.first { $0.questionNumber == 22 }?.bodyBlocks?.last?.rows,
                       [["浮動小数点加算", "3", "20"], ["浮動小数点乗算", "5", "20"], ["整数演算", "2", "60"]])
        XCTAssertEqual(catalog.questions.filter { $0.year == 2022 }.flatMap(\.allBlocks).filter { $0.type == .image }.count, 1)
        XCTAssertEqual(catalog.questions.filter { $0.year == 2019 }.flatMap(\.allBlocks).filter { $0.type == .image }.count, 2)
        let q2016 = catalog.questions.filter { $0.year == 2016 }
        XCTAssertEqual(q2016.flatMap(\.allBlocks).filter { $0.type == .image }.map(\.assetName),
                       ["nw-2016-q03-capacity.png", "nw-2016-q04-ospf.png", "nw-2016-q07-esp.png", "nw-2016-q13-routing.png"])
        XCTAssertEqual(q2016.first { $0.questionNumber == 13 }?.bodyBlocks?.last?.rows?.last,
                       ["0.0.0.0", "0.0.0.0", "192.168.0.1"])
        XCTAssertEqual(q2016.first { $0.questionNumber == 20 }?.choiceBlocks?[2].first?.rows,
                       [["PC", "SMTPサーバ", "1024以上", "25"], ["SMTPサーバ", "PC", "25", "1024以上"]])
        let q2014 = catalog.questions.filter { $0.year == 2014 }
        XCTAssertEqual(q2014.flatMap(\.allBlocks).filter { $0.type == .image }.map(\.assetName),
                       ["nw-2014-q10-vlsm.png", "nw-2014-q24-a.png", "nw-2014-q24-i.png", "nw-2014-q24-u.png", "nw-2014-q24-e.png"])
        XCTAssertEqual(q2014.first { $0.questionNumber == 10 }?.choiceBlocks?[2].first?.rows,
                       [["172.16.1.128", "255.255.255.192"]])
        XCTAssertEqual(q2014.first { $0.questionNumber == 24 }?.choices,
                       ["m/S = (n−m)/T", "m/S = T/(n−m)", "m/S = n/T", "m/S = T/n"])
        let q2013 = catalog.questions.filter { $0.year == 2013 }
        XCTAssertEqual(q2013.flatMap(\.allBlocks).filter { $0.type == .image }.map(\.assetName),
                       ["nw-2013-q04-ospf.png", "nw-2013-q13-a.png", "nw-2013-q13-i.png", "nw-2013-q13-u.png", "nw-2013-q13-e.png", "nw-2013-q24-performance.png", "nw-2013-q25-class.png"])
        XCTAssertEqual(q2013.first { $0.questionNumber == 4 }?.choiceBlocks?[1].first?.rows, [["30", "30"]])
        XCTAssertEqual(q2013.first { $0.questionNumber == 16 }?.choiceBlocks?[2].first?.text,
                       "From: =?ISO-2022-JP?B?GyRCPnBKc0JATzobKEI=?= <taro@example.jp>")
    }

    func testReviewed2015HistoricalIPv6AndOriginalRelationImagesPaid() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let questions = catalog.questions.filter { $0.year == 2015 && $0.kind == .past }
        XCTAssertEqual(questions.map(\.questionNumber), Array(1...25))
        XCTAssertEqual(questions.map(\.correctIndex), [2, 2, 2, 2, 3, 1, 1, 1, 3, 0, 0, 3, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 2, 2, 2])
        let historical = try XCTUnwrap(questions.first { $0.questionNumber == 9 })
        XCTAssertTrue(historical.explanation.contains("当時の公式正答で採点"))
        XCTAssertTrue(historical.explanation.contains("2011年"))
        XCTAssertTrue(historical.explanation.contains("出題年より前"))
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "nw-2015-autumn" })
        XCTAssertEqual(set.questionCount, 25)
        XCTAssertEqual(set.minutes, 40)
        XCTAssertNil(MockExam.session(set: set, catalog: catalog, unlocked: false))
        XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: true)?.questions.map(\.id), questions.map(\.id))
        XCTAssertTrue(questions.allSatisfy { !catalog.qualification.freeQuestionIDs.contains($0.id) })
        let free = SessionPlanner.available(catalog, unlocked: false)
        XCTAssertTrue(questions.allSatisfy { !free.contains($0) })
        let pending = PendingStudy(session: StudySession(title: "2015年の問題", mode: .year, questions: questions, timed: false))
        XCTAssertFalse(Set(questionsForEntitlement(catalog, unlocked: false)).isSuperset(of: Set(pending.questionIDs)))
        XCTAssertTrue(Set(questionsForEntitlement(catalog, unlocked: true)).isSuperset(of: Set(pending.questionIDs)))
        let formula = try XCTUnwrap(questions.first { $0.questionNumber == 23 })
        XCTAssertEqual(formula.bodyBlocks?.last?.assetName, "nw-2015-q23-amdahl.png")
        let relation = try XCTUnwrap(questions.first { $0.questionNumber == 24 })
        XCTAssertEqual(relation.choiceBlocks?.flatMap { $0 }.map(\.assetName),
                       ["nw-2015-q24-a.png", "nw-2015-q24-i.png", "nw-2015-q24-u.png", "nw-2015-q24-e.png"])
        for block in questions.flatMap(\.allBlocks).filter({ $0.type == .image }) {
            XCTAssertNotNil(block.assetName.flatMap { ContentAsset.url(name: $0) })
        }
    }

    @MainActor func testHistoricalQuestionsGradeUsingOfficialKeysInFixedMocks() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(qualificationID: "historical-official-keys", directory: directory)
        for (id, official, alternative) in [("nw-2015-autumn-q09", 3, 0),
                                             ("nw-2018-autumn-q17", 2, 3),
                                             ("nw-2024-spring-q22", 0, 2)] {
            let question = try XCTUnwrap(catalog.questions.first { $0.id == id })
            let set = try XCTUnwrap(catalog.mockSets.first { $0.id == question.mockSetID })
            for selection in [official, alternative] {
                let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: true))
                XCTAssertTrue(store.beginMock(session: session, minutes: 40, now: start))
                XCTAssertTrue(store.selectMock(selection, question: question, attemptID: session.id, now: start))
                let result = try XCTUnwrap(store.completeMock(attemptID: session.id, catalog: catalog, now: start.addingTimeInterval(30)))
                XCTAssertEqual(result.score, selection == official ? 1 : 0)
                XCTAssertEqual(result.total, 25)
                let graded = try XCTUnwrap(result.questionResults?.first { $0.questionID == id })
                XCTAssertEqual(graded.outcome, selection == official ? .correct : .incorrect)
                XCTAssertEqual(store.data.answers.last?.correct, selection == official)
                XCTAssertEqual(result.questionResults?.filter { $0.outcome == .unanswered }.count, 24)
            }
        }
    }

    @MainActor func testPaid2021RealMockSavedSelectionsAndDeadlineGrading() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "nw-2021-spring" })
        let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: true))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(qualificationID: "paid-2021", directory: directory)
        XCTAssertTrue(store.beginMock(session: session, minutes: 40, now: start))
        for number in [4, 7, 10, 22, 23] {
            let question = session.questions[number - 1]
            XCTAssertTrue(store.selectMock(question.correctIndex, question: question, attemptID: session.id, now: start))
        }
        XCTAssertTrue(store.moveMock(to: 22, attemptID: session.id))
        XCTAssertTrue(store.data.answers.isEmpty)
        XCTAssertTrue(store.data.mastery.isEmpty)
        let restored = store
        let pending = try XCTUnwrap(restored.data.pendingMock)
        XCTAssertEqual(pending.index, 22)
        XCTAssertEqual(pending.selections.count, 5)
        XCTAssertNil(MockExam.restore(pending, catalog: catalog, unlocked: false))
        XCTAssertNotNil(MockExam.restore(pending, catalog: catalog, unlocked: true))
        XCTAssertEqual(pending.remaining(at: start.addingTimeInterval(2399)), 1)
        XCTAssertFalse(restored.selectMock(0, question: session.questions[0], attemptID: session.id,
                                          now: start.addingTimeInterval(2400)))
        let result = try XCTUnwrap(restored.completeMock(attemptID: session.id, catalog: catalog,
                                                       now: start.addingTimeInterval(2405)))
        XCTAssertEqual(result.score, 5)
        XCTAssertEqual(result.total, 25)
        XCTAssertEqual(result.duration, 2400)
        XCTAssertEqual(result.questionResults?.filter { $0.outcome == .unanswered }.count, 20)
        XCTAssertEqual(restored.data.answers.count, 5)
        XCTAssertEqual(restored.data.mastery.count, 5)
        XCTAssertNil(restored.data.mastery[session.questions[0].id])
        XCTAssertNil(restored.data.pendingMock)
        XCTAssertEqual(restored.completeMock(attemptID: session.id, catalog: catalog)?.id, result.id)
        XCTAssertEqual(StudyStore(qualificationID: "paid-2021", directory: directory).data.mocks.count, 1)
    }

    func testReviewed2018HistoricalEAPAndOfficialFiguresPaid() throws {
        let catalog = try Catalog.load(id: "network-specialist")
        let questions = catalog.questions.filter { $0.year == 2018 }
        XCTAssertEqual(questions.map(\.questionNumber), Array(1...25))
        XCTAssertEqual(questions.map(\.correctIndex), [2, 0, 0, 0, 0, 1, 1, 1, 2, 0, 1, 1, 1, 3, 3, 1, 2, 1, 0, 2, 1, 3, 1, 2, 0])
        let historical = try XCTUnwrap(questions.first { $0.questionNumber == 17 })
        XCTAssertTrue(historical.explanation.contains("当時の公式正答で採点"))
        XCTAssertTrue(historical.explanation.contains("RFC5281"))
        XCTAssertTrue(historical.explanation.contains("任意"))
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "nw-2018-autumn" })
        XCTAssertEqual(set.questionCount, 25)
        XCTAssertEqual(set.minutes, 40)
        XCTAssertNil(MockExam.session(set: set, catalog: catalog, unlocked: false))
        XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: true)?.questions.map(\.id), questions.map(\.id))
        XCTAssertTrue(questions.allSatisfy { !catalog.qualification.freeQuestionIDs.contains($0.id) })
        XCTAssertTrue(questions.allSatisfy { !SessionPlanner.available(catalog, unlocked: false).contains($0) })
        XCTAssertTrue(questions.allSatisfy { SessionPlanner.available(catalog, unlocked: true).contains($0) })
        XCTAssertEqual(questions.flatMap(\.allBlocks).filter { $0.type == .image }.map(\.assetName),
                       ["nw-2018-q04-mtu.png", "nw-2018-q06-arp.png"])
        for block in questions.flatMap(\.allBlocks) where block.type == .image {
            XCTAssertNotNil(block.assetName.flatMap { ContentAsset.url(name: $0) })
        }
        let pending = PendingStudy(session: StudySession(title: "2018年の問題", mode: .year, questions: questions, timed: false))
        XCTAssertFalse(Set(questionsForEntitlement(catalog, unlocked: false)).isSuperset(of: Set(pending.questionIDs)))
        XCTAssertTrue(Set(questionsForEntitlement(catalog, unlocked: true)).isSuperset(of: Set(pending.questionIDs)))
        let formula = try XCTUnwrap(questions.first { $0.questionNumber == 23 }?.bodyBlocks?.first { $0.type == .formula })
        XCTAssertEqual(formula.text, "P = n / {1 + (n - 1)a}")
        XCTAssertTrue(questions.first { $0.questionNumber == 23 }?.stem.contains("オーバヘッドを表す定数") == true)
    }

    /// Synthetic 25-question set lives only in the test bundle, never the app bank.
    private func fixture() throws -> Catalog {
        let sample = try Catalog.load(id: "network-specialist")
        // Keep the fixture's free subset representative even as the real bank grows.
        let prototypeNumbers = [1, 3, 5, 6, 8, 12, 16, 20, 23, 24]
        let prototypes = try prototypeNumbers.map { number in
            try XCTUnwrap(sample.questions.first { $0.id == String(format: "nw-2025-spring-q%02d", number) })
        }
        let questions = try (1...25).map { number -> Question in
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(prototypes[(number - 1) % prototypes.count])) as? [String: Any])
            json["id"] = "fixture-q\(number)"
            json["questionNumber"] = number
            json["mockSetID"] = "fixture-set"
            return try JSONDecoder().decode(Question.self, from: JSONSerialization.data(withJSONObject: json))
        }
        var configJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(sample.qualification)) as? [String: Any])
        configJSON["freeQuestionIDs"] = Array(questions.prefix(15)).map(\.id)
        let config = try JSONDecoder().decode(Qualification.self, from: JSONSerialization.data(withJSONObject: configJSON))
        let set = MockSet(id: "fixture-set", title: "テスト用25問", kind: .past, questionIDs: questions.map(\.id), questionCount: 25, minutes: 40)
        return try Catalog(qualification: config, bank: QuestionBank(version: 2, questions: questions, mockSets: [set]))
    }

    func testFixedOrderAndWholeSetPurchaseGate() throws {
        let catalog = try fixture()
        let set = catalog.mockSets[0]
        XCTAssertNil(MockExam.session(set: set, catalog: catalog, unlocked: false))
        let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: true))
        XCTAssertEqual(session.questions.map(\.id), set.questionIDs)
        XCTAssertEqual(session.questions.map(\.choices), catalog.questions.map(\.choices))
        var pending = PendingMock(session: session, minutes: 40, now: start)
        pending.index = 20
        XCTAssertNil(MockExam.restore(pending, catalog: catalog, unlocked: false))
        XCTAssertEqual(MockExam.restore(pending, catalog: catalog, unlocked: true)?.id, session.id)
        XCTAssertEqual(pending.remaining(at: start.addingTimeInterval(900)), 1500)
    }

    @MainActor func testDeferredAtomicGradingChangesSkipsDeadlineAndIdempotence() throws {
        let catalog = try fixture()
        let session = try XCTUnwrap(MockExam.session(set: catalog.mockSets[0], catalog: catalog, unlocked: true))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(qualificationID: "test-nw", directory: directory)
        XCTAssertTrue(store.beginMock(session: session, minutes: 40, now: start))
        for question in session.questions.prefix(15) {
            XCTAssertTrue(store.selectMock((question.correctIndex + 1) % 4, question: question, attemptID: session.id, now: start))
            XCTAssertTrue(store.selectMock(question.correctIndex, question: question, attemptID: session.id, now: start))
        }
        let skipped = session.questions[15]
        XCTAssertTrue(store.selectMock(0, question: skipped, attemptID: session.id, now: start))
        XCTAssertTrue(store.selectMock(nil, question: skipped, attemptID: session.id, now: start))
        XCTAssertTrue(store.moveMock(to: 24, attemptID: session.id))
        XCTAssertTrue(store.data.answers.isEmpty)
        XCTAssertTrue(store.data.mastery.isEmpty)
        let restored = store
        XCTAssertEqual(restored.data.pendingMock?.index, 24)
        XCTAssertEqual(restored.data.pendingMock?.selections.count, 15)
        let expired = start.addingTimeInterval(2500)
        XCTAssertFalse(restored.selectMock(0, question: skipped, attemptID: session.id, now: expired))
        let result = try XCTUnwrap(restored.completeMock(attemptID: session.id, catalog: catalog, now: expired))
        XCTAssertEqual(result.score, 15)
        XCTAssertEqual(result.percent, 60)
        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.duration, 2400)
        XCTAssertEqual(result.date, start.addingTimeInterval(2400))
        XCTAssertEqual(result.questionResults?.filter { $0.outcome == .unanswered }.count, 10)
        XCTAssertEqual(restored.data.answers.count, 15)
        XCTAssertNil(restored.data.mastery[skipped.id])
        XCTAssertNil(restored.data.pendingMock)
        XCTAssertEqual(restored.completeMock(attemptID: session.id, catalog: catalog)?.id, result.id)
        let relaunched = StudyStore(qualificationID: "test-nw", directory: directory)
        XCTAssertEqual(relaunched.data.mocks.count, 1)
        XCTAssertEqual(relaunched.data.answers.count, 15)
        XCTAssertTrue(relaunched.data.mastery.values.allSatisfy { $0.attempts == 1 })
    }

    @MainActor func testRetakesAppendAndWrongAnswersUpdateOnlyAtFinish() throws {
        let catalog = try fixture()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(qualificationID: "retakes", directory: directory)
        for count in [0, 14, 15, 25] {
            let session = try XCTUnwrap(MockExam.session(set: catalog.mockSets[0], catalog: catalog, unlocked: true))
            XCTAssertTrue(store.beginMock(session: session, minutes: 40, now: start))
            for (position, question) in session.questions.enumerated() {
                store.selectMock(position < count ? question.correctIndex : (question.correctIndex + 1) % 4,
                                 question: question, attemptID: session.id, now: start)
            }
            let previous = store.data.answers.count
            XCTAssertEqual(previous, store.data.mocks.count * 25)
            let result = try XCTUnwrap(store.completeMock(attemptID: session.id, catalog: catalog, now: start.addingTimeInterval(60)))
            XCTAssertEqual(result.passed, count >= 15)
            XCTAssertEqual(result.score, count)
        }
        XCTAssertEqual(store.data.mocks.map(\.score), [0, 14, 15, 25])
        XCTAssertEqual(Set(store.data.mocks.map(\.id)).count, 4)
    }

    @MainActor func testSaveFailureKeepsAttemptAndDoesNotMutateHistory() throws {
        let catalog = try fixture()
        let session = try XCTUnwrap(MockExam.session(set: catalog.mockSets[0], catalog: catalog, unlocked: true))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(qualificationID: "failure", directory: directory)
        store.beginMock(session: session, minutes: 40, now: start)
        try FileManager.default.removeItem(at: store.url)
        try FileManager.default.createDirectory(at: store.url, withIntermediateDirectories: false)
        XCTAssertNil(store.completeMock(attemptID: session.id, catalog: catalog, now: start))
        XCTAssertNotNil(store.error)
        XCTAssertNotNil(store.data.pendingMock)
        XCTAssertTrue(store.data.answers.isEmpty)
        XCTAssertTrue(store.data.mocks.isEmpty)
    }

    func testLegacyStudyAndResultDecode() throws {
        let json = """
        {"schemaVersion":1,"answers":[],"mastery":{},"bookmarks":[],"mocks":[{"id":"CC000000-0000-0000-0000-000000000001","date":0,"score":1,"total":2,"passed":false,"subjectScores":{}}],"onboardingCompleted":true,"diagnosticCompleted":false,"recallFirst":true}
        """
        let data = try JSONDecoder().decode(StudyData.self, from: Data(json.utf8))
        XCTAssertNil(data.pendingMock)
        XCTAssertNil(data.mocks[0].questionResults)
        XCTAssertEqual(data.mocks[0].score, 1)
    }

    func testRejectsBrokenRichContentAndSetReferences() throws {
        let catalog = try fixture()
        var questions = catalog.questions
        questions[0].choiceBlocks = [[]]
        XCTAssertThrowsError(try Catalog(qualification: catalog.qualification, bank: QuestionBank(version: 2, questions: questions)))
        questions = catalog.questions
        questions[0].bodyBlocks = [ContentBlock(type: .image, assetName: "../missing.png", altText: "図")]
        XCTAssertFalse(questions[0].validContent)
        let invalidSet = MockSet(id: "bad", title: "不正", kind: .past, questionIDs: ["missing"], questionCount: 25, minutes: 40)
        XCTAssertThrowsError(try Catalog(qualification: catalog.qualification, bank: QuestionBank(version: 2, questions: catalog.questions, mockSets: [invalidSet])))
    }

    @MainActor func testNetworkPurchaseRestoreAndDedicatedPrice() async throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let config = try Catalog.load(id: "network-specialist").qualification
        let catalog = try Catalog.load(id: "network-specialist")
        let paidID = "nw-2026-pred-01-q01"
        let manager = PurchaseManager(productID: config.productID)
        await manager.refresh()
        XCTAssertEqual(try XCTUnwrap(manager.product).price, 300)
        XCTAssertTrue(manager.entitlementResolved)
        XCTAssertFalse(manager.unlocked)
        XCTAssertFalse(SessionPlanner.available(catalog, unlocked: manager.unlocked).contains { $0.id == paidID })
        await manager.buy()
        await manager.refreshEntitlement()
        XCTAssertTrue(manager.unlocked)
        XCTAssertTrue(SessionPlanner.available(catalog, unlocked: manager.unlocked).contains { $0.id == paidID })
        let restored = PurchaseManager(productID: config.productID)
        await restored.restore()
        XCTAssertTrue(restored.unlocked)
        XCTAssertTrue(SessionPlanner.available(catalog, unlocked: restored.unlocked).contains { $0.id == paidID })
        session.clearTransactions()
        // Local StoreKit clearing can return before currentEntitlements reflects
        // it. Require the real entitlement to disappear within a bounded wait.
        for _ in 0..<50 {
            await restored.refreshEntitlement()
            if !restored.unlocked { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(restored.unlocked)
        XCTAssertFalse(SessionPlanner.available(catalog, unlocked: restored.unlocked).contains { $0.id == paidID })
    }
}
