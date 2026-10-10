#!/usr/bin/env python3
"""Freeze content digests AFTER explicitly reviewing both stages.

This does not perform or approve reviews. A digest change requires a new review
and an explicit --accept-reviewed-content invocation; validation never updates it.
"""
import argparse
import json
from pathlib import Path
from validate import APP, DOCS, digest, load

parser = argparse.ArgumentParser()
parser.add_argument("--accept-reviewed-content", action="store_true", required=True)
args = parser.parse_args()
reviews = load(DOCS / "reviews.json")["questionReviews"]
path = DOCS / "review-snapshots.json"
snapshots = load(path) if path.exists() else {}
parts = sorted((DOCS / "content").glob("*.json"))
questions = [q for part in parts for q in load(part)["questions"]] if parts else load(APP / "questions.json")["questions"]
for question in questions:
    review = reviews.get(question["id"], {})
    if review.get("stage1") != "passed" or review.get("stage2") != "passed":
        raise SystemExit(f'Both reviews must pass: {question["id"]}')
    blocks = question.get("bodyBlocks", []) + question.get("explanationBlocks", [])
    blocks += [block for choice in question.get("choiceBlocks", []) for block in choice]
    for block in blocks:
        if block["type"] == "image" and not (APP / "Figures" / block["assetName"]).is_file():
            raise SystemExit(f'Missing reviewed figure: {block["assetName"]}')
    snapshots[question["id"]] = digest(question)
path.write_text(json.dumps(snapshots, indent=2) + "\n")
print(f"Froze {len(snapshots)} reviewed question digests")
