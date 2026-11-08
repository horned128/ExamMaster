#!/usr/bin/env python3
"""Build an expansion inventory from a saved official past-paper index HTML."""
import argparse
import json
import pathlib
import re
from html.parser import HTMLParser
from urllib.parse import urljoin

BASE = "https://www.shiken.or.jp/chief/third/qa/"
ROOT = pathlib.Path(__file__).resolve().parents[2]

class Index(HTMLParser):
    def __init__(self):
        super().__init__()
        self.date = None
        self.tag = None
        self.href = None
        self.buffer = []
        self.entries = []
    def handle_starttag(self, tag, attrs):
        if tag in ["h3", "a"]:
            self.tag = tag
            self.href = dict(attrs).get("href")
            self.buffer = []
    def handle_data(self, data):
        if self.tag: self.buffer.append(data)
    def handle_endtag(self, tag):
        if tag != self.tag: return
        text = "".join(self.buffer).strip()
        if tag == "h3" and re.search(r"\d{4}年\d+月\d+日", text):
            self.date = text
        elif tag == "a" and self.href and self.href.endswith(".pdf") and "第三種電気主任技術者" in text and self.date:
            self.entries.append({"examDate": self.date, "title": text, "url": urljoin(BASE, self.href),
                                 "included": "20260830_ch_third_" in self.href})
        self.tag = None

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("html", type=pathlib.Path)
    args = parser.parse_args()
    index = Index()
    index.feed(args.html.read_text())
    assert len(index.entries) >= 5 and len({r["url"] for r in index.entries}) == len(index.entries)
    out = ROOT / "docs/denken3/source-inventory.json"
    out.write_text(json.dumps({"checkedAt": "2026-10-17", "indexURL": BASE, "entries": index.entries}, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(index.entries)} official PDFs in {len(set(r['examDate'] for r in index.entries))} exam administrations")
