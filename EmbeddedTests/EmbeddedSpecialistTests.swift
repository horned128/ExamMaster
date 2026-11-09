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
        XCTAssertTrue(catalog.hasTextbook)
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

    // MARK: - 教科書

    func testTextbookAndLayerMapLoad() throws {
        let textbook = try XCTUnwrap(Textbook.main)
        let map = try XCTUnwrap(LayerMap.main)
        XCTAssertTrue(textbook.isValid)
        XCTAssertTrue(map.isValid)
        XCTAssertEqual(textbook.books.map(\.id), ["basics", "summary"])
        XCTAssertEqual(textbook.books[0].chapters.map(\.id), (1...8).map { "basics-\($0)" })
        XCTAssertEqual(textbook.books[1].chapters.map(\.id), (1...10).map { "summary-\($0)" })
        XCTAssertEqual(map.chips.count, 157)
        XCTAssertEqual(map.journeys.map(\.anchor), ["j-irq", "j-mem", "j-boot"])
        let blocks = textbook.chapters.flatMap(\.allBlocks)
        XCTAssertEqual(blocks.filter { $0.type == .quiz }.count, 26)
        XCTAssertEqual(blocks.filter { $0.type == .callout && $0.style == .exam }.count, 10)
        XCTAssertEqual(blocks.filter { $0.type == .callout && $0.style == .practice }.count, 10)
        XCTAssertEqual(TextbookShelf.current?.title, "教科書")
    }

    func testEveryTextbookFigureIsBundled() throws {
        let textbook = try XCTUnwrap(Textbook.main)
        let map = try XCTUnwrap(LayerMap.main)
        let images = (textbook.chapters.flatMap(\.allBlocks) + map.journeys.flatMap { $0.physical ?? [] })
            .filter { $0.type == .image }
        XCTAssertEqual(images.count, 28)
        for image in images {
            XCTAssertNotNil(image.assetName.flatMap { ContentAsset.url(name: $0) }, image.assetName ?? "")
        }
    }

    /// Links in questions, the textbook and the 全体図 must all land on a page that exists.
    func testEveryTextbookLinkResolves() throws {
        let textbook = try XCTUnwrap(Textbook.main)
        let map = try XCTUnwrap(LayerMap.main)
        let questions = try catalog().questions
        var texts = questions.flatMap { $0.allBlocks.flatMap { [$0.text, $0.answer] }.compactMap { $0 } + ($0.choiceExplanations ?? []) }
        texts += textbook.chapters.flatMap(\.allBlocks).flatMap { [$0.text, $0.answer] + ($0.rows ?? []).flatMap { $0 } }.compactMap { $0 }
        texts += map.chips.flatMap { [$0.description, $0.exam].compactMap { $0 } }
        texts += map.journeys.flatMap { [$0.intro] + $0.steps.map(\.text) + ($0.physical ?? []).compactMap(\.text) }
        let links = texts.flatMap { InlineMarkup.parse($0).flatMap(\.runs) }.compactMap(\.link) +
            map.chips.compactMap(\.textbook).compactMap(URL.init(string:))
        XCTAssertGreaterThan(links.count, 100)
        // One assertion for all links: hundreds of separate failures make XCTest crawl.
        let unresolved = links.filter { link in
            guard link.scheme == ContentLink.scheme else { return false }
            guard let location = TextbookLocation(url: link) else { return true }
            return !textbook.resolves(location, map: map) || TextbookRoute(url: link) == nil
        }
        XCTAssertEqual(unresolved.map(\.absoluteString), [])
        let ids = Set(questions.map(\.id))
        for chip in map.chips {
            XCTAssertTrue((chip.questionIDs ?? []).allSatisfy(ids.contains), chip.id)
        }
    }

    func testRoutesAndBacklinks() throws {
        XCTAssertEqual(TextbookRoute(url: URL(string: "exammaster://textbook/basics-2#floating")!), .chapter("basics-2", section: "floating"))
        XCTAssertEqual(TextbookRoute(url: URL(string: "exammaster://textbook/overview#j-irq")!), .journey("irq"))
        XCTAssertEqual(TextbookRoute(url: URL(string: "exammaster://textbook/overview#cache")!), .chip("cache"))
        XCTAssertEqual(TextbookRoute(url: URL(string: "exammaster://textbook/overview")!), .map)
        XCTAssertNil(TextbookRoute(url: URL(string: "exammaster://textbook/basics-99")!))
        XCTAssertEqual(Textbook.main?.chapter(id: "basics-2")?.section(anchor: "floating")?.id, "pullup")
        let backlinks = TextbookBacklinks(questions: try catalog().questions)
        XCTAssertFalse(backlinks.questionIDs.isEmpty)
        XCTAssertTrue(backlinks.questionIDs.keys.allSatisfy { !$0.contains("floating") })
    }

    func testSearchCoversQuestionsTermsAndTextbook() throws {
        let results = StudySearch.run("プルアップ", questions: try catalog().questions, glossary: Glossary.main,
                                      textbook: Textbook.main, map: LayerMap.main)
        XCTAssertFalse(results.questions.isEmpty)
        XCTAssertFalse(results.terms.isEmpty)
        XCTAssertTrue(results.textbook.contains { $0.id == "s:basics-2#pullup" })
        XCTAssertTrue(results.textbook.contains { $0.id == "c:pullup" })
        XCTAssertTrue(StudySearch.run("ＭＥＳＩ", questions: try catalog().questions, glossary: Glossary.main,
                                      textbook: nil, map: nil).terms.contains { $0.id == "t:mesi" })
    }
}
