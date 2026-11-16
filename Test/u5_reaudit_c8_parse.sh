#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tmp/u5_c8_config .tmp/u5_c8_data Test/out
export TMPDIR="$PWD/.tmp" XDG_CONFIG_HOME="$PWD/.tmp/u5_c8_config" XDG_DATA_HOME="$PWD/.tmp/u5_c8_data"
GODOT=${GODOT:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}
log=Test/out/u5_reaudit_c8_parse.log
: > "$log"
for f in scripts/world.gd scripts/ui_icon.gd scripts/ui_theme.gd; do
  printf '\n=== %s ===\n' "$f" >> "$log"
  timeout 240 "$GODOT" --headless --path . --check-only --script "res://$f" >> "$log" 2>&1
  echo "rc=0 :: $f" >> "$log"
done
if grep -Eq 'SCRIPT ERROR|Parse Error' "$log"; then exit 1; fi
echo 'PARSE DONE rc=0' >> "$log"
cat "$log" | tail -n 10
