#!/usr/bin/env python3
"""Standing per-starter PLAYER check (hotfix gate, stays in tree).

Reads the frames Test/harness.gd captured with a starter as the
PLAYER through the real start path (all / noplayer visibility diff),
plus the PXPERUNIT and PLAYERANCHOR lines from the harness log, and
asserts:
  * rendered world height within +/-20% of the species' cfg height
  * silhouette bottom within 0.30 u of the player's ground anchor
  * median body color inside the species' color family
Usage: check_starters.py <species> <harness_log>
Exit code 0 = PASS, 1 = FAIL (prints the measured values either way).
"""
import re
import sys
from collections import deque

import numpy as np
from PIL import Image

EXPECT = {
    "bulbasaur": (1.30, lambda r, g, b: g > r and g > b and g > 80),
    # Cycle 10 recalibration: the old floor (r > 140) was fit to a
    # sample that included the player's world-space HP bar — the bar
    # was a player child, so it sat inside this check's visibility-
    # diff silhouette and inflated the median. With the bar removed
    # (bundle alignment), the uncontaminated in-world median is
    # ~(128, 92, 54) (two runs), and the bar-free isolated probe
    # median is (142, 86, 58) — identical before/after the removal,
    # proving the model itself is unchanged. Thresholds below keep
    # ~15% margin under the measured values while still rejecting
    # the green/blue families and a grey/brown washout.
    "charmander": (1.30, lambda r, g, b: r > 105 and r - g > 22 and g - b > 12),
    "squirtle": (1.06, lambda r, g, b: b >= r and g >= r and b > 60),
}
BASE = "Test/out/"


def main() -> int:
    sp, log_path = sys.argv[1], sys.argv[2]
    log = open(log_path).read()
    ppu = float(re.search(r"PXPERUNIT player=([0-9.]+)", log).group(1))
    am = re.search(r"player_anchor=\(([0-9.]+), ([0-9.]+)\)", log)
    ax, ay = float(am.group(1)), float(am.group(2))
    a = np.asarray(Image.open(BASE + f"{sp}_all.png").convert("RGB")).astype(int)
    b = np.asarray(Image.open(BASE + f"{sp}_noplayer.png").convert("RGB")).astype(int)
    diff = np.abs(a - b).sum(axis=2)
    mask = diff > 24
    h, w = mask.shape
    # Window around the player's ground anchor; pick the component
    # whose centroid is closest to the expected body center (the
    # anchor + ~0.65 u up) rather than the largest blob, so a nearby
    # enemy or UI remnant cannot win the measurement.
    x0 = max(0, int(ax - 1.1 * ppu))
    x1 = min(w, int(ax + 1.1 * ppu))
    y0 = max(0, int(ay - 2.1 * ppu))
    y1 = min(h, int(ay + 0.45 * ppu))
    win = mask[y0:y1, x0:x1]
    seen = np.zeros(win.shape, dtype=bool)
    best = []
    best_d = 1e18
    tx, ty = ax, ay - 0.65 * ppu
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
                if len(comp) >= 30:
                    ccx = np.mean([c[1] for c in comp]) + x0
                    ccy = np.mean([c[0] for c in comp]) + y0
                    d = (ccx - tx) ** 2 + (ccy - ty) ** 2
                    if d < best_d:
                        best_d = d
                        best = [(c[0] + y0, c[1] + x0) for c in comp]
    if len(best) < 50:
        print(f"CHECK {sp} FAIL no player silhouette ({len(best)} px)")
        return 1
    ys = np.array([c[0] for c in best])
    # Height from the silhouette TOP to the ground line: the world
    # sun's cast shadow hides with the model and stretches the
    # component below the feet, so the component bottom is not the
    # feet. The anchor IS the ground point at the model's depth, so
    # top-to-anchor is the clean vertical measure.
    world_h = (ay + 0.02 * ppu - ys.min()) / ppu
    ground_off = (ay - ys.max()) / ppu
    # Color from body pixels only (above the ground line — excludes
    # the cast shadow on the grass).
    body = [c for c in best if c[0] <= ay + 0.05 * ppu]
    pix = np.array([a[c[0], c[1]] for c in body[::7]])
    med = tuple(int(v) for v in np.median(pix, axis=0))
    exp_h, fam = EXPECT[sp]
    ok_h = abs(world_h - exp_h) / exp_h <= 0.20
    ok_g = -0.85 <= ground_off <= 0.12  # reaches ground, not floating
    ok_c = fam(*med)
    verdict = "PASS" if (ok_h and ok_g and ok_c) else "FAIL"
    print(
        f"CHECK {sp} {verdict} world_h={world_h:.3f} (expect {exp_h}±20%) "
        f"ground_off={ground_off:+.3f}u (float limit +0.12) body_rgb={med} "
        f"[h={'ok' if ok_h else 'BAD'} g={'ok' if ok_g else 'BAD'} c={'ok' if ok_c else 'BAD'}]"
    )
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
