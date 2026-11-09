#!/bin/bash
# Detached B2 evidence; ALLDONE only after every requested stage ends.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out
export TMPDIR="$PWD/.tmp"
mode=${1:-final}
prefix=c23b2_$mode
donefile=Test/out/${prefix}.done
: > "$donefile"
for f in scripts/world.gd scripts/enemy.gd Test/harness.gd; do
 timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/${prefix}_check_$(basename "$f" .gd).log" 2>&1
 rc=$?; echo "check $f rc=$rc" >> "$donefile"
 [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$donefile"; exit 1; }
done
if [ "$mode" = red ]; then phases='c22 guardian c21'; else phases='c23b2 c22 guardian'; fi
for phase in $phases; do
 timeout 900 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 --only="$phase" > "Test/out/${prefix}_$phase.log" 2>&1
 echo "$phase rc=$?" >> "$donefile"
done
if [ "$mode" = final ]; then
 for n in 1 2 3 4; do
  timeout 900 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 --only=c21 > "Test/out/c23b2_glare_$n.log" 2>&1
  echo "glare$n rc=$?" >> "$donefile"
 done
 C23B_PREFIX=c23b2_full bash Test/c23b_batch.sh
 echo "full_batch rc=$?" >> "$donefile"
fi
echo "ALLDONE $(date -Is)" >> "$donefile"
