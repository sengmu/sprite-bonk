#!/bin/bash
# C23 A: NUC detached validation; .done is incremental, ALLDONE is final.
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out
export TMPDIR="$PWD/.tmp"
DONE=Test/out/c23_batch.done
: > "$DONE"
for f in scripts/world.gd scripts/player.gd scripts/profile.gd Test/harness.gd; do
  timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/c23_check_$(basename "$f" .gd).log" 2>&1
  rc=$?; echo "check $f rc=$rc" >> "$DONE"
  [ "$rc" = 0 ] || exit 1
done
timeout 700 xvfb-run -a "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 --only=c23 > Test/out/c23_target.log 2>&1
rc=$?; echo "target rc=$rc" >> "$DONE"
[ "$rc" = 0 ] || exit 1
if [ "${1:-}" = target ]; then echo ALLDONE >> "$DONE"; exit 0; fi
timeout 3000 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 > Test/out/c23_suite.log 2>&1
echo "suite rc=$?" >> "$DONE"
bash Test/check_bootsmoke.sh > Test/out/c23_bootsmoke_wrap.log 2>&1
echo "bootsmoke rc=$?" >> "$DONE"
# Requested corner a (2400x1080 touch 1.00 i0) and touch s070 i0.
for spec in 'phone 2400x1080 1.00 a' 'phone 2400x1080 0.70 s070_i0'; do
  read -r mode win scale tag <<< "$spec"
  timeout 1500 xvfb-run -a -s "-screen 0 ${win}x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode="$mode" --scale="$scale" --win="$win" --inset=0,0,0,0 > "Test/out/c23_phonehud_$tag.log" 2>&1
  echo "phonehud $tag rc=$?" >> "$DONE"
done
echo "ALLDONE $(date -Is)" >> "$DONE"
