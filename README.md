# 資格学習シリーズ / ExamMaster

**iPhone向け・買い切り型のWhite Label試験対策アプリ基盤。** 1つのSwiftUIコードベースから、資格ごとに異なるBundle ID・表示名・テーマ・アイコン・問題集・無料範囲・StoreKit商品を持つ独立アプリを作ります。アカウントやバックエンドは不要です。

現在の2つの独立したビルドターゲット:

| Scheme | 資格 | Bundle ID | 問題 / 無料 |
| --- | --- | --- | --- |
| `ExamMaster` | 設備安全管理士（架空） | `jp.example.exammaster.demo` | 32 / 12 |
| `HarborStudy` | 港湾安全記録士（架空） | `jp.example.exammaster.harbor` | 12 / 6 |

**両資格とも架空の教材です。実在する国家資格を扱うには、問題・解説・出典・試験基準の調査と転載許諾等を済ませて差し替えてください。** `jp.example`のBundle IDや商品IDを使ったままストアへ申請しないでください。

## 体験と技術選定

- 今日: 復習期限・忘却リスク・誤解・未学習を加味した最大12問を自動選択し、科目が偏らないように配列。初回は任意の無料診断から開始できます。
- 演習: 年度別・科目別・カテゴリ別・ランダム・間違い・お気に入り・混同学習・検索と絞り込み。回答後に出典と解説。計算問題は任意の段階的解説。模試は時間制限、全体と科目ごとの基準判定、終了後の問題別復習。
- Recall First: おすすめ/復習では選択肢を見る前に一度想起。年度別・模試・診断では無効。任意の自信度、同じ誤選択肢の繰り返し、自信ありの誤答から危険な思い込みを検知します。
- 分析: 学習準備度（合格確率ではない）、分野別の定着度、安定記憶、忘却リスク、復習期限、学習日数、回答・模試の履歴。
- 買い切り: 無料問題は何度でも利用可。全問題解放は資格アプリ固有の**非消耗型**IAP。価格はStoreKitのローカライズされた商品情報から表示し、購入状態は検証済み取引から再取得します。

**Swift / SwiftUI（iOS 17+）/ StoreKit 2 / Codable / XCTest**を採用。iPhone・App Store優先で、Apple標準のDynamic Type、ダークモード、VoiceOver、決済を使い、個人開発で外部依存とサーバーの保守を最小化します。AndroidはUI層とStoreKit層を作り直す必要がありますが、JSON問題集・資格設定と独立した学習計算の仕様は移植できます。AIは不要と判断し導入していません。正答・解説のSource of Truthはレビュー済みのJSONです。

## ディレクトリと責務

```
project.yml                   XcodeGen定義。QualificationAppテンプレートと各アプリの設定
MyApp.swift / ContentView.swift 起動・資格ID読み込み・各画面への入口
Core/Models.swift             資格/問題/回答のスキーマと問題集の厳格な検証
Core/MasteryEngine.swift      記憶状態の更新と統計・学習準備度
Core/SessionPlanner.swift     おすすめ/診断/混同学習/模試の問題選択
Core/StudyStore.swift         回答・状態・ブックマーク・模試の端末内永続化
Core/PurchaseManager.swift    StoreKit 2の取得/購入/復元/権限判定
Views/                      診断/今日/問題一覧/演習/分析/設定/購入
Qualifications/<id>/          qualification.json / questions.json / products.storekit
Assets.xcassets/              アプリ別アイコンと色
Config/                       XcodeGenが生成するアプリ別Info.plist
Tests/ / UITests/             学習・統計・保存・StoreKit・初回起動の検証
tools/GenerateIcon.swift      サンプル用1024pxアイコン生成スクリプト
```

UI、出題計画、習熟計算、端末保存、決済は別ファイルです。差し替え可能な純粋計算を`MasteryEngine`/`SessionPlanner`にまとめました。問題バンクはアプリに読み取り専用で同梱し、問題IDを履歴の永続キーとします。アプリごとのバンドルには**そのターゲットの資格JSONのみ**を含めます（共有のアイコン用アセットカタログを除く）。`.storekit`は開発Schemeとテストで参照し、アプリのリソースにはコピーしません。

## 動かし方・ビルド・テスト

macOS、Xcode 27、iOS Simulator、[XcodeGen](https://github.com/yonaskolb/XcodeGen)を使用。生成済み`ExamMaster.xcodeproj`も同梱しています。Swiftソースやターゲット追加後は再生成してください。

```sh
xcodegen generate
xcodebuild -project ExamMaster.xcodeproj -scheme ExamMaster -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ExamMaster.xcodeproj -scheme HarborStudy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ExamMaster.xcodeproj -scheme ExamMaster -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
```

XcodeでSchemeを選びRunするとサンプル商品設定が自動的に読み込まれます。CLIから起動する場合は、`xcrun simctl list devices available`でUDIDを調べ、`xcrun simctl boot <UDID>`、`xcrun simctl install <UDID> <ビルドした.appのパス>`、`xcrun simctl launch <UDID> <Bundle ID>`の順に実行します。CLIの`simctl launch`だけではXcodeのローカルStoreKit商品設定は適用されないため、商品価格確認にはXcodeのRunまたはStoreKitTestを使います。

テストは純粋な学習計算、資格の整合性、5桁件数の履歴統計、壊れた保存データの保護、StoreKitTestでの**実購入・復元・取引消去**、UIテストの初回診断・模試・演習・再起動後の履歴・購入画面を対象にしています。UIテストのみ`-UITestResetStudy`というDebug専用起動引数でデータを初期化します。実際のアプリから履歴を初期化する操作はありません。

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
     scheme:
       storeKitConfiguration: Qualifications/my-new-exam/products.storekit
   ```

4. `xcodegen generate`、`xcodebuild -scheme MyNewExam ... build`で生成。`Config/MyNewExam-Info.plist`は自動生成。起動して資格名・無料/有料数・診断・模試・価格・復元を確認。公開時は署名チームと実際のBundle IDを設定します。

`qualification.json`の設定項目: `id`（変更しない永続キー）、`name`・`subtitle`・`examNote`、`examMinutes`、`mockQuestionCount`、`passingPercent`、`minimumSubjectPercent`、`subjects`（科目名配列）、`freeQuestionIDs`（無料IDの明示リスト）、`productID`、`accentHex`（`#RRGGBB`）。アプリ名/Bundle ID/アイコンは`project.yml`のターゲット属性で指定します。価格は**資格の`products.storekit`（開発）およびApp Store Connect（公開）**の同一商品IDで設定し、アプリはStoreKitから表示します。無料範囲を変更するだけなら`freeQuestionIDs`を編集してください。診断が偏らないよう各科目2問程度を無料範囲に含めることを推奨します。

## 問題の追加と更新

`Qualifications/<id>/questions.json`の`version: 1`内に問題を追加。各問題は以下の形式です。

```json
{
  "id": "stable-0001", "year": 2025,
  "subject": "科目名", "category": "カテゴリ名",
  "stem": "設問", "choices": ["選択肢A", "選択肢B", "選択肢C"],
  "correctIndex": 1, "explanation": "根拠を含む解説",
  "source": "出典・年度・設問番号・許諾の確認先",
  "imageName": null, "difficulty": 2,
  "tags": ["計算"], "concepts": ["比較する概念"],
  "steps": ["何を求めるか確認", "式を立てる", "結果を検算"]
}
```

選択肢は2〜6件、`correctIndex`は**0始まり**、難易度は1〜5。画像はアセットカタログの名前を`imageName`に指定、不要なら`null`。`steps`は順次表示する解説で、不要なら`null`。`concepts`は混同学習で関連問題を紐づけます。`tags`と`category`は検索・演習用です。将来の形式追加では`version`を更新してモデルと検証/画面を拡張してください。問題IDは更新後も維持し、削除・再利用すると既存履歴との関連が失われるため、履歴移行を伴う変更として扱います。

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

`Application Support/study-<資格id>.json`に`StudyData(schemaVersion: 1)`を原子的に保存。回答履歴・Mastery・模試・お気に入り・診断済み/設定を保持します。読み込みに失敗した場合は元のファイルを**上書きしない読み取り専用状態**にし、保存失敗は画面で再試行できます。問題集はアプリ同梱でオフライン使用可。現状は端末間同期・バックアップの保証はなく、アプリ削除で履歴は消えます。将来のiCloud同期では`StudyStore`を差し替え、履歴と安定IDを移行してください。

購入権限は端末内の任意のフラグではなく、StoreKit 2の**検証済み・取消なし・商品ID一致・非消耗型**の`Transaction.currentEntitlements`から取得。購入時に取引を完了し、`Transaction.updates`で変更を反映。復元ボタンは`AppStore.sync()`後に権限を再確認します。購入済み端末ではStoreKitのローカル権限によりオフラインで使用できます。未購入/商品読み込み失敗/承認待ち/復元なしを区別して表示し、無料問題は使い続けられます。ローカルの`.storekit`は**開発時のみ**の設定で、公開商品の価格・IDはApp Store Connectに登録します。

公開する資格ごとに行う作業:

1. 正式な問題・解説・画像/出典・法令更新と権利確認、専門家校閲。架空資格の名称/説明を実資格へ変更し、設定した試験時間・合格基準が正しいことを確認。
2. Apple DeveloperのTeam、独立Bundle ID、署名、アプリ名/1024pxアイコン、バージョン/ビルド番号を設定。`jp.example`の識別子を置換。
3. App Store Connectで**Non-Consumable**商品を作り、同一`productID`、販売地域・価格・説明・審査用スクリーンショットを設定。Sandbox/TestFlightで新規購入、キャンセル、保留、復元、オフライン、返金後の失効を確認。
4. [プライバシーのひな型](PRIVACY.md)を運営者情報に合わせて正式なURLで公開し、App Storeのプライバシー回答・サポートURL、スクリーンショット、販売用説明、コンテンツ権利情報、審査用の操作説明を提出。必要な手続き・契約を完了。
5. 実機と最新/最小対応iOSでライト/ダーク、Dynamic Type、VoiceOver、バックグラウンド復帰、ストレージ不足、通信なし、長時間の模試を確認。`xcodebuild -project ExamMaster.xcodeproj -scheme <Scheme> -configuration Release -destination 'generic/platform=iOS' archive -archivePath <保存先>.xcarchive`で署名付きArchiveを作成して申請。

サンプルの`.storekit`と問題は開発・動作確認用です。ストア公開には各資格ごとの実データ・Apple Developerの署名/商品登録/審査が必要です。
