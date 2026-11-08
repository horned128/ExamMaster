import XCTest
@testable import DenkenThird

final class DenkenThirdTests: XCTestCase {
    private func catalog() throws -> Catalog { try Catalog.load(id: "denken3") }

    func testOfficialPapersAndAllFreeAssetsLoad() throws {
        let catalog = try catalog()
        XCTAssertEqual(catalog.questions.count, 320)
        XCTAssertEqual(catalog.mockSets.count, 16)
        XCTAssertEqual(catalog.qualification.subjects, ["理論", "電力", "機械", "法規"])
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: false).count, 320)
        XCTAssertFalse(catalog.qualification.ads.enabled)
        XCTAssertEqual(catalog.qualification.choiceLabel(4), "(5)")
        for question in catalog.questions {
            XCTAssertEqual(question.choices.count, 5)
            XCTAssertNotNil(question.points)
            XCTAssertTrue(question.validContent)
            if question.kind == .past {
                XCTAssertNotNil(question.sourceURL)
                XCTAssertTrue(question.source.contains("令和8年度上期"))
                XCTAssertTrue(question.allBlocks.contains { $0.type == .image })
            } else {
                XCTAssertNil(question.sourceURL)
                XCTAssertTrue(question.source.contains("オリジナル"))
                XCTAssertTrue(question.source.contains("令和8年度下期対策"))
                XCTAssertFalse(question.allBlocks.contains { $0.type == .image })
            }
        }
    }

    func testElectivePairsProduceExactlyOneHundredPointsAndRestore() throws {
        let catalog = try catalog()
        for set in catalog.mockSets where set.id.hasSuffix("theory") || set.id.hasSuffix("machine") {
            XCTAssertEqual(set.questionCount, 22)
            for choice in [17, 18] {
                let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: false,
                                                            electiveQuestionNumber: choice))
                XCTAssertEqual(session.questions.count, 20)
                XCTAssertEqual(session.questions.reduce(0) { $0 + ($1.points ?? 0) }, 100)
                XCTAssertEqual(session.questions.filter { $0.questionNumber == choice }.count, 2)
                XCTAssertFalse(session.questions.contains { $0.questionNumber == (choice == 17 ? 18 : 17) })
                let pending = PendingMock(session: session, minutes: set.minutes)
                let restored = try XCTUnwrap(MockExam.restore(pending, catalog: catalog, unlocked: false))
                XCTAssertEqual(restored.questions.map(\.id), session.questions.map(\.id))
            }
            XCTAssertNil(MockExam.session(set: set, catalog: catalog, unlocked: false, electiveQuestionNumber: 19))
        }
    }

    func testThreeOriginalRoundsAndCalendarYearTarget() throws {
        let catalog = try catalog()
        let originals=catalog.questions.filter { $0.kind == .prediction }
        XCTAssertEqual(originals.count,240)
        XCTAssertEqual(Set(originals.map(\.stem)).count,240)
        let yearItems=QuestionCollections.questions(for:.year(2027),catalog:catalog,data:StudyData())
        XCTAssertEqual(yearItems.count,240)
        XCTAssertTrue(yearItems.allSatisfy { $0.kind == .prediction })
        for round in 1...3 {
            let prefix=String(format:"d3-2027-pred-%02d-",round)
            let sets=catalog.mockSets.filter { $0.id.hasPrefix(prefix) }
            XCTAssertEqual(sets.count,4)
            XCTAssertEqual(sets.reduce(0) { $0+$1.questionCount },80)
            for set in sets {
                let session=try XCTUnwrap(MockExam.session(set:set,catalog:catalog,unlocked:false))
                var pending=PendingMock(session:session,minutes:set.minutes)
                for q in session.questions { pending.selections[q.id]=q.correctIndex }
                let graded=MockExam.grade(pending,questions:session.questions,qualification:catalog.qualification)
                XCTAssertEqual(graded.result.earnedPoints,100,set.id)
                XCTAssertEqual(graded.result.possiblePoints,100,set.id)
                XCTAssertTrue(graded.result.passed)
            }
        }
    }

    func testLawUsesOfficialSixAndSevenPointWeights() throws {
        let catalog = try catalog()
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id.hasSuffix("law") })
        let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: false))
        XCTAssertEqual(set.minutes, 65)
        XCTAssertEqual(session.questions.count, 16)
        XCTAssertEqual(session.questions.reduce(0) { $0 + ($1.points ?? 0) }, 100)
        // Ten A questions are 60 points but only 62.5% of the answer fields.
        var pending = PendingMock(session: session, minutes: 65)
        for q in session.questions where (q.questionNumber ?? 99) <= 10 {
            pending.selections[q.id] = q.correctIndex
        }
        let graded = MockExam.grade(pending, questions: session.questions, qualification: catalog.qualification)
        XCTAssertEqual(graded.result.score, 10)
        XCTAssertEqual(graded.result.earnedPoints, 60)
        XCTAssertEqual(graded.result.possiblePoints, 100)
        XCTAssertEqual(graded.result.percent, 60)
        XCTAssertTrue(graded.result.passed)
        XCTAssertEqual(graded.answers.count, 10)
        let encoded = try JSONEncoder().encode(graded.result)
        XCTAssertEqual(try JSONDecoder().decode(MockResult.self, from: encoded).percent, 60)

        // Nine A fields plus one 7-point B field gives 61 points, not 62.5.
        pending.selections.removeAll()
        for q in session.questions where (q.questionNumber ?? 99) <= 9 {
            pending.selections[q.id] = q.correctIndex
        }
        let seven = try XCTUnwrap(session.questions.first { $0.points == 7 })
        pending.selections[seven.id] = seven.correctIndex
        let mixed = MockExam.grade(pending, questions: session.questions, qualification: catalog.qualification)
        XCTAssertEqual(mixed.result.earnedPoints, 61)
        XCTAssertEqual(mixed.result.percent, 61)
    }

    func testBlankLawExamIsZeroAndPowerPaperIsComplete() throws {
        let catalog = try catalog()
        for set in catalog.mockSets {
            let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: false))
            let pending = PendingMock(session: session, minutes: set.minutes)
            let result = MockExam.grade(pending, questions: session.questions, qualification: catalog.qualification)
            XCTAssertEqual(result.result.earnedPoints, 0)
            XCTAssertEqual(result.result.possiblePoints, 100)
            XCTAssertFalse(result.result.passed)
            XCTAssertTrue(result.answers.isEmpty)
            if set.id.hasSuffix("power") { XCTAssertEqual(session.questions.count, 20); XCTAssertEqual(set.minutes, 90) }
        }
    }

    func testLegacyUnweightedScoresRemainCountBased() throws {
        let catalog = try catalog()
        var question = catalog.questions[0]
        question.points = nil
        let answer = Answer(questionID: question.id, date: .now, selectedIndex: question.correctIndex,
                            correct: true, duration: 1, confidence: nil, mode: .mock)
        let result = SessionPlanner.mockResult([answer], questions: [question], qualification: catalog.qualification)
        XCTAssertNil(result.earnedPoints)
        XCTAssertNil(result.possiblePoints)
        XCTAssertEqual(result.percent, 100)
        let legacy = """
        {"id":"00000000-0000-0000-0000-000000000001","date":0,"score":3,"total":4,"passed":true,"subjectScores":{}}
        """.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(MockResult.self, from: legacy).percent, 75)
    }
}
