"""Joins simulator captures into one contact sheet, each scaled to the phone's points (360 wide) and labeled.

    python3 hoja.py out.png a-1.png b-1.png ...
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

WIDTH = 360
GAP = 12
LABEL = 26
COLS = 4

out, paths = sys.argv[1], sys.argv[2:]
shots = []
for p in paths:
    im = Image.open(p).convert("RGB")
    shots.append((os.path.basename(p)[:-4], im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS)))

h = max(im.height for _, im in shots)
cols = min(COLS, len(shots))
rows = (len(shots) + cols - 1) // cols
sheet = Image.new("RGB", (cols * WIDTH + (cols + 1) * GAP, rows * (h + LABEL) + (rows + 1) * GAP), "white")
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 18)
except OSError:
    font = ImageFont.load_default()
for i, (name, im) in enumerate(shots):
    x = GAP + (i % cols) * (WIDTH + GAP)
    y = GAP + (i // cols) * (h + LABEL + GAP)
    draw.text((x, y), name, fill="black", font=font)
    sheet.paste(im, (x, y + LABEL))
sheet.save(out)
