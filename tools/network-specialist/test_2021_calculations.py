"""Exact independent checks for the official 2021 calculation problems."""
from collections import defaultdict
from fractions import Fraction
import ipaddress
import itertools
import re
import unittest
from validate import DOCS, load, official_answers


class Calculations2021Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.questions = {q["questionNumber"]: q for q in load(DOCS / "content/2021.json")["questions"]}

    def test_original_answer_pdf_and_complete_set(self):
        answers = official_answers(DOCS / "evidence/2021r03h_nw_am2_ans.pdf")
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertEqual({n: q["correctIndex"] for n, q in self.questions.items()}, answers)

    def test_capacity_min_cut_and_feasible_flow(self):
        question = self.questions[4]
        # These capacities were read from the original diagram, not the answer.
        edges = [("X", "A", 4), ("X", "B", 4), ("X", "C", 3),
                 ("A", "B", 2), ("B", "C", 1), ("A", "D", 1),
                 ("B", "D", 2), ("B", "E", 3), ("C", "F", 4),
                 ("D", "E", 2), ("E", "F", 2), ("E", "G", 4),
                 ("F", "G", 3), ("D", "Y", 3), ("E", "Y", 3), ("G", "Y", 6)]
        alt = question["bodyBlocks"][1]["altText"]
        self.assertEqual([(a, b, int(c)) for a, b, c in re.findall(r"([XABCDEFGY])-([XABCDEFGY])(\d+)", alt)], edges)
        cuts = []
        for flags in itertools.product((False, True), repeat=7):
            left = {"X"} | {v for v, present in zip("ABCDEFG", flags) if present}
            cuts.append(sum(c for a, b, c in edges if (a in left) != (b in left)))
        self.assertEqual(len(cuts), 128)
        self.assertEqual(min(cuts), 10)
        flow = [("X", "A", 3), ("X", "B", 4), ("X", "C", 3),
                ("A", "D", 1), ("A", "B", 2), ("B", "D", 2),
                ("B", "E", 3), ("B", "C", 1), ("C", "F", 4),
                ("F", "E", 1), ("F", "G", 3), ("D", "Y", 3),
                ("E", "Y", 3), ("E", "G", 1), ("G", "Y", 4)]
        capacities = {frozenset((a, b)): c for a, b, c in edges}
        used, balance = defaultdict(int), defaultdict(int)
        for a, b, value in flow:
            used[frozenset((a, b))] += value
            balance[a] -= value
            balance[b] += value
        self.assertTrue(all(value <= capacities[edge] for edge, value in used.items()))
        self.assertTrue(all(balance[v] == 0 for v in "ABCDEFG"))
        self.assertEqual(balance["X"], -10)
        self.assertEqual(balance["Y"], min(cuts))
        self.assertEqual(int(question["choices"][question["correctIndex"]]), balance["Y"])

    def test_mtu_and_all_distractors(self):
        question = self.questions[7]
        self.assertIn("1,500", question["stem"])
        values = [int(v.replace(",", "")) for v in question["choices"]]
        self.assertEqual(values, [1500 - 14 - 20 - 20, 1500 - 20 - 20 - 4, 1500 - 20 - 20, 1500 - 20])
        self.assertEqual(values[question["correctIndex"]], 1460)

    def test_nonoverlapping_subnet_and_broadcast(self):
        question = self.questions[10]
        existing = [ipaddress.ip_network(v) for v in ("172.16.1.32/27", "172.16.1.224/30", "172.16.1.64/26")]
        candidates = [ipaddress.ip_network("/".join(blocks[0]["rows"][0])) for blocks in question["choiceBlocks"]]
        eligible = [i for i, candidate in enumerate(candidates) if not any(candidate.overlaps(e) for e in existing)]
        self.assertEqual(eligible, [question["correctIndex"]])
        self.assertEqual(str(candidates[2]), "172.16.1.128/26")
        question = self.questions[14]
        address = re.search(r"192\.168\.10\.192/28", question["stem"]).group()
        subnet = ipaddress.ip_network(address)
        self.assertEqual(subnet.num_addresses, 16)
        self.assertEqual(str(subnet.broadcast_address), question["choices"][question["correctIndex"]])

    def test_weighted_cpi_and_milliseconds(self):
        question = self.questions[22]
        rows = question["bodyBlocks"][1]["rows"]
        self.assertEqual(rows, [["浮動小数点加算", "3", "20"], ["浮動小数点乗算", "5", "20"], ["整数演算", "2", "60"]])
        self.assertEqual(sum(int(row[2]) for row in rows), 100)
        average = sum(Fraction(row[1]) * Fraction(int(row[2]), 100) for row in rows)
        self.assertEqual(average, Fraction(14, 5))
        milliseconds = 1_000_000 * average / 1_000_000_000 * 1000
        self.assertEqual(milliseconds, Fraction(question["choices"][question["correctIndex"]]))

    def test_mm1_response_time_and_littles_law(self):
        question = self.questions[23]
        self.assertTrue(all(value in question["stem"] for value in ("6個", "7,500", "50バイト", "M/M/1")))
        arrival, service = Fraction(6, 3600), Fraction(50, 7500)
        utilization = arrival / service
        self.assertEqual(utilization, Fraction(1, 4))
        response = 1 / (service - arrival)
        mean_count = utilization / (1 - utilization)
        self.assertEqual(mean_count / arrival, response)
        self.assertEqual(response, 200)
        self.assertEqual(response - 1 / service, 50)
        self.assertEqual(response, Fraction(question["choices"][question["correctIndex"]]))


if __name__ == "__main__":
    unittest.main()
