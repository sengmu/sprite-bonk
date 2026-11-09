#!/bin/bash
# Detached C24 gates, no APK. Wait for ALLDONE and inspect every rc.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
prefix=${C24_PREFIX:-c24_final}
mkdir -p ".tmp/${prefix}_data" ".tmp/${prefix}_cache" Test/out
export TMPDIR="$PWD/.tmp"
export XDG_DATA_HOME="$PWD/.tmp/${prefix}_data"
export XDG_CACHE_HOME="$PWD/.tmp/${prefix}_cache"
# Reuse installed templates while keeping gameplay saves isolated.
mkdir -p "$XDG_DATA_HOME/godot"
if [ ! -e "$XDG_DATA_HOME/godot/export_templates" ]; then
 ln -s "$HOME/.local/share/godot/export_templates" "$XDG_DATA_HOME/godot/export_templates"
fi
DONE=Test/out/${prefix}.done
: > "$DONE"
for f in scripts/profile.gd scripts/enemy.gd scripts/player.gd scripts/fossils.gd scripts/world.gd Test/harness.gd Test/c24_shiny.gd Test/c24_fossils.gd Test/c24_live.gd; do
 timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/${prefix}_check_$(basename "$f" .gd).log" 2>&1
 rc=$?; echo "check $f rc=$rc" >> "$DONE"
 [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
done
for tag in shiny fossils live; do
 if [ "$tag" = live ]; then
  timeout 240 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 --script "res://Test/c24_$tag.gd" > "Test/out/${prefix}_$tag.log" 2>&1
 else
  timeout 120 "$G" --headless --path . --script "res://Test/c24_$tag.gd" > "Test/out/${prefix}_$tag.log" 2>&1
 fi
 rc=$?
 if grep -q "SCRIPT ERROR" "Test/out/${prefix}_$tag.log"; then rc=1; fi
 echo "$tag rc=$rc" >> "$DONE"
 [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
done
for script in Test/c24_fossils_mutations.py Test/c24_fusion_data.py; do
 python3 "$script" > "Test/out/${prefix}_$(basename "$script" .py).log" 2>&1
 rc=$?; echo "$script rc=$rc" >> "$DONE"
 [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
done
C23B_PREFIX=${prefix}_full bash Test/c23b_batch.sh
rc=$?; echo "full_batch rc=$rc" >> "$DONE"
if [ "$rc" != 0 ] || grep -Eq "rc=[1-9]" "Test/out/${prefix}_full_batch.done"; then
 echo ALLDONE_FAILED >> "$DONE"; exit 1
fi
echo "ALLDONE $(date -Is)" >> "$DONE"
