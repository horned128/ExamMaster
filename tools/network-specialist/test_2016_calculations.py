"""Checks read from 2016 official figures/tables, not inferred from answers."""
from collections import defaultdict
import ipaddress
import itertools
import re
import unittest
from validate import DOCS, load, official_answers


class Calculations2016Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part = load(DOCS / "content/2016.json")
        cls.questions = {q["questionNumber"]: q for q in cls.part["questions"]}

    def test_original_answers_and_complete_original_order_mock(self):
        answers = official_answers(DOCS / "evidence/2016h28a_nw_am2_ans.pdf")
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertEqual({n: q["correctIndex"] for n, q in self.questions.items()}, answers)
        mock, = self.part["mockSets"]
        self.assertEqual(mock["id"], "nw-2016-autumn")
        self.assertEqual(mock["questionCount"], 25)
        self.assertEqual(mock["minutes"], 40)
        self.assertEqual(mock["questionIDs"], [self.questions[n]["id"] for n in range(1, 26)])
        for question in self.questions.values():
            self.assertEqual(question["mockSetID"], mock["id"])
            self.assertEqual(len(question["choiceExplanations"]), 4)
            self.assertTrue(all(question["choiceExplanations"]))
            self.assertTrue(question["steps"])

    def test_capacity_all_cuts_and_conserving_feasible_flow_agree(self):
        q = self.questions[3]
        edges = [("X", "A", 4), ("X", "B", 4), ("X", "C", 3),
                 ("A", "B", 2), ("B", "C", 1), ("A", "D", 1),
                 ("B", "D", 2), ("B", "E", 3), ("C", "F", 4),
                 ("D", "E", 2), ("E", "F", 2), ("E", "G", 4),
                 ("F", "G", 3), ("D", "Y", 3), ("E", "Y", 3), ("G", "Y", 6)]
        alt = q["bodyBlocks"][1]["altText"]
        self.assertEqual([(a, b, int(c)) for a, b, c in re.findall(r"([X-YA-G])-([X-YA-G]):(\d+)", alt)], edges)
        cuts = []
        for states in itertools.product([False, True], repeat=7):
            source = {"X"} | {node for node, belongs in zip("ABCDEFG", states) if belongs}
            cuts.append(sum(cap for a, b, cap in edges if (a in source) != (b in source)))
        self.assertEqual(min(cuts), 10)
        capacities = {frozenset((a, b)): cap for a, b, cap in edges}
        witness = [("X", "A", 3), ("X", "B", 4), ("X", "C", 3),
                   ("A", "D", 1), ("A", "B", 2), ("B", "D", 2),
                   ("B", "E", 3), ("B", "C", 1), ("C", "F", 4),
                   ("F", "E", 1), ("F", "G", 3), ("D", "Y", 3),
                   ("E", "Y", 3), ("E", "G", 1), ("G", "Y", 4)]
        balance = defaultdict(int)
        for a, b, flow in witness:
            self.assertLessEqual(flow, capacities[frozenset((a, b))])
            balance[a] -= flow
            balance[b] += flow
        self.assertEqual(balance["X"], -10)
        self.assertEqual(balance["Y"], 10)
        self.assertTrue(all(balance[node] == 0 for node in "ABCDEFG"))
        self.assertEqual(int(q["choices"][q["correctIndex"]]), min(cuts))

    def test_ospf_all_simple_shortest_routes_both_directions(self):
        q = self.questions[4]
        fixed = [("a", "b", 30), ("a", "d", 40), ("c", "b", 50), ("c", "d", 40),
                 ("b", "e", 100), ("d", "g", 100), ("e", "f", 40), ("e", "h", 30),
                 ("f", "i", 10), ("h", "i", 10)]
        self.assertEqual([(a, b, int(c)) for a, b, c in re.findall(r"([a-i])-([a-i]):(\d+)", q["bodyBlocks"][1]["altText"])],
                         [e for e in fixed if e[0:2] not in [("b", "e"), ("d", "g")]])

        def shortest(start, end, k):
            graph = defaultdict(list)
            for a, b, cost in fixed + [("g", "f", k), ("g", "h", k)]:
                graph[a].append((b, cost))
                graph[b].append((a, cost))
            routes = []

            def visit(node, seen, path, cost):
                if node == end:
                    routes.append((cost, path))
                    return
                for following, price in graph[node]:
                    if following not in seen:
                        visit(following, seen | {following}, path + [(node, following)], cost + price)

            visit(start, {start}, [], 0)
            minimum = min(cost for cost, _ in routes)
            return minimum, [path for cost, path in routes if cost == minimum]

        acceptable = []
        for index, choice in enumerate(q["choiceBlocks"]):
            x, y = map(int, choice[0]["rows"][0])
            self.assertEqual(x, y)
            works = True
            for start, end, wan in [("a", "i", ("b", "e")), ("c", "i", ("d", "g")),
                                    ("i", "a", ("e", "b")), ("i", "c", ("g", "d"))]:
                _, paths = shortest(start, end, x)
                works &= all(wan in path for path in paths)
            if works:
                acceptable.append(index)
        self.assertEqual(acceptable, [q["correctIndex"]])
        self.assertEqual(shortest("a", "i", 30)[0], 170)
        self.assertEqual(shortest("c", "i", 30)[0], 180)

    def test_single_aggregate_covers_all_49_networks_with_longest_prefix(self):
        q = self.questions[11]
        targets = [ipaddress.IPv4Network(f"192.168.{n}.0/24") for n in range(10, 59)]
        candidates = [ipaddress.IPv4Network(choice) for choice in q["choices"]]
        possible = [index for index, subnet in enumerate(candidates) if all(t.subnet_of(subnet) for t in targets)]
        selected = max(possible, key=lambda index: candidates[index].prefixlen)
        self.assertEqual(selected, q["correctIndex"])
        self.assertEqual(str(candidates[selected]), "192.168.0.0/18")
        first, last = targets[0].network_address, targets[-1].broadcast_address
        prefix = 32 - (int(first) ^ int(last)).bit_length()
        self.assertEqual(prefix, candidates[selected].prefixlen)
        self.assertFalse(targets[-1].subnet_of(candidates[3]))

    def test_longest_matching_route_excludes_nearby_more_specifics(self):
        q = self.questions[13]
        destination = ipaddress.IPv4Address(re.search(r"宛先IPアドレス([\d.]+)", q["stem"]).group(1))
        rows = q["bodyBlocks"][2]["rows"]
        routes = [(ipaddress.IPv4Network(f"{address}/{mask}"), hop) for address, mask, hop in rows]
        matches = [(subnet, hop) for subnet, hop in routes if destination in subnet]
        self.assertEqual([s.prefixlen for s, _ in matches], [8, 0])
        selected = max(matches, key=lambda item: item[0].prefixlen)
        self.assertEqual(selected[1], "192.168.1.254")
        self.assertEqual(q["choices"][q["correctIndex"]], "ルータA")
        self.assertEqual([100 & mask for mask in [224, 252, 128]], [96, 100, 0])
        for _, _, hop in rows:
            self.assertIn(hop, q["bodyBlocks"][1]["altText"])

    def test_static_smtp_two_way_ports_and_test_stage_tables_preserved(self):
        q = self.questions[20]
        self.assertEqual(q["choiceBlocks"][q["correctIndex"]][0]["rows"],
                         [["PC", "SMTPサーバ", "1024以上", "25"], ["SMTPサーバ", "PC", "25", "1024以上"]])
        self.assertTrue(all(len(blocks[0]["headers"]) == 4 and len(blocks[0]["rows"]) == 2 for blocks in q["choiceBlocks"]))
        q = self.questions[24]
        self.assertEqual(q["choiceBlocks"][q["correctIndex"]][0]["rows"],
                         [["システム結合テスト", "ソフトウェア結合テスト", "ソフトウェアユニットテスト"]])

    def test_current_caveats_and_non_answer_leaking_esp_alt(self):
        q = self.questions[7]
        alt = q["bodyBlocks"][1]["altText"]
        self.assertIn("7区画", alt)
        self.assertNotIn("からESPトレーラまで", alt)
        self.assertIn("NULL", q["explanation"])
        self.assertIn("RFC3253", self.questions[14]["explanation"])
        self.assertIn("拡張CONNECT", self.questions[15]["explanation"])
        self.assertIn("ARP Probe", self.questions[6]["explanation"])
        self.assertIn("更新済み実装", self.questions[18]["explanation"])


if __name__ == "__main__":
    unittest.main()
