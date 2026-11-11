#!/bin/bash
# Detached BGM gates: parse gates -> BGM check -> P0/P12 audio
# checks (regression) -> full batch (suite + bootsmoke + phonehud)
# via c23b_batch.sh.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
prefix=audio_bgm
mkdir -p ".tmp/${prefix}_data" ".tmp/${prefix}_cache" Test/out
export TMPDIR="$PWD/.tmp"
export XDG_DATA_HOME="$PWD/.tmp/${prefix}_data"
export XDG_CACHE_HOME="$PWD/.tmp/${prefix}_cache"
mkdir -p "$XDG_DATA_HOME/godot"
if [ ! -e "$XDG_DATA_HOME/godot/export_templates" ]; then
 ln -s "$HOME/.local/share/godot/export_templates" "$XDG_DATA_HOME/godot/export_templates"
fi
DONE=Test/out/${prefix}.done
: > "$DONE"
for f in scripts/audio.gd Test/audio_bgm_check.gd; do
 timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/${prefix}_check_$(basename "$f" .gd).log" 2>&1
 rc=$?; echo "check $f rc=$rc" >> "$DONE"
 [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
done
for chk in audio_bgm audio_p0 audio_p12; do
 timeout 300 "$G" --headless --path . --script "res://Test/${chk}_check.gd" > "Test/out/${prefix}_${chk}.log" 2>&1
 rc=$?
 if grep -q "SCRIPT ERROR" "Test/out/${prefix}_${chk}.log"; then rc=1; fi
 if ! grep -q "fails=0" "Test/out/${prefix}_${chk}.log"; then rc=1; fi
 echo "${chk}_check rc=$rc" >> "$DONE"
 [ "$rc" = 0 ] || { echo ALLDONE_FAILED >> "$DONE"; exit 1; }
done
C23B_PREFIX=${prefix}_full bash Test/c23b_batch.sh
rc=$?; echo "full_batch rc=$rc" >> "$DONE"
if [ "$rc" != 0 ] || grep -Eq "rc=[1-9]" "Test/out/${prefix}_full_batch.done"; then
 echo ALLDONE_FAILED >> "$DONE"; exit 1
fi
echo "ALLDONE $(date -Is)" >> "$DONE"
