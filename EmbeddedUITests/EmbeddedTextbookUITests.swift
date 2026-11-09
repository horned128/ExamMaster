import XCTest

/// The 教科書 tab, the 全体図, and links between questions and the textbook in both directions.
final class EmbeddedTextbookUITests: XCTestCase {
    func testTextbookMapAndLinksBothWays() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        let skip = app.buttons["skipDiagnosis"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }

        let textbookTab = app.tabBars.buttons["教科書"]
        XCTAssertTrue(textbookTab.waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.count, 5)
        XCTAssertTrue(app.tabBars.buttons["セット"].exists)
        XCTAssertTrue(app.tabBars.buttons["復習"].exists)
        app.tabBars.buttons["復習"].tap()
        XCTAssertTrue(app.segmentedControls["reviewListPicker"].waitForExistence(timeout: 5))
        capture(app, name: "復習タブ")

        // 電子回路の基礎 → 第1章 → 確認問題
        textbookTab.tap()
        XCTAssertTrue(app.buttons["textbookShelf-basics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["textbookShelf-glossary"].exists)
        capture(app, name: "教科書・本棚")
        app.buttons["textbookShelf-basics"].tap()
        app.buttons["textbookChapter-basics-1"].tap()
        let quiz = app.buttons["textbookQuiz"].firstMatch
        XCTAssertTrue(quiz.waitForExistence(timeout: 5))
        scrollTo(quiz, in: app)
        quiz.tap()
        XCTAssertTrue(app.descendants(matching: .any)["textbookQuizAnswer"].firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "教科書・確認問題")

        // 全体図 → チップ → 教科書へのリンクが節の位置で開く
        textbookTab.tap()
        textbookTab.tap()
        XCTAssertTrue(app.buttons["textbookShelf-overview"].waitForExistence(timeout: 5))
        app.buttons["textbookShelf-overview"].tap()
        let chip = app.buttons["chip-pullup"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        scrollTo(chip, in: app)
        capture(app, name: "全体図")
        chip.tap()
        let textbookLink = app.descendants(matching: .any)["chipTextbookLink"].firstMatch
        XCTAssertTrue(textbookLink.waitForExistence(timeout: 5))
        capture(app, name: "全体図・用語")
        textbookLink.tap()
        let section = app.staticTexts["2-3 プルアップ／プルダウン"]
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        XCTAssertTrue(section.isHittable)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 関連問題を1問解く → 解説の関連知識から教科書をシートで開く
        let related = app.buttons["relatedQuestion-es-s01-q11"]
        XCTAssertTrue(related.waitForExistence(timeout: 5))
        scrollTo(related, in: app)
        related.tap()
        let reveal = app.buttons["選択肢を見る"]
        if reveal.waitForExistence(timeout: 2) { reveal.tap() }
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        scrollTo(choice, in: app)
        choice.tap()
        XCTAssertTrue(app.staticTexts["answerLine"].waitForExistence(timeout: 5))
        let relatedKnowledge = app.descendants(matching: .any)["relatedKnowledge"].firstMatch
        XCTAssertTrue(relatedKnowledge.waitForExistence(timeout: 5))
        scrollTo(relatedKnowledge, in: app)
        app.buttons["関連知識"].firstMatch.tap()
        let link = app.links["2章：プルアップ"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        scrollTo(link, in: app)
        link.tap()
        let close = app.buttons["閉じる"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2-3 プルアップ／プルダウン"].waitForExistence(timeout: 5))
        capture(app, name: "問題から教科書シート")
        close.tap()
        XCTAssertTrue(app.staticTexts["answerLine"].waitForExistence(timeout: 5))
    }

    /// 分野別 opens straight on the 弱点マップ; a theme drills its weak questions, explains itself and links to the textbook.
    func testWeakPointMapDrillsThemesAndColoursChips() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        let skip = app.buttons["skipDiagnosis"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }

        app.tabBars.buttons["分野別"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["subjectMap"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "category-")).count, 10)
        capture(app, name: "弱点マップ")

        // 1問解いて中断すると、そのテーマに正答率が付く
        let drill = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "weakDrill-")).firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: 5))
        let theme = String(drill.identifier.dropFirst("weakDrill-".count))
        drill.tap()
        XCTAssertTrue(app.navigationBars[theme + "の弱点"].waitForExistence(timeout: 5))
        let reveal = app.buttons["選択肢を見る"]
        if reveal.waitForExistence(timeout: 2) { reveal.tap() }
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        scrollTo(choice, in: app)
        choice.tap()
        XCTAssertTrue(app.staticTexts["answerLine"].waitForExistence(timeout: 5))
        app.buttons["学習を中断"].tap()
        app.buttons["問題一覧へ戻る"].tap()
        let card = app.buttons["category-" + theme]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("正答率"), card.label)

        // テーマの解説 → 中分類 → 教科書へのリンクはシートで開く
        let hardware = app.buttons["category-ハードウェア"]
        scrollTo(hardware, in: app)
        hardware.tap()
        XCTAssertTrue(app.descendants(matching: .any)["themeAbout"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["themeWeakDrill"].exists)
        capture(app, name: "弱点マップ・テーマの解説")
        let logic = app.buttons["subcategory-論理回路"]
        scrollTo(logic, in: app)
        XCTAssertTrue(logic.exists)
        let link = app.descendants(matching: .any)["themeLink"].firstMatch
        scrollTo(link, in: app)
        link.tap()
        let close = app.buttons["閉じる"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        // 全体図には習熟度の凡例が出る
        app.tabBars.buttons["教科書"].tap()
        XCTAssertTrue(app.buttons["textbookShelf-overview"].waitForExistence(timeout: 5))
        app.buttons["textbookShelf-overview"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["layerMapLegend"].firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "全体図・習熟度の色分け")
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        let tabTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
        for _ in 0..<25 {
            if element.isHittable && element.frame.maxY < tabTop - 8 && element.frame.minY > 100 { return }
            if element.frame.minY < 100 {
                app.swipeDown(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
