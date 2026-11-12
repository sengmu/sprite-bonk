#!/bin/bash
# Audio merge verification (NUC sb-merge clone, main @ fc25432 =
# a530665 + audio/bgm FF + audio/cries merge, 2026-11-12).
# import -> parse gates -> all four audio checks -> suite ->
# phonehud 2340 -> bootsmoke -> neutral. Only ALLDONE = done.
set -u
cd "$HOME/workspace/sb-merge" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp/amrg_data .tmp/amrg_cache Test/out
export TMPDIR="$PWD/.tmp"
export XDG_DATA_HOME="$PWD/.tmp/amrg_data"
export XDG_CACHE_HOME="$PWD/.tmp/amrg_cache"
mkdir -p "$XDG_DATA_HOME/godot"
if [ ! -e "$XDG_DATA_HOME/godot/export_templates" ]; then
 ln -s "$HOME/.local/share/godot/export_templates" "$XDG_DATA_HOME/godot/export_templates"
fi
DONE=Test/out/audio_merge.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"
timeout 600 "$G" --headless --path . --import > Test/out/audio_merge_import.log 2>&1
echo "import rc=$?" >> "$DONE"
for f in scripts/audio.gd Test/audio_bgm_check.gd Test/audio_cry_check.gd; do
 timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/audio_merge_check_$(basename "$f" .gd).log" 2>&1
 echo "check $f rc=$?" >> "$DONE"
done
for chk in audio_bgm audio_cry audio_p0 audio_p12; do
 timeout 300 "$G" --headless --path . --script "res://Test/${chk}_check.gd" > "Test/out/audio_merge_${chk}.log" 2>&1
 rc=$?
 if grep -q "SCRIPT ERROR" "Test/out/audio_merge_${chk}.log"; then rc=1; fi
 if ! grep -q "fails=0" "Test/out/audio_merge_${chk}.log"; then rc=1; fi
 echo "${chk}_check rc=$rc" >> "$DONE"
done
timeout 3000 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 > Test/out/audio_merge_suite.log 2>&1
echo "suite rc=$?" >> "$DONE"
timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 2340x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.50 --win=2340x1080 --inset=0,0,0,0 > Test/out/audio_merge_phonehud_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
bash Test/check_bootsmoke.sh > Test/out/audio_merge_bootsmoke_wrap.log 2>&1
echo "bootsmoke rc=$?" >> "$DONE"
bash Test/c23_neutral_smoke.sh > Test/out/audio_merge_neutral_wrap.log 2>&1
echo "neutral rc=$?" >> "$DONE"
echo "ALLDONE $(date -Is)" >> "$DONE"
