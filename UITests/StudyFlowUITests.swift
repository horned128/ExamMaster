import XCTest

final class StudyFlowUITests: XCTestCase {
    func testExamDayCountdownPersistsAndCanBeCleared() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        XCTAssertTrue(app.buttons["試験日を設定"].waitForExistence(timeout: 5))
        app.buttons["試験日を設定"].tap()
        XCTAssertTrue(app.buttons["試験日を保存"].waitForExistence(timeout: 5))
        app.buttons["試験日を保存"].tap()
        let countdown = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "あと")).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "試験日と学習準備度・ホーム"
        attachment.lifetime = .keepAlways
        add(attachment)
        let label = countdown.label
        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5))
        app.buttons["設定"].tap()
        app.buttons["試験日を設定"].tap()
        app.buttons["試験日の設定を解除"].tap()
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["試験日を設定"].waitForExistence(timeout: 5))
    }

    func testAnalysisCalendarAndEmptyCharts() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["記録"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["学習カレンダー"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["科目別の定着度"].exists)
    }

    func testSharedCollectionSingleQuestionAndResume() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["問題を探す"].tap()
        app.staticTexts["2025年"].tap()
        XCTAssertTrue(app.buttons["順番に回答 · 8問"].waitForExistence(timeout: 5))
        let firstQuestion = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "始業前点検の主な目的")).firstMatch
        firstQuestion.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch.tap()
        app.buttons["回答を確定"].tap()
        app.buttons["一覧へ戻る"].tap()
        XCTAssertTrue(app.buttons["順番に回答 · 8問"].waitForExistence(timeout: 5))

        app.buttons["順番に回答 · 8問"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch.tap()
        app.buttons["回答を確定"].tap()
        app.buttons["学習を中断"].tap()
        XCTAssertTrue(app.staticTexts["問題の途中ですが、中断しますか？"].exists)
        app.buttons["中断して後で再開"].tap()
        XCTAssertTrue(app.buttons["順番に回答 · 8問"].waitForExistence(timeout: 5))
        app.tabBars.buttons["ホーム"].tap()
        XCTAssertTrue(app.staticTexts["homeHeading"].waitForExistence(timeout: 5))
        let resume = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "続きから")).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(app.staticTexts["正解です"].waitForExistence(timeout: 5))
        app.buttons["次の問題へ"].tap()
        app.buttons["学習を中断"].tap()
        app.buttons["中断して後で再開"].tap()
    }

    func testSettingsPrivacyAndLearningReset() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.buttons["設定"].tap()
        XCTAssertTrue(app.buttons["データとプライバシー"].exists)
        app.buttons["データとプライバシー"].tap()
        XCTAssertTrue(app.buttons["プライバシーポリシー全文（サンプル）"].exists)
        app.buttons["学習情報をすべてリセット"].tap()
        XCTAssertTrue(app.staticTexts["学習情報をすべて削除しますか？"].exists)
        app.buttons["学習情報を削除"].tap()
        XCTAssertTrue(app.buttons["診断を始める"].waitForExistence(timeout: 5))
    }

    func testRandomUnansweredChoiceAndReplacingPendingExercise() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["問題を探す"].tap()
        app.staticTexts["2025年"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "始業前点検の主な目的")).firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch.tap()
        app.buttons["回答を確定"].tap()
        app.buttons["一覧へ戻る"].tap()
        XCTAssertTrue(app.buttons["ランダム出題"].waitForExistence(timeout: 5))
        app.buttons["ランダム出題"].tap()
        app.buttons["未回答のみ"].tap()
        XCTAssertTrue(app.buttons["7問の演習を始める"].waitForExistence(timeout: 5))
        app.buttons["7問の演習を始める"].tap()
        XCTAssertTrue(app.buttons["回答を確定"].waitForExistence(timeout: 5))
        app.buttons["学習を中断"].tap()
        app.buttons["中断して後で再開"].tap()
        XCTAssertTrue(app.buttons["順番に回答 · 8問"].waitForExistence(timeout: 5))
        app.buttons["順番に回答 · 8問"].tap()
        XCTAssertTrue(app.staticTexts["保存中の演習があります"].waitForExistence(timeout: 5))
        app.buttons["新しい演習に切り替える"].tap()
        XCTAssertTrue(app.buttons["回答を確定"].waitForExistence(timeout: 5))
        app.buttons["学習を中断"].tap()
        app.buttons["中断して後で再開"].tap()
    }

    func testAdConsentNeverBlocksFreeExercises() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy"] // The SDK only receives Google's demo ad units in Debug.
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        let consentContinue = app.buttons.matching(identifier: "Continue").firstMatch
        if consentContinue.waitForExistence(timeout: 12) { consentContinue.tap() }
        let trackingAlert = app.alerts.firstMatch
        if trackingAlert.waitForExistence(timeout: 3) { trackingAlert.buttons.firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["homeHeading"].waitForExistence(timeout: 5))
        app.tabBars.buttons["問題を探す"].tap()
        XCTAssertTrue(app.staticTexts["学習モード"].waitForExistence(timeout: 5))
        app.staticTexts["2025年"].tap()
        XCTAssertTrue(app.buttons["ランダム出題"].waitForExistence(timeout: 5))
        for _ in 0..<5 { app.swipeUp() }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "無料版・問題一覧の広告枠"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        // Never tap a real ad in an automated test, even if an account is added later.
    }

    func testDiagnosisCompletesAndMockHasTimer() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["診断を始める"].tap()
        for n in 0..<8 {
            let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            app.buttons["回答を確定"].tap()
            app.buttons[n == 7 ? "結果を見る" : "次の問題へ"].tap()
        }
        XCTAssertTrue(app.staticTexts["診断が完了しました"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["分野別の結果"].exists)
        app.buttons["ホームへ進む"].tap()
        XCTAssertTrue(app.staticTexts["homeHeading"].waitForExistence(timeout: 5))
        app.tabBars.buttons["問題を探す"].tap()
        let mock = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "模擬試験")).firstMatch
        XCTAssertTrue(mock.exists)
        mock.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "40:00")).firstMatch.waitForExistence(timeout: 5) ||
                      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "39:")).firstMatch.exists)
        app.buttons["学習を中断"].tap()
        app.buttons["模試を中断する"].tap()
    }

    func testFirstLaunchPracticePersistenceAndPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        XCTAssertTrue(app.buttons["診断を始める"].waitForExistence(timeout: 10))
        app.buttons["skipDiagnosis"].tap()
        XCTAssertTrue(app.staticTexts["homeHeading"].waitForExistence(timeout: 5))
        let recommendation = app.buttons["startDailyStudy"]
        XCTAssertTrue(recommendation.exists)
        recommendation.tap()
        XCTAssertTrue(app.buttons["選択肢を見る"].waitForExistence(timeout: 5))
        app.buttons["選択肢を見る"].tap()
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch
        XCTAssertTrue(choice.exists)
        choice.tap()
        app.buttons["回答を確定"].tap()
        XCTAssertTrue(app.staticTexts["正解です"].exists || app.staticTexts["答えを確認"].exists)
        app.buttons["学習を中断"].tap()
        app.buttons["中断して後で再開"].tap()

        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        XCTAssertTrue(app.staticTexts["homeHeading"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "続きから")).firstMatch.exists)
        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1回")).firstMatch.exists)
        app.buttons["設定"].tap()
        XCTAssertFalse(app.staticTexts["問題集"].exists)
        app.buttons["全問題を解放する"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "永久に解放")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
    }

    func testShortDailyStudyShowsActualCountAndNextReview() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.buttons["shortStudy"].tap()
        XCTAssertEqual(app.buttons["startDailyStudy"].label, "5問の学習を始める")
        capture(app, name: "ホーム・5問を自分で選ぶ")
        app.buttons["startDailyStudy"].tap()
        for index in 0..<5 {
            app.buttons["選択肢を見る"].tap()
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch.tap()
            app.buttons["回答を確定"].tap()
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "復習の目安 · ")).firstMatch.waitForExistence(timeout: 5))
            if index == 0 { capture(app, name: "回答・次の復習の目安") }
            app.buttons[index == 4 ? "結果を見る" : "次の問題へ"].tap()
        }
        XCTAssertTrue(app.staticTexts["次に出会う目安"].waitForExistence(timeout: 5))
        capture(app, name: "結果・今日はここまで")
        app.swipeUp()
        app.buttons["学習を終える"].tap()
        XCTAssertTrue(app.staticTexts["homeHeading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["resumeStudy"].exists)
    }

    func testLearningGuideIsOptionalAndHomeRemainsActionable() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        capture(app, name: "初回・記憶のリズム")
        app.buttons["skipDiagnosis"].tap()
        XCTAssertTrue(app.buttons["startDailyStudy"].isHittable)
        app.swipeUp()
        app.buttons["記憶と復習のしくみ"].tap()
        XCTAssertTrue(app.staticTexts["間隔をあけて、記憶を育てる。"].waitForExistence(timeout: 5))
        capture(app, name: "詳細・必要なときだけ読む")
        app.buttons["閉じる"].tap()
        app.swipeDown()
        XCTAssertTrue(app.buttons["startDailyStudy"].isHittable)
    }

    func testLargestTextHomeAndStudyRemainUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for _ in 0..<6 where !app.buttons["skipDiagnosis"].isHittable { app.swipeUp() }
        app.buttons["skipDiagnosis"].tap()
        for _ in 0..<6 where !app.buttons["startDailyStudy"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["startDailyStudy"].isHittable)
        capture(app, name: "最大文字サイズ・ホーム")
        app.buttons["startDailyStudy"].tap()
        XCTAssertTrue(app.buttons["選択肢を見る"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["選択肢を見る"].isHittable)
        capture(app, name: "最大文字サイズ・想起")
        app.buttons["選択肢を見る"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch.tap()
        XCTAssertTrue(app.buttons["回答を確定"].isHittable)
    }

    func testCompactHomeAndLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        capture(app, name: "コンパクト・初回")
        for _ in 0..<3 where !app.buttons["skipDiagnosis"].isHittable { app.swipeUp() }
        app.buttons["skipDiagnosis"].tap()
        for _ in 0..<3 where !app.buttons["startDailyStudy"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["startDailyStudy"].isHittable)
        capture(app, name: "コンパクト・ホーム")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _, _ in app.frame.width > app.frame.height }
        let rotation = XCTNSPredicateExpectation(predicate: rotated, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [rotation], timeout: 5), .completed)
        // XCTest scrolls this specific control into view. Whole-screen swipes can
        // overshoot it in a compact landscape viewport.
        app.buttons["startDailyStudy"].tap()
        XCTAssertTrue(app.buttons["選択肢を見る"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["選択肢を見る"].isHittable)
        capture(app, name: "横向き・下部操作")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        // Capture the display rather than the application's stale bounds after rotation.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
