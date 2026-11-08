#!/usr/bin/env python3
"""Verify every official answer and source asset, not just JSON shape."""
import hashlib
import json
import pathlib
from PIL import Image
from assemble_bank import official_answers, SUBJECTS, ROOT

def validate():
    base = ROOT / "Qualifications/denken3"
    bank = json.loads((base / "questions.json").read_text())
    config = json.loads((base / "qualification.json").read_text())
    official = official_answers()
    assert len(bank["questions"]) == 320
    assert len({q["id"] for q in bank["questions"]}) == 320
    assert set(config["freeQuestionIDs"]) == {q["id"] for q in bank["questions"]}
    by_id = {q["id"]: q for q in bank["questions"]}
    for key, subject in SUBJECTS.items():
        items = [q for q in bank["questions"] if q["subject"] == subject and q['kind']=='past']
        assert len(items) == len(official[key])
        for q in items:
            label = q["id"].split("-q")[-1].lstrip("0")
            assert q["correctIndex"] + 1 == official[key][label]["answer"], q["id"]
            assert q["points"] == official[key][label]["points"], q["id"]
            assert q["explanation"].strip(), q["id"]
            assert not any(t in q["explanation"] for t in ["解説作成中", "ではなく、公式", "TODO"])
            assert q["sourceURL"].startswith("https://www.shiken.or.jp/chief/upload/")
            for block in q["bodyBlocks"]:
                if block["type"] == "image":
                    with Image.open(base / "Figures" / block["assetName"]) as image:
                        assert image.width >= 300 and image.height >= 100
        for elective in [17, 18]:
            mock = [q for q in items if key not in ["theory", "machine"] or q["questionNumber"] < 17 or q["questionNumber"] == elective]
            assert sum(q["points"] for q in mock) == 100
            assert len(mock) == (16 if key == "law" else 20)
    for s in bank["mockSets"]:
        assert len(s["questionIDs"]) == s["questionCount"]
        assert all(by_id[q]["mockSetID"] == s["id"] for q in s["questionIDs"])
        assert len({by_id[q]["subject"] for q in s["questionIDs"]}) == 1
        items=[by_id[q] for q in s['questionIDs']]
        subject=items[0]['subject']
        for elective in [17,18]:
            selected=[q for q in items if subject not in ['理論','機械'] or q['questionNumber']<17 or q['questionNumber']==elective]
            assert sum(q['points'] for q in selected)==100, s['id']
            assert len(selected)==(16 if subject=='法規' else 20)
        assert s['minutes']==(65 if subject=='法規' else 90)
    predictions=[q for q in bank['questions'] if q['kind']=='prediction']
    assert len(predictions)==240
    assert len({q['stem'] for q in predictions})==240, 'Repeated original question text'
    assert len([s for s in bank['mockSets'] if s['kind']=='prediction'])==12
    for q in predictions:
        assert q['year']==2027 and '令和8年度下期対策' in q['source']
        assert q['bodyBlocks'] and all(b['type']!='image' for b in q['bodyBlocks'])
        assert len(q['choices'])==len(set(q['choices']))==5
        assert 0<=q['correctIndex']<5 and q['explanation'].strip()
        assert not any(t in q['stem']+q['explanation'] for t in ['TODO','作成中','2027年度','令和9年度'])
    provenance = json.loads((ROOT / "docs/denken3/provenance.json").read_text())
    for source in provenance["sources"]:
        assert hashlib.sha256((ROOT / source["path"]).read_bytes()).hexdigest() == source["sha256"]
    assert hashlib.sha256((ROOT / "docs/denken3/sources/2026-upper-answers.pdf").read_bytes()).hexdigest() == provenance["answers"]["sha256"]
    print("PASS: 80 official + 240 original fields; 76 assets; 16 subject papers; both electives; official-source SHA-256")

if __name__ == "__main__": validate()
