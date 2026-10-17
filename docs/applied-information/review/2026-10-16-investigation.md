# App Review 2.1(b) 調査記録（2026-10-16 JST）

## 審査結果と現在の状態

- App Store Connect app ID: `6822732103`
- Submission ID: `285ecb51-e240-4733-a1ff-33134d09eeae`
- Appleの審査メッセージ: 2026-10-15、1.0 (2)、iPad Air 11-inch (M3) / iPadOS 27.0。購入商品情報が読み込めないとの指摘。
- 2026-10-16にSafariの提出詳細を確認。アプリ項目は却下済み、IAPは審査準備完了。提出には両方が残っている。
- 現在の提出詳細には1.0 (4)が選択されている。今回の作業でビルドを選び直したものではなく、下記の診断で使用した提出時ソース1.0 (2)とは区別する。再提出前に使用ビルドの来歴と検証対象を照合する。
- ユーザーの明示許可を受け、Appleへの返信を送信済み。審査詳細に2件目のメッセージ（HinoAsato、19:07）として保存されたことを確認した。再提出は行っていない。公開方式は手動。

## App Store Connect / Developer Portalで確認した事実

| 項目 | 観測結果 |
|---|---|
| Bundle ID | `jp.hino.piyotre.appliedinformation` |
| IAP product ID | `jp.hino.piyotre.appliedinformation.unlock`（コード・提出時アーカイブの設定と一致） |
| IAP type | 非消耗型 |
| 現在の日本向けIAP価格 | 300円（価格スケジュール詳細で確認） |
| IAPの表示名・説明・審査画像・メモ | 登録済み |
| IAP配信地域 | 日本のみ（1/175） |
| アプリ配信地域 | 1件配信可能、174件配信不可。日本限定の設定と整合 |
| Paid Apps Agreement | 有効 |
| 銀行口座・納税フォーム | 有効（個人情報は本記録に転記しない） |
| 明示的App IDのIn-App Purchase | 有効 |

## Apple Sandboxでの実機診断

- 提出時のGit revision `487b35a`を隔離したmanaged worktreeで使用。
- Physical iPhone 17e。開発署名された応用情報版のホストでXCTestを実行。
- `AppliedInformation-Sandbox`スキームからローカルの`StoreKitConfigurationFileReference`を除外。`SKTestSession`を開始しない、明示的に実行を有効にした診断テスト。
- `Storefront.current`: `JPN`
- `Product.products(for:)`: 対象商品を1件返却。価格`¥300`、Non-Consumable。
- `PurchaseManager.refresh()`: 対象商品と`¥300`を読み込み、`loading == false`、`error == nil`。
- テスト1件成功（0.436秒）。購入・購入復元・取引履歴削除は実行していない。
- 初回のスキップ結果は成功の根拠に含めず、実行フラグを修正した後の成功結果のみを採用。
- Sanitized log: [2026-10-16-sandbox-results.txt](2026-10-16-sandbox-results.txt)
- 詳細xcresult（ローカル）: `/private/tmp/ap-iap-sandbox-diagnostics-20261016-4.xcresult`
- Worktree: `/Users/hino/.codex/worktrees/ap-iap-review-fix/ExamMaster`

## 結論と未確定事項

現在の日本のSandboxでは、Appleからの商品取得とアプリの購入管理処理で指摘事象を再現していない。契約・商品ID・価格・App IDの課金機能の設定不足は確認されなかった。

審査端末のストア地域、審査時点のApple側反映状況、Apple側サービスの一時的な応答は確認できていない。販売地域の違いは調査候補であり、今回のリジェクト原因と断定しない。日本での取得成功だけをもってiPadOS 27.0・審査用アカウントでの成功、購入完了、復元成功を保証しない。

根拠なくIAPの販売国や商品IDを変更したり、新ビルドを送信したりせず、Japan storefrontでの再確認と審査時storefrontの情報を依頼する返信案を作成した。ユーザーの明示指示に基づき送信し、審査詳細で保存を確認済み。

- [Appleへ送信した返信本文](2026-10-16-reply-draft-en.txt)
- [Apple TN3186: SandboxでのIAP取得問題](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)
- [Apple: Sandboxテスト](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)

## 汎用の再発対策（2026-10-17）

共有SubmitDockに、アプリのジャンルに依存しない実Sandbox商品取得プローブと提出前チェックを追加。商品ID・種別・基準国・価格・通貨・version/build・関連ソースとアーカイブの対応を検査する。以前の1.0 (2)の診断は調査の根拠として保持するが、現在の作業ソースや1.0 (4)に検証記録を付け替えない。新しいビルドの提出準備は改めて検証が必要。購入・復元の実Sandboxテストや原因特定の完了を意味しない。
