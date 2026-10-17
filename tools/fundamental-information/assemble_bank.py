#!/usr/bin/env python3
"""Assemble reviewed source files without modifying original questions."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / 'docs/fundamental-information/content'
DEST = ROOT / 'Qualifications/fundamental-information'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--allow-incomplete', action='store_true', help='Development only: mark bank as draft')
    args = parser.parse_args()
    questions, sets, missing = [], [], []
    expected = {'past.json': 104, 'practice-a.json': 660, 'practice-b.json': 240}
    for name, count in expected.items():
        path = CONTENT / name
        if not path.exists():
            missing.append(name)
            continue
        data = json.loads(path.read_text())
        if len(data['questions']) != count:
            missing.append(f'{name} ({len(data["questions"])}/{count})')
        questions.extend(data['questions'])
        sets.extend(data['mockSets'])
    if missing and not args.allow_incomplete:
        raise SystemExit('Missing content: ' + ', '.join(missing))
    assert len({q['id'] for q in questions}) == len(questions), 'duplicate question ID'
    assert len({s['id'] for s in sets}) == len(sets), 'duplicate set ID'
    questions.sort(key=lambda q: (-q['year'], q['kind'] != 'past', q['subject'], q['mockSetID'], q['questionNumber']))
    bank = {'version': 2, 'questions': questions, 'mockSets': sets}
    if missing:
        bank['isDraft'] = True
    (DEST / 'questions.json').write_text(json.dumps(bank, ensure_ascii=False, indent=2) + '\n')
    config_path = DEST / 'qualification.json'
    config = json.loads(config_path.read_text())
    config['freeQuestionIDs'] = [q['id'] for q in questions if q['kind'] == 'past' or q['mockSetID'] in {'fe-practice-a-01', 'fe-practice-b-01'}]
    config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(questions)} questions, {len(sets)} sets, {len(config["freeQuestionIDs"])} free; draft={bool(missing)}')

if __name__ == '__main__':
    main()
