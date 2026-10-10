"""Verify the reviewed 2015 subset, and reject the unresolved IPv6 item."""
from decimal import Decimal, localcontext
from fractions import Fraction
import hashlib
import hmac
import ipaddress
import re
import unittest
from assemble_bank import assemble
from validate import APP, DOCS, load, official_answers


class Calculations2015Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part = load(DOCS / "content/2015.json")
        cls.questions = {q["questionNumber"]: q for q in cls.part["questions"]}

    def test_official_answers_and_held_item_excluded_from_assembly_and_mock(self):
        answers = official_answers(DOCS / "evidence/2015h27a_nw_am2_ans.pdf")
        self.assertEqual(set(answers), set(range(1, 26)))
        self.assertEqual(set(self.questions), set(range(1, 26)) - {9})
        self.assertTrue(all(q["correctIndex"] == answers[n] for n, q in self.questions.items()))
        self.assertEqual(self.part["mockSets"], [])
        candidate = load(DOCS / "candidates/2015-q09.json")
        question, = candidate["questions"]
        self.assertEqual(question["correctIndex"], answers[9])
        self.assertIn("サポートが必須", question["choices"][3])
        reviews = load(DOCS / "reviews.json")["questionReviews"]
        self.assertEqual(reviews[question["id"]]["stage2"], "held")
        with self.assertRaisesRegex(ValueError, "Unreviewed or held question"):
            assemble([candidate], reviews, load(DOCS / "review-snapshots.json"))
        bank = load(APP / "questions.json")
        self.assertNotIn(question["id"], {q["id"] for q in bank["questions"]})
        self.assertNotIn("nw-2015-autumn", {s["id"] for s in bank["mockSets"]})

    def test_ber_approximation_and_independent_bit_exact_expectation(self):
        q = self.questions[5]
        self.assertIn("1×10⁻⁵", q["stem"])
        size, packet = [int(value.replace(",", "")) for value in re.findall(r"([\d,]+)バイト", q["stem"])]
        self.assertIn(f"{size:,}バイト", q["stem"])
        self.assertIn(f"{packet}バイト", q["stem"])
        bit_rate = Fraction(1, 100_000)
        count, bits = size // packet, packet * 8
        self.assertEqual(count, 2_000)
        self.assertEqual(bits, 800)
        approximate = count * bits * bit_rate
        self.assertEqual(approximate, 16)
        with localcontext() as context:
            context.prec = 60
            p = Decimal(1) / Decimal(100_000)
            exact = count * (1 - (1 - p) ** bits)
        self.assertTrue(Decimal("15.936") < exact < Decimal("15.937"))
        choices = list(map(int, q["choices"]))
        self.assertEqual(min(range(4), key=lambda i: abs(Decimal(choices[i]) - exact)), q["correctIndex"])
        self.assertIn("独立", q["explanation"])
        self.assertIn("バースト", q["explanation"])

    def test_host_bits_by_mask_and_network_offset(self):
        q = self.questions[13]
        address, mask = re.findall(r"\d+\.\d+\.\d+\.\d+", q["stem"])
        host = ipaddress.IPv4Address(address)
        interface = ipaddress.IPv4Interface(f"{address}/{mask}")
        bits = int(host) & int(interface.hostmask)
        offset = int(host) - int(interface.network.network_address)
        self.assertEqual(interface.network.prefixlen, 27)
        self.assertEqual(str(interface.network), "212.62.31.64/27")
        self.assertEqual(bits, offset)
        self.assertEqual(bits, 26)
        self.assertEqual(int(q["choices"][q["correctIndex"]]), bits)

    def test_four_24_networks_exact_aggregate_and_invalid_boundaries(self):
        q = self.questions[14]
        networks = [ipaddress.IPv4Network(f"192.168.{n}.0/24") for n in range(32, 36)]
        collapsed = list(ipaddress.collapse_addresses(networks))
        self.assertEqual([str(n) for n in collapsed], ["192.168.32.0/22"])
        table = q["choiceBlocks"][q["correctIndex"]][0]
        self.assertEqual(table["headers"], ["ネットワーク番号", "サブネットマスク"])
        address, mask = table["rows"][0]
        self.assertEqual(ipaddress.IPv4Network(f"{address}/{mask}"), collapsed[0])
        self.assertEqual(sum(n.num_addresses for n in networks), collapsed[0].num_addresses)
        for index in [2, 3]:
            address, mask = q["choiceBlocks"][index][0]["rows"][0]
            with self.assertRaises(ValueError):
                ipaddress.IPv4Network(f"{address}/{mask}", strict=True)
        self.assertEqual(ipaddress.IPv4Network("192.168.32.0/21").num_addresses, 2 * collapsed[0].num_addresses)

    def test_mac_alteration_detected_but_unmodified_replay_still_verifies(self):
        q = self.questions[16]
        key, message = b"educational-local-key", b"local educational message"
        tag = hmac.digest(key, message, hashlib.sha256)
        self.assertTrue(hmac.compare_digest(tag, hmac.digest(key, message, hashlib.sha256)))
        self.assertFalse(hmac.compare_digest(tag, hmac.digest(key, message + b" changed", hashlib.sha256)))
        copied_message, copied_tag = bytes(message), bytes(tag)
        self.assertTrue(hmac.compare_digest(copied_tag, hmac.digest(key, copied_message, hashlib.sha256)))
        self.assertEqual(q["correctIndex"], 2)
        self.assertIn("リプレイ", q["explanation"])
        self.assertIn("秘密鍵", self.questions[21]["explanation"])

    def test_amdahl_exact_upper_bound_and_counterexample(self):
        q = self.questions[23]
        speedup = lambda p, n: 1 / (1 - p + p / n)
        half = Fraction(1, 2)
        for n in [1, 2, 4, 10, 20, 100, 1_000_000]:
            s = speedup(half, n)
            self.assertEqual(s, Fraction(2 * n, n + 1))
            self.assertEqual(2 - s, Fraction(2, n + 1))
            self.assertLess(s, 2)
        self.assertEqual(speedup(Fraction(9, 10), 20), Fraction(200, 29))
        self.assertLess(speedup(Fraction(9, 10), 20), 20 / 2)
        self.assertEqual(speedup(Fraction(0), 4), 1)
        self.assertNotEqual(speedup(half, 4), 2 * speedup(Fraction(1, 4), 4))
        self.assertGreater(speedup(half, 4), speedup(Fraction(1, 4), 4))
        self.assertEqual(q["correctIndex"], 2)
        self.assertEqual(q["bodyBlocks"][1]["assetName"], "nw-2015-q23-amdahl.png")

    def test_four_original_relation_images_and_non_topology_alt_labels(self):
        q = self.questions[24]
        labels = [("画像", "拡大", "縮小"), ("社員", "氏名", "生年月日"),
                  ("自動車", "乗用車", "トラック"), ("電話機", "受話器", "プッシュボタン")]
        for index, (upper, left, right) in enumerate(labels):
            block, = q["choiceBlocks"][index]
            self.assertEqual(block["assetName"], f'nw-2015-q24-{["a", "i", "u", "e"][index]}.png')
            self.assertIn(f"上の箱は{upper}", block["altText"])
            self.assertIn(f"{left}と{right}", block["altText"])
            self.assertIn("白抜き三角形", block["altText"])
            self.assertNotIn("一種", block["altText"])
            self.assertNotIn("正解", block["altText"])
        self.assertEqual(q["correctIndex"], 2)
        self.assertIn("トポロジ選択肢ではありません", q["explanation"])

    def test_current_protocol_caveats_are_in_explanations_not_original_question(self):
        self.assertIn("RFC6633", self.questions[7]["explanation"])
        self.assertIn("RFC9568", self.questions[12]["explanation"])
        http = self.questions[11]
        self.assertEqual(http["choices"], ["DHCP", "FTP", "HTTP", "SMTP"])
        self.assertEqual(http["correctIndex"], 0)
        self.assertIn("HTTP/3", http["explanation"])
        self.assertIn("QUIC/UDP", http["explanation"])
        self.assertIn("EAP-TLS", self.questions[17]["explanation"])


if __name__ == "__main__":
    unittest.main()
