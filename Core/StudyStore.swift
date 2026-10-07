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
    }

    func record(_ answer: Answer, question: Question, pending: PendingStudy? = nil) {
        guard !readOnly else { return }
        data.answers.append(answer)
        data.mastery[question.id] = MasteryEngine.update(data.mastery[question.id] ?? Mastery(), answer: answer, difficulty: question.difficulty)
        if let pending { data.pending = pending }
        save()
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
