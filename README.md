# ピヨトレ！資格学習シリーズ / ExamMaster

**iPhone向け・無料＋広告／買い切り型のWhite Label試験対策アプリ基盤。** 1つのSwiftUIコードベースから、資格ごとに異なるBundle ID・表示名・テーマ・アイコン・問題集・無料範囲・StoreKit商品・広告ユニットを持つ独立アプリを作ります。アカウントやバックエンドは不要です。

架空のベースサンプルと、制作中のネットワークスペシャリスト専用アプリを含みます。共通コードは複製せず、資格別ターゲット・設定・教材で独立アプリを作ります。

公開シリーズ名は「ピヨトレ！」。アプリ名は「ピヨトレ！＋資格名」で統一します。**ピヨトレ！ネットワークスペシャリスト**に加え、**ピヨトレ！応用情報技術者**の開発用ターゲット・教材を追加しています。資格ごとに独立した教材・商品・Bundle IDを設定します。

| Scheme | 資格 | Bundle ID | 問題 / 無料 |
| --- | --- | --- | --- |
| `ExamMaster` | 設備安全管理士（架空） | `jp.example.exammaster.demo` | 32 / 12 |
| `NetworkSpecialist` | ネットワークスペシャリスト | `jp.hino.piyotre.networkspecialist` | 375 / 75 |
| `AppliedInformation` | 応用情報技術者 | `jp.hino.piyotre.appliedinformation` | 1,760 / 160 |
| `FundamentalInformation` | 基本情報技術者 | `jp.hino.piyotre.fundamentalinformation` | 1,004 / 184 |
| `DenkenThird` | 電験三種 | `jp.hino.piyotre.denken3` | 320解答欄 / 320 |

電験三種版は理論・電力・機械・法規の4科目に対応し、令和8年度上期の公式過去問66大問・80解答欄と、2027年実施向けのオリジナル予想3回・240解答欄を収録しています。全320解答欄が無料・広告なしです。次回の正式区分は2026年度（令和8年度）下期で、2027年2〜3月に実施。予想は4科目×3回の固定セットです。理論・機械の模試では問17／問18を選択し、法規は6点・7点の配点で採点します。公式原問は拡大可能な画像、予想の本文・数式と解説はテキストです。公式過去問15回分の追加用調査一覧も整理しました。[電験三種の構成・出典・検証状況](docs/denken3/STATUS.md)、[予想問題の構成と検証](docs/denken3/PREDICTIONS.md)を参照してください。

基本情報版は科目A・科目Bに対応します。2023〜2026年度のIPA公開問題104問と、現行シラバスVer.9.2を基準にしたオリジナル練習900問を収録。科目Aは60問・90分×11回、科目Bは20問・100分×12回のオリジナル模試です。公開問題は各年A20問・B6問の抜粋として扱い、本番の完全セットと区別しています。科目Bは段落・コード・図表の区切り、本文を別表示する読解画面、本文内の移動、選択肢へのジャンプに対応。アプリコット系の配色と専用アイコンを使います。公開問題104問とオリジナル第1回A・Bの80問は無料です。[構成・出典・検証状況](docs/fundamental-information/STATUS.md)を参照してください。

応用情報版は科目A専用で、指定範囲の2016年春期〜2025年秋期の公式過去問19回1,520問と、2026年オリジナル予想問題3セット240問を収録します。過去問は全1,520問を制作内AIで個別校閲し、本文・選択肢はテキスト、表はUI、必要な図だけ画像にしています。2016年春期より前の1,120問はこの配信版に含めません。科目Bの機能・教材は除外し、分野別はテーマからサブカテゴリへ二段階で絞れます。配色はラベンダー系、各模試80問・150分。買い切り商品は300円の開発設定済みで、App Store Connectへの登録・提出を準備中です。[制作状況と検証](docs/applied-information/STATUS.md)を参照してください。

**設備安全管理士は架空の教材です。NWは375問（無料75・有料300）を収録し、App Storeで配信中です。** [ピヨトレ！ネットワークスペシャリストを入手](https://apps.apple.com/jp/app/ピヨトレ-ネットワークスペシャリスト/id6821629759)。対象は2013〜2025年の過去問300問（2020年は対象試験なし）と、オリジナル2026年予想問題の第1〜3回・計75問。全12年度と予想3回は各25問・40分の固定模試です。2010年問23はアプリから外し、制作資料をarchiveへ保管しました。回答済みの履歴は保持します。

2015問9・2018問17・2024問22は、利用者指定に従い当時のIPA公式正答で採点し、仕様上の注意を回答後の解説に常時表示します。原問の技術的一意性の解決やIPAの訂正を意味しません。[採点と解説の方針](docs/network-specialist/review-notes/historical-answer-policy.md)、[制作状況](docs/network-specialist/STATUS.md)、[収録表](docs/network-specialist/COVERAGE.md)、[旧調査履歴](docs/network-specialist/HELD.md)、予想のレビュー[第1回](docs/network-specialist/review-notes/2026-pred-01.md)・[第2回](docs/network-specialist/review-notes/2026-pred-02.md)・[第3回](docs/network-specialist/review-notes/2026-pred-03.md)を参照。教材の完成版検証は通過済み。制作内AIレビューを独立専門家校閲とは称しません。本番設定と審査提出を実施済みで、初回ビルドのITMS-91064は修正済み。課金商品を取得できなかった1.0（2）の却下後、300円の買い切り価格・有料アプリ契約・銀行・税務情報を整え、購入再取得を改善したビルド3と同商品を再提出しました。ビルド3は審査を通過し、利用者が手動公開。2026-10-15にApp Store掲載を確認しました。AdMobへのストア連携は完了しましたが、Googleのアプリ確認がapp-ads.txtの照合で止まり、広告配信は制限中です。[公開・申請状態](docs/release/submission-status.json)。返金・VoiceOver・一部の実機検証は未確認です。

## 体験と技術選定

- ホーム: 相棒と**定着率・学習済み件数・要復習件数**をコンパクトなカードにまとめます。3区分は利用できる問題だけを対象にし、母数を明示。その下の「今日の学習」ボタンで、復習の優先順に選んだ10問（科目Bは2問まで）を1タップで始められ、復習・新しい問題の内訳を表示します。途中再開の操作はありません。6カードから年度別・分野別・苦手問題・ブックマーク・Lv別小テスト・学習記録へ。ホームの相棒を112ptへ拡大し，相棒・詳しく見る・学習記録カードはいずれも通常のページ遷移で同じ記録画面を開きます。
- 演習: 下部の5タブから学習にアクセス。年度は2列カードで無料／有料・問題数・進捗を表示し、無料問題のない年度は購入画面へのロック入口にします。混在年度では無料問題のみ表示。年度内は分野で分類し、一括出題は「模擬試験」だけ。完全な公式セットは従来の固定模試、部分年度は収録問題の時間制限付き演習です。分野別は関連テーマをつないだマップから一覧へ進みます。NWの細かなカテゴリは最大6テーマに集約し、教材の分類自体は保持。拡大・移動に対応し、最大文字設定ではテーマを縦に表示。小テストは問題の既存難易度をLvにし、最大5問を出題します。
- 出題順: 苦手問題・ブックマーク・分野別の「問題を解く」から「順番に解く／ランダムに解く」を選びます。未回答のみのフィルターと問題検索は提供しません。どちらの順序でも最後は問題一覧へ戻ります。
- 回答: 一覧で選んだ問題から次の問題へ進め、最後は「問題一覧へ戻る」。回答後も自信度を変更でき、同じ回答を更新して習熟度を再計算します。選択状態は塗りつぶし・チェック・太字で区別。解き方は答え合わせ後に全ステップを表示。中断・再起動時は途中の出題位置と模試の未採点選択を削除し、回答済みの学習記録は保持します。
- Recall First: おすすめ/復習では選択肢を見る前に一度想起。年度別・模試・診断では無効。任意の自信度、同じ誤選択肢の繰り返し、自信ありの誤答から危険な思い込みを検知します。
- 記録: 「学習記録」に学習状態・相棒の成長とリアクション・カレンダー・日別／全件回答履歴・模試成績を統合。準備度は従来の問題集全体の総合計算を保持し、定着率は利用可能な問題を対象にします。全件履歴の新しい順／古い順に対応。相棒専用の別ページは設けません。
- 記憶と学習: ホーム・設定の「記憶と復習のしくみ」と、記録の「学習指標の見方」を同じ説明ページへ統一。想起練習・分散学習・答え合わせ・使い方・指標・研究の限界を解説します。手順図、切替可能な模式グラフ、練習日の配分図、3区分の例、準備度の配点図を使用。本文は読みやすいサイズと行間を確保し、目次から章へ移動できます。記録からは指標の章へ直接移動。出典5件と、研究結果／アプリ独自のルール／未検証の効果を区別します。
- デザイン（ピヨポップ）: 全資格で共通の見た目です。クリーム色の地（#FFF9EB）・焦げ茶の文字・白いカードに下辺の影、ピヨの黄色（#FFC83D）の「ぷっくり」主ボタン（押すと5pt沈む）、丸ゴシック（`.fontDesign(.rounded)`。問題本文は標準書体）。正解は緑・不正解はオレンジで明度も変え、必ず ✓ / × を添えます。資格ごとの差は`accentHex`（リンク・チップ）と`theme`の状態色（positive / review / growing）だけに使い、`theme`の背景・カード・境界・補助文字の値は読み込みのみで適用しません。部品は`Views/Design.swift`の`Palette`・`Surface`・`popCard`・`PuffyButtonStyle`・`SessionProgressBar`・`FeatherBurst`。たたき台とデザイン案は`design-system/piyo-pop/`。
- あしあと・はね: ホーム上部に連続学習日数（あしあと）と、正解10・不正解2で貯まる「はね」を表示。週1日まで休んでも連続が切れない「おやすみ券」付きで、今日まだ解いていなくても昨日までの連続は消えません。相棒のまわりのリングが今日の目標10問の進み具合、「今週のあしあと」が月〜日の学習日です。いずれも回答履歴から計算し、保存データは増やしません（`Core/AnswerHistory.swift`の`StudyMomentum`）。
- 演出: 選択時に軽い触覚、正解で成功の触覚と羽根の紙吹雪、不正解で控えめな触覚と選択肢の小さな揺れ。進捗は1問ずつのセグメントで、2問以上の連続正解に「れんぞく！」チップ。結果画面には獲得したはねと、今日初めての学習ならあしあと「+1」。模試は採点まで正誤を示す演出を出さず、視差効果を減らす設定では動きを止めます。
- レビュー依頼: 診断・模試以外で5問以上・正答率70%以上の学習を終えてホームへ戻ったとき、学習日が3日以上あれば`requestReview`を呼びます。間隔は端末内で120日以上空け、インタースティシャル広告を出した直後とUIテスト起動時は出しません。
- 収益化: 無料問題は何度でも利用可。無料ユーザーにはホーム・問題一覧・記録・セッションの**結果画面だけ**に広告を配置。全問題解放は資格アプリ固有の**非消耗型**IAPで、購入と同時に広告も永久に削除。サブスクリプションはありません。

**Swift / SwiftUI（iOS 17+）/ StoreKit 2 / Google Mobile Ads 13.11.0 / Google UMP 3.1.0 / Codable / XCTest**を採用。Googleの公式Swift PackageはSwiftUI `UIViewRepresentable`・Privacy Manifestに対応し、広告SDKへの依存は`Ads/AdMobProvider.swift`だけに閉じ込めます。iPhone・App Store優先で、Apple標準のDynamic Type、ダークモード、VoiceOver、決済を使います。AndroidはUI層・広告/課金層を作り直す必要がありますが、JSON問題集と学習計算は移植できます。AIは不要と判断し導入していません。正答・解説のSource of Truthはレビュー済みのJSONです。

## ディレクトリと責務

```
project.yml                   XcodeGen定義。QualificationAppテンプレートと各アプリの設定
MyApp.swift / ContentView.swift 起動・資格ID読み込み・各画面への入口
Core/Models.swift             資格/問題/回答のスキーマと問題集の厳格な検証
Core/QuestionContent.swift    構造化本文・画像・表・数式と参照の検証
Core/MockExam.swift           固定模試・絶対期限・復元・未回答を含む一括採点
Core/MasteryEngine.swift      記憶状態の更新と統計・学習準備度
Core/SessionPlanner.swift     おすすめ/診断/混同学習/模試の問題選択
Core/QuestionCollections.swift 年度・科目・カテゴリ・習熟状態の共通リストと並び順
Core/StudyStore.swift         回答・状態・ブックマーク・模試の端末内永続化
Core/PurchaseManager.swift    StoreKit 2の取得/購入/復元/権限判定
Core/AdsService.swift          SDK非依存の広告表示権限/頻度制限/保存・AdProviderプロトコル
Ads/AdMobProvider.swift        Google Mobile Ads/UMP/ATTの唯一のアダプター
Views/AdBannerPlacement.swift  無料ユーザー用のアダプティブバナー
Views/QuestionCollectionView.swift 共通問題リストと出題メニュー
Views/QuestionContentView.swift 複数図版・ピンチ拡大・構造化表・全選択肢の解説
Views/MockExamView.swift       模試の自由移動・回答変更・一括採点・成績詳細
Views/PrivacyDetailsView.swift  保存・広告・購入説明と学習情報リセット
Views/ExamDateEditor.swift     ホーム/設定共通の試験日設定・解除
Views/LearningGuideView.swift  研究・メリット・図解・指標の読み方をまとめた共通説明
Views/Mascot/                  原案のベクター描画・成長・記録内の相棒
Core/TankeiIdentity.swift      成長判定・ノルマ・状態別セリフ
Core/TankeiMotion.swift        待機モーションと20種類の自動アクション
Core/AnswerHistory.swift       全回答の日付グループと新旧の並べ替え
Views/                      診断/ホーム/問題を探す/演習/記録/設定/購入
Qualifications/<id>/          qualification.json / questions.json / products.storekit / Figures/
Assets.xcassets/              アプリ別アイコンと色
Config/                       XcodeGenが生成するアプリ別Info.plist
Tests/ / UITests/             学習・統計・保存・StoreKit・初回起動の検証
NetworkTests/ / NetworkUITests/ NW教材・固定模試・専用購入・図版の検証
docs/network-specialist/      原本URL/ハッシュ・校合台帳・収録漏れ・実進捗
tools/network-specialist/     原本取得・図切出し・レビュー固定・教材検証
tools/GenerateIcon.swift      資格設定からチキンの顔＋資格名の1024pxアイコンを生成
tools/GenerateMascot.py       保存した原案から描画パーツと参照SVGを生成
```

UI、出題計画、習熟計算、端末保存、決済、広告は別ファイルです。差し替え可能な純粋計算を`MasteryEngine`/`SessionPlanner`にまとめました。問題バンクはアプリに読み取り専用で同梱し、問題IDを履歴の永続キーとします。アプリごとのバンドルには**そのターゲットの資格JSONのみ**を含めます（共有のアイコン用アセットカタログを除く）。`.storekit`は開発Schemeとテストで参照し、アプリのリソースにはコピーしません。

## 動かし方・ビルド・テスト

### ブランドキャラクター

ユーザー原案のひよこ／チキンSVGを部位別のSwiftUI描画に使用。利用可能な問題の**定着率と学習準備度**から内部で成長を算出し、ひよこ → 育ちざかり → 若鶏 → チキンに成長。成長の％・計算式・あと何問はユーザーに表示しません。途中は姿を変えず、学習終了後に「成長したよ！」画面で披露します。無料・模試なしでも最後まで育ち、誤答・時間経過・問題追加で獲得済みの姿は戻りません。ホーム・問題探しでは176pt、回答後は120ptで反応。待機中は呼吸に**20種類のアクション**を状態別にランダムで重ね、同じ動きを連続させません。相棒ページは日付ラベルの下にその日の全回答を並べ、既定の「新しい順」と「古い順」を切り替えられます。回答をタップすると問題を開き、閉じると相棒ページへ戻ります。問題文右上・模試中には置かず、画面外・Reduce Motion・省電力では停止します。[キャラクター設計](design-system/exammaster/mascot/README.md)、ビジュアル一覧は `design-system/exammaster/mascot/preview.html`。`python3 tools/GenerateMascot.py` でSVG・ネイティブPath・アイコン用の顔パーツを生成し、`--check` で整合性を検証できます。原案ファイル・輪郭・復習計算は変更せず、チキンのクリーム色の部位だけを資格設定から差し替えます。

### アイコンと資格ごとの色

`Qualifications/<id>/qualification.json` の `name` が資格名、任意の `brandName` がシリーズ名です。アプリ内の表示名は`brandName + name`で組み立て、ホームではブランドと資格名を2行にします。未指定なら従来の資格名のみ表示。`project.yml`の`displayName`とApp Storeの販売名も同じ全文にそろえてください。アイコンは資格名または`iconTitle`を使います。`mascotBaseHex` がチキンのベースカラーです。未指定なら原案の `#FFF3DA`。アプリ内の若鶏／チキンの全画面と、アイコンの顔に共通で反映します。ひよこは `chickBaseHex` の未指定時に原案色を使い、顔の細部・輪郭は原案色を維持します。アイコンはピヨポップ共通の黄色地に相棒の顔と白いラベルを置き、ラベルの下端（ぷっくりした影）だけを `accentHex` にして資格を見分けます。ラベルは1行が読みやすいので、長い資格名は `iconTitle` に短縮名（例: 基本情報、ネスペ）を指定してください。`\n` で2行も可能です。

```sh
python3 tools/GenerateMascot.py
swift tools/GenerateIcon.swift Qualifications/demo-safety/qualification.json Assets.xcassets/AppIcon.appiconset/AppIcon.png
swift tools/GenerateIcon.swift Qualifications/demo-safety/qualification.json Assets.xcassets/AppIcon.appiconset/AppIcon.png --check
```

`chickBaseHex` でひよこの体・羽のベース色も変更できます。未指定の場合は原案の黄色を維持します。任意の `theme` で背景・カード・境界・補助文字・学習状態の色をライト／ダーク別に変更でき、未指定の資格は従来の配色を維持します。応用情報版の設定が実例です。

名前や色の変更後はビルドするだけでアイコンも自動再生成します（iOSのホーム画面アイコンはビルド時の画像です）。上のコマンドは手動プレビューと整合性確認用。別資格でもスクリプトやSwiftUIコードの編集は不要です。

macOS、Xcode 27、iOS Simulator、[XcodeGen](https://github.com/yonaskolb/XcodeGen)を使用。生成済み`ExamMaster.xcodeproj`も同梱しています。Swiftソースやターゲット追加後は再生成してください。

```sh
xcodegen generate
xcodebuild -resolvePackageDependencies -project ExamMaster.xcodeproj -scheme ExamMaster
xcodebuild -project ExamMaster.xcodeproj -scheme ExamMaster -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ExamMaster.xcodeproj -scheme ExamMaster -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
xcodebuild -project ExamMaster.xcodeproj -scheme NetworkSpecialist -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
```

XcodeでSchemeを選びRunするとサンプル商品設定が自動的に読み込まれます。CLIから起動する場合は、`xcrun simctl list devices available`でUDIDを調べ、`xcrun simctl boot <UDID>`、`xcrun simctl install <UDID> <ビルドした.appのパス>`、`xcrun simctl launch <UDID> <Bundle ID>`の順に実行します。CLIの`simctl launch`だけではXcodeのローカルStoreKit商品設定は適用されないため、商品価格確認にはXcodeのRunまたはStoreKitTestを使います。

両Schemeのビルド・テストは**順次実行**してください。同じDerivedDataのビルドDBで並行実行するとロック競合になることがあります。NWの開発商品は専用の非消耗型500円です。App Store Connectの税込500円設定・Sandbox/TestFlightは別途必要です。`-UITestResetStudy -UITestDisableAds -UITestSeedFixedMock`はDebug限定の10問途中模試を投入します。これは公式年度別25問セットではありません。

NWの購入権限は`StoreKitTest`のローカル検証済み取引で確認します。対象は有料年度のロック・購入後開始・取引消去後の再ロック・2026年予想固定模試です。過去に実施した2010年問23の図版確認は旧版の検証記録であり，同問は現在のアプリには収録しません。広告無効のUI試験を購入後の広告SDK停止やSandbox/TestFlightの確認済みとは扱いません。

テストは純粋な学習計算、資格の整合性、既存履歴の読み込み、途中位置の削除・学習記録の保持・リセット、問題リストの絞り込み/順序、5桁件数の履歴統計、相棒の成長保存・20アクション・日付別履歴、StoreKitTestでの**実購入・復元・取引消去**、広告権限と頻度制御（SDKを使わないFake Provider）、UIテストの診断・一覧からの単問/順番・ランダム演習・中断・プライバシー画面・模試・広告同意・学習ガイドの図と指標・最大文字と横向きを対象にしています。最新の確認範囲と画面は[検証記録](design-system/exammaster/mascot/VERIFICATION.md)を参照。UIテスト用`-UITestResetStudy`はDebug専用で学習データを初期化し、同時指定の`-UITestSeedCompanionHistory`で日付別履歴のテストデータを作成。`-UITestDisableAds`は同意画面を不要とする学習導線のテストに使用。広告を有効にしたDebugビルドでも**常にGoogle公式テスト広告ID**しかリクエストしません。

## 新しい資格アプリを追加する

シリーズ版は資格設定に`"brandName": "ピヨトレ！"`を指定し、`name`に「応用情報技術者」「システムアーキテクト」など資格名のみを設定します。アプリ内の表示名は共通コードで組み立てます。`project.yml`の`displayName`とApp Store Connectの名前は、同じ「ピヨトレ！＋資格名」に設定します。

正式なポリシー本文は各資格の`PrivacyPolicy.txt`に保存し、`project.yml`の`privacyPolicyPath`で同梱する文書を指定します。ネットワーク版は資格フォルダの正式本文、架空資格デモはルートのサンプル本文を使用。資格JSONの`privacyPolicyURL`には、そのアプリ専用の公開ページURLを指定します。

1. `Qualifications/<新しいid>/`を追加し、既存の`qualification.json`・`questions.json`・`products.storekit`を複製して**すべて資格専用に編集**。`id`とフォルダ名を一致させ、`productID`とStoreKit設定/後述のApp Store Connectの商品IDを一致させます。
2. `Assets.xcassets/AppIcon.appiconset/Contents.json`を`Assets.xcassets/<新しいIcon名>.appiconset/Contents.json`へ複製し、`swift tools/GenerateIcon.swift Qualifications/<新しいid>/qualification.json Assets.xcassets/<新しいIcon名>.appiconset/AppIcon.png`で生成。資格名とチキンの色はJSONだけで指定できます。公開前にキャラクターの権利も確認してください。
3. `project.yml`の`targets:`へ以下を追加。`QualificationApp`テンプレートがSwiftソース・その資格だけの問題集・Info.plist・アプリアイコンを組み立てます。

   ```yaml
   MyNewExam:
     templates: [QualificationApp]
     templateAttributes:
       qualificationID: my-new-exam
       privacyPolicyPath: Qualifications/my-new-exam/PrivacyPolicy.txt
       displayName: ピヨトレ！新資格名
       bundleID: jp.yourcompany.mynewexam
       iconName: MyNewIcon
       adMobAppID: ca-app-pub-3940256099942544~1458002511 # 開発用サンプル。公開時は自分のアプリIDへ変更
     scheme:
       storeKitConfiguration: Qualifications/my-new-exam/products.storekit
   ```

4. `xcodegen generate`、`xcodebuild -scheme MyNewExam ... build`で生成。`Config/MyNewExam-Info.plist`は自動生成。起動して資格名・無料/有料数・診断・模試・価格・復元と広告を確認。公開時は署名チームと実際のBundle ID・AdMobアプリIDを設定します。

`qualification.json`の設定項目: `id`（変更しない永続キー）、`name`・`subtitle`・`examNote`、`examMinutes`、`mockQuestionCount`、`passingPercent`、`minimumSubjectPercent`、`subjects`（科目名配列）、`freeQuestionIDs`（無料IDの明示リスト）、`productID`、`accentHex`（`#RRGGBB`）、`mascotBaseHex`（任意、チキンのベースカラー、`#RRGGBB`）、`iconTitle`（任意、アイコン用の短縮名。未指定なら`name`）、`privacyPolicyURL`（公開時にHTTPS URLを設定、架空サンプルは`null`）、`ads`（下記）。アプリ名/Bundle ID/アイコン/AdMobアプリIDは`project.yml`のターゲット属性で指定します。価格は**資格の`products.storekit`（開発）およびApp Store Connect（公開）**の同一商品IDで設定し、アプリはStoreKitから表示します。無料範囲を変更するだけなら`freeQuestionIDs`を編集してください。診断が偏らないよう各科目2問程度を無料範囲に含めることを推奨します。

## 広告の設定と運用

Google Mobile Ads 13.11.0（AdMob）とGoogle User Messaging Platform（UMP）3.1.0を公式Swift Packageから取得します。前者はアダプティブバナー/インタースティシャル、後者は地域別の同意画面と設定変更用のフォームです。広告は**無料ユーザーのみ**ホーム・問題を探す・記録・連続演習の結果・共通問題リスト（メニューの後と末尾）に配置し、問題文・回答・解説・模試中には表示しません。結果画面で「学習を終える」を押した**後**にだけインタースティシャルを検討します。単問・診断・途中中断・短いセッションは対象外です。Rewarded Adsは採用していません。

資格ごとの`qualification.json`内の設定例（`ads`）:

```json
{
  "enabled": true,
  "bannerEnabled": true,
  "interstitialEnabled": true,
  "interstitialMinimumIntervalSeconds": 1800,
  "interstitialMinimumSessions": 3,
  "interstitialMinimumAnsweredQuestions": 8,
  "adMobAppID": "ca-app-pub-3940256099942544~1458002511",
  "bannerAdUnitID": "ca-app-pub-3940256099942544/2435281174",
  "interstitialAdUnitID": "ca-app-pub-3940256099942544/4411468910"
}
```

`enabled: false`なら広告リクエストを行いません。`bannerEnabled`/`interstitialEnabled`は独立して切り替え可能で、対象ユニットを無効にする場合そのIDは空文字でも構いません。無料範囲は`freeQuestionIDs`で定義。買い切り商品は`productID`で定義し、**広告削除用の別課金商品はありません**。設定検証ではインタースティシャルの最短間隔600秒以上、最低2セッション・各5問以上を要求します。サンプルは30分かつ3セッション・各8問以上。表示回数と最終表示日時は`Application Support/ad-frequency-<資格id>.json`へ原子的に保存し、読み書き失敗時は全画面広告を止めます。ロード失敗・未同意・オフラインでも学習と買い切り購入に影響しません。

`Core/AdsService.swift`が購入権限の確定後に`AdProvider`を起動し、購入・復元時には広告ビューとロード済みインタースティシャルを破棄します。広告SDKを差し替える場合は`AdProvider`を実装し`StudyAppView`の生成箇所を変更します。SDKを呼ばないFake Providerでテストしています。

### テスト広告から本番広告へ

1. **開発・Simulator・自動テスト:** `#if DEBUG`でGoogleの公開テスト広告ユニット（上記）を強制します。資格データに本番IDを書いていてもDebugでは送信しません。Googleの[テスト広告ガイド](https://developers.google.com/admob/ios/test-ads)も参照。UIテストの一部は`-UITestDisableAds`で広告SDK自体を起動せず学習導線だけを検証します。テスト中に本番広告をクリックしないでください。
2. **本番化:** 資格ごとにAdMobアカウントで独立したiOSアプリを登録し、アプリIDを`project.yml`の該当ターゲットの`adMobAppID`**および**その資格の`qualification.json`の`ads.adMobAppID`へ設定。バナー/インタースティシャルの専用広告ユニットIDを`bannerAdUnitID`・`interstitialAdUnitID`に登録。設定IDと生成後のInfo.plistの`GADApplicationIdentifier`が一致しないと起動時にエラーになります。
3. **Release/TestFlight:** ReleaseでGoogleのサンプルアプリIDや有効な広告枠のサンプル広告ユニットIDが残っていれば`AdsService`は**広告の初期化・リクエストを停止**します。実IDへ入れ替え、`xcodegen generate`とReleaseビルドで切り替えてください。アプリIDと広告ユニットIDは別物（`~`と`/`）です。AdMobアプリ審査・販売地域・[app-ads.txt](https://developers.google.com/admob/ios/app-ads)等の配信設定も確認してください。

### 同意・プライバシーとATT

無料版でのみStoreKitの検証済み購入状態を確認してからUMPの同意情報を更新し、必要なフォームを表示します。UMPの`canRequestAds`が真になるまで広告SDKを初期化・広告をリクエストしません。前回の同意が残る場合は、更新通信に失敗してもUMPの判定を尊重。フォームが必要な地域ではAdMobの**Privacy & messaging**でメッセージを作成し、日本語・配信地域・パートナーを管理してください。設定タブにUMPがプライバシー設定の変更を要求する場合、その再表示ボタンが現れます。広告を許可しなくても無料問題は使えます。

トラッキングが許可される可能性のある広告を扱うため、UMPのフォーム処理後にAppleのATT許可状態を確認し、未確認ならシステムの許可ダイアログを提示します。UMPでIDFA事前メッセージとATTをすでに提示済みの場合は重複提示しません。**拒否しても学習を制限せず、Googleの仕様ではIDFAは広告リクエストに含まれません。**購入済みユーザーには同意・ATT画面も広告リクエストも開始しません。サンプルAdMobアプリIDではGoogleの英語テスト用IDFAメッセージが表示されることがあります。本番はAdMob管理画面で対象地域に合わせた日本語メッセージを設定してください。

アプリの`PrivacyInfo.xcprivacy`に加え、Google両SDKも独自のPrivacy Manifestを持ちます。SDKの[データ開示](https://developers.google.com/admob/ios/privacy/data-disclosure)では概算位置、デバイスID、広告閲覧/操作、クラッシュ/パフォーマンス等が挙げられています。App Store ConnectのApp Privacy回答と[PRIVACY.md](PRIVACY.md)を各資格の利用実態に合わせて更新し、XcodeのPrivacy Reportで両SDKのマニフェストを確認してください。`NSUserTrackingUsageDescription`、Googleの`SKAdNetworkIdentifier`（`cstr6suwn9.skadnetwork`）は`project.yml`からInfo.plistに生成します。追加広告ネットワークを使うときは公式の最新SKAdNetwork IDも追加します。広告SDK更新・メディエーション追加時は収集データ・ATT・[GDPR/EEA/UK/スイス](https://developers.google.com/admob/ios/privacy/gdpr)と米国州別同意設定も再点検してください。

地域別フォームの検証は[UMP公式のテスト端末登録と強制地域指定](https://developers.google.com/admob/ios/privacy#testing)を使用します。開発端末のUMPログに出るハッシュ値を`DebugSettings.testDeviceIdentifiers`に登録し、`geography = .EEA`等を**開発中のみ**`RequestParameters.debugSettings`へ指定してください。初回同意の再現には開発時のみ`ConsentInformation.shared.reset()`が使えます。本番へ出す前にテスト端末ID/強制地域/リセット処理が混入していないことを確認します。Simulatorでの広告クリックを含む手動確認も必ずGoogleのテスト広告IDに限ってください。

## 問題の追加と更新

`Qualifications/<id>/questions.json`に問題を追加。既存の`version: 1`はそのまま読み込めます。構造化表示・固定模試を使う教材は`version: 2`にします。基本の問題形式は以下です。

```json
{
  "id": "stable-0001", "year": 2025,
  "subject": "科目名", "category": "カテゴリ名",
  "stem": "設問", "choices": ["選択肢A", "選択肢B", "選択肢C"],
  "correctIndex": 1, "explanation": "根拠を含む解説",
  "source": "出典・年度・設問番号・許諾の確認先", "questionNumber": 1,
  "imageName": null, "difficulty": 2,
  "tags": ["計算"], "concepts": ["比較する概念"],
  "steps": ["何を求めるか確認", "式を立てる", "結果を検算"]
}
```

選択肢は2〜16件（基本情報の科目Bには10肢の原問あり）、`correctIndex`は**0始まり**、難易度は1〜5。`choiceLabels`を指定する場合は最大の選択肢数以上のラベルを設定します。旧形式の画像はアセットカタログの名前を`imageName`に指定、不要なら`null`。`steps`は答え合わせ後に全手順を表示する解説で、不要なら`null`。`questionNumber`は年度別リストの本来の問番号（任意、既存サンプルは`source`の「問1」等から補完）。`concepts`は問題の概念を表します。`tags`と`category`は分類・演習用です。問題IDは更新後も維持し、削除・再利用すると既存履歴との関連が失われるため、履歴移行を伴う変更として扱います。

### version 2の構造化表示と固定模試

- `bodyBlocks`は本文の表示元。指定時も`stem`は一覧用の全文を保持します。
- `choiceBlocks`は`choices`と同じ件数・順序のブロック配列。`choices`も一覧・読み上げ用に保持します。
- `explanationBlocks`は解説補足、`choiceExplanations`は全選択肢それぞれの理由です。
- ブロックの`type`は`text`、`image`、`table`、`monospace`、`formula`。画像は`assetName`（`Figures/`内のPNG名）と`altText`、表は`headers`と列数が一致する`rows`、文字系は`text`が必須です。画像は白地のまま拡大表示できます。
- 問題の`kind`は`past`/`prediction`、`administration`は`spring`/`autumn`/`prediction`、`mockSetID`は安定したセットIDです。
- バンクの`mockSets`に`id`・`title`・`kind`・明示順の`questionIDs`・`questionCount`・`minutes`を設定します。部分年度は公式25問模試として登録しません。
- 資格設定の`choiceLabels`はNWなら`["ア","イ","ウ","エ"]`。未指定の旧教材はA/B/Cを維持します。`usesFixedMocks: true`で固定模試入口を使い、`mockPassTitle`で基準点到達の表示を設定、`contentCredit`で権利・独自解説・表示調整を明記します。
- `isDraft: true`は開発途中を示し、問題数の不足を許容します。模試の構成検証やリリースの完了条件を緩めるものではありません。

実例とNW専用JSON Schemaは`Qualifications/network-specialist/questions.json`と`tools/network-specialist/questions.schema.json`にあります。NW教材の編集元は`docs/network-specialist/content/<年>.json`です。原本との校合・技術レビュー後のみ`freeze_reviews.py --accept-reviewed-content`で本文・図版内容のハッシュを固定し、`assemble_bank.py --write`で同梱JSONと無料IDを再生成します。未承認・保留・ハッシュ不一致・不完全模試は生成時に拒否します。ハッシュ固定はレビューの代替ではありません。検証は`.venv-network/bin/python tools/network-specialist/validate.py`、完成版ゲートは同コマンドに`--release`を追加します。現在の375問教材は完成版ゲートを通過しています。制作ツールの回帰は`.venv-network/bin/python -m unittest discover -s tools/network-specialist -p 'test_*.py' -v`で実行します。

形式探索の記録は[原本形式調査](docs/network-specialist/FORMAT_SURVEY.md)に保存しています。`docs/network-specialist/candidates/`は未承認の草稿・図版の作業領域で、組立て対象でもアプリの同梱リソースでもありません。スキーマ検査や計算検算が成功しても収録済み件数には数えません。正式レビュー後にのみ`content/`と資格別図版へ移してください。

起動時に重複ID・科目・空の設問/解説/出典・正答の範囲・無料IDの参照先・銀行バージョンなどを検証し、不正な問題集はエラー画面を表示します。実際の国家資格では、公開されている過去問でも転載・画像・解説に必要な権利や利用条件を個別に確認し、法令改正と正誤表をレビューしてください。

## Adaptive Mastery Engine

[分散学習と想起練習のレビュー](https://www.psychologicalscience.org/publications/journals/pspi/learning-techniques.html)および[successive relearningの研究](https://pubmed.ncbi.nlm.nih.gov/29431462/)を設計上の参考にした**製品向けヒューリスティック**です。認知実験の成果をそのまま予測モデルと称するものではありません。

- 1問につき回答回数、日時、連続正解、異なる日の正解回数、回答時間、自信度（任意）、誤選択肢、記憶の安定期間を記録します。安定期間は別日の正答で大きく伸び、同日の再回答ではわずかしか伸びず、誤答で短くなります。難問・自信のない正答も控えめに更新します。時間と自信度は履歴に保存し、誤解の判定には自信度を使います。回答時間は記録・将来のモデル改良用で、現在の間隔計算には**使いません**。
- 忘却の目安 `exp(-経過日数 / 安定期間)`、復習日は目安が約0.8になる時点（誤答は翌日）。これは**実測の記憶確率ではありません**。安定記憶は異なる日で3回以上正答・安定期間7日以上・目安0.75以上・誤解なしを要件にします。
- 自信を持った誤答、または同じ誤選択肢を2回選んだ問題を危険な思い込みとし、優先出題。別の問題と概念タグを共有するものを混ぜて混同学習。2連続正解で思い込みフラグを解除します。
- 今日のおすすめは誤解→誤答→復習期限→新規→学習中→安定記憶の順を基調に、同科目の過剰出題を減点し、並べ替えでも科目を交互にします。何度も同日の簡単な問題だけを解く行為をMastered扱いしません。
- 学習準備度（0〜100）は既習率20%、分野別の記憶目安34%、最弱科目14%、直近14日の問題ごとの最終回答12%、直近模試20%（90日で徐々に減衰）です。**合格確率ではなくこの問題集内の学習目安**。実際の合格を保証しません。各資格の模試基準は資格設定から計算します。

将来の係数調整は`Core/MasteryEngine.swift`とテストで行い、問題データ/画面から独立させています。より精緻なモデルには同意の下での実データに基づく校正が必要です。

## 永続化・課金と公開準備

`Application Support/study-<資格id>.json`に`StudyData(schemaVersion: 1)`を原子的に保存。回答履歴・Mastery・模試成績・ブックマーク・診断済み/設定・試験日を保持します。通常演習は途中位置を保存しません。模試は受験中のみ絶対期限・現在位置・未採点の選択を保存し、中断・アプリ再起動で削除。採点済みの結果と回答は残ります。採点のUUIDで重複確定を防ぎ、結果・実回答のMastery更新・途中模試消去を一度の原子的書込みで確定します。未回答は失点と結果だけに残し、回答履歴・習熟度を変更しません。有料問題は一覧に本文を出さず、開始と解説閲覧でも購入権限を確認します。試験日は暦の年月日として保存。旧バージョンの保存データは新項目を補って読み込みます。読み込みに失敗した場合は元のファイルを**上書きしない読み取り専用状態**にし、保存失敗は画面で再試行できます。問題集はアプリ同梱でオフライン使用可。現状は端末間同期・バックアップの保証はなく、アプリ削除で履歴は消えます。将来のiCloud同期では`StudyStore`を差し替え、履歴と安定IDを移行してください。

試験日の追加・変更・解除はホーム最上部または設定の「受験予定」から行います。設定はホーム・年度別・分野別・学習記録の右上歯車から開きます。「データとプライバシー」には端末保存・広告・購入の説明と正式なポリシーへのリンクを設置。サンプルには`PrivacyPolicy.txt`を同梱します。学習情報リセットは回答・Mastery・模試・お気に入り・診断・途中演習・試験日を削除し、初回診断を再案内します。Recall First・StoreKit購入権限・UMP同意・広告の頻度履歴は維持します。旧ランダム設定の保存フィールドは読み込み互換のため残し，UIでは使いません。公開時は資格ごとの`privacyPolicyURL`を実際の公開URLへ設定してください。

購入権限は端末内の任意のフラグではなく、StoreKit 2の**検証済み・取消なし・商品ID一致・非消耗型**の`Transaction.currentEntitlements`から取得。購入時に取引を完了し、`Transaction.updates`で変更を反映。復元ボタンは`AppStore.sync()`後に権限を再確認します。購入済み端末ではStoreKitのローカル権限によりオフラインで使用でき、広告も非表示。未購入/商品読み込み失敗/承認待ち/復元なしを区別して表示し、無料問題は使い続けられます。ローカルの`.storekit`は**開発時のみ**の設定で、公開商品の価格・IDはApp Store Connectに登録します。

公開する資格ごとに行う作業:

NWの最新の申請手順・必要情報・375問完成を条件にした公開方針と、自動検査/Archive/アップロード/撮影コマンドは[公開申請の準備](docs/release/README.md)を参照してください。

1. 正式な問題・解説・画像/出典・法令更新と権利確認、専門家校閲。架空資格の名称/説明を実資格へ変更し、設定した試験時間・合格基準が正しいことを確認。
2. Apple DeveloperのTeam、独立Bundle ID、署名、アプリ名/1024pxアイコン、バージョン/ビルド番号を設定。`jp.example`の識別子を置換。
3. App Store Connectで**Non-Consumable**商品を作り、同一`productID`、販売地域・価格・説明・審査用スクリーンショットを設定。Sandbox/TestFlightで新規購入、キャンセル、保留、復元、オフライン、返金後の失効を確認。
4. 資格ごとのAdMobアプリ・広告枠、Google UMPの対象地域向け同意メッセージ、プライバシー設定への導線、実ID、必要なSKAdNetwork/app-ads.txt設定を用意し、ReleaseでサンプルIDが残っていないことを確認。出稿・メディエーションを加える場合はパートナーの開示と同意設定も更新。
5. [プライバシーのひな型](PRIVACY.md)を運営者情報に合わせて正式なURLで公開し、AdMob/UMPを含むApp Store ConnectのApp Privacy回答・サポートURL、スクリーンショット、販売用説明、コンテンツ権利情報、審査用の操作説明を提出。必要な手続き・契約を完了。
6. 実機と最新/最小対応iOSでライト/ダーク、Dynamic Type、VoiceOver、バックグラウンド復帰、同意あり/なし、購入前/後/復元/返金後、広告ロード失敗、ストレージ不足、通信なし、長時間の模試を確認。`xcodebuild -project ExamMaster.xcodeproj -scheme <Scheme> -configuration Release -destination 'generic/platform=iOS' archive -archivePath <保存先>.xcarchive`で署名付きArchiveを作成して申請。

サンプルの`.storekit`と問題は開発・動作確認用です。ストア公開には各資格ごとの実データ・Apple Developerの署名/商品登録/審査が必要です。
