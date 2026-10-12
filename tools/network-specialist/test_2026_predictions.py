"""Independent checks for the authored forecast, not automatic review approval."""
from fractions import Fraction
from itertools import product
from ipaddress import ip_address, ip_network, collapse_addresses
import re
import unittest
from collections import Counter
from validate import DOCS, load


class Predictions2026Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part = load(DOCS / 'content/2026-pred-01.json')
        cls.questions = {q['questionNumber']: q for q in cls.part['questions']}

    def correct(self, number):
        q = self.questions[number]
        return q['choices'][q['correctIndex']]

    def test_complete_original_set_and_difficulty_distribution(self):
        self.assertEqual(set(self.questions), set(range(1, 26)))
        self.assertEqual([q['difficulty'] for q in self.questions.values()], [2]*5 + [3]*15 + [4]*5)
        mock = self.part['mockSets'][0]
        self.assertEqual((mock['questionCount'], mock['minutes']), (25, 40))
        self.assertEqual(mock['questionIDs'], [q['id'] for q in self.questions.values()])
        for q in self.questions.values():
            self.assertEqual((q['year'], q['kind'], q['administration']), (2026, 'prediction', 'prediction'))
            self.assertIn('ExamMaster オリジナル', q['source'])
            self.assertEqual(len(q['choiceExplanations']), 4)
            self.assertTrue(q['steps'])
            self.assertNotIn('ネットワークスペシャリスト試験 2026年', q['source'])

    def test_host_count_and_longest_match(self):
        network = ip_network('192.0.2.64/27')
        self.assertEqual(len(list(network.hosts())), int(self.correct(1)))
        routes = [('0.0.0.0/0', 'R0'), ('192.0.2.0/24', 'R1'), ('192.0.2.128/25', 'R2')]
        matches = [(ip_network(net).prefixlen, hop) for net, hop in routes if ip_address('192.0.2.150') in ip_network(net)]
        self.assertEqual(max(matches)[1], self.correct(2))

    def test_non_aligned_aggregation_does_not_claim_one_prefix(self):
        blocks = [ip_network(f'192.0.{n}.0/24') for n in range(2, 6)]
        result = list(collapse_addresses(blocks))
        self.assertEqual([str(n) for n in result], ['192.0.2.0/23', '192.0.4.0/23'])
        self.assertEqual(self.questions[6]['correctIndex'], 3)
        self.assertTrue(all(str(n) in self.correct(6) for n in result))
        for text in self.questions[6]['choices'][:3]:
            match = re.search(r'192\.0\.\d+\.0/22', text).group()
            with self.subTest(choice=text):
                try:
                    aggregate = ip_network(match)
                except ValueError:
                    continue  # not aligned at /22 boundary
                self.assertNotEqual(set(aggregate), set().union(*[set(n) for n in blocks]))

    def test_vlsm_checks_every_choice_for_capacity_overlap_and_minimality(self):
        container = ip_network('192.0.2.0/24')
        valid = []
        for i, text in enumerate(self.questions[21]['choices']):
            networks = [ip_network(n) for n in re.findall(r'192\.0\.2\.\d+/\d+', text)]
            capacity = all(len(list(n.hosts())) >= needed for n, needed in zip(networks, [100, 50, 20]))
            overlap = any(left.overlaps(right) for x, left in enumerate(networks) for right in networks[x+1:])
            if capacity and not overlap and all(n.subnet_of(container) for n in networks): valid.append(i)
        self.assertEqual(valid, [self.questions[21]['correctIndex']])
        networks = [ip_network(n) for n in re.findall(r'192\.0\.2\.\d+/\d+', self.correct(21))]
        self.assertEqual([n.prefixlen for n in networks], [25, 26, 27])
        self.assertEqual([int(n.network_address) - int(container.network_address) for n in networks], [0, 128, 192])
        for n, required in zip(networks, [100, 50, 20]):
            self.assertLess(2**(32-n.prefixlen-1)-2, required)

    def test_route_costs_and_failed_link_enumeration(self):
        self.assertEqual(min(10+10, 5+30), int(self.correct(9)))
        edges = [('A','B',5), ('A','C',3), ('C','D',20), ('B','C',2)]
        paths = []
        def walk(node, visited, total):
            if node == 'D': paths.append(total); return
            for a,b,cost in edges:
                if a == node and b not in visited: walk(b, visited | {b}, total+cost)
                if b == node and a not in visited: walk(a, visited | {a}, total+cost)
        walk('A', {'A'}, 0)
        self.assertEqual(sorted(paths), [23, 27])
        self.assertEqual(min(paths), int(self.correct(22)))

    def test_units_cpu_and_ttl(self):
        self.assertEqual(600-240, int(self.correct(8)))
        time = Fraction(1,5) + Fraction(4,5)/4
        self.assertEqual(1/time, Fraction(self.correct(16).replace('倍','')))
        self.assertEqual(Fraction(50*10**6*8, 100*10**6) / Fraction(4,5), int(self.correct(19)))
        self.assertEqual(Fraction(120*90, 4*60), Fraction(self.correct(20)))

    def test_reliability_by_enumerating_all_sixteen_states(self):
        result = Fraction(0)
        for state in product([False,True], repeat=4):
            if (state[0] or state[1]) and (state[2] or state[3]):
                result += Fraction(9,10)**sum(state) * Fraction(1,10)**(4-sum(state))
        self.assertEqual(result, Fraction(self.correct(24)))
        self.assertEqual(result, Fraction(9801,10000))

    def test_pipeline_by_per_instruction_stage_schedule(self):
        completion = []
        for instruction in range(20):
            stages = [instruction+stage+1 for stage in range(5)]
            completion.append(stages[-1])
        self.assertEqual(max(completion), int(self.correct(25)))
        self.assertEqual(completion[:2], [5,6])

    def test_test_design_requirements(self):
        boundary_cases = {value+delta for value in [0,100] for delta in [-1,0,1]}
        # Parse signed values separately because Japanese text uses a Unicode minus.
        supplied = set(map(int,re.findall(r'-?\d+',self.correct(17).replace('−','-'))))
        self.assertEqual(supplied,boundary_cases)
        self.assertEqual(self.questions[18]['correctIndex'],2)
        self.assertIn('10分',self.correct(18))
        self.assertIn('95パーセンタイル',self.correct(18))


class AdditionalPredictions2026Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parts = {s: load(DOCS / f'content/2026-pred-{s:02d}.json') for s in range(1, 4)}
        cls.questions = {s: {q['questionNumber']: q for q in part['questions']} for s, part in cls.parts.items()}

    def correct(self, s, number):
        q = self.questions[s][number]
        return q['choices'][q['correctIndex']]

    def test_three_complete_distinct_sets_and_subject_balance(self):
        stems, ids = [], []
        for s, part in self.parts.items():
            with self.subTest(set=s):
                mock = part['mockSets'][0]
                questions = part['questions']
                self.assertEqual((mock['questionCount'], mock['minutes']), (25, 40))
                self.assertEqual(mock['id'], f'nw-2026-pred-{s:02d}')
                self.assertEqual(mock['questionIDs'], [q['id'] for q in questions])
                self.assertEqual([q['questionNumber'] for q in questions], list(range(1, 26)))
                self.assertEqual(Counter(q['difficulty'] for q in questions), {2:5, 3:15, 4:5})
                self.assertEqual(Counter(q['subject'] for q in questions),
                                 {'ネットワーク':16, 'セキュリティ':5, 'コンピュータシステム':2, 'システム開発技術':2})
                for q in questions:
                    self.assertEqual(q['source'], f'ExamMaster オリジナル 2026年予想問題 第{s}回 問{q["questionNumber"]}')
                    self.assertEqual((q['year'],q['kind'],q['administration'],q['mockSetID']), (2026,'prediction','prediction',mock['id']))
                    self.assertEqual(len(q['choices']),4)
                    self.assertEqual(len(q['choiceExplanations']),4)
                    self.assertTrue(q['steps'])
                stems += [q['stem'] for q in questions]
                ids += [q['id'] for q in questions]
        self.assertEqual(len(set(stems)),75)
        self.assertEqual(len(set(ids)),75)

    def test_set_two_window_limit_and_frame_event_schedule(self):
        q=self.questions[2][6]
        self.assertIn('250,000',q['stem']); self.assertIn('20ミリ秒',q['stem'])
        rate=Fraction(250000*8,1)/Fraction(20,1000)/10**6
        self.assertEqual(rate,int(self.correct(2,6)))
        # Explicit start/end timestamps establish that only 99 gaps are counted.
        time=Fraction(0)
        for frame in range(100):
            time += Fraction(1000*8,10*10**6)
            if frame<99: time += Fraction(2,10000)
        self.assertEqual(time*1000,Fraction(self.correct(2,7)))

    def test_set_two_fragments_cover_data_with_correct_offsets(self):
        payload=4000; maximum=(1500-20)//8*8
        fragments=[]; offset=0
        while offset<payload:
            size=min(maximum,payload-offset)
            fragments.append((offset//8,size,offset+size<payload))
            offset+=size
        self.assertEqual(fragments,[(0,1480,True),(185,1480,True),(370,1040,False)])
        self.assertEqual(fragments[2][0],int(self.correct(2,8)))
        self.assertEqual(sum(size for _,size,_ in fragments),payload)
        self.assertTrue(all(size+20<=1500 for _,size,_ in fragments))

    def test_set_two_timers_bucket_and_weighted_cache_time(self):
        self.assertEqual(Fraction(8,2),int(self.correct(2,11)))
        self.assertEqual(Fraction(2,5-1),Fraction(self.correct(2,14)))
        expected=Fraction(95,100)*5+Fraction(5,100)*(5+100)
        self.assertEqual(expected,int(self.correct(2,18)))
        self.assertNotEqual(expected,Fraction(self.questions[2][18]['choices'][1]))

    def test_set_two_replay_window_rejects_old_and_duplicate_packets(self):
        left=100-32+1
        received={92,100}
        choices=[68,92,95,100]
        valid=[i for i,number in enumerate(choices) if left<=number<=100 and number not in received]
        self.assertEqual(valid,[self.questions[2][21]['correctIndex']])
        self.assertEqual(left,69)

    def test_set_two_vxlan_overhead_and_mm1_stationary_distribution(self):
        headers=[20,8,8,14,20,20]
        self.assertEqual(1500-sum(headers),int(self.correct(2,22)))
        # Derive mean queue length from the geometric stationary distribution.
        rho=Fraction(80,100)
        lq=rho*rho/(1-rho)
        wq=lq/80
        self.assertEqual(wq*1000,int(self.correct(2,23)))
        self.assertNotEqual(wq,Fraction(1,100-80))

    def test_set_two_max_flow_all_cuts_and_realizable_flow(self):
        edges={('S','A'):6,('S','B'):4,('A','B'):3,('A','T'):4,('B','T'):5}
        cuts=[]
        for a,b in product([False,True],repeat=2):
            side={'S'}|({'A'} if a else set())|({'B'} if b else set())
            cuts.append(sum(cap for (u,v),cap in edges.items() if u in side and v not in side))
        self.assertEqual(min(cuts),int(self.correct(2,24)))
        flow={('S','A'):6,('S','B'):3,('A','B'):2,('A','T'):4,('B','T'):5}
        for edge,value in flow.items(): self.assertLessEqual(value,edges[edge])
        for node in ['A','B']:
            self.assertEqual(sum(v for (u,w),v in flow.items() if w==node),sum(v for (u,w),v in flow.items() if u==node))
        self.assertEqual(sum(v for (u,w),v in flow.items() if w=='T'),min(cuts))
        table=self.questions[2][24]['bodyBlocks'][1]
        self.assertEqual([int(row[1]) for row in table['rows']],list(edges.values()))

    def test_set_two_boolean_test_coverage_and_firewall_requirements(self):
        self.assertEqual(self.questions[2][19]['correctIndex'],0)
        all_cases=set(product([False,True],repeat=2))
        branch_cases={(False,False),(True,True)}
        self.assertEqual({a for a,b in branch_cases},{False,True})
        self.assertEqual({b for a,b in branch_cases},{False,True})
        self.assertNotEqual(branch_cases,all_cases)
        self.assertEqual(self.questions[2][20]['correctIndex'],3)
        policy=self.correct(2,25)
        for requirement in ['許可先','指定リゾルバ','UDP/TCP 53','追跡']:
            self.assertIn(requirement,policy)

    def test_set_three_dns_negative_ttl_and_ack_growth(self):
        self.assertEqual(min(900,300),int(self.correct(3,10)))
        window=2
        for _ in range(3):
            sent=window
            for ack in range(sent): window+=1
        self.assertEqual(window,int(self.correct(3,14)))

    def test_set_three_capacity_and_dependency_schedule(self):
        self.assertEqual((5-1)*2,int(self.correct(3,18)))
        duration={'A':4,'B':6,'C':3,'D':5}
        predecessors={'A':[],'B':[],'C':['A'],'D':['B','C']}
        completion={}
        for node in ['A','B','C','D']:
            completion[node]=max([completion[p] for p in predecessors[node]],default=0)+duration[node]
        self.assertEqual(completion['D'],int(self.correct(3,19)))
        self.assertEqual(completion,{'A':4,'B':6,'C':7,'D':12})

    def test_set_three_equivalence_classes_check_all_choices(self):
        valid=[]
        classify=lambda n:0 if n<=0 else 1 if n<=60 else 2
        for i,text in enumerate(self.questions[3][20]['choices']):
            values=[int(x) for x in re.findall(r'-?\d+',text.replace('−','-'))]
            if Counter(classify(n) for n in values)=={0:1,1:1,2:1}: valid.append(i)
        self.assertEqual(valid,[self.questions[3][20]['correctIndex']])

    def test_set_three_effective_tcp_window_and_common_power_failure(self):
        budget=min(64000,24000)-8000
        self.assertEqual(budget,int(self.correct(3,22)))
        probability=Fraction(0)
        for power,a,b in product([False,True],repeat=3):
            if power and (a or b):
                probability+=Fraction(99,100)*Fraction(95,100)**(a+b)*Fraction(5,100)**(2-a-b)
        self.assertEqual(probability,Fraction(self.correct(3,23)))
        self.assertLess(probability,Fraction(99,100))

    def test_set_three_nonpreemptive_queue_schedule(self):
        clock=0; wait=[]; response=[]
        for arrived,duration in [(0,4),(1,3),(2,1)]:
            clock=max(clock,arrived)
            wait.append(clock-arrived)
            clock+=duration
            response.append(clock-arrived)
        self.assertEqual(wait,[0,3,5])
        self.assertEqual(Fraction(sum(wait),len(wait)),Fraction(self.correct(3,25)))
        self.assertNotEqual(Fraction(sum(response),len(response)),Fraction(self.correct(3,25)))


if __name__ == '__main__':
    unittest.main()
