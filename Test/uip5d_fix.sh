#!/bin/bash
# UI-mobile P5 closing fix (drawer reds at uiScale 0.70 / 0.85,
# 2026-11-03 order) — phonehud combos on the CURRENT tree, NUC,
# detached via setsid. Template: uip5_red.sh (argv0-anchored
# Godot guard, --check-only parse gate first, 2400 s / 20 MB caps).
#   s1 : the two named reds (2400 s0.70 i0, 2400 s0.85 left 48)
#   s2 : all 19 reds of the uip5 final batch + a (2400 s1.00 i0,
#        control)
# Per-combo verdict + the drawer evidence lines land in
# Test/out/uip5d_<stage>.done; logs = uip5d_<stage>_<combo>_ubantu.log.
# Usage: bash Test/uip5d_fix.sh s1|s2|s070_<unique-tag>
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
ST=${1:-s1}
case "$ST" in s1|s2|s070_*) ;; *) echo "invalid stage: $ST" >&2; exit 2 ;; esac
DONE=Test/out/uip5d_${ST}.done
: > "$DONE"
echo "start $(date -Is) world=$(sha256sum scripts/world.gd | cut -c1-8)" >> "$DONE"
mkdir -p .tmp Test/out; export TMPDIR="$PWD/.tmp"
GPAT='^[^ ]*/Godot_v4\.3-stable_linux'
if pgrep -f "$GPAT" > /dev/null; then
  echo "ABORT: another Godot process is running" >> "$DONE"
  pgrep -af "$GPAT" >> "$DONE"
  exit 1
fi
for f in scripts/world.gd scripts/touch_controls.gd scripts/ui_theme.gd Test/phonehud.gd; do
  timeout 180 "$G" --headless --path . --check-only --script "res://$f" 2>&1 \
    | head -c 200000 > ".tmp/uip5d_check_$(basename "$f" .gd).log"
  rc=${PIPESTATUS[0]}
  echo "check $f rc=$rc" >> "$DONE"
  if [ "$rc" != "0" ]; then
    echo "ABORT: parse gate failed" >> "$DONE"
    exit 1
  fi
done
run() {
  # $1 win, $2 ts, $3 inset, $4.. extra phonehud args
  local win="$1" ts="$2" ins="$3"; shift 3
  local name="${win}_s$(echo "$ts" | tr -d '.')_i$(echo "$ins" | tr ',' '_')"
  for a in "$@"; do name="${name}_${a#--}"; done
  local log="Test/out/uip5d_${ST}_${name}_ubantu.log"
  timeout 2400 xvfb-run -a -s "-screen 0 ${win}x24" "$G" --path . \
    --rendering-driver opengl3 res://Test/phonehud.tscn -- \
    --mode=phone --scale="$ts" --win="$win" --inset="$ins" "$@" 2>&1 \
    | head -c 20000000 > "$log"
  local rc=${PIPESTATUS[0]}
  local v="FAIL"
  grep -q "PHONEHUD DONE .* fails=0" "$log" && v="OK"
  echo "$name rc=$rc $v $(grep -ho 'PHONEHUD DONE.*' "$log")" >> "$DONE"
  grep -h 'three events injected\|drawer inside UI area\|tap outside closes\|auto-collapses after\|PHONEHUD FAIL' "$log" \
    | cut -c1-200 | sed 's/^/    /' >> "$DONE"
}
if [[ "$ST" == s070_* ]]; then
  run 2400x1080 0.70 0,0,0,0
elif [ "$ST" = "s1" ]; then
  run 2400x1080 0.70 0,0,0,0
  run 2400x1080 0.85 48,0,0,0
else
  for win in 2400x1080 2340x1080 1920x1080; do
    for ts in 0.70 0.85; do
      for ins in 0,0,0,0 48,0,0,0 0,0,48,0; do
        run "$win" "$ts" "$ins"
      done
    done
  done
  run 2340x1080 0.85 0,0,48,0 --hud=1.30 --mm=0.75
  run 2400x1080 1.00 0,0,0,0
fi
echo "ALLDONE $(date -Is)" >> "$DONE"
