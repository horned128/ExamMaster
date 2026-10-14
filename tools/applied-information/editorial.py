"""Apply question-specific editorial work only while its source hashes match.

A saved review is an in-session AI editorial review, not independent human
expert review. No bulk operation certifies question reasoning or accessibility.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/applied-information"


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()


def source_snapshot(question, crops, documents):
    crop = crops[question["id"]]
    return digest({"id": question["id"], "correctIndex": crop["correctIndex"],
                   "bookletSHA256": documents[crop["booklet"]]["sha256"],
                   "answerSHA256": documents[crop["answerDocument"]]["sha256"],
                   "crops": crop["crops"]})


def load_editorial(questions, crops=None):
    by_id={q["id"]:q for q in questions}
    if crops is None:
        crops=json.loads((DOCS/"figure-crops.json").read_text())
    crops={row["id"]:row for row in crops}
    documents={d["file"]:d for row in json.loads((DOCS/"sources.json").read_text())["years"] for d in row["documents"]}
    result={}
    seen=set()
    for path in sorted((DOCS/"content").glob("*.json")):
        for row in json.loads(path.read_text())["questions"]:
            id_=row["id"]
            # Keep the full editorial archive, but validate and apply only the
            # question IDs present in this release bank.
            if id_ in seen:
                raise ValueError(f"Unknown/duplicate reviewed question: {id_}")
            seen.add(id_)
            if id_ not in by_id:
                parts=id_.split("-")
                if len(parts)>2 and parts[0]=="ap" and parts[1].isdigit() and int(parts[1])<2016:
                    continue
                raise ValueError(f"Unknown/duplicate reviewed question: {id_}")
            original=by_id[id_]
            if row["review"]["sourceSnapshot"]!=source_snapshot(original,crops,documents):
                raise ValueError(f"Original source changed after editorial review: {id_}")
            if row["correctIndex"]!=original["correctIndex"]: raise ValueError(f"Official answer mismatch: {id_}")
            if row["review"]["status"]!="reviewed-in-session": raise ValueError(f"Unreviewed editorial content: {id_}")
            required=[row["stem"],row["explanation"],row["accessibilityText"],row["review"]["notes"]]
            if not all(isinstance(s,str) and s.strip() for s in required): raise ValueError(f"Missing editorial fields: {id_}")
            if len(row["choices"])!=4 or len(set(row["choices"]))!=4 or len(row["choiceExplanations"])!=4:
                raise ValueError(f"Four distinct choices and individual explanations required: {id_}")
            if not row["steps"] or not all(s.strip() for s in row["steps"]+row["choiceExplanations"]):
                raise ValueError(f"Missing reasoning: {id_}")
            if row["review"]["editorialSnapshot"]!=digest({k:v for k,v in row.items() if k!="review"}):
                raise ValueError(f"Editorial content changed after review: {id_}")
            result[id_]=row
    for row in result.values():
        if (origin:=row.get("reusedFrom")) and origin not in result:
            raise ValueError(f"Reused explanation has no reviewed origin: {row['id']} / {origin}")
    return result


def apply_editorial(questions, crops=None):
    rows=load_editorial(questions, crops)
    for question in questions:
        if row:=rows.get(question["id"]):
            for field in ["stem","choices","explanation","choiceExplanations","steps","category","difficulty","tags","concepts"]:
                question[field]=row[field]
            if "choiceBlocks" in row:
                question["choiceBlocks"]=row["choiceBlocks"]
            for index,block in enumerate(question["bodyBlocks"]):
                block["altText"]=row["accessibilityText"] if index==0 else f"原問の続き。{question['source']}。前の図版の読み上げ説明を参照してください。"
    return rows
