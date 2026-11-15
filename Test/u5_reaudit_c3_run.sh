#!/bin/bash
# U5 re-audit Codex round 3 batch: verify the round-3 fixes
# (content shift up, row/payout/action typography, double-arc
# refresh glyph, home icon, 64 px tiles) landed in
# scripts/world.gd + scripts/ui_icon.gd by the Codex pool against
# the round-1 verdict list. Legs: 2400 s100 then 2340 s100, FAIL=0
# each; then compare the victory captures vs U5 reference.
# Precondition (verified before start): the ribbon .ctex sidecar
# records source_md5 d20f98ff (fix12 texture) and the tree is at the
# round-3 commit.
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
G=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
DONE=Test/out/u5_reaudit_c3.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"
timeout 1500 xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 --result=victory > Test/out/u5_reaudit_c3_phonehud_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u5_reaudit_c3_phonehud_2400.log >> "$DONE" 2>/dev/null
timeout 1500 xvfb-run -a -s "-screen 0 2340x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2340x1080 --inset=0,0,0,0 --result=victory > Test/out/u5_reaudit_c3_phonehud_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u5_reaudit_c3_phonehud_2340.log >> "$DONE" 2>/dev/null
echo "ALLDONE $(date -Is)" >> "$DONE"
