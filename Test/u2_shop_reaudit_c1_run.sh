#!/bin/bash
# U2 主菜单复审 + S10/S12 商店对齐：NUC 双档 2400x1080 与 2340x1080 s100 全量测试批
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tmp Test/out
mkdir -p .tmp/u2_c1_config .tmp/u2_c1_data .tmp/u2_c1_cache
export TMPDIR="$PWD/.tmp" XDG_CONFIG_HOME="$PWD/.tmp/u2_c1_config" XDG_DATA_HOME="$PWD/.tmp/u2_c1_data" XDG_CACHE_HOME="$PWD/.tmp/u2_c1_cache"
G=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
DONE=Test/out/u2_shop_reaudit_c1.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"

timeout 1500 xvfb-run -a -s "-screen 0 2400x1080x24" stdbuf -o0 -e0 "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 --result=victory > Test/out/u2_shop_reaudit_c1_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u2_shop_reaudit_c1_2400.log >> "$DONE" 2>/dev/null || true

timeout 1500 xvfb-run -a -s "-screen 0 2340x1080x24" stdbuf -o0 -e0 "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2340x1080 --inset=0,0,0,0 --result=victory > Test/out/u2_shop_reaudit_c1_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u2_shop_reaudit_c1_2340.log >> "$DONE" 2>/dev/null || true

if ! grep -Eq 'PHONEHUD DONE checks=[0-9]+ fails=0' Test/out/u2_shop_reaudit_c1_2400.log || ! grep -Eq 'PHONEHUD DONE checks=[0-9]+ fails=0' Test/out/u2_shop_reaudit_c1_2340.log; then
  echo 'BATCH FAILED: inspect logs' >> "$DONE"
  exit 1
fi
echo "ALLDONE $(date -Is)" >> "$DONE"
