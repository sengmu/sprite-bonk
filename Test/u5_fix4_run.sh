#!/bin/bash
# U5 fix2 batch: verify the single-column victory result (stars x3,
# ribbon, one-line summary, four rows + payout pill always visible,
# centred icon buttons, HUD hidden) at both phone tiers.
# Runs with --result=victory so the captures match the v2 victory
# reference; the default defeat path is unchanged (see s100 runs).
# Leg 1: 2400 s100. Leg 2: 2340 s100. Expect FAIL=0 each leg; then
# compare the victory captures vs U5 reference.
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
G=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
DONE=Test/out/u5_fix4.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"
timeout 1500 xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 --result=victory > Test/out/u5_fix4_phonehud_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u5_fix4_phonehud_2400.log >> "$DONE" 2>/dev/null
timeout 1500 xvfb-run -a -s "-screen 0 2340x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2340x1080 --inset=0,0,0,0 --result=victory > Test/out/u5_fix4_phonehud_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u5_fix4_phonehud_2340.log >> "$DONE" 2>/dev/null
echo "ALLDONE $(date -Is)" >> "$DONE"
