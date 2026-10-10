"""Enumerate all simple routes independently of the OSPF explanation."""
from collections import defaultdict
import re
import unittest
from validate import DOCS, load, official_answers


class Routes2019Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.questions = {q["questionNumber"]: q for q in load(DOCS / "content/2019.json")["questions"]}

    def test_original_answer_pdf_and_complete_set(self):
        answers = official_answers(DOCS / "evidence/2019r01a_nw_am2_ans.pdf")
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertEqual({n: q["correctIndex"] for n, q in self.questions.items()}, answers)

    def test_ospf_every_shortest_route_uses_intended_wan(self):
        q = self.questions[2]
        fixed = [("a", "b", 30), ("a", "d", 40), ("c", "b", 50), ("c", "d", 40),
                 ("b", "e", 100), ("d", "g", 100), ("e", "f", 40), ("e", "h", 30),
                 ("f", "i", 10), ("h", "i", 10)]
        alt = q["bodyBlocks"][1]["altText"]
        self.assertEqual([(a, b, int(c)) for a, b, c in re.findall(r"([a-i])-([a-i])(\d+)", alt)], fixed)
        self.assertIn("g-f x", alt)
        self.assertIn("g-h y", alt)
        eligible, distances = [], []
        for index, blocks in enumerate(q["choiceBlocks"]):
            x, y = map(int, blocks[0]["rows"][0])
            graph = defaultdict(list)
            for a, b, cost in fixed + [("g", "f", x), ("g", "h", y)]:
                graph[a].append((b, cost))
                graph[b].append((a, cost))
            shortest = {}
            for start in ("a", "c"):
                routes = []
                def visit(node, route, cost):
                    if node == "i":
                        routes.append((cost, route))
                        return
                    for next_node, weight in graph[node]:
                        if next_node not in route:
                            visit(next_node, route + [next_node], cost + weight)
                visit(start, [start], 0)
                least = min(cost for cost, _ in routes)
                shortest[start] = [route for cost, route in routes if cost == least]
                distances.append((index, start, least))
            def uses_wan(route, endpoints):
                return any(set(edge) == endpoints for edge in zip(route, route[1:]))
            if all(uses_wan(p, {"b", "e"}) for p in shortest["a"]) and all(uses_wan(p, {"d", "g"}) for p in shortest["c"]):
                eligible.append(index)
            # Equal-cost paths at 20/40 include an unwanted WAN, not just
            # multiple equal paths inside the intended WAN.
            if index == 0:
                self.assertTrue(any(uses_wan(p, {"d", "g"}) for p in shortest["a"]))
            if index == 2:
                self.assertTrue(any(uses_wan(p, {"b", "e"}) for p in shortest["c"]))
        self.assertEqual(eligible, [q["correctIndex"]])
        self.assertEqual(distances, [(0, "a", 170), (0, "c", 170), (1, "a", 170), (1, "c", 180),
                                     (2, "a", 170), (2, "c", 190), (3, "a", 170), (3, "c", 190)])


if __name__ == "__main__":
    unittest.main()
