# 2026-10-13の課金商品取得失敗と300円への変更

Appleは1.0（2）をiPad Air 11-inch（M3）・iPadOS 27.0で審査し、課金商品を読み込めないためGuideline 2.1(b)で却下した。前回のITMS-91064とは別の問題。

App Store Connectのビジネス画面で、有料アプリ契約は「新規」、無料アプリ契約は「有効」と表示された。有料契約への署名前に登録情報の更新を求める表示もあった。登録住所・銀行情報・税務情報は公開文書に保存しない。

Appleの[審査用Sandboxの設定](https://developer.apple.com/help/app-review/before-submitting-for-review/configure-in-app-purchases/)と[TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)によれば、有料アプリ契約が有効でない場合や銀行・税務情報が未完了の場合、Sandboxで商品を取得できない。IAP自体の事前承認は不要。今回は契約の未有効という具体的な問題を確認したが、契約完了後の実Sandbox動作を検証するまでは解消済みとしない。情報変更のSandbox反映には最大1時間かかる場合がある。

## 変更

- 同じ非消耗型商品 `jp.hino.piyotre.networkspecialist.unlock`（Apple ID 6821756732）の日本価格を480円から300円に変更。即時変更を保存し、「現在の価格」で日本￥300.00を確認。日本のみの販売設定を維持する。
- アプリは従来どおりStoreKitの商品・価格を使用する。仮の価格や端末フラグで購入を成立させない。
- 購入画面を開くたびに商品と購入権限を再取得。重複した取得要求は同じ処理を待つ。空の結果・通信失敗を最大3回取得し、再試行中は読み込み表示、成功後は古いエラーを消す。
- 正規購入済みの利用者は、商品メタデータを取得できなくても検証済み購入権限を維持して学習を続けられる。
- NWのビルド番号を3へ進め、開発StoreKit設定・申請原稿・公開ページ原稿も300円に合わせる。他資格の商品価格は変更しない。

## 検証と再提出条件

iPhone 17 Pro・iOS 26.2でNW単体23件と購入UI1件が成功した。実StoreKitTestによる取得失敗→同じアプリ起動内で復帰・古いエラー消去、商品なしで購入を進めないこと、購入済み権限を維持することを含む。これはApp Store Connectの実Sandbox検証とは別の結果。

審査と同じiPad Air M3・iPadOS 27.0、申請画像、Archive/IPAの検査を進める。有料契約・銀行・税務の有効化と、実Sandboxの商品取得・購入・復元を確認してから再提出する。最新状態は[submission-status.json](submission-status.json)を参照。
