import XCTest
import StoreKitTest

final class FundamentalStudyUITests: XCTestCase {
    // MARK: App Store screenshots
    /// Promotional captures of the Piyo Pop UI: light mode, seeded 3-day history, the correct answer chosen.
    /// Before running: xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100
    /// Export: xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>
    func testStoreScreenshotSet() throws {
        continueAfterFailure = false
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        session.clearTransactions()
        session.storefront = "JPN"
        session.locale = Locale(identifier: "ja_JP")
        defer { session.clearTransactions(); session.resetToDefaultState() }
        var app = storeLaunch()
        storeCapture("store-01-home")
        let firstTry = storeOpenTodayQuestion(app)
        storeCapture("store-02-question")
        let correct = storeAnswer(firstTry, in: app)
        if app.staticTexts["answerOutcome"].label != "正解です" {
            app = storeLaunch()
            _ = storeOpenTodayQuestion(app)
            let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", correct)).firstMatch
            _ = storeAnswer(choice, in: app)
        }
        XCTAssertEqual(app.staticTexts["answerOutcome"].label, "正解です")
        storeCapture("store-03-answer")

        app = storeLaunch()
        storeScroll(to: app.buttons["homeYears"], in: app)
        app.buttons["homeYears"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "year-")).firstMatch.waitForExistence(timeout: 10))
        storeCapture("store-04-years")

        app = storeLaunch()
        storeScroll(to: app.buttons["homeSubjects"], in: app)
        app.buttons["homeSubjects"].tap()
        let subject = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "subject-")).firstMatch
        XCTAssertTrue(subject.waitForExistence(timeout: 10))
        storeCapture("store-05-subjects")
        subject.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "subjectMap").firstMatch.waitForExistence(timeout: 10))
        storeCapture("store-06-subject-map")

        app = storeLaunch()
        storeScroll(to: app.buttons["homeRecords"], in: app)
        app.buttons["homeRecords"].tap()
        XCTAssertTrue(app.navigationBars["学習記録"].waitForExistence(timeout: 10))
        storeCapture("store-07-records")

        app = storeLaunch()
        app.buttons["設定"].tap()
        app.buttons["全問題を解放する"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS '300'")).firstMatch.waitForExistence(timeout: 10))
        storeCapture("store-08-unlock")
    }

    private func storeLaunch() -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["-UITestResetStudy", "-UITestSeedCompanionHistory", "-UITestDisableAds",
                               "-AppleInterfaceStyle", "Light"]
        app.launch()
        XCTAssertTrue(app.buttons["homeTodayStudy"].waitForExistence(timeout: 20))
        return app
    }

    /// Opens today's first question and returns its first choice.
    private func storeOpenTodayQuestion(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["homeTodayStudy"].tap()
        if app.buttons["選択肢を見る"].waitForExistence(timeout: 3) { app.buttons["選択肢を見る"].tap() }
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 ")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 10))
        return choice
    }

    /// Answers with `choice` and returns the correct choice's label prefix ("選択肢 N、").
    private func storeAnswer(_ choice: XCUIElement, in app: XCUIApplication) -> String {
        storeScroll(to: choice, in: app)
        choice.tap()
        let confirm = app.buttons["回答を確定"]
        storeScroll(to: confirm, in: app)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 10))
        let correct = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "選択肢 ", "、正答")).firstMatch
        guard correct.exists, let prefix = correct.label.components(separatedBy: "、").first else { return "選択肢 1、" }
        for _ in 0..<10 where !app.staticTexts["answerOutcome"].isHittable { app.swipeDown() }
        return prefix + "、"
    }

    private func storeScroll(to element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        for _ in 0..<10 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func storeCapture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testStorePurchaseScreenCapture() throws {
        let session = try SKTestSession(configurationFileNamed: "products")
        session.disableDialogs = true
        session.clearTransactions()
        session.storefront = "JPN"
        session.locale = Locale(identifier: "ja_JP")
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = launch()
        app.buttons["設定"].tap()
        app.buttons["全問題を解放する"].tap()
        let price = app.buttons.matching(NSPredicate(format: "label CONTAINS '300'")).firstMatch
        XCTAssertTrue(price.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
        capture("FEストア・全問題解放")
    }

    private func launch(large: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launchArguments += ["-AppleInterfaceStyle", large ? "Dark" : "Light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["skipDiagnosis"].waitForExistence(timeout: 20))
        app.buttons["skipDiagnosis"].tap()
        return app
    }

    private func capture(_ title: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openPracticeB(_ app: XCUIApplication) {
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2026"].tap()
        app.segmentedControls["examSubjectPicker"].buttons["科目B"].tap()
        let set = app.buttons["examSet-fe-practice-b-01"]
        for _ in 0..<15 where !set.isHittable { app.swipeUp() }
        XCTAssertTrue(set.isHittable)
        set.tap()
        app.buttons["question-fe-practice-b-01-q01"].tap()
        XCTAssertTrue(app.buttons["openReadingPane"].waitForExistence(timeout: 5))
    }

    func testBothPublicSubjectsAndOriginalMocksRemainReachable() {
        let app = launch()
        capture("FEホーム・アプリコット")
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2026"].tap()
        XCTAssertTrue(app.buttons["examSet-fe-2026-a"].waitForExistence(timeout: 5))
        capture("FE2026・公開問題とオリジナル")
        app.segmentedControls["examSubjectPicker"].buttons["科目B"].tap()
        let subjectB = app.buttons["examSet-fe-2026-b"]
        for _ in 0..<15 where !subjectB.isHittable { app.swipeUp() }
        XCTAssertTrue(subjectB.isHittable)
        subjectB.tap()
        XCTAssertTrue(app.buttons["時間を測って演習"].waitForExistence(timeout: 5))
    }

    func testLongPassageReadingAndReturnPreserveSelection() {
        let app = launch()
        openPracticeB(app)
        capture("FE科目B・段落とコード")
        app.buttons["jumpToChoices"].tap()
        let answer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '選択肢 1、'")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()
        XCTAssertTrue(answer.isSelected)
        app.buttons["openReadingPane"].tap()
        XCTAssertTrue(app.buttons["closeReadingPane"].waitForExistence(timeout: 5))
        capture("FE科目B・本文の別表示")
        app.buttons["closeReadingPane"].tap()
        XCTAssertTrue(answer.isSelected)
        app.buttons["submitOrAdvance"].tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
    }

    func testLargestTextAndDarkReadingPane() {
        let app = launch(large: true)
        openPracticeB(app)
        XCTAssertTrue(app.buttons["openReadingPane"].isHittable)
        app.buttons["openReadingPane"].tap()
        XCTAssertTrue(app.buttons["closeReadingPane"].waitForExistence(timeout: 5))
        capture("FE科目B・ダーク最大文字")
        app.buttons["readingContents"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'コード'")).firstMatch.tap()
        let reader = app.scrollViews["readingPassage"]
        let settings = reader.buttons["codeDisplaySettings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isHittable)
        XCTAssertLessThanOrEqual(settings.frame.maxX, app.windows.firstMatch.frame.maxX - 10)
        capture("FEコード・ダーク最大文字")
    }

    func testSubjectBMockKeepsAnswersWhileReadingAndNavigating() {
        let app = launch()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2026"].tap()
        app.segmentedControls["examSubjectPicker"].buttons["科目B"].tap()
        app.buttons["examSet-fe-practice-b-01"].tap()
        app.buttons["solveQuestions"].tap()
        XCTAssertTrue(app.buttons["practiceMock"].waitForExistence(timeout: 5))
        app.buttons["practiceMock"].tap()
        XCTAssertTrue(app.staticTexts["mockRemainingTime"].waitForExistence(timeout: 5))
        app.buttons["jumpToChoices"].tap()
        let answer = app.buttons["mockChoice-0"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()
        app.buttons["openReadingPane"].tap()
        XCTAssertTrue(app.buttons["closeReadingPane"].waitForExistence(timeout: 5))
        capture("FE科目B・模試中の読解")
        app.buttons["closeReadingPane"].tap()
        XCTAssertTrue(answer.isSelected)
        app.buttons["次へ"].tap()
        app.buttons["前へ"].tap()
        app.buttons["jumpToChoices"].tap()
        XCTAssertTrue(app.buttons["mockChoice-0"].isSelected)
    }

    func testOfficialLongCaseWithTenChoices() {
        let app = launch()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2026"].tap()
        app.segmentedControls["examSubjectPicker"].buttons["科目B"].tap()
        app.buttons["examSet-fe-2026-b"].tap()
        let question = app.buttons["question-fe-2026-b-q06"]
        for _ in 0..<5 where !question.isHittable { app.swipeUp() }
        question.tap()
        XCTAssertTrue(app.buttons["openReadingPane"].waitForExistence(timeout: 5))
        capture("FE科目B・IPA長文事例")
        app.buttons["jumpToChoices"].tap()
        let tenth = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '選択肢 10、'")).firstMatch
        for _ in 0..<8 where !tenth.isHittable { app.swipeUp() }
        XCTAssertTrue(tenth.isHittable)
        tenth.tap()
        capture("FE科目B・10選択肢")
        app.buttons["openReadingPane"].tap()
        XCTAssertTrue(app.buttons["readingContents"].waitForExistence(timeout: 5))
        app.buttons["readingContents"].tap()
        let tableLink = app.buttons.matching(NSPredicate(format: "label CONTAINS '図・表'")).firstMatch
        XCTAssertTrue(tableLink.waitForExistence(timeout: 5))
        tableLink.tap()
        XCTAssertTrue(app.otherElements["readableCaseTable"].firstMatch.waitForExistence(timeout: 5))
        capture("FE科目B・長文表を折り返して読む")
        app.buttons["closeReadingPane"].tap()
        XCTAssertTrue(tenth.isSelected)
    }

    func testLandscapeReadingControlsRemainReachable() {
        let app = launch()
        openPracticeB(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["jumpToChoices"].isHittable)
        app.buttons["openReadingPane"].tap()
        XCTAssertTrue(app.buttons["closeReadingPane"].waitForExistence(timeout: 5))
        capture("FE科目B・横向き")
    }

    func testCodeWrapsInsideScreenAndFontCanBeAdjusted() {
        let app = launch()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2026"].tap()
        app.segmentedControls["examSubjectPicker"].buttons["科目B"].tap()
        app.buttons["examSet-fe-2026-b"].tap()
        let question = app.buttons["question-fe-2026-b-q05"]
        for _ in 0..<5 where !question.isHittable { app.swipeUp() }
        question.tap()
        app.buttons["openReadingPane"].tap()
        app.buttons["readingContents"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'コード'")).firstMatch.tap()
        let reader = app.scrollViews["readingPassage"]
        let settings = reader.buttons["codeDisplaySettings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isHittable)
        XCTAssertTrue(app.staticTexts["画面幅で折り返し"].exists)
        capture("FEコード・標準の折り返し")
        settings.tap()
        app.buttons["大きめ"].tap()
        let line = reader.descendants(matching: .any).matching(identifier: "codeSourceLine-1").firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(line.frame.maxX, app.windows.firstMatch.frame.maxX - 10)
        XCTAssertGreaterThanOrEqual(line.frame.minX, 10)
        capture("FEコード・文字を大きめに調整")
        app.buttons["closeReadingPane"].tap()
        app.buttons["openReadingPane"].tap()
        app.buttons["readingContents"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'コード'")).firstMatch.tap()
        XCTAssertTrue(reader.buttons["codeDisplaySettings"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["画面幅で折り返し"].exists)
        capture("FEコード・読解画面でも折り返し")
    }
}
