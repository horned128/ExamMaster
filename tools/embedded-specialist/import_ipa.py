#!/usr/bin/env python3
"""One-time import of the ipa web app's ES data into ExamMaster files.

    python3 tools/embedded-specialist/import_ipa.py [--ipa ~/Downloads/ipa] [--skip-figures]

Writes Qualifications/embedded-specialist/{questions.json,glossary.json,Figures/*.png}.
After the import the JSON in this repository is the source of truth; the ipa files are
only read again if this script is re-run on purpose.

Conversion rules
- <b> → **bold**, <mark> → ==mark==, <br> → line break, <a href> → [label](exammaster://textbook/…).
- <sub>/<sup> → Unicode sub/superscript when every character has one, otherwise _x / ^x.
- Overlined spans (negative-logic signals such as CS) → combining overline.
- <div class='fig'> and bare <svg> → PNG @3x rendered by headless Chrome (image block).
- <table> → table block (cells are plain text), <pre> → monospace block.
- stem and choices are plain text because the app shows them with Text(); questions that
  carry figures or tables also get bodyBlocks, which the app shows instead of the stem.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
OUT = ROOT / "Qualifications" / "embedded-specialist"
FIGURES = OUT / "Figures"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SUBJECT = "午前II"
LABELS = ["ア", "イ", "ウ", "エ"]
ORIGINAL_YEAR = 2026
SET_TITLES = {12: "セット12 補強（セキュリティ）"}

# ---------------------------------------------------------------- mini DOM

class Node:
    def __init__(self, tag: str, attrs: dict[str, str] | None = None):
        self.tag = tag
        self.attrs = attrs or {}
        self.children: list[Node | str] = []


VOID = {"br", "img", "hr", "wbr"}


class DOMBuilder(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("#root")
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, {k: (v or "") for k, v in attrs})
        self.stack[-1].children.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(Node(tag, {k: (v or "") for k, v in attrs}))

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                return

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def parse(html: str) -> Node:
    builder = DOMBuilder()
    builder.feed(html)
    builder.close()
    return builder.root


# ---------------------------------------------------------------- inline text

SUPER = dict(zip("0123456789+-−=()nixhtLNEaebcdfgjklmoprsuvwyzABDGHIJKMOPRTUVW",
                 "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁻⁼⁽⁾ⁿⁱˣʰᵗᴸᴺᴱᵃᵉᵇᶜᵈᶠᵍʲᵏˡᵐᵒᵖʳˢᵘᵛʷʸᶻᴬᴮᴰᴳᴴᴵᴶᴷᴹᴼᴾᴿᵀᵁⱽᵂ"))
SUB = dict(zip("0123456789+-−=()aehijklmnoprstuvx", "₀₁₂₃₄₅₆₇₈₉₊₋₋₌₍₎ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ"))
OVERLINE = "̅"


class Context:
    def __init__(self, links: "LinkMapper", warnings: list[str], where: str):
        self.links = links
        self.warnings = warnings
        self.where = where


def script(text: str, table: dict[str, str], marker: str) -> str:
    if text and all(c in table for c in text):
        return "".join(table[c] for c in text)
    bare = len(text) == 1 or text.isalnum() or (text.startswith("(") and text.endswith(")"))
    return marker + (text if bare else "(" + text + ")")


def escape_markup(text: str) -> str:
    # Literal ** or == (C code) must not toggle bold/mark; a zero-width space breaks the pair.
    return text.replace("**", "*​*").replace("==", "=​=")


def inline(node: Node | str, ctx: Context, markup: bool) -> str:
    if isinstance(node, str):
        text = node.replace("\r", "")
        return escape_markup(text) if markup else text
    inner = lambda m=markup: "".join(inline(c, ctx, m) for c in node.children)
    tag = node.tag
    if tag in ("#root", "span", "code", "i", "em", "u", "small", "td", "th"):
        style = node.attrs.get("style", "")
        if tag == "span" and "overline" in style:
            plain_text = "".join(inline(c, ctx, False) for c in node.children)
            return "".join(ch + OVERLINE for ch in plain_text)
        parts = [c for c in node.children if isinstance(c, Node) and "display:block" in c.attrs.get("style", "")]
        if tag == "span" and "inline-block" in style and len(parts) == 2:
            numerator, denominator = (tidy(inline(c, ctx, False)) for c in parts)
            return f"{numerator} ÷ {{{denominator}}}"  # a stacked fraction on the web page
        if tag == "span" and "display:block" in style:
            return inner() + "\n"
        return inner()
    if tag in ("b", "strong"):
        body = inner()
        return f"**{body}**" if markup and body.strip() else body
    if tag == "mark":
        body = inner()
        return f"=={body}==" if markup and body.strip() else body
    if tag == "br":
        return "\n"
    if tag == "p":
        return inner() + "\n"
    if tag in ("sub", "sup"):
        body = "".join(inline(c, ctx, False) for c in node.children)
        return script(body, SUB if tag == "sub" else SUPER, "_" if tag == "sub" else "^")
    if tag == "a":
        label = "".join(inline(c, ctx, False) for c in node.children).strip()
        url = ctx.links.map(node.attrs.get("href", ""), ctx.where)
        if markup and url:
            return f"[{label}]({url})"
        return label
    ctx.warnings.append(f"{ctx.where}: unknown inline tag <{tag}>")
    return inner()


def tidy(text: str) -> str:
    lines = [line.strip() for line in text.split("\n")]
    out = "\n".join(lines)
    out = re.sub(r"\n{2,}", "\n", out).strip()
    # A line that happens to start with "- " would become a bullet.
    return re.sub(r"(?m)^- ", "－ ", out)


def to_markup(html: str, ctx: Context) -> str:
    return tidy(inline(parse(html), ctx, True))


def to_plain(html: str, ctx: Context) -> str:
    return tidy(inline(parse(html), ctx, False))


# ---------------------------------------------------------------- links

class LinkMapper:
    """ipa page links → exammaster://textbook/<chapter>#<section>.

    basics.html#rc → basics-3#rc (the h3 "3-1" sits in chapter 3)
    layers.html#t=cache → overview#cache, layers.html#j-irq → overview#j-irq
    """

    def __init__(self, ipa: Path, chip_ids: list[str], journey_ids: list[str]):
        basics = (ipa / "es" / "basics.html").read_text(encoding="utf-8")
        # Every id belongs to the chapter whose "第N章" heading came last; id="chN" is the chapter itself.
        self.basics: dict[str, str] = {}
        chapter = None
        for m in re.finditer(r'id="([^"]+)"|<h2>第(\d+)章', basics):
            if m.group(2):
                chapter = m.group(2)
            elif re.fullmatch(r"ch\d+", m.group(1)):
                self.basics[m.group(1)] = m.group(1)[2:]
            elif chapter:
                self.basics[m.group(1)] = chapter
        self.chips = set(chip_ids)
        self.journeys = {"j-" + j for j in journey_ids}
        self.errors: list[str] = []
        self.used: set[str] = set()

    def map(self, href: str, where: str) -> str | None:
        page, _, anchor = href.partition("#")
        url = None
        if page == "basics.html" and anchor in self.basics:
            chapter = f"exammaster://textbook/basics-{self.basics[anchor]}"
            url = chapter if re.fullmatch(r"ch\d+", anchor) else f"{chapter}#{anchor}"
        elif page == "layers.html" and anchor.startswith("t=") and anchor[2:] in self.chips:
            url = f"exammaster://textbook/overview#{anchor[2:]}"
        elif page == "layers.html" and anchor in self.journeys:
            url = f"exammaster://textbook/overview#{anchor}"
        elif href.startswith("https://"):
            url = href
        if url is None:
            self.errors.append(f"{where}: unresolved link {href}")
        else:
            self.used.add(url)
        return url


class NoLinks:
    """Glossary descriptions keep a link's label but drop the target."""
    def map(self, href: str, where: str) -> None:
        return None


# ---------------------------------------------------------------- figures

TEXTBOOK_FIGURE_PREFIX = "tb-"


class Figures:
    """PNG jobs for one importer. `owns` limits stale-file cleanup to that importer's files
    (questions own everything except tb-*, the textbook owns tb-*)."""

    def __init__(self, skip: bool, page: str | None = None, owns=lambda name: not name.startswith(TEXTBOOK_FIGURE_PREFIX)):
        self.skip = skip
        self.page = page
        self.owns = owns
        self.jobs: list[tuple[str, str]] = []

    def add(self, name: str, html: str) -> str:
        self.jobs.append((name, html))
        return name

    def render(self):
        FIGURES.mkdir(parents=True, exist_ok=True)
        if self.skip:
            missing = [n for n, _ in self.jobs if not (FIGURES / n).exists()]
            if missing:
                sys.exit(f"--skip-figures but {len(missing)} PNGs are missing, e.g. {missing[0]}")
            return
        from PIL import Image, ImageChops
        wanted = {n for n, _ in self.jobs}
        for stale in FIGURES.glob("*.png"):
            if self.owns(stale.name) and stale.name not in wanted:
                stale.unlink()
        with tempfile.TemporaryDirectory() as tmp:
            for index, (name, body) in enumerate(self.jobs):
                page = Path(tmp) / f"fig{index}.html"
                page.write_text((self.page or FIGURE_PAGE).replace("{{BODY}}", body), encoding="utf-8")
                shot = Path(tmp) / f"fig{index}.png"
                subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                                "--force-device-scale-factor=3", "--window-size=900,1400",
                                "--default-background-color=FFFFFFFF", f"--screenshot={shot}",
                                page.as_uri()], check=True, capture_output=True, timeout=60)
                image = Image.open(shot).convert("RGB")
                diff = ImageChops.difference(image, Image.new("RGB", image.size, (255, 255, 255)))
                box = diff.point(lambda v: 255 if v > 12 else 0).getbbox()
                if box is None:
                    sys.exit(f"figure {name} rendered blank")
                pad = 24
                box = (max(0, box[0] - pad), max(0, box[1] - pad),
                       min(image.width, box[2] + pad), min(image.height, box[3] + pad))
                if box[3] >= image.height - 1 or box[2] >= image.width - 1:
                    sys.exit(f"figure {name} does not fit the render window")
                image.crop(box).save(FIGURES / name, optimize=True)
                print(f"  figure {index + 1}/{len(self.jobs)} {name}", file=sys.stderr)


FIGURE_PAGE = """<!doctype html><meta charset="utf-8"><style>
html,body{margin:0;background:#fff}
body{padding:24px;font:15px/1.6 -apple-system,"Hiragino Sans",sans-serif;color:#222;display:inline-block}
svg{max-width:none;height:auto;display:block;margin:0 auto}
.fig{text-align:center}
table{border-collapse:collapse}td,th{border:1px solid #999;padding:2px 8px}
</style><div class="fig">{{BODY}}</div>"""


def svg_text(html: str) -> str:
    texts = re.findall(r"<text[^>]*>(.*?)</text>", html, flags=re.S)
    words = [re.sub(r"<[^>]+>", "", t).strip() for t in texts]
    words = [w for w in words if w]
    summary = "、".join(dict.fromkeys(words))
    return summary[:140]


# ---------------------------------------------------------------- blocks

SEGMENT = re.compile(r"(<div class='fig'>.*?</div>|<svg\b.*?</svg>|<table>.*?</table>|<pre>.*?</pre>)", re.S)


def table_block(html: str, ctx: Context) -> dict:
    """Spanned cells are repeated into every grid position they cover (the app's table has no spans)."""
    trs: list[Node] = []

    def walk(node):
        for child in node.children:
            if isinstance(child, Node):
                (trs.append(child) if child.tag == "tr" else walk(child))
    walk(parse(html))

    grid: dict[tuple[int, int], str] = {}
    for r, tr in enumerate(trs):
        c = 0
        for cell in (x for x in tr.children if isinstance(x, Node) and x.tag in ("td", "th")):
            while (r, c) in grid:
                c += 1
            value = tidy(inline(cell, ctx, False)).replace("\n", " ") or "—"
            for dr in range(int(cell.attrs.get("rowspan") or 1)):
                for dc in range(int(cell.attrs.get("colspan") or 1)):
                    grid[(r + dr, c + dc)] = value
            c += int(cell.attrs.get("colspan") or 1)
    height = len(trs)
    width = max(c for _, c in grid) + 1
    rows = [[grid.get((r, c), "—") for c in range(width)] for r in range(height)]
    return {"type": "table", "headers": rows[0], "rows": rows[1:]}


def blocks_for(html: str, ctx: Context, figures: Figures, prefix: str) -> list[dict]:
    blocks: list[dict] = []
    figure_index = 0
    for part in SEGMENT.split(html):
        if not part or not part.strip():
            continue
        if part.startswith("<div class='fig'>") and "<svg" not in part:
            blocks.append({"type": "formula", "text": to_plain(part[len("<div class='fig'>"):-len("</div>")], ctx)})
        elif part.startswith("<div class='fig'>") or part.startswith("<svg"):
            figure_index += 1
            body = part[len("<div class='fig'>"):-len("</div>")] if part.startswith("<div") else part
            name = figures.add(f"{prefix}-{figure_index}.png", body)
            alt = svg_text(body) or to_plain(body, ctx)
            blocks.append({"type": "image", "assetName": name, "altText": "図：" + alt if alt else "図"})
        elif part.startswith("<table>"):
            blocks.append(table_block(part, ctx))
        elif part.startswith("<pre>"):
            text = to_plain(part[5:-6].replace("\n", "<br>"), ctx)
            blocks.append({"type": "monospace", "text": text})
        else:
            text = to_markup(part, ctx)
            if text:
                blocks.append({"type": "text", "text": text})
    return blocks


def plain_of(blocks: list[dict]) -> str:
    parts = []
    for b in blocks:
        if b["type"] in ("text", "monospace"):
            parts.append(strip_markup(b["text"]))
    return "\n".join(parts).strip()


def strip_markup(text: str) -> str:
    text = re.sub(r"\[([^\]\n]+)\]\((?:https|exammaster)://[^)\s]+\)", r"\1", text)
    return text.replace("**", "").replace("==", "").replace("​", "")


# ---------------------------------------------------------------- questions

ERA = {"令和": 2018, "平成": 1988}


def source_info(src: str) -> tuple[str, int, list[str]]:
    """→ (kind, year, tags)."""
    if src.startswith("出典："):
        m = re.match(r"出典：(令和|平成)(元|\d+)年度", src)
        if not m:
            raise ValueError(f"unknown source year: {src}")
        year = ERA[m.group(1)] + (1 if m.group(2) == "元" else int(m.group(2)))
        tags = ["過去問"]
        count = re.search(r"ESで(\d+)回出題", src)
        if count:
            tags.append(f"ESで{count.group(1)}回出題")
        return "past", year, tags
    if src.startswith("オリジナル"):
        return "original", ORIGINAL_YEAR, ["オリジナル"]
    raise ValueError(f"unknown source: {src}")


def display_source(src: str, kind: str) -> str:
    if kind == "past":
        return src.removeprefix("出典：")
    return "ExamMaster " + src  # displaySource() swaps the prefix for the brand name


def convert_question(raw: dict, links: LinkMapper, figures: Figures, warnings: list[str]) -> dict:
    qid = f"es-s{raw['set']:02d}-q{raw['no']:02d}"
    ctx = lambda field: Context(links, warnings, f"{qid}.{field}")
    kind, year, tags = source_info(raw["src"])
    category = raw["cat"]
    concept = category.split("／")[-1]

    body = blocks_for(raw["q"], ctx("q"), figures, f"{qid}-q")
    stem = plain_of(body) or to_plain(raw["q"], ctx("q"))

    choices: list[str] = []
    choice_blocks: list[list[dict]] = []
    rich_choices = False
    for i, html in enumerate(raw["choices"]):
        if "<svg" in html:
            rich_choices = True
            name = figures.add(f"{qid}-c{i + 1}.png", html)
            choices.append(f"図{LABELS[i]}")
            alt = svg_text(html)
            choice_blocks.append([{"type": "image", "assetName": name,
                                   "altText": f"選択肢{LABELS[i]}の図" + (f"：{alt}" if alt else "")}])
        elif "<table" in html:
            rich_choices = True
            rows = re.findall(r"<tr>(.*?)</tr>", html, flags=re.S)
            lines = []
            for row in rows:
                cells = [to_plain(c, ctx("choices")) for c in re.findall(r"<t[hd]>(.*?)</t[hd]>", row)]
                lines.append((cells[0], cells[1:]))
            choices.append(" / ".join(f"{h}={''.join(v)}" for h, v in lines))
            choice_blocks.append([{"type": "monospace", "text": "\n".join(f"{h}  {' '.join(v)}" for h, v in lines)}])
        else:
            text = to_plain(html, ctx("choices"))
            choices.append(text)
            choice_blocks.append([{"type": "text", "text": text}])

    reasons = [to_markup(o, ctx("opts")) for o in raw["opts"]]

    exp_blocks = blocks_for(raw["exp"], ctx("exp"), figures, f"{qid}-e")
    if exp_blocks and exp_blocks[0]["type"] == "text":
        explanation = exp_blocks.pop(0)["text"]
    else:
        # A comparison table comes first; lead with why the answer is right.
        lead = re.sub(r"^正しい[。．]?\s*", "", reasons[raw["ans"]])
        explanation = lead or f"正解は{LABELS[raw['ans']]}「{choices[raw['ans']].rstrip('。')}」。"
        warnings.append(f"{qid}.exp: starts with a table; lead sentence taken from the correct choice's reason")

    related: list[dict] = []
    bullets: list[str] = []
    for item in raw.get("rel") or []:
        parts = blocks_for(item, ctx("rel"), figures, f"{qid}-r{len(related) + len(bullets) + 1}")
        if len(parts) == 1 and parts[0]["type"] == "text":
            bullets.append("- " + parts[0]["text"].replace("\n", " "))
            continue
        if bullets:
            related.append({"type": "text", "text": "\n".join(bullets)})
            bullets = []
        related.extend(parts)
    if bullets:
        related.append({"type": "text", "text": "\n".join(bullets)})

    question = {
        "id": qid,
        "year": year,
        "subject": SUBJECT,
        "category": category,
        "stem": stem,
        "choices": choices,
        "correctIndex": raw["ans"],
        "explanation": explanation,
        "source": display_source(raw["src"], kind),
        "questionNumber": raw["no"],
        "difficulty": 3,
        "tags": tags,
        "concepts": [concept],
        "kind": kind,
        "mockSetID": set_id(raw["set"]),
        "choiceExplanations": reasons,
    }
    if len(body) > 1 or any(b["type"] != "text" for b in body):
        question["bodyBlocks"] = body
    if rich_choices:
        question["choiceBlocks"] = choice_blocks
    if exp_blocks:
        question["explanationBlocks"] = exp_blocks
    if related:
        question["related"] = related
    return question


def set_id(number: int) -> str:
    return f"es-set-{number:02d}"


# ---------------------------------------------------------------- glossary

def glossary_terms(raw: list[dict], warnings: list[str]) -> list[dict]:
    terms = []
    used: set[str] = set()
    for index, g in enumerate(raw):
        name = g.get("n") or g["k"][0]
        slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
        base = slug if re.fullmatch(r"[\x20-\x7e]+", name) and slug else f"g{index + 1:04d}"
        term_id, n = base, 2
        while term_id in used:
            term_id, n = f"{base}-{n}", n + 1
        used.add(term_id)
        ctx = Context(NoLinks(), warnings, f"glossary.{term_id}")
        term = {"id": term_id, "term": name, "keys": g["k"]}
        if g.get("f"):
            term["english"] = g["f"]
        term["description"] = to_markup(g["d"], ctx)
        terms.append(term)
    return terms


_PATTERNS: list | None = None


def term_patterns(raw_terms: list[dict]) -> list:
    global _PATTERNS
    if _PATTERNS is None:
        _PATTERNS = [[re.compile(r"(^|[^A-Za-z0-9])" + re.escape(k) + r"(?![A-Za-z0-9])")
                      if re.fullmatch(r"[\x20-\x7e]+", k) else k for k in raw["k"]] for raw in raw_terms]
    return _PATTERNS


def term_hits(question_html: list[str], terms: list[dict], raw_terms: list[dict]) -> list[str]:
    """Same rule as the web app: ASCII keys match on word boundaries (case-sensitive), others by substring."""
    def plain(html):
        html = re.sub(r"<(br|/?(p|div|li|tr|td|th|table|ul|ol|h\d|text))\b[^>]*>", " ", html or "", flags=re.I)
        return re.sub(r"<[^>]+>", "", html)
    text = " \n ".join(plain(h) for h in question_html)
    hits = []
    for term, keys in zip(terms, term_patterns(raw_terms)):
        pos = -1
        for key in keys:
            if isinstance(key, str):
                p = text.find(key)
            else:
                m = key.search(text)
                p = m.start() + len(m.group(1)) if m else -1
            if p >= 0 and (pos < 0 or p < pos):
                pos = p
        if pos >= 0:
            hits.append((pos, term["id"]))
    return [term_id for _, term_id in sorted(hits, key=lambda h: h[0])]


# ---------------------------------------------------------------- main

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ipa", type=Path, default=Path.home() / "Downloads" / "ipa")
    parser.add_argument("--skip-figures", action="store_true", help="reuse existing PNGs")
    args = parser.parse_args()
    if not args.skip_figures and not Path(CHROME).exists():
        sys.exit("Google Chrome is required to render figures")

    data = json.loads(subprocess.run(["node", str(TOOLS / "extract_ipa.js"), str(args.ipa)],
                                     check=True, capture_output=True, text=True).stdout)
    warnings: list[str] = []
    links = LinkMapper(args.ipa, data["chipIDs"], data["journeyIDs"])
    figures = Figures(args.skip_figures)

    terms = glossary_terms(data["glossary"], warnings)
    questions = []
    for raw in data["questions"]:
        q = convert_question(raw, links, figures, warnings)
        ids = term_hits([raw["q"], raw["exp"], *raw["choices"], *raw["opts"], *(raw.get("rel") or [])],
                        terms, data["glossary"])
        if ids:
            q["glossaryTermIDs"] = ids
        questions.append(q)

    if links.errors:
        sys.exit("\n".join(links.errors))

    mock_sets = []
    for number in range(1, 13):
        ids = [q["id"] for q in questions if q["mockSetID"] == set_id(number)]
        mock_sets.append({"id": set_id(number), "title": SET_TITLES.get(number, f"セット{number}"),
                          "kind": "original", "questionIDs": ids, "questionCount": len(ids), "minutes": 40})

    figures.render()
    OUT.mkdir(parents=True, exist_ok=True)
    write_json(OUT / "questions.json", {"version": 2, "questions": questions, "mockSets": mock_sets})
    write_json(OUT / "glossary.json", {"version": 1, "terms": terms})
    print(f"questions {len(questions)}  sets {len(mock_sets)}  terms {len(terms)}  figures {len(figures.jobs)}"
          f"  textbook links {len(links.used)}")
    for w in warnings:
        print("note:", w)


def write_json(path: Path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
