#!/bin/bash
# Approved UI gates. Launch via setsid; inspect ALLDONE and each rc. No APK.
set -u
cd "$(dirname "$0")/.." || exit 1
G=${GODOT:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}
mkdir -p Test/out .tmp/reskin_gate_data .tmp/reskin_gate_config .tmp/reskin_gate_cache
export TMPDIR="$PWD/.tmp" XDG_DATA_HOME="$PWD/.tmp/reskin_gate_data" XDG_CONFIG_HOME="$PWD/.tmp/reskin_gate_config" XDG_CACHE_HOME="$PWD/.tmp/reskin_gate_cache"
mkdir -p "$XDG_DATA_HOME/godot"
[ -e "$XDG_DATA_HOME/godot/export_templates" ] || ln -s "$HOME/.local/share/godot/export_templates" "$XDG_DATA_HOME/godot/export_templates"
DONE=Test/out/reskin_batch.done
: > "$DONE"
for f in scripts/world.gd scripts/ui_theme.gd scripts/ui_badge.gd scripts/legal_document.gd scripts/minimap.gd scripts/ui_medallion.gd scripts/ult.gd scripts/touch_controls.gd scripts/ult_gauge.gd Test/uishot.gd Test/harness.gd Test/phonehud.gd; do
 timeout 180 "$G" --headless --path . --check-only --script "res://$f" > "Test/out/reskin_check_$(basename "$f").log" 2>&1
 rc=$?
 echo "check $f rc=$rc" >> "$DONE"
 if [ "$rc" != 0 ]; then echo ALLDONE_FAILED >> "$DONE"; exit 1; fi
done
python3 Test/check_legal.py > Test/out/reskin_legal.log 2>&1
echo "legal rc=$?" >> "$DONE"
timeout 3000 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/harness.tscn -- --mode=cycle9 > Test/out/reskin_suite.log 2>&1
echo "suite rc=$?" >> "$DONE"
bash Test/check_bootsmoke.sh > Test/out/reskin_bootsmoke_wrap.log 2>&1
echo "bootsmoke rc=$?" >> "$DONE"
bash Test/c23_neutral_smoke.sh > Test/out/reskin_neutral_wrap.log 2>&1
echo "neutral rc=$?" >> "$DONE"
for spec in '2400x1080 1.00 a' '2400x1080 0.70 s070_i0' '2340x1080 1.50 2340x1080_s150'; do
 read -r win scale tag <<< "$spec"
 timeout 1500 xvfb-run -a -s "-screen 0 ${win}x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale="$scale" --win="$win" --inset=0,0,0,0 > "Test/out/reskin_phonehud_$tag.log" 2>&1
 rc=$?
 grep -q 'PHONEHUD DONE .* fails=0' "Test/out/reskin_phonehud_$tag.log" || rc=1
 echo "phonehud $tag rc=$rc" >> "$DONE"
done
echo "ALLDONE $(date -Is)" >> "$DONE"
