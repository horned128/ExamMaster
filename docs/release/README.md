# ピヨトレ！ネットワークスペシャリストの公開申請

2026-10-14（日本時間）更新。対象は **NetworkSpecialist** Scheme。ExamMaster Schemeは架空資格のデモです。375問を収録。1.0（2）は課金商品を取得できずGuideline 2.1(b)で却下された。有料アプリ契約・銀行・税務情報を有効化し、買い切り価格を300円に変更。商品取得を改善した署名付きビルド3を提出し、TestFlightでの購入確認を受領。2026-10-14 10:27 JST、ビルド3と300円の買い切り商品を同じ提出物でAppleが受け付け、両項目とも審査待ち。提出IDは`01fd5a77-32b6-4c9c-ad66-52d2a43a2e38`。承認後は手動公開。

[App Store Connectの提出物](https://appstoreconnect.apple.com/apps/6821629759/distribution/reviewsubmissions/details/01fd5a77-32b6-4c9c-ad66-52d2a43a2e38)、[申請結果・検証記録](submission-status.json)。Appleの審査・ストア公開・AdMobアプリ審査はまだ完了していない。ストア公開後にAdMobへ公開ページをリンクし、Google側の審査とapp-ads.txt認証結果を確認する。

初回提出の履歴：08:34 JSTには1.0（1）とIAPが審査待ちだったが、その後ITMS-91064で「バイナリが無効」になった。アプリ本体のPrivacy Manifestでtracking=trueに対する対象ドメイン一覧が空だったため、広告ホストを追記し、回帰テストと実リソース検査を追加した。ビルド2はXcode再ログイン後に配布用書き出しとアップロードが成功。既存の審査提出物を更新して再提出した。詳細は[itms-91064-build1.md](itms-91064-build1.md)。

## 1.0（3）の課金修正

[調査と変更の記録](iap-review-2026-10-13.md)を参照。購入画面を開くたびに商品と購入権限を再取得し、商品が空・通信失敗の際は最大3回再試行する。成功時に古いエラーを消し、検証済み購入済み権限は商品情報の取得失敗で取り消さない。

300円のStoreKitTestでiPhone単体23件＋購入UI1件、審査端末と同じiPad Air M3 / iPadOS 27.0の対象5件、iPhone 17 Pro Maxの購入UI1件が成功。両iPhone画像の6枚目を `06-purchase-300.png` へ差し替え、旧480円の画像とテスト結果は履歴として保持する。署名付きビルド3のArchiveと全3つのPrivacy Manifest検査が成功。SubmitDockの既存台帳と公開ページも300円へ更新済み。TestFlight 1.0（3）での買い切り商品の購入動作は利用者が確認済み。2026-10-14 10:27 JSTにビルド3とIAPを同一提出へまとめ、Apple受付済みで両項目とも審査待ち。実Sandboxの購入確認は利用者申告、返金動作は未確認。

## 375問の教材と3問の採点方針

**375問（過去問300＋予想75）、無料75・有料300を収録済み。** 全12年度と予想3回の各25問・40分固定模試、15原稿と同梱教材のisDraft=falseを反映。教材の`validate.py --release`はエラー・不足0で通過した。

| 年度・問題 | 本アプリの正答 | 回答後の解説で明示すること |
|---|---|---|
| 2015年秋期 午前Ⅱ 問9 | エ | IPsec対応のSHOULDへの変更は2011年で出題前。「当時は必須で、その後に変更」とは説明しない。 |
| 2018年秋期 午前Ⅱ 問17 | ウ（EAP-TLS） | EAP-TTLSも任意のクライアント証明書認証が可能。「証明書を使えない」という理由にしない。 |
| 2024年春期 午前Ⅱ 問22 | ア | PCI-SIGも32レーンを記述するため、規格全体の最大値を16としてウを否定しない。 |

原文と公式正答を保持し、当時の公式正答による採点と仕様上の注意を回答後に常時表示する。利用者指定による編集方針であり、技術的一意性の解決やIPAの訂正取得ではない。根拠と制作内レビューは[今回の編集方針](../network-specialist/review-notes/historical-answer-policy.md)、旧調査は[HELD.md](../network-specialist/HELD.md)。

2010年の1問は利用者指定で削除・制作資料に保管したもので、この3問とは別。2020年は対象の公開NW問題がないため欠落の補填対象ではない。

## 必要な情報と現在の状態

| 情報 | 2026-10-14の状態 |
|---|---|
| Apple登録 | Team QZH83KGFVX、App Store Connect ID 6821629759。既存アカウントで新アプリを登録済み。 |
| 正式識別子 | Bundle `jp.hino.piyotre.networkspecialist`、非消耗型商品 `jp.hino.piyotre.networkspecialist.unlock`。本番設定は[production-config.json](production-config.json)。 |
| 販売 | 本体無料、全問題解放＋広告停止は買い切り300円、日本のみ。手動公開。商品ID 6821756732を維持。有料アプリ契約・銀行・税務情報は有効。 |
| 掲載情報 | 正式名「ピヨトレ！ネットワークスペシャリスト」、サブタイトル・日本語説明・キーワード・教育カテゴリ・審査連絡先を保存。個人の審査連絡先はGit管理外のprivateファイルにのみ保存。 |
| 公開Web | [サポート兼紹介ページ](https://submitdock-ios-pages.netlify.app/support/mv3sm6om-8784abde)、[プライバシー](https://submitdock-ios-pages.netlify.app/privacy/mv3sm6om-8784abde)。既存URLのままアイコン・Markdown・375問画像・300円表示を更新済み。 |
| AdMob | 本番アプリ、バナー、インタースティシャルのIDを登録・実装済み。一般向けGレーティングに制限し、高エンゲージメント広告をオフ。日本語・英語の欧州向けUMPメッセージを公開。 |
| app-ads.txt | ドメイン直下に正しい `pub-9785585722959806` のDIRECT行が公開済み。既存の正しい行を保持。App Store公開後にAdMobへストアを紐付け、認証・アプリ審査結果を確認する。 |
| App Privacy | 最終ArchiveのGoogle広告/UMP Privacy Manifestに従い7種類を入力。利用者の実行時同意を得てプライバシーラベル公開済み。位置情報・ID・使用状況は本人に関連、診断は非関連、デバイスIDをトラッキング用途として申告。学習履歴は端末保存。 |
| 年齢/権利/暗号 | 広告あり・教育4+、コンテンツ権利情報を保存。標準システム/SDKのネットワーク暗号化のみで`ITSAppUsesNonExemptEncryption=false`。 |
| ビルド3 | `.submitdock/piyotre-network/1.0-3.xcarchive` を署名・検査済み。`upload-1.0-3/upload.log` に Upload succeeded / EXPORT SUCCEEDED。Appleでバイナリ確認済み、版1.0への選択保存と内部TestFlight配布済み。2026-10-14にビルド3と300円IAPを同時再提出し、両項目の審査待ちを確認。 |
| ビルド2の履歴 | `release-artifacts/app-store-1.0-build2-privacy-fix/` に修正版のArchive/IPAと検査結果、`app-store-1.0-build2-upload/` に **Upload succeeded / EXPORT SUCCEEDED** のログ。ビルド2は処理完了・再提出済み。アップロード済み番号を再送しない。旧ビルド1は履歴として保持。 |
| 検証 | 過去の教材103件に加え、ビルド3の申請ツール17件・教材検査の回帰10件・事前検査16項目・ArchiveのPrivacy Manifest3つが成功。300円のStoreKitTestはiPhone単体23＋UI1、iPadOS 27対象5、大型iPhone購入UI1が成功。実Sandboxの購入は利用者が確認済みと申告。返金・最小OS実機・VoiceOverは未確認。 |

Appleは2026年4月28日からiOS 26以降のSDKでのビルドを要求。現在のXcode 27は対応範囲だが、提出時点の公式条件も再確認する。iOS 17という最小対応OSと、提出に必要なビルドSDKは別。2027年4月の追加要件を現在の要件と混同しない。

IPAの公開過去問は教育目的など制度の意義に反しない利用で、法令に特別の定めがある場合を除き許諾・使用料は不要と案内されている。著作権は放棄されず、年度・期・試験区分・時間区分・問番号の出典表示と改変の明記が必要。非公式教材でありIPA監修ではない表記、キャラクターの利用権も確認する。

## 申請までの順序

1. 教材375問の完成版検証は通過済み。最終ビルドでも組立て一致・公式正答・レビュー／図版ハッシュを検査する。3問の採点方針と回答後の注意書きを保持する。
2. Developer契約を確認。IAPを提供するのでPaid Apps Agreement・税務・銀行情報を本人が登録。販売国を決める。
3. 正式Bundle IDを登録し、NetworkSpecialistにTeamと署名を設定。App Store Connectにアプリを作成（日本語、iOS、正式Bundle ID、管理用SKU）。名前の利用可否はApple側で確認する。
4. 買い切り商品を作成。正式商品IDとアプリを一致させる。販売地域・税込300円の価格設定・商品名/説明・審査用購入画面を入力。
5. 正式サポート/ポリシーを公開。本番広告・同意を設定し、App Privacy・年齢区分・暗号化・権利を回答。販売文・画像・審査メモを確定する。
6. 下記のローカル検査と単体/対象UIテストを実行。署名付きArchiveからPrivacy Reportを生成・確認し、実機検証する。
7. ArchiveからIPAを生成しApp Store Connectへアップロード。ビルドの処理完了を確認し、暗号化申告等を済ませ、TestFlight/Sandboxで検証。外部TestFlightはベータ審査が必要になる場合がある。
8. アプリのバージョンに審査するビルドを選択。初回の非消耗型IAPも同じ審査提出に含める。審査メモに無料範囲、ロック入口、購入・復元、アカウント不要、独自予想問題であることを書く。
9. 最終内容を確認してSubmit for Review。初回は手動公開を推奨し、承認後の配信開始時刻を自分で決める。ビルドのアップロード・審査提出・審査承認・配信開始は別の段階。

## 用意した自動化

リポジトリのルートから実行する。Xcodeのビルド/テスト/Archiveは順次実行する。秘密鍵や証明書をチャットへ貼り付けず、ローカルのキー用ディレクトリ/KeychainまたはCI Secretsに置く。`.p8`/`.p12`/provisioning profileとrelease-artifactsはgitignore済み。

### 設定・教材の事前検査（実装済み）

```sh
.venv-network/bin/python tools/release/preflight.py --report /tmp/exammaster-release-preflight.json
```

Releaseの実ビルド設定と教材を読み、署名Team・正式ID・SDK・商品一致・広告ID/Info.plist一致・ポリシーを検査。既存教材の`validate.py --release`も実行する。未完了なら終了コード1、実行不能なら2。教材や本番IDを勝手に補完せず、Appleのアカウントにも変更を加えない。レポートのlocalChecksPassedはApple側・実機・法務・収集データの完了保証ではない。

最新の[事前検査レポート](preflight-2026-10-14.json)は16項目すべて通過。旧480円の固定値を300円に更新し、検査の回帰10件も成功。正式ID・300円の設定・広告ID・完成375問に加え、Privacy Manifestのトラッキング宣言と対象ドメインの整合も確認した。旧10/11レポートは本番設定前の履歴として保持。

保存済み設定で再検査する場合:

```sh
xcodebuild -project ExamMaster.xcodeproj -scheme NetworkSpecialist -configuration Release -destination 'generic/platform=iOS' -showBuildSettings -json > /tmp/exammaster-release-settings.json
.venv-network/bin/python tools/release/preflight.py --build-settings /tmp/exammaster-release-settings.json --report /tmp/exammaster-release-preflight.json
```

### 署名付きArchiveとIPA作成（実行済み）

```sh
bash tools/release/archive.sh /tmp/exammaster-release-build-001
```

ローカル検査を通った場合だけArchive/Exportを実行し、preflight.json・archive.log・export.log・IPAを新しい出力先に保存する。実際のArchiveとIPAに含まれるPrivacy Manifestも検査し、archive-privacy-check.json・ipa-privacy-check.jsonへ結果を保存する。自動署名にはXcodeのDeveloperアカウントと権限が必要。ビルド番号はアップロード済み番号より進めてから実行する。契約・Webページ・実機検証等を済ませてから配布用に使用する。

### アップロード（実行済み）

既存のXcode Developerアカウントを使ってアップロードできる。API秘密鍵の新規発行は不要。次回は新しいビルド番号でArchiveを作成し、新しい保存先へ実行する。

```sh
bash tools/release/upload.sh --archive /absolute/path/NetworkSpecialist.xcarchive /tmp/piyotre-upload-build2
```

ローカル検査、実際のPrivacy Manifest、ArchiveのBundle/Team一致を確認して`xcodebuild -exportArchive`の`destination=upload`を実行。APIキーを既に持つCI向けには従来のIPA指定モードも保持（EXAMMASTER_ASC_KEY_ID/ISSUER_IDが必要）。どちらもビルドのアップロードのみ。審査への追加・提出・手動公開は別の操作。

### スクリーンショットと入力文

`tools/release/screenshots.sh`で大型iPhoneの対象UIからXCTest添付を保存・書き出し。375問の最終教材と正式表示名で撮影済み。申請前には不要な画像を除いて、最終文面と実画像を確認する。広告はテスト中停止し、購入画面はStoreKitTestの開発商品である点に注意。支払画面の正式商品・価格はSandboxでも確認する。

2026-10-11に正式名称・375問版でスクリプトを再実行し、対象UI3件成功（失敗・スキップ0）。最新12枚は1320×2868・RGB・アルファなしで確認し、ホーム／試験日／年度の25問表示／3セット選択を目視した。`release-artifacts/screenshots-draft-piyotre-375-20261011/`に画像とmanifestを保存（Git管理外）。旧`release-artifacts/screenshots-draft-20261011/`は改名前372問版なので提出用に使わない。本番の商品・価格と最終文面を確認して画像を選定する。

```sh
bash tools/release/screenshots.sh <iPhone-17-Pro-MaxのSimulator-UDID> /tmp/exammaster-store-screenshots-001
```

2026-10-12の申請画面ではDynamic Island中型iPhone画像が必須。専用iPhone 17 Proで実画面を再撮影し、対象UI4件（ホーム試験日・年度/分野・予想3回・480円購入/ロック）が成功した。中型1206×2622と大型1320×2868のホーム、年度、分野マップ、予想3セット、回答、480円購入画面を各6枚選定。`release-artifacts/app-store-medium/`と`release-artifacts/app-store-selected/`へ原画像とmanifestを保存。画像の引き伸ばしや合成は行っていない。

`metadata-ja.json`に販売文と審査メモの草稿を保存。375問（無料75・有料300）の件数と、当時の公式正答による採点方針を反映済み。正式名称・運営者hino・サポート用メール・サポート／マーケティング／ポリシーURLは反映済み。公開ファイルの審査担当者は空欄で、実際の連絡先はGit管理外に保存しAppleへ入力済み。名前・サブタイトルは30文字以内、キーワードはAppleの入力項目仕様の100バイト以内で確認（草稿はUTF-8で100バイト）。自動アップロードには使用していない。

### SubmitDockの公開ページ（同じURLで更新済み）

Page IDは`mv3sm6om-8784abde`。新しい `/api/pages` PATCH APIでアイコン、Markdown、375問版の画像3枚を更新した。紹介・FAQに無料75問と300円買い切り、公式正答採点の注意を反映。新規ページを作ってURLを変える必要はない。

原稿は[web-pages](web-pages/)、公開情報は[published.json](web-pages/published.json)。編集トークンはGit対象外の`release-artifacts/submitdock/page.private.json`（0600）に保持し、ログに出さない。旧ページからの編集トークン取得と同一IDへの更新にも対応した。

```sh
# 原稿・画像の検査のみ
.venv-network/bin/python tools/release/submitdock_pages.py
# 既存のページを更新（公開ページの変更を意図したときのみ）
.venv-network/bin/python tools/release/submitdock_pages.py --update --publish --icon Assets.xcassets/NetworkSpecialistIcon.appiconset/AppIcon.png
```

新しい資格のページはその資格専用の原稿・保存先・登録情報で発行する。ネットワーク版のトークンや保存結果を流用しない。審査結果や公開後のAdMob確認を継続的に監視する自動化は今回作成していない。

## 一次資料（2026-10-11確認）

- [Apple SDK要件](https://developer.apple.com/news/upcoming-requirements/?id=02032026a)
- [App Store Connectの基本フロー・契約/銀行/税](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)
- [App Storeの入力項目](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/)
- [販売文・キーワード・審査担当者の項目](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [スクリーンショット仕様](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [初回IAPの提出](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [プライバシー申告](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [年齢区分](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
- [暗号化申告](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [アップロードとaltool](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [App Store Connect API](https://developer.apple.com/app-store-connect/api/)、[APIキー](https://developer.apple.com/documentation/AppStoreConnectAPI/creating-api-keys-for-app-store-connect-api)
- [Google Mobile Adsのデータ開示](https://developers.google.com/admob/ios/privacy/data-disclosure)
- [IPAの過去問利用条件](https://www.ipa.go.jp/shiken/faq.html)
- [2015の前提：RFC6434 §11](https://www.rfc-editor.org/rfc/rfc6434.txt)、[2018の前提：RFC5281 §7](https://www.rfc-editor.org/rfc/rfc5281.txt)、[PCI-SIG architecture](https://pcisig.com/what-pci-express-pcie-architecture)
