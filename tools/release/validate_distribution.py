#!/usr/bin/env python3
"""Check tracking declarations in actual app/IPA resources before uploading."""
import argparse
import json
import plistlib
import re
import sys
import zipfile
from pathlib import Path


def tracking_errors(manifest):
    if not isinstance(manifest, dict):
        return ["Privacy Manifestのルートは辞書である必要があります。"]
    tracking = manifest.get("NSPrivacyTracking", False)
    domains = manifest.get("NSPrivacyTrackingDomains", [])
    errors = []
    if type(tracking) is not bool:
        errors.append("NSPrivacyTrackingはBooleanで指定してください。")
    if not isinstance(domains, list):
        return errors + ["NSPrivacyTrackingDomainsは文字列の配列で指定してください。"]
    if tracking is True and not domains:
        errors.append("ITMS-91064: tracking=trueには空でない対象ドメイン一覧が必要です。")
    if domains and tracking is not True:
        errors.append("ITMS-91064: 対象ドメインがある場合はtracking=trueが必要です。")
    # Omit the optional domain key when there are no tracking domains.
    if "NSPrivacyTrackingDomains" in manifest and not domains:
        errors.append("空のNSPrivacyTrackingDomainsを残さず、宣言内容を修正してください。")
    for domain in domains:
        labels = domain.split(".") if isinstance(domain, str) else []
        if (len(labels) < 2 or not re.fullmatch(r"[A-Za-z]{2,63}", labels[-1])
                or any(not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", label)
                       for label in labels)):
            errors.append("対象ドメインはURL・パス・ワイルドカードを含まないホスト名で指定してください。")
    return errors


def inspect_resources(resources, root_manifest):
    files = []
    if root_manifest not in resources:
        files.append({"path": root_manifest, "errors": ["アプリ本体のPrivacyInfo.xcprivacyがありません。"]})
    for name, data in resources.items():
        manifest = plistlib.loads(data)
        errors = tracking_errors(manifest)
        values = manifest if isinstance(manifest, dict) else {}
        files.append({"path": name, "tracking": values.get("NSPrivacyTracking"),
                      "domains": values.get("NSPrivacyTrackingDomains", []), "errors": errors})
    return {"passed": all(not file["errors"] for file in files), "manifests": files}


def inspect_app(path):
    resources = {str(file.relative_to(path)): file.read_bytes() for file in path.rglob("PrivacyInfo.xcprivacy")}
    return inspect_resources(resources, "PrivacyInfo.xcprivacy")


def inspect_ipa(path):
    with zipfile.ZipFile(path) as ipa:
        roots = [name for name in ipa.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(roots) != 1:
            raise ValueError("IPAにはアプリ本体が1つ必要です。")
        prefix = roots[0].removesuffix("Info.plist")
        resources = {name.removeprefix(prefix): ipa.read(name) for name in ipa.namelist()
                     if name.startswith(prefix) and name.endswith("PrivacyInfo.xcprivacy")}
        return inspect_resources(resources, "PrivacyInfo.xcprivacy")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--app", type=Path)
    source.add_argument("--ipa", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = inspect_app(args.app) if args.app else inspect_ipa(args.ipa)
    if args.report:
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        print(f"検証できません: {error}", file=sys.stderr)
        sys.exit(2)
