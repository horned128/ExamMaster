#!/usr/bin/env python3
"""Build the Piyo Pop App Store screenshot page for one qualification app.

    python3 tools/release/store_screenshots.py docs/<app>/app-store-assets/storyboard.json

Writes index.html next to storyboard.json. Captures in assets/ stay untouched (uniform scaling only).
Render with Chrome headless via tools/release/render_store_screenshots.sh.
"""
import html
import json
import sys
from pathlib import Path

CSS = """
*{box-sizing:border-box;margin:0}
html,body{background:#FFF9EB}
body{font-family:"Hiragino Sans","Noto Sans JP",sans-serif;color:#2D2618;-webkit-font-smoothing:antialiased}
.shot{position:relative;overflow:hidden;width:100vw;height:100vh;display:flex;flex-direction:column;align-items:center;
  padding:7.4vw 6.8vw 0;background:#FFF9EB}
.shot.yellow{background:#FFC83D}
.shot::before{content:"";position:absolute;left:-12vw;right:-12vw;top:92vw;bottom:-20vw;border-radius:50% 50% 0 0/14vw 14vw 0 0;background:#FFC83D}
.shot.yellow::before{background:#FFF1C7}
.chip{position:relative;display:inline-flex;align-items:center;gap:1.6vw;padding:1.5vw 3.4vw 1.5vw 2.2vw;border-radius:99vw;
  background:#fff;font-family:"Hiragino Maru Gothic ProN","Hiragino Sans",sans-serif;font-size:2.9vw;font-weight:700;color:#6A5D45;
  box-shadow:0 .7vw 0 var(--accent)}
.chip i{width:2.6vw;height:2.6vw;border-radius:50%;background:var(--accent)}
h1{position:relative;margin-top:5.6vw;font-size:8.6vw;line-height:1.32;letter-spacing:-.02em;font-weight:800;text-align:center}
h1 em{font-style:normal;background:linear-gradient(transparent 62%,#FFC83D 62%,#FFC83D 92%,transparent 92%)}
.yellow h1 em{background:linear-gradient(transparent 62%,#fff 62%,#fff 92%,transparent 92%)}
.subhead{position:relative;margin-top:3vw;font-size:3.7vw;line-height:1.6;font-weight:600;color:#6A5D45;text-align:center}
.screen{position:relative;margin-top:5.6vw;width:70vw;flex-shrink:0;padding:1.5vw;border-radius:8.8vw;background:#2D2618;
  box-shadow:0 3vw 0 rgba(45,38,24,.18),0 6vw 10vw rgba(120,90,20,.18);line-height:0}
.screen img{display:block;width:100%;height:auto;border-radius:7.4vw}
.note{position:absolute;left:0;right:0;bottom:3.4vw;text-align:center;font-size:2.4vw;color:#6A5D45;font-weight:600}
"""


def build(storyboard_path: Path) -> Path:
    board = json.loads(storyboard_path.read_text())
    base = storyboard_path.parent
    sections = []
    for index, panel in enumerate(board["panels"]):
        image = base / "assets" / panel["image"]
        if not image.exists():
            raise SystemExit(f"missing capture: {image}")
        tone = "yellow" if index % 2 else ""
        headline = "<br>".join(html.escape(line).replace("[", "<em>").replace("]", "</em>")
                               for line in panel["headline"])
        note = f'<p class="note" data-qa-content>{html.escape(board["note"])}</p>' if board.get("note") else ""
        sections.append(
            f'<section class="shot {tone}" id="p{index + 1}">'
            f'<p class="chip"><i></i>{html.escape(board["brand"])}</p>'
            f'<h1>{headline}</h1>'
            f'<p class="subhead">{html.escape(panel["subhead"])}</p>'
            f'<figure class="screen"><img src="assets/{html.escape(panel["image"])}" alt="{html.escape(panel["alt"])}"></figure>'
            f'{note}</section>')
    page = (f'<!doctype html><html lang="ja"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{html.escape(board["brand"])} App Store</title>'
            f'<style>:root{{--accent:{board["accent"]}}}{CSS}</style></head><body>'
            + "".join(sections)
            + '<script>const id=location.hash.slice(1);if(id)document.querySelectorAll(".shot")'
              '.forEach(s=>{if(s.id!==id)s.remove()})</script></body></html>\n')
    output = base / "index.html"
    output.write_text(page)
    return output


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    print(build(Path(sys.argv[1])))
