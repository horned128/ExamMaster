import XCTest

final class StudyFlowUITests: XCTestCase {
    func testCompanionIsPartOfHomeFinderAndLearningGuide() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        XCTAssertTrue(app.buttons["openCompanion"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["qualificationTitle"].exists)
        let memory = app.descendants(matching: .any).matching(identifier: "homeMemory").firstMatch
        XCTAssertTrue(memory.exists)
        XCTAssertEqual(memory.value as? String, "定着 0問、学習中 0問、これから 12問")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "homeRetention").firstMatch.exists)
        let previous = app.buttons["homeHeading"].label
        app.buttons["homeHeading"].tap()
        XCTAssertNotEqual(app.buttons["homeHeading"].label, previous)
        capture(app, name: "相棒・ホームで待つひよこ")
        app.buttons["openCompanion"].tap()
        XCTAssertTrue(app.navigationBars["学習の相棒"].waitForExistence(timeout: 5))
        for label in ["応援して", "力こぶ！", "ひと休み", "応援して"] { app.buttons[label].tap() }
        capture(app, name: "相棒・触れ合いと成長")
        app.buttons["閉じる"].tap()
        app.tabBars.buttons["問題を探す"].tap()
        XCTAssertTrue(app.staticTexts["どこから学ぼう？"].waitForExistence(timeout: 5))
        capture(app, name: "相棒・問題を探す")
        app.tabBars.buttons["ホーム"].tap()
        for _ in 0..<6 where !app.buttons["記憶と復習のしくみ"].isHittable { app.swipeUp() }
        app.buttons["記憶と復習のしくみ"].tap()
        XCTAssertTrue(app.staticTexts["復習は、もう一度育てる時間。"].waitForExistence(timeout: 5))
        capture(app, name: "相棒・復習ガイド")
        app.buttons["閉じる"].tap()
    }

    func testTankeiGalleryShowsSixStatesAndCompactSizes() {
        let app = XCUIApplication()
        app.launchArguments = ["-TankeiGallery"]
        app.launch()
        XCTAssertTrue(app.staticTexts["いっしょに、ひと区切り。"].waitForExistence(timeout: 5))
        capture(app, name: "原案・ひよことチキン")
        for (value, title) in [(25, "育ちざかり"), (60, "若鶏"), (85, "チキン")] {
            app.buttons["\(value)"].tap()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        }
        capture(app, name: "原案・最終段階のチキン")
        app.swipeUp()
        for title in ["応援", "ひと区切り", "達成", "復習", "再挑戦", "ひと休み"] {
            for _ in 0..<4 where !app.staticTexts[title].exists { app.swipeUp() }
            XCTAssertTrue(app.staticTexts[title].exists)
        }
        capture(app, name: "原案・部位ごとの6状態")
        for _ in 0..<6 where !app.buttons["動きをもう一度"].isHittable { app.swipeUp() }
        for label in ["24pt", "32pt", "48pt", "64pt"] {
            XCTAssertTrue(app.staticTexts[label].exists)
        }
        app.buttons["動きをもう一度"].tap()
        capture(app, name: "原案・チキンの小サイズ")
    }

    func testCorrectDiagnosisGrowsCompanionAndPersistsAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["診断を始める"].tap()
        for index in 0..<8 {
            XCTAssertTrue(app.buttons["回答を確定"].waitForExistence(timeout: 5))
            let number = correctChoice(in: app)
            guard let number else { XCTFail("Expected a question from the sample free bank"); return }
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 \(number)、")).firstMatch.tap()
            app.buttons["回答を確定"].tap()
            XCTAssertEqual(app.staticTexts["answerOutcome"].value as? String, "相棒：ひよこ")
            XCTAssertFalse(app.staticTexts["mascotGrowthMilestone"].exists)
            app.buttons[index == 7 ? "結果を見る" : "次の問題へ"].tap()
        }
        XCTAssertTrue(app.staticTexts["mascotGrowthMilestone"].waitForExistence(timeout: 5))
        capture(app, name: "相棒・学習の積み重ねで育ちざかりへ")
        XCTAssertEqual(app.staticTexts["growthStage"].label, "育ちざかり")
        app.buttons["結果を見る"].tap()
        for _ in 0..<8 where !app.buttons["ホームへ進む"].isHittable { app.swipeUp() }
        app.buttons["ホームへ進む"].tap()
        let memory = app.descendants(matching: .any).matching(identifier: "homeMemory").firstMatch
        XCTAssertTrue(memory.waitForExistence(timeout: 5))
        XCTAssertEqual(memory.value as? String, "定着 0問、学習中 8問、これから 4問")
        capture(app, name: "ホーム・3区分と相棒の成長")
        app.tabBars.buttons["記録"].tap()
        let retention = app.descendants(matching: .any).matching(identifier: "recordRetention").firstMatch
        XCTAssertTrue(retention.waitForExistence(timeout: 5))
        XCTAssertEqual(retention.value as? String, "0パーセント、利用できる12問のうち0問が定着")
        XCTAssertTrue(app.buttons["recordCompanion"].label.contains("育ちざかり"))
        XCTAssertTrue((app.buttons["recordCompanion"].value as? String ?? "").isEmpty)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "一度でも正解")).firstMatch.exists)
        capture(app, name: "記録・準備度と定着率の統合")
        app.terminate()
        app.launchArguments = ["-UITestDisableAds"]
        app.launch()
        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.buttons["recordCompanion"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["recordCompanion"].label.contains("育ちざかり"))
        XCTAssertTrue((app.buttons["recordCompanion"].value as? String ?? "").isEmpty)
    }

    func testGrowthMilestoneSupportsLargestText() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for _ in 0..<10 where !app.buttons["診断を始める"].isHittable { app.swipeUp() }
        app.buttons["診断を始める"].tap()
        for index in 0..<8 {
            XCTAssertTrue(app.buttons["回答を確定"].waitForExistence(timeout: 5))
            guard let number = correctChoice(in: app) else { XCTFail("Expected a sample question"); return }
            answerChoice(app, number: number, revealChoices: false)
            XCTAssertEqual(app.staticTexts["answerOutcome"].value as? String, "相棒：ひよこ")
            let next = app.buttons[index == 7 ? "結果を見る" : "次の問題へ"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["mascotGrowthMilestone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["growthStage"].isHittable)
        XCTAssertLessThanOrEqual(app.staticTexts["growthStage"].frame.maxY, app.buttons["結果を見る"].frame.minY)
        capture(app, name: "成長・最大文字サイズ")
        XCTAssertTrue(app.buttons["結果を見る"].isHittable)
        app.buttons["結果を見る"].tap()
        for _ in 0..<12 where !app.buttons["ホームへ進む"].isHittable { app.swipeUp() }
        app.buttons["ホームへ進む"].tap()
        XCTAssertTrue(app.buttons["homeHeading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["startDailyStudy"].exists)
    }

    func testTankeiResultRemainsUsableWithLargestText() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        capture(app, name: "タンケイ・初回・最大文字")
        for _ in 0..<8 where !app.buttons["skipDiagnosis"].isHittable { app.swipeUp() }
        app.buttons["skipDiagnosis"].tap()
        for _ in 0..<8 where !app.buttons["shortStudy"].isHittable { app.swipeUp() }
        app.buttons["shortStudy"].tap()
        for _ in 0..<8 where !app.buttons["startDailyStudy"].isHittable { app.swipeUp() }
        app.buttons["startDailyStudy"].tap()
        for index in 0..<5 {
            answerFirstChoice(app)
            let next = app.buttons[index == 4 ? "結果を見る" : "次の問題へ"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        continuePastGrowthIfNeeded(app)
        XCTAssertTrue(app.staticTexts["おつかれさま"].waitForExistence(timeout: 5))
        capture(app, name: "タンケイ・結果・最大文字")
        for _ in 0..<12 where !app.buttons["学習を終える"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["学習を終える"].isHittable)
        app.buttons["学習を終える"].tap()
        XCTAssertTrue(app.buttons["homeHeading"].waitForExistence(timeout: 5))
    }

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
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "recordReadiness").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "recordRetention").firstMatch.exists)
        capture(app, name: "記録・すっきりした学習の状態")
        let subjects = app.buttons["科目別の定着率"]
        scrollTo(subjects, in: app)
        subjects.tap()
        let lastSubject = app.descendants(matching: .any).matching(identifier: "subjectRetention-安全計算").firstMatch
        XCTAssertTrue(lastSubject.waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "subjectRetention-点検計画").firstMatch.value as? String,
                       "定着率 0パーセント")
        XCTAssertEqual(lastSubject.value as? String, "定着率 0パーセント")
        capture(app, name: "記録・科目別の定着率")
        subjects.tap()
        scrollTo(app.staticTexts["学習履歴"], in: app)
        XCTAssertTrue(app.staticTexts["学習履歴"].exists)
        scrollTo(app.buttons["模擬試験を試す"], in: app)
        XCTAssertTrue(app.buttons["模擬試験を試す"].isHittable)
    }

    func testMergedHistoryKeepsDayAllAnswersAndCompanionAccess() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.buttons["shortStudy"].tap()
        app.buttons["startDailyStudy"].tap()
        answerFirstChoice(app)
        app.buttons["学習を中断"].tap()
        app.buttons["中断して後で再開"].tap()
        let homeMemory = app.descendants(matching: .any).matching(identifier: "homeMemory").firstMatch
        XCTAssertTrue(homeMemory.waitForExistence(timeout: 5))
        XCTAssertEqual(homeMemory.value as? String, "定着 0問、学習中 1問、これから 11問")
        let records = app.tabBars.buttons["記録"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: records)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        records.tap()
        let recordMemory = app.descendants(matching: .any).matching(identifier: "recordMemory").firstMatch
        XCTAssertTrue(recordMemory.waitForExistence(timeout: 5))
        XCTAssertEqual(recordMemory.value as? String, "定着 0問、学習中 1問、これから 11問")
        XCTAssertFalse(app.staticTexts["最近の回答"].exists)
        XCTAssertTrue(app.staticTexts["studyHistorySummary"].label.contains("回答 1回"))
        let allHistory = app.buttons["allAnswerHistory"]
        scrollTo(allHistory, in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "allAnswerHistory").count, 1)
        capture(app, name: "記録・カレンダーと回答履歴を統合")
        allHistory.tap()
        XCTAssertTrue(app.navigationBars["学習の相棒"].waitForExistence(timeout: 5))
        scrollTo(app.staticTexts["historyDay"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["historyDay"].firstMatch.exists)
        app.buttons["閉じる"].tap()
        app.buttons["selectedDayHistory"].tap()
        XCTAssertTrue(app.staticTexts["1回答 · 1正解"].waitForExistence(timeout: 5) || app.staticTexts["1回答 · 0正解"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for _ in 0..<8 where !app.buttons["recordCompanion"].isHittable { app.swipeDown() }
        app.buttons["recordCompanion"].tap()
        XCTAssertTrue(app.navigationBars["学習の相棒"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["mascotStage"].exists)
        app.buttons["閉じる"].tap()
    }

    func testMergedRecordsSupportLargestText() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        scrollTo(app.buttons["skipDiagnosis"], in: app)
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["記録"].tap()
        app.buttons["学習指標の見方"].tap()
        XCTAssertTrue(app.staticTexts["復習は、もう一度育てる時間。"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()
        let retention = app.descendants(matching: .any).matching(identifier: "recordRetention").firstMatch
        scrollFullyIntoView(retention, in: app)
        XCTAssertTrue(retention.isHittable)
        XCTAssertLessThanOrEqual(retention.frame.maxX, app.frame.maxX)
        XCTAssertEqual(retention.value as? String, "0パーセント、利用できる12問のうち0問が定着")
        capture(app, name: "記録・最大文字の定着率")
        let memory = app.descendants(matching: .any).matching(identifier: "recordMemory").firstMatch
        scrollTo(memory, in: app)
        XCTAssertEqual(memory.value as? String, "定着 0問、学習中 0問、これから 12問")
        let subjects = app.buttons["科目別の定着率"]
        scrollTo(subjects, in: app)
        subjects.tap()
        let subject = app.descendants(matching: .any).matching(identifier: "subjectRetention-点検計画").firstMatch
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        scrollFullyIntoView(subject, in: app)
        XCTAssertEqual(subject.value as? String, "定着率 0パーセント")
        XCTAssertLessThanOrEqual(subject.frame.maxX, app.frame.maxX)
        capture(app, name: "記録・最大文字の科目別定着率")
    }

    func testCompanionHistoryGroupsDaysSortsBothWaysAndOpensQuestions() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestSeedCompanionHistory", "-UITestDisableAds"]
        app.launch()
        app.buttons["openCompanion"].tap()
        XCTAssertTrue(app.navigationBars["学習の相棒"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["mascotProgress"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "一度でも正解")).firstMatch.exists)
        let order = app.segmentedControls["historyOrder"]
        scrollTo(order, in: app)
        XCTAssertTrue(order.buttons["新しい順"].isSelected)
        let firstDay = app.staticTexts.matching(identifier: "historyDay").firstMatch
        XCTAssertTrue(firstDay.waitForExistence(timeout: 5))
        let newestDate = firstDay.label
        capture(app, name: "相棒・日付別の回答・新しい順")
        order.buttons["古い順"].tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in firstDay.label != newestDate }, object: firstDay)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        let firstAnswer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "historyAnswer-")).firstMatch
        XCTAssertTrue(firstAnswer.label.contains("始業前点検"))
        XCTAssertGreaterThanOrEqual(firstAnswer.frame.minY, firstDay.frame.maxY)
        capture(app, name: "相棒・日付別の回答・古い順")
        firstAnswer.tap()
        XCTAssertTrue(app.buttons["回答を確定"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["学習の相棒"].exists)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 1、")).firstMatch.tap()
        app.buttons["回答を確定"].tap()
        app.buttons["一覧へ戻る"].tap()
        if app.staticTexts["mascotGrowthMilestone"].waitForExistence(timeout: 1) { app.buttons["一覧へ戻る"].tap() }
        XCTAssertTrue(app.navigationBars["学習の相棒"].waitForExistence(timeout: 5))
        scrollTo(app.segmentedControls["historyOrder"], in: app)
        XCTAssertTrue(app.segmentedControls["historyOrder"].buttons["古い順"].isSelected)
        app.buttons["閉じる"].tap()
        app.buttons["設定"].tap()
        app.buttons["相棒の成長を見る"].tap()
        XCTAssertTrue(app.navigationBars["学習の相棒"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()
    }

    func testCompanionHistorySortSupportsLargestText() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestSeedCompanionHistory", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        scrollTo(app.buttons["openCompanion"], in: app)
        app.buttons["openCompanion"].tap()
        XCTAssertTrue(app.navigationBars["学習の相棒"].waitForExistence(timeout: 5))
        let order = app.buttons["historyOrder"]
        scrollTo(order, in: app)
        XCTAssertTrue(order.isHittable)
        XCTAssertLessThanOrEqual(order.frame.maxX, app.frame.maxX)
        order.tap()
        app.buttons["古い順"].tap()
        let firstDay = app.staticTexts.matching(identifier: "historyDay").firstMatch
        scrollTo(firstDay, in: app)
        XCTAssertTrue(firstDay.isHittable)
        capture(app, name: "相棒・回答履歴・最大文字")
        app.buttons["閉じる"].tap()
    }

    func testLearningGuideExplainsResearchDiagramsAndMetricsInOnePage() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        scrollTo(app.buttons["記憶と復習のしくみ"], in: app)
        app.buttons["記憶と復習のしくみ"].tap()
        XCTAssertTrue(app.navigationBars["記憶と学習"].waitForExistence(timeout: 5))
        capture(app, name: "記憶と学習・メリットと導入")
        jumpInGuide(app, to: "間隔をあける理由")
        let compare = app.switches["guideMemoryCompare"]
        scrollTo(compare, in: app)
        XCTAssertEqual(compare.value as? String, "1")
        compare.tap()
        XCTAssertEqual(compare.value as? String, "0")
        compare.tap()
        capture(app, name: "記憶と学習・復習の比較グラフ")
        jumpInGuide(app, to: "指標の見方")
        scrollTo(app.staticTexts["guideMemoryHeading"], in: app)
        capture(app, name: "記憶と学習・3区分と定着率")
        let criteria = app.buttons["定着の判定を詳しく見る"]
        scrollTo(criteria, in: app)
        criteria.tap()
        XCTAssertTrue(app.staticTexts["guideMasteryCriteria"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["guideMasteryCriteria"].label.contains("安定期間が7日以上"))
        let weights = app.buttons["準備度の内訳を詳しく見る"]
        scrollTo(weights, in: app)
        weights.tap()
        XCTAssertTrue(app.staticTexts["guideReadinessWeights"].waitForExistence(timeout: 5))
        scrollTo(app.staticTexts["guideReadinessWeights"], in: app)
        capture(app, name: "記憶と学習・準備度の配点")
        jumpInGuide(app, to: "研究と、このアプリの限界")
        XCTAssertTrue(app.staticTexts["guideSourcesHeading"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "guideResearch-1").firstMatch.exists)
        capture(app, name: "記憶と学習・研究と限界")
        app.buttons["閉じる"].tap()
        app.tabBars.buttons["記録"].tap()
        app.buttons["学習指標の見方"].tap()
        XCTAssertTrue(app.navigationBars["記憶と学習"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["guide-metrics"].isHittable)
        app.buttons["閉じる"].tap()
    }

    func testLearningGuideRemainsReadableAtLargestTextAndInLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        scrollTo(app.buttons["skipDiagnosis"], in: app)
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["記録"].tap()
        app.buttons["学習指標の見方"].tap()
        XCTAssertTrue(app.navigationBars["記憶と学習"].waitForExistence(timeout: 5))
        let heading = app.staticTexts["guide-metrics"]
        XCTAssertTrue(heading.isHittable)
        XCTAssertLessThanOrEqual(heading.frame.maxX, app.frame.maxX)
        capture(app, name: "記憶と学習・指標の見方・最大文字")
        jumpInGuide(app, to: "間隔をあける理由")
        let compare = app.switches["guideMemoryCompare"]
        scrollTo(compare, in: app)
        XCTAssertLessThanOrEqual(compare.frame.maxX, app.frame.maxX)
        compare.tap()
        capture(app, name: "記憶と学習・比較グラフ・最大文字")
        jumpInGuide(app, to: "思い出す練習")
        let flow = app.descendants(matching: .any).matching(identifier: "guideRecallFlow").firstMatch
        scrollTo(flow, in: app)
        XCTAssertLessThanOrEqual(flow.frame.maxX, app.frame.maxX)
        XCTAssertTrue((flow.value as? String)?.contains("答え合わせ") == true)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        jumpInGuide(app, to: "このアプリでできること")
        XCTAssertTrue(app.buttons["learningGuideContents"].isHittable)
        XCTAssertTrue(app.buttons["閉じる"].isHittable)
        capture(app, name: "記憶と学習・横向き・最大文字")
        app.buttons["閉じる"].tap()
    }

    private func jumpInGuide(_ app: XCUIApplication, to title: String) {
        app.buttons["learningGuideContents"].tap()
        app.buttons[title].tap()
    }

    func testSharedCollectionSingleQuestionAndResume() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetStudy", "-UITestDisableAds"]
        app.launch()
        app.buttons["skipDiagnosis"].tap()
        app.tabBars.buttons["問題を探す"].tap()
        scrollTo(app.staticTexts["2025年"], in: app)
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
        XCTAssertTrue(app.buttons["homeHeading"].waitForExistence(timeout: 5))
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
        scrollTo(app.buttons["データとプライバシー"], in: app)
        XCTAssertTrue(app.buttons["データとプライバシー"].exists)
        app.buttons["データとプライバシー"].tap()
        XCTAssertTrue(app.buttons["プライバシーポリシー全文（サンプル）"].exists)
        scrollTo(app.buttons["学習情報をすべてリセット"], in: app)
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
        scrollTo(app.staticTexts["2025年"], in: app)
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
        let consentContinue = app.webViews.buttons["Continue"].firstMatch
        if consentContinue.waitForExistence(timeout: 20) { consentContinue.tap() }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let trackingAlert = springboard.alerts.firstMatch
        if trackingAlert.waitForExistence(timeout: 8) { trackingAlert.buttons.firstMatch.tap() }
        XCTAssertTrue(app.buttons["homeHeading"].waitForExistence(timeout: 5))
        let finder = app.tabBars.buttons["問題を探す"]
        finder.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: finder)
        guard XCTWaiter.wait(for: [selected], timeout: 5) == .completed else {
            XCTFail("Consent or the system alert still covers navigation")
            return
        }
        XCTAssertTrue(app.staticTexts["学習モード"].waitForExistence(timeout: 5))
        scrollTo(app.staticTexts["2025年"], in: app)
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
        continuePastGrowthIfNeeded(app)
        XCTAssertTrue(app.staticTexts["診断が完了しました"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["分野別の結果"].exists)
        app.buttons["ホームへ進む"].tap()
        XCTAssertTrue(app.buttons["homeHeading"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["homeHeading"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["homeHeading"].waitForExistence(timeout: 5))
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
        continuePastGrowthIfNeeded(app)
        XCTAssertTrue(app.staticTexts["次に出会う目安"].waitForExistence(timeout: 5))
        capture(app, name: "結果・今日はここまで")
        app.swipeUp()
        app.buttons["学習を終える"].tap()
        XCTAssertTrue(app.buttons["homeHeading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["resumeStudy"].exists)
        XCTAssertFalse(app.staticTexts["dailyGoalCard"].exists)
        XCTAssertFalse(app.buttons["startDailyStudy"].exists)
        capture(app, name: "ホーム・今日のノルマ達成後")
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
        let memory = app.descendants(matching: .any).matching(identifier: "homeMemory").firstMatch
        scrollFullyIntoView(memory, in: app)
        XCTAssertTrue(memory.isHittable)
        XCTAssertEqual(memory.value as? String, "定着 0問、学習中 0問、これから 12問")
        XCTAssertLessThanOrEqual(memory.frame.maxX, app.frame.maxX)
        capture(app, name: "最大文字サイズ・ホームの3区分")
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
        scrollFullyIntoView(app.buttons["startDailyStudy"], in: app)
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

    private func continuePastGrowthIfNeeded(_ app: XCUIApplication) {
        if app.staticTexts["mascotGrowthMilestone"].waitForExistence(timeout: 2) {
            app.buttons["結果を見る"].tap()
        }
    }

    /// ScrollView's accessibility frame includes the fixed submit bar on iOS 26.
    /// Keep the drag and the tap inside its unobscured region, never on the bar.
    private func answerFirstChoice(_ app: XCUIApplication) {
        answerChoice(app, number: 1, revealChoices: true)
    }

    private func answerChoice(_ app: XCUIApplication, number: Int, revealChoices: Bool) {
        if revealChoices {
            let reveal = app.buttons["選択肢を見る"]
            XCTAssertTrue(reveal.waitForExistence(timeout: 5))
            reveal.tap()
        }
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "選択肢 \(number)、")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        let confirm = app.buttons["回答を確定"]
        let questionScroll = app.scrollViews.containing(.button, identifier: choice.label).firstMatch
        for _ in 0..<12 {
            let top = questionScroll.frame.minY + 20
            let bottom = confirm.frame.minY - 20
            let center = choice.frame.midY
            if choice.isHittable && center >= top && center <= bottom { break }
            let down = center < top
            let startY = down ? top + 30 : bottom - 30
            let distance = min(200, (bottom - top) * 0.5)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY))
            let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY + (down ? distance : -distance)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(choice.isHittable)
        choice.tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: confirm)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 3), .completed)
        confirm.tap()
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable {
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: app.frame.height * 0.65))
            let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: app.frame.height * 0.30))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }

    /// A partially visible element is hittable, but not enough for a readable capture.
    private func scrollFullyIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let top = app.navigationBars.firstMatch.frame.maxY + 12
        let bottom = app.tabBars.firstMatch.frame.minY - 12
        for _ in 0..<12 {
            if element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom { break }
            let down = element.frame.minY < top
            let startY = down ? top + 40 : bottom - 40
            let overflow = down ? top - element.frame.minY : element.frame.maxY - bottom
            let distance = min(180, max(20, overflow + 8))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY))
            let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY + (down ? distance : -distance)))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertGreaterThanOrEqual(element.frame.minY, top)
        XCTAssertLessThanOrEqual(element.frame.maxY, bottom)
    }

    private func correctChoice(in app: XCUIApplication) -> Int? {
        let choices: [(String, Int)] = [
            ("始業前点検の主な目的", 1), ("定期点検の計画", 2), ("点検中に異音", 3),
            ("設備の保守前", 1), ("保守後の再起動前", 2), ("電源を切っただけ", 3),
            ("測定値を点検記録", 1), ("緊急性のある異常", 2), ("基準値を超えた", 3),
            ("20件の点検", 1), ("15分の点検", 2), ("50個の部品", 3)
        ]
        return choices.first { prefix, _ in
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", prefix)).firstMatch.exists
        }?.1
    }
}
