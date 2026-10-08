import SwiftUI

struct WelcomeView: View {
    let catalog: Catalog
    let start: () -> Void
    let skip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(catalog.qualification.name)
                            .font(.subheadline.weight(.medium)).foregroundStyle(Palette.muted)
                        Text("思い出すたび、\n自分のものに。")
                            .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                        Text("少し解く。日をあける。また思い出す。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }
                    Surface { MemoryRhythm() }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "pencil.line").foregroundStyle(.tint).font(.title2)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("まずは、今の得意を知る").font(.headline)
                                Text("\(SessionPlanner.diagnostic(catalog, unlocked: false).questions.count)問 · 無料")
                                    .font(.subheadline).foregroundStyle(Palette.muted)
                            }
                        }
                        Button(action: start) {
                            HStack {
                                Text("診断を始める")
                                Spacer()
                                Image(systemName: "arrow.right").accessibilityHidden(true)
                            }
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 44).padding(8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent(catalog.qualification.accentHex))
                        .foregroundStyle(Palette.onAccent(catalog.qualification.accentHex))
                        Button("診断なしで始める", action: skip)
                            .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier("skipDiagnosis")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(catalog.qualification.subtitle).font(.caption).foregroundStyle(Palette.muted)
                        DisclosureGroup("教材・広告について") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(catalog.qualification.examNote)
                                if catalog.qualification.ads.enabled {
                                    Text("無料版は問題・解説以外に広告を表示。全問題を買い切りで解放すると広告もなくなります。")
                                }
                            }
                            .font(.footnote).foregroundStyle(Palette.muted).padding(.top, 8)
                        }
                        .font(.footnote)
                    }
                }
                .padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
        }
    }
}
