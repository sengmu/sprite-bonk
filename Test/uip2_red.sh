#!/bin/bash
# UI-mobile P2 red baseline (detached on the NUC): the new
# P2 gate assertions against the UNCHANGED P1 game tree
# (scripts/world.gd sha256 685e5f47...), the two plan
# capture combos + the desktop variant. Expectation: kept
# + P1 assertions pass, the P2 ones fail (they bite).
# Hardened per P1: refuses to start while any Godot runs;
# each run is time-boxed and its log capped at 20 MB.
# The guard matches argv0 only: an unanchored -f pattern
# also matched the launching ssh session's command line
# (it carried the same string) and false-aborted the
# first P2 red launch at 17:24.
# Usage: bash Test/uip2_red.sh <tag>   (logs uip2_<tag>_*)
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
TAG=${1:-red}
DONE=Test/out/uip2_${TAG}.done
: > "$DONE"
mkdir -p .tmp; export TMPDIR="$PWD/.tmp"
GPAT='^[^ ]*/Godot_v4\.3-stable_linux'
if pgrep -f "$GPAT" > /dev/null; then
  echo "ABORT: another Godot process is running" >> "$DONE"
  pgrep -af "$GPAT" >> "$DONE"
  exit 1
fi
for v in "phone 2400x1080 1.00 0,0,0,0 a" "phone 1920x1080 1.50 48,0,0,0 b" "desktop 1280x720 1.00 0,0,0,0 d"; do
  set -- $v
  timeout 900 xvfb-run -a -s "-screen 0 ${2}x24" "$G" --path . \
    --rendering-driver opengl3 res://Test/phonehud.tscn -- \
    --mode="$1" --scale="$3" --win="$2" --inset="$4" 2>&1 \
    | head -c 20000000 > "Test/out/uip2_${TAG}_$1_$5_ubantu.log"
  echo "$1 $2 $3 $4 rc=${PIPESTATUS[0]}" >> "$DONE"
done
echo ALLDONE >> "$DONE"
