import SwiftUI

struct WelcomeView: View {
    let catalog: Catalog
    let start: () -> Void
    let skip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 48)).foregroundStyle(.tint)
                        .frame(width: 90, height: 90)
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("今日から、確かな記憶へ。")
                            .font(.largeTitle.bold())
                        Text(catalog.qualification.name).font(.title3.bold())
                        Text("短い診断から始めると、今の理解度に合わせて次に解く問題を選べます。間違えた問題は、忘れそうなタイミングでまた出会えます。")
                            .foregroundStyle(.secondary)
                    }
                    Surface {
                        Label("約\(SessionPlanner.diagnostic(catalog, unlocked: false).questions.count)問・数分で完了", systemImage: "clock")
                            .font(.headline)
                        Text("結果から得意分野と最初に取り組む分野を提案します。無料で利用できます。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(catalog.qualification.examNote)
                        .font(.footnote).foregroundStyle(.secondary)
                    if catalog.qualification.ads.enabled {
                        Text("無料版では学習画面以外に広告を表示します。全問題解放の買い切り購入で広告も永久に非表示になります。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button(action: start) {
                        Label("診断を始める", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity).padding(7)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("診断をスキップして始める", action: skip)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background)
        }
    }
}
