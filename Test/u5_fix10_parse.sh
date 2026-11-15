#!/bin/bash
# U5 fix10 parse gate for the changed script (world.gd only:
# chunky value pills (44 px, 210 min width, 32 px digits, deep
# gold), payout gap 28 + payout min height 59, bottom gap 13).
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
GODOT=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
log="Test/out/u5_fix10_parse.log"
: > "$log"
for f in scripts/world.gd; do
  echo "=== $f ===" >> "$log"
  timeout 240 "$GODOT" --headless --check-only --script "res://$f" >> "$log" 2>&1
  echo "rc=$? :: $f" >> "$log"
done
echo "PARSE DONE" >> "$log"
