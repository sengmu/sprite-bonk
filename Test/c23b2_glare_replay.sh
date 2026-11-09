#!/bin/bash
# B2 glare evidence after the passive/facing fixture fix; never overlaps profile tests.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
export TMPDIR="$PWD/.tmp"
DONE=Test/out/c23b2_glare_fixed.done
: > "$DONE"
while ! grep -q '^ALLDONE ' Test/out/c23b2_final.done 2>/dev/null; do sleep 5; done
timeout 180 "$G" --headless --path . --check-only --script res://Test/harness.gd > Test/out/c23b2_glare_fixed_check_harness.log 2>&1
echo "check harness rc=$?" >> "$DONE"
for n in 1 2 3 4; do
 timeout 900 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 --only=c21 > "Test/out/c23b2_glare_fixed_$n.log" 2>&1
 echo "glare$n rc=$?" >> "$DONE"
done
echo "ALLDONE $(date -Is)" >> "$DONE"
