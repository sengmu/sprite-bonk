#!/bin/bash
# U1 1:1 round 15 (coordinator): phonehud-only re-verification.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out
export TMPDIR="$PWD/.tmp"
DONE=Test/out/u1_fix15_run.done
: > "$DONE"
for f in scripts/world.gd Test/phonehud.gd; do
  timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/u1_fix15_check_$(basename "$f" .gd).log" 2>&1
  rc=$?; echo "check $f rc=$rc" >> "$DONE"
  [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
done
timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 2340x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.50 --win=2340x1080 --inset=0,0,0,0 > Test/out/u1_fix15_phonehud_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.50 --win=2400x1080 --inset=0,0,0,0 > Test/out/u1_fix15_phonehud_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
echo "ALLDONE $(date -Is)" >> "$DONE"
