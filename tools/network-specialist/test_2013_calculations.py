"""Independent numeric/structural checks for the original 2013 booklet."""
import base64
from email import policy
from email.parser import Parser
from fractions import Fraction
import ipaddress
import itertools
import re
import unittest
from urllib.parse import parse_qs, urlsplit
import fitz
from validate import APP, DOCS, load, official_answers


class Calculations2013Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part = load(DOCS / "content/2013.json")
        cls.questions = {q["questionNumber"]: q for q in cls.part["questions"]}

    def test_original_answers_and_complete_original_order_mock(self):
        answers = official_answers(DOCS / "evidence/2013h25a_nw_am2_ans.pdf")
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertEqual({n: q["correctIndex"] for n, q in self.questions.items()}, answers)
        mock, = self.part["mockSets"]
        self.assertEqual(mock["id"], "nw-2013-autumn")
        self.assertEqual((mock["questionCount"], mock["minutes"]), (25, 40))
        self.assertEqual(mock["questionIDs"], [self.questions[n]["id"] for n in range(1, 26)])
        for q in self.questions.values():
            self.assertEqual(q["mockSetID"], mock["id"])
            self.assertEqual(len(q["choiceExplanations"]), 4)
            self.assertTrue(all(q["choiceExplanations"]))
            self.assertTrue(q["steps"])

    def test_transmission_overhead_exact_gap_count_and_nearest_choice(self):
        q = self.questions[2]
        self.assertIn("128×10³バイト", q["stem"])
        self.assertIn("128kビット／秒", q["stem"])
        self.assertIn("長さは128バイト", q["stem"])
        self.assertIn("データは100バイト", q["stem"])
        self.assertIn("平均1ミリ秒", q["stem"])
        count = 128 * 10 ** 3 // 100
        packet = Fraction(128 * 8, 128 * 10 ** 3)
        gap = Fraction(1, 1000)
        exact = count * packet + (count - 1) * gap
        # An explicit event timeline independently avoids the trailing gap.
        start = Fraction(0)
        for index in range(count):
            finish = start + packet
            if index != count - 1:
                start = finish + gap
        self.assertEqual(finish, exact)
        self.assertEqual(exact, Fraction(11519, 1000))
        simplified = count * (packet + gap)
        self.assertEqual(simplified - exact, gap)
        alternatives = list(map(Fraction, q["choices"]))
        self.assertEqual(min(range(4), key=lambda i: abs(alternatives[i] - exact)), q["correctIndex"])
        self.assertEqual(alternatives[q["correctIndex"]], 12)
        self.assertEqual(Fraction(128 * 10 ** 3 * 8, 128 * 10 ** 3), 8)

    def test_ospf_all_simple_paths_both_directions_and_all_four_choices(self):
        q = self.questions[4]
        expected = [[170, 170, 190, 170], [170, 180, 190, 180],
                    [170, 190, 190, 190], [170, 200, 190, 200]]
        eligible = []
        for index, blocks in enumerate(q["choiceBlocks"]):
            table, = blocks
            self.assertEqual(table["headers"], ["x", "y"])
            x, y = map(int, table["rows"][0])
            self.assertEqual(x, y)
            self.assertEqual(q["choices"][index], f"x：{x}，y：{y}")
            edges = {("a", "b"): 30, ("a", "d"): 40, ("c", "b"): 50, ("c", "d"): 40,
                     ("b", "e"): 100, ("d", "g"): 100, ("e", "f"): 40, ("e", "h"): 30,
                     ("g", "f"): x, ("g", "h"): y, ("f", "i"): 10, ("h", "i"): 10}
            adjacency = {node: [] for node in "abcdefghi"}
            for (left, right), cost in edges.items():
                adjacency[left].append((right, cost))
                adjacency[right].append((left, cost))

            def paths(source, destination):
                found = []

                def visit(node, path, cost):
                    if node == destination:
                        found.append((cost, path))
                        return
                    for neighbor, weight in adjacency[node]:
                        if neighbor not in path:
                            visit(neighbor, path + [neighbor], cost + weight)
                visit(source, [source], 0)
                return found

            def wan_set(path):
                pairs = {frozenset(pair) for pair in zip(path, path[1:])}
                return {label for label, pair in [("WAN1", ("b", "e")), ("WAN2", ("d", "g"))]
                        if frozenset(pair) in pairs}

            costs, preference = [], []
            for source, wanted in [("a", "WAN1"), ("c", "WAN2")]:
                forward = paths(source, "i")
                reverse = paths("i", source)
                self.assertEqual(sorted((c, tuple(p)) for c, p in forward),
                                 sorted((c, tuple(reversed(p))) for c, p in reverse))
                for label in ["WAN1", "WAN2"]:
                    costs.append(min(cost for cost, path in forward if wan_set(path) == {label}))
                minimum = min(cost for cost, _ in forward)
                shortest = [wan_set(path) for cost, path in forward if cost == minimum]
                preference.append(all(value == {wanted} for value in shortest))
            self.assertEqual(costs, expected[index])
            self.assertEqual(q["explanationBlocks"][0]["rows"][index][1:3],
                             [f"{costs[0]} / {costs[1]}", f"{costs[2]} / {costs[3]}"])
            if all(preference):
                eligible.append(index)
        self.assertEqual(eligible, [q["correctIndex"]])
        self.assertEqual(eligible, [1])

    def test_tcp_original_four_sequences_and_syn_consumes_one(self):
        q = self.questions[13]
        sequences = [[("要求元", "要求先", "SYN"), ("要求先", "要求元", "SYN＋ACK"), ("要求元", "要求先", "ACK")],
                     [("要求元", "要求先", "SYN"), ("要求先", "要求元", "ACK"), ("要求先", "要求元", "SYN"), ("要求元", "要求先", "ACK"), ("要求元", "要求先", "SYN"), ("要求先", "要求元", "ACK")],
                     [("要求元", "要求先", "SYN")] * 3 + [("要求先", "要求元", "ACK")],
                     [("要求元", "要求先", "SYN"), ("要求先", "要求元", "ACK")] * 3]
        for choice, expected in zip(q["choices"], sequences):
            actual = re.findall(r"(?:コネクション)?(要求元|要求先)→(要求元|要求先) (SYN＋ACK|SYN|ACK)", choice)
            self.assertEqual(actual, expected)
        self.assertEqual(q["correctIndex"], 0)
        self.assertEqual([b[0]["assetName"] for b in q["choiceBlocks"]], [f"nw-2013-q13-{s}.png" for s in ["a", "i", "u", "e"]])
        for initial_a, initial_b in [(100, 300), (0, 17), (65535, 12345)]:
            a_next, b_next = initial_a + 1, initial_b + 1
            self.assertEqual(a_next - initial_a, 1)
            self.assertEqual(b_next - initial_b, 1)
            # ACK alone consumes no sequence-space byte.
            final_ack_seq, final_ack_number = a_next, b_next
            self.assertEqual((final_ack_seq, final_ack_number), (initial_a + 1, initial_b + 1))
        self.assertIn("SYNはシーケンス番号を一つ消費", q["explanation"])

    def test_aggregation_minimum_single_prefix_and_extra_network(self):
        q = self.questions[14]
        self.assertIn("192.168.1.0/24〜192.168.15.0/24", q["stem"])
        originals = [ipaddress.IPv4Network(f"192.168.{n}.0/24") for n in range(1, 16)]
        choices = list(map(ipaddress.IPv4Network, q["choices"]))
        includes = [all(network.subnet_of(choice) for network in originals) for choice in choices]
        self.assertEqual(includes, [True, True, False, False])
        eligible = [i for i, included in enumerate(includes) if included]
        correct = max(eligible, key=lambda i: choices[i].prefixlen)
        self.assertEqual(correct, q["correctIndex"])
        self.assertEqual(str(choices[correct]), "192.168.0.0/20")
        self.assertEqual(choices[correct].num_addresses - sum(n.num_addresses for n in originals), 256)
        self.assertTrue(ipaddress.IPv4Network("192.168.0.0/24").subnet_of(choices[correct]))
        collapsed = list(ipaddress.collapse_addresses(originals))
        self.assertEqual(list(map(str, collapsed)), ["192.168.1.0/24", "192.168.2.0/23", "192.168.4.0/22", "192.168.8.0/21"])
        self.assertIn("対象外の0.0/24も含み", q["explanation"])

    def test_url_literal_query_port_not_authority_port(self):
        q = self.questions[15]
        literal = q["bodyBlocks"][1]["text"]
        self.assertEqual(literal, "https://ftp.example.jp/index.cgi?port=123")
        self.assertIn(literal, q["stem"])
        url = urlsplit(literal)
        self.assertEqual((url.scheme, url.hostname, url.port, url.path), ("https", "ftp.example.jp", None, "/index.cgi"))
        self.assertEqual(parse_qs(url.query), {"port": ["123"]})
        self.assertEqual(int(q["choices"][q["correctIndex"]]), {"https": 443}[url.scheme])
        self.assertEqual(urlsplit("https://ftp.example.jp:123/index.cgi").port, 123)
        self.assertIn("TCPポート", q["stem"])
        self.assertNotIn("HTTP/3", q["stem"])
        self.assertIn("HTTP/3", q["explanation"])

    def test_mime_original_base64_roundtrip_and_valid_display_name(self):
        q = self.questions[16]
        token = "=?ISO-2022-JP?B?GyRCPnBKc0JATzobKEI=?="
        self.assertIn(token, q["stem"])
        self.assertEqual(base64.b64encode("情報太郎".encode("iso2022_jp")).decode("ascii"), "GyRCPnBKc0JATzobKEI=")
        self.assertEqual(base64.b64decode("GyRCPnBKc0JATzobKEI=", validate=True).decode("iso2022_jp"), "情報太郎")
        self.assertEqual("".join(block["text"] for block in q["bodyBlocks"]), q["stem"])
        self.assertEqual(q["choices"], [f"From: <{token}> taro@example.jp", f"From: <taro@example.jp> {token}",
                                         f"From: {token} <taro@example.jp>", f"From: taro@example.jp <{token}>"])
        for choice, blocks in zip(q["choices"], q["choiceBlocks"]):
            self.assertEqual(blocks, [{"type": "monospace", "text": choice}])
        correct = q["choices"][q["correctIndex"]]
        header = Parser(policy=policy.default).parsestr(correct + "\n\n")["From"]
        self.assertFalse(header.defects)
        address, = header.addresses
        self.assertEqual((address.display_name, address.addr_spec), ("情報太郎", "taro@example.jp"))
        self.assertEqual(q["correctIndex"], 2)

    def test_pairwise_shared_keys_enumeration_and_sum_agree(self):
        q = self.questions[18]
        people = int(re.search(r"(\d+)人", q["stem"]).group(1))
        pairs = list(itertools.combinations(range(people), 2))
        self.assertEqual(len(pairs), people * (people - 1) // 2)
        self.assertEqual(len(pairs), sum(range(people)))
        self.assertEqual(len(pairs), 4950)
        self.assertEqual(int(q["choices"][q["correctIndex"]].replace(",", "")), len(pairs))
        self.assertEqual(people * (people - 1), 9900)
        self.assertTrue(all(a < b for a, b in pairs))

    def test_pipeline_completion_schedule_and_single_instruction(self):
        q = self.questions[22]
        self.assertEqual(q["choices"], ["（I＋D）×P", "（I＋D−1）×P", "（I×D）＋P", "（I×D−1）＋P"])
        self.assertEqual(q["correctIndex"], 1)
        for instructions, depth in itertools.product([1, 2, 5, 10], [1, 3, 5]):
            stage_finish = [[instruction + stage + 1 for stage in range(depth)] for instruction in range(instructions)]
            pitch = Fraction(3, 1000)
            simulated = stage_finish[-1][-1] * pitch
            self.assertEqual(simulated, (instructions + depth - 1) * pitch)
            if instructions == 1:
                self.assertEqual(simulated, depth * pitch)
        self.assertIn("パイプラインは1本だけ", q["stem"])
        self.assertIn("ハザード", q["stem"])

    def test_parallel_performance_limit_gap_and_original_example(self):
        q = self.questions[24]
        self.assertIn("P = n / (1＋(n−1)a)", q["stem"])
        self.assertIn("aはオーバヘッドを表す定数", q["stem"])
        a = Fraction(1, 10)
        upper = 1 / a
        last = 0
        for n in [1, 4, 10, 100, 1024, 10 ** 6]:
            original = Fraction(n, 1 + (n - 1) * a)
            divided = 1 / (a + (1 - a) / n)
            self.assertEqual(original, divided)
            self.assertLess(original, upper)
            self.assertEqual(upper - original, Fraction(90, n + 9))
            self.assertGreater(original, last)
            last = original
        self.assertEqual(Fraction(4, 1 + 3 * a), Fraction(40, 13))
        self.assertEqual(int(q["choices"][q["correctIndex"]]), upper)

    def test_seven_original_crops_reproduce_candidate_and_bundled_bytes(self):
        booklet = next(b for b in load(DOCS / "figure-crops.json")["booklets"] if b["booklet"] == "2013h25a_nw_am2_qs.pdf")
        self.assertEqual(len(booklet["crops"]), 7)
        with fitz.open(DOCS / "evidence" / booklet["booklet"]) as pdf:
            for crop in booklet["crops"]:
                page = pdf[crop["page"] - 1]
                left, top, right, bottom = crop["box"]
                clip = fitz.Rect(left * page.rect.width, top * page.rect.height, right * page.rect.width, bottom * page.rect.height)
                png = page.get_pixmap(matrix=fitz.Matrix(booklet["scale"], booklet["scale"]), clip=clip, alpha=False).tobytes("png")
                self.assertEqual(png, (DOCS / "candidates/Figures" / crop["asset"]).read_bytes())
                self.assertEqual(png, (APP / "Figures" / crop["asset"]).read_bytes())
        for number in [4, 13, 24, 25]:
            q = self.questions[number]
            for block in q.get("bodyBlocks", []) + sum(q.get("choiceBlocks", []), []):
                if block["type"] == "image":
                    self.assertNotIn("正解", block["altText"])

    def test_old_protocol_and_current_caveats_are_separate(self):
        cable = self.questions[1]
        self.assertIn("1000BASE-TX", cable["choices"][2])
        self.assertIn("1000BASE-Tです", cable["choiceExplanations"][2])
        bgp = self.questions[6]
        self.assertIn("変化したときだけ", bgp["choices"][1])
        self.assertIn("KEEPALIVE", bgp["explanation"])
        rarp = self.questions[12]
        self.assertEqual(rarp["choices"][rarp["correctIndex"]], "RARP")
        self.assertIn("データリンク層", rarp["stem"])
        self.assertIn("DHCP", rarp["explanation"])
        tunnel = self.questions[9]
        self.assertIn("anycast", tunnel["explanation"])
        mail = self.questions[17]
        self.assertIn("自動で突破できるわけではなく", mail["explanation"])
        self.assertIn("事業者の運用", mail["explanation"])
        dns = self.questions[21]
        self.assertIn("公開権威サーバでも", dns["explanation"])
        self.assertIn("DNSSEC", dns["explanation"])


if __name__ == "__main__":
    unittest.main()
