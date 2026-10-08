import SwiftUI

struct ExamDateEditor: View {
    let store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Date

    init(store: StudyStore) {
        self.store = store
        let calendar = ExamDay.localCalendar
        let defaultDate = calendar.date(byAdding: .day, value: 30, to: .now) ?? .now
        let saved = store.data.examDay?.date(calendar: calendar)
        _selection = State(initialValue: saved.map { $0 >= calendar.startOfDay(for: .now) ? $0 : defaultDate } ?? defaultDate)
    }

    var body: some View {
        Form {
            Section {
                DatePicker("試験日", selection: $selection,
                           in: ExamDay.localCalendar.startOfDay(for: .now)...,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
            } footer: {
                Text("あと何日かを、ホームに表示します。")
            }
            Section {
                Button("試験日を保存") {
                    store.setExamDay(ExamDay(date: selection))
                    if store.error == nil { dismiss() }
                }
                .frame(maxWidth: .infinity)
                if store.data.examDay != nil {
                    Button("試験日の設定を解除", role: .destructive) {
                        store.setExamDay(nil)
                        if store.error == nil { dismiss() }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let error = store.error {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("試験日")
        .navigationBarTitleDisplayMode(.inline)
    }
}
