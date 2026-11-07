#!/bin/bash
# UI-mobile P1 verification batch (NUC, detached via
# setsid): .godot purge + reimport -> phonehud full matrix
# -> full suite -> bootsmoke. No APK in this phase.
# Step RCs land in Test/out/uip1_batch.done as they
# complete; per-variant gate logs are copied to uip1_-
# prefixed names for the pull.
#
# Recovery-run hardening (2026-10-28): the first launch of
# this batch hung in --import (engine error loop, log grew
# to 25 GB) after its `rm -rf .godot` overlapped another
# Godot run in the same tree. Now: refuse to start while
# any Godot process is up, and bound the import by time
# (900 s) and log size (20 MB).
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out; export TMPDIR="$PWD/.tmp"
DONE=Test/out/uip1_batch.done
: > "$DONE"
echo "start $(date -Is)" >> "$DONE"
if pgrep -f "Godot_v4.3-stable_linux" > /dev/null; then
  echo "ABORT: another Godot process is running" >> "$DONE"
  pgrep -af "Godot_v4.3-stable_linux" >> "$DONE"
  exit 1
fi
rm -rf .godot
timeout 900 "$G" --headless --import --path . 2>&1 \
  | head -c 20000000 > Test/out/uip1_import_ubantu.log
irc=${PIPESTATUS[0]}
echo "import rc=$irc" >> "$DONE"
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  echo "ABORT: import produced no class cache" >> "$DONE"
  exit 1
fi
bash Test/check_class_cache.sh > Test/out/uip1_class_cache_ubantu.log 2>&1
echo "class_cache rc=$?" >> "$DONE"
rm -f Test/out/mobile_p1_*.png Test/out/phonehud_touch_*_ubantu.log Test/out/phonehud_desktop_ubantu_*.log
bash Test/check_phonehud.sh > Test/out/uip1_matrix_ubantu.log 2>&1
echo "matrix rc=$?" >> "$DONE"
for f in Test/out/phonehud_touch_*_ubantu.log Test/out/phonehud_desktop_ubantu_*.log; do
  [ -f "$f" ] && cp "$f" "Test/out/uip1_$(basename "$f")"
done
timeout 2400 xvfb-run -a -s "-screen 0 2400x1080x24" "$G" \
  --path . --rendering-driver opengl3 res://Test/harness.tscn \
  -- --mode=cycle9 > Test/out/uip1_suite_ubantu.log 2>&1
echo "suite rc=$?" >> "$DONE"
bash Test/check_bootsmoke.sh > Test/out/uip1_bootsmoke_wrap_ubantu.log 2>&1
echo "bootsmoke rc=$?" >> "$DONE"
cp Test/out/bootsmoke_ubantu.log Test/out/uip1_bootsmoke_ubantu.log 2>/dev/null
echo "ALLDONE $(date -Is)" >> "$DONE"
