#!/usr/bin/env python3
"""Render the editable App Store poster layout to PNG using Pillow."""
from __future__ import annotations

from html.parser import HTMLParser
from pathlib import Path
import re

from PIL import Image, ImageColor, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
HTML = ROOT / "index.html"
CSS = ROOT / "styles.css"
PNG_DIR = ROOT / "png" / "1320x2868"
WIDTH, HEIGHT = 1320, 2868
FONT_REGULAR = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"


class PosterParser(HTMLParser):
    """Read each poster's copy and its source PNG directly from index.html."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.posters = []
        self.current = None
        self.capture = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = attrs.get("class", "").split()
        if tag == "section" and "shot" in classes:
            self.current = {"classes": classes, "label": attrs.get("aria-label", "")}
            self.posters.append(self.current)
        elif self.current is not None and tag in {"span", "p", "h1"}:
            key = next((name for name in ("brand", "sequence", "eyebrow", "subhead") if name in classes), None)
            if tag == "h1":
                key = "headline"
            if key:
                self.capture = key
                self.current[key] = ""
        elif self.current is not None and tag == "img":
            self.current["image"] = attrs.get("src", "")

    def handle_endtag(self, tag):
        if tag in {"span", "p", "h1"}:
            self.capture = None
        if tag == "section":
            self.current = None

    def handle_data(self, data):
        if self.current is not None and self.capture:
            self.current[self.capture] += data


def css_rule(text: str, selector: str) -> dict[str, str]:
    escaped = re.escape(selector)
    match = re.search(rf"(?m)^{escaped}\s*\{{([^}}]*)\}}", text)
    if not match:
        return {}
    result = {}
    for declaration in match.group(1).split(";"):
        if ":" in declaration:
            key, value = declaration.split(":", 1)
            result[key.strip()] = value.strip()
    return result


def px(value: str, default: float = 0) -> float:
    match = re.match(r"(-?[\d.]+)px", value.strip())
    return float(match.group(1)) if match else default


def color(value: str, fallback: str = "#000000") -> tuple[int, int, int, int]:
    value = value.strip()
    match = re.fullmatch(r"rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)", value)
    if match:
        r, g, b = (int(match.group(i)) for i in (1, 2, 3))
        a = round(float(match.group(4)) * 255)
        return r, g, b, a
    try:
        return ImageColor.getcolor(value or fallback, "RGBA")
    except ValueError:
        return ImageColor.getcolor(fallback, "RGBA")


def spaced_width(font: ImageFont.FreeTypeFont, text: str, spacing: float) -> float:
    return sum(font.getlength(char) for char in text) + max(0, len(text) - 1) * spacing


def tracking(value: str, font: ImageFont.FreeTypeFont) -> float:
    value = value.strip()
    em = re.fullmatch(r"(-?[\d.]+)em", value)
    if em:
        return float(em.group(1)) * font.size
    return px(value)


def draw_spaced(draw: ImageDraw.ImageDraw, xy, text, font, fill, spacing=0):
    # Share one baseline across glyphs so Japanese punctuation stays in place.
    x, y = xy
    baseline = y + font.getmetrics()[0]
    for char in text:
        draw.text((round(x), round(baseline)), char, font=font, fill=fill, anchor="ls")
        x += font.getlength(char) + spacing


def render_decor(canvas: Image.Image, poster, css: str, accent):
    draw = ImageDraw.Draw(canvas, "RGBA")
    cls = next((name for name in poster["classes"] if name.startswith("decor-")), "decor-one")
    base = css_rule(css, ".decor")
    special = css_rule(css, "." + cls)
    layout = {**base, **special}
    width, height = px(layout.get("width", "350px")), px(layout.get("height", "350px"))
    top, right = px(layout.get("top", "-152px")), px(layout.get("right", "-78px"))
    x, y = WIDTH - right - width, top
    outer = color(poster["tone"].get("--decor", "rgba(0,0,0,.2)"))
    draw.ellipse((round(x), round(y), round(x + width), round(y + height)), outline=outer, width=max(1, round(px(layout.get("border-width", "2px")))))

    before = {**css_rule(css, ".decor::before"), **css_rule(css, f".{cls}::before")}
    inset = px(before.get("inset", "33px"), 33)
    inner = color(before.get("border-color", poster["tone"].get("--decor-inner", "rgba(0,0,0,.15)")))
    draw.ellipse((round(x + inset), round(y + inset), round(x + width - inset), round(y + height - inset)), outline=inner, width=max(1, round(px(before.get("border-width", "1px")))))

    after = {**css_rule(css, ".decor::after"), **css_rule(css, f".{cls}::after")}
    dot_w, dot_h = px(after.get("width", "15px")), px(after.get("height", "15px"))
    dot_x = x + px(after.get("left", "37px"))
    dot_y = y + height - px(after.get("bottom", "27px")) - dot_h
    draw.ellipse((round(dot_x), round(dot_y), round(dot_x + dot_w), round(dot_y + dot_h)), fill=accent)


def main():
    if not Path(FONT_REGULAR).exists() or not Path(FONT_BOLD).exists():
        raise SystemExit("Set FONT_REGULAR and FONT_BOLD to Japanese-capable fonts on this system.")
    parser = PosterParser()
    parser.feed(HTML.read_text(encoding="utf-8"))
    css = CSS.read_text(encoding="utf-8")
    root_tokens = css_rule(css, ":root")
    masthead = css_rule(css, ".masthead")
    progress = css_rule(css, ".progress")
    copy = css_rule(css, ".copy")
    eyebrow_style = css_rule(css, ".eyebrow")
    headline_style = css_rule(css, "h1")
    subhead_style = css_rule(css, ".subhead")
    screen_style = css_rule(css, ".screen")
    screen_left, screen_top = px(screen_style.get("left", "100px")), px(screen_style.get("top", "414px"))
    screen_width = round(px(screen_style.get("width", "1120px")))
    brand_font = ImageFont.truetype(FONT_BOLD, round(px(masthead.get("font-size", "23px"))))
    eyebrow_font = ImageFont.truetype(FONT_BOLD, round(px(eyebrow_style.get("font-size", "25px"))))
    headline_font = ImageFont.truetype(FONT_BOLD, round(px(headline_style.get("font-size", "70px"))))
    subhead_font = ImageFont.truetype(FONT_REGULAR, round(px(subhead_style.get("font-size", "30px"))))
    PNG_DIR.mkdir(parents=True, exist_ok=True)

    for index, poster in enumerate(parser.posters, start=1):
        tone_name = next(name for name in poster["classes"] if name.startswith("tone-"))
        tone = css_rule(css, "." + tone_name)
        poster["tone"] = tone
        bg = color(tone.get("background", "#fbf6eb"))
        ink = color(tone.get("--ink", root_tokens.get("--ink", "#19353b")))
        muted = color(tone.get("--muted", root_tokens.get("--muted", "#51666a")))
        accent = color(tone.get("--accent", "#c26448"))
        canvas = Image.new("RGBA", (WIDTH, HEIGHT), bg)
        render_decor(canvas, poster, css, accent)
        draw = ImageDraw.Draw(canvas, "RGBA")

        margin_left = px(masthead.get("left", "96px"))
        margin_right = px(masthead.get("right", "96px"))
        mast_top = px(masthead.get("top", "74px"))
        brand = poster.get("brand", "PIYOTORE · APPLIED INFORMATION")
        brand_parts = brand.split("·")
        brand_left = brand_parts[0].strip()
        brand_right = brand_parts[1].strip() if len(brand_parts) > 1 else ""
        brand_y = mast_top + 2
        brand_tracking = tracking(masthead.get("letter-spacing", "0em"), brand_font)
        draw_spaced(draw, (margin_left, brand_y), brand_left, brand_font, ink, brand_tracking)
        separator_x = margin_left + spaced_width(brand_font, brand_left, brand_tracking) + 7
        draw.text((round(separator_x), round(brand_y)), "·", font=brand_font, fill=accent, anchor="lt")
        right_brand_x = separator_x + brand_font.getlength("·") + 7
        draw_spaced(draw, (right_brand_x, brand_y), brand_right, brand_font, ink, brand_tracking)

        sequence = poster.get("sequence", f"{index:02} / 06").replace("/", " / ")
        sequence_tracking = tracking(css_rule(css, ".sequence").get("letter-spacing", "0em"), brand_font)
        seq_width = spaced_width(brand_font, sequence, sequence_tracking)
        draw_spaced(draw, (WIDTH - margin_right - seq_width, brand_y), sequence, brand_font, muted, sequence_tracking)

        progress_left, progress_top = px(progress.get("left", "96px")), px(progress.get("top", "126px"))
        progress_width, progress_height = px(progress.get("width", "1128px")), max(1, round(px(progress.get("height", "4px"))))
        draw.rectangle((round(progress_left), round(progress_top), round(progress_left + progress_width), round(progress_top + progress_height)), fill=color(tone.get("--line", root_tokens.get("--line", "rgba(25,53,59,.2)"))))
        draw.rectangle((round(progress_left), round(progress_top), round(progress_left + progress_width * index / len(parser.posters)), round(progress_top + progress_height)), fill=accent)

        copy_top, copy_left = px(copy.get("top", "157px")), px(copy.get("left", "96px"))
        ey_line = px(eyebrow_style.get("line-height", "33.75px"), 33.75)
        draw_spaced(draw, (copy_left, copy_top), poster["eyebrow"], eyebrow_font, accent, tracking(eyebrow_style.get("letter-spacing", "0em"), eyebrow_font))
        headline_y = copy_top + ey_line + px(eyebrow_style.get("margin-bottom", "13px"))
        title_spacing = tracking(headline_style.get("letter-spacing", "0em"), headline_font)
        draw_spaced(draw, (copy_left, headline_y), poster["headline"], headline_font, ink, title_spacing)
        title_line = px(headline_style.get("line-height", "87.5px"), 87.5)
        sub_y = headline_y + title_line + px(subhead_style.get("margin-top", "13px"))
        draw_spaced(draw, (copy_left, sub_y), poster["subhead"], subhead_font, muted, tracking(subhead_style.get("letter-spacing", "0em"), subhead_font))

        source_path = ROOT / poster["image"]
        source = Image.open(source_path).convert("RGBA")
        screen_height = round(screen_width * source.height / source.width)
        shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.rectangle((round(screen_left), round(screen_top + 16), round(screen_left + screen_width), round(screen_top + screen_height + 16)), fill=(28, 40, 39, 34))
        shadow = shadow.filter(ImageFilter.GaussianBlur(34))
        canvas.alpha_composite(shadow)
        screen = source.resize((screen_width, screen_height), Image.Resampling.LANCZOS)
        canvas.alpha_composite(screen, (round(screen_left), round(screen_top)))
        output = PNG_DIR / f"{index:02}.png"
        canvas.convert("RGB").save(output, "PNG", optimize=True)

    create_contact_sheet(parser.posters)
    print(f"Rendered {len(parser.posters)} PNGs at {WIDTH}x{HEIGHT} and contact-sheet.png")


def create_contact_sheet(posters):
    cols, thumb_w, gap, margin, label_h = 3, 340, 24, 28, 58
    thumb_h = round(thumb_w * HEIGHT / WIDTH)
    rows = (len(posters) + cols - 1) // cols
    sheet_w = margin * 2 + cols * thumb_w + (cols - 1) * gap
    sheet_h = margin * 2 + rows * (thumb_h + label_h) + (rows - 1) * gap
    sheet = Image.new("RGB", (sheet_w, sheet_h), "#e8e3d9")
    draw = ImageDraw.Draw(sheet)
    label_font = ImageFont.truetype(FONT_BOLD, 20)
    for index, poster in enumerate(posters):
        row, col = divmod(index, cols)
        x = margin + col * (thumb_w + gap)
        y = margin + row * (thumb_h + label_h + gap)
        thumb = Image.open(PNG_DIR / f"{index + 1:02}.png").convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x, y))
        draw.text((x, y + thumb_h + 11), f"{index + 1:02}  {poster.get('headline', '')}", font=label_font, fill="#19353b", anchor="lt")
    sheet.save(ROOT / "contact-sheet.png", "PNG", optimize=True)


if __name__ == "__main__":
    main()
