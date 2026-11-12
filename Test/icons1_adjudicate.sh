#!/bin/bash
# Icon order 1 adjudication + evidence run (NUC):
# 1) suite rerun — adjudicate the two reds from the batch run
#    (c21 passive static = documented flake family; c22 lapras
#    needs a same-tree rerun verdict).
# 2) phonehud 2400 s150 — refresh the p5 state captures (menu,
#    draft, shop, lab, result) on the icons1 tree for the
#    order's screenshot evidence.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out
export TMPDIR="$PWD/.tmp"
DONE=Test/out/icons1_adjudicate.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"
timeout 3000 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 > Test/out/icons1_suite_rerun.log 2>&1
echo "suite rerun rc=$?" >> "$DONE"
timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.50 --win=2400x1080 --inset=0,0,0,0 > Test/out/icons1_phonehud_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
echo "ALLDONE $(date -Is)" >> "$DONE"
