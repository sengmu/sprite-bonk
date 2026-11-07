#!/bin/bash
# Detached launcher for subset4 (setsid; immune to
# ssh session drops). Import first if cache missing.
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
{
  echo "launch $(date -Is)"
  if [ ! -d .godot ]; then
    "$G" --headless --import --path . \
      > Test/out/c2131_import4_ubantu.log 2>&1
    echo "import rc=$?"
  fi
  bash Test/c2131_subset4.sh
  echo "subset4 chain done $(date -Is)"
} >> "$HOME/c2131_launch4.log" 2>&1
