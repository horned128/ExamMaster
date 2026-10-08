import SwiftUI

struct PreferencesView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let paywall: () -> Void
    let onReset: () -> Void
    let openCompanion: () -> Void
    @State private var showLearningGuide = false

    private var recallBinding: Binding<Bool> {
        Binding(get: { store.data.recallFirst }, set: { store.setRecallFirst($0) })
    }

    var body: some View {
        Form {
            Section("受験予定") {
                NavigationLink {
                    ExamDateEditor(store: store)
                } label: {
                    HStack {
                        Label("試験日", systemImage: "calendar")
                        Spacer()
                        if let date = store.data.examDay?.date() {
                            Text(date, format: .dateTime.year().month().day())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("未設定").foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel("試験日を設定")
            }
            Section {
                Toggle(isOn: recallBinding) {
                    Label("選択肢の前に、ひと呼吸", systemImage: "bubble.left")
                }
            } header: {
                Text("記憶定着")
            } footer: {
                Text("今日の学習と復習で、まず答えを思い出す。")
            }
            Section {
                Button(action: openCompanion) {
                    HStack(spacing: 12) {
                        TankeiView(stage: TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked).stage, size: 48, idle: true)
                        Text("相棒の成長を見る")
                    }
                }
                Button { showLearningGuide = true } label: {
                    Label("記憶と復習のしくみ", systemImage: "info.circle")
                }
            }
            Section {
                if purchase.unlocked {
                    Label("購入済み · 全問題・広告なし", systemImage: "checkmark.circle")
                        .foregroundStyle(Palette.positive)
                } else {
                    Button("全問題を解放する", action: paywall)
                }
                Button("購入を復元") { Task { await purchase.restore() } }
                    .disabled(purchase.purchasing)
                if let error = purchase.error {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    Button("商品情報を再取得") { Task { await purchase.refresh() } }
                }
            } header: {
                Text("全問題の解放")
            } footer: {
                Text("買い切り · 定期購入なし · オフライン対応")
            }
            Section {
                NavigationLink {
                    PrivacyDetailsView(catalog: catalog, store: store, purchase: purchase,
                                       ads: ads, onReset: onReset)
                } label: {
                    Label("データとプライバシー", systemImage: "hand.raised")
                }
            }
        }
        .navigationTitle("設定")
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .sheet(isPresented: $showLearningGuide) {
            LearningGuideView(stage: TankeiGrowth(catalog: catalog, data: store.data, unlocked: purchase.unlocked).stage)
                .environment(\.mascotMotionEnabled, true)
        }
    }
}

struct PaywallView: View {
    let catalog: Catalog
    let purchase: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: purchase.unlocked ? "checkmark.seal.fill" : "lock.open.fill")
                        .font(.system(size: 46)).foregroundStyle(.tint)
                        .frame(width: 88, height: 88)
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                    Text(purchase.unlocked ? "全問題を利用できます" : "学習を、最後まで。")
                        .font(.largeTitle.bold())
                    Text("全\(catalog.questions.count)問を、永久に解放。")
                        .font(.title3.bold())
                    Text("\(catalog.qualification.name) · 買い切り")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Surface {
                        Label("無料の\(catalog.qualification.freeQuestionIDs.count)問は購入不要", systemImage: "checkmark.circle")
                        Label("年度別・分野別・模試", systemImage: "square.grid.2x2")
                        Label("学習履歴はそのまま", systemImage: "arrow.clockwise")
                        Label("広告なし", systemImage: "rectangle.slash")
                    }
                    if purchase.loading {
                        ProgressView("商品情報を確認中…")
                    } else if purchase.unlocked {
                        Button("学習を続ける") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(Palette.accent(catalog.qualification.accentHex))
                            .foregroundStyle(Palette.onAccent(catalog.qualification.accentHex))
                    } else if let product = purchase.product {
                        Button {
                            Task { await purchase.buy() }
                        } label: {
                            Text("買い切り \(product.displayPrice)で解放")
                                .frame(maxWidth: .infinity).padding(7)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent(catalog.qualification.accentHex))
                        .foregroundStyle(Palette.onAccent(catalog.qualification.accentHex))
                        .disabled(purchase.purchasing)
                    }
                    Button("購入を復元") { Task { await purchase.restore() } }
                        .disabled(purchase.purchasing)
                    if let error = purchase.error {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                        Button("再試行") { Task { await purchase.refresh() } }
                    }
                    Text("定期購入なし。Apple Accountで購入。")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .navigationTitle("全問題を解放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("閉じる")
                }
            }
        }
    }
}
