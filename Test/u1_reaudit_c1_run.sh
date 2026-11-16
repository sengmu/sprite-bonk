#!/bin/bash
# U1 复审第 1 轮：先在 NUC 编辑器 --import 重建 .ctex 并核验 5 张触屏按钮 source_md5，再运行双档 phonehud 全量测试批
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tmp Test/out
mkdir -p .tmp/u1_c1_config .tmp/u1_c1_data .tmp/u1_c1_cache
export TMPDIR="$PWD/.tmp" XDG_CONFIG_HOME="$PWD/.tmp/u1_c1_config" XDG_DATA_HOME="$PWD/.tmp/u1_c1_data" XDG_CACHE_HOME="$PWD/.tmp/u1_c1_cache"
G=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
DONE=Test/out/u1_reaudit_c1.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"

# 1. NUC 强制重建新贴图缓存并校验 source_md5
timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --headless --path . --import --quit > Test/out/u1_reaudit_c1_import.log 2>&1 || true
git checkout -- addons/ 2>/dev/null || true
find design -name '*.import' -delete 2>/dev/null || true

python3 - <<'PY' >> "$DONE"
import hashlib
from pathlib import Path
root = Path(".")
for p in [
    "assets/ui/touch/btn_ult.png",
    "assets/ui/touch/btn_ult_charging.png",
    "assets/ui/touch/btn_interact.png",
    "assets/ui/touch/btn_jump.png",
    "assets/ui/touch/btn_dash.png",
]:
    md5 = hashlib.md5((root / p).read_bytes()).hexdigest()
    imp = (root / (p + ".import")).read_text(encoding="utf-8")
    ctex = [l.split('"')[1] for l in imp.splitlines() if 'path="res://.godot/imported/' in l][0].replace("res://", "")
    md5_file = root / (ctex[:-5] + ".md5")
    ok = md5_file.exists() and (f'source_md5="{md5}"' in md5_file.read_text(encoding="utf-8"))
    print(f"MD5_CHECK {p} md5={md5} match={ok}")
    if not ok:
        raise SystemExit(f"MD5 MISMATCH for {p}")
PY

# 2. 跑 2400x1080 与 2340x1080 双档全量 phonehud 测试批
timeout 1500 xvfb-run -a -s "-screen 0 2400x1080x24" stdbuf -o0 -e0 "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 --result=victory > Test/out/u1_reaudit_c1_phonehud_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u1_reaudit_c1_phonehud_2400.log >> "$DONE" 2>/dev/null || true

timeout 1500 xvfb-run -a -s "-screen 0 2340x1080x24" stdbuf -o0 -e0 "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2340x1080 --inset=0,0,0,0 --result=victory > Test/out/u1_reaudit_c1_phonehud_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u1_reaudit_c1_phonehud_2340.log >> "$DONE" 2>/dev/null || true

if ! grep -Eq 'PHONEHUD DONE checks=[0-9]+ fails=0' Test/out/u1_reaudit_c1_phonehud_2400.log || ! grep -Eq 'PHONEHUD DONE checks=[0-9]+ fails=0' Test/out/u1_reaudit_c1_phonehud_2340.log; then
  echo 'BATCH FAILED: inspect logs' >> "$DONE"
  exit 1
fi
echo "ALLDONE $(date -Is)" >> "$DONE"
