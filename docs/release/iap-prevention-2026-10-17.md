# IAP商品取得の汎用リリース対策（2026-10-17）

アプリのジャンル・名称・資格区分によらない対策を、共有SubmitDockとios-release-submitdockスキルへ反映しました。特定アプリのSKU、300円、日本限定、単一商品の前提を共通ルールに固定していません。

## 反映先

- [スキル](/Users/hino/.codex/skills/ios-release-submitdock/SKILL.md)
- [共通IAP手順](/Users/hino/.codex/skills/ios-release-submitdock/references/iap-release.md)
- [共有ツールの使い方](/Users/hino/Desktop/dev/iOSSubmitter/releasekit/README.md)
- [検証記録の照合](/Users/hino/Desktop/dev/iOSSubmitter/releasekit/iap.py)
- [実機の商品取得テスト実行](/Users/hino/Desktop/dev/iOSSubmitter/releasekit/iap_probe.py)
- [他アプリでも使えるXCTest](/Users/hino/Desktop/dev/iOSSubmitter/releasekit/assets/IAPSandboxTests.swift)

## 動作

- 購入商品があるプロファイルには、実機・実Sandboxで取得した商品ID、種別、基準国、通貨、価格、version/build、関連ソースの照合を要求します。検証記録がない、別ビルド、模擬StoreKit、Simulator、スキップ、空応答等は提出可能扱いになりません。
- プローブは専用の一時スキームを作り、ローカルStoreKit設定を外して商品情報だけを取得します。購入・復元・レシート更新は呼びません。失敗時に以前の成功記録を上書きしません。
- 対象ソースの指紋とアーカイブの来歴を記録し、別アーカイブへの結果流用を防ぎます。API提出時は実際に選択されたApple側ビルドも照合します。Safari等の画面提出でも同じiap-checkを実行する手順です。
- 契約・実際の価格スケジュール・販売国・審査メモの確認、Apple側だけの設定変更後の再検証、購入画面と購入/復元の別途検証をスキルに明記しました。未再現の障害を地域差と断定しません。
- このリポジトリの共有購入処理には、前景復帰・ストア地域変更時の再取得、空応答とAPIエラーの区別、商品情報と購入/復元エラーの分離を追加しました。既存の検証済み権限は商品取得失敗で失いません。

## 検証結果

- 共有CLIの自動テスト: 29件成功。購入4種別、複数の価格/ストア地域、正しい証跡、記録不足、別ビルド、変更後ソース、スキップ、失敗時の記録保持、提出前の選択ビルド不一致等を検証。
- 共通購入処理のSimulatorテスト: 6件成功。実機Sandbox専用テスト1件は意図どおりスキップし、Sandbox成功の根拠には含めません。
- 実機コードのRelease構成build-for-testing: 成功（署名・実機実行なし）。
- ios-release-submitdockの標準スキル検証: 成功。
- 実際にインストールしたCLIでも29件成功、iap-probeの実行計画表示成功。現在の3プロファイルは新ソースに対応した実Sandbox記録が未取得のため、readyToSubmit=falseになることを確認。
- Simulator結果: /private/tmp/iap-generic-check-20261017-retry.xcresult
- 実機向けコンパイルログ: /private/tmp/iap-generic-device-compile-20261017.log

新しい汎用プローブ自体の実機実行と購入/復元は今回実施していません。以前の提出時ソースのSandbox商品取得成功は調査記録に保持し、現在のソースへ付け替えていません。元のリジェクト原因は未確定で、新ビルドのアップロード・再提出も行っていません。
