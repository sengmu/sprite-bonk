#!/bin/bash
# Detached launcher: import (if needed) then subset3.
# Runs under setsid; immune to ssh session drops.
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
{
  echo "launch $(date -Is)"
  if [ ! -d .godot ]; then
    "$G" --headless --import --path . \
      > Test/out/c2131_import3_ubantu.log 2>&1
    echo "import rc=$?"
  fi
  cp Test/c2131_subset3.sh "$HOME/c2131_subset3.sh"
  chmod +x "$HOME/c2131_subset3.sh"
  "$HOME/c2131_subset3.sh"
  echo "subset3 chain done $(date -Is)"
} >> "$HOME/c2131_launch3.log" 2>&1
