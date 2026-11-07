#!/bin/bash
# Standing per-starter PLAYER render check (hotfix gate — keep in tree).
# Runs the real game harness with each starter as the PLAYER and
# asserts rendered height / grounding / body color via
# Test/check_starters.py. Run from the project root:
#   bash Test/check_starters.sh
# Exit code is non-zero if any starter fails. Takes ~4 min per
# starter under software rendering (llvmpipe).
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}
fail=0
for sp in bulbasaur charmander squirtle; do
  log=$PWD/Test/out/check_$sp.log
  timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
    --rendering-driver opengl3 res://Test/harness.tscn -- --starter=$sp > "$log" 2>&1
  if ! grep -q "HARNESS DONE" "$log"; then
    echo "CHECK $sp FAIL harness did not finish (see $log)"
    fail=1
    continue
  fi
  python3 Test/check_starters.py "$sp" "$log" || fail=1
done
exit $fail
