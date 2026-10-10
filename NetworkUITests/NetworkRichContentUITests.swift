import XCTest
import UIKit

/// Verified free material only. These tests never seed a partial official mock.
final class NetworkRichContentUITests: XCTestCase {
    private enum Surface { case study, mock, result }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        let revision = XCTAttachment(string: "rich-content-v4: v3 operations plus prominent mock action contrast and independent diagram caption")
        revision.name = "構造化UI検査版 v4"
        revision.lifetime = .keepAlways
        add(revision)
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            capture("構造化表示・失敗時の実画面")
            let hierarchy = XCTAttachment(string: XCUIApplication().debugDescription)
            hierarchy.name = "構造化表示・失敗時のAXツリー"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        try super.tearDownWithError()
    }

    func testLargestText2024BodyAndChoiceTables() {
        let app = launchLargestText()
        openQuestion(containing: "即時式完全群負荷表", in: app)
        let bodyTable = app.scrollViews["contentTable"].firstMatch
        verifyTable(bodyTable, firstHeader: "回線数", lastHeader: "呼損率 0.1",
                    cells: ["回線数: 3", "回線数: 4", "呼損率 0.1: 1.271", "呼損率 0.1: 2.045",
                            "呼損率 0.1: 2.881", "呼損率 0.1: 3.758"],
                    name: "2024問3・本文負荷表", surface: .study, app: app)
        answer(2, expected: "イ", in: app)
        returnToSearch(in: app)

        openQuestion(containing: "最小のスーパーネット", in: app)
        XCTAssertEqual(app.scrollViews.matching(identifier: "contentTable").count, 4)
        let choiceTable = app.scrollViews.matching(identifier: "contentTable").element(boundBy: 1)
        verifyTable(choiceTable, firstHeader: "ネットワークアドレス", lastHeader: "サブネットマスク",
                    cells: ["ネットワークアドレス: 192.168.32.0", "サブネットマスク: 255.255.252.0"],
                    name: "2024問12・選択肢イの組合せ表", surface: .study, app: app)
        answer(2, expected: "イ", in: app)
    }

    func testLargestText2024MonospaceAnd2025Formula() {
        let app = launchLargestText()
        openQuestion(containing: "ホストアドレスを求める式", in: app)
        let choices = app.scrollViews.matching(identifier: "contentMonospace")
        XCTAssertEqual(choices.count, 4)
        verifyCode(choices.element(boundBy: 2), text: "a ＆ 〜m", name: "2024問11・選択肢ウの等幅式",
                   surface: .study, app: app)
        answer(3, expected: "ウ", in: app)
        let example = app.scrollViews.matching(identifier: "contentMonospace").element(boundBy: 4)
        verifyCode(example,
                   text: "解説例：192.168.1.10/24 の最終オクテット\na  : 00001010\nm  : 00000000\n〜m: 11111111\na ＆ 〜m = 00001010\n上位24ビットは0になる。",
                   name: "2024問11・独自ビット演算例", surface: .study, app: app)
        returnToSearch(in: app)

        openQuestion(containing: "180台の電話機", in: app)
        answer(4, expected: "エ", in: app)
        verifyCode(app.scrollViews["contentFormula"].firstMatch,
                   text: "A = N × λ × h\n  = 180 × (1 / 180) × 80 = 80 [Erlang]",
                   name: "2025問1・独自解説の呼量式", surface: .study, app: app)
    }

    func testLargestTextOfficialMockTableAndResultBlocks() {
        let app = launchLargestText()
        app.tabBars.buttons["問題を探す"].tap()
        tapListRow(app.buttons["年度別・オリジナル模試"], in: app)
        tapListRow(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "2025年春期")).firstMatch, in: app)
        XCTAssertTrue(app.buttons["mockNavigator"].waitForExistence(timeout: 5))
        app.buttons["mockNavigator"].tap()
        tapListRow(app.buttons["mockJump-14"], in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2025年春期 午前Ⅱ 問15"].waitForExistence(timeout: 5))
        let table = app.scrollViews.matching(identifier: "contentTable").element(boundBy: 2)
        verifyTable(table, firstHeader: "IEEE 802.11n", lastHeader: "IEEE 802.11ac",
                    cells: ["IEEE 802.11n: 2.4GHz帯，5GHz帯", "IEEE 802.11ac: 5GHz帯"],
                    name: "2025問15・公式模試の選択肢ウ表", surface: .mock, app: app)
        let choice = app.buttons["mockChoice-2"]
        bringIntoView(choice, on: .mock, in: app)
        tapVisiblePart(of: choice, on: .mock, in: app)
        XCTAssertTrue(choice.isSelected)
        XCTAssertFalse(app.staticTexts["answerOutcome"].exists)
        verifyActionContrast(app.buttons["mockFinish"], name: "模試の終了して採点", in: app)
        app.buttons["mockFinish"].tap()
        app.buttons["mockConfirmFinish"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["1 / 25問 · 4%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 24問"].exists)
        verifyActionContrast(app.buttons["mockResultFinish"], name: "模試結果の学習を終える", in: app)
        capture("2025模試・最大文字・採点結果と終了ボタン")

        let first = resultDisclosure(number: 1, in: app)
        bringIntoView(first, on: .result, in: app)
        tapVisiblePart(of: first, on: .result, in: app)
        verifyCode(app.scrollViews["contentFormula"].firstMatch,
                   text: "A = N × λ × h\n  = 180 × (1 / 180) × 80 = 80 [Erlang]",
                   name: "2025問1・模試結果の独自解説式", surface: .result, app: app)
        bringIntoView(first, on: .result, in: app)
        tapVisiblePart(of: first, on: .result, in: app)
        let tcp = resultDisclosure(number: 11, in: app)
        bringIntoView(tcp, on: .result, in: app)
        tapVisiblePart(of: tcp, on: .result, in: app)
        verifyCode(app.scrollViews["contentMonospace"].firstMatch,
                   text: "クライアント          サーバ\n                 [LISTEN]\nSYN ------------>\n      <---------- SYN + ACK\n                 [SYN-RECEIVED]\nACK ------------>\n                 [ESTABLISHED]",
                   name: "2025問11・模試結果の独自TCP手順", surface: .result, app: app)
        let caption = app.staticTexts["独自の通常接続の模式図"]
        bringIntoView(caption, on: .result, in: app)
        XCTAssertTrue(caption.isHittable)
        capture("2025問11・模試結果の独自図説明")
        app.buttons["mockResultFinish"].tap()
        XCTAssertTrue(app.navigationBars["固定模試と成績"].waitForExistence(timeout: 5))
    }

    private func launchLargestText() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        tapListRow(app.buttons["skipDiagnosis"], in: app)
        return app
    }

    private func openQuestion(containing keyword: String, in app: XCUIApplication) {
        if !app.navigationBars["すべての問題"].exists {
            app.tabBars.buttons["問題を探す"].tap()
            tapListRow(app.buttons["問題を検索"], in: app)
        }
        let search = app.searchFields.firstMatch
        // The system search field is collapsed initially, and is not in the AX
        // tree until the list is pulled down. Do not require it before revealing it.
        for _ in 0..<8 where !search.exists || !search.isHittable { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        if let existing = search.value as? String, !existing.isEmpty, existing != search.placeholderValue {
            // A tap can place the caret in the middle of a long XXXL query.
            // Use the system clear control, rather than deleting only its prefix.
            let clear = search.buttons["テキストを消去"]
            XCTAssertTrue(clear.waitForExistence(timeout: 5))
            clear.tap()
        }
        search.typeText(keyword)
        XCTAssertEqual(search.value as? String, keyword)
        search.typeText("\n")
        let question = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", keyword, "利用可能")).firstMatch
        tapListRow(question, in: app)
        XCTAssertTrue(app.scrollViews["studyQuestionScroll"].waitForExistence(timeout: 5))
    }

    private func returnToSearch(in app: XCUIApplication) {
        app.buttons["submitOrAdvance"].tap()
        XCTAssertTrue(app.navigationBars["すべての問題"].waitForExistence(timeout: 5))
    }

    private func answer(_ number: Int, expected: String, in app: XCUIApplication) {
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 \(number)、")).firstMatch
        bringIntoView(choice, on: .study, in: app)
        tapVisiblePart(of: choice, on: .study, in: app)
        XCTAssertTrue(app.buttons["submitOrAdvance"].isEnabled)
        app.buttons["submitOrAdvance"].tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["正解: \(expected)"].exists)
    }

    private func verifyTable(_ table: XCUIElement, firstHeader: String, lastHeader: String,
                             cells: [String], name: String, surface: Surface, app: XCUIApplication) {
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        let leading = table.staticTexts[firstHeader]
        let trailing = table.staticTexts[lastHeader]
        XCTAssertTrue(leading.exists)
        XCTAssertTrue(trailing.exists)
        for cell in cells { XCTAssertTrue(table.staticTexts[cell].exists, "見出しと値の対応を保持: \(cell)") }
        bringIntoView(table, on: surface, in: app)
        let before = leading.frame.minX
        capture("\(name)・最大文字・左端")
        panToEnd(table, trailing: trailing, surface: surface, app: app)
        XCTAssertLessThan(leading.frame.minX, before - 40, "表が実際に横へ移動する")
        XCTAssertLessThanOrEqual(trailing.frame.maxX, table.frame.maxX + 1)
        assertNoAnswerAfterReading(surface, in: app)
        capture("\(name)・最大文字・右端")
    }

    private func verifyCode(_ block: XCUIElement, text: String, name: String,
                            surface: Surface, app: XCUIApplication) {
        XCTAssertTrue(block.waitForExistence(timeout: 5))
        let content = block.staticTexts["contentCodeText"].firstMatch
        XCTAssertTrue(content.exists)
        XCTAssertEqual(content.label, text, "式・空白・改行を失わない")
        bringIntoView(block, on: surface, in: app)
        let before = content.frame.minX
        capture("\(name)・最大文字・左端")
        bringIntoView(block, on: surface, in: app, tail: true)
        capture("\(name)・最大文字・左端の末尾")
        bringIntoView(block, on: surface, in: app)
        if content.frame.maxX > block.frame.maxX + 1 {
            panToEnd(block, trailing: content, surface: surface, app: app)
            XCTAssertLessThan(content.frame.minX, before - 40, "横幅を超える等幅/数式が実際に横へ移動する")
        } else {
            XCTAssertGreaterThanOrEqual(content.frame.minX, block.frame.minX)
        }
        XCTAssertLessThanOrEqual(content.frame.maxX, block.frame.maxX + 1)
        capture("\(name)・最大文字・右端")
    }

    private func assertNoAnswerAfterReading(_ surface: Surface, in app: XCUIApplication) {
        switch surface {
        case .study: XCTAssertFalse(app.buttons["submitOrAdvance"].isEnabled)
        case .mock: XCTAssertFalse(app.buttons["回答を取り消す"].exists)
        case .result: break
        }
    }

    private func resultDisclosure(number: Int, in app: XCUIApplication) -> XCUIElement {
        let source = "ネットワークスペシャリスト試験 2025年春期 午前Ⅱ 問\(number)"
        return app.buttons.matching(NSPredicate(format: "label CONTAINS %@", source)).firstMatch
    }

    private func viewport(on surface: Surface, in app: XCUIApplication) -> CGRect {
        let scroll: XCUIElement
        let footer: XCUIElement
        switch surface {
        case .study:
            scroll = app.scrollViews["studyQuestionScroll"]
            footer = app.buttons["submitOrAdvance"]
        case .mock:
            scroll = app.scrollViews["mockQuestionScroll"]
            footer = app.otherElements["mockControls"].firstMatch
        case .result:
            scroll = app.scrollViews["mockResultScroll"]
            footer = app.buttons["学習を終える"]
        }
        let navigationBottom = app.navigationBars.allElementsBoundByIndex.last?.frame.maxY ?? scroll.frame.minY
        // safeAreaInset is not subtracted from the ScrollView's AX frame. At
        // XXXL the fixed timer occupies the area below the navigation bar too.
        let contentTop = surface == .mock ? max(navigationBottom, app.staticTexts["mockRemainingTime"].frame.maxY) : navigationBottom
        let top = max(scroll.frame.minY, contentTop) + 12
        let bottom = min(scroll.frame.maxY, footer.frame.minY) - 12
        return CGRect(x: scroll.frame.minX, y: top, width: scroll.frame.width, height: max(0, bottom - top))
    }

    /// Tall tables/code cannot fit entirely at XXXL. Position an actual readable
    /// portion rather than repeatedly attempting to fit an impossible height.
    private func bringIntoView(_ element: XCUIElement, on surface: Surface, in app: XCUIApplication, tail: Bool = false) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let area = viewport(on: surface, in: app)
        XCTAssertGreaterThan(area.height, 100)
        for _ in 0..<40 {
            let edge = tail ? element.frame.maxY : element.frame.minY
            let needed = min(100, element.frame.height)
            let lower = tail ? area.minY + needed : area.minY
            let upper = tail ? area.maxY : area.maxY - needed
            if edge >= lower && edge <= upper { break }
            let down = edge < lower
            let overflow = down ? lower - edge : edge - upper
            let distance = min(area.height / 2, max(120, overflow + 12))
            drag(from: CGPoint(x: area.minX + 8, y: down ? area.minY + 30 : area.maxY - 30),
                 to: CGPoint(x: area.minX + 8, y: (down ? area.minY + 30 : area.maxY - 30) + (down ? distance : -distance)), in: app)
        }
        XCTAssertGreaterThanOrEqual(element.frame.intersection(area).height, min(90, element.frame.height))
    }

    private func panToEnd(_ block: XCUIElement, trailing: XCUIElement, surface: Surface, app: XCUIApplication) {
        let visible = block.frame.intersection(viewport(on: surface, in: app))
        XCTAssertGreaterThan(visible.height, 40)
        let y = visible.minY + min(30, visible.height / 2)
        for _ in 0..<12 {
            if trailing.frame.maxX <= block.frame.maxX + 1 { break }
            drag(from: CGPoint(x: block.frame.maxX - 30, y: y), to: CGPoint(x: block.frame.minX + 30, y: y), in: app)
        }
    }

    private func tapVisiblePart(of element: XCUIElement, on surface: Surface, in app: XCUIApplication) {
        let visible = element.frame.intersection(viewport(on: surface, in: app))
        XCTAssertGreaterThan(visible.height, 40)
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visible.midX, dy: visible.midY)).tap()
    }

    private func tapListRow(_ element: XCUIElement, in app: XCUIApplication) {
        // List rows are lazy. Scroll before asserting existence, including the
        // navigator sheet whose offscreen rows have not yet been instantiated.
        let window = app.windows.firstMatch.frame
        let navigationBottom = app.navigationBars.allElementsBoundByIndex.last?.frame.maxY ?? (window.minY + 48)
        let top = navigationBottom + 12
        let bottom = app.tabBars.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY - 12 : window.maxY - 30
        let area = CGRect(x: window.minX, y: top, width: window.width, height: bottom - top)
        for _ in 0..<40 {
            if element.isHittable && element.frame.intersection(area).height >= min(44, element.frame.height) { break }
            let down = element.exists && element.frame.maxY < top
            let startY = down ? top + 30 : bottom - 30
            let distance = area.height / 2
            let endY = startY + (down ? distance : -distance)
            drag(from: CGPoint(x: 8, y: startY), to: CGPoint(x: 8, y: endY), in: app)
        }
        XCTAssertTrue(element.exists)
        let visible = element.frame.intersection(area)
        XCTAssertGreaterThanOrEqual(visible.height, min(44, element.frame.height))
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visible.midX, dy: visible.midY)).tap()
    }

    private func drag(from start: CGPoint, to end: CGPoint, in app: XCUIApplication) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: start.x, dy: start.y))
            .press(forDuration: 0.01, thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
                   withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func verifyActionContrast(_ button: XCUIElement, name: String, in app: XCUIApplication) {
        XCTAssertTrue(button.isHittable)
        guard let image = XCUIScreen.main.screenshot().image.cgImage else {
            return XCTFail("コントラスト検査用の実画面を取得できません")
        }
        let ratio = RenderedLabelContrast.measure(in: image, window: app.windows.firstMatch.frame, button: button.frame)
        let measurement = XCTAttachment(string: "\(name): local rendered label contrast \(ratio):1; AX frame \(button.frame)")
        measurement.name = "\(name)・実ピクセルの局所コントラスト"
        measurement.lifetime = .keepAlways
        add(measurement)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "有効な模試終了操作も両配色で読める")
    }
}
