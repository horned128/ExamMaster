import XCTest
import StoreKitTest
import StoreKit
@testable import AppliedInformation

final class AppliedInformationTests: XCTestCase {
    func testReviewedReleaseScopeAndExamSizing() throws {
        let catalog = try Catalog.load(id: "applied-information")
        XCTAssertEqual(catalog.questions.count, 1760)
        XCTAssertEqual(catalog.mockSets.count, 22)
        XCTAssertEqual(catalog.qualification.freeQuestionIDs.count, 160)
        XCTAssertEqual(catalog.qualification.subjects, ["テクノロジ", "マネジメント", "ストラテジ"])
        for set in catalog.mockSets {
            XCTAssertEqual(set.questionCount, 80)
            XCTAssertEqual(set.minutes, 150)
            let questions = QuestionCollections.questions(for: .mockSet(set.id), catalog: catalog, data: StudyData())
            XCTAssertEqual(questions.map(\.questionNumber), Array(1...80))
            XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: true)?.questions.count, 80)
        }
        let past = catalog.questions.filter { $0.kind == .past }
        XCTAssertEqual(past.count, 1520)
        XCTAssertTrue(past.allSatisfy { $0.year >= 2016 })
        XCTAssertTrue(past.allSatisfy { $0.choiceExplanations?.count == 4 && !($0.steps ?? []).isEmpty })
        XCTAssertTrue(past.allSatisfy { !($0.bodyBlocks ?? []).isEmpty && $0.choices.count == 4 })
        XCTAssertTrue(catalog.questions.allSatisfy(\.validContent))
        let sqlChoices = try XCTUnwrap(past.first { $0.id == "ap-2023-autumn-q28" })
        XCTAssertEqual(sqlChoices.choiceBlocks?.count, 4)
        XCTAssertTrue(try XCTUnwrap(sqlChoices.choiceBlocks).allSatisfy { $0.first?.type == .monospace })
        let inventory = try XCTUnwrap(past.first { $0.id == "ap-2023-autumn-q29" })
        XCTAssertTrue((inventory.bodyBlocks ?? []).contains { $0.type == .monospace })
        XCTAssertEqual((inventory.bodyBlocks ?? []).filter { $0.type == .table }.count, 2)
        XCTAssertFalse((inventory.bodyBlocks ?? []).contains { $0.type == .image })
        let reviewed = past.filter { $0.year == 2024 || $0.year == 2025 }
        XCTAssertEqual(reviewed.count, 320)
        XCTAssertTrue(reviewed.allSatisfy {
            !$0.explanation.contains("詳細な理由解説は未収録") && $0.choiceExplanations?.count == 4 && !($0.steps ?? []).isEmpty
        })
        let lp = try XCTUnwrap(reviewed.first { $0.id == "ap-2025-autumn-q75" })
        XCTAssertEqual(lp.correctIndex, 2)
        XCTAssertTrue(lp.explanation.contains("x＝30、y＝15"))
        XCTAssertEqual(lp.bodyBlocks?.first?.type, .text)
        XCTAssertTrue((lp.bodyBlocks ?? []).contains { $0.type == .table })
        XCTAssertFalse((lp.bodyBlocks ?? []).contains { $0.type == .image })
        let avl = try XCTUnwrap(reviewed.first { $0.id == "ap-2025-spring-q06" })
        XCTAssertEqual(avl.correctIndex, 2)
        XCTAssertTrue(avl.explanation.contains("ほかの図も"))
        let lgpl = try XCTUnwrap(reviewed.first { $0.id == "ap-2025-spring-q16" })
        XCTAssertTrue(lgpl.explanation.contains("必須とは限らない"))
        XCTAssertEqual(catalog.questions.filter { $0.year == 2020 }.count, 80)
        XCTAssertTrue(catalog.questions.filter { $0.year == 2020 }.allSatisfy { $0.source.contains("10月") })
        XCTAssertTrue(catalog.questions.filter { $0.administration == "special" }.allSatisfy { $0.source.contains("特別") })
    }

    func testThreeDistinctOriginalMocksAndBalancedSubjects() throws {
        let catalog = try Catalog.load(id: "applied-information")
        let original = catalog.questions.filter { $0.kind == .prediction }
        XCTAssertEqual(original.count, 240)
        XCTAssertEqual(Set(original.map(\.stem)).count, 240)
        XCTAssertTrue(original.allSatisfy { $0.source.contains("IPA非公式") && $0.choiceExplanations?.count == 4 })
        for number in 1...3 {
            let id = String(format: "ap-2026-pred-%02d", number)
            let set = try XCTUnwrap(catalog.mockSets.first { $0.id == id })
            let questions = QuestionCollections.questions(for: .mockSet(id), catalog: catalog, data: StudyData())
            XCTAssertEqual(questions.filter { $0.subject == "テクノロジ" }.count, 50)
            XCTAssertEqual(questions.filter { $0.subject == "マネジメント" }.count, 10)
            XCTAssertEqual(questions.filter { $0.subject == "ストラテジ" }.count, 20)
            XCTAssertNil(MockExam.session(set: set, catalog: catalog, unlocked: false))
        }
    }

    func testFreeOfficialMocksAndPaidAccessStaySeparate() throws {
        let catalog = try Catalog.load(id: "applied-information")
        let free = SessionPlanner.available(catalog, unlocked: false)
        XCTAssertEqual(free.count, 160)
        XCTAssertTrue(free.allSatisfy { $0.year == 2025 && $0.kind == .past })
        for set in catalog.mockSets.filter({ $0.id.hasPrefix("ap-2025-") }) {
            XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: false)?.questions.count, 80)
        }
        let paid = try XCTUnwrap(catalog.mockSets.first { $0.id == "ap-2024-spring" })
        XCTAssertNil(MockExam.session(set: paid, catalog: catalog, unlocked: false))
        for subject in catalog.qualification.subjects {
            XCTAssertLessThanOrEqual(StudyTopic.grouped(subject: subject, questions: catalog.questions).count, 6)
        }
    }

    func testStudyMapSecondLevelPartitionsEveryQuestionExactlyOnce() throws {
        let catalog = try Catalog.load(id: "applied-information")
        var unreviewedCount = 0
        var partitionedIDs = [String]()
        for subject in catalog.qualification.subjects {
            let topics = StudyTopic.grouped(subject: subject, questions: catalog.questions)
            for topic in topics {
                let subtopics = StudySubtopic.grouped(topic: topic)
                XCTAssertFalse(subtopics.isEmpty, "\(topic.title)にサブカテゴリがありません")
                XCTAssertTrue(subtopics.allSatisfy { !$0.questions.isEmpty })
                XCTAssertEqual(subtopics.reduce(0) { $0 + $1.questions.count }, topic.questions.count)
                let ids = subtopics.flatMap { $0.questions.map(\.id) }
                XCTAssertEqual(Set(ids).count, topic.questions.count, "\(topic.title)で問題が重複分類されています")
                partitionedIDs.append(contentsOf: ids)
                unreviewedCount += subtopics.first { $0.title == StudySubtopic.unreviewedTitle }?.questions.count ?? 0

                for subtopic in subtopics {
                    let route = QuestionCollectionRoute.subjectSubtopic(subject, topic.title, subtopic.title)
                    let routedIDs = QuestionCollections.questions(for: route, catalog: catalog, data: StudyData()).map(\.id)
                    XCTAssertEqual(Set(routedIDs), Set(subtopic.questions.map(\.id)))
                }
            }
        }
        XCTAssertEqual(Set(partitionedIDs).count, catalog.questions.count)
        XCTAssertEqual(unreviewedCount, 0)
    }

    func test2022AnswerTableTranscriptionAndUnansweredMockScoring() throws {
        let catalog = try Catalog.load(id: "applied-information")
        let set = try XCTUnwrap(catalog.mockSets.first { $0.id == "ap-2022-spring" })
        let questions = QuestionCollections.questions(for: .mockSet(set.id), catalog: catalog, data: StudyData())
        let expected = "アアウアアエエエイエイウアアエウイウイエウウウウアウアウアアイウイアエエウエアイエウイウウエイアエアエアウアウエイアイアアエイウアアウウエエウウアウイエエアウエ"
        XCTAssertEqual(questions.map { catalog.qualification.choiceLabel($0.correctIndex) }.joined(), expected)
        let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: true))
        var pending = PendingMock(session: session, minutes: set.minutes)
        for q in questions.prefix(48) { pending.selections[q.id] = q.correctIndex }
        let grade = MockExam.grade(pending, questions: questions, qualification: catalog.qualification)
        XCTAssertTrue(grade.result.passed)
        XCTAssertEqual(grade.result.score, 48)
        XCTAssertEqual(grade.result.total, 80)
        XCTAssertEqual(grade.answers.count, 48)
        XCTAssertEqual(grade.result.questionResults?.filter { $0.outcome == .unanswered }.count, 32)
    }

    func testSubjectAOnlyResourcesAndTheme() throws {
        XCTAssertNil(Bundle.main.url(forResource: "written-booklets", withExtension: "json"))
        XCTAssertNil(Bundle.main.url(forResource: "WrittenResources", withExtension: nil))
        let qualification = try Catalog.load(id: "applied-information").qualification
        XCTAssertTrue(try XCTUnwrap(qualification.theme).isValid)
        XCTAssertEqual(qualification.chickBaseHex, "#C5B1EF")
        XCTAssertEqual(qualification.mascotColorHex, "#E5DEF7")
        XCTAssertFalse(qualification.ads.enabled)
        XCTAssertEqual(Bundle.main.bundleIdentifier, "jp.hino.piyotre.appliedinformation")
        XCTAssertNil(Bundle.main.url(forResource: "nw-2023-q05-frame", withExtension: "png", subdirectory: "Figures"))
    }

    @MainActor func testQualificationSpecificPurchaseAndRestore() async throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let catalog = try Catalog.load(id: "applied-information")
        let manager = PurchaseManager(productID: catalog.qualification.productID)
        await manager.refresh()
        XCTAssertNotNil(manager.product)
        XCTAssertFalse(manager.unlocked)
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: manager.unlocked).count, 160)
        await manager.buy()
        await manager.refreshEntitlement()
        XCTAssertTrue(manager.unlocked, manager.error ?? "購入権限が反映されませんでした")
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: manager.unlocked).count, 1760)
        let restored = PurchaseManager(productID: catalog.qualification.productID)
        await restored.restore()
        XCTAssertTrue(restored.unlocked, restored.error ?? "復元権限が反映されませんでした")
    }
}

@MainActor final class AppliedProductLoadingTests: XCTestCase {
    func testAppActivationRecoversRealAPProductAfterLocalNetworkFailure() async throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let id = try Catalog.load(id: "applied-information").qualification.productID
        let manager = PurchaseManager(productID: id)
        await manager.refresh()
        XCTAssertNil(manager.product)
        XCTAssertNotNil(manager.productLoadFailure)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await manager.refreshIfNeeded()
        XCTAssertEqual(manager.product?.id, id)
        XCTAssertEqual(manager.product?.price, 300)
        XCTAssertNil(manager.error)
        XCTAssertFalse(manager.unlocked)
    }
}
