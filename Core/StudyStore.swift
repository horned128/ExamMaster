import Foundation
import Observation

@MainActor @Observable final class StudyStore {
    private(set) var data: StudyData
    private(set) var error: String?
    private(set) var readOnly = false
    let url: URL

    init(qualificationID: String, directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = base.appendingPathComponent("study-\(qualificationID).json")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestResetStudy") { try? FileManager.default.removeItem(at: url) }
        #endif
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            data = FileManager.default.fileExists(atPath: url.path)
                ? try JSONDecoder().decode(StudyData.self, from: Data(contentsOf: url)) : StudyData()
            if data.schemaVersion != 1 { throw CatalogError.invalid("履歴の形式") }
        } catch {
            data = StudyData()
            readOnly = true
            self.error = "学習履歴を読み込めませんでした。元のファイルは保持しています。\n\(error.localizedDescription)"
        }
        clearInterruptedStudy()
        #if DEBUG
        if !readOnly && ProcessInfo.processInfo.arguments.contains("-UITestResetStudy") &&
            ProcessInfo.processInfo.arguments.contains("-UITestSeedFixedMock"),
           let catalog = try? Catalog.load(id: qualificationID) {
            completeOnboarding(diagnostic: false)
            let session = StudySession(title: "UIテスト用10問（公式模試ではありません）", mode: .mock,
                                       questions: Array(SessionPlanner.available(catalog, unlocked: false).prefix(10)), timed: true)
            let expired = ProcessInfo.processInfo.arguments.contains("-UITestExpiredMock")
            let start = expired ? Date.now.addingTimeInterval(-2500) : .now
            beginMock(session: session, minutes: 40, now: start)
            if expired, let question = session.questions.first {
                selectMock(question.correctIndex, question: question, attemptID: session.id, now: start)
            }
        }
        if !readOnly && ProcessInfo.processInfo.arguments.contains("-UITestResetStudy") &&
            ProcessInfo.processInfo.arguments.contains("-UITestSeedCompanionHistory"),
           let catalog = try? Catalog.load(id: qualificationID) {
            let questions = SessionPlanner.available(catalog, unlocked: false)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            for (index, question) in questions.prefix(6).enumerated() {
                let day = calendar.date(byAdding: .day, value: index / 2 - 2, to: today) ?? today
                let date = calendar.date(bySettingHour: 10, minute: (index % 2) * 10, second: 0, of: day) ?? day
                record(Answer(questionID: question.id, date: date, selectedIndex: question.correctIndex,
                              correct: true, duration: 10, confidence: nil, mode: .search), question: question)
            }
            completeOnboarding(diagnostic: false)
        }
        #endif
    }

    func record(_ answer: Answer, question: Question, pending: PendingStudy? = nil) {
        guard !readOnly else { return }
        data.answers.append(answer)
        data.mastery[question.id] = MasteryEngine.update(data.mastery[question.id] ?? Mastery(), answer: answer, difficulty: question.difficulty)
        if let pending { data.pending = pending }
        save()
    }

    /// Amend the existing attempt; confidence changes must not create duplicate answers.
    @discardableResult func updateConfidence(_ confidence: Confidence?, answerID: UUID, question: Question) -> Bool {
        guard !readOnly, let index = data.answers.firstIndex(where: { $0.id == answerID && $0.questionID == question.id }) else { return false }
        var replacement = data
        replacement.answers[index].confidence = confidence
        var state = Mastery()
        let attempts = replacement.answers.enumerated().filter { $0.element.questionID == question.id }
            .sorted { $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date < $1.element.date }
        for attempt in attempts {
            state = MasteryEngine.update(state, answer: attempt.element, difficulty: question.difficulty)
        }
        replacement.mastery[question.id] = state
        return commit(replacement)
    }

    /// Only transient positions/selections are discarded. Recorded attempts and results remain.
    func clearInterruptedStudy() {
        guard !readOnly, data.pending != nil || data.pendingMock != nil else { return }
        var replacement = data
        replacement.pending = nil
        replacement.pendingMock = nil
        _ = commit(replacement)
    }

    /// Commit earned growth at session completion (or once when migrating legacy history).
    /// Recording answers and suspending a session never change the visible stage.
    func updateMascotGrowth(questions: [Question], now: Date = .now) {
        guard !readOnly, !questions.isEmpty else { return }
        let stage = TankeiGrowth(questions: questions, data: data, now: now).stage.rawValue
        guard stage != data.mascotHighestStage || data.mascotNeedsMigration else { return }
        data.mascotHighestStage = stage
        data.mascotNeedsMigration = false
        save()
    }

    func migrateMascotGrowthIfNeeded(questions: [Question], now: Date = .now) {
        guard data.mascotNeedsMigration, data.pending == nil else { return }
        updateMascotGrowth(questions: questions, now: now)
    }

    func setPending(_ pending: PendingStudy) {
        guard !readOnly else { return }
        data.pending = pending
        save()
    }

    func clearPending() {
        guard !readOnly, data.pending != nil else { return }
        data.pending = nil
        save()
    }

    @discardableResult func beginMock(session: StudySession, minutes: Int, now: Date = .now) -> Bool {
        guard !readOnly, session.timed, !session.questions.isEmpty, minutes > 0, data.pendingMock == nil else { return false }
        var replacement = data
        replacement.pendingMock = PendingMock(session: session, minutes: minutes, now: now)
        return commit(replacement)
    }

    @discardableResult func selectMock(_ index: Int?, question: Question, attemptID: UUID, now: Date = .now) -> Bool {
        guard !readOnly, var pending = data.pendingMock, pending.id == attemptID,
              pending.remaining(at: now) > 0, pending.questionIDs.contains(question.id),
              index.map({ question.choices.indices.contains($0) }) ?? true else { return false }
        pending.selections[question.id] = index
        var replacement = data
        replacement.pendingMock = pending
        return commit(replacement)
    }

    @discardableResult func moveMock(to index: Int, attemptID: UUID) -> Bool {
        guard !readOnly, var pending = data.pendingMock, pending.id == attemptID,
              pending.questionIDs.indices.contains(index) else { return false }
        pending.index = index
        var replacement = data
        replacement.pendingMock = pending
        return commit(replacement)
    }

    /// One write commits the result, learning updates and removal of the active attempt.
    /// Failure leaves the pending exam intact; repeated completion returns the same result.
    @discardableResult func completeMock(attemptID: UUID, catalog: Catalog, now: Date = .now) -> MockResult? {
        if let existing = data.mocks.first(where: { $0.id == attemptID }) { return existing }
        guard !readOnly, let pending = data.pendingMock, pending.id == attemptID,
              let session = MockExam.restore(pending, catalog: catalog, unlocked: true) else { return nil }
        let graded = MockExam.grade(pending, questions: session.questions, qualification: catalog.qualification, now: now)
        var replacement = data
        for answer in graded.answers {
            guard let question = session.questions.first(where: { $0.id == answer.questionID }) else { continue }
            replacement.answers.append(answer)
            replacement.mastery[question.id] = MasteryEngine.update(replacement.mastery[question.id] ?? Mastery(),
                                                                   answer: answer, difficulty: question.difficulty)
        }
        replacement.mocks.append(graded.result)
        replacement.pendingMock = nil
        return commit(replacement) ? graded.result : nil
    }

    private func commit(_ replacement: StudyData) -> Bool {
        do {
            try JSONEncoder().encode(replacement).write(to: url, options: .atomic)
            data = replacement
            error = nil
            return true
        } catch {
            self.error = "学習履歴を保存できませんでした: \(error.localizedDescription)"
            return false
        }
    }

    func setRandomScope(_ scope: RandomScope) {
        guard !readOnly else { return }
        data.randomScope = scope
        save()
    }

    func setExamDay(_ day: ExamDay?) {
        guard !readOnly else { return }
        data.examDay = day
        save()
    }

    @discardableResult func resetLearning() -> Bool {
        guard !readOnly else { return false }
        var replacement = StudyData()
        replacement.recallFirst = data.recallFirst
        replacement.randomScope = data.randomScope
        do {
            try JSONEncoder().encode(replacement).write(to: url, options: .atomic)
            data = replacement
            error = nil
            return true
        } catch {
            self.error = "学習情報を削除できませんでした: \(error.localizedDescription)"
            return false
        }
    }

    func finishMock(_ result: MockResult) { guard !readOnly else { return }; data.mocks.append(result); save() }
    func toggleBookmark(_ id: String) {
        guard !readOnly else { return }
        if data.bookmarks.contains(id) { data.bookmarks.remove(id) } else { data.bookmarks.insert(id) }
        save()
    }
    func completeOnboarding(diagnostic: Bool) {
        guard !readOnly else { return }
        data.onboardingCompleted = true
        data.diagnosticCompleted = diagnostic
        save()
    }
    func setRecallFirst(_ enabled: Bool) { guard !readOnly else { return }; data.recallFirst = enabled; save() }
    func retrySave() { guard !readOnly else { return }; error = nil; save() }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
            error = nil
        } catch { self.error = "学習履歴を保存できませんでした: \(error.localizedDescription)" }
    }
}
