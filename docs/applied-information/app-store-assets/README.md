# App Store screenshots — ピヨトレ！応用情報技術者

Six Japanese portrait marketing screenshots, each exported at 1320 × 2868 px for the large iPhone display class. Apple currently accepts this portrait resolution for large Dynamic Island iPhones; Apple also documents a required medium-display screenshot class for submission. The set uses the large-display size already used by this app's screenshot assets. Checked against Apple's official screenshot specification on 2026-10-14: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/.

## Files

- `png/1320x2868/01.png` through `06.png`: final upload-ready PNGs.
- `contact-sheet.png`: overview of all six panels.
- `index.html` and `styles.css`: editable composition.
- `render.py`: deterministic PNG/contact-sheet renderer that reads the copy and image references from the HTML and the layout/color tokens from the CSS.
- `assets/source/`: exact copies of the genuine app screenshots used as immutable image assets.
- `storyboard.md`: copy, panel order, source mapping, and claim basis.
- `design-direction.md`: UI/UX Pro Max direction and critique note.
- `quality-report.md`: dimensions, pixel-fidelity, text, and visual QA.

## Re-render

The HTML uses relative image paths. Rebuild the PNGs and contact sheet from this directory with Pillow installed:

```sh
python3 docs/applied-information/app-store-assets/render.py
```

The renderer writes `01.png` … `06.png` in storyboard order. Its typography uses the macOS Hiragino Sans system font; adjust `FONT_REGULAR` and `FONT_BOLD` in `render.py` on another operating system.
