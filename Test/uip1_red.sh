#!/bin/bash
# UI-mobile P1 red baseline (detached on the NUC): the new
# P1 gate assertions against the UNCHANGED C22 game tree
# (scripts/world.gd sha256 db0f8748...), one phone combo +
# the desktop variant. Expectation: the kept assertions
# pass, the P1 ones fail (they bite).
# Usage: bash Test/uip1_red.sh <tag>   (logs uip1_<tag>_*)
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
TAG=${1:-red}
DONE=Test/out/uip1_${TAG}.done
: > "$DONE"
mkdir -p .tmp; export TMPDIR="$PWD/.tmp"
for v in "phone 2400x1080" "desktop 1280x720"; do
  set -- $v
  timeout 900 xvfb-run -a -s "-screen 0 ${2}x24" "$G" --path . \
    --rendering-driver opengl3 res://Test/phonehud.tscn -- \
    --mode="$1" --scale=1.00 --win="$2" --inset=0,0,0,0 \
    > "Test/out/uip1_${TAG}_$1_ubantu.log" 2>&1
  echo "$1 rc=$?" >> "$DONE"
done
echo ALLDONE >> "$DONE"
