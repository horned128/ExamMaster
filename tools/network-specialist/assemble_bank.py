#!/usr/bin/env python3
"""Build the bundled bank from individually reviewed source fragments.

Hand-edit docs/network-specialist/content, not the generated application JSON.
Only two-stage approved, hash-frozen questions can enter the application.
"""
import argparse
import json
from pathlib import Path
import jsonschema
from validate import APP, DOCS, digest, load


def assemble(parts, reviews, snapshots):
    schema = load(Path(__file__).with_name("questions.schema.json"))
    questions, sets, ids, set_ids = [], [], set(), set()
    for part in parts:
        jsonschema.Draft202012Validator(schema).validate(part)
        for question in part["questions"]:
            key = question["id"]
            if key in ids:
                raise ValueError(f"Duplicate question: {key}")
            review = reviews.get(key, {})
            if review.get("stage1") != "passed" or review.get("stage2") != "passed":
                raise ValueError(f"Unreviewed or held question: {key}")
            if snapshots.get(key) != digest(question):
                raise ValueError(f"Question changed after review: {key}")
            ids.add(key)
            questions.append(question)
        for mock in part.get("mockSets", []):
            if mock["id"] in set_ids:
                raise ValueError(f"Duplicate mock: {mock['id']}")
            set_ids.add(mock["id"])
            sets.append(mock)
    by_id = {q["id"]: q for q in questions}
    for mock in sets:
        members = [by_id.get(key) for key in mock["questionIDs"]]
        if mock["questionCount"] != 25 or len(members) != 25 or mock["minutes"] != 40 or \
                any(q is None or q["mockSetID"] != mock["id"] or q["kind"] != mock["kind"] for q in members) or \
                [q["questionNumber"] for q in members] != list(range(1, 26)):
            raise ValueError(f"Incomplete or invalid mock: {mock['id']}")
    questions.sort(key=lambda q: (-q["year"], q["administration"], q["mockSetID"], q["questionNumber"]))
    sets.sort(key=lambda s: s["id"], reverse=True)
    return {"version": 2, "isDraft": any(p.get("isDraft", False) for p in parts),
            "mockSets": sets, "questions": questions}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="Write reviewed bank and derived free IDs to application resources")
    args = parser.parse_args()
    parts = [load(path) for path in sorted((DOCS / "content").glob("*.json"))]
    if not parts:
        raise SystemExit("No source fragments")
    bank = assemble(parts, load(DOCS / "reviews.json")["questionReviews"], load(DOCS / "review-snapshots.json"))
    config = load(APP / "qualification.json")
    if any(q["subject"] not in config["subjects"] for q in bank["questions"]):
        raise SystemExit("Question subject is not defined in qualification.json")
    if args.write:
        config["freeQuestionIDs"] = [q["id"] for q in bank["questions"] if q["kind"] == "past" and q["year"] in [2023, 2024, 2025]]
        (APP / "questions.json").write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n")
        (APP / "qualification.json").write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n")
        print(f"Bundled {len(bank['questions'])} reviewed questions, {len(bank['mockSets'])} complete mocks")
    else:
        print(json.dumps(bank, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
