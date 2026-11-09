#!/usr/bin/env python3
"""One-time import of the ipa web app's ES textbook into ExamMaster files.

    python3 tools/embedded-specialist/import_textbook.py [--ipa ~/Downloads/ipa] [--skip-figures]

Writes Qualifications/embedded-specialist/{textbook.json,layermap.json,Figures/tb-*.png}.
Like import_ipa.py, the JSON becomes the source of truth after this; edit it directly afterwards.

Mapping
- basics.html chapter N → textbook chapter basics-N; each <h3 id> is a section, <h4 id> an extra anchor.
- p.exam → callout exam, p.link → callout practice (「組込みでは」), div.fix → callout caution,
  details.quiz → quiz block, figures and timing charts → PNG @3x.
- cheatsheet.js section N → chapter summary-N; each table is a section, its bold words become ==mark==.
- layers-data.js → layermap.json; "📝 試験：" in a term splits off as the chip's exam note,
  a journey's phys blocks become its 物理的には content.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from html import escape
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_ipa import (CHROME, FIGURE_PAGE, OUT, TEXTBOOK_FIGURE_PREFIX, TOOLS, Context, Figures,  # noqa: E402
                        LinkMapper, Node, inline, parse, svg_text, tidy, write_json)

PRACTICE_TITLE = "組込みでは"

# Department names on the web page were the author's own; the app uses neutral ones.
ZONE_NAMES = {"appz": "アプリケーション", "plat": "プラットフォーム（ソフトウェア）", "hw": "ハードウェア"}

BASICS_BOOK = {
    "id": "basics", "title": "電子回路の基礎", "symbol": "bolt",
    "summary": "部品からマイコンのピンまで、電気の動きを積み上げる",
}
SUMMARY_BOOK = {
    "id": "summary", "title": "要点まとめ", "symbol": "list.bullet.rectangle",
    "summary": "取り違えやすい用語の対比・計算の公式・ひっかけの型",
}
MAP_SUMMARY = "組込みシステムの階層に用語を並べ、割込み・メモリアクセス・起動の流れを段ごとに追う"


class TextbookLinks(LinkMapper):
    """Adds the links only textbook pages use: same-page anchors and the 全体図 page itself."""

    def __init__(self, ipa: Path, chip_ids, journey_ids):
        super().__init__(ipa, chip_ids, journey_ids)
        self.page = "basics.html"

    def map(self, href: str, where: str):
        if href.startswith("#"):
            href = self.page + href
        page, _, anchor = href.partition("#")
        if page == "layers.html" and anchor in ("", "map"):
            url = "exammaster://textbook/overview"
            self.used.add(url)
            return url
        return super().map(href, where)


def classes(node: Node) -> set[str]:
    return set(node.attrs.get("class", "").split())


def children_markup(node: Node, ctx: Context) -> str:
    holder = Node("#root")
    holder.children = node.children
    return tidy(inline(holder, ctx, True))


def outer_html(node: Node | str) -> str:
    if isinstance(node, str):
        return escape(node, quote=False)
    attrs = "".join(f' {k}="{escape(v)}"' for k, v in node.attrs.items())
    if node.tag in ("br", "img", "hr", "wbr"):
        return f"<{node.tag}{attrs}>"
    return f"<{node.tag}{attrs}>" + "".join(outer_html(c) for c in node.children) + f"</{node.tag}>"


def element_ids(nodes: list) -> list[str]:
    """Every id a link can point at inside a section, except figure internals."""
    ids: list[str] = []
    for node in nodes:
        if isinstance(node, Node) and node.tag != "svg":
            if node.attrs.get("id"):
                ids.append(node.attrs["id"])
            ids.extend(element_ids(node.children))
    return ids


def find(node: Node, tag: str) -> Node | None:
    for child in node.children:
        if isinstance(child, Node):
            if child.tag == tag:
                return child
            hit = find(child, tag)
            if hit:
                return hit
    return None


def strip(markup: str) -> str:
    """Plain text for alt text: link labels and emphasis without the markup."""
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", markup)
    return text.replace("**", "").replace("==", "")


def table_markup_block(node: Node, ctx: Context) -> dict:
    """Like import_ipa.table_block, but cells keep **bold**/==mark== (the app renders cell markup)."""
    trs: list[Node] = []

    def walk(n):
        for child in n.children:
            if isinstance(child, Node):
                (trs.append(child) if child.tag == "tr" else walk(child))
    walk(node)
    grid: dict[tuple[int, int], str] = {}
    for r, tr in enumerate(trs):
        c = 0
        for cell in (x for x in tr.children if isinstance(x, Node) and x.tag in ("td", "th")):
            while (r, c) in grid:
                c += 1
            value = children_markup(cell, ctx).replace("\n", " ") or "—"
            if cell.tag == "th":
                value = re.sub(r"\*\*(.+?)\*\*", r"\1", value)
            for dr in range(int(cell.attrs.get("rowspan") or 1)):
                for dc in range(int(cell.attrs.get("colspan") or 1)):
                    grid[(r + dr, c + dc)] = value
            c += int(cell.attrs.get("colspan") or 1)
    width = max(c for _, c in grid) + 1
    rows = [[grid.get((r, c), "—") for c in range(width)] for r in range(len(trs))]
    return {"type": "table", "headers": rows[0], "rows": rows[1:]}


class BlockWriter:
    """Turns a run of HTML block elements into ContentBlocks."""

    def __init__(self, ctx: Context, figures: Figures, prefix: str, defs: str = ""):
        self.ctx = ctx
        self.figures = figures
        self.prefix = prefix
        self.defs = defs
        self.figure_count = 0

    def figure(self, svg_html: str, alt: str, caption: str | None) -> dict:
        self.figure_count += 1
        name = self.figures.add(f"{TEXTBOOK_FIGURE_PREFIX}{self.prefix}-{self.figure_count}.png", self.defs + svg_html)
        block = {"type": "image", "assetName": name, "altText": alt}
        if caption:
            block["caption"] = caption
        return block

    def text(self, value: str) -> list[dict]:
        return [{"type": "text", "text": value}] if value else []

    def blocks(self, nodes: list[Node | str]) -> list[dict]:
        out: list[dict] = []
        loose: list[Node | str] = []

        def flush():
            if loose:
                holder = Node("#root")
                holder.children = list(loose)
                out.extend(self.text(tidy(inline(holder, self.ctx, True))))
                loose.clear()

        for node in nodes:
            if isinstance(node, str) or node.tag in ("b", "strong", "span", "a", "code", "br", "sub", "sup", "mark", "i", "em"):
                loose.append(node)
                continue
            flush()
            out.extend(self.element(node))
        flush()
        return out

    def element(self, node: Node) -> list[dict]:
        cls = classes(node)
        tag = node.tag
        if tag == "p" and "exam" in cls:
            return [{"type": "callout", "style": "exam", "text": children_markup(node, self.ctx)}]
        if tag == "p" and "link" in cls:
            return [{"type": "callout", "style": "practice", "title": PRACTICE_TITLE, "text": children_markup(node, self.ctx)}]
        if tag == "div" and "fix" in cls:
            return [{"type": "callout", "style": "caution", "text": "\n".join(b["text"] for b in self.blocks(node.children) if b["type"] == "text")}]
        if tag in ("p", "figcaption"):
            return self.text(children_markup(node, self.ctx))
        if tag in ("h4", "h5"):
            return self.text("**" + children_markup(node, self.ctx).replace("**", "") + "**")
        if tag in ("ul", "ol"):
            items = [x for x in node.children if isinstance(x, Node) and x.tag == "li"]
            lines = []
            for number, li in enumerate(items, 1):
                nested = [x for x in li.children if isinstance(x, Node) and x.tag in ("ul", "ol")]
                own = Node("li")
                own.children = [x for x in li.children if x not in nested]
                body = children_markup(own, self.ctx).replace("\n", "　")
                lines.append(f"- {body}" if tag == "ul" else f"{number}. {body}")
                for sub in nested:
                    sub_items = [x for x in sub.children if isinstance(x, Node) and x.tag == "li"]
                    for k, item in enumerate(sub_items, 1):
                        mark = "・" if sub.tag == "ul" else f"({k})"
                        lines.append(f"　{mark} " + children_markup(item, self.ctx).replace("\n", "　"))
            return self.text("\n".join(lines))
        if tag == "figure":
            svg = find(node, "svg")
            cap = find(node, "figcaption")
            caption = children_markup(cap, self.ctx) if cap else None
            if svg is None:
                return self.blocks(node.children)
            alt = caption if caption and caption.startswith("図") else "図：" + (caption or svg_text(outer_html(svg)) or "回路図")
            return [self.figure(outer_html(svg), strip(alt), caption)]
        if tag == "svg":
            if node.attrs.get("width") == "0":
                return []
            alt = svg_text(outer_html(node))
            return [self.figure(outer_html(node), "図：" + (alt or "図"), None)]
        if tag == "table":
            return [table_markup_block(node, self.ctx)]
        if tag == "div" and "tw" in cls:
            table = find(node, "table")
            return [table_markup_block(table, self.ctx)] if table else []
        if tag == "div" and "quizhead" in cls:
            return self.text("**" + children_markup(node, self.ctx) + "**")
        if tag == "details" and "quiz" in cls:
            summary = find(node, "summary")
            answer = next((x for x in node.children if isinstance(x, Node) and "ans" in classes(x)), None)
            return [{"type": "quiz", "text": children_markup(summary, self.ctx) if summary else "",
                     "answer": children_markup(answer, self.ctx) if answer else ""}]
        if tag == "div" and ("totop" in cls or "stack" in cls):
            return []
        if tag == "pre":
            return [{"type": "monospace", "text": tidy(inline(node, self.ctx, False))}]
        if tag == "div":
            return self.blocks(node.children)
        self.ctx.warnings.append(f"{self.ctx.where}: unhandled block <{tag}>")
        return self.text(children_markup(node, self.ctx))


# ---------------------------------------------------------------- 電子回路の基礎

def basics_book(ipa: Path, links: TextbookLinks, figures: Figures, warnings: list[str]) -> dict:
    html = (ipa / "es" / "basics.html").read_text(encoding="utf-8")
    defs = re.search(r'<svg width="0" height="0".*?</svg>', html, re.S).group(0)
    root = parse(html)
    cards: list[Node] = []

    def walk(n):
        for child in n.children:
            if isinstance(child, Node):
                (cards.append(child) if child.tag == "section" and "card" in classes(child) else walk(child))
    walk(root)

    chapters = []
    outro: list[Node | str] = []
    for card in cards:
        card_id = card.attrs.get("id", "")
        if not card_id and chapters:  # 「この先へ」 closes the last chapter
            ctx = Context(links, warnings, chapters[-1]["id"])
            nodes = [c for c in card.children if not (isinstance(c, str) and not c.strip())]
            heading = next(n for n in nodes if isinstance(n, Node) and n.tag == "h2")
            writer = BlockWriter(ctx, figures, chapters[-1]["id"] + "-next", defs)
            chapters[-1]["sections"].append({"id": "next", "title": children_markup(heading, ctx),
                                             "blocks": writer.blocks([n for n in nodes if n is not heading])})
            continue
        if not re.fullmatch(r"ch\d+", card_id):
            continue
        number = card_id[2:]
        ctx = Context(links, warnings, f"basics-{number}")
        nodes = [c for c in card.children if not (isinstance(c, str) and not c.strip())]
        heading = next(n for n in nodes if isinstance(n, Node) and n.tag == "h2")
        title = children_markup(heading, ctx).split("　", 1)[-1]
        writer = BlockWriter(ctx, figures, f"basics-{number}", defs)
        lead: list[Node | str] = []
        sections: list[tuple[Node, list]] = []
        target = lead
        for n in nodes:
            if n is heading:
                continue
            if isinstance(n, Node) and n.tag == "h2":  # 「この先へ」 after chapter 8
                sections.append((n, []))
                target = sections[-1][1]
                continue
            if isinstance(n, Node) and n.tag == "h3":
                sections.append((n, []))
                target = sections[-1][1]
                continue
            target.append(n)
        chapter = {"id": f"basics-{number}", "number": f"第{number}章", "title": title}
        lead_blocks = writer.blocks(lead)
        if lead_blocks:
            chapter["blocks"] = lead_blocks
        chapter["sections"] = []
        for h, body in sections:
            section_title = children_markup(h, ctx).replace("　", " ")
            section_id = h.attrs.get("id") or ("next" if "この先へ" in section_title else f"s{len(chapter['sections']) + 1}")
            blocks = writer.blocks(body)
            section = {"id": section_id, "title": section_title}
            anchors = element_ids(body)
            if anchors:
                section["anchors"] = anchors
            section["blocks"] = blocks
            chapter["sections"].append(section)
        chapters.append(chapter)
    intro = [{"type": "text", "text":
              "ES の午前IIは「マイコンの外と中で、電気的に何が起きているか」を知っていると一気に解きやすくなります。"
              "この本は試験範囲より一段深く、**部品レベルから積み上げて**マイコンの入出力ピンまでたどり着く構成です。\n"
              "- 各部品は **役割（回路で何をするか）→ 仕組み（直感的に）→ 計算（最低限）** の順に説明します。\n"
              "- 例にするマイコンは **Cortex-M 相当、入出力ピンは 3.3V** です。「目安」と書いた数値は品種によって変わるので、実機ではデータシートを確認してください。"}]
    return {**BASICS_BOOK, "intro": intro, "chapters": chapters}


# ---------------------------------------------------------------- 要点まとめ

def summary_book(cheatsheet: list[dict], links: TextbookLinks, figures: Figures, warnings: list[str]) -> dict:
    chapters = []
    for index, item in enumerate(cheatsheet, 1):
        ctx = Context(links, warnings, f"summary-{index}")
        number, _, title = item["title"].partition(" ")
        html = re.sub(r"<(/?)b>", r"<\1mark>", item["html"])
        nodes = [c for c in parse(html).children if not (isinstance(c, str) and not c.strip())]
        writer = BlockWriter(ctx, figures, f"summary-{index}")
        lead: list = []
        sections: list[dict] = []
        for n in nodes:
            if isinstance(n, Node) and n.tag == "table":
                block = table_markup_block(n, ctx)
                head = block["headers"][0]
                sections.append({"id": f"t{len(sections) + 1}", "title": head, "blocks": [block]})
            elif sections:
                sections[-1]["blocks"].extend(writer.blocks([n]))
            else:
                lead.append(n)
        chapter = {"id": f"summary-{index}", "number": number, "title": title}
        lead_blocks = writer.blocks(lead)
        if lead_blocks:
            chapter["blocks"] = lead_blocks
        if len(sections) == 1 and not lead_blocks:
            sections[0]["title"] = title
        chapter["sections"] = sections
        chapters.append(chapter)
    return {**SUMMARY_BOOK, "chapters": chapters}


# ---------------------------------------------------------------- 全体図

def question_id(ref: str) -> str:
    set_number, number = ref.split("-")
    return f"es-s{int(set_number):02d}-q{int(number):02d}"


def layer_map(layers: dict, links: TextbookLinks, figures: Figures, warnings: list[str], question_ids: set[str]) -> dict:
    links.page = "layers.html"
    zones = [{"id": z["key"], "name": ZONE_NAMES.get(z["key"], z["name"]), "rows": z["rows"], "colorHex": z["c"]}
             for z in layers["zones"]]
    rows = []
    for r in layers["rows"]:
        row = {"id": r["key"], "name": r["name"]}
        if r.get("short"):
            row["short"] = r["short"]
        row["example"] = r["ex"]
        if r.get("cross"):
            row["crossCutting"] = True
        row["colorHex"] = r["b"]
        rows.append(row)
    chips = []
    for t in layers["terms"]:
        ctx = Context(links, warnings, f"overview.{t['id']}")
        body, _, exam = t["desc"].partition("📝 試験：")
        chip = {"id": t["id"], "term": t["t"], "row": t["row"],
                "description": tidy(inline(parse(re.sub(r"<br>\s*$", "", body.strip())), ctx, True))}
        if exam:
            chip["exam"] = tidy(inline(parse(exam), ctx, True))
        ids = [question_id(q) for q in t.get("q") or []]
        missing = [i for i in ids if i not in question_ids]
        if missing:
            warnings.append(f"overview.{t['id']}: unknown questions {missing}")
        if ids:
            chip["questionIDs"] = [i for i in ids if i in question_ids]
        if t.get("b"):
            chip["textbook"] = links.map(t["b"], ctx.where)
        chips.append(chip)
    journeys = []
    for j in layers["journeys"]:
        ctx = Context(links, warnings, f"overview.j-{j['id']}")
        writer = BlockWriter(ctx, figures, f"overview-{j['id']}")
        physical = []
        for part in j.get("phys") or []:
            if "chart" in part:
                svg = re.search(r"<svg\b.*?</svg>", part["chart"], re.S).group(0)
                svg = svg.replace("<svg ", '<svg width="760" ', 1)
                physical.append(writer.figure(svg, "タイミングチャート：" + part["title"], part["title"] or None))
            else:
                nodes = [c for c in parse(part["html"]).children if not (isinstance(c, str) and not c.strip())]
                physical.extend(writer.blocks(nodes))
        steps = [{"row": s["r"], "title": s["title"], "text": tidy(inline(parse(s["text"]), ctx, True)),
                  **({"chipIDs": s["terms"]} if s.get("terms") else {})} for s in j["steps"]]
        journeys.append({"id": j["id"], "title": j["title"], "intro": tidy(inline(parse(j["intro"]), ctx, True)),
                         "steps": steps, "physical": physical})
    return {"version": 1, "title": "全体図", "summary": MAP_SUMMARY,
            "intro": [{"type": "text", "text":
                       "行は組込みシステムの階層です（上ほどソフトウェア・抽象的、下ほどハードウェア・物理的）。"
                       "下の4本は、どの階層にもまたがる分野です。用語を押すと説明と関連問題が開きます。"}],
            "zones": zones, "rows": rows, "chips": chips, "journeys": journeys}


# ---------------------------------------------------------------- main

FIGURE_CSS = """<style>
svg.fig { max-width: none; height: auto; }
svg.fig text { font-family: -apple-system, "Hiragino Sans", sans-serif; font-size: 13px; fill: #222; }
svg.fig .t { font-weight: bold; fill: #1f3a5f; }
svg.fig .s { font-size: 12px; fill: #555; }
svg.fig .rt { fill: #c0392b; }
svg.fig .bt { fill: #1f3a5f; }
svg.fig .gt { fill: #1d6b38; }
svg.fig .w { stroke: #222; stroke-width: 2; fill: none; }
svg.fig .p { stroke: #222; stroke-width: 2; fill: #fff; }
svg.fig .f { fill: #222; }
svg.fig .thin { stroke: #888; stroke-width: 1; fill: none; }
svg.fig .dash { stroke: #888; stroke-width: 1; stroke-dasharray: 4 3; fill: none; }
svg.fig .cur { stroke: #c0392b; stroke-width: 2; fill: none; }
svg.fig .curd { stroke: #c0392b; stroke-width: 2; fill: none; stroke-dasharray: 6 4; }
svg.fig .sig { stroke: #1f3a5f; stroke-width: 2.2; fill: none; }
svg.fig .sig2 { stroke: #c0392b; stroke-width: 2.2; fill: none; }
svg.fig .sig3 { stroke: #1d6b38; stroke-width: 2.2; fill: none; }
svg.fig .box { stroke: #33557f; stroke-width: 1.5; fill: #eef3fb; }
svg.fig .zone { fill: #fff4d6; stroke: none; }
svg text { font-family: -apple-system, "Hiragino Sans", sans-serif; }
</style>"""


# The web page labelled its physical-layer panel with ⚡; the app calls it 「物理的には」.
TEXT_FIXES = [("⚡ 物理層の説明を開くと", "「物理的には」を開くと"), ("（⚡の図）", "（「物理的には」の図）")]


def retitle(value):
    text = json.dumps(value, ensure_ascii=False)
    for old, new in TEXT_FIXES:
        text = text.replace(old, new)
    if "⚡" in text:
        sys.exit("unhandled ⚡ reference in textbook text")
    return json.loads(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ipa", type=Path, default=Path.home() / "Downloads" / "ipa")
    parser.add_argument("--skip-figures", action="store_true", help="reuse existing PNGs")
    args = parser.parse_args()
    if not args.skip_figures and not Path(CHROME).exists():
        sys.exit("Google Chrome is required to render figures")

    data = json.loads(subprocess.run(["node", str(TOOLS / "extract_ipa.js"), str(args.ipa)],
                                     check=True, capture_output=True, text=True).stdout)
    question_ids = {q["id"] for q in json.loads((OUT / "questions.json").read_text(encoding="utf-8"))["questions"]}
    warnings: list[str] = []
    links = TextbookLinks(args.ipa, data["chipIDs"], data["journeyIDs"])
    figures = Figures(args.skip_figures, page=FIGURE_PAGE.replace("</style>", "</style>" + FIGURE_CSS),
                      owns=lambda name: name.startswith(TEXTBOOK_FIGURE_PREFIX))

    books = [basics_book(args.ipa, links, figures, warnings),
             summary_book(data["cheatsheet"], links, figures, warnings)]
    overview = layer_map(data["layers"], links, figures, warnings, question_ids)
    if links.errors:
        sys.exit("\n".join(links.errors))

    figures.render()
    write_json(OUT / "textbook.json", retitle({"version": 1, "books": books}))
    write_json(OUT / "layermap.json", retitle(overview))
    sections = sum(len(c["sections"]) for b in books for c in b["chapters"])
    print(f"books {len(books)}  chapters {sum(len(b['chapters']) for b in books)}  sections {sections}"
          f"  chips {len(overview['chips'])}  journeys {len(overview['journeys'])}  figures {len(figures.jobs)}")
    for w in warnings:
        print("note:", w)


if __name__ == "__main__":
    main()
