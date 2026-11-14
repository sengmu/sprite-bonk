#!/bin/bash
# U3 fix1 batch: verify the ①–④ fixes (banner star/leaf clusters, solid
# card-top pills, featured gold rim+glow, tool row order/colors).
# Leg 1: 2400 s100. Leg 2: 2340 s100 (capture combo snapshots the draft).
# Expect 1564/0 (or 1549/0, full-segment count floats) each leg; then measure
# draft cards in phone_hud_touch_*_draft.png vs U3 reference.
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
G=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
DONE=Test/out/u3_fix1.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"
timeout 1500 xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 > Test/out/u3_fix1_phonehud_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u3_fix1_phonehud_2400.log >> "$DONE" 2>/dev/null
timeout 1500 xvfb-run -a -s "-screen 0 2340x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2340x1080 --inset=0,0,0,0 > Test/out/u3_fix1_phonehud_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u3_fix1_phonehud_2340.log >> "$DONE" 2>/dev/null
echo "ALLDONE $(date -Is)" >> "$DONE"
