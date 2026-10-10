#!/usr/bin/env python3
"""Exact graph-state cross-checks for reviewed 2010 Q23, not review approval."""
from fractions import Fraction
from itertools import product
from math import comb
import unittest


# Each edge is a separate communication link, including the parallel links in C.
# Node 0 = N₁, node 3 = N₂; B's bridge is between intermediate nodes 1 and 2.
PLANS = {
    "A": [(0, 1), (1, 3), (0, 2), (2, 3)],
    "B": [(0, 1), (1, 3), (0, 2), (2, 3), (1, 2)],
    "C": [(0, 1), (0, 1), (1, 3), (1, 3)],
}


def success_counts(edges):
    counts = [0] * (len(edges) + 1)
    for working in product([False, True], repeat=len(edges)):
        reached = {0}
        while True:
            before = set(reached)
            for (left, right), enabled in zip(edges, working):
                if enabled and (left in reached or right in reached):
                    reached.update((left, right))
            if reached == before:
                break
        if 3 in reached:
            counts[sum(working)] += 1
    return counts


def polynomial(counts):
    """Expand sum(count[k] * p**k * (1-p)**(n-k)) exactly."""
    degree = len(counts) - 1
    coefficients = [0] * (degree + 1)
    for working, count in enumerate(counts):
        for offset in range(degree - working + 1):
            coefficients[working + offset] += count * comb(degree - working, offset) * (-1)**offset
    return coefficients


class ReviewedReliabilityTests(unittest.TestCase):
    def test_all_states_match_the_reviewed_polynomials(self):
        self.assertEqual(polynomial(success_counts(PLANS["A"])), [0, 0, 2, 0, -1])
        self.assertEqual(polynomial(success_counts(PLANS["B"])), [0, 0, 2, 2, -5, 2])
        self.assertEqual(polynomial(success_counts(PLANS["C"])), [0, 0, 4, -4, 1])
        # R_C-R_A = 2p²(1-p)², R_B-R_A = 2p³(1-p)²,
        # R_C-R_B = 2p²(1-p)³: strictly positive on 0<p<1.
        a, b, c = [polynomial(success_counts(PLANS[key])) + [0] * (5 - len(PLANS[key]))
                   for key in "ABC"]
        self.assertEqual([right - left for left, right in zip(a, c)], [0, 0, 2, -4, 2, 0])
        self.assertEqual([right - left for left, right in zip(a, b)], [0, 0, 0, 2, -4, 2])
        self.assertEqual([right - left for left, right in zip(b, c)], [0, 0, 2, -6, 6, -2])

    def test_exact_probabilities_and_the_central_link_condition(self):
        counts = {key: success_counts(edges) for key, edges in PLANS.items()}
        for numerator in range(1, 20):
            failure = Fraction(numerator, 20)
            working = 1 - failure
            rates = {
                key: sum(count * working**k * failure**(len(values) - 1 - k)
                         for k, count in enumerate(values))
                for key, values in counts.items()
            }
            with self.subTest(failure=failure):
                self.assertEqual(rates["A"], 1 - (1 - working**2)**2)
                self.assertEqual(rates["C"], (1 - failure**2)**2)
                self.assertEqual(rates["B"], working * rates["C"] + failure * rates["A"])
                self.assertLess(rates["A"], rates["B"])
                self.assertLess(rates["B"], rates["C"])


if __name__ == "__main__":
    unittest.main()
