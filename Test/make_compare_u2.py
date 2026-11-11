#!/usr/bin/env python3
"""Build design/ui-reference/compare/U2.png: v2 reference on top, fresh
phonehud 2340 s150 menu shot below, each with a dark label bar.
Usage: make_compare_u2.py <shot-png> [shot-label]"""
import sys
from PIL import Image, ImageDraw, ImageFont

W = 1648
BAR = 29
BAR_COLOR = (26, 16, 48)
REF = "design/ui-reference/v2/U2_final.jpg"
OUT = "design/ui-reference/compare/U2.png"

shot_path = sys.argv[1]
shot_label = sys.argv[2] if len(sys.argv) > 2 else "SHOT phonehud 2340x1080 s150 menu (u2_recheck)"

ref = Image.open(REF).convert("RGB")
shot = Image.open(shot_path).convert("RGB")
rh = round(ref.height * W / ref.width)
sh = round(shot.height * W / shot.width)
canvas = Image.new("RGB", (W, BAR + rh + BAR + sh), BAR_COLOR)
d = ImageDraw.Draw(canvas)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
except OSError:
    font = ImageFont.load_default()
d.text((8, 4), "REF " + REF, fill=(255, 255, 255), font=font)
canvas.paste(ref.resize((W, rh)), (0, BAR))
d.text((8, BAR + rh + 4), shot_label, fill=(255, 255, 255), font=font)
canvas.paste(shot.resize((W, sh)), (0, BAR + rh + BAR))
canvas.save(OUT)
print("wrote", OUT, canvas.size)
