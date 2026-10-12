#!/usr/bin/env python3
"""NetworkSpecialist local release checks. No account changes or uploads."""
import argparse
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse
from validate_distribution import tracking_errors

ROOT = Path(__file__).resolve().parents[2]
SCHEME = "NetworkSpecialist"
SAMPLE_AD_PUBLISHER = "3940256099942544"


def valid_https(value):
    url = urlparse(value or "")
    host = (url.hostname or "").lower()
    return (url.scheme == "https" and bool(host) and not url.username and not url.password
            and host not in {"localhost", "example.com", "example.org", "example.net"}
            and not host.endswith((".example.com", ".example.org", ".example.net")))


def checks(config, bank, product, info, settings, policy):
    result = []
    def check(id_, condition, message):
        result.append({"id": id_, "passed": bool(condition), "message": message})
    bundle = settings.get("PRODUCT_BUNDLE_IDENTIFIER", "")
    check("bundle", re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle)
          and not bundle.startswith("jp.example."), "正式なBundle ID（jp.exampleは開発用）")
    check("team", re.fullmatch(r"[A-Z0-9]{10}", settings.get("DEVELOPMENT_TEAM", "")), "NWターゲットのApple Developer Team ID")
    check("version", re.fullmatch(r"\d+(?:\.\d+){0,2}", settings.get("MARKETING_VERSION", "")), "公開バージョン")
    check("build", re.fullmatch(r"[1-9]\d*", settings.get("CURRENT_PROJECT_VERSION", "")), "正のビルド番号（アップロード時は未使用の番号）")
    check("sdk", settings.get("PLATFORM_NAME") == "iphoneos"
          and int(re.sub(r"\D.*", "", str(settings.get("SDK_VERSION", "0"))) or "0") >= 26,
          "iOS 26以降のSDK（2026-10-11確認）")
    check("draft", bank.get("isDraft") is False, "レビューを終えた教材のisDraft解除（件数ゲートは別途検査）")
    product_id = config.get("productID", "")
    check("iap", bool(product_id) and not product_id.startswith("jp.example.")
          and product.get("productID") == product_id and product.get("type") == "NonConsumable",
          "正式な非消耗型商品IDと教材設定/StoreKit設定の一致（ASC側の登録は別途）")
    check("policy_url", valid_https(config.get("privacyPolicyURL")), "公開HTTPSプライバシーポリシーURL（到達性は別途確認）")
    check("policy_text", bool(policy.strip()) and not any(word in policy for word in ["開発用サンプル", "架空資格", "ひな型"]),
          "同梱ポリシーの開発用サンプル文言を正式版に更新")
    ads = config.get("ads", {})
    app_id = ads.get("adMobAppID", "")
    check("ad_app", re.fullmatch(r"ca-app-pub-\d{16}~\d{10}", app_id)
          and SAMPLE_AD_PUBLISHER not in app_id and info.get("GADApplicationIdentifier") == app_id,
          "本番AdMobアプリIDと生成Info.plistの一致")
    for kind in ["banner", "interstitial"]:
        id_ = ads.get(kind + "AdUnitID", "")
        check("ad_" + kind, not ads.get(kind + "Enabled", True) or
              (re.fullmatch(r"ca-app-pub-\d{16}/\d{10}", id_) and SAMPLE_AD_PUBLISHER not in id_),
              kind + "広告の本番ユニットID（無効な枠は不要）")
    check("att", bool(info.get("NSUserTrackingUsageDescription")), "ATT説明文")
    check("iap_credit", bool(config.get("contentCredit")), "過去問の出典・権利表記")
    return result


def read_settings(root, file=None):
    if file:
        output = json.loads(Path(file).read_text())
    else:
        command = ["xcodebuild", "-project", str(root / "ExamMaster.xcodeproj"), "-scheme", SCHEME,
                   "-configuration", "Release", "-destination", "generic/platform=iOS", "-showBuildSettings", "-json"]
        process = subprocess.run(command, cwd=root, capture_output=True, text=True)
        if process.returncode:
            raise RuntimeError("XcodeのRelease設定を読めません。xcodebuildのパッケージ・署名設定を確認してください。")
        output = json.loads(process.stdout)
    return next(item["buildSettings"] for item in output if item.get("target") == SCHEME)


def inspect(root, settings):
    app = root / "Qualifications/network-specialist"
    config = json.loads((app / "qualification.json").read_text())
    bank = json.loads((app / "questions.json").read_text())
    products = json.loads((app / "products.storekit").read_text())["products"]
    product = next((p for p in products if p.get("productID") == config.get("productID")), {})
    info = plistlib.loads((root / "Config/NetworkSpecialist-Info.plist").read_bytes())
    entries = checks(config, bank, product, info, settings, (app / "PrivacyPolicy.txt").read_text())
    privacy = plistlib.loads((root / "PrivacyInfo.xcprivacy").read_bytes())
    privacy_errors = tracking_errors(privacy)
    entries.append({"id": "privacy_tracking", "passed": not privacy_errors,
                    "message": "Privacy Manifestのトラッキング宣言と対象ドメインの整合" +
                               ("：" + " / ".join(privacy_errors) if privacy_errors else "")})
    process = subprocess.run([sys.executable, str(root / "tools/network-specialist/validate.py"), "--release"],
                             cwd=root, capture_output=True, text=True)
    entries.append({"id": "content_release", "passed": process.returncode == 0,
                    "message": "教材の正答・レビュー固定ハッシュ・件数・完成版ゲート"})
    report = {"scheme": SCHEME, "localChecksPassed": all(e["passed"] for e in entries), "checks": entries,
              "manualChecks": ["Developer契約/税務/銀行情報", "App Store Connectのアプリ/商品/価格/販売地域",
                               "サポートURL/運営者連絡先/年齢区分/暗号化申告/コンテンツ権利",
                               "公開URLの到達性/AdMobとUMPの配信地域設定/Privacy ReportとApp Privacy",
                               "実機/VoiceOver/SandboxとTestFlightの購入・復元・返金",
                               "正式サイズのスクリーンショット/審査メモ/公開方法"],
              "note": "ローカル検査はApple側の登録・審査・実機検証の完了を保証しません。"}
    validation = root / "docs/network-specialist/validation-report.json"
    if validation.exists():
        data = json.loads(validation.read_text())
        report["content"] = {k: data.get(k) for k in ["included", "free", "paid", "errors", "incomplete", "releaseReady"]}
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-settings", help="保存済みxcodebuild -showBuildSettings -json出力（省略時はXcodeから取得）")
    parser.add_argument("--report", type=Path, help="JSONレポート保存先")
    args = parser.parse_args()
    try:
        report = inspect(ROOT, read_settings(ROOT, args.build_settings))
    except (OSError, ValueError, RuntimeError, StopIteration) as error:
        parser.exit(2, f"検査を実行できません: {error}\n")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    for item in report["checks"]:
        print(("OK   " if item["passed"] else "未設定/未完了 ") + item["message"])
    print(report["note"])
    return 0 if report["localChecksPassed"] else 1


if __name__ == "__main__":
    sys.exit(main())
