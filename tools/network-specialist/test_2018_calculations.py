"""Check actual 2018 data; never complete its held question or mock."""
from fractions import Fraction
import ipaddress
import re
import unittest
from urllib.parse import urlsplit
from assemble_bank import assemble
from validate import APP, DOCS, load, official_answers


class Calculations2018Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part = load(DOCS / "content/2018.json")
        cls.questions = {q["questionNumber"]: q for q in cls.part["questions"]}

    def test_original_answers_and_hold_not_bundled_or_mocked(self):
        answers = official_answers(DOCS / "evidence/2018h30a_nw_am2_ans.pdf")
        self.assertEqual(set(answers), set(range(1, 26)))
        self.assertEqual(set(self.questions), set(range(1, 26)) - {17})
        self.assertTrue(all(q["correctIndex"] == answers[n] for n, q in self.questions.items()))
        self.assertEqual(self.part["mockSets"], [])
        candidate = load(DOCS / "candidates/2018-q17.json")
        question = candidate["questions"][0]
        self.assertEqual(question["correctIndex"], answers[17])
        reviews = load(DOCS / "reviews.json")["questionReviews"]
        self.assertEqual(reviews[question["id"]]["stage2"], "held")
        with self.assertRaisesRegex(ValueError, "Unreviewed or held question"):
            assemble([candidate], reviews, load(DOCS / "review-snapshots.json"))
        bank = load(APP / "questions.json")
        self.assertNotIn(question["id"], {q["id"] for q in bank["questions"]})
        self.assertNotIn("nw-2018-autumn", {s["id"] for s in bank["mockSets"]})

    def test_hexadecimal_mask_host_count(self):
        q = self.questions[10]
        digits = re.search(r"16進数の([0-9A-F]{8})", q["stem"]).group(1)
        mask = ipaddress.IPv4Address(int(digits, 16))
        subnet = ipaddress.IPv4Network(f"172.16.0.0/{mask}")
        self.assertEqual(str(mask), "255.255.255.128")
        self.assertEqual(subnet.prefixlen, 25)
        self.assertEqual(subnet.num_addresses, 128)
        self.assertEqual(len(list(subnet.hosts())), 126)
        self.assertEqual(q["choices"][q["correctIndex"]], str(len(list(subnet.hosts()))))
        self.assertEqual(list(map(int, q["choices"])), [126, 127, 254, 255])

    def test_url_query_is_not_authority_port(self):
        q = self.questions[14]
        address = re.search(r"https://[^と]+", q["stem"]).group()
        url = urlsplit(address)
        self.assertEqual(url.scheme, "https")
        self.assertEqual(url.hostname, "ftp.example.jp")
        self.assertEqual(url.path, "/index.cgi")
        self.assertEqual(url.query, "port=123")
        self.assertIsNone(url.port)
        self.assertEqual(q["choices"][q["correctIndex"]], str(url.port or {"https": 443}[url.scheme]))
        # An explicit authority port, unlike the original query, changes it.
        self.assertEqual(urlsplit("https://ftp.example.jp:123/index.cgi").port, 123)

    def test_multiprocessor_limit_exact_gap_and_monotonicity(self):
        q = self.questions[23]
        self.assertIn("オーバヘッドを表す定数", q["stem"])
        self.assertEqual(q["bodyBlocks"][1]["text"], "P = n / {1 + (n - 1)a}")
        a = Fraction(1, 10)
        bound = 1 / a
        performance = lambda n: Fraction(n) / (1 + (n - 1) * a)
        self.assertEqual(performance(1), 1)
        self.assertEqual(performance(4), Fraction(40, 13))
        for n in [1, 2, 4, 10, 100, 1000, 1_000_000]:
            with self.subTest(n=n):
                p = performance(n)
                self.assertEqual(p, 1 / (a + (1 - a) / n))
                self.assertEqual(bound - p, Fraction(90, n + 9))
                self.assertGreater(p, 0)
                self.assertLess(p, bound)
                self.assertGreater(performance(n + 1), p)
        self.assertLess(bound - performance(1_000_000), Fraction(1, 10_000))
        self.assertEqual(Fraction(q["choices"][q["correctIndex"]]), bound)


if __name__ == "__main__":
    unittest.main()
