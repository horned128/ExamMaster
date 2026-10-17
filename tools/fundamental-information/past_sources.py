#!/usr/bin/env python3
"""Download IPA FE public A/B exam booklets and official answer keys."""
from datetime import date
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin
import hashlib
import json
import subprocess
import re

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/fundamental-information"
ORIGINALS = DOCS / "originals"
BASE = "https://www.ipa.go.jp"
YEARS = {
    2026: "2026r08",
    2025: "2025r07",
    2024: "2024r06",
    2023: "2023r05",
}


class PDFLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        href = attrs.get("href", "")
        if tag == "a" and "_fe_kamoku_" in href and href.endswith(".pdf"):
            self.links.append(urljoin(BASE, href))


def fetch(url, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    if not output.exists():
        partial = output.with_suffix(output.suffix + ".part")
        subprocess.run(["curl", "--fail", "--location", "--retry", "2", "--max-time", "120",
                        "--silent", "--show-error", url, "--output", str(partial)], check=True)
        partial.replace(output)
    data = output.read_bytes()
    if not data.startswith(b"%PDF"):
        raise ValueError(f"Not a PDF: {url}")
    return data


def main():
    years = []
    for year, slug in YEARS.items():
        page_url = f"{BASE}/shiken/mondai-kaiotu/sg_fe/koukai/{slug}.html"
        html_path = DOCS / "originals" / f"{slug}.html"
        subprocess.run(["curl", "--fail", "--location", "--retry", "2", "--max-time", "120",
                        "--silent", "--show-error", page_url, "--output", str(html_path)], check=True)
        parser = PDFLinks()
        parser.feed(html_path.read_text(encoding="utf-8"))
        wanted = {f"{slug}_fe_kamoku_{subject}_{kind}.pdf"
                  for subject in "ab" for kind in ("qs", "ans")}
        links = {url.rsplit("/", 1)[-1]: url for url in parser.links}
        if set(links) != wanted:
            raise ValueError(f"{year}: expected {sorted(wanted)}, found {sorted(links)}")
        documents = []
        for filename in sorted(wanted):
            url = links[filename]
            data = fetch(url, ORIGINALS / filename)
            documents.append({"file": filename, "url": url, "sha256": hashlib.sha256(data).hexdigest(),
                              "bytes": len(data), "subject": "科目A" if "_a_" in filename else "科目B",
                              "role": "question-booklet" if filename.endswith("_qs.pdf") else "answer-key"})
        official_answers = {}
        for subject in "ab":
            answer_text = (ORIGINALS / f"{slug}_fe_kamoku_{subject}_ans.txt").read_text(encoding="utf-8")
            pairs = [(int(number.translate(str.maketrans("０１２３４５６７８９", "0123456789"))), kana)
                     for number, kana in re.findall(r"問\s*([0-9０-９]+)\s*([アイウエオカキクケコ])", answer_text)]
            pairs.sort()
            expected = 20 if subject == "a" else 6
            if len(pairs) != expected or [n for n, _ in pairs] != list(range(1, expected + 1)):
                raise ValueError(f"{year} {subject}: official answer key has {len(pairs)} entries: {pairs}")
            official_answers["科目A" if subject == "a" else "科目B"] = [kana for _, kana in pairs]
        years.append({"year": year, "pageURL": page_url, "documents": documents,
                      "publishedQuestions": {"科目A": 20, "科目B": 6},
                      "officialAnswerKeys": official_answers})
    manifest = {"checkedOn": date.today().isoformat(),
                "indexURL": f"{BASE}/shiken/mondai-kaiotu/sg_fe/koukai/index.html",
                "usage": "IPA states its public exam questions may be used without permission or fee, subject to its stated usage notes.",
                "years": years}
    target = DOCS / "sources.json"
    target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Downloaded {sum(len(y['documents']) for y in years)} PDFs for {len(years)} years")


if __name__ == "__main__":
    main()
