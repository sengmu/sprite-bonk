#!/usr/bin/env python3
"""Native (scale-1) render measurement for species GLBs.

For each species: runs Test/probe.tscn in native mode, diffs the
model shot against the model-hidden shot, and derives:
  native = rendered height in world units at scale 1
  feet   = world y of the model's lowest point (origin-relative)
Usage: python3 Test/native_probe2.py sp1 sp2 ...
Prints one RESULT line per species.
"""
import re
import subprocess
import sys

from PIL import Image

GODOT = "/home/hatch/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
ROOT = "/home/hatch/workspace/sprite-bonk-3d"


def measure(sp: str):
    r = subprocess.run(
        ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", GODOT,
         "--path", ".", "--rendering-driver", "opengl3",
         "res://Test/probe.tscn", "--", f"--species={sp}", "--mode=native"],
        cwd=ROOT, capture_output=True, text=True, timeout=420)
    m = re.search(r"PXPERUNIT probe=([\d.]+) anchor=\(([\d.]+), ([\d.]+)\)", r.stdout)
    if not m:
        print(f"RESULT {sp}: NO-PXPERUNIT (rc={r.returncode})")
        return
    ppu, _ax, ay = float(m.group(1)), float(m.group(2)), float(m.group(3))
    a = Image.open(f"{ROOT}/Test/out/probe_{sp}_native_all.png").convert("RGB")
    b = Image.open(f"{ROOT}/Test/out/probe_{sp}_native_none.png").convert("RGB")
    w, h = a.size
    pa, pb = a.load(), b.load()
    rows = {}
    for y in range(h):
        cnt = 0
        for x in range(w):
            p1, p2 = pa[x, y], pb[x, y]
            if abs(p1[0] - p2[0]) + abs(p1[1] - p2[1]) + abs(p1[2] - p2[2]) > 36:
                cnt += 1
        if cnt >= 3:
            rows[y] = cnt
    if not rows:
        print(f"RESULT {sp}: NO-MODEL-PIXELS")
        return
    top, bot = min(rows), max(rows)
    native = (bot - top) / ppu
    feet = (ay - bot) / ppu
    print(f"RESULT {sp}: native={native:.4f} feet={feet:.4f} ppu={ppu:.1f} rows={top}..{bot} anchor_y={ay:.1f}")


if __name__ == "__main__":
    for sp in sys.argv[1:]:
        measure(sp)
