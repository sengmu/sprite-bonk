#!/bin/bash
# U2 主菜单复审 + 商店界面 (S10/S12) 解析门校验
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT_BIN:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}"
for s in res://scripts/world.gd res://scripts/ui_theme.gd res://scripts/ui_icon.gd res://Test/phonehud.gd; do
  if "$G" --headless --path . --check-only -s "$s" 2>&1 | grep -v "SolanaSDK" | grep -qiE "SCRIPT ERROR|Parse Error|Compile Error"; then
    exit 1
  fi
done
echo "U2_SHOP PARSE GATE OK"
