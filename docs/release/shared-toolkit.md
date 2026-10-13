# 全アプリ共通の公開準備

共通ツールは [SubmitDock releasekit](/Users/hino/Desktop/dev/iOSSubmitter/releasekit/README.md)、台帳は https://submitdock-ios-pages.netlify.app/admin/releases です。今後の公開依頼には個人スキル `ios-release-submitdock` を利用します。

このアプリの設定は `docs/release/release.json`。正式なBundle ID・Apple ID・課金商品・広告枠・公開ページID、既存原稿、選定済み画像を登録済みです。審査状態は `submission-status.json` の観測記録を取り込んだもので、ライブ確認とは区別します。

```sh
python3 /Users/hino/Desktop/dev/iOSSubmitter/releasekit/submitdock.py -m docs/release/release.json validate
python3 /Users/hino/Desktop/dev/iOSSubmitter/releasekit/submitdock.py -m docs/release/release.json prepare --run-checks
python3 /Users/hino/Desktop/dev/iOSSubmitter/releasekit/submitdock.py -m docs/release/release.json apple plan
```

`.submitdock/` はGit管理外です。提出済みの1.0/build2を操作記録へ引き継いでおり、同一ビルドの再アップロードを防ぎます。審査中の版を変更せず、次回更新は次のバージョン・ビルドを設定してから準備します。

新しいアプリは共通CLIの `init`、または台帳の「アプリを追加」で始めます。広告・課金なしにも対応し、資格教材に固定されません。Xcodeのプロジェクト/ワークスペース・Scheme、検査コマンド、撮影用XCTestとSimulatorはアプリごとの `local` に指定します。Apple/AdMobの個別IDやプライバシー申告を他アプリからそのまま使い回さないでください。

API連携にはMac側の初回設定が必要です。Apple API、AdMob OAuth、台帳CLI用の管理認証は共通READMEを参照してください。秘密鍵・パスワード・審査連絡先の私的な電話番号はクラウド台帳へ保存しません。API未設定でも、ログイン済みの管理画面から登録・原稿編集・公開反映を行えます。
