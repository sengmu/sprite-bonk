#!/bin/bash
# Icon order 1 verification batch (NUC). Import first (new PNGs need
# .import files), parse gates, suite, phonehud 2340, smokes.
cd ~/workspace/sprite-bonk-3d || exit 1
G=~/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
D=Test/out/icons1_batch.done
rm -f "$D"
{
  echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)"
  timeout 600 "$G" --headless --path . --import > Test/out/icons1_import.log 2>&1
  echo "import rc=$?"
  for f in scripts/world.gd scripts/ui_badge.gd scripts/ui_icon.gd; do
    timeout 240 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/icons1_parse_$(basename $f).log" 2>&1
    echo "check $f rc=$?"
  done
  timeout 1500 bash Test/run_suite.sh > Test/out/icons1_suite.log 2>&1
  echo "suite rc=$?"
  PH_PROFILES=a PH_TIMEOUT=1500 timeout 1700 "$G" --headless --path . --script res://Test/phonehud.gd > Test/out/icons1_phonehud_2340.log 2>&1
  echo "phonehud 2340 rc=$?"
  timeout 300 "$G" --headless --path . > Test/out/icons1_bootsmoke.log 2>&1
  echo "bootsmoke rc=$?"
  timeout 600 bash Test/check_bootsmoke.sh > Test/out/icons1_neutral.log 2>&1
  echo "neutral rc=$?"
  echo "ALLDONE $(date -Is)"
} > "$D" 2>&1
