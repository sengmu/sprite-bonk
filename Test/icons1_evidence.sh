#!/bin/bash
# Icon order 1 evidence pass (NUC): phonehud 2400 @ scale 1.00 —
# the s100 tag is what makes the harness write the p5 state
# captures (menu/draft/shop/lab/result) the order's screenshot
# evidence needs. The s150 passes already verified green.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out
export TMPDIR="$PWD/.tmp"
DONE=Test/out/icons1_evidence.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"
timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 > Test/out/icons1_phonehud_s100.log 2>&1
echo "phonehud s100 rc=$?" >> "$DONE"
echo "ALLDONE $(date -Is)" >> "$DONE"
