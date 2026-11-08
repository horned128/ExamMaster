import XCTest
@testable import EmbeddedSpecialist

final class EmbeddedSpecialistTests: XCTestCase {
    private func catalog() throws -> Catalog { try Catalog.load(id: "embedded-specialist") }

    func testBankLoadsWithEveryFigure() throws {
        let catalog = try catalog()
        XCTAssertEqual(catalog.questions.count, 300)
        XCTAssertEqual(catalog.qualification.subjects, ["午前II"])
        XCTAssertEqual(catalog.questions.filter { $0.kind == .past }.count, 198)
        XCTAssertEqual(catalog.questions.filter { $0.kind == .original }.count, 102)
        XCTAssertTrue(catalog.hasGlossary)
        XCTAssertFalse(catalog.hasTextbook)
        for question in catalog.questions {
            XCTAssertEqual(question.choices.count, 4, question.id)
            XCTAssertEqual(question.choiceExplanations?.count, 4, question.id)
            XCTAssertNotNil(question.related, question.id)
            XCTAssertTrue(question.validContent, question.id)
        }
        let images = catalog.questions.flatMap(\.allBlocks).filter { $0.type == .image }
        XCTAssertEqual(images.count, 66)
        XCTAssertTrue(images.allSatisfy { $0.assetName.flatMap { ContentAsset.url(name: $0) } != nil })
    }

    func testSetsAreTheLibraryAndTwoAreFree() throws {
        let catalog = try catalog()
        let qualification = catalog.qualification
        XCTAssertEqual(qualification.resolvedLibraryStyle, .sets)
        XCTAssertEqual(qualification.libraryTabTitle, "セット")
        XCTAssertEqual(qualification.subcategoryDrill, true)
        XCTAssertEqual(catalog.mockSets.map(\.id), (1...12).map { String(format: "es-set-%02d", $0) })
        XCTAssertTrue(catalog.mockSets.allSatisfy { $0.questionCount == 25 && $0.minutes == 40 })
        let free = Set(qualification.freeQuestionIDs)
        XCTAssertEqual(free.count, 50)
        XCTAssertEqual(SessionPlanner.available(catalog, unlocked: false).count, 50)
        for set in catalog.mockSets {
            let isFree = ["es-set-01", "es-set-02"].contains(set.id)
            XCTAssertEqual(Set(set.questionIDs).isSubset(of: free), isFree, set.id)
            XCTAssertEqual(set.questionIDs.contains { free.contains($0) }, isFree, set.id)
        }
    }

    func testMockSetMatchesTheExamAndRestores() throws {
        let catalog = try catalog()
        let set = try XCTUnwrap(catalog.mockSets.first)
        let session = try XCTUnwrap(MockExam.session(set: set, catalog: catalog, unlocked: false))
        XCTAssertEqual(session.questions.count, 25)
        XCTAssertEqual(session.questions.map(\.questionNumber), Array(1...25))
        let restored = try XCTUnwrap(MockExam.restore(PendingMock(session: session, minutes: set.minutes),
                                                       catalog: catalog, unlocked: false))
        XCTAssertEqual(restored.questions.map(\.id), session.questions.map(\.id))
        let fields = Dictionary(grouping: session.questions) { $0.category.components(separatedBy: "／")[0] }
            .mapValues(\.count)
        XCTAssertEqual(fields["コンピュータ構成要素"], 4)
        XCTAssertEqual(fields["ストラテジ"], 4)
        XCTAssertEqual(fields["ネットワーク"], 2)
    }

    func testImportedMarkupAndTextbookLinks() throws {
        let catalog = try catalog()
        let first = try XCTUnwrap(catalog.questions.first { $0.id == "es-s01-q01" })
        XCTAssertEqual(first.correctIndex, 1)
        XCTAssertTrue(first.choiceExplanations?[1].hasPrefix("正しい") ?? false)
        XCTAssertTrue(first.explanation.contains("**共有バスを常に監視**"))
        XCTAssertTrue(first.choiceExplanations?[0].contains("==独立のメモリ空間==") ?? false)
        XCTAssertTrue(first.glossaryTermIDs?.contains("mesi") ?? false)
        let links = catalog.questions.flatMap { ($0.related ?? []) + ($0.explanationBlocks ?? []) }
            .compactMap(\.text).flatMap { InlineMarkup.parse($0).flatMap(\.runs) }.compactMap(\.link)
        XCTAssertFalse(links.isEmpty)
        for link in links {
            let location = try XCTUnwrap(TextbookLocation(url: link), link.absoluteString)
            XCTAssertTrue(location.chapter == "overview" || location.chapter.hasPrefix("basics-"), link.absoluteString)
        }
        XCTAssertTrue(catalog.questions.allSatisfy { InlineMarkup.plainText($0.explanation).contains("**") == false })
    }

    func testIdentityAndTheme() throws {
        let qualification = try catalog().qualification
        XCTAssertEqual(qualification.appDisplayName, "ピヨトレ！エンベデッドシステムスペシャリスト")
        XCTAssertEqual(Bundle.main.bundleIdentifier, "jp.hino.piyotre.embeddedspecialist")
        XCTAssertEqual(qualification.productID, "jp.hino.piyotre.embeddedspecialist.unlock")
        XCTAssertEqual(qualification.choiceLabel(3), "エ")
        XCTAssertTrue(qualification.ads.enabled)
        XCTAssertEqual(qualification.theme?.isValid, true)
    }

    /// 用語メモ resolves every precomputed term ID against the bundled glossary.
    func testGlossaryMemoTermsResolve() throws {
        let glossary = try XCTUnwrap(Glossary.main)
        XCTAssertEqual(glossary.terms.count, 993)
        let questions = try catalog().questions
        let withTerms = questions.filter { !($0.glossaryTermIDs ?? []).isEmpty }
        XCTAssertGreaterThan(withTerms.count, 250)
        for question in withTerms {
            let ids = question.glossaryTermIDs ?? []
            XCTAssertEqual(glossary.terms(ids: ids).map(\.id), ids, question.id)
        }
    }
}
