#!/usr/bin/env python3
"""Writes the release review checklist for the ES original questions.

    python3 tools/embedded-specialist/review_originals.py

Rewrites docs/embedded-specialist/original-review.md from questions.json.
Ticked boxes and notes written after "｜メモ:" on a question's line are kept.
"""
from __future__ import annotations

import difflib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "Qualifications" / "embedded-specialist"
OUT = ROOT / "docs" / "embedded-specialist" / "original-review.md"
LABELS = ["ア", "イ", "ウ", "エ"]
SIMILAR = 0.5  # 問題文＋選択肢がこれ以上似ている過去問は、写しになっていないかを見る
CALC = re.compile(r"求め|いくら|何[ミマキナ]?(秒|ビット|バイト|個|回|%|％|Hz|ヘルツ|ワット|W|Ω|V|A)|[0-9０-９]+\s*(MHz|kHz|ms|μs|ns|kバイト|Mバイト|ビット)")
LINE = re.compile(r"^- \[(?P<done>[ x])\] \*\*(?P<id>es-s\d\d-q\d\d)\*\*.*?(?P<memo>｜メモ:.*)?$")


def main() -> None:
    questions = json.loads((DIR / "questions.json").read_text(encoding="utf-8"))["questions"]
    originals = [q for q in questions if q["kind"] == "original"]
    past = [q for q in questions if q["kind"] == "past"]
    kept = previous_marks()

    for q in originals:
        q["_near"] = nearest_past(q, past)
        q["_flags"] = flags(q)

    lines = HEADER.splitlines()
    lines += ["", "## 自動で数えたこと", ""]
    lines += stats(originals, past)
    lines += ["", "## 問題ごとのチェック", "",
              "1問ずつ、上の観点で確かめてから箱に印を付ける。直したいことは行の末尾に「｜メモ: 」で書く"
              "（このスクリプトを再実行しても、印とメモは残る）。", ""]
    for set_id in sorted({q["mockSetID"] for q in originals}):
        members = [q for q in originals if q["mockSetID"] == set_id]
        number = int(set_id[-2:])
        lines += [f"### セット{number}" + ("（補強・セキュリティ）" if number == 12 else "") + f" · {len(members)}問", ""]
        for q in members:
            done, memo = kept.get(q["id"], (" ", ""))
            flag = "".join(f" ⚠{f}" for f in q["_flags"])
            lines.append(f"- [{done}] **{q['id']}**（問{q['questionNumber']}・正解{LABELS[q['correctIndex']]}）"
                         f"{q['category']} — {topic(q)}{flag}{memo}")
        lines.append("")
    OUT.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    checked = sum(1 for d, _ in kept.values() if d == "x")
    print(f"{OUT.relative_to(ROOT)}: {len(originals)} questions, {checked} already checked")


def previous_marks() -> dict[str, tuple[str, str]]:
    if not OUT.exists():
        return {}
    marks = {}
    for line in OUT.read_text(encoding="utf-8").splitlines():
        if m := LINE.match(line):
            marks[m["id"]] = (m["done"], m["memo"] or "")
    return marks


def flags(q: dict) -> list[str]:
    found = longest_correct(q)
    score, best = q["_near"]
    if score >= SIMILAR:
        found.append(f"過去問と似ている（{best['id']}）")
    if CALC.search(q["stem"]) or "計算" in topic(q):
        found.append("計算")
    if q.get("bodyBlocks") or q.get("choiceBlocks"):
        found.append("図表あり")
    return found


def nearest_past(q: dict, past: list[dict]) -> tuple[float, dict]:
    """問題文と選択肢をつないで比べる。定型の問い方だけが似ている組は高くならない。"""
    text = lambda x: x["stem"] + "".join(x["choices"])
    matcher = difflib.SequenceMatcher(None, autojunk=False)
    matcher.set_seq2(text(q))
    scored = []
    for p in past:
        matcher.set_seq1(text(p))
        scored.append((matcher.quick_ratio(), p))
    best = []
    for _, p in sorted(scored, key=lambda s: s[0], reverse=True)[:5]:
        matcher.set_seq1(text(p))
        best.append((matcher.ratio(), p))
    return max(best, key=lambda s: s[0])


def topic(q: dict) -> str:
    m = re.search(r"／(.+)）$", q["source"])
    if m:
        return m.group(1)
    stem = q["stem"].replace("\n", " ")
    return stem[:32] + ("…" if len(stem) > 32 else "")


def stats(originals: list[dict], past: list[dict]) -> list[str]:
    def positions(group):
        c = Counter(q["correctIndex"] for q in group)
        return "・".join(f"{LABELS[i]} {c[i]}" for i in range(4))

    def longest(group):
        n = sum(1 for q in group if longest_correct(q))
        return f"{n}/{len(group)}（{round(n * 100 / len(group))}%）"

    kinds = Counter(origin(q) for q in originals)
    difficulty = Counter(q["difficulty"] for q in originals)
    flagged = Counter(f.split("（")[0] for q in originals for f in q["_flags"])
    closest = max(originals, key=lambda q: q["_near"][0])
    score, q_id, p_id = closest["_near"][0], closest["id"], closest["_near"][1]["id"]
    return [
        f"- 内訳: {'、'.join(f'{k} {v}問' for k, v in kinds.items())}",
        f"- 正解の位置: オリジナル {positions(originals)}／過去問 {positions(past)}",
        f"- 正解の選択肢がいちばん長い: オリジナル {longest(originals)}／過去問 {longest(past)}。"
        "4択で偶然なら約25%。高いと、内容を知らなくても長さで当てられる。",
        f"- 難易度: {'、'.join(f'Lv{k} {v}問' for k, v in sorted(difficulty.items()))}"
        "（小テストは Lv ごとに出題するので、全問同じ Lv だと分かれない）",
        f"- 過去問との近さ（問題文＋選択肢の一致度）: いちばん近い組でも {score:.2f}（{q_id} と {p_id}）。"
        f"{SIMILAR} 以上に⚠を付ける。",
        f"- 印の数: {'、'.join(f'{k} {v}問' for k, v in flagged.most_common()) or 'なし'}",
    ]


def longest_correct(q: dict) -> list[str]:
    lengths = [len(c) for c in q["choices"]]
    return ["正解が最長"] if lengths[q["correctIndex"]] == max(lengths) and lengths.count(max(lengths)) == 1 else []


def origin(q: dict) -> str:
    if "NW版" in q["source"]:
        return "NW版からの流用"
    m = re.search(r"（([AB])：", q["source"])
    return {"A": "A（別角度）", "B": "B（新しい項目）"}.get(m.group(1) if m else "", "その他")


HEADER = """# オリジナル問題 リリース前チェックリスト（ES 午前II）

ES アプリのオリジナル問題（`kind: original`）を、リリース前に人の目で確かめるための一覧。
過去問は IPA の公式正答があるので対象外。正本は `Qualifications/embedded-specialist/questions.json`。

この文書は `python3 tools/embedded-specialist/review_originals.py` で作り直せる（印とメモは残る）。

## 自動チェック（取り込み・修正のたびに実行）

`python3 tools/embedded-specialist/validate.py` が次を確かめ、問題があれば1行ずつ出して失敗する。

- ID が重複せず、`es-sNN-qNN` の形になっている。問題文が重複していない。
- 4択で、選択肢が空でなく、重複していない。
- 正解番号と、選択肢ごとの解説で「正しい」「正解」と書いた選択肢が一致する（ちょうど1つ）。
- オリジナルの出典が「ExamMaster オリジナル」で始まる。
- セット1〜11が本番と同じ分野構成（25問・40分）。無料がセット1・2だけ。
- 記法（太字・==マーク==・リンク）の閉じ忘れや HTML の残りがない。用語メモの ID が用語集にある。
- 図のファイルがそろっていて、使われていない図がない。

教科書へのリンクが実在の章・節・用語チップを指すかは、ユニットテスト
`EmbeddedSpecialistTests.testEveryTextbookLinkResolves` が確かめる。

## 人が確かめる観点

自動チェックでは分からない、内容の正しさを見る。1問ごとに次を確かめる。

1. **正解が1つに決まる**: 他の選択肢が、読み方や前提しだいで正しくならないか。「適切でないもの」を問う問題は、誤りが1つだけか。
2. **正解の根拠が正しい**: 用語の定義・数値・単位・規格名が、IPA のシラバスや一般的な教科書と合っているか。年が経って変わった事実（規格の版、推奨される方式）はないか。
3. **計算は自分で解き直す**（⚠計算）: 数値・単位・桁・丸めを確かめ、別の正しい解き方でも同じ答えになるか。
4. **誤りの選択肢それぞれに理由がある**: 「どこが誤りか」が具体的で、==マーク== がその誤りの語に付いているか。
5. **長さや言い回しで正解が分からない**（⚠正解が最長）: 正解だけが長い・詳しい・断定を避けている、になっていないか。必要なら誤答を同じくらいの長さに書き足すか、正解を削る。
6. **過去問の写しになっていない**（⚠過去問と似ている）: 問題文や選択肢が、過去問をほぼそのまま使っていないか。オリジナルと名乗れる程度に、問い方・場面・選択肢が違うか。
7. **分野が合っている**: `category`（大分類／中分類）が内容と合い、弱点マップで正しいテーマに入るか。
8. **解説と関連知識**: 「なぜ正解か」を、用語を知らない人にも分かる順で説明しているか。関連知識と用語メモが、その問題に役立つものだけか。リンク先が合っているか。
9. **図表**（⚠図表あり）: 図や表が本文と矛盾せず、iPhone の画面幅で読めるか（表は横スクロール）。
10. **NW版からの流用（セット12）**: ES の受験者に必要な内容か。NW 向けの前提（設問の場面、用語の水準）が残っていないか。

## 直し方

1. `questions.json` を直接直す（ipa からの再取り込みはしない）。
2. `python3 tools/embedded-specialist/validate.py` を実行して OK を確かめる。
3. ES のユニットテスト（`EmbeddedSpecialistTests`）を実行する。
4. アプリで該当の問題を開き、解説パネルと選択肢ごとの理由の表示を確かめる。
5. この文書を作り直して、印の数が減ったかを見る。"""


if __name__ == "__main__":
    main()
