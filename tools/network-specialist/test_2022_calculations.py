"""Independent calculations tied to the transcribed 2022 conditions."""
from fractions import Fraction
import ipaddress
import unittest
from validate import DOCS, load, official_answers


class Calculations2022Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.questions = {q["questionNumber"]: q for q in load(DOCS / "content/2022.json")["questions"]}

    def test_original_answer_pdf_and_complete_set(self):
        answers = official_answers(DOCS / "evidence/2022r04h_nw_am2_ans.pdf")
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertEqual({n: q["correctIndex"] for n, q in self.questions.items()}, answers)

    def test_call_traffic_units(self):
        question = self.questions[1]
        self.assertTrue(all(value in question["stem"] for value in ("180台", "3分", "80秒")))
        result = Fraction(180, 3 * 60) * 80
        self.assertEqual(result, 80)
        self.assertEqual(Fraction(question["choices"][question["correctIndex"]]), result)

    def test_single_aggregate_covers_all_49_networks(self):
        question = self.questions[9]
        self.assertIn("192.168.10.0/24〜192.168.58.0/24", question["stem"])
        subnets = [ipaddress.ip_network(f"192.168.{n}.0/24") for n in range(10, 59)]
        candidates = [ipaddress.ip_network(value) for value in question["choices"]]
        eligible = [i for i, candidate in enumerate(candidates) if all(s.subnet_of(candidate) for s in subnets)]
        self.assertEqual(eligible, [0, 1, 2])
        best = max(eligible, key=lambda i: candidates[i].prefixlen)
        self.assertEqual(best, question["correctIndex"])
        # Derive the common prefix from both endpoint integers, not the explanation.
        left, right = int(subnets[0].network_address), int(subnets[-1].broadcast_address)
        prefix = 32 - (left ^ right).bit_length()
        self.assertEqual(prefix, 18)
        self.assertEqual(candidates[best], ipaddress.ip_network(f"192.168.10.0/{prefix}", strict=False))

    def test_host_address_special_ranges_and_mask(self):
        question = self.questions[12]
        interfaces = [ipaddress.ip_interface(s) for s in question["choices"]]
        usable = [i for i, value in enumerate(interfaces)
                  if not (value.ip.is_loopback or value.ip.is_multicast)
                  and value.ip not in (value.network.network_address, value.network.broadcast_address)]
        self.assertEqual(usable, [question["correctIndex"]])
        self.assertEqual(str(interfaces[1].network.broadcast_address), "172.16.255.255")
        self.assertEqual(interfaces[2].ip, interfaces[2].network.broadcast_address)

    def test_parallel_availability_inverse_and_all_choices(self):
        question = self.questions[23]
        self.assertTrue(all(value in question["stem"] for value in ("0.9", "0.999", "二重化")))
        old, combined = Fraction("0.9"), Fraction("0.999")
        result = 1 - (1 - combined) / (1 - old)
        self.assertEqual(result, Fraction(99, 100))
        self.assertEqual(Fraction(question["choices"][question["correctIndex"]]), result)
        computed = [1 - (1 - old) * (1 - Fraction(choice)) for choice in question["choices"]]
        self.assertEqual(computed, [Fraction(999, 1000), Fraction(9993, 10000), Fraction(2499, 2500), Fraction(9999, 10000)])
        self.assertEqual([i for i, value in enumerate(computed) if value == combined], [0])
        self.assertIn("原文に独立性の明示はありません", question["explanation"])


if __name__ == "__main__":
    unittest.main()
