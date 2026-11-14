#!/usr/bin/env python3
"""Build design/ui-reference/compare/U5.png: v2 reference on the left,
phonehud victory result shot on the right, preserving both aspect ratios.
Usage: make_compare_u5.py <shot-png> [shot-label] [output-png]"""
import sys
from PIL import Image, ImageDraw, ImageFont

W = 1400
BAR = 29
BAR_COLOR = (26, 16, 48)
REF = "design/ui-reference/v2/U5_final.jpg"
OUT = sys.argv[3] if len(sys.argv) > 3 else "design/ui-reference/compare/U5.png"

shot_path = sys.argv[1]
shot_label = sys.argv[2] if len(sys.argv) > 2 else "SHOT phonehud 2400x1080 s100 result_victory (u5_fix1)"

ref = Image.open(REF).convert("RGB")
shot = Image.open(shot_path).convert("RGB")
rh = round(ref.height * W / ref.width)
sh = round(shot.height * W / shot.width)
canvas = Image.new("RGB", (2 * W, BAR + max(rh, sh)), BAR_COLOR)
d = ImageDraw.Draw(canvas)
font = ImageFont.load_default()
for font_path in ["C:/Windows/Fonts/arial.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
    try:
        font = ImageFont.truetype(font_path, 20)
        break
    except OSError:
        continue
d.text((8, 4), "REF " + REF, fill=(255, 255, 255), font=font)
canvas.paste(ref.resize((W, rh)), (0, BAR))
d.text((W + 8, 4), shot_label, fill=(255, 255, 255), font=font)
canvas.paste(shot.resize((W, sh)), (W, BAR))
canvas.save(OUT)
print("wrote", OUT, canvas.size)
