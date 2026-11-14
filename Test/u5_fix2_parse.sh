#!/bin/bash
# U5 fix2 parse gate for the three changed scripts (single-column
# result, stars per state, payout pill, icon buttons, home glyph,
# --result=victory flag).
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
GODOT=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
log="Test/out/u5_fix2_parse.log"
: > "$log"
for f in scripts/world.gd scripts/ui_icon.gd Test/phonehud.gd; do
  echo "=== $f ===" >> "$log"
  timeout 240 "$GODOT" --headless --check-only --script "res://$f" >> "$log" 2>&1
  echo "rc=$? :: $f" >> "$log"
done
echo "PARSE DONE" >> "$log"
