#!/bin/bash
# UI-mobile P2 iteration runs (NUC, detached): a corner
# subset of the phonehud matrix on the current tree, same
# hardening as uip2_red.sh (argv0-anchored Godot guard,
# 900 s / 20 MB caps). Not the gate — uip2_batch.sh is.
# Usage: bash Test/uip2_iter.sh <tag>   (logs uip2_<tag>_*)
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
TAG=${1:-it}
DONE=Test/out/uip2_${TAG}.done
: > "$DONE"
mkdir -p .tmp; export TMPDIR="$PWD/.tmp"
GPAT='^[^ ]*/Godot_v4\.3-stable_linux'
if pgrep -f "$GPAT" > /dev/null; then
  echo "ABORT: another Godot process is running" >> "$DONE"
  exit 1
fi
for v in "phone 1920x1080 1.50 48,0,0,0 b" "phone 2400x1080 1.50 0,0,0,0 e" \
    "phone 2340x1080 0.70 0,0,48,0 f" "phone 1920x1080 0.85 0,0,0,0 g" \
    "phone 2400x1080 1.00 0,0,0,0 a" "desktop 1280x720 1.00 0,0,0,0 d"; do
  set -- $v
  timeout 900 xvfb-run -a -s "-screen 0 ${2}x24" "$G" --path . \
    --rendering-driver opengl3 res://Test/phonehud.tscn -- \
    --mode="$1" --scale="$3" --win="$2" --inset="$4" 2>&1 \
    | head -c 20000000 > "Test/out/uip2_${TAG}_$1_$5_ubantu.log"
  echo "$1 $2 $3 $4 rc=${PIPESTATUS[0]}" >> "$DONE"
done
echo ALLDONE >> "$DONE"
