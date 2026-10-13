#!/usr/bin/env python3
"""Acquire AP documents linked by IPA, preserving originals and SHA-256 provenance."""
import hashlib
import json
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from zoneinfo import ZoneInfo
from pathlib import Path
from urllib.parse import urljoin, urlparse

import fitz

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/applied-information"
CACHE = DOCS / "evidence"
BASE = "https://www.ipa.go.jp"


def fetch(url, output):
    if urlparse(url).hostname != "www.ipa.go.jp":
        raise ValueError("Only official IPA resources are allowed")
    output.parent.mkdir(parents=True, exist_ok=True)
    if not output.exists():
        partial = output.with_suffix(output.suffix + ".part")
        subprocess.run(["curl", "--fail", "--location", "--retry", "2", "--max-time", "120",
                        "--silent", "--show-error", url, "--output", str(partial)], check=True)
        partial.rename(output)
    return output.read_bytes()


def discover(page_url):
    year = int(re.search(r"/(\d{4})", page_url)[1])
    html = fetch(page_url, CACHE / f"{year}.html").decode("utf-8")
    links = list(dict.fromkeys(urljoin(page_url, href) for href in re.findall(r'href="([^"]+)"', html)
                              if re.search(r"_ap_am_(?:qs|ans)\.pdf$", href, re.I)))
    documents = []
    for url in links:
        filename = url.rsplit("/", 1)[-1]
        data = fetch(url, CACHE / filename)
        if not data.startswith(b"%PDF"):
            raise ValueError(f"Not a PDF: {url}")
        pdf = fitz.open(stream=data, filetype="pdf")
        text = "\n".join(page.get_text() for page in pdf)
        (CACHE / (filename + ".txt")).write_text(text)
        match = re.search(r"^\d{4}(?:h\d+|r\d+)(tokubetsu|[hao])_ap_(am|pm)_(qs|ans|cmnt)", filename)
        if not match:
            raise ValueError(f"Unexpected official filename: {filename}")
        documents.append({"url": url, "file": filename, "sha256": hashlib.sha256(data).hexdigest(),
                          "bytes": len(data), "pages": len(pdf),
                          "administration": {"h": "spring", "a": "autumn", "o": "autumn", "tokubetsu": "special"}[match[1]],
                          "section": "A" if match[2] == "am" else "B", "role": match[3]})
    return {"year": year, "pageURL": page_url, "documents": documents}


def main():
    index_url = BASE + "/shiken/mondai-kaiotu/index.html"
    index = fetch(index_url, CACHE / "index.html").decode("utf-8")
    pages = sorted(set(urljoin(index_url, href) for href in re.findall(r'href="([^"]+)"', index)
                       if re.search(r"/(?:20\d{2})(?:h\d+|r\d+)\.html$", href)))
    with ThreadPoolExecutor(max_workers=4) as pool:
        years = list(pool.map(discover, pages))
    result = {"checkedOn": datetime.now(ZoneInfo("Asia/Tokyo")).date().isoformat(), "indexURL": index_url, "years": years}
    (DOCS / "sources.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    for year in years:
        print(year["year"], len(year["documents"]), "official AP documents", flush=True)
    print("Total", sum(len(row["documents"]) for row in years), flush=True)


if __name__ == "__main__":
    main()
