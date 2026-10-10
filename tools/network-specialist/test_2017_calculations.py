"""Independent checks against the reviewed 2017 original data."""
from fractions import Fraction
import ipaddress
import re
import unittest
from validate import DOCS, load, official_answers


class Calculations2017Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part = load(DOCS / "content/2017.json")
        cls.questions = {q["questionNumber"]: q for q in cls.part["questions"]}

    def test_original_answers_and_complete_original_order_mock(self):
        answers = official_answers(DOCS / "evidence/2017h29a_nw_am2_ans.pdf")
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertEqual({n: q["correctIndex"] for n, q in self.questions.items()}, answers)
        mock, = self.part["mockSets"]
        self.assertEqual(mock["id"], "nw-2017-autumn")
        self.assertEqual(mock["questionCount"], 25)
        self.assertEqual(mock["minutes"], 40)
        self.assertEqual(mock["questionIDs"], [self.questions[n]["id"] for n in range(1, 26)])
        for question in self.questions.values():
            self.assertEqual(question["mockSetID"], mock["id"])
            self.assertEqual(len(question["choiceExplanations"]), 4)
            self.assertTrue(all(question["choiceExplanations"]))
            self.assertTrue(question["steps"])
            self.assertIsNone(question["imageName"])

    def test_offered_traffic_seconds_and_hours_agree(self):
        q = self.questions[2]
        phones = int(re.search(r"(\d+)台", q["stem"]).group(1))
        minutes = int(re.search(r"(\d+)分に1回", q["stem"]).group(1))
        hold = int(re.search(r"保留時間は(\d+)秒", q["stem"]).group(1))
        seconds = Fraction(phones * hold, minutes * 60)
        hours = phones * Fraction(60, minutes) * Fraction(hold, 3600)
        self.assertEqual(seconds, hours)
        self.assertEqual(seconds, 80)
        self.assertEqual(Fraction(q["choices"][q["correctIndex"]]), seconds)

    def test_broadcast_library_and_host_bit_or_agree(self):
        q = self.questions[12]
        address = re.search(r"[\d.]+/\d+", q["stem"]).group()
        subnet = ipaddress.IPv4Network(address)
        self.assertEqual(subnet.num_addresses, 16)
        self.assertEqual(len(list(subnet.hosts())), 14)
        broadcast = ipaddress.IPv4Address(int(subnet.network_address) | int(subnet.hostmask))
        self.assertEqual(subnet.broadcast_address, broadcast)
        self.assertEqual(str(broadcast), "192.168.10.207")
        self.assertEqual(q["choices"][q["correctIndex"]], str(broadcast))
        self.assertIn(ipaddress.IPv4Address(q["choices"][0]), list(subnet.hosts()))
        self.assertNotIn(ipaddress.IPv4Address(q["choices"][2]), subnet)
        self.assertNotIn(ipaddress.IPv4Address(q["choices"][3]), subnet)

    def test_printer_sojourn_wait_and_little_law_agree(self):
        q = self.questions[23]
        arrival = Fraction(int(re.search(r"毎分(\d+)回", q["stem"]).group(1)), 60)
        service = Fraction(int(re.search(r"平均が(\d+)秒", q["stem"]).group(1)))
        rate = 1 / service
        rho = arrival / rate
        self.assertLess(rho, 1)
        self.assertEqual(rho, Fraction(1, 4))
        sojourn = 1 / (rate - arrival)
        mean_jobs = rho / (1 - rho)
        self.assertEqual(mean_jobs / arrival, sojourn)
        self.assertEqual(sojourn, 20)
        self.assertEqual(sojourn - service, 5)
        self.assertEqual(Fraction(q["choices"][q["correctIndex"]]), sojourn)
        self.assertIn("要求してから終了するまで", q["stem"])
        self.assertIn("ポアソン分布", q["stem"])
        self.assertIn("指数分布", q["stem"])

    def test_http3_caveat_is_only_in_explanation_not_original_choices(self):
        q = self.questions[10]
        self.assertEqual(q["stem"], "UDPを使用するプロトコルはどれか。")
        self.assertEqual(q["choices"], ["DHCP", "FTP", "HTTP", "SMTP"])
        self.assertEqual(q["correctIndex"], 0)
        self.assertIn("HTTP/3", q["choiceExplanations"][2])
        self.assertIn("QUIC/UDP", q["choiceExplanations"][2])
        self.assertIn("2017", q["explanation"])


if __name__ == "__main__":
    unittest.main()
