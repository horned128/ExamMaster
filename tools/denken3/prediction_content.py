"""Small authoring helpers: correct answers are explicit, options are shuffled later."""
def item(category, stem, answer, wrongs, explanation):
    choices = [str(answer), *map(str, wrongs)]
    assert len(choices) == len(set(choices)) == 5, (stem, choices)
    assert stem.strip() and explanation.strip()
    return dict(category=category, stem=stem, answer=str(answer), choices=choices, explanation=explanation)

def number(category, stem, answer, wrongs, unit, explanation):
    def fmt(value):
        return (f"{value:g}" if isinstance(value, (int, float)) else value) + (f" {unit}" if unit else "")
    return item(category, stem, fmt(answer), [fmt(n) for n in wrongs], explanation)

def choose(round_index, cases):
    assert len(cases) == 3
    return cases[round_index]
