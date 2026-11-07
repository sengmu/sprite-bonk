#!/bin/bash
# Cycle 21.3.1 full verification batch (v3 code):
# phonehud matrix -> full suite -> bootsmoke -> APK
# build. Detached via c2131_launch5.sh; step RCs land
# in ~/c2131_batch2.done as they complete.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
DONE="$HOME/c2131_batch2.done"
: > "$DONE"
bash Test/check_phonehud.sh \
  > Test/out/c2131_matrix2_ubantu.log 2>&1
echo "matrix rc=$?" >> "$DONE"
timeout 2400 xvfb-run -a -s "-screen 0 2400x1080x24" \
  "$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64" \
  --path . --rendering-driver opengl3 res://Test/harness.tscn \
  -- --mode=cycle9 > Test/out/c2131_suite2_ubantu.log 2>&1
echo "suite rc=$?" >> "$DONE"
bash Test/check_bootsmoke.sh \
  > Test/out/c2131_bootsmoke2_wrap_ubantu.log 2>&1
echo "bootsmoke rc=$?" >> "$DONE"
bash android/build_apk.sh \
  > Test/out/c2131_build2_ubantu.log 2>&1
echo "build rc=$?" >> "$DONE"
echo ALLDONE >> "$DONE"
