#!/bin/bash
# Icon order 2 verification batch (NUC): import (generates the
# .import sidecars for the ~291 placed files) -> parse gates ->
# suite -> phonehud 2340 s150 -> phonehud 2400 s150 ->
# phonehud 2400 s100 (evidence captures) -> bootsmoke -> neutral.
# Stage invocations copied from the proven icons1/u1_fix17 batches.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out
export TMPDIR="$PWD/.tmp"
DONE=Test/out/icons2_batch.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"
timeout 600 "$G" --headless --path . --import > Test/out/icons2_import.log 2>&1
echo "import rc=$?" >> "$DONE"
for f in scripts/world.gd scripts/ui_badge.gd scripts/ui_theme.gd scripts/minimap.gd scripts/big_map.gd scripts/touch_controls.gd scripts/ult_gauge.gd; do
  timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/icons2_parse_$(basename "$f" .gd).log" 2>&1
  echo "check $f rc=$?" >> "$DONE"
done
timeout 3000 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 > Test/out/icons2_suite.log 2>&1
echo "suite rc=$?" >> "$DONE"
timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 2340x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.50 --win=2340x1080 --inset=0,0,0,0 > Test/out/icons2_phonehud_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.50 --win=2400x1080 --inset=0,0,0,0 > Test/out/icons2_phonehud_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 > Test/out/icons2_phonehud_s100.log 2>&1
echo "phonehud s100 rc=$?" >> "$DONE"
bash Test/check_bootsmoke.sh > Test/out/icons2_bootsmoke_wrap.log 2>&1
echo "bootsmoke rc=$?" >> "$DONE"
bash Test/c23_neutral_smoke.sh > Test/out/icons2_neutral_wrap.log 2>&1
echo "neutral rc=$?" >> "$DONE"
echo "ALLDONE $(date -Is)" >> "$DONE"
