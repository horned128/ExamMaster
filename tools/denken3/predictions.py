"""Three complete original practice rounds for the next exam held in 2027.

2027 is the calendar year of sitting; the official fiscal year is FY2026 lower.
No claim is made about actual forthcoming questions or an unpublished syllabus.
"""
import re
import random
import prediction_theory
import prediction_power
import prediction_machine
import prediction_law

SUBJECTS={'theory':'理論','power':'電力','machine':'機械','law':'法規'}
AUTHORS={'theory':prediction_theory,'power':prediction_power,'machine':prediction_machine,'law':prediction_law}
EXAM_TARGET={
    'calendarYear':2027, 'fiscalYear':2026, 'administration':'下期',
    'officialTitle':'令和8年度 第三種電気主任技術者 下期試験',
    'cbtStart':'2027-02-04', 'cbtEnd':'2027-02-28', 'writtenDate':'2027-03-21',
    'scheduleURL':'https://www.shiken.or.jp/chief/third/',
    'schedulePDF':'https://www03.shiken.or.jp/ecee-overview/news/upload/R08denkennittei2.pdf',
    'checkedAt':'2026-10-17',
}
REFERENCES=[
    {'title':'電気技術者試験センター：試験概要・出題分野', 'url':'https://www.shiken.or.jp/chief/third/overview/'},
    {'title':'電気技術者試験センター：令和8年度上期受験案内', 'url':'https://www.shiken.or.jp/chief/upload/20260511r8tannai0526.pdf'},
    {'title':'電気技術者試験センター：公開過去問・配点', 'url':'https://www.shiken.or.jp/chief/third/qa/'},
    {'title':'e-Gov：電気設備に関する技術基準を定める省令', 'url':prediction_law.VOLTAGE_URL},
    {'title':'経済産業省：電気設備の技術基準の解釈', 'url':prediction_law.RULES_URL},
    {'title':'経済産業省：小規模事業用電気工作物', 'url':prediction_law.SMALL_URL},
]

def build():
    questions,sets=[],[]
    for r in range(3):
        for key,subject in SUBJECTS.items():
            set_id=f'd3-2027-pred-{r+1:02d}-{key}'
            rows=AUTHORS[key].paper(r)
            expected=16 if key=='law' else 20 if key=='power' else 22
            assert len(rows)==expected
            correct_positions=[i%5 for i in range(len(rows))]
            random.Random(set_id+'-correct-positions').shuffle(correct_positions)
            ids=[]
            for position,(label,spec) in enumerate(rows):
                number=int(re.match(r'\d+',label)[0])
                part=label[-1] if label[-1] in 'ab' else ''
                qid=f'{set_id}-q{number:02d}{part}'
                ids.append(qid)
                correct_index=correct_positions[position]
                wrongs=[c for c in spec['choices'] if c!=spec['answer']]
                random.Random(qid).shuffle(wrongs)
                choices=wrongs.copy();choices.insert(correct_index,spec['answer'])
                points=(6 if number<=10 or label in ['11a','12a'] else 7) if key=='law' else 5
                display=f'問{number}'+(f'({part})' if part else '')
                source=f'ピヨトレ！ オリジナル · 2027年実施向け（令和8年度下期対策）第{r+1}回 {subject} {display}'
                questions.append({
                    'id':qid,'year':2027,'subject':subject,'category':spec['category'],
                    'stem':spec['stem'],'choices':choices,'correctIndex':correct_index,
                    'explanation':spec['explanation'],'source':source,'questionNumber':number,
                    'difficulty':3 if part else 2,'points':points,
                    'tags':['オリジナル予想','2027年実施向け','令和8年度下期対策',f'第{r+1}回','B問題' if part else 'A問題']+
                           (['選択問題'] if key in ['theory','machine'] and number>=17 else []),
                    'concepts':[spec['category']], 'administration':f'2027年実施向け予想 第{r+1}回',
                    'kind':'prediction','mockSetID':set_id,
                    'bodyBlocks':[{'type':'text','text':spec['stem']}],
                })
            sets.append({'id':set_id,'title':f'2027年実施向け予想 第{r+1}回 · {subject}',
                         'kind':'prediction','questionIDs':ids,'questionCount':len(ids),'minutes':65 if key=='law' else 90})
    assert len(questions)==240 and len(sets)==12
    return questions,sets
