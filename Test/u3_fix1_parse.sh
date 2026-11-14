#!/bin/bash
# U3 fix1 parse gate for the three changed scripts (banner star/leaves,
# solid card-top pills, featured gold rim+glow, tool row order/colors).
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
GODOT=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
log="Test/out/u3_fix1_parse.log"
: > "$log"
for f in scripts/world.gd scripts/ui_theme.gd Test/phonehud.gd; do
  echo "=== $f ===" >> "$log"
  timeout 240 "$GODOT" --headless --check-only --script "res://$f" >> "$log" 2>&1
  echo "rc=$? :: $f" >> "$log"
done
echo "PARSE DONE" >> "$log"
