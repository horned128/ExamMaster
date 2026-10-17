import XCTest
import UIKit
import StoreKitTest

final class NetworkStudyUITests: XCTestCase {
    func testHomeExamDateIsVisibleAndPersists() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        XCTAssertTrue(app.staticTexts["homeToday"].waitForExistence(timeout: 5))
        app.buttons["homeExamSchedule"].tap()
        app.buttons["試験日を保存"].tap()
        XCTAssertTrue(app.staticTexts["homeExamCountdown"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["homeExamCountdown"].label, "あと30日")
        let examDate = app.staticTexts["homeExamDate"].label
        XCTAssertTrue(examDate.hasPrefix("試験日 "))
        XCTAssertTrue(app.buttons["homeRecords"].isHittable)
        capture("試験日・ネットワークのホーム")
        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        XCTAssertTrue(app.staticTexts["homeExamDate"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["homeExamDate"].label, examDate)
        XCTAssertEqual(app.staticTexts["homeExamCountdown"].label, "あと30日")
    }

    @MainActor func testHistoricalAnswersShowNotesAfterAnswerAndCompleteMocks() async throws {
        continueAfterFailure = false
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        _ = try await storeKit.buyProduct(identifier: "jp.hino.piyotre.networkspecialist.unlock")
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        for (year, number, selection, expected, caution) in [
            (2015, 9, 3, "正解: エ", "出題年より前"),
            (2018, 17, 3, "正解: ウ", "任意のクライアント証明書認証"),
            (2024, 22, 2, "正解: ア", "32レーン構成")
        ] {
            openYear(year, in: app)
            let period = year < 2020 ? "autumn" : "spring"
            let row = app.buttons[String(format: "question-nw-%d-%@-q%02d", year, period, number)]
            for _ in 0..<20 where !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.isHittable)
            row.tap()
            let note = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "当時の公式正答で採点します。")).firstMatch
            XCTAssertFalse(note.exists, "採点方針と正答の説明は回答後に表示する")
            let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 \(selection + 1)、")).firstMatch
            scrollStudyContentTo(option, in: app)
            option.tap()
            app.buttons["submitOrAdvance"].tap()
            XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["answerOutcome"].label, year == 2015 ? "正解です" : "答えを確認")
            XCTAssertTrue(note.waitForExistence(timeout: 5))
            XCTAssertTrue(note.label.contains(caution))
            for _ in 0..<8 where !note.isHittable || note.frame.minY > app.buttons["submitOrAdvance"].frame.minY - 120 {
                app.scrollViews["studyQuestionScroll"].swipeUp()
            }
            XCTAssertTrue(app.staticTexts[expected].exists)
            XCTAssertTrue(note.isHittable)
            capture("\(year)問\(number)・公式正答の採点と仕様上の注意")
            app.buttons["学習を中断"].tap()
            app.buttons["問題一覧へ戻る"].tap()
            XCTAssertTrue(app.navigationBars["\(year)年の問題"].waitForExistence(timeout: 5))
            let mock = app.buttons["solveQuestions"]
            for _ in 0..<20 where !mock.isHittable { app.swipeDown() }
            XCTAssertTrue(mock.isHittable)
            startCollectionMock(in: app)
            jumpToMockQuestion(number, year: year, in: app)
            XCTAssertFalse(note.exists, "模試中に答えを表示しない")
            selectMockChoice(year == 2015 ? 3 : year == 2018 ? 2 : 0, in: app)
            finishMock(in: app)
            XCTAssertTrue(app.staticTexts["1 / 25問 · 4%"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["未回答 24問"].exists)
            capture("\(year)年度・追加問題を含む25問固定模試の採点")
            app.buttons["mockResultFinish"].tap()
        }
    }

    func testYearPracticeStatePickerAndSubjectModes() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.buttons["homeYears"].tap()
        app.buttons["year-2025"].tap()
        app.buttons["solveQuestions"].tap()
        XCTAssertTrue(app.buttons["practiceMock"].waitForExistence(timeout: 5))
        app.buttons["practiceQuestionState"].tap()
        app.buttons["学習済み（0問）"].tap()
        XCTAssertFalse(app.buttons["practiceSequential"].isEnabled)
        XCTAssertFalse(app.buttons["practiceRandom"].isEnabled)
        XCTAssertTrue(app.buttons["practiceMock"].isEnabled)
        app.buttons["practiceQuestionState"].tap()
        app.buttons["未学習（25問）"].tap()
        capture("年度別・学習状態と3つの出題方法")
        app.buttons["practiceSequential"].tap()
        XCTAssertTrue(app.staticTexts["1 / 25問"].waitForExistence(timeout: 5))
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch
        scrollStudyContentTo(choice, in: app)
        choice.tap()
        app.buttons["submitOrAdvance"].tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
        app.buttons["学習を中断"].tap()
        app.buttons["問題一覧へ戻る"].tap()
        app.buttons["solveQuestions"].tap()
        app.buttons["practiceQuestionState"].tap()
        app.buttons["前回不正解（1問）"].tap()
        XCTAssertTrue(app.staticTexts["1問を出題"].exists)
        app.buttons["practiceRandom"].tap()
        XCTAssertTrue(app.staticTexts["1 / 1問"].waitForExistence(timeout: 5))
        app.buttons["学習を中断"].tap()
        app.buttons["問題一覧へ戻る"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["分野別"].tap()
        app.buttons["subject-ネットワーク"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "category-")).firstMatch.tap()
        app.buttons["solveQuestions"].tap()
        XCTAssertTrue(app.buttons["practiceSequential"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["practiceRandom"].exists)
        XCTAssertTrue(app.buttons["practiceQuestionState"].exists)
        XCTAssertFalse(app.buttons["practiceMock"].exists)
        capture("分野別・学習状態と2つの出題方法")
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            capture("失敗時の実画面")
            let hierarchy = XCTAttachment(string: XCUIApplication().debugDescription)
            hierarchy.name = "失敗時のアクセシビリティツリー"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        try super.tearDownWithError()
    }

    func testRedesignedYearGridAndSubjectHierarchy() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        capture("リデザイン・ネットワークホーム")
        app.buttons["homeYears"].tap()
        XCTAssertTrue(app.buttons["year-2025"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["year-2024"].label.contains("25問"))
        XCTAssertTrue(app.buttons["year-2023"].label.contains("25問"))
        XCTAssertTrue(app.buttons["year-2026"].label.contains("2026年予想問題"))
        XCTAssertTrue(app.buttons["year-2026"].label.contains("75問"))
        XCTAssertEqual(app.buttons["year-2026"].frame.minY, app.buttons["year-2025"].frame.minY, accuracy: 1)
        XCTAssertGreaterThan(app.buttons["year-2025"].frame.minX, app.buttons["year-2026"].frame.minX)
        XCTAssertFalse(app.buttons["問題を検索"].exists)
        XCTAssertFalse(app.buttons["year-2010"].exists)
        capture("リデザイン・ネットワーク年度グリッド")
        app.tabBars.buttons["分野別"].tap()
        capture("リデザイン・ネットワーク分野")
        app.buttons["subject-ネットワーク"].tap()
        XCTAssertTrue(app.staticTexts["学びのマップ"].waitForExistence(timeout: 5))
        let category = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "category-")).firstMatch
        XCTAssertTrue(category.exists)
        capture("リデザイン・ネットワーク中分類")
        category.tap()
        XCTAssertTrue(app.buttons["solveQuestions"].waitForExistence(timeout: 5))
    }

    @MainActor func test2026PredictionLocksAndStartsOriginalFixedMock() async throws {
        continueAfterFailure = false
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        XCTAssertTrue(app.buttons["year-2026"].label.contains("ロック中"))
        app.buttons["year-2026"].tap()
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["question-nw-2026-pred-01-q01"].exists)
        buyAndDismissPaywall(in: app)
        app.buttons["year-2026"].tap()
        XCTAssertTrue(app.navigationBars["2026年予想問題"].waitForExistence(timeout: 5))
        for number in 1...3 {
            let set = app.buttons[String(format: "predictionSet-nw-2026-pred-%02d", number)]
            XCTAssertTrue(set.exists)
            XCTAssertTrue(set.label.contains("25問、40分"))
        }
        XCTAssertFalse(app.buttons["模擬試験"].exists)
        capture("2026年予想問題・3セットの選択")
        app.buttons["predictionSet-nw-2026-pred-01"].tap()
        XCTAssertTrue(app.navigationBars["2026年予想問題 第1回"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ネットワーク · 16問"].exists)
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        XCTAssertTrue(app.buttons["solveQuestions"].exists)
        capture("2026年予想問題・分野別の問題一覧")
        startCollectionMock(in: app)
        XCTAssertTrue(app.staticTexts["ピヨトレ！ オリジナル 2026年予想問題 第1回 問1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mockChoice-1"].waitForExistence(timeout: 5))
        app.buttons["mockChoice-1"].tap()
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.staticTexts["ピヨトレ！ オリジナル 2026年予想問題 第1回 問2"].waitForExistence(timeout: 5))
        app.buttons["mockNavigator"].tap()
        let last = app.buttons["mockJump-24"]
        for _ in 0..<8 where !last.isHittable { app.swipeUp() }
        last.tap()
        XCTAssertTrue(app.staticTexts["ピヨトレ！ オリジナル 2026年予想問題 第1回 問25"].waitForExistence(timeout: 5))
        let choice = app.buttons["mockChoice-1"]
        for _ in 0..<8 where !choice.isHittable { app.swipeUp() }
        choice.tap()
        capture("2026年予想問題・第1回25問40分の模擬試験")
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["2 / 25問 · 8%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 23問"].exists)
        capture("2026年予想問題・一括採点結果")
        app.buttons["mockResultFinish"].tap()
        XCTAssertTrue(app.navigationBars["2026年予想問題 第1回"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["2026年予想問題"].waitForExistence(timeout: 5))
        for number in 2...3 {
            let id = String(format: "nw-2026-pred-%02d", number)
            app.buttons["predictionSet-\(id)"].tap()
            XCTAssertTrue(app.navigationBars["2026年予想問題 第\(number)回"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["ネットワーク · 16問"].exists)
            XCTAssertFalse(app.buttons["question-nw-2026-pred-01-q01"].exists)
            XCTAssertTrue(app.buttons["solveQuestions"].exists)
            startCollectionMock(in: app)
            XCTAssertTrue(app.staticTexts["ピヨトレ！ オリジナル 2026年予想問題 第\(number)回 問1"].waitForExistence(timeout: 5))
            let correct = app.buttons["mockChoice-\(number == 2 ? 1 : 2)"]
            XCTAssertTrue(correct.waitForExistence(timeout: 5))
            correct.tap()
            app.buttons["次へ"].tap()
            XCTAssertTrue(app.staticTexts["ピヨトレ！ オリジナル 2026年予想問題 第\(number)回 問2"].waitForExistence(timeout: 5))
            capture("2026年予想問題・第\(number)回25問40分の開始")
            finishMock(in: app)
            XCTAssertTrue(app.staticTexts["1 / 25問 · 4%"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["未回答 24問"].exists)
            app.buttons["mockResultFinish"].tap()
            XCTAssertTrue(app.navigationBars["2026年予想問題 第\(number)回"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["2026年予想問題"].waitForExistence(timeout: 5))
        }
        XCTAssertTrue(app.buttons["predictionSet-nw-2026-pred-01"].label.contains("学習済み2問"))
        XCTAssertTrue(app.buttons["predictionSet-nw-2026-pred-02"].label.contains("学習済み1問"))
        XCTAssertTrue(app.buttons["predictionSet-nw-2026-pred-03"].label.contains("学習済み1問"))
        capture("2026年予想問題・3セット別の学習記録")
        let transaction = try XCTUnwrap(storeKit.allTransactions().first { $0.productIdentifier == "jp.hino.piyotre.networkspecialist.unlock" })
        try storeKit.refundTransaction(identifier: transaction.identifier)
        let lockedSet = app.buttons["predictionSet-nw-2026-pred-03"]
        let locked = NSPredicate(format: "label CONTAINS %@", "ロック中")
        let relocked = expectation(for: locked, evaluatedWith: lockedSet)
        await fulfillment(of: [relocked], timeout: 8)
        lockedSet.tap()
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["question-nw-2026-pred-03-q01"].exists)
    }

    @MainActor func testPredictionSetSelectionAndNewTableSupportLargestText() async throws {
        continueAfterFailure = false
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        let year = app.buttons["year-2026"]
        for _ in 0..<8 where !year.isHittable { app.swipeUp() }
        year.tap()
        buyAndDismissPaywall(in: app)
        year.tap()
        XCTAssertTrue(app.navigationBars["2026年予想問題"].waitForExistence(timeout: 5))
        for number in 1...3 {
            let set = app.buttons[String(format: "predictionSet-nw-2026-pred-%02d", number)]
            for _ in 0..<8 where !set.isHittable { app.swipeUp() }
            XCTAssertTrue(set.isHittable)
            XCTAssertGreaterThanOrEqual(set.frame.height, 44)
            XCTAssertGreaterThanOrEqual(set.frame.minX, 0)
            XCTAssertLessThanOrEqual(set.frame.maxX, app.windows.firstMatch.frame.maxX)
        }
        capture("2026年予想問題・最大文字で3セットを選択")
        let second = app.buttons["predictionSet-nw-2026-pred-02"]
        for _ in 0..<8 where !second.isHittable { app.swipeDown() }
        second.tap()
        XCTAssertTrue(app.navigationBars["2026年予想問題 第2回"].waitForExistence(timeout: 5))
        startCollectionMock(in: app)
        app.buttons["mockNavigator"].tap()
        let question = app.buttons["mockJump-23"]
        for _ in 0..<10 where !question.isHittable { app.swipeUp() }
        question.tap()
        XCTAssertTrue(app.staticTexts["ピヨトレ！ オリジナル 2026年予想問題 第2回 問24"].waitForExistence(timeout: 5))
        let table = app.scrollViews["contentTable"].firstMatch
        XCTAssertTrue(table.exists)
        let firstLink = table.staticTexts["リンク: S → A"]
        scrollMockContentTo(firstLink, in: app)
        XCTAssertTrue(firstLink.isHittable)
        let lastLink = table.staticTexts["リンク: B → T"]
        scrollMockContentTo(lastLink, in: app)
        XCTAssertTrue(lastLink.isHittable)
        XCTAssertTrue(table.staticTexts["容量: 5"].isHittable)
        capture("2026年予想問題・最大文字の最大流量表")
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["0 / 25問 · 0%"].waitForExistence(timeout: 5))
    }

    @MainActor func testPaidYearIsLockedUntilVerifiedPurchase() async throws {
        continueAfterFailure = false
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        openYear(2022, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["question-nw-2022-q01"].exists)
        capture("改訂・有料年度は購入前に入れない")
        buyAndDismissPaywall(in: app)
        openYear(2022, in: app)
        XCTAssertTrue(app.buttons["solveQuestions"].waitForExistence(timeout: 5))
        startCollectionMock(in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2022年春期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        app.buttons["mockSuspend"].tap()
        app.buttons["問題一覧へ戻る"].tap()
        storeKit.clearTransactions()
        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        app.tabBars.buttons["年度別"].tap()
        openYear(2022, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        capture("改訂・購入権限がなくなると再びロック")
    }

    func testPrototypeAnswerAndFigureZoom() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["問題を検索"].tap()
        let graph = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "可変長サブネットマスク")).firstMatch
        for _ in 0..<8 where !graph.isHittable { app.swipeUp() }
        XCTAssertTrue(graph.exists)
        graph.tap()
        let figure = app.buttons["questionFigure"].firstMatch
        XCTAssertTrue(figure.waitForExistence(timeout: 5))
        for _ in 0..<4 where !figure.isHittable { app.swipeUp() }
        figure.tap()
        XCTAssertTrue(app.navigationBars["図を拡大"].waitForExistence(timeout: 5))
        app.buttons["拡大"].tap()
        app.buttons["全体表示"].tap()
        app.buttons["閉じる"].tap()
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 3、")).firstMatch
        for _ in 0..<10 where !choice.isHittable { app.swipeUp() }
        choice.tap()
        app.buttons["回答を確定"].tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["正解: ウ"].exists)
    }

    func testMockInterruptionDiscardsSelectionsAndStartsFresh() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2025"].tap()
        startCollectionMock(in: app)
        XCTAssertTrue(app.buttons["mockChoice-1"].waitForExistence(timeout: 5))
        app.buttons["mockChoice-1"].tap()
        app.buttons["次へ"].tap()
        app.buttons["mockSuspend"].tap()
        app.buttons["問題一覧へ戻る"].tap()
        XCTAssertTrue(app.buttons["solveQuestions"].waitForExistence(timeout: 5))
        startCollectionMock(in: app)
        XCTAssertTrue(app.buttons["mockChoice-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mockChoice-1"].isSelected)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2025年春期 午前Ⅱ 問1"].exists)
        capture("改訂・模試の中断後は最初から")
    }

    func testOfficial2025FixedMockIsFreeAndKeepsOriginalOrder() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2025"].tap()
        startCollectionMock(in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2025年春期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        app.buttons["mockChoice-3"].tap()
        XCTAssertFalse(app.staticTexts["answerOutcome"].exists)
        app.buttons["mockNavigator"].tap()
        let last = app.buttons["mockJump-24"]
        for _ in 0..<8 where !last.isHittable { app.swipeUp() }
        last.tap()
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2025年春期 午前Ⅱ 問25"].waitForExistence(timeout: 5))
        let choice = app.buttons["mockChoice-3"]
        for _ in 0..<8 where !choice.isHittable { app.swipeUp() }
        choice.tap()
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["2 / 25問 · 8%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 23問"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "2025公式25問模試・未回答を含む一括採点"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testImageChoiceZoomDoesNotSelectAnAnswer() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2025"].tap()
        startCollectionMock(in: app)
        app.buttons["mockNavigator"].tap()
        let jump = app.buttons["mockJump-5"]
        for _ in 0..<8 where !jump.isHittable { app.swipeUp() }
        jump.tap()
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2025年春期 午前Ⅱ 問6"].waitForExistence(timeout: 5))
        let originalBrightness = mockBackgroundBrightness(in: app)
        let figures = app.buttons.matching(identifier: "questionFigure")
        XCTAssertEqual(figures.count, 5)
        for index in 1...4 {
            let imageChoice = figures.element(boundBy: index)
            scrollMockContentTo(imageChoice, in: app)
            capture("2025問6・選択肢画像\(index)拡大前")
            XCTAssertFalse(app.buttons["回答を取り消す"].exists, "スクロールだけで回答を選択しない")
            XCTAssertGreaterThanOrEqual(imageChoice.frame.height, 44)
            imageChoice.tap()
            guard app.navigationBars["図を拡大"].waitForExistence(timeout: 5) else {
                XCTFail("選択肢画像\(index)の拡大画面が開きません")
                return
            }
            app.buttons["拡大"].tap()
            app.buttons["全体表示"].tap()
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "2025問6・選択肢画像\(index)拡大"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.navigationBars["図を拡大"].buttons["閉じる"].firstMatch.tap()
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["図を拡大"])
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
            capture("2025問6・選択肢画像\(index)拡大後")
            XCTAssertEqual(mockBackgroundBrightness(in: app), originalBrightness, accuracy: 0.08,
                           "図拡大を閉じても模試のライト/ダーク配色を変更しない")
            XCTAssertFalse(app.buttons["mockChoice-\(index - 1)"].isSelected)
            XCTAssertFalse(app.buttons["回答を取り消す"].exists)
        }
    }

    func testOfficial2023MockFiguresAndTableChoices() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2023"].tap()
        startCollectionMock(in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2023年春期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        for number in [5, 9, 11] {
            app.buttons["mockNavigator"].tap()
            let jump = app.buttons["mockJump-\(number - 1)"]
            for _ in 0..<8 where !jump.isHittable { app.swipeUp() }
            XCTAssertTrue(jump.isHittable)
            jump.tap()
            XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2023年春期 午前Ⅱ 問\(number)"].waitForExistence(timeout: 5))
            let figure = app.buttons["questionFigure"].firstMatch
            for _ in 0..<8 where !figure.isHittable { app.swipeUp() }
            XCTAssertTrue(figure.isHittable)
            figure.tap()
            XCTAssertTrue(app.navigationBars["図を拡大"].waitForExistence(timeout: 5))
            app.buttons["拡大"].tap()
            app.buttons["全体表示"].tap()
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "2023問\(number)・公式フレーム図拡大"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.buttons["閉じる"].tap()
        }
        app.buttons["mockNavigator"].tap()
        let tableQuestion = app.buttons["mockJump-14"]
        for _ in 0..<8 where !tableQuestion.isHittable { app.swipeUp() }
        tableQuestion.tap()
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2023年春期 午前Ⅱ 問15"].waitForExistence(timeout: 5))
        let choice = app.buttons["mockChoice-2"]
        scrollMockContentTo(choice, in: app)
        XCTAssertTrue(choice.label.contains("IEEE 802.11n"))
        XCTAssertTrue(choice.label.contains("IEEE 802.11ac"))
        choice.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: choice)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
        XCTAssertFalse(app.staticTexts["answerOutcome"].exists)
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["1 / 25問 · 4%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 24問"].exists)
    }

    func testInterruptedMockDoesNotResumeAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2025"].tap()
        startCollectionMock(in: app)
        app.buttons["mockChoice-0"].tap()
        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        if app.buttons["skipDiagnosis"].waitForExistence(timeout: 2) { app.buttons["skipDiagnosis"].tap() }
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2025"].tap()
        startCollectionMock(in: app)
        XCTAssertFalse(app.buttons["mockChoice-0"].isSelected)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "続きから")).firstMatch.exists)
    }

    func testLandscapeOfficialMockNavigationAndUnansweredGrading() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2025"].tap()
        startCollectionMock(in: app)
        XCTAssertTrue(app.buttons["mockNavigator"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            window.frame.width > window.frame.height
        }, object: app)
        guard XCTWaiter.wait(for: [rotated], timeout: 10) == .completed else {
            XCTFail("実ウィンドウが横向きに切り替わりません")
            return
        }
        let timer = app.staticTexts["mockRemainingTime"]
        XCTAssertTrue(timer.isHittable)
        XCTAssertNotNil((timer.value as? String)?.range(of: "^[0-9]{2}:[0-9]{2}$", options: .regularExpression))
        for control in [timer, app.buttons["mockNavigator"], app.buttons["次へ"], app.buttons["mockFinish"]] {
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.minX, window.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, window.frame.maxX)
            XCTAssertGreaterThanOrEqual(control.frame.minY, window.frame.minY)
            XCTAssertLessThanOrEqual(control.frame.maxY, window.frame.maxY)
        }
        capture("NW公式模試・横向き・残り時間と下部操作")
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2025年春期 午前Ⅱ 問2"].waitForExistence(timeout: 5))
        app.buttons["mockNavigator"].tap()
        XCTAssertTrue(app.buttons["mockJump-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mockJump-0"].label.contains("未回答"))
        app.buttons["mockJump-0"].tap()
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2025年春期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["回答を取り消す"].exists)
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["0 / 25問 · 0%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 25問"].exists)
        capture("NW公式模試・横向き・全問未回答の採点")
    }

    func testLargestTextMockNavigationAndFinishRemainAccessible() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        if app.buttons["skipDiagnosis"].waitForExistence(timeout: 2) { app.buttons["skipDiagnosis"].tap() }
        app.tabBars.buttons["年度別"].tap()
        app.buttons["year-2025"].tap()
        startCollectionMock(in: app)
        XCTAssertTrue(app.buttons["mockNavigator"].waitForExistence(timeout: 5))
        let timer = app.staticTexts["mockRemainingTime"]
        XCTAssertTrue(timer.isHittable)
        XCTAssertNotNil((timer.value as? String)?.range(of: "^[0-9]{2}:[0-9]{2}$", options: .regularExpression))
        XCTAssertGreaterThanOrEqual(timer.frame.minX, app.windows.firstMatch.frame.minX)
        XCTAssertLessThanOrEqual(timer.frame.maxX, app.windows.firstMatch.frame.maxX)
        for name in ["mockNavigator", "次へ", "終了して採点"] {
            let control = app.buttons[name]
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.windows.firstMatch.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.windows.firstMatch.frame.maxX)
        }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "NW模試・最大文字サイズ・下部操作"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["次へ"].tap()
        app.buttons["mockNavigator"].tap()
        XCTAssertTrue(app.buttons["mockJump-0"].waitForExistence(timeout: 5))
    }

    func testPaid2010PurchaseMultipleFiguresAndResumeGate() throws {
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        open2010Year(in: app)
        XCTAssertFalse(app.buttons["順番に回答 · 0問"].isEnabled)
        let locked = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "データ伝送網")).firstMatch
        XCTAssertTrue(locked.label.contains("全問題解放が必要"))
        locked.tap()
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        XCTAssertFalse(app.staticTexts["正解: エ"].exists)
        capture("2010問23・未購入は本文図と解説を開けない")
        buyAndDismissPaywall(in: app)
        XCTAssertTrue(app.buttons["順番に回答 · 1問"].waitForExistence(timeout: 5))
        app.buttons["順番に回答 · 1問"].tap()
        verify2010Figures(in: app)
        app.buttons["学習を中断"].tap()
        app.buttons["問題一覧へ戻る"].tap()
        app.terminate()
        storeKit.clearTransactions()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        app.buttons["resumeStudy"].tap()
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        XCTAssertFalse(app.staticTexts["正解: エ"].exists)
        capture("2010問23・購入権限消去後の再開は購入画面へ")
        buyAndDismissPaywall(in: app)
        app.buttons["resumeStudy"].tap()
        XCTAssertTrue(app.buttons["questionFigure"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "questionFigure").count, 3)
        let correct = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 4、")).firstMatch
        scrollStudyContentTo(correct, in: app)
        correct.tap()
        app.buttons["submitOrAdvance"].tap()
        XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["正解: エ"].exists)
        capture("2010問23・購入後の通常演習正答と解説")
    }

    func testPaid2021And2022OfficialMocksPurchaseResumeFiguresAndGrading() throws {
        XCUIDevice.shared.orientation = .portrait
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        openMockLibrary(in: app)
        openPaidMock(year: 2022, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mockNavigator"].exists)
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        capture("2022公式模試・未購入は開始不可")
        buyAndDismissPaywall(in: app)
        openPaidMock(year: 2022, in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2022年春期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        selectMockChoice(3, in: app)
        jumpToMockQuestion(10, year: 2022, in: app)
        verifyPaidMockFigure(year: 2022, number: 10, in: app)
        selectMockChoice(2, in: app)
        app.buttons["mockSuspend"].tap()
        app.buttons["問題一覧へ戻る"].tap()
        app.terminate()
        storeKit.clearTransactions()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        openMockLibrary(in: app)
        let resume = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "続きから")).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mockNavigator"].exists)
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        capture("2022公式模試・権限消去後の保存再開ゲート")
        buyAndDismissPaywall(in: app)
        resume.tap()
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2022年春期 午前Ⅱ 問10"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mockChoice-2"].isSelected)
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["2 / 25問 · 8%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 23問"].exists)
        capture("2022公式模試・保存回答の一括採点")
        app.buttons["mockResultFinish"].tap()
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH %@", "年の問題")).firstMatch.waitForExistence(timeout: 5))

        openPaidMock(year: 2021, in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2021年春期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        for number in [4, 7, 10] {
            jumpToMockQuestion(number, year: 2021, in: app)
            verifyPaidMockFigure(year: 2021, number: number, in: app)
            selectMockChoice(2, in: app)
        }
        jumpToMockQuestion(22, year: 2021, in: app)
        let table = app.scrollViews["contentTable"].firstMatch
        scrollMockContentTo(table, in: app)
        // Table cells expose their column header together with the value.
        // Check that association rather than a non-existent bare-value label.
        for cell in ["演算命令: 浮動小数点加算", "演算命令: 浮動小数点乗算", "演算命令: 整数演算",
                     "CPI（Cycles Per Instruction）: 3", "CPI（Cycles Per Instruction）: 5", "CPI（Cycles Per Instruction）: 2",
                     "構成比率（%）: 20", "構成比率（%）: 60"] {
            XCTAssertTrue(table.staticTexts[cell].firstMatch.exists, cell)
        }
        capture("2021問22・公式CPI表の左端")
        let trailing = table.staticTexts["構成比率（%）"]
        let firstColumn = table.staticTexts["演算命令"]
        let before = firstColumn.frame.minX
        for _ in 0..<8 where trailing.frame.maxX > table.frame.maxX + 1 {
            table.swipeLeft()
        }
        XCTAssertLessThan(firstColumn.frame.minX, before - 40)
        XCTAssertLessThanOrEqual(trailing.frame.maxX, table.frame.maxX + 1)
        XCTAssertFalse(app.buttons["回答を取り消す"].exists)
        capture("2021問22・公式CPI表の右端と構成比率")
        selectMockChoice(1, in: app)
        jumpToMockQuestion(23, year: 2021, in: app)
        selectMockChoice(2, in: app)
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["5 / 25問 · 20%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 20問"].exists)
        capture("2021公式模試・図表計算5問の一括採点")
        app.buttons["mockResultFinish"].tap()
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH %@", "年の問題")).firstMatch.waitForExistence(timeout: 5))
    }

    private func startCollectionMock(in app: XCUIApplication) {
        let solve = app.buttons["solveQuestions"]
        XCTAssertTrue(solve.waitForExistence(timeout: 5))
        for _ in 0..<20 where !solve.isHittable { app.swipeDown() }
        solve.tap()
        let mock = app.buttons["practiceMock"]
        XCTAssertTrue(mock.waitForExistence(timeout: 5))
        mock.tap()
    }

    private func openMockLibrary(in app: XCUIApplication) {
        app.tabBars.buttons["年度別"].tap()
        XCTAssertTrue(app.navigationBars["年度別演習"].waitForExistence(timeout: 5))
    }

    private func openPaidMock(year: Int, in app: XCUIApplication) {
        openYear(year, in: app)
        if app.buttons["solveQuestions"].waitForExistence(timeout: 2) { startCollectionMock(in: app) }
    }

    private func jumpToMockQuestion(_ number: Int, year: Int, in app: XCUIApplication) {
        app.buttons["mockNavigator"].tap()
        let row = app.buttons["mockJump-\(number - 1)"]
        for _ in 0..<15 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 \(year)年\(year < 2020 ? "秋期" : "春期") 午前Ⅱ 問\(number)"].waitForExistence(timeout: 5))
    }

    private func selectMockChoice(_ index: Int, in app: XCUIApplication) {
        let choice = app.buttons["mockChoice-\(index)"]
        scrollMockContentTo(choice, in: app)
        choice.tap()
        XCTAssertTrue(choice.isSelected)
        XCTAssertFalse(app.staticTexts["answerOutcome"].exists)
    }

    func testPaid2019OfficialOSPFChoicesAndProcessorFigures() throws {
        XCUIDevice.shared.orientation = .portrait
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        openMockLibrary(in: app)
        openPaidMock(year: 2019, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mockNavigator"].exists)
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        capture("2019公式模試・未購入ゲート")
        buyAndDismissPaywall(in: app)
        openPaidMock(year: 2019, in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2019年秋期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        jumpToMockQuestion(2, year: 2019, in: app)
        verifyPaidMockFigure(year: 2019, number: 2, in: app)
        let table = app.scrollViews.matching(identifier: "contentTable").element(boundBy: 1)
        scrollMockContentTo(table, in: app)
        XCTAssertTrue(table.staticTexts["x: 30"].exists)
        XCTAssertTrue(table.staticTexts["y: 30"].exists)
        capture("2019問2・公式選択肢イのコスト表")
        selectMockChoice(1, in: app)
        jumpToMockQuestion(22, year: 2019, in: app)
        verifyPaidMockFigure(year: 2019, number: 22, in: app)
        selectMockChoice(3, in: app)
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["2 / 25問 · 8%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 23問"].exists)
        capture("2019公式模試・原問図表と一括採点")
        app.buttons["mockResultFinish"].tap()
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH %@", "年の問題")).firstMatch.waitForExistence(timeout: 5))
    }

    func testPaid2017OfficialMockCalculationsAndCurrentHTTPNote() throws {
        XCUIDevice.shared.orientation = .portrait
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        openMockLibrary(in: app)
        openPaidMock(year: 2017, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mockNavigator"].exists)
        buyAndDismissPaywall(in: app)
        openPaidMock(year: 2017, in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2017年秋期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        for (number, correct) in [(2, 3), (10, 0), (12, 1), (23, 2)] {
            jumpToMockQuestion(number, year: 2017, in: app)
            selectMockChoice(correct, in: app)
            capture("2017問\(number)・公式四肢と採点前の選択")
        }
        // A selected response can still be changed before the single grading.
        jumpToMockQuestion(10, year: 2017, in: app)
        selectMockChoice(2, in: app)
        selectMockChoice(0, in: app)
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["4 / 25問 · 16%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 21問"].exists)
        capture("2017公式模試・4問正答と21問未回答の一括採点")
        let detail = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ネットワークスペシャリスト試験 2017年秋期 午前Ⅱ 問10")).firstMatch
        scrollResultContentTo(detail, in: app)
        detail.tap()
        let caveat = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "HTTP/3", "QUIC/UDP")).firstMatch
        scrollResultContentTo(caveat, in: app)
        XCTAssertTrue(caveat.isHittable)
        capture("2017問10・原試験の正答と現在のHTTP3補足")
    }

    func testPaid2016OriginalFiguresRoutingAndChoiceTables() throws {
        XCUIDevice.shared.orientation = .portrait
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        openMockLibrary(in: app)
        openPaidMock(year: 2016, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mockNavigator"].exists)
        buyAndDismissPaywall(in: app)
        openPaidMock(year: 2016, in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2016年秋期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        for (number, correct) in [(3, 2), (4, 1), (7, 2), (13, 0)] {
            jumpToMockQuestion(number, year: 2016, in: app)
            verifyPaidMockFigure(year: 2016, number: number, in: app)
            if number == 4 {
                let table = app.scrollViews.matching(identifier: "contentTable").element(boundBy: 1)
                scrollMockContentTo(table, in: app)
                XCTAssertTrue(table.staticTexts["x: 30"].exists)
                XCTAssertTrue(table.staticTexts["y: 30"].exists)
                capture("2016問4・公式OSPF選択肢イの原順表")
            } else if number == 13 {
                let table = app.scrollViews["contentTable"].firstMatch
                for value in ["10.0.0.0", "10.64.0.0", "10.96.0.0", "10.128.0.0", "0.0.0.0"] {
                    XCTAssertTrue(table.staticTexts["宛先アドレス: \(value)"].firstMatch.exists)
                }
                verify2016TableEnds(table, first: "宛先アドレス", last: "ネクストホップ", number: number, in: app)
                XCTAssertTrue(table.staticTexts["ネクストホップ: 192.168.0.1"].exists)
            }
            selectMockChoice(correct, in: app)
        }
        for number in [20, 24] {
            jumpToMockQuestion(number, year: 2016, in: app)
            let table = app.scrollViews.matching(identifier: "contentTable").element(boundBy: 2)
            let first = number == 20 ? "送信元" : "システム方式設計"
            let last = number == 20 ? "宛先ポート番号" : "ソフトウェア詳細設計"
            verify2016TableEnds(table, first: first, last: last, number: number, in: app)
            XCTAssertTrue(table.staticTexts[number == 20 ? "宛先ポート番号: 1024以上" : "ソフトウェア詳細設計: ソフトウェアユニットテスト"].exists)
            selectMockChoice(2, in: app)
        }
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["6 / 25問 · 24%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 19問"].exists)
        capture("2016公式模試・図表6問の正答と19問未回答")
    }

    func testPaid2014OriginalVLSMTableAndAllFractionChoices() throws {
        XCUIDevice.shared.orientation = .portrait
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        openMockLibrary(in: app)
        openPaidMock(year: 2014, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mockNavigator"].exists)
        XCTAssertFalse(app.buttons["questionFigure"].exists)
        buyAndDismissPaywall(in: app)
        openPaidMock(year: 2014, in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2014年秋期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        let literals = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "2001:db8::b083:ba94:60c7:7c36", "fe80::200:c0ff:fea8:2")).firstMatch
        scrollMockContentTo(literals, in: app)
        capture("2014問1・原文のIPv6アドレス等幅表示")
        selectMockChoice(3, in: app)
        jumpToMockQuestion(10, year: 2014, in: app)
        verifyPaidMockFigure(year: 2014, number: 10, in: app)
        let table = app.scrollViews.matching(identifier: "contentTable").element(boundBy: 2)
        scrollMockContentTo(table, in: app)
        XCTAssertTrue(table.staticTexts["ネットワークアドレス: 172.16.1.128"].exists)
        capture("2014問10・公式選択肢ウの表左端")
        let trailing = table.staticTexts["サブネットマスク: 255.255.255.192"]
        table.swipeLeft()
        for _ in 0..<8 where trailing.frame.maxX > table.frame.maxX + 1 { table.swipeLeft() }
        XCTAssertLessThanOrEqual(trailing.frame.maxX, table.frame.maxX + 1)
        XCTAssertGreaterThanOrEqual(trailing.frame.minX, table.frame.minX - 1)
        XCTAssertTrue(table.staticTexts["サブネットマスク: 255.255.255.192"].exists)
        XCTAssertFalse(app.buttons["回答を取り消す"].exists)
        capture("2014問10・公式選択肢表右端のマスク値全桁（検査v2）")
        selectMockChoice(2, in: app)
        jumpToMockQuestion(24, year: 2014, in: app)
        let figures = app.buttons.matching(identifier: "questionFigure")
        XCTAssertEqual(figures.count, 4)
        for index in 0..<4 {
            let figure = figures.element(boundBy: index)
            scrollMockContentTo(figure, in: app)
            XCTAssertGreaterThanOrEqual(figure.frame.height, 44)
            XCTAssertFalse(app.buttons["回答を取り消す"].exists)
            let brightness = mockBackgroundBrightness(in: app)
            capture("2014問24・原式選択肢\(index + 1)の模試表示")
            figure.tap()
            XCTAssertTrue(app.navigationBars["図を拡大"].waitForExistence(timeout: 5))
            app.buttons["拡大"].tap()
            app.buttons["全体表示"].tap()
            capture("2014問24・原式選択肢\(index + 1)の拡大")
            app.navigationBars["図を拡大"].buttons["閉じる"].firstMatch.tap()
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["図を拡大"])
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
            XCTAssertEqual(mockBackgroundBrightness(in: app), brightness, accuracy: 0.08)
            XCTAssertFalse(app.buttons["回答を取り消す"].exists, "数式選択肢の拡大だけで回答しない")
            capture("2014問24・原式閉鎖後\(index + 1)の配色")
        }
        selectMockChoice(3, in: app)
        selectMockChoice(0, in: app)
        for (number, correct) in [(3, 3), (13, 0), (21, 2), (23, 3)] {
            jumpToMockQuestion(number, year: 2014, in: app)
            selectMockChoice(correct, in: app)
        }
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["7 / 25問 · 28%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 18問"].exists)
        capture("2014公式模試・7正答18未回答の一括採点")
        let detail = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ネットワークスペシャリスト試験 2014年秋期 午前Ⅱ 問21")).firstMatch
        scrollResultContentTo(detail, in: app)
        detail.tap()
        let caveat = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "SMTP AUTH", "共有/NAT")).firstMatch
        scrollResultContentTo(caveat, in: app)
        XCTAssertTrue(caveat.isHittable)
        capture("2014問21・原試験の旧方式と現行の投稿認証補足")
    }

    func testPaid2013TCPChoiceFiguresAndMIMEOriginalLines() throws {
        XCUIDevice.shared.orientation = .portrait
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        openMockLibrary(in: app)
        openPaidMock(year: 2013, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mockNavigator"].exists)
        buyAndDismissPaywall(in: app)
        openPaidMock(year: 2013, in: app)
        XCTAssertTrue(app.staticTexts["ネットワークスペシャリスト試験 2013年秋期 午前Ⅱ 問1"].waitForExistence(timeout: 5))
        selectMockChoice(1, in: app)
        jumpToMockQuestion(4, year: 2013, in: app)
        verifyPaidMockFigure(year: 2013, number: 4, in: app)
        let table = app.scrollViews.matching(identifier: "contentTable").element(boundBy: 1)
        scrollMockContentTo(table, in: app)
        XCTAssertTrue(table.staticTexts["x: 30"].exists)
        XCTAssertTrue(table.staticTexts["y: 30"].exists)
        capture("2013問4・原選択肢イのx/y表")
        selectMockChoice(1, in: app)
        jumpToMockQuestion(13, year: 2013, in: app)
        let figures = app.buttons.matching(identifier: "questionFigure")
        XCTAssertEqual(figures.count, 4)
        for index in 0..<4 {
            let figure = figures.element(boundBy: index)
            scrollMockContentTo(figure, in: app)
            XCTAssertGreaterThanOrEqual(figure.frame.height, 44)
            XCTAssertFalse(app.buttons["回答を取り消す"].exists)
            let brightness = mockBackgroundBrightness(in: app)
            capture("2013問13・原TCP手順選択肢\(index + 1)の模試表示")
            figure.tap()
            XCTAssertTrue(app.navigationBars["図を拡大"].waitForExistence(timeout: 5))
            app.buttons["拡大"].tap()
            app.buttons["全体表示"].tap()
            capture("2013問13・原TCP手順選択肢\(index + 1)の拡大")
            app.navigationBars["図を拡大"].buttons["閉じる"].firstMatch.tap()
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["図を拡大"])
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
            XCTAssertEqual(mockBackgroundBrightness(in: app), brightness, accuracy: 0.08)
            XCTAssertFalse(app.buttons["回答を取り消す"].exists, "TCP原図の拡大だけで回答しない")
            capture("2013問13・原図閉鎖後\(index + 1)の配色")
        }
        selectMockChoice(2, in: app)
        selectMockChoice(0, in: app)
        jumpToMockQuestion(16, year: 2013, in: app)
        let token = "=?ISO-2022-JP?B?GyRCPnBKc0JATzobKEI=?="
        let lines = ["From: <\(token)> taro@example.jp", "From: <taro@example.jp> \(token)",
                     "From: \(token) <taro@example.jp>", "From: taro@example.jp <\(token)>"]
        for index in 0..<4 {
            let code = app.scrollViews.matching(identifier: "contentMonospace").element(boundBy: index + 1)
            scrollMockContentTo(code, in: app)
            let text = code.staticTexts["contentCodeText"].firstMatch
            XCTAssertEqual(text.label, lines[index])
            capture("2013問16・原From選択肢\(index + 1)左端")
            code.swipeLeft()
            for _ in 0..<10 where text.frame.maxX > code.frame.maxX + 1 { code.swipeLeft() }
            XCTAssertLessThanOrEqual(text.frame.maxX, code.frame.maxX + 1)
            XCTAssertFalse(app.buttons["回答を取り消す"].exists)
            capture("2013問16・原From選択肢\(index + 1)右末尾")
        }
        selectMockChoice(2, in: app)
        for (number, correct) in [(24, 1), (25, 1)] {
            jumpToMockQuestion(number, year: 2013, in: app)
            verifyPaidMockFigure(year: 2013, number: number, in: app)
            selectMockChoice(correct, in: app)
        }
        for (number, correct) in [(2, 3), (14, 1), (15, 3), (18, 1), (22, 1)] {
            jumpToMockQuestion(number, year: 2013, in: app)
            selectMockChoice(correct, in: app)
        }
        finishMock(in: app)
        XCTAssertTrue(app.staticTexts["11 / 25問 · 44%"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未回答 14問"].exists)
        capture("2013公式模試・11正答14未回答の一括採点")
        let detail = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ネットワークスペシャリスト試験 2013年秋期 午前Ⅱ 問16")).firstMatch
        scrollResultContentTo(detail, in: app)
        detail.tap()
        let caveat = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "SMTPUTF8", "暗号化/本人認証ではなく")).firstMatch
        scrollResultContentTo(caveat, in: app)
        XCTAssertTrue(caveat.isHittable)
        capture("2013問16・原MIME形式と現行UTF-8補足/符号化の役割")
    }

    private func verify2016TableEnds(_ table: XCUIElement, first: String, last: String, number: Int, in app: XCUIApplication) {
        scrollMockContentTo(table, in: app)
        XCTAssertTrue(table.staticTexts[first].exists)
        capture("2016問\(number)・公式表の左端")
        let trailing = table.staticTexts[last]
        for _ in 0..<8 where trailing.frame.maxX > table.frame.maxX + 1 { table.swipeLeft() }
        XCTAssertLessThanOrEqual(trailing.frame.maxX, table.frame.maxX + 1)
        XCTAssertFalse(app.buttons["回答を取り消す"].exists)
        capture("2016問\(number)・公式表の右端と見出し")
    }

    private func scrollResultContentTo(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let scroll = app.scrollViews["mockResultScroll"]
        let top = max(scroll.frame.minY, app.navigationBars["模試の結果"].frame.maxY) + 12
        let bottom = min(scroll.frame.maxY, app.buttons["mockResultFinish"].frame.minY) - 12
        let needed = min(80, element.frame.height)
        for _ in 0..<32 {
            if element.frame.minY >= top && element.frame.minY + needed <= bottom { break }
            let down = element.frame.minY < top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: scroll.frame.minX + 8, dy: down ? top + 30 : bottom - 30))
            let end = start.withOffset(CGVector(dx: 0, dy: (down ? 1 : -1) * (bottom - top) / 2))
            start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertGreaterThanOrEqual(element.frame.minY, top)
        XCTAssertLessThanOrEqual(element.frame.minY + needed, bottom)
    }

    private func verifyPaidMockFigure(year: Int, number: Int, in app: XCUIApplication) {
        let figure = app.buttons["questionFigure"].firstMatch
        scrollMockContentTo(figure, in: app)
        XCTAssertGreaterThanOrEqual(figure.frame.height, 44)
        XCTAssertFalse(app.buttons["回答を取り消す"].exists)
        let brightness = mockBackgroundBrightness(in: app)
        capture("\(year)問\(number)・公式原図の模試表示")
        figure.tap()
        XCTAssertTrue(app.navigationBars["図を拡大"].waitForExistence(timeout: 5))
        app.buttons["拡大"].tap()
        app.buttons["全体表示"].tap()
        capture("\(year)問\(number)・公式原図の拡大")
        app.navigationBars["図を拡大"].buttons["閉じる"].firstMatch.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["図を拡大"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        XCTAssertEqual(mockBackgroundBrightness(in: app), brightness, accuracy: 0.08)
        XCTAssertFalse(app.buttons["回答を取り消す"].exists)
    }

    @MainActor func testPaid2010LargestTextMultipleFigureZoom() async throws {
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        _ = try await storeKit.buyProduct(identifier: "jp.hino.piyotre.networkspecialist.unlock")
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        open2010Year(in: app)
        XCTAssertTrue(app.buttons["順番に回答 · 1問"].waitForExistence(timeout: 5))
        app.buttons["順番に回答 · 1問"].tap()
        verify2010Figures(in: app)
        let submit = app.buttons["submitOrAdvance"]
        XCTAssertTrue(submit.isHittable)
        XCTAssertGreaterThanOrEqual(submit.frame.height, 44)
        XCTAssertLessThanOrEqual(submit.frame.maxX, app.windows.firstMatch.frame.maxX)
        XCTAssertFalse(submit.isEnabled, "図を見るだけでは回答は選ばれない")
        capture("2010問23・最大文字・3図拡大後の演習と下部操作")
    }

    private func open2010Year(in app: XCUIApplication) {
        openYear(2010, in: app)
    }

    private func openYear(_ value: Int, in app: XCUIApplication) {
        app.tabBars.buttons["年度別"].tap()
        if app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH %@", "年の問題")).firstMatch.exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let year = app.buttons["year-\(value)"]
        let top = app.navigationBars["年度別演習"].frame.maxY + 56
        let bottom = app.tabBars.firstMatch.frame.minY - 64
        // Fast full-screen swipes can skip a lazily created year row at XXXL.
        // Move less than half a viewport and keep the row clear of both bars.
        for _ in 0..<40 {
            if year.exists && year.isHittable && year.frame.minY >= top && year.frame.maxY <= bottom { break }
            let down = year.exists && year.frame.minY < top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: 8, dy: down ? top + 30 : bottom - 30))
            let end = start.withOffset(CGVector(dx: 0, dy: (down ? 1 : -1) * (bottom - top) / 2))
            start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(year.isHittable)
        year.tap()
    }

    func testPaidPartial2018PurchaseAndOfficialFigureStudy() throws {
        XCUIDevice.shared.orientation = .portrait
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        openYear(2018, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        capture("2018部分年度・購入前の解放ゲート")
        buyAndDismissPaywall(in: app)
        openYear(2018, in: app)
        XCTAssertTrue(app.buttons["solveQuestions"].waitForExistence(timeout: 5))
        for (number, keyword, choice, answer) in [(4, "MTU", 1, "ア"), (6, "プロキシARP", 2, "イ")] {
            app.swipeDown()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            if let text = search.value as? String, !text.isEmpty, !text.contains("検索") {
                search.buttons["テキストを消去"].tap()
            }
            search.typeText(keyword)
            search.typeText("\n")
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", keyword, "利用可能")).firstMatch
            for _ in 0..<8 where !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.isHittable)
            row.tap()
            let questionScroll = app.scrollViews["studyQuestionScroll"]
            XCTAssertTrue(questionScroll.waitForExistence(timeout: 5))
            // Ordinary study uses year/subject at the top; the full source is
            // shown with the answer, unlike the mock's source-only header.
            XCTAssertTrue(questionScroll.staticTexts["2018 · ネットワーク"].exists)
            let prefix = number == 4 ? "図のイーサネットパケットのMTU" : "図のような2台のレイヤ2スイッチ"
            XCTAssertTrue(questionScroll.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch.exists)
            let figure = app.buttons["questionFigure"].firstMatch
            scrollStudyContentTo(figure, in: app)
            XCTAssertGreaterThanOrEqual(figure.frame.height, 44)
            let brightness = studyBackgroundBrightness(in: app)
            XCTAssertFalse(app.buttons["submitOrAdvance"].isEnabled)
            capture("2018問\(number)・公式原図の通常演習")
            figure.tap()
            XCTAssertTrue(app.navigationBars["図を拡大"].waitForExistence(timeout: 5))
            app.buttons["拡大"].tap()
            app.buttons["全体表示"].tap()
            capture("2018問\(number)・公式原図拡大")
            app.navigationBars["図を拡大"].buttons["閉じる"].firstMatch.tap()
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["図を拡大"])
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
            XCTAssertEqual(studyBackgroundBrightness(in: app), brightness, accuracy: 0.08)
            XCTAssertFalse(app.buttons["submitOrAdvance"].isEnabled)
            let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 \(choice)、")).firstMatch
            scrollStudyContentTo(option, in: app)
            option.tap()
            app.buttons["submitOrAdvance"].tap()
            XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["正解: \(answer)"].exists)
            capture("2018問\(number)・正答と独自解説")
            app.buttons["submitOrAdvance"].tap()
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: questionScroll)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
            XCTAssertTrue(app.navigationBars["2018年の問題"].waitForExistence(timeout: 5))
        }
        // Relaunch without resetting either the answers or the purchase. The
        // background year navigation bar exists while a study sheet dismisses;
        // a generic navigation-button query can hit its lingering Close button.
        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        openMockLibrary(in: app)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "2018年秋期")).firstMatch.exists)
    }

    func testPaidPartial2015PurchaseAndOriginalFormulaAndRelationChoices() throws {
        XCUIDevice.shared.orientation = .portrait
        let storeKit = try SKTestSession(configurationFileNamed: "products")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()
        defer { storeKit.clearTransactions() }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        openYear(2015, in: app)
        XCTAssertTrue(app.navigationBars["全問題を解放"].waitForExistence(timeout: 5))
        buyAndDismissPaywall(in: app)
        XCTAssertTrue(app.buttons["順番に回答 · 24問"].waitForExistence(timeout: 5))
        for (number, keyword, figureCount) in [(23, "アムダール", 1), (24, "is-a", 4)] {
            app.swipeDown()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            if let text = search.value as? String, !text.isEmpty, !text.contains("検索") {
                search.buttons["テキストを消去"].tap()
            }
            search.typeText(keyword)
            search.typeText("\n")
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", keyword, "利用可能")).firstMatch
            for _ in 0..<8 where !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.isHittable)
            row.tap()
            let scroll = app.scrollViews["studyQuestionScroll"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 5))
            XCTAssertTrue(scroll.staticTexts["2015 · \(number == 23 ? "コンピュータシステム" : "システム開発技術")"].exists)
            let figures = app.buttons.matching(identifier: "questionFigure")
            XCTAssertEqual(figures.count, figureCount)
            for index in 0..<figureCount {
                let figure = figures.element(boundBy: index)
                scrollStudyContentTo(figure, in: app)
                XCTAssertGreaterThanOrEqual(figure.frame.height, 44)
                XCTAssertFalse(app.buttons["submitOrAdvance"].isEnabled)
                let brightness = studyBackgroundBrightness(in: app)
                capture("2015問\(number)・原式/原図\(index + 1)拡大前")
                figure.tap()
                XCTAssertTrue(app.navigationBars["図を拡大"].waitForExistence(timeout: 5))
                app.buttons["拡大"].tap()
                app.buttons["全体表示"].tap()
                capture("2015問\(number)・原式/原図\(index + 1)拡大")
                app.navigationBars["図を拡大"].buttons["閉じる"].firstMatch.tap()
                let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["図を拡大"])
                XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
                XCTAssertEqual(studyBackgroundBrightness(in: app), brightness, accuracy: 0.08)
                XCTAssertFalse(app.buttons["submitOrAdvance"].isEnabled, "選択肢図の拡大だけで回答しない")
                capture("2015問\(number)・原式/原図\(index + 1)閉鎖後")
            }
            let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 3、")).firstMatch
            scrollStudyContentTo(option, in: app)
            option.tap()
            app.buttons["submitOrAdvance"].tap()
            XCTAssertTrue(app.staticTexts["answerOutcome"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["正解: ウ"].exists)
            capture("2015問\(number)・公式正答ウと全肢解説")
            app.buttons["submitOrAdvance"].tap()
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: scroll)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
            XCTAssertTrue(app.navigationBars["2015年の問題"].waitForExistence(timeout: 5))
        }
        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        openMockLibrary(in: app)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "2015年秋期")).firstMatch.exists)
    }

    private func buyAndDismissPaywall(in app: XCUIApplication) {
        let buy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "買い切り ")).firstMatch
        XCTAssertTrue(buy.waitForExistence(timeout: 10))
        XCTAssertTrue(buy.label.contains("300"))
        for _ in 0..<8 where !buy.isHittable { app.swipeUp() }
        capture("購入画面・300円買い切り")
        buy.tap()
        let done = app.buttons["学習を続ける"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["全問題を解放"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    }

    private func verify2010Figures(in app: XCUIApplication) {
        let figures = app.buttons.matching(identifier: "questionFigure")
        XCTAssertTrue(figures.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(figures.count, 3)
        for (index, name) in ["A", "B", "C"].enumerated() {
            let figure = figures.element(boundBy: index)
            XCTAssertTrue(figure.label.hasPrefix("\(name)案。"))
            scrollStudyContentTo(figure, in: app)
            XCTAssertGreaterThanOrEqual(figure.frame.height, 44)
            let brightness = studyBackgroundBrightness(in: app)
            XCTAssertFalse(app.buttons["submitOrAdvance"].isEnabled)
            XCTAssertGreaterThanOrEqual(disabledSubmitContrast(in: app), 3,
                                       "未回答の無効ボタンでも操作名が実画面で読める")
            capture("2010問23・\(name)案の演習表示")
            figure.tap()
            guard app.navigationBars["図を拡大"].waitForExistence(timeout: 5) else {
                XCTFail("\(name)案の拡大画面が開きません")
                return
            }
            app.buttons["拡大"].tap()
            app.buttons["全体表示"].tap()
            capture("2010問23・\(name)案の公式原図拡大")
            app.navigationBars["図を拡大"].buttons["閉じる"].firstMatch.tap()
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["図を拡大"])
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
            XCTAssertEqual(studyBackgroundBrightness(in: app), brightness, accuracy: 0.08,
                           "図拡大の閉鎖後も演習の配色を維持する")
            XCTAssertFalse(app.buttons["submitOrAdvance"].isEnabled)
        }
    }

    private func scrollStudyContentTo(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let scroll = app.scrollViews.firstMatch
        let top = max(scroll.frame.minY, app.buttons["学習を中断"].frame.maxY) + 12
        let bottom = min(scroll.frame.maxY, app.buttons["submitOrAdvance"].frame.minY - 16) - 12
        for _ in 0..<16 {
            if element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { break }
            let down = element.frame.minY < top
            let overflow = down ? top - element.frame.minY : element.frame.maxY - bottom
            let distance = min((bottom - top) / 2, max(120, overflow + 12))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: scroll.frame.minX + 8, dy: down ? top + 30 : bottom - 30))
            let end = start.withOffset(CGVector(dx: 0, dy: down ? distance : -distance))
            start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertGreaterThanOrEqual(element.frame.minY, top)
        XCTAssertLessThanOrEqual(element.frame.maxY, bottom)
    }

    private func studyBackgroundBrightness(in app: XCUIApplication) -> Double {
        let scroll = app.scrollViews.firstMatch.frame
        let bottom = min(scroll.maxY, app.buttons["submitOrAdvance"].frame.minY - 16)
        return backgroundBrightness(in: app, at: CGPoint(x: scroll.minX + 8, y: bottom - 24))
    }

    @MainActor func testDisabledSubmitContrastDetectsMissingAndFadedInk() {
        let window = CGRect(x: 0, y: 0, width: 402, height: 874)
        let button = CGRect(x: 0, y: 750, width: 402, height: 124)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let examples: [(String, UIColor, UIColor, Bool)] = [
            ("白地の白文字", .white, .white, false),
            ("システムに薄められた文字", .white, UIColor(white: 0.84, alpha: 1), false),
            ("ライトの読める文字", UIColor(white: 0.9, alpha: 1), .black, true),
            ("ダークの読める文字", UIColor(white: 0.22, alpha: 1), .white, true)
        ]
        for (name, background, ink, readable) in examples {
            let image = UIGraphicsImageRenderer(size: window.size, format: format).image { context in
                background.setFill()
                context.fill(window)
                // Match the real padded AX frame: the visible label is above
                // frame.midY, while the bottom contains the home indicator.
                ink.setFill()
                context.fill(CGRect(x: 145, y: 785, width: 112, height: 16))
                UIColor.black.setFill()
                context.fill(CGRect(x: 140, y: 860, width: 120, height: 5))
            }
            guard let bitmap = image.cgImage else { return XCTFail("検査用画像を生成できません") }
            XCTAssertEqual(RenderedLabelContrast.measure(in: bitmap, window: window, button: button) >= 3, readable, name)
        }
    }

    /// Detect white-on-white disabled text from rendered pixels, not AX labels.
    private func disabledSubmitContrast(in app: XCUIApplication) -> Double {
        guard let image = XCUIScreen.main.screenshot().image.cgImage else { return 0 }
        return RenderedLabelContrast.measure(in: image, window: app.windows.firstMatch.frame,
                                             button: app.buttons["submitOrAdvance"].frame)
    }

    /// XCTest can report a clipped element as hittable and tap the fixed footer
    /// instead. Bring the entire control inside the question's scroll viewport.
    private func scrollMockContentTo(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let scroll = app.scrollViews["mockQuestionScroll"]
        XCTAssertTrue(scroll.exists)
        let top = max(scroll.frame.minY, app.buttons["mockSuspend"].frame.maxY) + 12
        let footer = app.otherElements["mockControls"].firstMatch
        XCTAssertTrue(footer.exists)
        let bottom = min(scroll.frame.maxY, footer.frame.minY) - 12
        for _ in 0..<12 {
            if element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { break }
            let down = element.frame.minY < top
            let overflow = down ? top - element.frame.minY : element.frame.maxY - bottom
            let distance = min((bottom - top) / 2, max(120, overflow + 12))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            // Start in the scroll view's empty gutter, not on a choice/image.
            let start = origin.withOffset(CGVector(dx: scroll.frame.minX + 8, dy: down ? top + 30 : bottom - 30))
            let end = start.withOffset(CGVector(dx: 0, dy: down ? distance : -distance))
            start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertGreaterThanOrEqual(element.frame.minY, top)
        XCTAssertLessThanOrEqual(element.frame.maxY, bottom)
    }

    private func finishMock(in app: XCUIApplication) {
        app.buttons["mockFinish"].tap()
        let confirmation = app.buttons["mockConfirmFinish"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
    }

    /// Sample the empty question gutter, away from text, figures and fixed bars.
    /// Compare rendered pixels rather than the Simulator setting: a nested sheet
    /// can leave the app light even while the device remains configured dark.
    private func mockBackgroundBrightness(in app: XCUIApplication) -> Double {
        let scroll = app.scrollViews["mockQuestionScroll"].frame
        let footer = app.otherElements["mockControls"].firstMatch.frame
        return backgroundBrightness(in: app, at: CGPoint(x: scroll.minX + 8, y: min(scroll.maxY, footer.minY) - 24))
    }

    private func backgroundBrightness(in app: XCUIApplication, at point: CGPoint) -> Double {
        guard let image = XCUIScreen.main.screenshot().image.cgImage else {
            XCTFail("実画面の画像を取得できません")
            return -1
        }
        let window = app.windows.firstMatch.frame
        let x = Int((point.x - window.minX) / window.width * CGFloat(image.width))
        let y = Int((point.y - window.minY) / window.height * CGFloat(image.height))
        guard x >= 0, x < image.width, y >= 0, y < image.height else {
            XCTFail("配色検査点が実画面の範囲外です")
            return -1
        }
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { XCTFail("画面の配色を読み取れません"); return -1 }
        let offset = (y * image.width + x) * 4
        return (0.2126 * Double(pixels[offset]) + 0.7152 * Double(pixels[offset + 1]) +
                0.0722 * Double(pixels[offset + 2])) / 255
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
