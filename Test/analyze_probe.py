#!/usr/bin/env python3
"""Fitted-probe verification for every species in ModelRig.SPECIES.

Reads Test/out/probe_<sp>_all.png / _none.png (close-camera probe
shots, anchor (640, 481.6903), 174.9253 px per unit) and reports the
rendered height vs the species' cfg height plus the grounding
offset. A species is OK when its height ratio is within ±15% and
its silhouette bottom sits within 0.12 u of its hover height.
Usage: python3 Test/analyze_probe.py [species ...]
"""
import re
import sys
from collections import deque

import numpy as np
from PIL import Image

AX, AY, PPU = 640.0, 481.6903, 174.925349308894
BASE = "Test/out/"
tab = {}
for ln in open("scripts/model_rig.gd"):
    m = re.match(r'\t"([a-z0-9-]+)": \{"path".*"height": ([0-9.]+)', ln)
    if m:
        hov = re.search(r'"hover": ([0-9.]+)', ln)
        tab[m.group(1)] = (float(m.group(2)), float(hov.group(1)) if hov else 0.0)


def measure(sp):
    a = np.asarray(Image.open(BASE + f"probe_{sp}_all.png").convert("RGB")).astype(int)
    b = np.asarray(Image.open(BASE + f"probe_{sp}_none.png").convert("RGB")).astype(int)
    diff = np.abs(a - b).sum(axis=2)
    mask = diff > 24
    h, w = mask.shape
    x0, x1, y0, y1 = 400, 810, 0, h
    win = mask[y0:y1, x0:x1]
    seen = np.zeros(win.shape, dtype=bool)
    best = []
    Hh, Ww = win.shape
    for sy in range(Hh):
        for sx in range(Ww):
            if win[sy, sx] and not seen[sy, sx]:
                q = deque([(sy, sx)])
                seen[sy, sx] = True
                comp = []
                while q:
                    cy, cx = q.popleft()
                    comp.append((cy, cx))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < Hh and 0 <= nx < Ww and win[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
                if len(comp) > len(best):
                    best = comp
    if len(best) < 30:
        return f"{sp}: NO SILHOUETTE"
    ys = np.array([c[0] for c in best])
    world_h = (ys.max() - ys.min() + 1) / PPU
    ground = (AY - ys.max()) / PPU
    cfg, hover = tab[sp]
    ratio = world_h / cfg
    flag = "OK " if 0.85 <= ratio <= 1.15 else "BAD"
    gflag = "OK " if abs(ground - hover) <= 0.12 else "BAD"
    return (f"{sp}: h={world_h:.3f} cfg={cfg} ratio={ratio:.3f} [{flag}] "
            f"ground={ground:+.3f} hover={hover} [{gflag}] npix={len(best)}")


names = sys.argv[1:] or list(tab)
bad = 0
for sp in names:
    line = measure(sp)
    print(line)
    if "BAD" in line or "NO SILHOUETTE" in line:
        bad += 1
print(f"probe check: {len(names) - bad}/{len(names)} OK")
sys.exit(1 if bad else 0)
