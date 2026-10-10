"""Independent calculations and original figure checks for the 2014 booklet."""
from fractions import Fraction
import ipaddress
import re
import unicodedata
import unittest
import fitz
from validate import APP, DOCS, load, official_answers


class Calculations2014Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part = load(DOCS / "content/2014.json")
        cls.questions = {q["questionNumber"]: q for q in cls.part["questions"]}

    def test_original_answers_and_complete_original_order_mock(self):
        answers = official_answers(DOCS / "evidence/2014h26a_nw_am2_ans.pdf")
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertEqual({n: q["correctIndex"] for n, q in self.questions.items()}, answers)
        mock, = self.part["mockSets"]
        self.assertEqual(mock["id"], "nw-2014-autumn")
        self.assertEqual(mock["questionCount"], 25)
        self.assertEqual(mock["minutes"], 40)
        self.assertEqual(mock["questionIDs"], [self.questions[n]["id"] for n in range(1, 26)])
        for q in self.questions.values():
            self.assertEqual(q["mockSetID"], mock["id"])
            self.assertEqual(len(q["choiceExplanations"]), 4)
            self.assertTrue(all(q["choiceExplanations"]))
            self.assertTrue(q["steps"])

    def test_original_ipv6_literals_and_link_local_not_loopback(self):
        q = self.questions[1]
        block = q["bodyBlocks"][1]
        literal = re.findall(r"(?m)^（[12]）([0-9a-f:]+)$", block["text"])
        self.assertEqual(literal, ["2001:db8::b083:ba94:60c7:7c36", "fe80::200:c0ff:fea8:2"])
        first, second = map(ipaddress.IPv6Address, literal)
        self.assertIn(first, ipaddress.IPv6Network("2001:db8::/32"))
        self.assertIn(second, ipaddress.IPv6Network("fe80::/10"))
        self.assertTrue(second.is_link_local)
        self.assertFalse(second.is_loopback)
        self.assertEqual(q["correctIndex"], 3)
        self.assertIn("文書用", q["explanation"])

    def test_offered_traffic_seconds_and_hours_agree_without_doubling(self):
        q = self.questions[3]
        phones = int(re.search(r"(\d+)台", q["stem"]).group(1))
        minutes = int(re.search(r"(\d+)分に1回", q["stem"]).group(1))
        hold = int(re.search(r"保留時間は(\d+)秒", q["stem"]).group(1))
        seconds = Fraction(phones * hold, minutes * 60)
        hours = phones * Fraction(60, minutes) * Fraction(hold, 3600)
        self.assertEqual(seconds, hours)
        self.assertEqual(seconds, 80)
        self.assertEqual(Fraction(q["choices"][q["correctIndex"]]), seconds)
        self.assertIn("発着呼の合計", q["stem"])

    def test_vlsm_figure_numbers_and_all_four_choice_overlaps(self):
        q = self.questions[10]
        original = q["bodyBlocks"][1]["altText"]
        networks = []
        for label, address, mask, expected in [
            ("B", "172.16.1.32", "255.255.255.224", (32, 63)),
            ("C", "172.16.1.224", "255.255.255.252", (224, 227)),
            ("D", "172.16.1.64", "255.255.255.192", (64, 127)),
        ]:
            self.assertIn(f"{label}の上段{address}，下段{mask}", original)
            network = ipaddress.IPv4Network(f"{address}/{mask}")
            self.assertEqual((int(str(network.network_address).split(".")[-1]),
                              int(str(network.broadcast_address).split(".")[-1])), expected)
            networks.append(network)
        overlaps = []
        for index, blocks in enumerate(q["choiceBlocks"]):
            table, = blocks
            self.assertEqual(table["headers"], ["ネットワークアドレス", "サブネットマスク"])
            address, mask = table["rows"][0]
            network = ipaddress.IPv4Network(f"{address}/{mask}")
            self.assertEqual(q["choices"][index], f"{address}，{mask}")
            overlaps.append([label for label, other in zip("BCD", networks) if network.overlaps(other)])
        self.assertEqual(overlaps, [["B", "D"], ["C"], [], ["C"]])
        self.assertEqual(q["correctIndex"], overlaps.index([]))
        table = q["explanationBlocks"][0]
        self.assertEqual(table["rows"][-1], ["A（ウ）", "172.16.1.128/26", "128〜191"])

    def test_hex_mask_prefix_host_count_and_enumeration_agree(self):
        q = self.questions[13]
        hex_mask = re.search(r"16進数の([0-9A-F]{8})", q["stem"]).group(1)
        mask = ipaddress.IPv4Address(int(hex_mask, 16))
        self.assertEqual(str(mask), "255.255.255.128")
        network = ipaddress.IPv4Network(f"172.16.0.0/{mask}")
        self.assertEqual(network.prefixlen, 25)
        expected = 2 ** (32 - network.prefixlen) - 2
        self.assertEqual(len(list(network.hosts())), expected)
        self.assertEqual(expected, 126)
        self.assertEqual(int(q["choices"][q["correctIndex"]]), expected)

    def test_idn_original_fullwidth_example_and_ascii_mapping(self):
        q = self.questions[15]
        fullwidth, ascii_name = re.findall(r"例：([^）]+)", q["choices"][0])
        self.assertEqual(fullwidth, "ＥＸＡＭＰＬＥ１.jp")
        self.assertEqual(ascii_name, "EXAMPLE1.jp")
        self.assertEqual(unicodedata.normalize("NFKC", fullwidth).casefold(), ascii_name.casefold())
        # Python's built-in codec is IDNA2003, not a test of UTS #46 conformance.
        self.assertEqual(fullwidth.encode("idna").lower(), ascii_name.encode("idna").lower())
        label = "日本語"
        alabel = "xn--" + label.encode("punycode").decode("ascii")
        self.assertTrue(alabel.isascii())
        self.assertEqual(alabel[4:].encode("ascii").decode("punycode"), label)
        self.assertEqual(q["correctIndex"], 1)
        self.assertIn("IDNA2008", q["explanation"])
        self.assertIn("UTS #46", q["explanation"])

    def test_transaction_time_components_and_total_agree(self):
        q = self.questions[23]
        sent, received = map(int, re.findall(r"(\d+)バイトの電文", q["stem"]))
        efficiency = Fraction(int(re.search(r"伝送効率を(\d+)%", q["stem"]).group(1)), 100)
        processing = int(re.search(r"処理時間を(\d+)ミリ秒", q["stem"]).group(1))
        self.assertIn("1×10⁶ビット/秒", q["stem"])
        speed = 10 ** 6 * efficiency
        upload, download = (Fraction(size * 8 * 1000, speed) for size in [sent, received])
        self.assertEqual((upload, download, processing), (4, 6, 40))
        total = upload + processing + download
        combined = Fraction((sent + received) * 8 * 1000, speed) + processing
        self.assertEqual(total, combined)
        self.assertEqual(total, 50)
        self.assertEqual(int(q["choices"][q["correctIndex"]]), total)
        self.assertEqual(set(map(int, q["choices"][:3])), {int(upload + download), int(upload + processing), int(processing + download)})

    def test_error_seeding_rates_total_and_remaining_are_distinct(self):
        q = self.questions[24]
        self.assertEqual(q["choices"], ["m/S = (n−m)/T", "m/S = T/(n−m)", "m/S = n/T", "m/S = T/n"])
        self.assertEqual(q["correctIndex"], 0)
        # Independent illustrative counts, not invented values for the original question.
        for seed, found_seed, latent, found_latent in [(40, 20, 60, 30), (40, 10, 80, 20), (40, 30, 80, 60)]:
            total_found = found_seed + found_latent
            rate = Fraction(found_seed, seed)
            self.assertEqual(rate, Fraction(total_found - found_seed, latent))
            estimate = Fraction(seed * (total_found - found_seed), found_seed)
            self.assertEqual(estimate, latent)
            self.assertEqual(estimate - (total_found - found_seed), latent - found_latent)
            alternatives = [Fraction(total_found - found_seed, latent), Fraction(latent, total_found - found_seed),
                            Fraction(total_found, latent), Fraction(latent, total_found)]
            self.assertEqual([i for i, value in enumerate(alternatives) if value == rate], [0])
        self.assertIn("推定", q["explanation"])
        self.assertIn("mが0でない", q["explanation"])

    def test_five_registered_original_crops_reproduce_bundled_and_candidate_bytes(self):
        booklet = next(b for b in load(DOCS / "figure-crops.json")["booklets"] if b["booklet"] == "2014h26a_nw_am2_qs.pdf")
        self.assertEqual(len(booklet["crops"]), 5)
        with fitz.open(DOCS / "evidence" / booklet["booklet"]) as pdf:
            for crop in booklet["crops"]:
                page = pdf[crop["page"] - 1]
                left, top, right, bottom = crop["box"]
                clip = fitz.Rect(left * page.rect.width, top * page.rect.height, right * page.rect.width, bottom * page.rect.height)
                png = page.get_pixmap(matrix=fitz.Matrix(booklet["scale"], booklet["scale"]), clip=clip, alpha=False).tobytes("png")
                self.assertEqual(png, (DOCS / "candidates/Figures" / crop["asset"]).read_bytes())
                self.assertEqual(png, (APP / "Figures" / crop["asset"]).read_bytes())
        q = self.questions[24]
        self.assertEqual([b[0]["assetName"] for b in q["choiceBlocks"]], [f"nw-2014-q24-{symbol}.png" for symbol in ["a", "i", "u", "e"]])
        for blocks in q["choiceBlocks"]:
            self.assertNotIn("正解", blocks[0]["altText"])

    def test_current_security_caveats_do_not_modify_original_questions(self):
        certificate = self.questions[17]
        self.assertIn("SSL/TLS", certificate["choices"][1])
        self.assertNotIn("1.3", certificate["stem"])
        self.assertIn("TLS1.3", certificate["explanation"])
        self.assertIn("静的RSA鍵交換は廃止", certificate["explanation"])
        dnssec = self.questions[16]
        self.assertIn("送信者の正当性", dnssec["choices"][1])
        self.assertIn("出所", dnssec["explanation"])
        self.assertIn("機密性", dnssec["explanation"])
        mail = self.questions[21]
        self.assertEqual(mail["choices"], ["DKIM", "OP25B", "POP before SMTP", "SPF"])
        self.assertEqual(mail["correctIndex"], 2)
        self.assertIn("SMTP AUTH", mail["explanation"])
        self.assertIn("共有/NAT", mail["explanation"])


if __name__ == "__main__":
    unittest.main()
