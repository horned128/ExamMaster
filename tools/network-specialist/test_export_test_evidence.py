import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from export_test_evidence import descendants, export


class EvidenceExportTests(unittest.TestCase):
    def test_descendants_traverses_nested_activity_lists(self):
        tree = {"actions": [{"activities": [{"attachments": [{"name": "image"}]}]}]}
        self.assertEqual([item["name"] for item in descendants(tree) if "name" in item], ["image"])

    def test_existing_destination_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            original = output / "000.png"
            original.write_bytes(b"existing user evidence")
            with self.assertRaises(FileExistsError):
                export(Path("unused.xcresult"), output)
            self.assertEqual(original.read_bytes(), b"existing user evidence")

    def test_export_records_source_test_status_and_payload_hash(self):
        objects = {
            None: {"actions": {"_values": [{"actionResult": {"testsRef": {"id": {"_value": "tests"}}}}]}},
            "tests": {"tests": [{"identifier": {"_value": "UI/testFigure()"},
                                 "testStatus": {"_value": "Success"},
                                 "summaryRef": {"id": {"_value": "summary"}}}]},
            "summary": {"activities": [{"attachments": [
                {"name": {"_value": "Figure in dark mode"},
                 "uniformTypeIdentifier": {"_value": "public.png"},
                 "payloadRef": {"id": {"_value": "image"}}},
                {"name": {"_value": "unrelated binary"},
                 "uniformTypeIdentifier": {"_value": "public.data"},
                 "payloadRef": {"id": {"_value": "binary"}}}]}]},
        }

        def get_object(command):
            ref = command[command.index("--id") + 1] if "--id" in command else None
            return json.dumps(objects[ref]).encode()

        def export_object(command, **kwargs):
            self.assertEqual(command[command.index("--id") + 1], "image")
            Path(command[command.index("--output-path") + 1]).write_bytes(b"test image payload")

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "new-evidence"
            with patch("export_test_evidence.subprocess.check_output", side_effect=get_object), \
                 patch("export_test_evidence.subprocess.run", side_effect=export_object):
                manifest = export(Path("completed.xcresult"), output, "UI/")
            self.assertEqual(len(manifest["attachments"]), 1)
            self.assertEqual(manifest["attachments"][0], {
                "test": "UI/testFigure()", "result": "Success", "name": "Figure in dark mode",
                "file": "000.png", "sha256": hashlib.sha256(b"test image payload").hexdigest(),
            })
            self.assertEqual(json.loads((output / "manifest.json").read_text()), manifest)

    def test_filter_does_not_export_unrelated_test(self):
        root = {"actions": {"_values": [{"actionResult": {"testsRef": {"id": {"_value": "tests"}}}}]}}
        tests = {"identifier": {"_value": "Unit/testOne()"}, "summaryRef": {"id": {"_value": "skip"}}}
        with tempfile.TemporaryDirectory() as directory:
            with patch("export_test_evidence.subprocess.check_output", side_effect=[json.dumps(root), json.dumps(tests)]) as call:
                manifest = export(Path("bundle.xcresult"), Path(directory) / "output", "UI/")
            self.assertEqual(manifest["attachments"], [])
            self.assertEqual(call.call_count, 2)
