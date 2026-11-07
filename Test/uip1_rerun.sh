#!/bin/bash
# UI-mobile P1 closing re-run (NUC, detached via setsid):
# the phonehud full matrix on the final gate file (the
# desktop-inversion harness fix landed after uip1_batch's
# matrix) -> full suite pass 2 (uip1_batch's pass had two
# C21-passive fixture reds). Game scripts are unchanged
# since uip1_batch's purge + import, so no re-import.
# Logs: uip1r2_* ; step RCs in Test/out/uip1_rerun.done.
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out; export TMPDIR="$PWD/.tmp"
DONE=Test/out/uip1_rerun.done
: > "$DONE"
echo "start $(date -Is)" >> "$DONE"
if pgrep -f "Godot_v4.3-stable_linux" > /dev/null; then
  echo "ABORT: another Godot process is running" >> "$DONE"
  exit 1
fi
rm -f Test/out/phonehud_touch_*_ubantu.log Test/out/phonehud_desktop_ubantu_*.log
bash Test/check_phonehud.sh > Test/out/uip1r2_matrix_ubantu.log 2>&1
echo "matrix rc=$?" >> "$DONE"
for f in Test/out/phonehud_touch_*_ubantu.log Test/out/phonehud_desktop_ubantu_*.log; do
  [ -f "$f" ] && cp "$f" "Test/out/uip1r2_$(basename "$f")"
done
timeout 2400 xvfb-run -a -s "-screen 0 2400x1080x24" "$G" \
  --path . --rendering-driver opengl3 res://Test/harness.tscn \
  -- --mode=cycle9 > Test/out/uip1r2_suite_ubantu.log 2>&1
echo "suite rc=$?" >> "$DONE"
echo "ALLDONE $(date -Is)" >> "$DONE"
