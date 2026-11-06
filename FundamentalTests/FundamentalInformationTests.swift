import XCTest
import StoreKitTest
@testable import FundamentalInformation

final class FundamentalInformationTests: XCTestCase {
    func testCompleteBankAndSubjectSpecificMocks() throws {
        let catalog = try Catalog.load(id: "fundamental-information")
        XCTAssertEqual(catalog.questions.count, 1004)
        XCTAssertEqual(catalog.mockSets.count, 31)
        XCTAssertEqual(catalog.qualification.subjects, ["科目A", "科目B"])
        XCTAssertEqual(catalog.questions.filter { $0.subject == "科目A" }.count, 740)
        XCTAssertEqual(catalog.questions.filter { $0.subject == "科目B" }.count, 264)
        XCTAssertTrue(catalog.questions.allSatisfy(\.validContent))
        for set in catalog.mockSets {
            let items = QuestionCollections.questions(for: .mockSet(set.id), catalog: catalog, data: StudyData())
            XCTAssertEqual(Set(items.map(\.subject)).count, 1, set.id)
            XCTAssertEqual(items.map(\.questionNumber), Array(1...set.questionCount).map(Optional.some))
            if set.kind == .prediction {
                let subjectA = items.first?.subject == "科目A"
                XCTAssertEqual(set.questionCount, subjectA ? 60 : 20)
                XCTAssertEqual(set.minutes, subjectA ? 90 : 100)
                if !subjectA {
                    XCTAssertEqual(items.filter { $0.category.contains("セキュリティ") }.count, 4)
                }
            } else {
                XCTAssertEqual(set.questionCount, items.first?.subject == "科目A" ? 20 : 6)
                XCTAssertTrue(set.title.contains("公開"))
            }
            XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: true)?.questions.count, set.questionCount)
        }
    }

    func testTodayPlanLimitsLongSubjectBReading() throws {
        let catalog = try Catalog.load(id: "fundamental-information")
        for unlocked in [false, true] {
            let plan = SessionPlanner.today(catalog, data: StudyData(), unlocked: unlocked)
            XCTAssertEqual(plan.session.questions.count, 10)
            XCTAssertLessThanOrEqual(plan.session.questions.filter { $0.subject == "科目B" }.count, 2)
        }
    }

    func testTenChoiceOfficialQuestionAndReadingBlocks() throws {
        let catalog = try Catalog.load(id: "fundamental-information")
        let question = try XCTUnwrap(catalog.questions.first { $0.id == "fe-2026-b-q06" })
        XCTAssertEqual(question.choices.count, 10)
        XCTAssertEqual(catalog.qualification.choiceLabel(9), "コ")
        XCTAssertEqual(question.choiceExplanations?.count, 10)
        XCTAssertTrue(catalog.questions.filter { $0.subject == "科目B" }.allSatisfy { !($0.bodyBlocks ?? []).isEmpty })
        XCTAssertTrue(catalog.questions.filter { $0.subject == "科目B" && $0.kind == .prediction }.contains {
            ($0.bodyBlocks ?? []).contains { $0.type == .monospace }
        })
    }

    func testFreeScopeAndIndependentPurchaseIdentity() throws {
        let catalog = try Catalog.load(id: "fundamental-information")
        let free = SessionPlanner.available(catalog, unlocked: false)
        XCTAssertEqual(free.count, 184)
        XCTAssertEqual(free.filter { $0.kind == .past }.count, 104)
        XCTAssertEqual(catalog.qualification.productID, "jp.hino.piyotre.fundamentalinformation.unlock")
        let ads = catalog.qualification.ads
        XCTAssertTrue(ads.enabled && ads.bannerEnabled && ads.interstitialEnabled)
        XCTAssertEqual(ads.adMobAppID, "ca-app-pub-9785585722959806~7250744489")
        XCTAssertEqual(ads.bannerAdUnitID, "ca-app-pub-9785585722959806/6962050007")
        XCTAssertEqual(ads.interstitialAdUnitID, "ca-app-pub-9785585722959806/1642449726")
        for set in catalog.mockSets {
            let expected = Set(set.questionIDs).isSubset(of: Set(catalog.qualification.freeQuestionIDs))
            XCTAssertEqual(MockExam.session(set: set, catalog: catalog, unlocked: false) != nil, expected)
        }
    }

    func testBrowsePartitionsWithoutDroppingEitherSubject() throws {
        let catalog = try Catalog.load(id: "fundamental-information")
        var ids: [String] = []
        for subject in catalog.qualification.subjects {
            let topics = StudyTopic.grouped(subject: subject, questions: catalog.questions)
            XCTAssertLessThanOrEqual(topics.count, 6)
            for topic in topics {
                let groups = StudySubtopic.grouped(topic: topic)
                XCTAssertEqual(groups.flatMap(\.questions).count, topic.questions.count)
                ids += groups.flatMap { $0.questions.map(\.id) }
            }
        }
        XCTAssertEqual(Set(ids).count, catalog.questions.count)
        // 2026 contains both public excerpts and original mocks; all stay reachable.
        let current = QuestionCollections.questions(for: .year(2026), catalog: catalog, data: StudyData())
        XCTAssertTrue(current.contains { $0.kind == .past })
        XCTAssertTrue(current.contains { $0.kind == .prediction })
    }

    @MainActor func testDedicatedPurchaseAndRestoreUnlockBothSubjects() async throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let catalog = try Catalog.load(id: "fundamental-information")
        let manager = PurchaseManager(productID: catalog.qualification.productID)
        await manager.refresh()
        XCTAssertNotNil(manager.product)
        XCTAssertFalse(manager.unlocked)
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: manager.unlocked).count, 184)
        await manager.buy()
        await manager.refreshEntitlement()
        XCTAssertTrue(manager.unlocked, manager.error ?? "購入権限を確認できません")
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: manager.unlocked).count, 1004)
        let restored = PurchaseManager(productID: catalog.qualification.productID)
        await restored.restore()
        XCTAssertTrue(restored.unlocked, restored.error ?? "復元権限を確認できません")
    }
}
