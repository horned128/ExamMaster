# ピヨトレ！応用情報技術者

2026-10-13。科目A専用の開発版。ユーザー指示により科目Bの画面・記述ノート・同梱PDFを削除しました。App Storeへの登録・審査対応は保留です。

`AppliedInformation` Scheme、Bundle ID `jp.hino.piyotre.appliedinformation`。共通SwiftUIコードを使い、資格ごとに教材・商品・端末内学習履歴を分離します。

## 教材と表示

- 公式科目A（旧午前）：2009〜2025年度の33回、2,640問。2011年度の特別試験・2020年度10月試験を含みます。
- 独自2026年予想問題：80問×3回、240問。計2,880問・36模試。各模試80問・150分。予想問題はIPA非公式です。
- 2025年度春期・秋期160問が無料。他の過去問と予想問題は資格専用の非消耗型IAPで解放します。
- 校閲済み522問を本文・選択肢のテキスト表示へ変更。カルノー図、在庫、原価、部品数等の55問は表UIで表示。木構造・波形・曲線・論理回路の7問だけ図の領域を画像にし、原問の本文は画像から外しました。
- 未校閲の2,118問は、文字認識の誤りを確定本文として扱わず、現段階では原問画像を維持しています。条件・全選択肢の校合と同時にテキスト化を進めます。全件テキスト化は未完了です。
- 詳細解説・全4選択肢の理由・解き方・読み上げ用の補助説明は522/2,640問。2024〜2025年度春秋320問と、再出題を個別に目視照合した169問と2023年秋期の33問です。校閲種別は制作内AI校閲で、独立した外部専門家校閲ではありません。

本文は編集済みの条件・選択肢を使用し、図表は数値や親子関係等を表UIまたはテキストへ置き換えます。必要な図のみIPA原問から切り出します。変換済みの問題の原問全体画像はアプリへ同梱せず、制作証跡として `evidence/question-crops/` に保存します。画像のタップ・ピンチ拡大は図に限って残します。

公式正答2,640問は公式解答PDFと自動照合します。文字情報のない2022年春期だけは解答表を画像で確認し、[転記記録](answer-overrides.json)に保存。本文・原本・公式解答・画像・編集元のハッシュが変わったレビューは生成時に拒否します。制作途中のため `isDraft: true`、`validate.py --release` は未校閲の過去問が1件でも残る教材を拒否します。

記録：[進捗](editorial-progress.json)、[検証](validation-report.json)、[原問切出し](figure-crops.json)、[図だけの切出し](diagram-crops.json)、[編集元](content/)。科目Aの公式66 PDFだけを取得・検証対象とします。以前取得した科目B資料は制作履歴にのみ保存し、アプリでは使用しません。アプリへの科目Bリンク・機能もありません。

## 配色とアプリ設定

相棒：ひよこ `#C5B1EF`、ニワトリ `#E5DEF7`、アクセント `#6554A4`。背景・カード・境界・補助文字・学習状態の色を資格設定から変更し、ライト／ダークでラベンダーの配色を使用。専用1024pxアイコンも生成しています。

ホームにテクノロジ／マネジメント／ストラテジの3分野の習熟度を表示。年度内の春期・秋期・特別試験をそれぞれ80問の模試として選べます。

IAPは480円の開発用StoreKit設定。本番商品登録・広告枠・公開プライバシーポリシーURLは未設定です。広告は無効。NW版の本番IDを使いません。App Store登録・審査はユーザー指示で保留です。

## 検証

- 教材：2,880問、全36模試、公式正答、原本ハッシュ、表示ブロック、テキスト化522問の本文一致を検証。
- Python 32件成功。ハミング符号の全16符号語×7位置の誤り訂正、デッドロックの全獲得順序、メモリ転送、SQLの外部結合・NULL、クリティカルパス、計算問題等を別方式で確認。
- テキスト化前の320問時点ではAP専用XCTest 8件成功。`/tmp/AppliedInformation-2024-editorial-unit-tests.xcresult`。
- 160問時点ではAP 8 unit＋3 UI成功。`/tmp/AppliedInformation-2025-editorial-tests.xcresult`、画面証跡 `evidence/ui-2025-editorial/`。この履歴には削除前の科目B検証を含みます。
- 基盤コードは以前のNW 20 unit、ベース58 unit成功を記録しています。科目B削除後もNW 20 unit・ベース58 unitが再度成功しました。
- Release iOS構成の署名なしビルドは160問時点で成功（`/tmp/ap-release-build.log`）。新表示のRelease iOSビルドも成功（341問時点、署名なし、`/tmp/ap-native-release-build.log`）。

実機・VoiceOver操作と予想問題の独立した専門家校閲は未完了です。

## 再生成

```sh
.venv-network/bin/python tools/applied-information/assemble_bank.py
.venv-network/bin/python tools/applied-information/validate.py
.venv-network/bin/python -m unittest discover -s tools/applied-information -p 'test_*.py' -v
python3 tools/GenerateMascot.py --check
xcodegen generate
xcodebuild -project ExamMaster.xcodeproj -scheme AppliedInformation \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
```

参照：[IPA公式過去問](https://www.ipa.go.jp/shiken/mondai-kaiotu/index.html)、[試験要綱・シラバス](https://www.ipa.go.jp/shiken/syllabus/gaiyou.html)。科目Aの基準点到達だけで資格試験全体の合格とは判定しません。

新表示ではAP 6 unit＋3 UIが同一実行で成功。テキスト・表・図の拡大と科目B画面の不在を確認。結果と画像は[検証記録](verification.json)を参照してください。UI検証は513問時点の教材、Pythonによる全対応検証は上記の最新問題数です。

SQLの等幅表示・在庫表・全コンテンツ形式を最新522問のAP 6 unitで再検証し成功（`/tmp/AppliedInformation-522-native-unit-tests.xcresult`）。513問時点のAP 6 unit＋3 UIは同一実行で全件成功（`/tmp/AppliedInformation-513-native-tests.xcresult`）。

最新522問時点のRelease構成・署名なしビルドに成功（`/tmp/ap-522-native-release-clean-build.log`）。完成物の教材が元データと一致し、図版2,157枚が必要な資産の集合と完全一致すること、科目Bファイルの不在を確認しました。提出・公開はしていません。
