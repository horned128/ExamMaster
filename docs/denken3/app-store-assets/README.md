# App Store用画像（ピヨトレ！電験三種）

ピヨポップUI版。2026-11-06作成。日本語・iPhoneのみ、全6枚。
出力は1320×2868（6.9インチ）と1206×2622（6.3インチ）。サイズはApple公式仕様（2026-10-15確認）に従う：
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## パネル

| # | 見出し | 補足 | 実画面 | 根拠 |
| --- | --- | --- | --- | --- |
| 01 | 今日の10問、ピヨといっしょに。 | 復習と新しい問題を、毎日ちょうどよく。 | `assets/home.png` | SessionPlanner.today count:10 / DashboardView homeTodayStudy |
| 02 | 1問ずつ、サクッと解ける。 | 理論・電力・機械・法規を、スマホで。 | `assets/question.png` | SessionView / QuestionContentView |
| 03 | 答えたら、すぐ解説。 | 正解の理由と、まちがえやすい点を確認。 | `assets/answer.png` | SessionView answer feedback |
| 04 | 公式問題と予想問題で練習。 | 令和8年度上期の公式問題＋予想問題3回分。 | `assets/years.png` | questions.json 320問 / LibraryView |
| 05 | 4科目を、分野別に。 | 理論・電力・機械・法規の進み具合がひと目で。 | `assets/subjects.png` | qualification.json subjects / LibraryView subject-* |
| 06 | 続けた日が、あしあとに。 | 学習記録とピヨの成長で、毎日つづく。 | `assets/records.png` | InsightsView / TankeiGrowth |

実画面は `DenkenStudyUITests.testStoreScreenshotSet`（iPhone 17 Pro / iOS 26.2 シミュレータ、ライトモード、`-UITestSeedCompanionHistory` で3日分の学習履歴を投入、ステータスバー9:41）。
今日の学習の1問目は一度回答して正答を確認し、再起動して正答を選んだ画面を使う。画像は等比縮小のみで、UIの加工・文字の重ね・トリミングはしない。

## 再生成

```bash
xcrun simctl status_bar <udid> override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
xcodebuild test -project ExamMaster.xcodeproj -scheme DenkenThird -destination 'platform=iOS Simulator,id=<udid>' -only-testing:DenkenThirdUITests/DenkenStudyUITests/testStoreScreenshotSet -resultBundlePath <out>.xcresult
xcrun xcresulttool export attachments --path <out>.xcresult --output-path <dir>
```

`store-0N-*.png` を `assets/` の対応ファイル名へコピーし、文言は `storyboard.json` を編集してから：

```bash
python3 tools/release/store_screenshots.py docs/denken3/app-store-assets/storyboard.json
tools/release/render_store_screenshots.sh docs/denken3/app-store-assets
```

描画はGoogle Chromeのヘッドレス（Playwright不要）。フォントはmacOS標準のヒラギノ角ゴ・丸ゴ。書き出し後にサイズとアルファなし（RGB）を検査する。

## QA

- 実画面・正確さ 2/2：数値は `qualification.json`（無料範囲）・`questions.json`（総数）・`products.storekit`（300円）と照合。
- 読みやすさ 2/2：見出しは25%縮小のコンタクトシートで判読可能。
- 統一感 2/2：シリーズ共通の黄色／クリーム交互、資格色はチップの縁と点のみ。
- 画面の存在感 2/2：端末全体が見切れずに収まる。
- サイズ・はみ出し・個人情報 2/2：2サイズとも寸法一致、個人情報なし。
