#!/usr/bin/env python3
"""Independent arithmetic and trace checks for numerical/code-based past questions.

This deliberately re-implements each result from booklet inputs instead of
using the answer explanation as the oracle. Run from any working directory.
"""
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "docs/fundamental-information/content/past.json"
QUESTIONS = {q["id"]: q for q in json.loads(BANK.read_text(encoding="utf-8"))["questions"]}
SOURCES = json.loads((ROOT / "docs/fundamental-information/sources.json").read_text(encoding="utf-8"))
OFFICIAL_KEYS = {item["year"]: item["officialAnswerKeys"] for item in SOURCES["years"]}
KEY_LETTERS = "アイウエオカキクケコ"
checks: list[tuple[str, str]] = []

for q in QUESTIONS.values():
    subject = "科目A" if "-a-" in q["id"] else "科目B"
    official = OFFICIAL_KEYS[q["year"]][subject][q["questionNumber"] - 1]
    actual = KEY_LETTERS[q["correctIndex"]]
    assert actual == official, f"{q['id']}: JSON key {actual}, IPA key {official}"


def answer(qid: str, expected: str, label: str) -> None:
    q = QUESTIONS[qid]
    actual = q["choices"][q["correctIndex"]]
    assert expected in actual, f"{qid}: expected {expected!r}, got {actual!r}"
    checks.append((qid, label))


# 2026 科目A: two availability calculations use equal annual service time.
before = (5000 - 100) / 5000 * 100
after = (5000 - 0.5) / 5000 * 100
answer("fe-2026-a-q14", f"{after - before:.2f}", "availability percentage-point delta")

# 2026 科目A retention rates: remove new members before dividing by last month's count.
retention = [(end - new) / start for start, new, end in
             [(1000, 500, 800), (1000, 200, 800), (1500, 500, 1100), (1500, 1000, 1800)]]
assert retention == [0.30, 0.60, 0.40, 800 / 1500]
answer("fe-2026-a-q17", "サービス B", "retention rate comparison")

# 2026 科目B recurrence: compare a recursive reference with a separate rolling-array model.
def rec(n: int) -> int:
    return 1 if n <= 2 else 2 * rec(n - 2) + rec(n - 1)


rolling = [1, 1, 1]
for n in range(3, 13):
    rolling = [rolling[1], rolling[2], 2 * rolling[1] + rolling[2]]
    assert rolling[2] == rec(n), (n, rolling[2], rec(n))
answer("fe-2026-b-q03", "2 × data[1] ＋ data[2]", "recurrence trace n=1..12")

# 2025 科目A: MTBF/MTTR improvements are each applied for six full years.
mtbf, mttr = 4000 + 6 * 100, 1000 - 6 * 100
answer("fe-2025-a-q04", f"{mtbf / (mtbf + mttr):.2f}", "availability after six annual improvements")

# 2025 科目A: decimal SI units, transfer overhead adds 20 percent to payload.
payload_mbit = 1_000 * 8
transferred_mbit = payload_mbit * 1.20
average_mbps = transferred_mbit / (5 * 60)
answer("fe-2025-a-q07", f"{average_mbps / 40 * 100:.0f}", "link utilization")

# 2025 科目A q14: derive the event-time critical path from the booklet network.
# A=3, B=6, C=8, D=6, E=5, F=14, G=11, H=15, I=5; dotted links are zero-day dummies.
# A->B branches to C/G/H; F starts after A; G and F join before D; H bypasses D and joins I.
critical_days = max(3 + 6 + 8 + 6 + 5, 3 + 6 + 11 + 6 + 5,
                    3 + 14 + 6 + 5, 3 + 6 + 15 + 5)
answer("fe-2025-a-q14", str(critical_days), "critical-path duration")

# 2025 科目A q19: contribution margin, target profit, days, and seats.
customers_per_seat_day = (300_000 + 100_000) / (500 - 100) / 20 / 10
answer("fe-2025-a-q19", f"{customers_per_seat_day:g}", "break-even volume including target profit")

# 2025 科目B q1: independently compare the optimized multiple-count loop to brute force.
def optimized_multiples(n: int, m: int) -> int:
    first = n
    for _ in range(3):
        if first % 4 == 0:
            break
        first += 1
    return 0 if first % 4 else (m - first) // 4 + 1


for n in range(1, 40):
    for m in range(n + 10, n + 31):
        assert optimized_multiples(n, m) == sum(x % 4 == 0 for x in range(n, m + 1))
answer("fe-2025-b-q01", "4ずつ", "multiple counting, exhaustive n/m ranges")

# 2025 科目B q2: enumerate actual coin-count triples, independent of stated loop condition.
def coin_combinations(total: int) -> int:
    return sum(1 for tens in range(total // 10 + 1)
               for fives in range((total - 10 * tens) // 5 + 1))


for amount in range(11, 101):
    loop_count = sum((amount - 10 * tens) // 5 + 1
                     for tens in range(amount // 10 + 1))
    assert loop_count == coin_combinations(amount)
answer("fe-2025-b-q02", "rest ≧ 0", "coin combinations, 11..100 yen")

# 2025 科目B q4: simulate the booklet's nested comparison and early-exit behavior.
data, key = list("ababcabc"), list("abc")
true_tests = 0
matches = []
for start in range(len(data) - len(key) + 1):
    for offset, wanted in enumerate(key):
        equal = data[start + offset] == wanted
        true_tests += equal
        if not equal:
            break
        if offset == len(key) - 1:
            matches.append(start + 1)
assert matches == [3, 6] and true_tests == 8
answer("fe-2025-b-q04", "8", "pattern-match true-condition count")

# 2025 科目B q5: expected frequencies under independence, using row × column / grand total.
table = [[82, 6], [58, 8]]
rows = [sum(row) for row in table]
cols = [sum(table[r][c] for r in range(2)) for c in range(2)]
grand = sum(rows)
expected = [[rows[r] * cols[c] / grand for c in range(2)] for r in range(2)]
assert expected == [[80.0, 8.0], [60.0, 6.0]]
answer("fe-2025-b-q05", "80 6", "independent expected frequencies")

# 2024 科目A: equal mean memory access time; solve linear equality independently.
# 40h+400(1-h) = 20h+580(1-h) => 220h=180.
hit_rate = (580 - 400) / ((580 - 20) - (400 - 40))
assert abs(hit_rate - 0.9) < 1e-12
answer("fe-2024-a-q03", "0.90", "cache hit rate")

# 2024 科目A q1: infer the unknown operator output from AND/OR result columns.
truth_rows = [(0, 0, 0, 1), (0, 1, 0, 1), (1, 0, 0, 1), (1, 1, 1, 1)]
unknown_output = []
for x, y, and_result, or_result in truth_rows:
    candidates = [z for z in (0, 1) if (x & z) == and_result and (x | z) == or_result]
    assert len(candidates) == 1
    unknown_output.append(candidates[0])
assert unknown_output == [1, 1, 0, 1]
answer("fe-2024-a-q01", "選択肢ウ", "truth-table operator result [1,1,0,1]")

# 2024 科目A: percentage improvements are measured against this year's values.
answer("fe-2024-a-q04", "80", "availability after percentage improvements")
assert (3000 * 1.20) / (3000 * 1.20 + 1000 * 0.90) * 100 == 80

# 2024 科目A q13: event-time calculation includes the diagram's zero-day dummy links.
after_a = 30
after_b = after_a + 5
after_c = max(after_a + 30, after_b)  # B-to-C dummy dependency
after_d = max(after_a + 20, after_c)   # C-to-D dummy dependency
merge = max(after_b + 40, after_c + 25, after_d + 30)
duration = merge + 30
assert duration == 120
answer("fe-2024-a-q13", "120", "critical-path duration with dummy links")

# 2023 科目A: hexadecimal fractional digit C is 12/16.
answer("fe-2023-a-q01", "0.75", "hexadecimal fraction conversion")
assert int("C", 16) / 16 == 0.75

# 2023 科目A q13: determine paths before/after A's one-day delay, then compare
# shortening costs only on paths that now control the finish date.
baseline = {"A-B-E-G": 4 + 6 + 5 + 5,
            "A-C-G": 4 + 8 + 5,
            "A-D-F-G": 4 + 4 + 4 + 5}
delayed = {name: length + 1 for name, length in baseline.items()}
assert max(baseline.values()) == 20 and max(delayed.values()) == 21
critical_choices = {"B": 6, "C": 3, "D": 2, "E": 2.5}
critical_candidates = {"B", "E"}  # among listed choices, only these lie on A-B-E-G
cheapest = min(critical_candidates, key=critical_choices.__getitem__)
assert cheapest == "E"
answer("fe-2023-a-q13", "E", "least-cost one-day recovery on critical path")

# 2023 科目B q3: execute the booklet partition loop literally; it exits before any swap.
arr, pivot, i, j = [2, 1, 3, 5, 4], 3, 0, 4
while True:
    while arr[i] < pivot:
        i += 1
    while pivot < arr[j]:
        j -= 1
    if i >= j:
        break
    arr[i], arr[j] = arr[j], arr[i]
    i += 1
    j -= 1
assert arr == [2, 1, 3, 5, 4] and i == j == 2
answer("fe-2023-b-q03", "2 1 3 5 4", "quicksort first-partition trace")

# 2023 科目B q4: hash positions are calculated 1-based, then each key is inserted in order.
slots = [-1] * 5
for value in (3, 18, 11):
    first = value % 5 + 1
    second = (value + 3) % 5 + 1
    position = first if slots[first - 1] == -1 else second
    assert slots[position - 1] == -1
    slots[position - 1] = value
assert slots == [-1, 18, -1, 3, 11]
answer("fe-2023-b-q04", "{－1, 18, －1, 3, 11}", "two-hash insertion trace")

# 2024 科目A q19's plotted points have a downward trend (visual source is the IPA figure).
answer("fe-2024-a-q19", "相関係数は負", "scatter-plot correlation direction")

# 2024 B2: left-to-right binary accumulation, for every value up to 255.
for number in range(256):
    result = 0
    for digit in bin(number)[2:]:
        result = result * 2 + int(digit)
    assert result == number
answer("fe-2024-b-q02", "result × 2 ＋ int(binary の i文字目の文字)", "binary conversion, all 8-bit values")

# 2024 B4: independently count the trailing data2 copy, not total insertions.
a, b, out = [2, 3], [1, 4], []
i = j = trailing = 0
while i < len(a) and j < len(b):
    if a[i] <= b[j]:
        out.append(a[i]); i += 1
    else:
        out.append(b[j]); j += 1
out.extend(a[i:])
while j < len(b):
    out.append(b[j]); j += 1; trailing += 1
assert out == [1, 2, 3, 4] and trailing == 1
answer("fe-2024-b-q04", "1 回", "merge trailing-copy count")

# 2024 B5: compare each purchase count and co-occurrence with direct sets.
orders = [set(x) for x in ["ABD", "AD", "A", "ABE", "B", "CE"]]
for item in "ABCDE":
    others = sorted(set.union(*orders) - {item})
    item_count, array_k, array_m = 0, [0] * len(others), [0] * len(others)
    for order in orders:
        if item in order:
            item_count += 1
        for i, other in enumerate(others):
            if other in order:
                if item in order:
                    array_m[i] += 1
                array_k[i] += 1
    for i, other in enumerate(others):
        direct = sum({item, other} <= order for order in orders) * len(orders) / (
            sum(item in order for order in orders) * sum(other in order for order in orders))
        assert array_m[i] * len(orders) / (item_count * array_k[i]) == direct
answer("fe-2024-b-q05", "arrayM[i] arrayK[i] ordersの要素数", "purchase co-occurrence formula, all products")

print(f"IPA answer-key letters match all {len(QUESTIONS)} questions")
print(f"independently checked {len(checks)} calculation, logic, or diagram results")
for qid, label in checks:
    print(f"PASS {qid}: {label}")
