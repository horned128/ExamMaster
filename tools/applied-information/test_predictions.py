import math
import unittest
from predictions import build_sets, calculation_questions


class PredictionTests(unittest.TestCase):
    def testCasesAreSolvableFromExplicitQuantities(self):
        for s in range(1,4):
            questions={q["tags"][0]:q for q in calculation_questions(s)}
            def answer(tag):
                q=questions[tag];return q["choices"][q["correctIndex"]]
            self.assertEqual(int(answer("2の補数"),2), 256-[23,37,51][s-1])
            self.assertEqual(int(answer("進数変換"),16),[45,90,165][s-1])
            self.assertEqual(int(answer("二分探索の計算")),math.log2([128,512,2048][s-1]))
            self.assertEqual(int(answer("RAID5")),([4,6,8][s-1]-1)*2)
            self.assertEqual(int(answer("IPv4サブネット")),2**(32-[26,27,28][s-1])-2)
            self.assertAlmostEqual(float(answer("直列システム")),[.8,.9,.95][s-1]**2,places=4)
            self.assertAlmostEqual(float(answer("並列システム")),1-(1-[.8,.9,.95][s-1])**2,places=4)
            self.assertAlmostEqual(float(answer("EVM・SPI")),.8)
            self.assertAlmostEqual(float(answer("EVM・EAC")),[300,600,900][s-1]/.8)
            self.assertAlmostEqual(float(answer("損益分岐点")),[300000,600000,900000][s-1]/600)
            self.assertAlmostEqual(float(answer("NPV")),[1000,2000,3000][s-1]*1.32/1.1-[1000,2000,3000][s-1])

    def testThreeCompleteSetsHaveOriginalExplanationsAndUniqueStems(self):
        questions,sets=build_sets()
        self.assertEqual(len(questions),240)
        self.assertEqual(len(sets),3)
        self.assertEqual(len({q["stem"] for q in questions}),240)
        for q in questions:
            self.assertEqual(len(set(q["choices"])),4)
            self.assertEqual(len(q["choiceExplanations"]),4)
            self.assertTrue(q["explanation"].strip())


if __name__=="__main__":unittest.main()
