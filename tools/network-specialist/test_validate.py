#!/usr/bin/env python3
"""Mutation checks use isolated synthetic evidence, never edit the reviewed bank."""
import contextlib
import copy
import hashlib
import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import validate


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.app = self.root / "app"
        self.docs = self.root / "docs"
        self.app.mkdir()
        (self.docs / "evidence").mkdir(parents=True)
        shutil.copytree(validate.APP / "Figures", self.app / "Figures")
        for name in ["questions.json", "qualification.json", "products.storekit"]:
            shutil.copyfile(validate.APP / name, self.app / name)
        for name in ["reviews.json", "review-snapshots.json"]:
            shutil.copyfile(validate.DOCS / name, self.docs / name)
        sources = copy.deepcopy(validate.load(validate.DOCS / "sources.json"))
        self.answer_keys = {}
        # Fake tiny PDF bytes for isolation. Official answer text and inventory stay intact.
        for year in sources["years"]:
            for doc in year["documents"]:
                path = self.docs / "evidence" / doc["file"]
                path.write_bytes(doc["file"].encode())
                doc["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
                if doc["role"] == "answers":
                    self.answer_keys[doc["file"]] = validate.official_answers(validate.DOCS / "evidence" / doc["file"])
                    name = doc["file"] + ".txt"
                    shutil.copyfile(validate.DOCS / "evidence" / name, self.docs / "evidence" / name)
        self.write(self.docs / "sources.json", sources)
        self.bank = validate.load(self.app / "questions.json")

    def write(self, path, data):
        path.write_text(json.dumps(data, ensure_ascii=False))

    def run_validation(self, release=False):
        code = 0
        with patch.object(validate, "APP", self.app), patch.object(validate, "DOCS", self.docs), \
                patch.object(validate, "official_answers", side_effect=lambda path: self.answer_keys[path.name]), \
                patch("sys.argv", ["validate.py"] + (["--release"] if release else [])), \
                contextlib.redirect_stdout(io.StringIO()):
            try:
                validate.main()
            except SystemExit as error:
                code = error.code
        return code, validate.load(self.docs / "validation-report.json")

    def test_complete_bank_passes_release(self):
        code, report = self.run_validation()
        self.assertEqual(code, 0)
        self.assertEqual(report["errors"], [])
        self.assertTrue(report["releaseReady"])
        self.assertEqual(report["included"], 375)
        self.assertEqual((report["free"], report["paid"]), (75, 300))
        self.assertEqual(self.run_validation(release=True)[0], 0)

    def test_missing_historical_question_and_mock_still_block_release(self):
        self.bank["questions"] = [q for q in self.bank["questions"] if q["id"] != "nw-2015-autumn-q09"]
        self.bank["mockSets"] = [s for s in self.bank["mockSets"] if s["id"] != "nw-2015-autumn"]
        self.write(self.app / "questions.json", self.bank)
        code, report = self.run_validation(release=True)
        self.assertEqual(code, 1)
        self.assertEqual(report["errors"], [])
        self.assertFalse(report["releaseReady"])
        self.assertTrue(any("2015" in error for error in report["incomplete"]))

    def test_changed_text_requires_review(self):
        self.bank["questions"][0]["stem"] += "内容変更"
        self.write(self.app / "questions.json", self.bank)
        code, report = self.run_validation()
        self.assertEqual(code, 1)
        self.assertTrue(any("校合後に内容変更" in error for error in report["errors"]))

    def test_changed_figure_requires_review_even_with_same_filename(self):
        path = self.app / "Figures" / "nw-2025-q08-network.png"
        path.write_bytes(path.read_bytes() + b"changed")
        code, report = self.run_validation()
        self.assertEqual(code, 1)
        self.assertTrue(any("nw-2025-spring-q08:校合後に内容変更" in error for error in report["errors"]))

    def test_missing_figure_fails_without_crashing(self):
        (self.app / "Figures" / "nw-2025-q08-network.png").unlink()
        code, report = self.run_validation()
        self.assertEqual(code, 1)
        self.assertTrue(any("図版欠落" in error for error in report["errors"]))

    def test_missing_source_is_rejected(self):
        (self.docs / "evidence" / "2025r07h_nw_am2_qs.pdf").unlink()
        code, report = self.run_validation()
        self.assertEqual(code, 1)
        self.assertTrue(any("原本欠落" in error for error in report["errors"]))

    def test_wrong_official_answer_and_paid_free_mismatch_are_rejected(self):
        next(q for q in self.bank["questions"] if q["id"] == "nw-2025-spring-q01")["correctIndex"] = 0
        self.write(self.app / "questions.json", self.bank)
        config = validate.load(self.app / "qualification.json")
        config["freeQuestionIDs"] = config["freeQuestionIDs"][1:]
        self.write(self.app / "qualification.json", config)
        code, report = self.run_validation()
        self.assertEqual(code, 1)
        self.assertTrue(any("公式正答不一致" in error for error in report["errors"]))
        self.assertIn("無料ID集合", report["errors"])

    def test_changed_answer_sidecar_is_rejected_against_pdf(self):
        path = self.docs / "evidence" / "2025r07h_nw_am2_ans.pdf.txt"
        path.write_text(path.read_text().replace("エ", "ア", 1))
        code, report = self.run_validation()
        self.assertEqual(code, 1)
        self.assertIn("2025:正答テキストと原本PDFが不一致", report["errors"])

    def test_unpublished_official_question_is_rejected(self):
        question = copy.deepcopy(next(q for q in self.bank["questions"] if q["kind"] == "past"))
        question.update(id="nw-2020-spring-q01", year=2020, mockSetID="nw-2020-spring",
                        source="ネットワークスペシャリスト試験 2020年春期 午前Ⅱ 問1")
        self.bank["questions"].append(question)
        self.write(self.app / "questions.json", self.bank)
        code, report = self.run_validation()
        self.assertEqual(code, 1)
        self.assertIn("公式原本にない年度/期/問番号", report["errors"])

    def test_reordered_or_mislabeled_mock_is_rejected(self):
        mock = next(s for s in self.bank["mockSets"] if s["kind"] == "past")
        mock["questionIDs"].reverse()
        mock["kind"] = "prediction"
        self.write(self.app / "questions.json", self.bank)
        code, report = self.run_validation()
        self.assertEqual(code, 1)
        self.assertTrue(any("原問順" in error for error in report["errors"]))
        self.assertTrue(any("過去問/予想の混在" in error for error in report["errors"]))


if __name__ == "__main__":
    unittest.main()
