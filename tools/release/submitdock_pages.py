#!/usr/bin/env python3
"""Create or update the app's public pages; dry run by default, no automatic retries."""
import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "https://submitdock-ios-pages.netlify.app"
PAGES = ROOT / "docs/release/web-pages"
OUTPUT = ROOT / "release-artifacts/submitdock"


def plain_text(markdown):
    text = re.sub(r"^#{1,6}\s+", "", markdown, flags=re.MULTILINE)
    return re.sub(r"\[([^\]]+)\]\((https://[^)]+)\)", r"\1（\2）", text)


def prepare(api, screenshots):
    metadata = json.loads((ROOT / "docs/release/metadata-ja.json").read_text())
    email = metadata.get("supportEmail", "")
    if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
        raise ValueError("metadata-ja.jsonに正式なsupportEmailを設定してください。")
    fields = {
        "appName": metadata["name"], "developerName": metadata["developerName"],
        "supportEmail": email,
        "appDescription": (PAGES / "about.md").read_text(),
        "supportContent": (PAGES / "support.md").read_text(),
        "privacyPolicy": (PAGES / "privacy.md").read_text(),
    }
    if api == "legacy":
        fields["appDescription"] = (PAGES / "legacy-description.txt").read_text()
        fields["privacyPolicy"] = plain_text(fields["privacyPolicy"])
        fields.pop("supportContent")
    if any("{SUPPORT_EMAIL}" in value for value in fields.values()):
        raise ValueError("連絡先の仮置きが残っています。")
    limits = {"appName": 120, "developerName": 120, "supportEmail": 160,
              "appDescription": 1200 if api == "legacy" else 4000,
              "privacyPolicy": 10000 if api == "legacy" else 40000, "supportContent": 20000}
    for key, value in fields.items():
        if len(value) > limits[key]:
            raise ValueError(f"{key}がAPIの上限{limits[key]}文字を超えています。")
    images = []
    for path in screenshots:
        data = path.read_bytes()
        if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) > 2_500_000:
            raise ValueError("スクリーンショットは2.5MB以下のPNGを指定してください。")
        images.append((path.name, data))
    if len(images) > (4 if api == "legacy" else 6) or sum(len(data) for _, data in images) > 5_500_000:
        raise ValueError("スクリーンショットの枚数または合計サイズがAPI上限を超えています。")
    return fields, images


def multipart(fields, images, icon=None):
    boundary = "piyotre-" + uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n'.encode() + value.encode() + b"\r\n")
    for index, (_, data) in enumerate(images, 1):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="screenshots"; filename="screen-{index}.png"\r\nContent-Type: image/png\r\n\r\n'.encode() + data + b"\r\n")
    if icon:
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="appIcon"; filename="icon.png"\r\nContent-Type: image/png\r\n\r\n'.encode() + icon + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


def save_private(path, value):
    # Write tokens without placing them in command arguments or public logs.
    with tempfile.NamedTemporaryFile(dir=OUTPUT, mode="w", delete=False) as file:
        temporary = Path(file.name)
        temporary.chmod(0o600)
        json.dump(value, file, ensure_ascii=False, indent=2)
        file.write("\n")
    temporary.replace(path)


def api_request(method, endpoint, body, content_type, token=""):
    with tempfile.NamedTemporaryFile(dir=OUTPUT) as file:
        file.write(body)
        file.flush()
        config = f'header = "Content-Type: {content_type}"\nheader = "Accept: application/json"\n'
        if token:
            if not re.fullmatch(r"sdk_[A-Za-z0-9_-]+", token):
                raise ValueError("編集トークンの形式が不正です。")
            config += f'header = "Authorization: Bearer {token}"\n'
        response = subprocess.run(["curl", "--silent", "--show-error", "--connect-timeout", "15",
                                   "--max-time", "45", "--config", "-", "--request", method,
                                   "--data-binary", "@" + file.name, "--write-out", "\n%{http_code}", endpoint],
                                  input=config.encode(), capture_output=True, timeout=50)
    if response.returncode:
        raise ValueError(f"API接続が停止しました（curl {response.returncode}）。自動再送していません。")
    payload, status_bytes = response.stdout.rsplit(b"\n", 1)
    status = int(status_bytes)
    if not 200 <= status < 300:
        raise ValueError(f"APIがHTTP {status}を返しました。自動再送していません。")
    return json.loads(payload)


def update_existing(fields, images, icon):
    public_path = PAGES / "published.json"
    public = json.loads(public_path.read_text())
    page_id = public["id"]
    if not re.fullmatch(r"[a-z0-9-]{8,64}", page_id):
        raise ValueError("既存のPage IDが不正です。")
    endpoint = BASE + "/api/pages/" + page_id
    receipt = OUTPUT / "page.private.json"
    result = json.loads(receipt.read_text()) if receipt.exists() else {}
    if result.get("id") != page_id:
        raise ValueError("公開ページとローカル発行結果のIDが一致しません。")
    if not result.get("editToken"):
        pending = OUTPUT / "claim.pending.json"
        if pending.exists():
            raise ValueError("編集権限取得の結果が未確定です。claim.pending.jsonを確認してください。")
        pending.write_text(json.dumps({"id": page_id}))
        result = api_request("POST", endpoint + "/token",
                             json.dumps({"supportEmail": fields["supportEmail"]}).encode(), "application/json")
        if result.get("id") != page_id or not result.get("editToken"):
            raise ValueError("編集権限取得の応答が不正です。自動再送していません。")
        save_private(receipt, result)
        pending.unlink()
    body, content_type = multipart(fields, images, icon)
    result = api_request("PATCH", endpoint, body, content_type, result["editToken"])
    page = result.get("page", result)
    if page.get("id") != page_id or (icon and not page.get("appIcon")):
        raise ValueError("ページ更新の応答を確認できません。GETで状態を確認してください。")
    public.update(api="modern", editable=True, contentFormat="markdown", appIcon=page.get("appIcon"),
                  updatedAt=page.get("updatedAt"))
    public_path.write_text(json.dumps(public, ensure_ascii=False, indent=2) + "\n")
    print(f"既存ページを更新しました: {public['supportUrl']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", choices=["legacy", "modern"], default="modern")
    parser.add_argument("--screenshot", type=Path, action="append", default=[])
    parser.add_argument("--icon", type=Path)
    parser.add_argument("--update", action="store_true", help="published.jsonの既存ページを同じURLで更新する。")
    parser.add_argument("--publish", action="store_true", help="確認済みの原稿をサイトへ送信する。省略時はローカル準備のみ。")
    args = parser.parse_args()
    fields, images = prepare(args.api, args.screenshot)
    icon = args.icon.read_bytes() if args.icon else None
    if icon and (args.api == "legacy" or not icon.startswith(b"\x89PNG\r\n\x1a\n") or len(icon) > 1_000_000):
        raise ValueError("アイコンはmodern APIに1MB以下のPNGで指定してください。")
    if args.update and args.api != "modern":
        raise ValueError("既存ページの更新にはmodern APIを指定してください。")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    request_file = OUTPUT / "request.json"
    request_file.write_text(json.dumps({"api": args.api, "fields": fields,
                                       "screenshots": [name for name, _ in images],
                                       "appIcon": args.icon.name if args.icon else None}, ensure_ascii=False, indent=2) + "\n")
    print(f"原稿検査成功: {request_file}（画像{len(images)}枚）")
    if not args.publish:
        action = "既存ページを更新" if args.update else "ページを作成"
        print(f"未送信。--publishで指定サイトの{action}します。")
        return 0
    if args.update:
        update_existing(fields, images, icon)
        return 0
    receipt = OUTPUT / "page.private.json"
    pending = OUTPUT / "creation.pending.json"
    if receipt.exists() or pending.exists():
        raise ValueError("発行結果または送信中記録があるため再作成を止めました。既存ページの状態を確認してください。")
    endpoint = BASE + ("/api/create" if args.api == "legacy" else "/api/pages")
    if not shutil.which("curl"):
        raise ValueError("TLS証明書を検証できるcurlが必要です。")
    body, content_type = multipart(fields, images, icon)
    pending.write_text(json.dumps({"endpoint": endpoint, "appName": fields["appName"]}, ensure_ascii=False))
    try:
        response = subprocess.run(["curl", "--silent", "--show-error", "--connect-timeout", "15",
                                   "--max-time", "45", "--request", "POST", "--header", "Content-Type: " + content_type,
                                   "--header", "Accept: application/json", "--data-binary", "@-",
                                   "--write-out", "\n%{http_code}", endpoint], input=body, capture_output=True, timeout=50)
    except subprocess.TimeoutExpired as error:
        raise ValueError("送信後の成否を確定できません。自動再送していません。creation.pending.jsonを確認してください。") from error
    if response.returncode:
        # DNS/connection/TLS failures happen before an HTTP request can create a page.
        if response.returncode in {6, 7, 35, 60}:
            pending.unlink()
            raise ValueError(f"接続前に停止しました（curl {response.returncode}）。ページは作成していません。")
        raise ValueError(f"送信結果を確定できません（curl {response.returncode}）。自動再送せず送信中記録を残しました。")
    payload, status_bytes = response.stdout.rsplit(b"\n", 1)
    status = int(status_bytes)
    if not 200 <= status < 300:
        if 400 <= status < 500:
            pending.unlink()
        raise ValueError(f"作成APIがHTTP {status}を返しました。自動再送していません。")
    try:
        result = json.loads(payload)
    except json.JSONDecodeError as error:
        raise ValueError("作成APIの応答を解釈できません。自動再送せず送信中記録を残しました。") from error
    with receipt.open("x") as file:
        receipt.chmod(0o600)
        file.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    pending.unlink()
    page_id = result.get("id", "")
    if not re.fullmatch(r"[a-z0-9-]{8,64}", page_id):
        raise ValueError("返却されたPage IDが不正です。結果はローカルに保存済みです。")
    expected = {"supportUrl": BASE + "/support/" + page_id, "privacyUrl": BASE + "/privacy/" + page_id}
    if any(result.get(key) != value for key, value in expected.items()):
        raise ValueError("返却URLが指定サイトと一致しません。結果はローカルに保存済みです。")
    public = {"id": page_id, "appName": fields["appName"], **expected,
              "marketingUrl": expected["supportUrl"], "api": args.api,
              "editable": bool(result.get("editToken"))}
    (ROOT / "docs/release/web-pages/published.json").write_text(json.dumps(public, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(public, ensure_ascii=False, indent=2))
    print("発行結果と編集トークン（返却された場合）はGit対象外のpage.private.jsonに保存しました。")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError) as error:
        print(f"停止: {error}", file=sys.stderr)
        sys.exit(1)
