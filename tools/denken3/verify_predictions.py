#!/usr/bin/env python3
"""Independent answer-key review, using laws and worked results outside authoring.

Checks nearest-choice uniqueness against unrounded answers, plus logic truth tables.
The reviewed values here are intentionally separate from the content generators.
"""
import json
import math
import pathlib
import re
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[2]
def vector(labels,values): return dict(zip(labels,values))
A=[str(n) for n in range(1,15)]
B=['15a','15b','16a','16b','17a','17b','18a','18b']
THEORY=[
    {**vector(A,[.6,2.5,1,6,2,50,10,1.2,100*math.sqrt(3),2,None,-1,9,44.4]),
     **vector(B,[2,40,480,360,177.6,2,-4,-2])},
    {**vector(A,[4,40,12,6,400/6000,200/math.sqrt(2),.8,5,10*math.sqrt(3),.2,None,4,1/9,200]),
     **vector(B,[3,81,800,1000,133.2,2.5,-3,-1.2])},
    {**vector(A,[60,4,.5,4,15,None,1/(2*math.pi*math.sqrt(.1*.0001)),.6,1000*math.sqrt(3),math.exp(-1),4,None,None,.6]),
     **vector(B,[4,128,400,500,133.2,1,-2,-1.5])},
]
POWER=[
    {'12':6600/(2*math.sqrt(3)),'13':60,'14':50,**vector(B[:6],[35280,70.56,4,2/15,97,130])},
    {'12':3300/math.sqrt(3),'13':160,'14':75,**vector(B[:6],[39200,78.4,6,1/6,92,400])},
    {'12':11000/(5*math.sqrt(3)),'13':45,'14':40,**vector(B[:6],[33320,66.64,4.8,.2,105,340])},
]
MACHINE=[
    {'2':4,'4':200,'6':200,'9':.8,'10':45,'11':2.45,'12':50,
     **vector(B[:6],[.8,19.2,200,8000/8200*100,2520,30])},
    {'1':210,'2':1200,'6':90,'10':42,'11':math.pi,'12':30,
     **vector(B[:6],[1.5,28.5,400,20000/20400*100,3360,70/3])},
    {'2':1.5,'7':.64,'10':255,'12':25,
     **vector(B[:6],[1.2,38.8,300,15000/15300*100,1680,112/3])},
]
LB=['11a','11b','12a','12b','13a','13b']
LAW=[
    {'3':10,'5':1.2,**vector(LB,[60,50,300,3,60,36])},
    {'3':10,'5':.6,**vector(LB,[50,75,825,6.6,120,64])},
    {'3':100,**vector(LB,[60,50,456,5.472,90,36])},
]

class PredictionReview(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        bank=json.loads((ROOT/'Qualifications/denken3/questions.json').read_text())
        cls.questions={q['id']:q for q in bank['questions'] if q['kind']=='prediction'}

    def check_numeric(self,subject,rounds):
        for r,key in enumerate(rounds,1):
            for label,expected in key.items():
                if expected is None: continue
                n=int(re.match(r'\d+',label)[0]);part=label[-1] if label[-1] in 'ab' else ''
                qid=f'd3-2027-pred-{r:02d}-{subject}-q{n:02d}{part}'
                q=self.questions[qid]
                values=[float(re.match(r'^[-+]?\d+(?:\.\d+)?',s)[0]) for s in q['choices']]
                distances=[abs(value-expected) for value in values]
                best=min(distances)
                self.assertEqual(distances.count(best),1,qid)
                self.assertEqual(distances.index(best),q['correctIndex'],qid)
                self.assertAlmostEqual(values[q['correctIndex']],expected,delta=max(abs(expected)*.005,.0005),msg=qid)

    def test_theory_numerical_keys(self): self.check_numeric('theory',THEORY)
    def test_power_numerical_keys(self): self.check_numeric('power',POWER)
    def test_machine_numerical_keys(self): self.check_numeric('machine',MACHINE)
    def test_facility_management_numerical_keys(self): self.check_numeric('law',LAW)

    def test_original_logic_for_every_input(self):
        for x in [False,True]:
            for y in [False,True]:
                self.assertEqual((x and y) or (x and not y),x)
                self.assertEqual((x or y) and (x or not y),x)
                first=not(x and x)
                self.assertEqual(first,not x)
                self.assertEqual(not(first and first),x)
        # Review the published choices as well as the algebra.
        for r in [1,2]:
            q=self.questions[f'd3-2027-pred-{r:02d}-machine-q18a']
            self.assertEqual(q['choices'][q['correctIndex']],'X')
        q=self.questions['d3-2027-pred-03-machine-q18a']
        self.assertEqual(q['choices'][q['correctIndex']],'X̅')
        for r,answer in [(1,'0'),(2,'1'),(3,'X')]:
            q=self.questions[f'd3-2027-pred-{r:02d}-machine-q18b']
            self.assertEqual(q['choices'][q['correctIndex']],answer)

    def test_exam_shape_and_answer_position_balance(self):
        for r in range(1,4):
            items=[q for id,q in self.questions.items() if f'pred-{r:02d}-' in id]
            self.assertEqual(len(items),80)
            for key,subject in [('theory','理論'),('power','電力'),('machine','機械'),('law','法規')]:
                paper=[q for q in items if q['subject']==subject]
                counts=[sum(q['correctIndex']==i for q in paper) for i in range(5)]
                self.assertLessEqual(max(counts)-min(counts),1)
                for elective in [17,18]:
                    selected=[q for q in paper if key not in ['theory','machine'] or q['questionNumber']<17 or q['questionNumber']==elective]
                    self.assertEqual(sum(q['points'] for q in selected),100)

if __name__=='__main__': unittest.main()
