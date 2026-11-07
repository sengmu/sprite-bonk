#!/bin/bash
# Cycle 21.3.1 subset v4 — the stressed combos only,
# invoked EXACTLY like Test/check_phonehud.sh
# (xvfb + opengl3 + --win/--scale/--inset user args).
# (Subsets v1-v3 passed --resolution/--touchscale,
# which the harness ignores — their geometry was
# wrong; only check_phonehud-faithful runs count.)
set -u
cd "$(dirname "$0")/.."
mkdir -p .tmp Test/out
export TMPDIR="${TMPDIR:-$PWD/.tmp}"
GODOT=${GODOT:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}
HOST=$(hostname -s | tr 'A-Z' 'a-z')
DONE="$HOME/c2131_subset4.done"
: > "$DONE"

run_variant() {
  local mode="$1" win="$2" scale="$3" inset="$4"
  local ts="s$(echo "$scale" | tr -d '.')"
  local ins="i0"
  if [ "$inset" != "0,0,0,0" ]; then
    ins="i$(echo "$inset" | tr ',.' '__')"
  fi
  local log="Test/out/c2131_s4_${mode}_${win}_${ts}_${ins}_${HOST}.log"
  timeout 900 xvfb-run -a -s "-screen 0 ${win}x24" "$GODOT" --path . \
    --rendering-driver opengl3 res://Test/phonehud.tscn -- \
    --mode="$mode" --scale="$scale" --win="$win" --inset="$inset" \
    > "$log" 2>&1
  local verdict
  if grep -q "PHONEHUD DONE .* fails=0" "$log"; then
    verdict="OK"
  else
    verdict="FAIL"
  fi
  echo "$mode $win ($scale) inset=$inset $verdict" >> "$DONE"
  grep -E "prompt fits the F5c 2-line cap|narrow-span prompt column bounded" \
    "$log" | sed 's/^PHONEHUD //' >> "$DONE"
}

run_variant phone 1920x1080 0.70 "0,0,0,0"
run_variant phone 1920x1080 0.85 "0,0,0,0"
run_variant phone 1920x1080 1.50 "0,0,0,0"
run_variant phone 1920x1080 1.50 "48,0,0,0"
run_variant phone 1920x1080 1.50 "0,0,48,0"
run_variant phone 2400x1080 1.50 "48,0,0,0"
run_variant phone 2400x1080 1.50 "0,0,0,0"
run_variant desktop 1280x720 1.00 "0,0,0,0"
echo ALLDONE >> "$DONE"
