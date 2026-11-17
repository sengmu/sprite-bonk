#!/bin/bash
# U1战斗HUD + 全界面 1:1 终极对齐：NUC 双档 2400x1080 与 2340x1080 s100 全量验收并生成全部 compare 图
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tmp Test/out
mkdir -p .tmp/u1_fin_config .tmp/u1_fin_data .tmp/u1_fin_cache
export TMPDIR="$PWD/.tmp" XDG_CONFIG_HOME="$PWD/.tmp/u1_fin_config" XDG_DATA_HOME="$PWD/.tmp/u1_fin_data" XDG_CACHE_HOME="$PWD/.tmp/u1_fin_cache"
G=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
DONE=Test/out/u1_final_reaudit.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"

timeout 1500 xvfb-run -a -s "-screen 0 2400x1080x24" stdbuf -o0 -e0 "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 --result=victory > Test/out/u1_final_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u1_final_2400.log >> "$DONE" 2>/dev/null || true

timeout 1500 xvfb-run -a -s "-screen 0 2340x1080x24" stdbuf -o0 -e0 "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2340x1080 --inset=0,0,0,0 --result=victory > Test/out/u1_final_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u1_final_2340.log >> "$DONE" 2>/dev/null || true

if ! grep -Eq 'PHONEHUD DONE checks=[0-9]+ fails=0' Test/out/u1_final_2400.log || ! grep -Eq 'PHONEHUD DONE checks=[0-9]+ fails=0' Test/out/u1_final_2340.log; then
  echo 'BATCH FAILED: inspect logs' >> "$DONE"
  exit 1
fi

# 全部双档通过后原地重建 U1-U6 全套并排对照图
python3 Test/make_compare_u1.py Test/out/phone_hud_touch_2340x1080_s100_i0_hudstart.png "SHOT phonehud 2340x1080 s100 hud_start (u1_final)" design/ui-reference/compare/U1.png || true
python3 Test/make_compare_u1_boss.py Test/out/mobile_p2_boss_2340x1080_s100_i0.png "SHOT phonehud 2340x1080 s100 boss (u1_final)" design/ui-reference/compare/U1_boss.png || true
python3 Test/make_compare_u2.py Test/out/mobile_p5_menu_2340x1080_s100_i0.png "SHOT phonehud 2340x1080 s100 menu (u1_final)" design/ui-reference/compare/U2.png || true
python3 Test/make_compare_u2.py Test/out/mobile_p5_menu_2400x1080_s100_i0.png "SHOT phonehud 2400x1080 s100 menu (u1_final)" design/ui-reference/compare/U2_2400.png || true
python3 Test/make_compare_u3.py Test/out/phone_hud_touch_2340x1080_s100_i0_draft.png "SHOT phonehud 2340x1080 s100 draft (u1_final)" design/ui-reference/compare/U3.png || true
python3 Test/make_compare_u3.py Test/out/phone_hud_touch_2400x1080_s100_i0_draft.png "SHOT phonehud 2400x1080 s100 draft (u1_final)" design/ui-reference/compare/U3_2400.png || true
python3 Test/make_compare_u4.py Test/out/mobile_p5_lab_upgrades_2340x1080_s100_i0.png "SHOT phonehud 2340x1080 s100 lab (u1_final)" design/ui-reference/compare/U4.png || true
python3 Test/make_compare_u4.py Test/out/mobile_p5_lab_upgrades_2400x1080_s100_i0.png "SHOT phonehud 2400x1080 s100 lab (u1_final)" design/ui-reference/compare/U4_2400.png || true
python3 Test/make_compare_u6.py Test/out/mobile_p5_wallet_2340x1080_s100_i0.png "SHOT phonehud 2340x1080 s100 wallet (u1_final)" design/ui-reference/compare/U6.png || true
python3 Test/make_compare_u6.py Test/out/mobile_p5_wallet_2400x1080_s100_i0.png "SHOT phonehud 2400x1080 s100 wallet (u1_final)" design/ui-reference/compare/U6_2400.png || true

echo "ALLDONE $(date -Is)" >> "$DONE"
