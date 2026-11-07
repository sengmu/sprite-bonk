#!/bin/bash
# UI-mobile P3 fix round 2 (NUC, detached via setsid): the six
# final-batch red combos (1-6), the it3 nine corners (a b c p e
# f g q d) and the classic corner, on the CURRENT tree.
# Hardening = uip3_red.sh (argv0-anchored Godot guard,
# --check-only parse gate first, 900 s / 20 MB caps per run).
# SCENE=res://Test/diag/p3r2_diag.tscn swaps in the throwaway
# diagnostic subclass (same gate + extra P3R2DIAG lines).
# Usage: bash Test/uip3_r2.sh <tag> [keys]   keys: 1-6 a-q, d
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
TAG=${1:-r2}
WANT=${2:-123456abcpefgqd}
SCENE=${SCENE:-res://Test/phonehud.tscn}
DONE=Test/out/uip3_${TAG}.done
: > "$DONE"
mkdir -p .tmp Test/out; export TMPDIR="$PWD/.tmp"
GPAT='^[^ ]*/Godot_v4\.3-stable_linux'
if pgrep -f "$GPAT" > /dev/null; then
  echo "ABORT: another Godot process is running" >> "$DONE"
  pgrep -af "$GPAT" >> "$DONE"
  exit 1
fi
for f in scripts/world.gd scripts/touch_controls.gd scripts/ui_icon.gd \
    scripts/ult_gauge.gd scripts/ui_medallion.gd scripts/profile.gd Test/phonehud.gd; do
  timeout 180 "$G" --headless --path . --check-only --script "res://$f" 2>&1 \
    | head -c 200000 > ".tmp/uip3_check_$(basename "$f" .gd).log"
  rc=${PIPESTATUS[0]}
  echo "check $f rc=$rc" >> "$DONE"
  if [ "$rc" != "0" ]; then
    echo "ABORT: parse gate failed" >> "$DONE"
    exit 1
  fi
done
echo "world $(sha256sum scripts/world.gd | cut -c1-16) scene=$SCENE" >> "$DONE"
run() {
  local l="$1" mode="$2" win="$3" ts="$4" ins="$5"; shift 5
  case "$WANT" in *"$l"*) ;; *) return ;; esac
  timeout 900 xvfb-run -a -s "-screen 0 ${win}x24" "$G" --path . \
    --rendering-driver opengl3 "$SCENE" -- \
    --mode="$mode" --scale="$ts" --win="$win" --inset="$ins" "$@" 2>&1 \
    | head -c 20000000 > "Test/out/uip3_${TAG}_${mode}_${l}_ubantu.log"
  echo "$l $mode $win $ts $ins $* rc=${PIPESTATUS[0]} $(grep -a 'PHONEHUD DONE' "Test/out/uip3_${TAG}_${mode}_${l}_ubantu.log")" >> "$DONE"
}
run 1 phone 1920x1080 1.50 0,0,48,0
run 2 phone 2340x1080 0.85 0,0,48,0 --hud=1.30 --mm=0.75
run 3 phone 2400x1080 0.85 0,0,0,0
run 4 phone 2400x1080 1.00 0,0,0,0 --hud=0.80 --mm=0.75
run 5 phone 2400x1080 1.50 0,0,48,0
run 6 phone 2400x1080 1.50 48,0,0,0
run a phone 2400x1080 1.00 0,0,0,0
run b phone 1920x1080 1.50 48,0,0,0
run c phone 2400x1080 1.00 0,0,0,0 --layout=classic
run p phone 2400x1080 1.50 0,0,0,0 --hud=1.30 --mm=1.50
run e phone 2400x1080 1.50 0,0,0,0
run f phone 2340x1080 0.70 0,0,48,0
run g phone 1920x1080 0.70 0,0,0,0
run q phone 1920x1080 1.50 48,0,0,0 --hud=0.80 --mm=1.50
run d desktop 1280x720 1.00 0,0,0,0
echo ALLDONE >> "$DONE"
