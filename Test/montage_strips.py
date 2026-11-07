#!/usr/bin/env python3
"""Montage gait strip frames into one contact sheet per species:
rows = before/after, columns = sequence frames (center-cropped on
the subject, downscaled). Usage: python3 Test/montage_strips.py rattata"""
import glob
import sys

from PIL import Image

sp = sys.argv[1]
rows = []
for tag in ["before", "after"]:
    frames = []
    for path in sorted(glob.glob(f"Test/out/strip_{sp}_{tag}_*.png"))[:16]:
        im = Image.open(path).convert("RGB")
        w, h = im.size
        crop = im.crop((w // 2 - 190, h // 2 - 170, w // 2 + 190, h // 2 + 130))
        frames.append(crop.resize((190, 150)))
    if frames:
        row = Image.new("RGB", (190 * len(frames), 150))
        for j, f in enumerate(frames):
            row.paste(f, (j * 190, 0))
        rows.append(row)
if not rows:
    print("no frames for", sp)
    sys.exit(1)
out = Image.new("RGB", (rows[0].width, 150 * len(rows)))
for j, r in enumerate(rows):
    out.paste(r, (0, j * 150))
out.save(f"Test/out/strip_{sp}_montage.png")
print("wrote Test/out/strip_%s_montage.png" % sp)
