import XCTest
import StoreKitTest

final class AppliedStudyUITests: XCTestCase {
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

    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        XCTAssertTrue(app.buttons["skipDiagnosis"].waitForExistence(timeout: 20))
        app.buttons["skipDiagnosis"].tap()
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHomeContainsSubjectABalanceAndNoWrittenPractice() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["科目A・3分野のバランス"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["homeWrittenPractice"].exists)
        XCTAssertFalse(app.staticTexts["科目B・記述ノート"].exists)
        capture("APホーム・科目Aのみ")
    }

    func testResearchBasedLearningGuideScreens() {
        let app = launch()
        app.buttons["記憶と復習のしくみ"].tap()
        XCTAssertTrue(app.navigationBars["記憶と学習"].waitForExistence(timeout: 5))
        capture("AP記憶と学習・研究を参考にした学び方")

        let retrieval = app.staticTexts["guide-retrieval"]
        for _ in 0..<6 where !retrieval.isHittable { app.swipeUp() }
        XCTAssertTrue(retrieval.waitForExistence(timeout: 5))
        capture("AP記憶と学習・想起練習")
    }

    func testSubjectMapAddsSubcategorySelectionBeforeQuestions() {
        let app = launch()
        app.tabBars.buttons["分野別"].tap()
        app.buttons["subject-テクノロジ"].tap()
        let security = app.buttons["category-セキュリティ"]
        XCTAssertTrue(security.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["学びのマップ"].exists)
        capture("AP分野マップ・テーマから選択")
        security.tap()
        let authentication = app.buttons["subcategory-認証・アクセス制御"]
        XCTAssertTrue(authentication.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["subcategory-攻撃・脆弱性"].exists)
        XCTAssertTrue(app.buttons["topic-all-セキュリティ"].exists)
        let lastSubcategory = app.buttons["subcategory-その他"]
        app.swipeUp()
        for _ in 0..<4 where !lastSubcategory.isHittable { app.swipeUp() }
        XCTAssertTrue(lastSubcategory.isHittable)
        capture("AP分野マップ・サブカテゴリ一覧")
        authentication.tap()
        XCTAssertTrue(app.navigationBars["認証・アクセス制御"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["solveQuestions"].waitForExistence(timeout: 5))
        capture("AP分野マップ・選択したサブカテゴリ")
    }

    func testNativeTextAndEssentialDiagram() {
        let app = launch()
        app.tabBars.buttons["年度別"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS '2025' AND label CONTAINS '160'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["pastSet-ap-2025-spring"].waitForExistence(timeout: 5))
        capture("AP年度・春期と秋期")
        app.buttons["pastSet-ap-2025-spring"].tap()
        app.buttons["question-ap-2025-spring-q01"].tap()
        XCTAssertTrue(app.staticTexts["contentBodyText"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        capture("AP科目A・テキストのみ")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["問題一覧へ戻る"].waitForExistence(timeout: 5))
        app.buttons["問題一覧へ戻る"].tap()
        let diagramQuestion = app.buttons["question-ap-2025-spring-q06"]
        for _ in 0..<4 where !diagramQuestion.isHittable { app.swipeUp() }
        diagramQuestion.tap()
        XCTAssertTrue(app.buttons["questionFigure"].waitForExistence(timeout: 5))
        capture("AP科目A・本文テキストとAVL図のみ")
        app.buttons["questionFigure"].tap()
        XCTAssertTrue(app.navigationBars["図を拡大"].waitForExistence(timeout: 5))
        capture("AP原問・拡大")
    }

    func testDetailedExplanationAndIndividualChoiceReasons() {
        let app = launch()
        app.tabBars.buttons["年度別"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS '2025' AND label CONTAINS '160'")).firstMatch.tap()
        app.buttons["pastSet-ap-2025-autumn"].tap()
        app.buttons["question-ap-2025-autumn-q01"].tap()
        XCTAssertTrue(app.scrollViews["contentTable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        let answer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '選択肢 4、'")).firstMatch
        for _ in 0..<5 where !answer.isHittable { app.swipeUp() }
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()
        app.buttons["submitOrAdvance"].tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
        let explanation = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Cが式から消えるのは'")).firstMatch
        for _ in 0..<5 where !explanation.isHittable { app.swipeUp() }
        XCTAssertTrue(explanation.exists)
        capture("AP2025秋・カルノー図の詳細解説")
        let reasons = app.buttons["選択肢ごとの理由"]
        for _ in 0..<5 where !reasons.isHittable { app.swipeUp() }
        reasons.tap()
        XCTAssertTrue(app.staticTexts["左右端の2セルと中央の4セルを、それぞれ¬A・¬B・¬DとB・Dで表している。"].waitForExistence(timeout: 5))
        capture("AP2025秋・全選択肢の理由と解き方")
    }

    func test300YenNonConsumableUnlockScreen() {
        let store = try! SKTestSession(configurationFileNamed: "products")
        store.disableDialogs = true
        store.clearTransactions()
        store.storefront = "JPN"
        store.locale = Locale(identifier: "ja_JP")
        defer {
            store.clearTransactions()
            store.resetToDefaultState()
        }
        let app = launch()
        app.buttons["設定"].tap()
        let unlock = app.buttons["全問題を解放する"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        unlock.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1,760問を、永久に解放。'")).firstMatch.waitForExistence(timeout: 10))
        let buy = app.buttons.matching(NSPredicate(format: "label CONTAINS '300'")).firstMatch
        XCTAssertTrue(buy.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
        capture("AP全問題解放・300円買い切り")
    }
}
