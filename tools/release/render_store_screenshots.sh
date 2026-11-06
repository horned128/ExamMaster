#!/bin/zsh
# Render docs/<app>/app-store-assets/index.html into png/<w>x<h>/NN.png with Chrome headless.
# Usage: tools/release/render_store_screenshots.sh docs/<app>/app-store-assets
set -euo pipefail
dir=${1:?app-store-assets directory}
chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
count=$(grep -o 'class="shot' "$dir/index.html" | wc -l | tr -d ' ')
for size in 1320x2868 1206x2622; do
  out="$dir/png/$size"; rm -rf "$out"; mkdir -p "$out"
  for i in $(seq 1 "$count"); do
    "$chrome" --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size="${size/x/,}" \
      --virtual-time-budget=3000 --screenshot="$out/$(printf %02d "$i").png" "file://$PWD/$dir/index.html#p$i" >/dev/null 2>&1
  done
  python3 - "$out" "$size" <<'PY'
import sys, glob
from PIL import Image
w, h = map(int, sys.argv[2].split("x"))
for p in sorted(glob.glob(sys.argv[1] + "/*.png")):
    im = Image.open(p)
    assert im.size == (w, h), (p, im.size)
    if im.mode != "RGB": im.convert("RGB").save(p)  # App Store rejects alpha
print(sys.argv[1], "ok")
PY
done
