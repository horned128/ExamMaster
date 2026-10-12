# ITMS-91064とビルド2の対応

2026-10-12、利用者からAppleの通知本文を受領。対象はアプリ6821629759、1.0（1）。提出直後の審査待ちから「バイナリが無効」に変わった。

## 原因と修正

送信したビルド1のIPAを展開せず直接検査したところ、アプリ本体のPrivacyInfo.xcprivacyは`NSPrivacyTracking=true`、`NSPrivacyTrackingDomains=[]`だった。広告SDKのdSYM警告とは別の指摘。

Appleの[NSPrivacyTracking仕様](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacytracking)と[TN3182](https://developer.apple.com/documentation/technotes/tn3182-adding-privacy-tracking-keys-to-your-privacy-manifest)に従い、有効なトラッキング宣言に対象ホストを指定する。`googleads.g.doubleclick.net`は[Google Mobile Adsの公開リクエスト例](https://developers.google.com/admob/android/network-tracing?hl=en)に記載された広告ホスト。接続先の全量を動的に調査したという意味ではない。

アプリ本体のマニフェストへ広告ホストを追記し、NWのビルド番号だけ2に更新した。Google広告/UMPの署名付きSDKは編集せず、App StoreのデバイスID・トラッキング申告と既存のATT/UMP処理は保持する。

## 再発防止と確認

- preflightにトラッキング有効フラグ・対象ドメインの整合検査を追加。
- Archive、書き出したIPA、アップロード対象の実リソースをvalidate_distribution.pyで検査する。
- 空/欠落の対象ドメイン、有効フラグの誤型、URL/ワイルドカード等、アプリ本体のマニフェスト欠落を検出する回帰テストを追加。
- 申請ツール17テスト成功。ビルド1のIPAで元の不整合を再現して検出し、ビルド2のArchiveと配布用IPAは検査に通過した。ローカル事前検査は16項目すべて成功。

成果物はGit管理外の`release-artifacts/app-store-1.0-build2-privacy-fix/`。最初のIPA書き出しはXcodeのアカウントがなく停止したが、利用者の再ログイン後に同じArchiveから配布用署名・書き出しが成功した。2026-10-12 09:11:57 JSTにアップロード成功、TestFlightのビルド2で「提出準備完了」を確認した。アップロードログは`release-artifacts/app-store-1.0-build2-upload/upload.log`。

既存の提出物のビルド1を2へ差し替え、480円の全問題解放・広告停止商品を保持して09:16 JSTに再提出した。App Store Connectでアプリ1.0（2）とIAPの両方が「審査待ち」を表示した。現時点の状態であり、審査承認や公開の完了ではない。承認後のリリース方式は手動。最新状態と履歴は[submission-status.json](submission-status.json)を参照。
