"""Independent checks of worked examples and source/editorial release boundaries."""
import copy
import json
import math
import unittest
from fractions import Fraction
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

import editorial

ROOT=Path(__file__).resolve().parents[2]


class Autumn2025ReasoningTests(unittest.TestCase):
    def test_karnaugh_choices_retain_negation_and_counterexamples(self):
        # Source diagrams have AB/CD Gray-code order; evaluate the actual
        # displayed choices instead of only checking a separate worked formula.
        order=[(0,0),(0,1),(1,1),(1,0)]
        diagram=[[1,0,0,1],[0,1,1,0],[0,1,1,0],[0,0,0,0]]
        for set_id in ['ap-2025-autumn','ap-2014-autumn']:
            rows=json.loads((ROOT/'docs/applied-information/content'/f'{set_id}.json').read_text())['questions']
            question=next(q for q in rows if q['id']==set_id+'-q01')
            outcomes=[]
            for choice in question['choices']:
                expression=choice.replace('¬',' not ').replace('・',' and ').replace('＋',' or ').strip()
                outcomes.append([[int(eval(expression,{'__builtins__':{}},dict(A=bool(a),B=bool(b),C=bool(c),D=bool(d))))
                                  for c,d in order] for a,b in order])
            self.assertEqual([x==diagram for x in outcomes],[False,False,False,True])
            # Choice イ covers CD=00 but misses CD=10 at AB=00. Losing
            # C's negation reverses these two values without changing the key.
            self.assertEqual(outcomes[1][0],[1,0,0,0])

    def test_boolean_diagram_and_edge_logic(self):
        order=[(0,0),(0,1),(1,1),(1,0)]
        diagram=[[1,0,0,1],[0,1,1,0],[0,1,1,0],[0,0,0,0]]
        for r,(a,b) in enumerate(order):
            for c,(_,d) in enumerate(order):
                self.assertEqual(int((not a and not b and not d) or (b and d)),diagram[r][c])
        for previous in [0,1]:
            for current in [0,1]:
                self.assertEqual(bool(current and not previous),(previous,current)==(0,1))
        waveform=[(0,1,1),(0,0,1),(1,1,0),(0,0,1),(1,1,0),(0,0,1),(1,0,1)]
        self.assertTrue(all(z==int(not(a and b)) for a,b,z in waveform))

    def test_timing_capacity_and_sampling(self):
        self.assertEqual(Fraction(1_000_000,10_000)/2,50)
        self.assertEqual(8*1000*4//16,2000)
        self.assertEqual(8*1000*4*20//1000,640)
        self.assertEqual(Fraction(32*150,16_000_000)*1_000_000,300)
        self.assertEqual(Fraction(1,2*20_000)*1_000_000,25)
        self.assertEqual(Fraction(1250*8,100_000_000)-Fraction(1250*8,1_000_000_000),Fraction(9,100_000))
        self.assertEqual(Fraction(9,1000)/Fraction(9,100_000),100)
        self.assertEqual(Fraction(2*10,10*10),Fraction(1,5))
        self.assertAlmostEqual(10_000*(-math.expm1(12_000*math.log1p(-1e-6))),119.28293,places=4)

    def test_scheduling_and_lru(self):
        pending=[('A',0,2),('B',1,4),('C',2,3),('D',3,2),('E',4,1)]
        time=0;completed={};order=[]
        while pending:
            candidates=[j for j in pending if j[1]<=time]
            job=min(candidates,key=lambda j:j[2]);pending.remove(job)
            time+=job[2];completed[job[0]]=time-job[1];order.append(job[0])
        self.assertEqual(order,list('ACEDB'))
        self.assertEqual(completed['B'],11)
        last_access={'C0':8,'C1':6,'C2':5,'C3':10}
        self.assertEqual(min(last_access,key=last_access.get),'C2')

    def test_waiting_and_error_seeding(self):
        rho=Fraction(1,2)
        self.assertEqual(rho/(1-rho),1)
        self.assertEqual(Fraction(42,1)/Fraction(36,48)-42,14)

    def test_project_staff_and_expected_value(self):
        lost=4*2+4*Fraction(1,2)
        replacements=math.ceil(lost/2)
        self.assertEqual(replacements,5)
        self.assertEqual((replacements*Fraction(5,2)-4*2)*100,450)
        self.assertEqual(Fraction(6,10)*(80-50)+Fraction(4,10)*(40-50),14)
        self.assertEqual(Fraction(5*3+8*0+12*1,(5+8+12)*3)*100,36)

    def test_inventory_and_constrained_profit(self):
        costs={q:Fraction(100_000*5_000,q)+Fraction(q*1_000,2) for q in range(1,3001)}
        self.assertEqual(min(costs,key=costs.get),1000)
        feasible=[(x+y,x,y) for x in range(41) for y in range(31) if 3*x+2*y<=120 and x+2*y<=60]
        self.assertEqual(max(feasible),(45,30,15))
        self.assertEqual(Fraction(2000+1000+500,6000+4000)*100,35)
        profits=[a*12_000+b*15_000-15_000_000
                 for b in range(1251) for a in [(15_000-12*b)//8]]
        self.assertEqual(max(profits),7_500_000)


class Spring2025ReasoningTests(unittest.TestCase):
    def test_implication_bisection_and_stack_orders(self):
        imply=lambda a,b:not a or b
        for r in [False,True]:
            self.assertTrue(imply(imply(True,False) or imply(True,False),imply(True,r)))
        width=Fraction(1);steps=0
        while True:
            steps+=1;mid_distance=width/2
            if mid_distance<Fraction(1,1000):break
            width/=2
        self.assertEqual(steps,10)
        orders=set()
        def visit(remaining,stack,out):
            if not remaining and not stack:orders.add(out);return
            if remaining:visit(remaining[1:],stack+[remaining[0]],out)
            if stack:visit(remaining,stack[:-1],out+stack[-1])
        visit(list('ABC'),[],'')
        self.assertEqual(orders,{'ABC','ACB','BAC','BCA','CBA'})

    def test_avl_shapes_and_standard_local_rotation(self):
        # (value,left,right), all four original drawings satisfy BST/AVL properties.
        node=lambda value,left=None,right=None:(value,left,right)
        left=node(1,node(0),node(2))
        shapes=[node(3,left,node(5,node(4),node(6,None,node(7)))),
                node(4,node(2,node(1,node(0)),node(3)),node(6,node(5),node(7))),
                node(5,node(3,left,node(4)),node(7,node(6))),
                node(5,node(3,left,node(4)),node(6,None,node(7)))]
        def check(tree,lo=-1,hi=8):
            if tree is None:return 0
            value,l,r=tree;self.assertTrue(lo<value<hi)
            lh=check(l,lo,value);rh=check(r,value,hi)
            self.assertLessEqual(abs(lh-rh),1)
            return max(lh,rh)+1
        for shape in shapes:check(shape)
        # The insertion imbalance is LL at 2; rotate just that subtree.
        old=node(2,node(1,node(0)))
        pivot=old[1]
        rotated=node(pivot[0],pivot[1],node(old[0],pivot[2],old[2]))
        self.assertEqual(node(5,node(3,rotated,node(4)),node(7,node(6))),shapes[2])

    def test_sla_activity_cost_and_financial_ratios(self):
        self.assertEqual((22-7)*20*(Fraction(995,1000)-Fraction(993,1000)),Fraction(3,5))
        quote=Fraction(60,50+100)*50;proposal=Fraction(360,50+400)*50
        self.assertEqual((quote+proposal)*Fraction(1,5),12)
        self.assertGreater(Fraction(800,100),Fraction(1000,900))
        self.assertGreater(Fraction(20,100),Fraction(90,900))
        self.assertLess(Fraction(20,800),Fraction(90,1000))
        margin=Fraction(600-(-200),9000-7000)
        self.assertEqual(8000*(1-margin),4800)

    def test_units_tcp_and_addressing(self):
        import ipaddress
        self.assertEqual(int('82',16)*10,1300)
        wait=Fraction(1111,10)
        self.assertEqual((10_000*Fraction(1,100)+Fraction(1,10)*wait)/(Fraction(1,100)+wait),1)
        self.assertEqual(2000-(1500-20-20),540)
        subnet=ipaddress.ip_network('10.16.32.64/26')
        self.assertEqual(str(list(subnet.hosts())[-10]),'10.16.32.117')
        destination=ipaddress.ip_address('192.168.1.1')
        matches=[ipaddress.ip_network(n) for n in ['0.0.0.0/0','192.168.0.0/16','192.168.1.0/24','192.168.1.0/26']]
        self.assertEqual(str(max((n for n in matches if destination in n),key=lambda n:n.prefixlen)),'192.168.1.0/26')
        for r in [set(),{1},{1,2},{1,2,3}]:
            for t in [set(),{2},{2,3},{1,2,3}]:
                self.assertEqual(r-(r-t),r&t)

    def test_cpu_amdahl_reliability_and_lru(self):
        self.assertEqual(Fraction(4*1,1)/(Fraction(1,2)*4),2)
        speed=lambda r,n:1/(1-r+r/n)
        self.assertEqual(speed(Fraction(9,10),6)/speed(Fraction(3,10),6),3)
        for n in range(1,100):
            x=Fraction(n,100);availability=(1-(1-x)**2)*x
            self.assertLess(availability,x)
        self.assertEqual((1-Fraction(1,2)**2)*Fraction(1,2),Fraction(3,8))
        frames={0x4000:1,0x5000:2,0x6000:3,0x7000:4}
        latest={p:i for i,p in enumerate([1,2,3,4])};address=None
        for t,p in enumerate([2,5,3,1,6,5,4],start=4):
            if p not in frames.values():
                victim=min(frames,key=lambda a:latest[frames[a]])
                frames[victim]=p
            address=next(a for a,value in frames.items() if value==p)
            latest[p]=t
        self.assertEqual(address,0x6000)


class EditorialBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.bank=json.loads((ROOT/'Qualifications/applied-information/questions.json').read_text())['questions']
        self.rows=json.loads((editorial.DOCS/'content/ap-2025-autumn.json').read_text())['questions']

    def test_source_content_and_answer_changes_invalidate_review(self):
        original=editorial.DOCS
        with TemporaryDirectory() as folder:
            target=Path(folder);(target/'content').mkdir()
            for name in ['figure-crops.json','sources.json']:
                (target/name).write_bytes((original/name).read_bytes())
            def check(rows,expected):
                (target/'content/set.json').write_text(json.dumps({'questions':rows}))
                with patch.object(editorial,'DOCS',target):
                    with self.assertRaisesRegex(ValueError,expected):editorial.load_editorial(self.bank)
            altered=copy.deepcopy(self.rows);altered[0]['explanation']+=' unreviewed change'
            check(altered,'Editorial content changed')
            altered=copy.deepcopy(self.rows);altered[0]['correctIndex']=(altered[0]['correctIndex']+1)%4
            check(altered,'Official answer mismatch')
            altered=copy.deepcopy(self.rows);altered[0]['review']['sourceSnapshot']='changed'
            check(altered,'Original source changed')
            check(self.rows+[self.rows[0]],'Unknown/duplicate')
            altered=copy.deepcopy(self.rows)
            altered[0]['reusedFrom']='ap-2014-spring-q01'
            altered[0]['review']['editorialSnapshot']=editorial.digest({k:v for k,v in altered[0].items() if k!='review'})
            check(altered,'no reviewed origin')

    def test_reviewed_bank_matches_authored_content(self):
        reviewed=editorial.load_editorial(self.bank)
        actual={q['id']:q for q in self.bank}
        self.assertEqual(len([r for r in reviewed if r.startswith('ap-2025-autumn')]),80)
        for id_,row in reviewed.items():
            self.assertEqual(actual[id_]['explanation'],row['explanation'])
            self.assertEqual(actual[id_]['choiceExplanations'],row['choiceExplanations'])
            self.assertEqual(actual[id_]['bodyBlocks'][0],{'type':'text','text':row['stem']})



class Autumn2024ReasoningTests(unittest.TestCase):
    def test_waiting_cache_capacity_and_reliability(self):
        self.assertEqual((Fraction(2,5)/(1-Fraction(2,5)))/(Fraction(1,4)/(1-Fraction(1,4))),2)
        self.assertAlmostEqual(float(Fraction(95,100)/30+Fraction(5,100)),.0816666667)
        self.assertEqual(min(100_000_000/1_000_000,80_000_000/(200_000*8)),50)
        for n in range(1,100):
            a=Fraction(n,100);parallel=1-(1-a)**2
            mixed=parallel*a;branches=1-(1-a*a)**2
            self.assertGreater(parallel,branches);self.assertGreater(branches,mixed)
        self.assertEqual(800*600*24*30,345_600_000)
        self.assertEqual(Fraction(8,5)/Fraction(3,5),Fraction(8,3))

    def test_bpr_inventory_schedule_and_game(self):
        import itertools
        benefit=lambda count,outsource:(5-count)*600+(count*1800-(5000 if outsource else 7000))*Fraction(20,100)-(700 if outsource else 0)
        self.assertEqual([benefit(c,o) for c,o in [(4,True),(4,False),(5,True),(5,False)]],[340,640,100,400])
        cost={'a':{'b':2,'c':1,'d':2},'b':{'a':1,'c':1,'d':2},'c':{'a':3,'b':2,'d':2},'d':{'a':4,'b':3,'c':2}}
        values=[(sum(cost[p[i]][p[i+1]] for i in range(3)),p) for p in itertools.permutations('abcd')]
        self.assertEqual(min(v for v,p in values),4)
        self.assertIn((4,('b','a','c','d')),values)
        manufacturing_a=300-100;manufacturing_sub=3*manufacturing_a-100
        self.assertEqual(2*manufacturing_a+manufacturing_sub-300,600)
        payoffs=[[(40,20),(50,30)],[(30,10),(25,25)]]
        equilibria=[(r,c) for r in range(2) for c in range(2)
                    if all(payoffs[r][c][0]>=payoffs[rr][c][0] for rr in range(2))
                    and all(payoffs[r][c][1]>=payoffs[r][cc][1] for cc in range(2))]
        self.assertEqual(equilibria,[(0,1)])
        self.assertGreater(Fraction(1000-500,1000),Fraction(1000-800,1000))
        self.assertGreater(Fraction(400,1)/Fraction(1,2),Fraction(100,1)/Fraction(1,5))

    def test_sql_window_first_attempt(self):
        import sqlite3
        db=sqlite3.connect(':memory:')
        db.execute('CREATE TABLE grades(student TEXT, attempt INTEGER, points INTEGER)')
        db.executemany('INSERT INTO grades VALUES(?,?,?)',[('S01',1,70),('S01',7,80),('S02',2,85),('S02',5,82),('S03',3,83),('S03',9,78),('S03',12,90),('S04',6,100)])
        grouped=db.execute('SELECT a.* FROM grades a JOIN (SELECT student, MIN(attempt) first FROM grades GROUP BY student) b ON a.student=b.student AND a.attempt=b.first ORDER BY a.student').fetchall()
        window=db.execute('SELECT student,attempt,points FROM (SELECT *, ROW_NUMBER() OVER(PARTITION BY student ORDER BY attempt) n FROM grades) WHERE n=1 ORDER BY student').fetchall()
        self.assertEqual(grouped,window)
        self.assertEqual(window,[('S01',1,70),('S02',2,85),('S03',3,83),('S04',6,100)])
        db.close()


class Spring2024ReasoningTests(unittest.TestCase):
    def test_hamming_corrects_every_single_bit_error(self):
        import itertools
        syndrome=lambda bits:[sum(bits[i-1] for i in positions)%2 for positions in [(1,3,5,7),(2,3,6,7),(4,5,6,7)]]
        codewords=[list(bits) for bits in itertools.product([0,1],repeat=7) if syndrome(bits)==[0,0,0]]
        self.assertEqual(len(codewords),16)
        for word in codewords:
            for i in range(7):
                damaged=word.copy();damaged[i]^=1
                checks=syndrome(damaged);position=sum(c*(2**j) for j,c in enumerate(checks))
                self.assertEqual(position,i+1)
                damaged[position-1]^=1;self.assertEqual(damaged,word)
        bits=list(map(int,'1000101'));self.assertEqual(syndrome(bits),[1,1,0])
        bits[2]^=1;self.assertEqual(''.join(map(str,bits)),'1010101')

    def test_loops_traversal_and_overlapping_copy(self):
        for maximum in range(1,30):
            x=1;n=1
            while True:
                x*=n;n+=1
                if n>maximum:break
            self.assertEqual(x,math.factorial(maximum))
        tree=('＋',('A',None,None),('÷',('×',('B',None,None),('C',None,None)),('−',('D',None,None),('E',None,None))))
        def traverse(t):
            return '' if t is None else traverse(t[2])+traverse(t[1])+t[0]
        self.assertEqual(traverse(tree),'ED−CB×÷A＋')
        def transfer(source,target,direction):
            memory={i:i for i in range(990,1020)};original=memory.copy()
            for step in range(4):
                delta=step*(-1 if direction else 1)
                memory[target+delta]=memory[source+delta]
            return [memory[i] for i in range(1003,1007)]==[original[i] for i in range(1001,1005)]
        self.assertEqual([transfer(*args) for args in [(1001,1003,0),(1001,1003,1),(1004,1006,0),(1004,1006,1)]],[False,False,False,True])

    def test_resource_deadlock_exhaustive_interleavings(self):
        def has_deadlock(second):
            sequences=['XYZ',second];pending=[(0,0)];visited=set()
            while pending:
                state=pending.pop()
                if state in visited:continue
                visited.add(state)
                held=[set(sequences[i][:state[i]]) if state[i]<3 else set() for i in range(2)]
                successors=[]
                for i in range(2):
                    if state[i]<3 and sequences[i][state[i]] not in held[1-i]:
                        updated=list(state);updated[i]+=1;successors.append(tuple(updated))
                if not successors and state!=(3,3):return True
                pending.extend(successors)
            return False
        self.assertEqual([has_deadlock(order) for order in ['XYZ','ZXY','ZYX']],[False,True,True])
        arrival=[0,1,2,3]
        def completion(slots):
            available=[0]*slots
            for timestamp in arrival:
                i=min(range(slots),key=lambda i:available[i]);available[i]=max(timestamp,available[i])+4
            return max(available)
        self.assertEqual((completion(1),completion(2)),(16,9))

    def test_inventory_outer_join_and_null(self):
        import sqlite3
        db=sqlite3.connect(':memory:')
        db.executescript("CREATE TABLE parts(id TEXT, reorder INTEGER); CREATE TABLE stock(id TEXT, quantity INTEGER); INSERT INTO parts VALUES('P01',100),('P02',150),('P03',100); INSERT INTO stock VALUES('P01',90),('P01',90),('P02',150);")
        def query(expression):
            return db.execute(f"SELECT parts.id, CASE WHEN reorder>{expression} THEN '必要' ELSE '不要' END FROM parts LEFT JOIN stock ON parts.id=stock.id GROUP BY parts.id,reorder ORDER BY parts.id").fetchall()
        expected=[('P01','不要'),('P02','不要'),('P03','必要')]
        expressions=['COALESCE(MIN(quantity),0)','COALESCE(MIN(quantity),NULL)','COALESCE(SUM(quantity),0)','COALESCE(SUM(quantity),NULL)']
        self.assertEqual([query(e)==expected for e in expressions],[False,False,True,False]);db.close()

    def test_timing_network_and_memory(self):
        self.assertEqual(Fraction(15-60,10-60),Fraction(9,10))
        self.assertEqual(Fraction(15*4,10)/20+Fraction(15*4,10)*Fraction(3,100),Fraction(48,100))
        self.assertEqual(2*(6*640+7),7694)
        p=-math.expm1(12000*math.log1p(-.000001))
        self.assertAlmostEqual(10000*p,119.2829305698352,places=5)
        dag={1:[(2,3),(3,2)],2:[(3,1),(4,4),(5,2)],3:[(5,2)],4:[(5,0),(6,1)],5:[(6,1)]}
        def paths(node,target,total=0):
            if node==target:return [total]
            return [x for nxt,days in dag.get(node,[]) for x in paths(nxt,target,total+days)]
        self.assertEqual(max(paths(1,5)),7)

    def test_expected_value_billing_and_profit_thresholds(self):
        self.assertEqual(Fraction(7,10)*180+Fraction(3,10)*50-100,41)
        self.assertEqual(Fraction(7,10)*120+Fraction(3,10)*40-50,46)
        revenues=[250*4000,1500*700,3300*300,650*1600]
        self.assertEqual([r*12-10500000 for r in revenues],[1500000,2100000,1380000,1980000])
        flows=[[100,150,200,250,300],[100,200,300,200,100],[200,150,100,150,200],[300,200,100,50,50]]
        def payback(values):
            accumulated=0
            for year,value in enumerate(values,1):
                accumulated+=value
                if accumulated>=500:return year
        self.assertEqual([payback(v) for v in flows],[4,3,4,2])
        profit=lambda n:90*n-157500
        self.assertLess(profit(2861),100000);self.assertGreaterEqual(profit(2862),100000)
        margin=1-Fraction(300,500);self.assertEqual(Fraction(180,1)/margin,450)


class Autumn2023ReasoningTests(unittest.TestCase):
    def test_displayed_sql_inventory_and_subnet_boundaries(self):
        import sqlite3,ipaddress
        from presentation import TABLES,CODES
        connection=sqlite3.connect(':memory:')
        connection.execute('CREATE TABLE 製品 (製品番号 TEXT, 製品名 TEXT, 単価 INTEGER)')
        connection.execute('CREATE TABLE 在庫 (倉庫コード TEXT, 製品番号 TEXT, 在庫数 INTEGER)')
        products,stock=TABLES['ap-2023-autumn-q29']
        connection.executemany('INSERT INTO 製品 VALUES (?,?,?)',[(id_,name,int(price.replace(',',''))) for id_,name,price in products['rows']])
        connection.executemany('INSERT INTO 在庫 VALUES (?,?,?)',[(warehouse,id_,int(count)) for warehouse,id_,count in stock['rows']])
        result=connection.execute(CODES['ap-2023-autumn-q29'][0]['text']).fetchall()
        self.assertEqual(sorted(result),[('MZ1000',),('XZ3000',)])
        # Total stock is 50, but each stock row is <=30. EXISTS tests each
        # qualifying row, not the sum; absent inventory also qualifies.
        self.assertEqual(connection.execute("SELECT SUM(在庫数) FROM 在庫 WHERE 製品番号='XZ3000'").fetchone()[0],50)
        connection.close()
        network=ipaddress.ip_network('172.30.123.45/255.255.252.0',strict=False)
        self.assertEqual(str(network.network_address),'172.30.120.0')
        self.assertEqual(str(network.broadcast_address),'172.30.123.255')
        self.assertEqual(Fraction(1000*1000*8,100_000_000)*2,Fraction(16,100))

    def test_feedback_latch_and_majority_circuits(self):
        x,y=0,1
        for s in [0,1]:
            for _ in range(4):
                x=int(not(s and y));y=int(not x)  # R remains 1.
            self.assertEqual((x,y),(1,0))
        for a in [0,1]:
            for b in [0,1]:
                for c in [0,1]:
                    self.assertEqual(bool((a and b) or (b and c) or (a and c)),a+b+c>=2)
                    self.assertFalse((a!=b) and (b!=c) and (a!=c))

    def test_bit_exchange_postfix_and_sort_states(self):
        for x in range(4):
            self.assertEqual(2*x-3*(x//2),int(f'{x:02b}'[::-1],2))
        stack=[]
        for token in ['16','8','4','2','-','*','+']:
            if token.isdigit():stack.append(int(token));continue
            right=stack.pop();left=stack.pop()
            stack.append({'-':lambda a,b:a-b,'*':lambda a,b:a*b,'+':lambda a,b:a+b}[token](left,right))
        self.assertEqual(stack,[32])
        values=[3,5,9,6,1,2];states=[]
        for stop in range(5,0,-1):
            for i in range(stop):
                if values[i]>values[i+1]:values[i],values[i+1]=values[i+1],values[i]
            states.append(values[:])
        self.assertEqual(states[:2],[[3,5,6,1,2,9],[3,5,1,2,6,9]])
        self.assertEqual(states[-1],[1,2,3,5,6,9])

    def test_two_dimensional_parity_and_linked_list(self):
        values=[[1,0,0,0],[0,1,1,0],[0,0,1,0],[1,1,0,1]]
        row_parity=[sum(row)%2 for row in values]
        col_parity=[sum(row[c] for row in values)%2 for c in range(4)]
        self.assertEqual(row_parity,[1,0,1,1]);self.assertEqual(col_parity,[0,0,0,1])
        for r in range(4):
            for c in range(4):
                corrupted=copy.deepcopy(values);corrupted[r][c]^=1
                bad_rows=[i for i in range(4) if sum(corrupted[i])%2!=row_parity[i]]
                bad_cols=[j for j in range(4) if sum(row[j] for row in corrupted)%2!=col_parity[j]]
                self.assertEqual((bad_rows,bad_cols),([r],[c]))
        elem={1:'A',2:'F',3:'D',4:'B',5:'E',6:'C'}
        nxt={1:4,2:0,3:5,4:3,5:2};prev={1:0,2:5,3:4,4:1,5:3}
        right=nxt[3];nxt[6]=right;prev[6]=3;nxt[3]=6;prev[right]=6
        head=1;forward=[]
        while head:forward.append(elem[head]);head=nxt[head]
        tail=2;backward=[]
        while tail:backward.append(elem[tail]);tail=prev[tail]
        self.assertEqual(forward,list('ABDCEF'));self.assertEqual(backward,forward[::-1])

    def test_availability_weighted_average_and_preemptive_deadlines(self):
        self.assertAlmostEqual(99/(99+2),0.98,places=2)
        self.assertEqual(Fraction(30-60,20-60),Fraction(3,4))
        responses=[]
        # Simulate execution one millisecond at a time, independently of the
        # fixed-point response-time equation used in the worked explanation.
        for a_time,a_period,b_time,b_period in [(2,4,3,8),(3,6,4,9),(3,5,5,13),(4,6,5,15)]:
            a_remaining=0;b_remaining=b_time
            for time in range(30):
                if time%a_period==0:a_remaining+=a_time
                if a_remaining:a_remaining-=1
                elif b_remaining:b_remaining-=1
                if not b_remaining:responses.append(time+1);break
        self.assertEqual(responses,[7,10,14,17])
        self.assertEqual([r<=p for r,p in zip(responses,[8,9,13,15])],[True,False,False,False])


class NativePresentationTests(unittest.TestCase):
    def test_native_karnaugh_table_against_boolean_function(self):
        from presentation import TABLES
        table=TABLES['ap-2025-autumn-q01'][0]
        for row in table['rows']:
            a,b=map(int,row[0])
            for cd,value in zip(table['headers'][1:],row[1:]):
                c,d=map(int,cd)
                self.assertEqual(int(value),int((not a and not b and not d) or (b and d)))

    def test_converted_questions_never_reference_whole_originals(self):
        bank=json.loads((ROOT/'Qualifications/applied-information/questions.json').read_text())
        reviews=editorial.load_editorial(bank['questions'])
        for question in bank['questions']:
            if question['id'] not in reviews:continue
            self.assertEqual(question['bodyBlocks'][0]['type'],'text')
            for block in question['bodyBlocks']:
                if block['type']=='image':
                    self.assertEqual(block['assetName'],question['id']+'-diagram.jpg')
        self.assertFalse((ROOT/'Qualifications/applied-information/WrittenResources').exists())
        self.assertFalse((ROOT/'Qualifications/applied-information/written-booklets.json').exists())


if __name__=='__main__':unittest.main()
