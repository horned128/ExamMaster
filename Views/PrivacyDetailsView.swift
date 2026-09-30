import SwiftUI

struct PrivacyDetailsView: View {
    let catalog: Catalog
    let store: StudyStore
    let purchase: PurchaseManager
    let ads: AdsService
    let onReset: () -> Void
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("学習データ") {
                Text("回答履歴、問題ごとの習熟状態、模擬試験、お気に入り、途中の演習はこの端末に保存します。アカウント登録は必要ありません。アプリの削除で端末内の学習情報は失われます。")
            }
            Section("購入と広告") {
                Text("買い切り購入はAppleのStoreKitで確認します。無料版にはGoogle AdMobの広告を表示し、購入後は全問題が使え、広告も永久に非表示になります。")
                if !purchase.unlocked && catalog.qualification.ads.enabled && ads.canShowPrivacyOptions {
                    Button("広告のプライバシー設定を変更") { Task { await ads.presentPrivacyOptions() } }
                }
                if !purchase.unlocked && ads.error != nil {
                    Text(ads.error ?? "").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("プライバシーポリシー") {
                if let text = catalog.qualification.privacyPolicyURL,
                   let url = URL(string: text) {
                    Link("正式なプライバシーポリシーを開く", destination: url)
                } else {
                    NavigationLink("プライバシーポリシー全文（サンプル）") {
                        PrivacyPolicySampleView()
                    }
                }
            }
            Section {
                Button("学習情報をすべてリセット", role: .destructive) { confirmReset = true }
                if let error = store.error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                    Button("保存を再試行") { store.retrySave() }
                }
            } header: {
                Text("端末内データの削除")
            } footer: {
                Text("回答・習熟度・模試・お気に入り・診断結果・途中の演習を削除します。買い切り購入、広告同意、表示設定は維持します。")
            }
        }
        .navigationTitle("データとプライバシー")
        .confirmationDialog("学習情報をすべて削除しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("学習情報を削除", role: .destructive) {
                if store.resetLearning() { onReset() }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("回答履歴・習熟度・模試・お気に入り・途中の演習が消え、初回診断からやり直せます。買い切り購入と広告同意は維持します。この操作は取り消せません。")
        }
    }
}

private struct PrivacyPolicySampleView: View {
    private var content: String {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "文書を読み込めませんでした。アプリの配布データをご確認ください。"
        }
        return text
    }

    var body: some View {
        ScrollView {
            Text(content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
