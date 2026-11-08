#!/usr/bin/env python3
"""Checks the ES bank after import or after hand edits (the JSON is the source of truth).

    python3 tools/embedded-specialist/validate.py

Exits non-zero with one line per problem.
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "Qualifications" / "embedded-specialist"
FIELDS = {  # 本番1回分の構成（セット1〜11）
    "コンピュータ構成要素": 4, "システム構成要素": 1, "ソフトウェア": 3, "ハードウェア": 3,
    "ユーザーインタフェース": 1, "ネットワーク": 2, "セキュリティ": 3, "システム開発技術": 3,
    "ソフトウェア開発管理技術": 1, "ストラテジ": 4,
}
LINK = re.compile(r"\[([^\]\n]+)\]\(([^)\s]+)\)")
TEXTBOOK = re.compile(r"exammaster://textbook/(basics-[1-8]|overview)(#[A-Za-z0-9-]+)?")
CORRECT = re.compile(r"^(正しい|正解)")


def main() -> int:
    bank = json.loads((DIR / "questions.json").read_text(encoding="utf-8"))
    glossary = json.loads((DIR / "glossary.json").read_text(encoding="utf-8"))
    config = json.loads((DIR / "qualification.json").read_text(encoding="utf-8"))
    questions, sets = bank["questions"], bank["mockSets"]
    problems: list[str] = []
    fail = problems.append

    term_ids = [t["id"] for t in glossary["terms"]]
    if len(set(term_ids)) != len(term_ids):
        fail("glossary: duplicate term IDs")
    for t in glossary["terms"]:
        if not t["term"].strip() or not t["description"].strip() or not t["keys"]:
            fail(f"glossary {t['id']}: empty term, description or keys")
        check_markup(t["description"], f"glossary {t['id']}", fail, allow_links=False)
    term_set = set(term_ids)

    ids = [q["id"] for q in questions]
    if len(questions) != 300:
        fail(f"expected 300 questions, found {len(questions)}")
    for qid, n in Counter(ids).items():
        if n > 1:
            fail(f"{qid}: duplicate ID")
    for stem, n in Counter(q["stem"] for q in questions).items():
        if n > 1:
            fail(f"duplicate stem ×{n}: {stem[:40]}")

    referenced_assets: set[str] = set()
    for q in questions:
        where = q["id"]
        if not re.fullmatch(r"es-s(0[1-9]|1[0-2])-q(0[1-9]|1[0-9]|2[0-5])", where):
            fail(f"{where}: ID pattern")
        if q["subject"] != config["subjects"][0]:
            fail(f"{where}: subject {q['subject']}")
        if q["category"].split("／")[0] not in FIELDS:
            fail(f"{where}: unknown field {q['category']}")
        choices = q["choices"]
        if len(choices) != 4 or len(set(choices)) != 4 or any(not c.strip() for c in choices):
            fail(f"{where}: needs 4 distinct non-empty choices")
        if q["correctIndex"] not in range(len(choices)):
            fail(f"{where}: correctIndex out of range")
        reasons = q.get("choiceExplanations") or []
        if len(reasons) != len(choices):
            fail(f"{where}: one reason per choice is required")
        else:
            marked = [i for i, r in enumerate(reasons) if CORRECT.match(strip(r))]
            if marked != [q["correctIndex"]]:
                fail(f"{where}: correctIndex {q['correctIndex']} but reasons mark {marked} as correct")
        kind = q.get("kind")
        if kind == "past" and not re.search(r"問\d+", q["source"]):
            fail(f"{where}: past question without 問番号 in source")
        if kind == "original" and not q["source"].startswith("ExamMaster オリジナル"):
            fail(f"{where}: original source must start with 'ExamMaster オリジナル'")
        if kind not in ("past", "original"):
            fail(f"{where}: kind {kind}")
        for field in ("stem", *[f"choices[{i}]" for i in range(len(choices))]):
            value = q["stem"] if field == "stem" else choices[int(field[8:-1])]
            if re.search(r"<[a-z/]|\*\*|==|\]\(", value):
                fail(f"{where}.{field}: stem and choices are shown as plain text")
        check_markup(q["explanation"], f"{where}.explanation", fail)
        for i, r in enumerate(reasons):
            check_markup(r, f"{where}.reason[{i}]", fail)
        blocks = (q.get("bodyBlocks") or []) + [b for c in q.get("choiceBlocks") or [] for b in c] + \
            (q.get("explanationBlocks") or []) + (q.get("related") or [])
        if "choiceBlocks" in q and len(q["choiceBlocks"]) != len(choices):
            fail(f"{where}: choiceBlocks count")
        for b in blocks:
            check_block(b, where, fail, referenced_assets)
        gids = q.get("glossaryTermIDs") or []
        if len(set(gids)) != len(gids) or not set(gids) <= term_set:
            fail(f"{where}: glossaryTermIDs must be unique and exist in glossary.json")

    on_disk = {p.name for p in (DIR / "Figures").glob("*.png")}
    for name in sorted(referenced_assets - on_disk):
        fail(f"missing figure {name}")
    for name in sorted(on_disk - referenced_assets):
        fail(f"unused figure {name}")

    by_id = {q["id"]: q for q in questions}
    if [s["id"] for s in sets] != [f"es-set-{n:02d}" for n in range(1, 13)]:
        fail("mock sets must be es-set-01 … es-set-12")
    for s in sets:
        members = [by_id[i] for i in s["questionIDs"] if i in by_id]
        if s["questionCount"] != 25 or len(members) != 25 or s["minutes"] != 40:
            fail(f"{s['id']}: 25 questions / 40 minutes expected")
        if any(m["mockSetID"] != s["id"] for m in members):
            fail(f"{s['id']}: member with another mockSetID")
        if [m["questionNumber"] for m in members] != list(range(1, 26)):
            fail(f"{s['id']}: questionNumber must follow the set order 1…25")
        if s["id"] != "es-set-12":
            fields = Counter(m["category"].split("／")[0] for m in members)
            if fields != Counter(FIELDS):
                fail(f"{s['id']}: field mix {dict(fields)} differs from the exam")

    free = set(config["freeQuestionIDs"])
    expected_free = {q["id"] for q in questions if q["mockSetID"] in ("es-set-01", "es-set-02")}
    if free != expected_free:
        fail("freeQuestionIDs must be exactly sets 1 and 2")

    for p in problems:
        print(p)
    kinds = Counter(q["kind"] for q in questions)
    print(f"{len(questions)} questions ({kinds['past']} past, {kinds['original']} original), "
          f"{len(sets)} sets, {len(term_ids)} terms, {len(on_disk)} figures — "
          f"{'OK' if not problems else f'{len(problems)} problems'}")
    return 1 if problems else 0


def strip(text: str) -> str:
    return LINK.sub(r"\1", text).replace("**", "").replace("==", "")


def check_markup(text: str, where: str, fail, allow_links: bool = True):
    if not text.strip():
        fail(f"{where}: empty")
    if re.search(r"<[a-z/][^>]*>", text):
        fail(f"{where}: leftover HTML")
    for line in text.split("\n"):
        if line.count("**") % 2 or line.count("==") % 2:
            fail(f"{where}: unbalanced ** or == in '{line[:30]}'")
    for _, url in LINK.findall(text):
        if not allow_links:
            fail(f"{where}: link not allowed")
        elif not (url.startswith("https://") or TEXTBOOK.fullmatch(url)):
            fail(f"{where}: link target {url}")


def check_block(b: dict, where: str, fail, assets: set[str]):
    kind = b.get("type")
    if kind == "text":
        check_markup(b.get("text", ""), f"{where} text block", fail)
    elif kind in ("monospace", "formula"):
        if not b.get("text", "").strip():
            fail(f"{where}: empty {kind} block")
    elif kind == "image":
        name = b.get("assetName", "")
        if not name or "/" in name or not b.get("altText", "").strip():
            fail(f"{where}: image needs assetName and altText")
        assets.add(name)
    elif kind == "table":
        headers, rows = b.get("headers") or [], b.get("rows") or []
        if not headers or not rows or any(not h.strip() for h in headers) or any(len(r) != len(headers) for r in rows):
            fail(f"{where}: table shape")
    else:
        fail(f"{where}: block type {kind}")


if __name__ == "__main__":
    sys.exit(main())
