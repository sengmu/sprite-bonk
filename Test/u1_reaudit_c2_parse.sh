#!/bin/bash
# U1 复审第 2 轮：校验全部修改与相关核心脚本在 Godot 4.3 下的语法与类型零错误
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT_BIN:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}"
for s in \
  res://scripts/world.gd \
  res://scripts/ui_theme.gd \
  res://scripts/touch_controls.gd \
  res://scripts/ui_medallion.gd \
  res://scripts/minimap.gd \
  res://Test/phonehud.gd; do
  "$G" --headless --path . --check-only -s "$s" 2>&1 \
    | grep -iE "SCRIPT ERROR|Parse Error|Compile Error|ERROR:" \
    | grep -v "SolanaSDK" && exit 1 || true
done
echo "PARSE GATE OK"
