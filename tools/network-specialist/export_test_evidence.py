#!/usr/bin/env python3
"""Export kept XCTest images/text using legacy objects when attachment export fails.

Exports evidence only; successful tests or saved screenshots do not establish
that a UI has passed visual or VoiceOver review. Requires Xcode's xcresulttool.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def descendants(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from descendants(child)
    elif isinstance(value, list):
        for child in value:
            yield from descendants(child)


def value(item, key, default=""):
    return item.get(key, {}).get("_value", default)


def export(bundle, output, test_filter=None):
    def object_data(ref=None):
        command = ["xcrun", "xcresulttool", "get", "object", "--legacy",
                   "--format", "json", "--path", str(bundle)]
        if ref:
            command += ["--id", ref]
        return json.loads(subprocess.check_output(command))

    # Never overwrite an earlier review's screenshots or other user files.
    output.mkdir(parents=True, exist_ok=False)
    attachments = []
    for action in object_data().get("actions", {}).get("_values", []):
        ref = action.get("actionResult", {}).get("testsRef", {}).get("id", {}).get("_value")
        if not ref:
            continue
        for test in descendants(object_data(ref)):
            if "summaryRef" not in test:
                continue
            identifier = value(test, "identifier")
            if test_filter and test_filter not in identifier:
                continue
            for attachment in descendants(object_data(test["summaryRef"]["id"]["_value"])):
                if "payloadRef" not in attachment:
                    continue
                uti = value(attachment, "uniformTypeIdentifier")
                extension = {"public.png": ".png", "public.jpeg": ".jpg",
                             "public.plain-text": ".txt", "public.utf8-plain-text": ".txt"}.get(uti)
                if not extension:
                    continue
                destination = output / f"{len(attachments):03d}{extension}"
                payload = attachment["payloadRef"]["id"]["_value"]
                subprocess.run(["xcrun", "xcresulttool", "export", "object", "--legacy",
                                "--type", "file", "--path", str(bundle), "--id", payload,
                                "--output-path", str(destination)], check=True, stdout=subprocess.DEVNULL)
                attachments.append({"test": identifier, "result": value(test, "testStatus"),
                                    "name": value(attachment, "name"), "file": destination.name,
                                    "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
    manifest = {"resultBundle": str(bundle), "attachments": attachments}
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("result_bundle", type=Path)
    parser.add_argument("output_directory", type=Path, help="New directory; refuses existing paths")
    parser.add_argument("--test", help="Optional substring in the XCTest identifier")
    args = parser.parse_args()
    if not args.result_bundle.is_dir():
        parser.error("The result bundle does not exist")
    print(json.dumps(export(args.result_bundle.resolve(), args.output_directory.resolve(), args.test),
                     ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
