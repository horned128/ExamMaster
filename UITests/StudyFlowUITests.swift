import XCTest

final class StudyFlowUITests: XCTestCase {
    func testDiagnosisCompletesAndMockHasTimer() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy"]
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
        app.buttons["ホームに戻る"].tap()
        XCTAssertTrue(app.staticTexts["今日、覚えるべきこと。"].waitForExistence(timeout: 5))
        app.tabBars.buttons["問題を探す"].tap()
        let mock = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "模擬試験")).firstMatch
        XCTAssertTrue(mock.exists)
        mock.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "40:00")).firstMatch.waitForExistence(timeout: 5) ||
                      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "39:")).firstMatch.exists)
        app.buttons["学習を中断"].tap()
        app.buttons["中断する"].tap()
    }

    func testFirstLaunchPracticePersistenceAndPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy"]
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
        app.buttons["中断する"].tap()

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["今日、覚えるべきこと。"].waitForExistence(timeout: 5))
        app.tabBars.buttons["分析"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1回")).firstMatch.exists)
        app.tabBars.buttons["設定"].tap()
        app.buttons["全問題を解放する"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "永久に解放")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
    }
}
