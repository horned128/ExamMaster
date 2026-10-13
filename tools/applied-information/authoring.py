"""Save individually inspected editorial rows; never certify raw OCR in bulk."""
import json
from pathlib import Path
from editorial import ROOT, DOCS, digest, source_snapshot

class EditorialWriter:
    def __init__(self, set_id):
        self.set_id=set_id
        self.path=DOCS/'content'/f'{set_id}.json'
        self.rows={r['id']:r for r in json.loads(self.path.read_text())['questions']} if self.path.exists() else {}
        self.bank={q['id']:q for q in json.loads((ROOT/'Qualifications/applied-information/questions.json').read_text())['questions']}
        self.crops={q['id']:q for q in json.loads((DOCS/'figure-crops.json').read_text())}
        self.documents={d['file']:d for y in json.loads((DOCS/'sources.json').read_text())['years'] for d in y['documents']}

    def add(self, row, notes):
        row=dict(row);id_=row['id']
        assert id_.rsplit('-q',1)[0]==self.set_id and id_ not in self.rows
        assert row['correctIndex']==self.crops[id_]['correctIndex']
        assert len(row['choices'])==len(set(row['choices']))==len(row['choiceExplanations'])==4
        assert row['stem'] and row['explanation'] and row['steps'] and notes
        row.setdefault('difficulty',3);row.setdefault('references',[])
        row.setdefault('concepts',row['tags'])
        row.setdefault('accessibilityText',row['stem']+'\n'+'\n'.join(f'{l}：{v}' for l,v in zip('アイウエ',row['choices'])))
        row.pop('review',None)
        row['review']=dict(status='reviewed-in-session',reviewedOn='2026-10-13',reviewer='Codex（制作内AI校閲）',notes=notes,
                           sourceSnapshot=source_snapshot(self.bank[id_],self.crops,self.documents),editorialSnapshot=digest(row))
        self.rows[id_]=row

    def save(self):
        temporary=self.path.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(dict(setID=self.set_id,questions=sorted(self.rows.values(),key=lambda r:r['id'])),ensure_ascii=False,indent=2)+'\n')
        temporary.replace(self.path)
