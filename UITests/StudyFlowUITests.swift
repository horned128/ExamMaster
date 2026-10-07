import XCTest

final class StudyFlowUITests: XCTestCase {
    func testExamDayCountdownPersistsAndCanBeCleared() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["診断をスキップして始める"].tap()
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
        XCTAssertTrue(app.staticTexts["未設定"].waitForExistence(timeout: 5))
    }

    func testAnalysisCalendarAndEmptyCharts() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["診断をスキップして始める"].tap()
        app.tabBars.buttons["分析"].tap()
        XCTAssertTrue(app.staticTexts["学習カレンダー"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["科目別の定着度"].exists)
    }

    func testSharedCollectionSingleQuestionAndResume() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["診断をスキップして始める"].tap()
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
        XCTAssertTrue(app.staticTexts["今日、覚えるべきこと。"].waitForExistence(timeout: 5))
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
        app.buttons["診断をスキップして始める"].tap()
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
        app.buttons["診断をスキップして始める"].tap()
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
        app.buttons["診断をスキップして始める"].tap()
        let consentContinue = app.buttons.matching(identifier: "Continue").firstMatch
        if consentContinue.waitForExistence(timeout: 12) { consentContinue.tap() }
        let trackingAlert = app.alerts.firstMatch
        if trackingAlert.waitForExistence(timeout: 3) { trackingAlert.buttons.firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["今日、覚えるべきこと。"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "まず取り組む分野")).firstMatch.exists)
        app.buttons["ホームへ進む"].tap()
        XCTAssertTrue(app.staticTexts["今日、覚えるべきこと。"].waitForExistence(timeout: 5))
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
        app.buttons["診断をスキップして始める"].tap()
        XCTAssertTrue(app.staticTexts["今日、覚えるべきこと。"].waitForExistence(timeout: 5))
        let recommendation = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今日のおすすめ学習")).firstMatch
        XCTAssertTrue(recommendation.exists)
        recommendation.tap()
        XCTAssertTrue(app.buttons["選択肢を見る"].waitForExistence(timeout: 5))
        app.buttons["選択肢を見る"].tap()
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch
        XCTAssertTrue(choice.exists)
        choice.tap()
        app.buttons["回答を確定"].tap()
        XCTAssertTrue(app.staticTexts["正解です"].exists || app.staticTexts["もう一度確認しましょう"].exists)
        app.buttons["学習を中断"].tap()
        app.buttons["中断して後で再開"].tap()

        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        XCTAssertTrue(app.staticTexts["今日、覚えるべきこと。"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "続きから")).firstMatch.exists)
        app.tabBars.buttons["分析"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1回")).firstMatch.exists)
        app.buttons["設定"].tap()
        XCTAssertFalse(app.staticTexts["問題集"].exists)
        app.buttons["全問題を解放する"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "永久に解放")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
    }
}
