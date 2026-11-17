#!/bin/bash
# U5 复审第 9 轮：校验 scripts/world.gd 与核心界面脚本语法零错误
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT_BIN:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}"
for s in res://scripts/world.gd res://scripts/ui_theme.gd res://scripts/ui_icon.gd res://Test/phonehud.gd; do
  "$G" --headless --path . --check-only -s "$s" 2>&1 \
    | grep -iE "SCRIPT ERROR|Parse Error|Compile Error|ERROR:" \
    | grep -v "SolanaSDK" && exit 1 || true
done
echo "U5 C9 PARSE GATE OK"
