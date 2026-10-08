# 資格学習シリーズ / ExamMaster

**iPhone向け・無料＋広告／買い切り型のWhite Label試験対策アプリ基盤。** 1つのSwiftUIコードベースから、資格ごとに異なるBundle ID・表示名・テーマ・アイコン・問題集・無料範囲・StoreKit商品・広告ユニットを持つ独立アプリを作ります。アカウントやバックエンドは不要です。

現在の2つの独立したビルドターゲット:

| Scheme | 資格 | Bundle ID | 問題 / 無料 |
| --- | --- | --- | --- |
| `ExamMaster` | 設備安全管理士（架空） | `jp.example.exammaster.demo` | 32 / 12 |
| `HarborStudy` | 港湾安全記録士（架空） | `jp.example.exammaster.harbor` | 12 / 6 |

**両資格とも架空の教材です。実在する国家資格を扱うには、問題・解説・出典・試験基準の調査と転載許諾等を済ませて差し替えてください。** `jp.example`のBundle IDや商品IDを使ったままストアへ申請しないでください。

## 体験と技術選定

- ホーム: 試験日と「今日のひと区切り」。少なめ（最大5問）／いつもの量（最大12問）を自分で選択し、選択を端末に保存。初期値は少なめです。復習タイミングは「今」「明日」などと件数で表示し、定着／学習中／これからの3区分を記憶バーで確認できます。中断中の演習は「続きから」で再開。計算と出題の優先順位は従来通りです。
- 演習: 「問題を探す」で年度・科目・カテゴリ・苦手・お気に入りなどを選ぶと共通問題リストへ進みます。リスト内検索、単問、表示中の全問を順番に回答、未回答だけ／ごちゃまぜのランダム出題に対応。単問は解説後にリストへ戻り、連続演習は結果画面へ。模試は時間制限、全体と科目ごとの基準判定、終了後の問題別復習。
- Recall First: おすすめ/復習では選択肢を見る前に一度想起。年度別・模試・診断では無効。任意の自信度、同じ誤選択肢の繰り返し、自信ありの誤答から危険な思い込みを検知します。
- 記録: 学習準備度のリング（合格確率ではない）、学習日カレンダー、科目別の定着度バー、模試得点の推移、日付別と全件の回答履歴。研究の根拠と推定の限界は「記憶と復習」から確認できます。初回の忘却曲線は学び方のイメージであり、個人の実測値ではありません。
- 収益化: 無料問題は何度でも利用可。無料ユーザーにはホーム・問題一覧・記録・セッションの**結果画面だけ**に広告を配置。全問題解放は資格アプリ固有の**非消耗型**IAPで、購入と同時に広告も永久に削除。サブスクリプションはありません。

**Swift / SwiftUI（iOS 17+）/ StoreKit 2 / Google Mobile Ads 13.11.0 / Google UMP 3.1.0 / Codable / XCTest**を採用。Googleの公式Swift PackageはSwiftUI `UIViewRepresentable`・Privacy Manifestに対応し、広告SDKへの依存は`Ads/AdMobProvider.swift`だけに閉じ込めます。iPhone・App Store優先で、Apple標準のDynamic Type、ダークモード、VoiceOver、決済を使います。AndroidはUI層・広告/課金層を作り直す必要がありますが、JSON問題集と学習計算は移植できます。AIは不要と判断し導入していません。正答・解説のSource of Truthはレビュー済みのJSONです。

## ディレクトリと責務

```
project.yml                   XcodeGen定義。QualificationAppテンプレートと各アプリの設定
MyApp.swift / ContentView.swift 起動・資格ID読み込み・各画面への入口
Core/Models.swift             資格/問題/回答のスキーマと問題集の厳格な検証
Core/MasteryEngine.swift      記憶状態の更新と統計・学習準備度
Core/SessionPlanner.swift     おすすめ/診断/混同学習/模試の問題選択
Core/QuestionCollections.swift 年度・科目・カテゴリ・習熟状態の共通リストと並び順
Core/StudyStore.swift         回答・状態・ブックマーク・模試の端末内永続化
Core/PurchaseManager.swift    StoreKit 2の取得/購入/復元/権限判定
Core/AdsService.swift          SDK非依存の広告表示権限/頻度制限/保存・AdProviderプロトコル
Ads/AdMobProvider.swift        Google Mobile Ads/UMP/ATTの唯一のアダプター
Views/AdBannerPlacement.swift  無料ユーザー用のアダプティブバナー
Views/QuestionCollectionView.swift 共通問題リストと出題メニュー
Views/PrivacyDetailsView.swift  保存・広告・購入説明と学習情報リセット
Views/ExamDateEditor.swift     ホーム/設定共通の試験日設定・解除
Views/                      診断/ホーム/問題を探す/演習/記録/設定/購入
Qualifications/<id>/          qualification.json / questions.json / products.storekit
Assets.xcassets/              アプリ別アイコンと色
Config/                       XcodeGenが生成するアプリ別Info.plist
Tests/ / UITests/             学習・統計・保存・StoreKit・初回起動の検証
tools/GenerateIcon.swift      サンプル用1024pxアイコン生成スクリプト
```

UI、出題計画、習熟計算、端末保存、決済、広告は別ファイルです。差し替え可能な純粋計算を`MasteryEngine`/`SessionPlanner`にまとめました。問題バンクはアプリに読み取り専用で同梱し、問題IDを履歴の永続キーとします。アプリごとのバンドルには**そのターゲットの資格JSONのみ**を含めます（共有のアイコン用アセットカタログを除く）。`.storekit`は開発Schemeとテストで参照し、アプリのリソースにはコピーしません。

## 動かし方・ビルド・テスト

macOS、Xcode 27、iOS Simulator、[XcodeGen](https://github.com/yonaskolb/XcodeGen)を使用。生成済み`ExamMaster.xcodeproj`も同梱しています。Swiftソースやターゲット追加後は再生成してください。

```sh
xcodegen generate
xcodebuild -resolvePackageDependencies -project ExamMaster.xcodeproj -scheme ExamMaster
xcodebuild -project ExamMaster.xcodeproj -scheme ExamMaster -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ExamMaster.xcodeproj -scheme HarborStudy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ExamMaster.xcodeproj -scheme ExamMaster -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
```

XcodeでSchemeを選びRunするとサンプル商品設定が自動的に読み込まれます。CLIから起動する場合は、`xcrun simctl list devices available`でUDIDを調べ、`xcrun simctl boot <UDID>`、`xcrun simctl install <UDID> <ビルドした.appのパス>`、`xcrun simctl launch <UDID> <Bundle ID>`の順に実行します。CLIの`simctl launch`だけではXcodeのローカルStoreKit商品設定は適用されないため、商品価格確認にはXcodeのRunまたはStoreKitTestを使います。

テストは純粋な学習計算、資格の整合性、既存履歴の読み込み、途中演習の保存・再開・リセット、問題リストの絞り込み/順序、5桁件数の履歴統計、StoreKitTestでの**実購入・復元・取引消去**、広告権限と頻度制御（SDKを使わないFake Provider）、UIテストの診断・一覧からの単問/ランダム/連続演習・再開・プライバシー画面・模試・広告同意を対象にしています。UIテスト用`-UITestResetStudy`はDebug専用で学習データを初期化し、`-UITestDisableAds`は同意画面を不要とする学習導線のテストに使用。広告を有効にしたDebugビルドでも**常にGoogle公式テスト広告ID**しかリクエストしません。

## 新しい資格アプリを追加する

1. `Qualifications/<新しいid>/`を追加し、既存の`qualification.json`・`questions.json`・`products.storekit`を複製して**すべて資格専用に編集**。`id`とフォルダ名を一致させ、`productID`とStoreKit設定/後述のApp Store Connectの商品IDを一致させます。
2. `Assets.xcassets/<新しいIcon名>.appiconset/Contents.json`と1024px PNGを用意。架空サンプル用のアイコンなら `swift tools/GenerateIcon.swift Assets.xcassets/<新しいIcon名>.appiconset/AppIcon.png '#365783'`。実アプリでは独自のデザインと権利を確認してください。
3. `project.yml`の`targets:`へ以下を追加。`QualificationApp`テンプレートがSwiftソース・その資格だけの問題集・Info.plist・アプリアイコンを組み立てます。

   ```yaml
   MyNewExam:
     templates: [QualificationApp]
     templateAttributes:
       qualificationID: my-new-exam
       displayName: 新資格学習
        bundleID: jp.yourcompany.mynewexam
        iconName: MyNewIcon
        adMobAppID: ca-app-pub-3940256099942544~1458002511 # 開発用サンプル。公開時は自分のアプリIDへ変更
     scheme:
       storeKitConfiguration: Qualifications/my-new-exam/products.storekit
   ```

4. `xcodegen generate`、`xcodebuild -scheme MyNewExam ... build`で生成。`Config/MyNewExam-Info.plist`は自動生成。起動して資格名・無料/有料数・診断・模試・価格・復元と広告を確認。公開時は署名チームと実際のBundle ID・AdMobアプリIDを設定します。

`qualification.json`の設定項目: `id`（変更しない永続キー）、`name`・`subtitle`・`examNote`、`examMinutes`、`mockQuestionCount`、`passingPercent`、`minimumSubjectPercent`、`subjects`（科目名配列）、`freeQuestionIDs`（無料IDの明示リスト）、`productID`、`accentHex`（`#RRGGBB`）、`privacyPolicyURL`（公開時にHTTPS URLを設定、架空サンプルは`null`）、`ads`（下記）。アプリ名/Bundle ID/アイコン/AdMobアプリIDは`project.yml`のターゲット属性で指定します。価格は**資格の`products.storekit`（開発）およびApp Store Connect（公開）**の同一商品IDで設定し、アプリはStoreKitから表示します。無料範囲を変更するだけなら`freeQuestionIDs`を編集してください。診断が偏らないよう各科目2問程度を無料範囲に含めることを推奨します。

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

`enabled: false`なら広告リクエストを行いません。`bannerEnabled`/`interstitialEnabled`は独立して切り替え可能で、対象ユニットを無効にする場合そのIDは空文字でも構いません。無料範囲は`freeQuestionIDs`で定義。買い切り商品は`productID`で定義し、**広告削除用の別課金商品はありません**。設定検証ではインタースティシャルの最短間隔600秒以上、最低2セッション・各5問以上を要求します。サンプルは30分かつ3セッション・各8問以上。港湾サンプルはインタースティシャル無効です。表示回数と最終表示日時は`Application Support/ad-frequency-<資格id>.json`へ原子的に保存し、読み書き失敗時は全画面広告を止めます。ロード失敗・未同意・オフラインでも学習と買い切り購入に影響しません。

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

`Qualifications/<id>/questions.json`の`version: 1`内に問題を追加。各問題は以下の形式です。

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

選択肢は2〜6件、`correctIndex`は**0始まり**、難易度は1〜5。画像はアセットカタログの名前を`imageName`に指定、不要なら`null`。`steps`は順次表示する解説で、不要なら`null`。`questionNumber`は年度別リストの本来の問番号（任意、既存サンプルは`source`の「問1」等から補完）。`concepts`は混同学習で関連問題を紐づけます。`tags`と`category`は検索・演習用です。将来の形式追加では`version`を更新してモデルと検証/画面を拡張してください。問題IDは更新後も維持し、削除・再利用すると既存履歴との関連が失われるため、履歴移行を伴う変更として扱います。

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

`Application Support/study-<資格id>.json`に`StudyData(schemaVersion: 1)`を原子的に保存。回答履歴・Mastery・模試・お気に入り・診断済み/設定に加え、**資格あたり1件の通常演習の出題順・現在位置・回答済み状態**と任意の試験日を保持します。試験日は時刻ではなく暦の年月日として保存し、夏時間や端末のタイムゾーン変更で設定日がずれないようにしています。ホームの残日数は当日0日、経過時は「試験日が経過」と表示します。別の連続演習を始めるときは再開/切り替えを確認。単問は途中演習を消さず、時間制限付き模試は中断後の再開対象外です。旧バージョンの保存データは新項目を補って読み込みます。読み込みに失敗した場合は元のファイルを**上書きしない読み取り専用状態**にし、保存失敗は画面で再試行できます。問題集はアプリ同梱でオフライン使用可。現状は端末間同期・バックアップの保証はなく、アプリ削除で履歴は消えます。将来のiCloud同期では`StudyStore`を差し替え、履歴と安定IDを移行してください。

試験日の追加・変更・解除はホーム最上部または設定の「受験予定」から行います。設定はホーム・問題を探す・記録の右上歯車から開きます。「データとプライバシー」には端末保存・広告・購入の説明と正式なポリシーへのリンクを設置。サンプルには`PrivacyPolicy.txt`を同梱します。学習情報リセットは回答・Mastery・模試・お気に入り・診断・途中演習・試験日を削除し、初回診断を再案内します。Recall Firstとランダム設定・学習量の選択・StoreKit購入権限・UMP同意・広告の頻度履歴は維持します。公開時は資格ごとの`privacyPolicyURL`を実際の公開URLへ設定してください。

購入権限は端末内の任意のフラグではなく、StoreKit 2の**検証済み・取消なし・商品ID一致・非消耗型**の`Transaction.currentEntitlements`から取得。購入時に取引を完了し、`Transaction.updates`で変更を反映。復元ボタンは`AppStore.sync()`後に権限を再確認します。購入済み端末ではStoreKitのローカル権限によりオフラインで使用でき、広告も非表示。未購入/商品読み込み失敗/承認待ち/復元なしを区別して表示し、無料問題は使い続けられます。ローカルの`.storekit`は**開発時のみ**の設定で、公開商品の価格・IDはApp Store Connectに登録します。

公開する資格ごとに行う作業:

1. 正式な問題・解説・画像/出典・法令更新と権利確認、専門家校閲。架空資格の名称/説明を実資格へ変更し、設定した試験時間・合格基準が正しいことを確認。
2. Apple DeveloperのTeam、独立Bundle ID、署名、アプリ名/1024pxアイコン、バージョン/ビルド番号を設定。`jp.example`の識別子を置換。
3. App Store Connectで**Non-Consumable**商品を作り、同一`productID`、販売地域・価格・説明・審査用スクリーンショットを設定。Sandbox/TestFlightで新規購入、キャンセル、保留、復元、オフライン、返金後の失効を確認。
4. 資格ごとのAdMobアプリ・広告枠、Google UMPの対象地域向け同意メッセージ、プライバシー設定への導線、実ID、必要なSKAdNetwork/app-ads.txt設定を用意し、ReleaseでサンプルIDが残っていないことを確認。出稿・メディエーションを加える場合はパートナーの開示と同意設定も更新。
5. [プライバシーのひな型](PRIVACY.md)を運営者情報に合わせて正式なURLで公開し、AdMob/UMPを含むApp Store ConnectのApp Privacy回答・サポートURL、スクリーンショット、販売用説明、コンテンツ権利情報、審査用の操作説明を提出。必要な手続き・契約を完了。
6. 実機と最新/最小対応iOSでライト/ダーク、Dynamic Type、VoiceOver、バックグラウンド復帰、同意あり/なし、購入前/後/復元/返金後、広告ロード失敗、ストレージ不足、通信なし、長時間の模試を確認。`xcodebuild -project ExamMaster.xcodeproj -scheme <Scheme> -configuration Release -destination 'generic/platform=iOS' archive -archivePath <保存先>.xcarchive`で署名付きArchiveを作成して申請。

サンプルの`.storekit`と問題は開発・動作確認用です。ストア公開には各資格ごとの実データ・Apple Developerの署名/商品登録/審査が必要です。
