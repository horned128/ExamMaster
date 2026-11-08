#!/usr/bin/env python3
"""Independent release checks: source hashes, official keys, scope and content."""
import collections
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / 'docs/fundamental-information'
APP = ROOT / 'Qualifications/fundamental-information'

def normalize(value):
    return re.sub(r'\s+', '', value)

def main():
    bank = json.loads((APP / 'questions.json').read_text())
    config = json.loads((APP / 'qualification.json').read_text())
    sources = json.loads((DOCS / 'sources.json').read_text())
    curriculum = json.loads((DOCS / 'curriculum.json').read_text())
    questions, sets = bank['questions'], bank['mockSets']
    errors = []
    def check(condition, message):
        if not condition:
            errors.append(message)
    check(not bank.get('isDraft'), 'bank is marked draft')
    check(len(questions) == 1004, f'expected 1004 questions, got {len(questions)}')
    check(len(sets) == 31, f'expected 31 sets, got {len(sets)}')
    syllabus = DOCS / 'originals/syllabus_fe_ver9_2.pdf'
    check(syllabus.exists() and hashlib.sha256(syllabus.read_bytes()).hexdigest() == curriculum['basis']['sha256'], 'syllabus hash mismatch')
    ids = [q['id'] for q in questions]
    check(len(ids) == len(set(ids)), 'duplicate IDs')
    by_id = {q['id']: q for q in questions}
    for qid in ['fe-2026-a-q06', 'fe-2025-a-q03', 'fe-2025-a-q14',
                'fe-2024-a-q01', 'fe-2024-a-q03', 'fe-2024-a-q13', 'fe-2024-a-q19',
                'fe-2023-a-q10', 'fe-2023-a-q11', 'fe-2023-a-q13', 'fe-2024-b-q03']:
        q = by_id.get(qid)
        if q:
            check(any(b['type'] in {'image', 'table'} for b in q.get('bodyBlocks', [])), f'essential figure/table missing {qid}')
    checked_keys = checked_hashes = 0
    for year in sources['years']:
        for document in year['documents']:
            original = DOCS / 'originals' / document['file']
            check(original.exists(), f'missing source {original.name}')
            if original.exists():
                check(hashlib.sha256(original.read_bytes()).hexdigest() == document['sha256'], f'changed source {original.name}')
                checked_hashes += 1
        for subject, keys in year['officialAnswerKeys'].items():
            letter = 'a' if subject == '科目A' else 'b'
            for number, label in enumerate(keys, 1):
                qid = f'fe-{year["year"]}-{letter}-q{number:02d}'
                q = by_id.get(qid)
                check(q is not None, f'missing official {qid}')
                if q:
                    check(config['choiceLabels'][q['correctIndex']] == label, f'official key mismatch {qid}')
                    check(q['kind'] == 'past' and q['subject'] == subject, f'official classification {qid}')
                    checked_keys += 1
    for q in questions:
        qid = q['id']
        check(q['subject'] in config['subjects'], f'unknown subject {qid}')
        check(2 <= len(q['choices']) <= len(config['choiceLabels']), f'choice count {qid}')
        check(len(q['choices']) == len(set(map(normalize, q['choices']))), f'duplicate choices {qid}')
        check(all('試験問題に記載されている会社名' not in c for c in q['choices']), f'booklet footer leaked into choices {qid}')
        check(0 <= q['correctIndex'] < len(q['choices']), f'answer index {qid}')
        check(len(q.get('choiceExplanations', [])) == len(q['choices']), f'choice explanations {qid}')
        check(all(str(x).strip() for x in q.get('choiceExplanations', [])), f'blank choice reason {qid}')
        check(bool(q.get('steps')) and bool(q.get('bodyBlocks')), f'missing reading content {qid}')
        if q['subject'] == '科目B':
            code = normalize('\n'.join(b.get('text', '') for b in q.get('bodyBlocks', []) if b['type'] == 'monospace'))
            if qid == 'fe-2024-b-q01':
                check(code.find('maximum(') < code.find('if('), f'function header moved after body {qid}')
            if qid == 'fe-2024-b-q03':
                check(code.count('[空欄]') == 1 and 'adjMatrix[u,v]←[空欄]' not in code, f'statement blank converted to expression blank {qid}')
            if qid == 'fe-2024-b-q05':
                check('arrayK←{otherItemsの要素数個の0}' in code and 'arrayM←{otherItemsの要素数個の0}' in code, f'missing zero initialization {qid}')
                check('(arrayM[i]×[c])÷(itemCount×arrayK[i])' in code, f'purchase association formula {qid}')
            if qid == 'fe-2023-b-q05':
                check('denominator←denominator×[b]' not in code, f'answer expression applied twice {qid}')
            for block in q.get('bodyBlocks', []):
                content = block.get('text', '')
                check(not re.search(r'←\s*\n\s*(?:endfor|endif|endwhile|return)', content), f'missing assignment/blank marker {qid}')
                check(not re.search(r'(?:プログラム|記述)中の\s*に入れる', content), f'missing prompt blank marker {qid}')
                if block['type'] == 'monospace':
                    check(not re.search(r'(?m)^\s*[abc]\s*$', content), f'detached PDF blank label {qid}')
        if q['kind'] == 'past':
            for match in re.finditer(r'(?:公式解答は|公式正答は|正答は|正答)([アイウエオカキクケコ])', q['explanation']):
                check(match.group(1) == config['choiceLabels'][q['correctIndex']], f'explanation contradicts official key {qid}: {match.group(0)}')
        for block in q.get('bodyBlocks', []) + q.get('explanationBlocks', []) + [b for blocks in q.get('choiceBlocks', []) for b in blocks]:
            kind = block.get('type')
            check(kind in {'text','monospace','formula','image','table'}, f'block type {qid}')
            if kind == 'image':
                filename = block.get('assetName', '')
                check(bool(filename) and '/' not in filename and '..' not in filename and (APP / 'Figures' / filename).exists(), f'missing image {qid}: {filename}')
                check(bool(block.get('altText')), f'image description {qid}')
            elif kind == 'table':
                check(bool(block.get('headers')) and bool(block.get('rows')), f'empty table {qid}')
                check(all(len(row) == len(block['headers']) for row in block.get('rows', [])), f'table dimensions {qid}')
            else:
                check(bool(block.get('text', '').strip()), f'empty text {qid}')
    membership = []
    for s in sets:
        members = [by_id[x] for x in s['questionIDs'] if x in by_id]
        check(len(members) == s['questionCount'] == len(set(s['questionIDs'])), f'set size {s["id"]}')
        check(all(q['mockSetID'] == s['id'] for q in members), f'set membership {s["id"]}')
        check(len(set(q['subject'] for q in members)) == 1, f'mixed subject mock {s["id"]}')
        check([q['questionNumber'] for q in members] == list(range(1, len(members)+1)), f'question order {s["id"]}')
        if members and s['kind'] == 'original':
            a = members[0]['subject'] == '科目A'
            check((s['questionCount'], s['minutes']) == ((60,90) if a else (20,100)), f'full mock format {s["id"]}')
            if not a:
                check(sum('セキュリティ' in q['category'] for q in members) == 4, f'B 16:4 ratio {s["id"]}')
        membership.extend(s['questionIDs'])
    check(collections.Counter(membership) == collections.Counter(ids), 'questions must occur in exactly one set')
    free = set(config['freeQuestionIDs'])
    check(len(free) == 184 and free.issubset(by_id), f'free scope {len(free)}')
    originals = [q for q in questions if q['kind'] == 'original']
    fingerprints = collections.defaultdict(list)
    choice_fingerprints = collections.defaultdict(list)
    for q in originals:
        body = json.dumps(q.get('bodyBlocks'), ensure_ascii=False, sort_keys=True)
        fingerprints[normalize(body) + '|'.join(sorted(map(normalize, q['choices'])))].append(q['id'])
        choice_fingerprints['|'.join(sorted(map(normalize, q['choices'])))].append(q['id'])
    duplicate_questions = [v for v in fingerprints.values() if len(v) > 1]
    repeated_choices = [v for v in choice_fingerprints.values() if len(v) > 1]
    check(not duplicate_questions, f'exact duplicate original questions: {duplicate_questions[:5]}')
    report = {
        'checkedOn': '2026-10-15', 'questions': len(questions), 'sets': len(sets),
        'bySubject': dict(collections.Counter(q['subject'] for q in questions)),
        'byKind': dict(collections.Counter(q['kind'] for q in questions)),
        'free': len(free), 'officialKeysChecked': checked_keys, 'sourceHashesChecked': checked_hashes,
        'curriculumVersion': '9.2',
        'exactDuplicateOriginals': duplicate_questions,
        'repeatedChoiceSetsForEditorialReview': repeated_choices,
        'errors': errors, 'passed': not errors,
        'limits': 'Automated structure, source and calculation checks do not replace expert editorial review.'
    }
    (DOCS / 'validation-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k:v for k,v in report.items() if k not in {'repeatedChoiceSetsForEditorialReview','exactDuplicateOriginals'}}, ensure_ascii=False, indent=2))
    print(f'Repeated original choice sets needing editorial review: {len(repeated_choices)}')
    raise SystemExit(1 if errors else 0)

if __name__ == '__main__':
    main()
