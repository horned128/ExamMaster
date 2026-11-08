import XCTest

final class DenkenStudyUITests: XCTestCase {
    // MARK: App Store screenshots
    /// Promotional captures of the Piyo Pop UI: light mode, seeded 3-day history, the correct answer chosen.
    /// Before running: xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100
    /// Export: xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>
    func testStoreScreenshotSet() throws {
        continueAfterFailure = false
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

    private func launch(large: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds", "-AppleInterfaceStyle", large ? "Dark" : "Light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["skipDiagnosis"].waitForExistence(timeout: 20))
        app.buttons["skipDiagnosis"].tap()
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 10))
        return app
    }
    private func openYear(_ year: Int, in app: XCUIApplication) {
        app.tabBars.buttons["年度別"].tap()
        let row=app.buttons["year-\(year)"]
        for _ in 0..<10 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout:5))
        row.tap()
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testFourSubjectsAndOfficialFigurePractice() {
        let app = launch()
        capture("電験三種・ホーム")
        openYear(2026,in:app)
        let picker = app.segmentedControls["electricalSubjectPicker"]
        for (title, key) in [("理論", "theory"), ("電力", "power"), ("機械", "machine"), ("法規", "law")] {
            picker.buttons[title].tap()
            XCTAssertTrue(app.buttons["electricalSet-d3-2026-upper-\(key)"].exists)
        }
        picker.buttons["理論"].tap()
        capture("電験三種・科目別")
        app.buttons["electricalSet-d3-2026-upper-theory"].tap()
        app.buttons["question-d3-2026-upper-theory-q01"].tap()
        XCTAssertTrue(app.buttons["questionFigure"].waitForExistence(timeout: 5))
        capture("電験三種・公式問題")
        app.buttons["questionFigure"].tap()
        XCTAssertTrue(app.buttons["全体表示"].waitForExistence(timeout: 5))
        capture("電験三種・原問の拡大")
        app.buttons["閉じる"].tap()
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '選択肢 2、'")).firstMatch
        for _ in 0..<8 where !choice.isHittable { app.swipeUp() }
        choice.tap()
        app.buttons["submitOrAdvance"].tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
        capture("電験三種・解説")
    }

    func testElectiveSelectionAndTimedExam() {
        let app = launch()
        openYear(2026,in:app)
        app.buttons["electricalSet-d3-2026-upper-theory"].tap()
        app.buttons["solveQuestions"].tap()
        app.segmentedControls["electricalElectivePicker"].buttons["問18"].tap()
        app.buttons["practiceMock"].tap()
        XCTAssertTrue(app.staticTexts["mockRemainingTime"].waitForExistence(timeout: 5))
        app.buttons["mockNavigator"].tap()
        for _ in 0..<8 where !app.buttons["mockJump-19"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["mockJump-19"].exists)
        XCTAssertFalse(app.buttons["mockJump-20"].exists)
        capture("電験三種・20解答欄の模試")
        app.buttons["mockJump-19"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '問18(b)' AND label CONTAINS '出典'")).firstMatch.exists)
    }

    func testLargeDarkSubjectNavigation() {
        let app = launch(large: true)
        openYear(2026,in:app)
        app.segmentedControls["electricalSubjectPicker"].buttons["法規"].tap()
        XCTAssertTrue(app.buttons["electricalSet-d3-2026-upper-law"].exists)
        capture("電験三種・ダーク最大文字")
    }

    func testOriginalThreeRoundsAndTextQuestion() {
        let app = launch()
        openYear(2027,in:app)
        XCTAssertTrue(app.navigationBars["2027年実施向け予想"].exists)
        let picker=app.segmentedControls["electricalSubjectPicker"]
        for (subject,key) in [("理論","theory"),("電力","power"),("機械","machine"),("法規","law")] {
            picker.buttons[subject].tap()
            for round in 1...3 {
                let id=String(format:"electricalSet-d3-2027-pred-%02d-%@",round,key)
                let card=app.buttons[id]
                for _ in 0..<6 where !card.isHittable { app.swipeUp() }
                XCTAssertTrue(card.exists)
            }
            for _ in 0..<3 { app.swipeDown() }
        }
        picker.buttons["理論"].tap()
        capture("電験三種・2027年実施向け予想3回")
        app.buttons["electricalSet-d3-2027-pred-01-theory"].tap()
        let question=app.buttons["question-d3-2027-pred-01-theory-q01"]
        XCTAssertTrue(question.waitForExistence(timeout:5))
        question.tap()
        XCTAssertTrue(app.staticTexts["contentBodyText"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        capture("電験三種・予想問題のテキスト表示")
        let choice=app.buttons.matching(NSPredicate(format:"label CONTAINS '、0.6 N'")).firstMatch
        for _ in 0..<6 where !choice.isHittable { app.swipeUp() }
        choice.tap()
        app.buttons["submitOrAdvance"].tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["answerOutcome"].label,"正解です")
        capture("電験三種・予想問題の解説")
    }

    func testThirdOriginalLawPaperCanStartWithoutPurchase() {
        let app=launch()
        openYear(2027,in:app)
        app.segmentedControls["electricalSubjectPicker"].buttons["法規"].tap()
        let card=app.buttons["electricalSet-d3-2027-pred-03-law"]
        for _ in 0..<6 where !card.isHittable { app.swipeUp() }
        card.tap()
        app.buttons["solveQuestions"].tap()
        XCTAssertFalse(app.segmentedControls["electricalElectivePicker"].exists)
        app.buttons["practiceMock"].tap()
        XCTAssertTrue(app.staticTexts["mockRemainingTime"].waitForExistence(timeout:5))
        let clock=app.staticTexts["mockRemainingTime"].value as? String ?? ""
        XCTAssertTrue(clock.hasPrefix("64:") || clock.hasPrefix("65:"),clock)
        app.buttons["mockNavigator"].tap()
        for _ in 0..<8 where !app.buttons["mockJump-15"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["mockJump-15"].exists)
        XCTAssertFalse(app.buttons["mockJump-16"].exists)
        capture("電験三種・予想第3回法規の16解答欄")
    }
}
