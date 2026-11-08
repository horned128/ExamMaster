#!/usr/bin/env python3
"""Independent numerical checks for the app-authored calculation notes."""
import cmath
import math
import unittest

class OfficialCalculations(unittest.TestCase):
    def test_theory(self):
        self.assertAlmostEqual((8e-6*1000)**2/(2*4e-6), 8)
        h = 1e-4/(4*math.pi*4*math.pi*1e-7)*(1/9+1)
        self.assertAlmostEqual(h, 7.04, delta=.01)
        self.assertAlmostEqual((9/(.5+.1/4))**2*.5, 147, delta=1)
        self.assertAlmostEqual((2*(4*2/(4+2))*6)/(4+2), 8/3)
        self.assertEqual((12/6)**2*8+(20/math.hypot(4,3))**2*4, 96)
        ab,bc,ac=100/(3+4j),100/(4-3j),200/(8+6j)
        self.assertGreater(abs(ab+ac),abs(-bc-ac))
        self.assertGreater(abs(-bc-ac),abs(bc-ab))
        self.assertAlmostEqual(9e9*(1.6e-19)**2/4e-15,5.8e-14,delta=.1e-14)
        self.assertEqual(min(150/18000,300/30000)*(18000+30000),400)
        self.assertAlmostEqual(150/(300/30000-150/18000),90000)
        vb=12*100/700
        self.assertAlmostEqual(12-(vb-.6)*5-(vb-.6),5.3,delta=.02)
        self.assertAlmostEqual(1/(2*math.pi*10e-6*3000),5.3,delta=.01)

    def test_power(self):
        self.assertAlmostEqual(1000*9.8*(6500e6*1.1)*750/3.6e15,15,delta=.5)
        self.assertAlmostEqual(20*2*1.2*.95/.93,49,delta=.1)
        self.assertAlmostEqual(9.8*50*450*.97*.9,192500,delta=10)
        self.assertAlmostEqual(9.8*40*450*1.03/.85,213750,delta=10)
        self.assertAlmostEqual(.97/1.03*.9*.85*100,72,delta=.1)
        sag=math.sqrt(3*50*.01/8)
        self.assertAlmostEqual(10*50**2/(8*sag)/1000,7.22,delta=.01)
        self.assertAlmostEqual(.15*(75**2+50**2)+.2*25**2-.15*2*62.5**2,172,delta=.2)

    def test_machine(self):
        self.assertAlmostEqual(2*.4*.5*(math.pi*.5*1500/60),15.7,delta=.01)
        self.assertAlmostEqual(200*(2*math.pi*1000/60)/1000,21,delta=.1)
        self.assertAlmostEqual(400/(2*((6000**2/4500000)/1.25)),31.3,delta=.1)
        self.assertAlmostEqual(1000*9.8*.5/.9/1000,5.5,delta=.1)
        self.assertAlmostEqual(3*(400/math.sqrt(3))*200/(2*math.pi*1800/60),735,delta=.2)
        current=200+200/math.sqrt(3)*1j
        self.assertAlmostEqual(abs(400/math.sqrt(3)-1j*current),400)
        self.assertAlmostEqual(math.pi*(1-math.sqrt(3)/2)/3,.14,delta=.001)
        heat=(30*1.25+70*4.19)*80+65*2260
        self.assertEqual(heat,173364)
        self.assertAlmostEqual(heat/(22*.55)/3600,4,delta=.03)

    def test_law(self):
        copper=(1080/1.4-150)/(.4**2)
        self.assertAlmostEqual(copper,3880,delta=5)
        self.assertAlmostEqual((150+copper*.75**2)/(500+6700*.75**2)*100,55,delta=.4)
        leakage=100/math.hypot(100+15,6*math.pi*50*.1e-6*100*15)
        self.assertAlmostEqual(leakage,.87,delta=.001)
        rated=50000/(math.sqrt(3)*6600)
        self.assertAlmostEqual(rated*1.5,6.6,delta=.05)
        self.assertAlmostEqual(rated*1.15,5,delta=.04)

    def test_machine_logic_for_every_input(self):
        # Original formulas, including complemented variables, versus the notes.
        for x in [False,True]:
            for y in [False,True]:
                for z in [False,True]:
                    original=(x and y and not z) or (x and y and z) or (not x and y and z) or (not x and not y and z)
                    self.assertEqual(original,(x and y) or (not x and z))
                    original=(x or y or z) and (x or not y or z) and (not x or y or z)
                    self.assertEqual(original,(x or z) and (y or z))

if __name__ == "__main__": unittest.main()
