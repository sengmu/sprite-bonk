#!/bin/bash
# U5 re-audit Codex round 4 parse gate for the changed scripts
# (world.gd + ui_icon.gd: content VBox / row 66.3 / tile 64 /
# row label 31 / payout 32 / action 33 / result_refresh glyph /
# icons 56+50). P5-only; desktop values unchanged.
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
GODOT=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
log="Test/out/u5_reaudit_c4_parse.log"
: > "$log"
for f in scripts/world.gd scripts/ui_icon.gd; do
  echo "=== $f ===" >> "$log"
  timeout 240 "$GODOT" --headless --check-only --script "res://$f" >> "$log" 2>&1
  echo "rc=$? :: $f" >> "$log"
done
echo "PARSE DONE" >> "$log"
