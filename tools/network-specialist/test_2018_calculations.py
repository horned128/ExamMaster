"""Verify the complete 2018 bank, official keys, and historical-answer caveats."""
from fractions import Fraction
import ipaddress
import re
import unittest
from urllib.parse import urlsplit
from validate import APP, DOCS, load, official_answers


class Calculations2018Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part = load(DOCS / "content/2018.json")
        cls.questions = {q["questionNumber"]: q for q in cls.part["questions"]}

    def test_official_answers_complete_mock_and_historical_caveat(self):
        answers = official_answers(DOCS / "evidence/2018h30a_nw_am2_ans.pdf")
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertTrue(all(q["correctIndex"] == answers[n] for n, q in self.questions.items()))
        question = self.questions[17]
        self.assertIn("当時の公式正答で採点", question["explanation"])
        self.assertIn("任意", question["explanation"])
        self.assertIn("RFC5281", question["explanation"])
        self.assertIn("任意で利用", question["choiceExplanations"][3])
        mock, = self.part["mockSets"]
        self.assertEqual(mock["questionIDs"], [self.questions[n]["id"] for n in range(1, 26)])
        self.assertEqual((mock["questionCount"], mock["minutes"]), (25, 40))
        bank = load(APP / "questions.json")
        self.assertIn(question, bank["questions"])
        self.assertIn(mock, bank["mockSets"])
        self.assertFalse(self.part["isDraft"])

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
