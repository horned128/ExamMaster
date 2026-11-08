#!/usr/bin/env python3
"""Rebuild the bundled ECEE paper from original PDFs and app-authored notes.

Requires pdfplumber, Pillow and Poppler's pdftoppm. No OCR is used for marking.
"""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import tempfile
import unicodedata

import pdfplumber
from PIL import Image, ImageChops
from editorial import rows
from predictions import build as build_predictions, EXAM_TARGET, REFERENCES

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = ROOT / "docs/denken3/sources"
DEST = ROOT / "Qualifications/denken3"
SUBJECTS = {"theory": "理論", "power": "電力", "machine": "機械", "law": "法規"}
PAGE_MAP = {
    "theory": {**{str(n): [n + 3] for n in range(1, 15)}, "15": [18], "16": [19], "17": [20, 21], "18": [22, 23]},
    "power": {**{str(n): [n + 3] for n in range(1, 15)}, "15": [18, 19], "16": [20], "17": [21]},
    "machine": {**{str(n): [n + 3] for n in range(1, 15)}, "15": [18, 19], "16": [20, 21], "17": [22], "18": [23]},
    "law": {"1": [4, 5], "2": [6, 7], **{str(n): [n + 5] for n in range(3, 9)}, "9": [14, 15], "10": [16], "11": [17], "12": [18, 19], "13": [20, 21]},
}

def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

def official_answers():
    with pdfplumber.open(SOURCES / "2026-upper-answers.pdf") as doc:
        tables = doc.pages[0].extract_tables()
    assert len(tables) == 4
    result = {}
    for key, table in zip(SUBJECTS, tables):
        parsed = {}
        for label, answer, points in table[1:]:
            label = unicodedata.normalize("NFKC", label).replace("問", "").replace("(", "").replace(")", "")
            assert re.fullmatch(r"\d+[ab]?", label)
            parsed[label] = {"answer": int(answer), "points": int(points)}
        result[key] = parsed
    return result

def render_figures(key):
    path = SOURCES / f"2026-upper-{key}.pdf"
    # Respect CropBox. Some booklets contain duplicated, invisible spread content
    # outside each page's crop; extracting MediaBox would mix adjacent questions.
    with tempfile.TemporaryDirectory(prefix="denken3-") as temp, pdfplumber.open(path) as doc:
        prefix = pathlib.Path(temp) / "page"
        subprocess.run(["pdftoppm", "-f", "4", "-cropbox", "-r", "180", "-png", str(path), str(prefix)], check=True)
        for number in range(4, len(doc.pages) + 1):
            page = doc.pages[number - 1]
            box = page.cropbox
            visible = page.crop(box)
            x0, top, x1, bottom = box[0] + 47, box[1] + 45, box[2] - 47, box[3] - 52
            # Remove the subject heading and A/B/elective instructions when the
            # actual numbered question starts on this page. Keep all continuations.
            starts = [l["top"] for l in visible.extract_text_lines()
                      if re.match(r"^問\s*[0-9０-９]+\s", l["text"])]
            if starts:
                top = min(starts) - 3
            img = Image.open(next(pathlib.Path(temp).glob(f"page-{number:02d}.png"))).convert("RGB")
            sx, sy = img.width / (box[2] - box[0]), img.height / (box[3] - box[1])
            crop = img.crop((round((x0-box[0])*sx), round((top-box[1])*sy),
                             round((x1-box[0])*sx), round((bottom-box[1])*sy)))
            bounds = ImageChops.difference(crop, Image.new("RGB", crop.size, "white")).getbbox()
            assert bounds, (key, number)
            crop = crop.crop(bounds)
            padded = Image.new("RGB", (crop.width+32, crop.height+32), "white")
            padded.paste(crop, (16, 16))
            padded.save(DEST / "Figures" / f"d3-2026-upper-{key}-p{number:02d}.png", optimize=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-render", action="store_true")
    args = parser.parse_args()
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "Figures").mkdir(exist_ok=True)
    answers = official_answers()
    questions, sets, provenance = [], [], []
    for index, (key, subject) in enumerate(SUBJECTS.items(), 1):
        if not args.skip_render:
            render_figures(key)
        set_id = f"d3-2026-upper-{key}"
        ids = []
        notes = rows(key)
        assert {r[0] for r in notes} == set(answers[key])
        for label, title, category, explanation in notes:
            n = int(re.match(r"\d+", label)[0])
            part = label[-1] if label[-1] in "ab" else ""
            display = f"問{n}" + (f"({part})" if part else "")
            question_id = f"{set_id}-q{n:02d}{part}"
            ids.append(question_id)
            pages = PAGE_MAP[key][str(n)]
            source = f"出典：令和8年度上期 第三種電気主任技術者試験 {subject} {display}"
            intro = f"{display} · {title}"
            blocks = [{"type": "text", "text": intro},
                      {"type": "text", "text": f"公式問題の図中の(1)〜(5)から選んでください。{f'今回は({part})に解答します。' if part else ''}画像はタップして拡大できます。"}]
            for page in pages:
                blocks.append({"type": "image", "assetName": f"{set_id}-p{page:02d}.png",
                               "altText": f"{subject} {display} {title}の公式問題・数式・選択肢（{page-3}ページ）",
                               "caption": f"公式問題 {page-3}ページ · タップして拡大"})
            if key == "law":
                explanation += "\n\n法規は原問の指定する2026年4月1日時点の法令に基づく解説です。"
            questions.append({"id": question_id, "year": 2026, "subject": subject, "category": category,
                "stem": intro, "choices": [f"図中の({n})" for n in range(1, 6)],
                "correctIndex": answers[key][label]["answer"] - 1,
                "points": answers[key][label]["points"], "explanation": explanation,
                "source": source, "questionNumber": n, "difficulty": 3 if part else 2,
                "tags": ["令和8年度", "上期", "B問題" if part else "A問題"] + (["選択問題"] if key in ["theory", "machine"] and n >= 17 else []),
                "concepts": [category, title], "administration": "上期", "kind": "past", "mockSetID": set_id,
                "bodyBlocks": blocks,
                "sourceURL": f"https://www.shiken.or.jp/chief/upload/20260830_ch_third_q{index:02d}.pdf"})
        sets.append({"id": set_id, "title": f"令和8年度 上期 · {subject}", "kind": "past",
                     "questionIDs": ids, "questionCount": len(ids), "minutes": 65 if key == "law" else 90})
        f = SOURCES / f"2026-upper-{key}.pdf"
        provenance.append({"subject": subject, "path": str(f.relative_to(ROOT)),
                           "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
                           "url": f"https://www.shiken.or.jp/chief/upload/20260830_ch_third_q{index:02d}.pdf",
                           "answerFields": len(ids), "questionPages": PAGE_MAP[key]})
    prediction_questions,prediction_sets=build_predictions()
    questions.extend(prediction_questions)
    sets.extend(prediction_sets)
    write_json(DEST / "questions.json", {"version": 2, "questions": questions, "mockSets": sets})
    # No production ad units or purchases are required for this initial bank.
    config = {"id": "denken3", "name": "電験三種", "brandName": "ピヨトレ！",
        "subtitle": "理論・電力・機械・法規を、ひとつずつ。", "examMinutes": 90, "mockQuestionCount": 20,
        "passingPercent": 60, "minimumSubjectPercent": 0, "subjects": list(SUBJECTS.values()),
        "freeQuestionIDs": [q["id"] for q in questions], "productID": "jp.hino.piyotre.denken3.unlock",
        "accentHex": "#146C72", "mascotBaseHex": "#BDE6DD", "chickBaseHex": "#91D0C3", "iconTitle": "電験三種",
        "choiceLabels": ["(1)", "(2)", "(3)", "(4)", "(5)"], "usesFixedMocks": True,
        "mockPassTitle": "学習の目安に到達",
        "contentCredit": "過去問題・公式正答の著作権は一般財団法人電気技術者試験センターに帰属します。各問に年度・期・試験区分・科目・問番号を明記しています。原問の数式・図表・選択肢は公式PDFから画像化し、余白を調整しています。B問題は(a)(b)を別の解答欄として収録。予想3回分240解答欄、見出しと解説は本アプリ独自に作成しており、試験センターによる作成・監修・推奨を意味しません。",
        "examNote": "令和8年度上期の公式過去問80解答欄と、2027年実施向けのオリジナル予想3回分・240解答欄を収録。全320解答欄が無料です。次回試験の正式区分は令和8年度下期で、CBTは2027年2月4〜28日、筆記は3月21日。理論・機械は問17／問18の一方を選び20解答欄・90分、電力は20解答欄・90分、法規は16解答欄・65分、各100点満点です。60点は学習の目安です。予想は公式問題ではなく、実際の出題を保証しません。過去問法規は2026年4月1日、予想の法規は2026年10月17日に確認できた公開資料を基準とし、本試験の適用法令は公式受験案内を確認してください。",
        "ads": {"enabled": False, "bannerEnabled": False, "interstitialEnabled": False,
                "interstitialMinimumIntervalSeconds": 1800, "interstitialMinimumSessions": 3,
                "interstitialMinimumAnsweredQuestions": 8, "adMobAppID": "ca-app-pub-3940256099942544~1458002511",
                "bannerAdUnitID": "ca-app-pub-3940256099942544/2934735716",
                "interstitialAdUnitID": "ca-app-pub-3940256099942544/4411468910"},
        "theme": {"backgroundLight": "#EFF8F4", "backgroundDark": "#142624", "surfaceLight": "#FAFEFC", "surfaceDark": "#203632",
                  "borderLight": "#BAD6CD", "borderDark": "#4C7268", "trackLight": "#D9EDE5", "trackDark": "#324F47",
                  "mutedLight": "#45635B", "mutedDark": "#BDD5CB", "positiveLight": "#146C72", "positiveDark": "#91DCD2",
                  "reviewLight": "#A34528", "reviewDark": "#F3B59B"}}
    write_json(DEST / "qualification.json", config)
    write_json(ROOT / "docs/denken3/prediction-manifest.json", {
        "target":EXAM_TARGET,"references":REFERENCES,"roundCount":3,"subjectPaperCount":12,
        "answerFieldCount":240,"largeQuestionCount":198,"sets":prediction_sets,
        "authorship":"本アプリ独自のオリジナル教材。制作内AIによる作成・検証。公式監修や外部専門家の独立校閲ではありません。",
        "legalBasis":"2026年10月17日に確認できた公式公開資料。将来試験の法令基準日の公表とは区別する。"})
    answer_pdf = SOURCES / "2026-upper-answers.pdf"
    write_json(ROOT / "docs/denken3/provenance.json", {
        "checkedAt": "2026-10-17", "publisher": "一般財団法人電気技術者試験センター",
        "indexURL": "https://www.shiken.or.jp/chief/third/qa/", "sources": provenance,
        "answers": {"url": "https://www.shiken.or.jp/chief/upload/20260830_ch_third_a01.pdf",
                    "sha256": hashlib.sha256(answer_pdf.read_bytes()).hexdigest(), "fields": answers}})
    print(f"Built {len(questions)} answer fields, {len(sets)} subject papers")

if __name__ == "__main__":
    main()
