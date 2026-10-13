# ピヨトレ！応用情報技術者

2026-10-14 時点の開発状況。科目A専用です。科目Bの問題・画面・記述ノート・PDFは教材とアプリから除外しています。ユーザー指示によりApp Store Connectへの登録・申請・審査対応は保留中です。

## 収録範囲

- IPA公式の科目Aは2009〜2025年度の33回・2,640問。2011年度の特別試験と2020年度10月試験を含む、科目Aの公式PDF66件を取得しています。
- 2026年予想問題はオリジナル3セット・240問。各80問・150分、分野配分は50/10/20です。予想問題はIPA非公式です。
- 合計2,880問・36模試。2025年度春期・秋期160問が無料で、ほかは非消耗型IAPの対象です。
- 詳細校閲済みの過去問は1,568問。うち、依頼された2016年春期〜2025年秋期の19回・1,520問は全問完了し、それ以前の年度で個別校閲した問題が48問あります。
- 対象外の過去問1,072問は未校閲で、原問画像を維持しています。未校閲のOCRを正確な本文として扱っていません。

## 校閲と表示

過去問1,568問について、原問・公式正答を個別照合し、本文、全選択肢、詳しい解説、選択肢ごとの理由、解き方、読み上げ用説明を編集しました。公式の表は画面内の表などへ置き換え、本文と選択肢はテキストで表示します。図の理解に必要な範囲だけ画像を残します。生成後の検証では、過去問1,568問・予想問題240問をネイティブ表示、表UIを166問、図版を1,153ファイル確認しています。図版には未校閲問題の原問画像も含まれます。

校閲は制作内のAIレビューで、独立した外部専門家による確認ではありません。予想問題も独立した専門家校閲は未実施です。レビュー記録には原本・公式解答・編集内容のハッシュを保存し、変更時に再確認を要求します。

予想問題はIPAの現行シラバスVer.7.2を参照し、2026年の制度変更を反映しています。IPAは2026年度のCBT移行後も出題範囲・問題数・試験時間を変えないと案内しています。[IPAシラバスVer.7.2](https://www.ipa.go.jp/shiken/syllabus/omgdg50000005kq5-att/syllabus_ap_ver7_2.pdf)、[2026年度CBT案内](https://www.ipa.go.jp/shiken/2026/ap_koudo_sc-cbt.html)。

## アプリ設定

- `AppliedInformation` Scheme、Bundle ID `jp.hino.piyotre.appliedinformation`。
- ひよこ `#C5B1EF`、ニワトリ `#E5DEF7`、アクセント `#6554A4`。背景・カード・境界・補助文字もラベンダー系に変更しています。
- 分野別は既存のテーママップからサブカテゴリ一覧を経由して問題へ進みます。詳細ラベルから統一分類へ振り分け、未校閲の2015年以前の問題は詳細分類なしとして分けています。テーマ全体の問題一覧にも直接進めます。
- 無料の160問は2025年度春期・秋期。全問題解放の価格は開発用StoreKit設定で300円です。App Store Connect上の商品・価格は未登録です。
- 広告は無効、公開プライバシーポリシーURLは未設定。教材は`isDraft: true`です。過去問1,072問が未校閲のため公開用リリースゲートは通りません。

## 検証結果

- `tools/applied-information/validate.py` 成功。公式正答2,640問、原本PDF66件のハッシュ、模試36回、図版とネイティブ表示を確認。詳細校閲1,568/2,640、未校閲1,072、`releaseReady: false`。
- Pythonテスト32件成功。原問に関する計算、解釈、表UI、ハッシュ保護、予想問題の問題数・分野配分・参照・選択肢別解説を確認。
- `python3 tools/GenerateMascot.py --check` 成功（31ファイル）。`git diff --check` 成功。
- XcodeGen生成と、キャッシュ済みSwift Packageを使った署名なしのiOS Simulator向けビルドが成功。XCTestのunit/UIテスト対象も`build-for-testing`でコンパイルしましたが、この環境ではCoreSimulatorサービスに接続できずテストは実行していません。
- 実機、VoiceOverの手動確認、App Store Connectの商品登録・審査は未実施です。

## 再生成

```sh
.venv-network/bin/python tools/applied-information/assemble_bank.py
.venv-network/bin/python tools/applied-information/validate.py
.venv-network/bin/python -m unittest discover -s tools/applied-information -p 'test_*.py' -v
python3 tools/GenerateMascot.py --check
xcodegen generate
```

公式の過去問は[IPA試験問題・解答例](https://www.ipa.go.jp/shiken/mondai-kaiotu/index.html)から取得しています。科目Aの基準点到達だけで試験全体の合格とは判定しません。
