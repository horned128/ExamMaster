# ピヨトレ！基本情報技術者

## 2026年10月16日：審査提出済み

App Store Connectの提出詳細で、アプリ **1.0 (2)** と **全問題解放（非消耗型・300円）** の2項目がともに「審査待ち」であることを確認。App ID `6823176672`、提出ID `c52939f7-4bf9-4723-b155-c077b19cd8ed`。提出時刻はApple画面で2026年10月16日19:12 JST。

アプリ本体は無料、日本のみで配信し、承認後は手動リリース。無料184問・全1,004問の構成を、ストア原稿、購入商品、公開ページと照合済み。審査連絡先はAppleの非公開フォームに保存し、この記録には含めていない。

AdMobの専用本番アプリ・バナー・全画面広告IDを設定し、UMPの基本情報専用欧州同意メッセージ（日本語＋英語、同意拒否あり）を公開。7種のSDKデータ申告をAppleで公開し、`app-ads.txt` のDIRECT行も検証した。GoogleのStore連携と広告配信の準備状況審査は、App Storeで公開後に確認する。現時点では未公開・Google審査承認前。

宣伝画像は中型1206×2622・大型1320×2868を各6枚、01〜06の順で保存済み。署名付きアーカイブと教材検査を確認。基本情報の初回検証12件に加えて、広告本番設定後のユニット5件・購入画面UI1件も成功。Xcodeの送信は成功したが、Google広告SDKのdSYM不足警告があり、SDK内のクラッシュ解析には制限が残る。実機・iOS 17上での実行検証は未実施。

実状態の詳細は [submission-status.json](submission-status.json)、[提出画面](https://appstoreconnect.apple.com/apps/6823176672/distribution/reviewsubmissions/details/c52939f7-4bf9-4723-b155-c077b19cd8ed) を参照。

更新日：2026年10月15日。専用ターゲット、1,004問の教材、科目A・Bの学習画面を実装。

## 教材

| 内容 | 科目A | 科目B | 合計 |
| --- | ---: | ---: | ---: |
| IPA公開問題（2023〜2026年度） | 80 | 24 | 104 |
| オリジナル練習・模試 | 660 | 240 | 900 |
| 合計 | 740 | 264 | 1,004 |

公式公開問題は各年の実試験の抜粋で、完全な本試験セットではありません。公開分は科目別の短時間演習にしています。オリジナル模試は科目Aが60問・90分×11セット、科目Bが20問・100分×12セットです。Bは各セットでアルゴリズム・プログラミング16問、セキュリティ4問。

確定済みの[IPAシラバスVer.9.2](https://www.ipa.go.jp/shiken/syllabus/omgdg50000005kpe-att/syllabus_fe_ver9_2.pdf)を教材の基準にしています。2027年度向けのシラバス案は混在させていません。[curriculum.json](curriculum.json)に根拠とハッシュを保存。

公開過去問の正答は[IPA公開問題](https://www.ipa.go.jp/shiken/mondai-kaiotu/sg_fe/koukai/index.html)の公式解答例に固定し、16個の問題・解答PDFのURL、SHA-256、正答表を[sources.json](sources.json)に保存しています。解説とオリジナル問題は制作内AIで作成・確認したもので、IPAの監修や独立専門家の校閲を受けたものではありません。

オリジナル900問のうち、科目Aの660問は214知識目標を定義・用語同定・誤り発見の3形式で確認する642問と計算18問。科目Bはアルゴリズム20系統の結果・追跡・境界条件・計算量の反復演習と、48件の個別セキュリティ事例です。複数の問題で同じ学習目標を復習します。形式や入力の違いを、新しい知識領域の数とは数えていません。

## 長文の表示

- 科目Bを問題文、コード、図表、設問の順に区切り、本文の行間を確保。
- コードは画面幅で折り返す等幅表示を標準に設定。字下げと元の行番号を保ち、継続行を見分けられる。「表示設定」で文字サイズを3段階から選択し、折り返しも切替可能。アクセシビリティの大きな文字サイズでは設定欄を縦に並べて操作幅を確保。
- 長い文が入る表は、列名付きの縦のカードに再配置して折り返し。
- 上部に「本文を別表示」と「選択肢へ」を固定。読解画面を閉じても回答を保持。
- 読解画面の「本文内を移動」で先頭・コード・図表・末尾へ移動。
- 10肢の公式問題を省略せず表示（データモデルは最大16肢）。
- 年度画面の上部で科目A・Bを切り替え。公開過去問とオリジナル模試を併記。
- 正答率60%は練習目安として表示。本試験のIRT評価点600点と区別。

## アプリ設定

Scheme：`FundamentalInformation`。Bundle ID：`jp.hino.piyotre.fundamentalinformation`。

アプリコットの背景・ひよこ・アイコンと、濃いオレンジの操作色を使い、NWの青緑・応用情報のラベンダーから区別しています。学習履歴と買い切り商品のIDも独立しています。公式公開104問と第1回のオリジナルA60問・B20問、計184問を無料範囲に設定しています。

初回実装時（2026年10月15日）の状態は、ローカルStoreKit設定と広告無効の開発構成でした。その後の広告本番設定・ストア提出の結果は本書冒頭とsubmission-status.jsonを参照。

## 再生成と検証

```sh
python3 tools/fundamental-information/practice_a.py
python3 tools/fundamental-information/practice_b.py --verify
python3 tools/fundamental-information/past.py
python3 tools/fundamental-information/assemble_bank.py
python3 tools/fundamental-information/validate.py
python3 tools/fundamental-information/verify_official_calculations.py
xcodegen generate
xcodebuild -project ExamMaster.xcodeproj -scheme FundamentalInformation -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
```

最終の教材検証は[validation-report.json](validation-report.json)、出題・検算方針は[公開過去問](review-past.md)、[科目A](review-a.md)、[科目B](review-b.md)を参照。生成ツールによる検査だけで、専門家の独立校閲が完了したとは扱いません。

共通基盤58件とネットワーク版23件の既存ユニットテストは通過。応用情報版は7件中6件通過、1件は既存の広告設定に対する古い期待値（広告無効の期待に対して、開始前から設定が有効）で失敗しました。応用情報の教材・広告設定は変更していません。

基本情報版の最終検証：iPhone 17 Pro（iOS 26.2 Simulator）でユニット5件・UI7件、計12件が全件成功。ライトモード11件と、OSの外観をダークに切り替えた最大文字サイズ1件に分けて実行。文字サイズ変更と設定保持、折り返した長いコード行の左右の収まり、本文・表への移動、回答保持、10選択肢、横向き、購入・復元を確認しました。スクリーンショットはローカルの `evidence/` に保存しています（Git対象外）。実機とiOS 17での実行確認は未実施です。
