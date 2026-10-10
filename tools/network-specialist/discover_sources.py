#!/usr/bin/env python3
"""Discover only links actually present on IPA pages; never synthesize PDF URLs.

Downloads development evidence, not distributable app resources. Uses curl's
system trust store (Python's bundled trust store may differ on macOS).
"""
import hashlib
import json
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urljoin

import fitz

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/network-specialist"
CACHE = DOCS / "evidence"
BASE = "https://www.ipa.go.jp"


def fetch(url, path):
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["curl", "--fail", "--location", "--retry", "2", "--silent",
                        "--show-error", url, "--output", str(path)], check=True)
    return path.read_bytes()


def discover(year):
    era = f"r{year - 2018:02d}" if year >= 2020 else f"h{year - 1988:02d}"
    url = f"{BASE}/shiken/mondai-kaiotu/{year}{era}.html"
    html = fetch(url, CACHE / f"{year}.html").decode("utf-8")
    links = list(dict.fromkeys(urljoin(url, href) for href in
                 re.findall(r'href="([^"]+)"', html) if re.search(r'nw.*\.pdf$', href, re.I)))
    rows = []
    for link in links:
        filename = link.rsplit("/", 1)[-1]
        if not re.search(r'nw_am2_(?:qs|ans)', filename, re.I):
            continue
        data = fetch(link, CACHE / filename)
        doc = fitz.open(stream=data, filetype="pdf")
        text = "\n".join(page.get_text() for page in doc)
        (CACHE / (filename + ".txt")).write_text(text)
        rows.append({"url": link, "file": filename, "sha256": hashlib.sha256(data).hexdigest(),
                     "pages": len(doc), "role": "questions" if "_qs" in filename else "answers",
                     "questionNumbers": sorted(set(map(int, re.findall(r'問\s*(\d+)', text))))})
    return {"year": year, "pageURL": url, "documents": rows,
            "status": "requires-booklet-review" if rows else "no-nw-am2-links"}


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        years = list(pool.map(discover, range(2009, 2026)))
    (DOCS / "sources.json").write_text(json.dumps({"checkedOn": "2026-10-08", "years": years},
                                                 ensure_ascii=False, indent=2) + "\n")
    for row in years:
        print(row["year"], [(d["file"], len(d["questionNumbers"])) for d in row["documents"]])


if __name__ == "__main__":
    main()
