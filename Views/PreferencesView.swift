import SwiftUI

struct PreferencesView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let paywall: () -> Void

    private var recallBinding: Binding<Bool> {
        Binding(get: { store.data.recallFirst }, set: { store.setRecallFirst($0) })
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: recallBinding) {
                    Label("思い出してから選択肢を見る", systemImage: "brain.head.profile")
                }
            } header: {
                Text("記憶定着")
            } footer: {
                Text("おすすめ・復習・混同学習でのみ有効です。年度別演習と模擬試験は通常の出題形式で表示します。")
            }
            Section("問題集") {
                LabeledContent("資格", value: catalog.qualification.name)
                LabeledContent("収録問題", value: "\(catalog.questions.count)問")
                LabeledContent("無料問題", value: "\(catalog.qualification.freeQuestionIDs.count)問")
                LabeledContent("データ版", value: "端末内に保存")
                Text(catalog.qualification.examNote)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                if purchase.unlocked {
                    Label("購入済み · 全問題を利用できます", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
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
                Text("買い切りです。定期購入はありません。購入済みの問題はオフラインでも利用できます。")
            }
            Section("データとプライバシー") {
                Text("学習履歴・お気に入りはこの端末内に保存します。アカウント登録は不要です。購入状態はAppleのStoreKitで確認します。")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let error = store.error {
                    Text(error).foregroundStyle(.red)
                    Button("保存を再試行") { store.retrySave() }
                }
            }
        }
        .navigationTitle("設定")
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
                    Text("\(catalog.qualification.name) の全\(catalog.questions.count)問を、1回の購入で永久に解放。")
                        .font(.title3)
                    Surface {
                        Label("無料の\(catalog.qualification.freeQuestionIDs.count)問は購入不要", systemImage: "checkmark.circle")
                        Label("年度別・分野別・模擬試験の全問題", systemImage: "square.grid.2x2")
                        Label("復習と学習履歴はそのまま継続", systemImage: "arrow.clockwise")
                    }
                    if purchase.loading {
                        ProgressView("商品情報を確認中…")
                    } else if purchase.unlocked {
                        Button("学習を続ける") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    } else if let product = purchase.product {
                        Button {
                            Task { await purchase.buy() }
                        } label: {
                            Text("全問題を解放 · \(product.displayPrice)")
                                .frame(maxWidth: .infinity).padding(7)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(purchase.purchasing)
                    }
                    Button("購入を復元") { Task { await purchase.restore() } }
                        .disabled(purchase.purchasing)
                    if let error = purchase.error {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                        Button("再試行") { Task { await purchase.refresh() } }
                    }
                    Text("価格はApp Storeの商品情報から表示しています。定期購入はありません。購入の確認にはApple Accountを使用します。")
                        .font(.footnote).foregroundStyle(.secondary)
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
