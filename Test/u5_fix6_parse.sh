#!/bin/bash
# U5 fix6 parse gate for the changed scripts (result wrapper stack,
# P5 extended-stats skip, refresh icon, phonehud _p5_panel wrap).
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
GODOT=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
log="Test/out/u5_fix6_parse.log"
: > "$log"
for f in scripts/world.gd scripts/ui_icon.gd Test/phonehud.gd; do
  echo "=== $f ===" >> "$log"
  timeout 240 "$GODOT" --headless --check-only --script "res://$f" >> "$log" 2>&1
  echo "rc=$? :: $f" >> "$log"
done
echo "PARSE DONE" >> "$log"
