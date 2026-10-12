#!/usr/bin/env python3
"""Structural checks plus evidence/review coverage. --release fails incomplete work."""
import argparse
import hashlib
import ipaddress
import json
import re
from collections import Counter
from pathlib import Path
import jsonschema
import fitz

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "Qualifications/network-specialist"
DOCS = ROOT / "docs/network-specialist"

def load(path):
    return json.loads(path.read_text())

def digest(question):
    blocks = question.get("bodyBlocks", []) + question.get("explanationBlocks", [])
    blocks += [block for choice in question.get("choiceBlocks", []) for block in choice]
    figures = {}
    for block in blocks:
        if block["type"] == "image":
            name = block["assetName"]
            path = APP / "Figures" / name
            figures[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
    payload = {"question": question, "figureSHA256": figures}
    return hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()

def official_answers(path):
    """Read the hash-checked original PDF, not a mutable text sidecar."""
    with fitz.open(path) as doc:
        text = "\n".join(page.get_text() for page in doc)
    return {int(n): list("アイウエ").index(c) for n, c in re.findall(r'問\s*(\d+)\s*([アイウエ])', text)}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    bank, config = load(APP / "questions.json"), load(APP / "qualification.json")
    schema = load(Path(__file__).with_name("questions.schema.json"))
    jsonschema.Draft202012Validator(schema).validate(bank)
    questions = bank["questions"]
    by_id = {q["id"]: q for q in questions}
    reviews = load(DOCS / "reviews.json")["questionReviews"]
    snapshots_path = DOCS / "review-snapshots.json"
    snapshots = load(snapshots_path) if snapshots_path.exists() else {}
    errors, incomplete = [], []
    def require(condition, message):
        if not condition: errors.append(message)
    require(len(by_id) == len(questions), "問題ID重複")
    require(all(2013 <= q["year"] <= 2025 for q in questions if q["kind"] == "past"), "公開過去問の対象年度2013〜2025")
    require(config["mockQuestionCount"] == 25 and config["examMinutes"] == 40, "試験設定25問/40分")
    require(config["passingPercent"] == 60 and config["minimumSubjectPercent"] == 0, "基準点/足切り")
    require(config["choiceLabels"] == list("アイウエ"), "選択肢記号")
    expected_free = {q["id"] for q in questions if q.get("kind") == "past" and q["year"] in [2023, 2024, 2025]}
    require(set(config["freeQuestionIDs"]) == expected_free and len(config["freeQuestionIDs"]) == len(expected_free), "無料ID集合")
    figures = set()
    for q in questions:
        name = q["id"]
        require(len(q["choices"]) == 4 and 0 <= q["correctIndex"] < 4, f"{name}:四肢/正答範囲")
        require(q["subject"] in config["subjects"] and q["tags"] and q["concepts"], f"{name}:分類/概念")
        require(len(q.get("choiceExplanations", [])) == 4 and q.get("steps"), f"{name}:各選択肢理由/steps")
        require(reviews.get(name, {}).get("stage1") == "passed" and reviews.get(name, {}).get("stage2") == "passed", f"{name}:二段階レビュー未完了")
        require(snapshots.get(name) == digest(q), f"{name}:校合後に内容変更（再レビュー必要）")
        blocks = q.get("bodyBlocks", []) + q.get("explanationBlocks", [])
        if "choiceBlocks" in q:
            require(len(q["choiceBlocks"]) == 4, f"{name}:選択肢ブロック数")
            blocks += [b for choice in q["choiceBlocks"] for b in choice]
        for block in blocks:
            if block["type"] == "image":
                figures.add(block["assetName"])
                require((APP / "Figures" / block["assetName"]).is_file(), f"{name}:図版欠落")
            if block["type"] == "table":
                require(bool(block["headers"]) and all(len(row) == len(block["headers"]) for row in block["rows"]), f"{name}:表の列数")
        if q["kind"] == "past":
            require(re.fullmatch(r'nw-\d{4}-(spring|autumn)-q\d{2}', name) is not None, f"{name}:ID形式")
            require(name == f'nw-{q["year"]}-{q["administration"]}-q{q["questionNumber"]:02d}', f"{name}:年度/期/問番号")
            period = "春期" if q["administration"] == "spring" else "秋期"
            require(q["source"] == f'ネットワークスペシャリスト試験 {q["year"]}年{period} 午前Ⅱ 問{q["questionNumber"]}', f"{name}:出典")
    counts, official_ids, official_sets = [], set(), {}
    years = load(DOCS / "sources.json")["years"]
    require(sorted(y["year"] for y in years) == list(range(2009, 2026)), "公式年度調査2009〜2025の不足/重複")
    for year in years:
        documents = year["documents"]
        for document in documents:
            evidence = DOCS / "evidence" / document["file"]
            require(evidence.is_file(), f'{document["file"]}:原本欠落')
            if evidence.is_file(): require(hashlib.sha256(evidence.read_bytes()).hexdigest() == document["sha256"], f'{document["file"]}:原本ハッシュ不一致')
        if not documents:
            require(year["year"] == 2020, "未調査年度あり")
            counts.append({"year": year["year"], "period": None, "official": 0, "included": 0, "verified": 0, "held": 0, "reason": "公式年度ページにNW午前Ⅱの公開なし"})
            continue
        answer = next(d for d in documents if d["role"] == "answers")
        file = answer["file"]
        period = "spring" if re.search(r'h_nw_', file) else "autumn"
        items = [q for q in questions if q["year"] == year["year"] and q.get("administration") == period and q["kind"] == "past"]
        nums = [q["questionNumber"] for q in items]
        require(len(set(nums)) == len(nums), f'{year["year"]}:問番号重複')
        official = len(answer["questionNumbers"])
        require(official == 25, f'{year["year"]}:正答冊子問題数要確認')
        expected_ids = [f'nw-{year["year"]}-{period}-q{n:02d}' for n in answer["questionNumbers"]]
        official_ids.update(expected_ids)
        official_sets[f'nw-{year["year"]}-{period}'] = expected_ids
        textpath = DOCS / "evidence" / (file + ".txt")
        try:
            answers = official_answers(DOCS / "evidence" / file)
            require(set(answers) == set(answer["questionNumbers"]), f'{year["year"]}:公式正答抽出不全')
            if textpath.exists():
                sidecar = {int(n): list("アイウエ").index(c) for n, c in re.findall(r'問\s*(\d+)\s*([アイウエ])', textpath.read_text())}
                require(sidecar == answers, f'{year["year"]}:正答テキストと原本PDFが不一致')
            for q in items: require(answers.get(q["questionNumber"]) == q["correctIndex"], f'{q["id"]}:公式正答不一致')
        except Exception as error:
            errors.append(f'{year["year"]}:原本正答を読み取れません（{error}）')
        verified = sum(reviews.get(q["id"], {}).get("stage1") == "passed" and reviews.get(q["id"], {}).get("stage2") == "passed" and snapshots.get(q["id"]) == digest(q) for q in items)
        holds = {key: reviews[key]["notes"] for key in expected_ids if reviews.get(key, {}).get("stage2") == "held"}
        counts.append({"year": year["year"], "period": period, "official": official, "included": len(items), "verified": verified, "held": official - verified, "missingQuestionIDs": [f'nw-{year["year"]}-{period}-q{n:02d}' for n in answer["questionNumbers"] if n not in nums], "heldReviewNotes": holds, "reason": "未転記・未解説・未レビュー，個別保留はheldReviewNotes参照" if verified < official else None})
        if year["year"] >= 2013 and set(nums) != set(answer["questionNumbers"]): incomplete.append(f'{year["year"]}:収録{len(items)}/{official}')
    sets = bank.get("mockSets", [])
    require(all(q["id"] in official_ids for q in questions if q["kind"] == "past"), "公式原本にない年度/期/問番号")
    require(sum(row["official"] for row in counts) == 400, "公式原本400問の調査不整合")
    require(len({s["id"] for s in sets}) == len(sets), "固定模試ID重複")
    for s in sets:
        require(s["questionCount"] == 25 and len(s["questionIDs"]) == 25 and s["minutes"] == 40, f'{s["id"]}:模試構成')
        require(all(i in by_id and by_id[i].get("mockSetID") == s["id"] for i in s["questionIDs"]), f'{s["id"]}:参照不整合')
        require(all(i in by_id and by_id[i]["kind"] == s["kind"] for i in s["questionIDs"]), f'{s["id"]}:過去問/予想の混在')
        require([by_id[i]["questionNumber"] for i in s["questionIDs"] if i in by_id] == list(range(1, 26)), f'{s["id"]}:原問順')
        if s["kind"] == "past": require(s["questionIDs"] == official_sets.get(s["id"]), f'{s["id"]}:公式年度セット不一致')
    for row in counts:
        if row["year"] >= 2013 and row["official"] and f'nw-{row["year"]}-{row["period"]}' not in {s["id"] for s in sets}: incomplete.append(f'{row["year"]}:固定模試未完成')
    prediction = [q for q in questions if q.get("kind") == "prediction"]
    if len(prediction) != 75: incomplete.append(f"予想問題{len(prediction)}/75")
    prediction_counts = {}
    for n in range(1, 4):
        set_id = f"nw-2026-pred-{n:02d}"
        items = [q for q in prediction if q["mockSetID"] == set_id]
        prediction_counts[set_id] = dict(Counter(q["difficulty"] for q in items))
        if len(items) != 25: incomplete.append(f"{set_id}:25問未完成")
        if items:
            require(sum(q["difficulty"] <= 2 for q in items) == 5 and sum(q["difficulty"] == 3 for q in items) == 15 and sum(q["difficulty"] >= 4 for q in items) == 5, f"{set_id}:難易度配分")
        if set_id not in {s["id"] for s in sets}: incomplete.append(f"{set_id}:固定模試未完成")
    require(all(q["mockSetID"] in prediction_counts and q["administration"] == "prediction" for q in prediction), "予想セットID/実施区分")
    for q in prediction:
        require(q["year"] == 2026 and q["id"] == f'{q["mockSetID"]}-q{q["questionNumber"]:02d}', f'{q["id"]}:予想年度/問ID')
        number = int(q["mockSetID"].rsplit("-", 1)[-1]) if q["mockSetID"] in prediction_counts else 0
        require(q["source"] == f'ExamMaster オリジナル 2026年予想問題 第{number}回 問{q["questionNumber"]}', f'{q["id"]}:予想出典')
    # Independent numeric checks for the prototype's calculation/diagram problems.
    require(180 / 180 * 80 == 80, "呼量計算")
    require(abs(2000 * (1 - (1 - 1e-5) ** 800) - 16) < 0.1, "誤り電文計算")
    existing = [ipaddress.ip_network(s) for s in ["172.16.1.32/27", "172.16.1.224/30", "172.16.1.64/26"]]
    candidates = [ipaddress.ip_network(s) for s in ["172.16.1.0/25", "172.16.1.128/25", "172.16.1.128/26", "172.16.1.192/26"]]
    require([i for i, c in enumerate(candidates) if not any(c.overlaps(e) for e in existing)] == [2], "サブネット正答一意性")
    products = load(APP / "products.storekit")["products"]
    require(len(products) == 1 and products[0]["productID"] == config["productID"] and products[0]["type"] == "NonConsumable" and products[0]["displayPrice"] == "480", "資格固有IAP")
    if bank.get("isDraft"): incomplete.append("問題集は試作版")
    report = {"years": counts, "included": len(questions), "free": len(expected_free), "paid": len(questions) - len(expected_free), "figures": len(figures), "predictions": len(prediction), "predictionDifficulty": prediction_counts, "errors": errors, "incomplete": incomplete, "releaseReady": not errors and not incomplete}
    (DOCS / "validation-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if errors or (args.release and incomplete): raise SystemExit(1)

if __name__ == "__main__": main()
