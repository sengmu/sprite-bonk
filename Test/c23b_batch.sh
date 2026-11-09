#!/bin/bash
# C23B detached NUC gates; only ALLDONE denotes completion.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out
export TMPDIR="$PWD/.tmp"
DONE=Test/out/${C23B_PREFIX:-c23b}_batch.done
: > "$DONE"
for f in scripts/world.gd scripts/player.gd scripts/enemy.gd scripts/pickups.gd scripts/profile.gd Test/harness.gd Test/c23_damage.gd Test/c23_pickups.gd Test/c23_pickup_stats.gd; do
 timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/${C23B_PREFIX:-c23b}_check_$(basename "$f" .gd).log" 2>&1
 rc=$?; echo "check $f rc=$rc" >> "$DONE"
 [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
done
for tag in damage pickups pickup_stats; do
 timeout 180 "$G" --headless --path . --script "res://Test/c23_$tag.gd" > "Test/out/${C23B_PREFIX:-c23b}_$tag.log" 2>&1
 rc=$?; echo "$tag rc=$rc" >> "$DONE"
 [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
done
timeout 900 python3 Test/c23_pickups_mutations.py > Test/out/${C23B_PREFIX:-c23b}_pickups_mutations.log 2>&1
rc=$?; echo "pickup_mutations rc=$rc" >> "$DONE"
[ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
if [ "${1:-}" = target ]; then echo ALLDONE >> "$DONE"; exit 0; fi
timeout 3000 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 > Test/out/${C23B_PREFIX:-c23b}_suite.log 2>&1
echo "suite rc=$?" >> "$DONE"
# Require a fresh Linux export: stale binaries cannot stand in for this tree.
rm -f build/linux/SpriteBonk.x86_64 build/linux/SpriteBonk.pck
bash Test/check_bootsmoke.sh > Test/out/${C23B_PREFIX:-c23b}_bootsmoke_wrap.log 2>&1
echo "bootsmoke rc=$?" >> "$DONE"
bash Test/c23_neutral_smoke.sh > Test/out/${C23B_PREFIX:-c23b}_neutral_wrap.log 2>&1
echo "neutral rc=$?" >> "$DONE"
for spec in 'phone 2400x1080 1.00 a' 'phone 2400x1080 0.70 s070_i0'; do
 read -r mode win scale tag <<< "$spec"
 timeout 1500 xvfb-run -a -s "-screen 0 ${win}x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode="$mode" --scale="$scale" --win="$win" --inset=0,0,0,0 > "Test/out/${C23B_PREFIX:-c23b}_phonehud_$tag.log" 2>&1
 echo "phonehud $tag rc=$?" >> "$DONE"
done
echo "ALLDONE $(date -Is)" >> "$DONE"
