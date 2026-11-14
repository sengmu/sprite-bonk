#!/bin/bash
# U5 fix8 parse gate for the changed script (world.gd only:
# fat ribbon rect 225, row plates margin 3, core separation 1,
# fixed-height value pills, bottom spacer, taller buttons).
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
GODOT=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
log="Test/out/u5_fix8_parse.log"
: > "$log"
for f in scripts/world.gd; do
  echo "=== $f ===" >> "$log"
  timeout 240 "$GODOT" --headless --check-only --script "res://$f" >> "$log" 2>&1
  echo "rc=$? :: $f" >> "$log"
done
echo "PARSE DONE" >> "$log"
