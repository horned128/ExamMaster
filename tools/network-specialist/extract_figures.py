#!/usr/bin/env python3
"""Reproducible crops of the official booklet; coordinates are reviewed, not OCR guesses."""
import json
from pathlib import Path
import fitz

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/network-specialist"
OUT = ROOT / "Qualifications/network-specialist/Figures"
# Manifest coordinates use top-left origin; page numbers are 1-based PDF pages.

def main():
    manifest = json.loads((DOCS / "figure-crops.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    seen = set()
    for booklet in manifest["booklets"]:
        with fitz.open(DOCS / "evidence" / booklet["booklet"]) as doc:
            for crop in booklet["crops"]:
                name, number, box = crop["asset"], crop["page"], crop["box"]
                if name in seen or Path(name).name != name or not name.endswith(".png"):
                    raise ValueError(f"Invalid or duplicate figure name: {name}")
                if not (1 <= number <= len(doc) and 0 <= box[0] < box[2] <= 1 and 0 <= box[1] < box[3] <= 1):
                    raise ValueError(f"Invalid crop: {name}")
                seen.add(name)
                page = doc[number - 1]
                w, h = page.rect.width, page.rect.height
                clip = fitz.Rect(box[0] * w, box[1] * h, box[2] * w, box[3] * h)
                scale = booklet["scale"]
                pix = page.get_pixmap(matrix=fitz.Matrix(scale, scale), clip=clip, alpha=False)
                pix.save(OUT / name)
                print(name, pix.width, pix.height)

if __name__ == "__main__":
    main()
