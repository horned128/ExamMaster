#!/usr/bin/env python3
"""Build the AP bank from IPA source PDFs, verified answers and reviewed text.

OCR locates source boundaries; pending questions retain their original PDF
image, while individually reviewed questions are rendered as native text,
tables and only the figures needed to preserve their meaning. Complete 1...80
sets and source hashes are required before assembly. The shipped question bank
is intentionally limited to the reviewed 2016 spring through 2025 autumn sets.
"""
import hashlib
import json
import re
import shutil
import unicodedata
from collections import Counter
from pathlib import Path

import fitz
from predictions import build_sets
from editorial import apply_editorial
from presentation import apply_native, ORIGINALS

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/applied-information"
EVIDENCE = DOCS / "evidence"
APP = ROOT / "Qualifications/applied-information"
LABELS = "アイウエ"
SUBJECTS = {"T":"テクノロジ", "M":"マネジメント", "S":"ストラテジ"}
PERIODS = {"spring":"春期", "autumn":"秋期", "special":"特別"}
RELEASE_START_YEAR = 2016


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def load_answers(document, ranges):
    override = json.loads((DOCS / "answer-overrides.json").read_text()).get(document["file"])
    if override:
        sequence = "".join(override["answerColumns"])
        assert len(sequence)==80 and set(sequence)<=set(LABELS)
        return {n: (LABELS.index(sequence[n-1]), next(subject for a,b,subject in override["subjectRanges"] if a<=n<=b)) for n in range(1,81)}
    text = unicodedata.normalize("NFKC", (EVIDENCE / (document["file"] + ".txt")).read_text())
    rows = re.findall(r"問\s*(\d+)\s*([アイウエ])(?:\s*([TMS]))?", text)
    assert len(rows)==80 and {int(n) for n,_,_ in rows}==set(range(1,81)), document["file"]
    return {int(n): (LABELS.index(a), SUBJECTS[subject] if subject else next(s for start,end,s in ranges if start<=int(n)<=end)) for n,a,subject in rows}


def markers(ocr):
    found, ranges = [], []
    expected = 1
    for page in ocr["pages"]:
        for line in sorted(page["lines"], key=lambda x: x["box"][1]):
            text = unicodedata.normalize("NFKC", line["text"])
            group = re.search(r"問\s*(\d+)\s*から問\s*(\d+)\s*までは", text)
            if group:
                subject = "マネジメント" if "マネジ" in text else "ストラテジ" if "ストラテ" in text else "テクノロジ"
                ranges.append((int(group[1]),int(group[2]),subject))
                continue
            match = re.match(r"^[・.、\s]*(?:間)?[問間]\s*(\d+)", text)
            if match and line["box"][0] < .14 and match[1].startswith(str(expected)):
                # Digits may run together in OCR (問14 + 1台 => 問141).
                found.append(dict(number=expected, page=page["page"], y=line["box"][1],
                                  markerText=text, markerBox=line["box"]))
                expected += 1
    assert expected==81 and len(found)==80, (ocr["file"],expected)
    if not ranges:
        ranges = [(1,50,"テクノロジ"),(51,60,"マネジメント"),(61,80,"ストラテジ")]
    assert set(n for a,b,_ in ranges for n in range(a,b+1))==set(range(1,81)), ranges
    return found, ranges


def category(subject, text):
    rules = [
        ("セキュリティ", ["暗号", "認証", "脆弱", "攻撃", "署名", "マルウェア", "リスクアセスメント"]),
        ("データベース", ["SQL", "データベース", "関係モデル", "正規化", "トランザクション", "外部キー"]),
        ("ネットワーク", ["LAN", "ルータ", "通信", "TCP", "DNS", "IPアドレス", "HTTP"]),
        ("アルゴリズム・データ構造", ["アルゴリズム", "探索", "ソート", "スタック", "キュー", "リスト", "配列"]),
        ("コンピュータシステム", ["CPU", "キャッシュ", "記憶", "RAID", "稼働率", "プロセッサ", "パイプライン", "クラウド", "クロック", "割込み"]),
        ("開発技術", ["テスト", "設計", "モジュール", "レビュー", "UML", "開発", "要求", "オブジェクト", "クラス"]),
        ("AI・データ分析", ["学習", "AI", "データマイニング", "ニューラル", "回帰分析"]),
        ("サービス管理", ["サービス", "ITIL", "SLA", "インシデント"]),
        ("システム監査", ["監査"]),
        ("会計・財務", ["利益", "損益", "原価", "財務", "売上", "NPV", "投資", "キャッシュフロー"]),
        ("法務", ["著作", "特許", "契約", "法律", "個人情報", "労働", "法に", "法律"]),
        ("システム戦略・企画", ["システム化", "RFP", "ERP", "CRM", "SCM", "BPR", "システム戦略"])
    ]
    allowed = {"テクノロジ": set(x[0] for x in rules[:7]),
               "マネジメント":{"サービス管理","システム監査"},
               "ストラテジ":{"会計・財務","法務","システム戦略・企画"}}
    for title, keywords in rules:
        if title in allowed[subject] and any(word in text for word in keywords): return title
    return {"テクノロジ":"基礎理論・その他技術", "マネジメント":"プロジェクト管理", "ストラテジ":"経営戦略・企業活動"}[subject]


def build_past(year, documents):
    result, sets, crops = [], [], []
    for booklet in sorted([d for d in documents if d["section"]=="A" and d["role"]=="qs"],
                          key=lambda d: d["administration"]):
        period = booklet["administration"]
        period_title = "10月" if year==2020 else PERIODS[period]
        answers_doc = next(d for d in documents if d["section"]=="A" and d["role"]=="ans" and d["administration"]==period)
        raw = (EVIDENCE / booklet["file"]).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==booklet["sha256"]
        pdf = fitz.open(stream=raw,filetype="pdf")
        ocr = json.loads((EVIDENCE / Path(booklet["file"]).with_suffix(".ocr.json")).read_text())
        starts, ranges = markers(ocr)
        answers = load_answers(answers_doc,ranges)
        set_id = f"ap-{year}-{period}"
        qs = []
        for i, start in enumerate(starts):
            n=start["number"]
            next_start = starts[i+1] if i+1 < len(starts) else dict(page=start["page"]+1,y=.94)
            blocks, raw_lines, boxes = [], [], []
            for page_number in range(start["page"],next_start["page"]+1):
                if page_number > len(pdf): break
                top = max(.05,start["y"]-.008) if page_number==start["page"] else .075
                bottom = next_start["y"]-.014 if page_number==next_start["page"] else .945
                if bottom<=top: continue
                page_lines=[l for l in ocr["pages"][page_number-1]["lines"] if top<=l["box"][1]<bottom]
                if not page_lines: continue
                text="\n".join(l["text"] for l in page_lines)
                if len(text.strip())<10: continue
                page=pdf[page_number-1]
                clip=fitz.Rect(.075*page.rect.width,top*page.rect.height,.94*page.rect.width,bottom*page.rect.height)
                name=f"{set_id}-q{n:02d}-p{page_number:02d}.jpg"
                ORIGINALS.mkdir(parents=True,exist_ok=True)
                output=ORIGINALS / name
                previous=APP / "Figures" / name
                if not output.exists() and previous.exists(): shutil.copyfile(previous,output)
                if not output.exists(): page.get_pixmap(matrix=fitz.Matrix(2.4,2.4),clip=clip,alpha=False).save(output,jpg_quality=88)
                if not previous.exists(): shutil.copyfile(output,previous)
                alt=f"{year}年度{period_title} 応用情報技術者試験 午前 問{n}。原問の文字認識補助（数式や図表の認識には誤りがあり得ます）：\n{text}"
                blocks.append(dict(type="image",assetName=name,altText=alt,
                                   caption=f"IPA公式原問・問{n}（タップで拡大）"))
                raw_lines.extend(page_lines)
                boxes.append(dict(asset=name,page=page_number,box=[.075,top,.94,bottom],sha256=hashlib.sha256(output.read_bytes()).hexdigest()))
            assert blocks, (set_id,n)
            marker_text=start["markerText"]
            prefix=re.match(r"^[・.、\s]*(?:間)?[問間]\s*",marker_text)
            intro=marker_text[prefix.end()+len(str(n)):].strip()
            # A short list preview; source images, not this OCR preview, define the question.
            if len(intro)<5: intro=f"公式原問・問{n}"
            correct,subject=answers[n]
            source=f"IPA {year}年度 {period_title} 応用情報技術者試験 午前 問{n}"
            explanation=(f"公式正答：{LABELS[correct]}。{source}の公式解答例に基づいて採点します。\n"
                         "本問は原問と公式正答を収録しています。詳細な理由解説は未収録です。選択肢の根拠を自分の言葉で確認し、判断できなかった条件や用語を復習してください。\n"
                         "過去問は当時の法令・仕様・用語に基づくものです。現在の制度や技術とは異なる場合があります。")
            row=dict(id=f"{set_id}-q{n:02d}",year=year,subject=subject,category=category(subject,intro),
                     stem=intro,choices=[f"原問の{label}" for label in LABELS],correctIndex=correct,
                     explanation=explanation,source=source,questionNumber=n,difficulty=3,
                     tags=[subject],concepts=[category(subject,intro)],administration=period,kind="past",
                     mockSetID=set_id,bodyBlocks=blocks)
            result.append(row); qs.append(row)
            crops.append(dict(id=row["id"],booklet=booklet["file"],answerDocument=answers_doc["file"],
                              correctIndex=correct,markerText=start["markerText"],markerBox=start["markerBox"],crops=boxes))
        sets.append(dict(id=set_id,title=f"{year}年度 {period_title} 科目A（旧午前）",kind="past",
                         questionIDs=[q["id"] for q in qs],questionCount=80,minutes=150))
    return result,sets,crops


def main():
    APP.mkdir(parents=True,exist_ok=True)
    (APP/"Figures").mkdir(exist_ok=True)
    sources=json.loads((DOCS/"sources.json").read_text())
    predictions,sets=build_sets()
    questions,crops=[],[]
    for year in sorted((x for x in sources["years"] if x["year"] >= RELEASE_START_YEAR),key=lambda x:x["year"],reverse=True):
        q,s,c=build_past(year["year"],year["documents"])
        questions.extend(q); sets.extend(s); crops.extend(c)
        print(year["year"],len(q),"past questions",flush=True)
    assert len(questions)==1520 and len(sets)==22
    questions.extend(predictions)
    reviewed=apply_editorial(questions, crops)
    assert len(reviewed)==1520, "リリース対象の全過去問を校閲してください。"
    apply_native(questions, reviewed, crops)
    used_images={b["assetName"] for q in questions for b in q.get("bodyBlocks",[]) if b["type"]=="image"}
    for image in (APP/"Figures").glob("*.jpg"):
        if image.name not in used_images:
            image.unlink()
    dump(APP/"questions.json",dict(version=2,isDraft=False,questions=questions,mockSets=sets))
    dump(DOCS/"figure-crops.json",crops)
    qualification=json.loads((APP/"qualification.json").read_text())
    qualification["freeQuestionIDs"]=[q["id"] for q in questions if q["year"]==2025]
    dump(APP/"qualification.json",qualification)
    print("Total",len(questions),"科目A questions",flush=True)
    print("Question-specific explanations and in-session reviews:",len(reviewed),"/ 1520 shipped past questions",flush=True)


if __name__=="__main__":main()
