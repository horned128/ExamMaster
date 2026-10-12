import copy
import unittest
from assemble_bank import assemble
from validate import DOCS, digest, load


class AssemblyTests(unittest.TestCase):
    def setUp(self):
        self.parts = [load(p) for p in sorted((DOCS / "content").glob("*.json"))]
        self.reviews = load(DOCS / "reviews.json")["questionReviews"]
        self.snapshots = load(DOCS / "review-snapshots.json")

    def test_generated_bank_matches_sources(self):
        from validate import APP
        self.assertEqual(assemble(self.parts, self.reviews, self.snapshots), load(APP / "questions.json"))

    def test_duplicate_question_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate question"):
            assemble(self.parts + [self.parts[0]], self.reviews, self.snapshots)

    def test_held_question_cannot_enter_bank(self):
        reviews = copy.deepcopy(self.reviews)
        reviews[self.parts[0]["questions"][0]["id"]]["stage2"] = "held"
        with self.assertRaisesRegex(ValueError, "Unreviewed or held"):
            assemble(self.parts, reviews, self.snapshots)

    def test_changed_question_requires_review(self):
        self.parts[0]["questions"][0]["explanation"] += "変更"
        with self.assertRaisesRegex(ValueError, "changed after review"):
            assemble(self.parts, self.reviews, self.snapshots)

    def test_partial_year_cannot_be_mock(self):
        partial = self.parts[0]
        partial["questions"].pop()
        partial["mockSets"] = [{"id": partial["questions"][0]["mockSetID"], "title": "未完成年度", "kind": "past",
                                "questionIDs": [q["id"] for q in partial["questions"]], "questionCount": 25, "minutes": 40}]
        with self.assertRaisesRegex(ValueError, "Incomplete or invalid mock"):
            assemble(self.parts, self.reviews, self.snapshots)

    def test_wrong_mock_order_is_rejected(self):
        complete = next(p for p in self.parts if p["mockSets"])
        complete["mockSets"][0]["questionIDs"].reverse()
        with self.assertRaisesRegex(ValueError, "Incomplete or invalid mock"):
            assemble(self.parts, self.reviews, self.snapshots)


if __name__ == "__main__":
    unittest.main()
