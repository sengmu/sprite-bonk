#!/bin/bash
# Detached launcher for the 21.3.1 full batch
# (setsid; immune to ssh session drops).
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
{
  echo "launch $(date -Is)"
  if [ ! -d .godot ]; then
    "$G" --headless --import --path . \
      > Test/out/c2131_import5_ubantu.log 2>&1
    echo "import rc=$?"
  fi
  bash Test/c2131_batch2.sh
  echo "batch2 chain done $(date -Is)"
} >> "$HOME/c2131_launch5.log" 2>&1
