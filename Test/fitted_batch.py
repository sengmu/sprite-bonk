#!/usr/bin/env python3
import subprocess, sys
GODOT = "/home/hatch/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
ROOT = "/home/hatch/workspace/sprite-bonk-3d"
for sp in sys.argv[1:]:
    r = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", GODOT,
        "--path", ".", "--rendering-driver", "opengl3",
        "res://Test/probe.tscn", "--", f"--species={sp}", "--mode=fitted"],
        cwd=ROOT, capture_output=True, text=True, timeout=420)
    ok = "PROBE DONE" in r.stdout
    a = subprocess.run(["python3", "Test/analyze_probe.py", sp],
        cwd=ROOT, capture_output=True, text=True)
    print(f"FITTED {sp}: probe={'OK' if ok else 'FAIL'} analyze={a.stdout.strip().splitlines()[-1] if a.stdout.strip() else a.stderr.strip()[:120]}")
