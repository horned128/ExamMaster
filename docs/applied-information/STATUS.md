# ピヨトレ！応用情報技術者

2026-10-14 時点の制作・提出状況。科目A専用です。科目Bの問題・画面・記述ノート・PDFは収録していません。

## リリース対象

- IPA公式の科目Aは2009〜2025年度の33回・2,640問で、公式PDF66件を取得・保管しています。
- 配信対象は、指定された2016年度春期〜2025年度秋期の19回・1,520問です。2016年春期より前の1,120問はこの版に含めません（未校閲1,072問と、旧範囲で個別校閲済みの48問）。
- 2026年予想問題はオリジナル3セット・240問。各80問・150分、分野配分は50/10/20です。予想問題はIPA非公式です。
- 合計1,760問・22模試。2025年度春期・秋期の160問は無料で、残りは買い切り購入の対象です。

## 校閲と表示

収録する過去問1,520問は、原問・公式正答を個別照合し、本文、全選択肢、詳しい解説、選択肢ごとの理由、解き方、読み上げ用説明を編集しました。公式の表は画面内の表で表現し、本文と選択肢はテキスト、図の理解に必要なものだけ画像で表示します。校閲は制作内AIによるもので、独立した外部専門家による確認ではありません。予想問題も外部専門家校閲は未実施です。

予想問題はIPAの現行シラバスVer.7.2を参照しています。IPAは2026年度のCBT移行後も出題範囲・問題数・試験時間を変えないと案内しています。[IPAシラバスVer.7.2](https://www.ipa.go.jp/shiken/syllabus/omgdg50000005kq5-att/syllabus_ap_ver7_2.pdf)、[2026年度CBT案内](https://www.ipa.go.jp/shiken/2026/ap_koudo_sc-cbt.html)。

## アプリと本番設定

- Scheme `AppliedInformation`、Bundle ID `jp.hino.piyotre.appliedinformation`、Version 1.0 / Build 1。
- ひよこ `#C5B1EF`、ニワトリ `#E5DEF7`、アクセント `#6554A4`。背景・カード・境界・補助文字もラベンダー系です。
- 分野別はテーマからサブカテゴリへ二段階で絞れます。収録する全問題が詳細分類に含まれます。
- 無料の160問は2025年度春期・秋期。IAP商品ID `jp.hino.piyotre.appliedinformation.unlock`、非消耗型、価格300円。App Store Connect商品を登録済みです（Apple ID `6822732714`）。
- 無料版はGoogle Mobile Ads SDK（AdMob）でバナー広告と頻度を制限した全画面広告を表示し、購入後は停止します。Google AdMobアプリ・広告枠を本番IDで作成済みですが、AdMob上では未公開の状態です。SafariでSubmitDockに専用台帳を作成済みです。サポートページは公開中、広告・同意管理を反映した新しいプライバシー文面はSubmitDockの下書きで、公開反映は未完了です。
- 2026年10月14日にApp Store ConnectでPaid Applications契約（Schedule 2・3）を受諾し、有効状態を確認しました（画面表示期間：2026年10月14日〜2027年2月7日）。Apple Developer PortalにBundle ID `jp.hino.piyotre.appliedinformation` を登録し、App Store Connectのアプリを作成済みです（Apple ID `6822732103`、iOS 1.0、提出準備中）。
- 非消耗型IAP「全問題と模試を解放」は日本ストア300円で登録済みです。初回審査用スクリーンショットのApp Store Connect添付とアプリバージョンへの関連付けは未完了です。アプリの配信先は日本のみ、承認後のリリース方式は手動に設定します。

## 検証状況

- `tools/applied-information/validate.py` は成功。公式ソース66件・全2,640問分の正答資料を検証し、配信対象1,520問、予想問題240問、模試22回、未校閲配信問題0件を確認しています。
- App Store掲載用の6枚を `app-store-assets/` に作成し、編集用HTML/CSS、原画像、一覧プレビュー、品質検証結果を同梱しました。各PNGは1320×2868、透過なしです。リリース用manifestはこの6枚を参照し、SubmitDockの素材・メタデータ検査の必須項目も通過しました。App Store Connectへの画像アップロードは未完了です。
- `tools/applied-information` のPythonテスト32件、マスコット資産31件の検査、`git diff --check`は過去の検証で成功しています。直近のXcodeスクリーンショット撮影テストは、SwiftPM/ClangキャッシュとCoreSimulatorへのアクセス不足で失敗し、その後の再成功は未確認です。2026年10月14日現在、空き容量は約18GBです。
- 既知の制約：実機・VoiceOverの手動確認、最新版ビルドのアップロード、審査提出、App Store Connectのプライバシー申告は未完了です。制作内AIレビューは独立専門家の校閲を意味しません。

## 再生成

```sh
.venv-network/bin/python tools/applied-information/assemble_bank.py
.venv-network/bin/python tools/applied-information/validate.py
.venv-network/bin/python -m unittest discover -s tools/applied-information -p 'test_*.py' -v
python3 tools/GenerateMascot.py --check
xcodegen generate
```

公式の過去問は[IPA試験問題・解答例](https://www.ipa.go.jp/shiken/mondai-kaiotu/index.html)から取得しています。科目Aの基準点到達だけで試験全体の合格とは判定しません。
