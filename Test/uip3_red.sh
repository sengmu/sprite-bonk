#!/bin/bash
# UI-mobile P3 runs on the NUC (detached via setsid): a
# corner subset of the phonehud gate on the CURRENT tree.
#   red  : the P3 assertions against the UNCHANGED P2-closed
#          game tree (world.gd b95354db...) — they must bite.
#   it*  : iteration runs on the implementation tree.
# Hardening = uip2_*: argv0-anchored Godot guard (an
# unanchored -f pattern matches the launching ssh session),
# a --check-only parse gate first (a parse error otherwise
# idles each run to the 900 s timeout with an empty log),
# 900 s / 20 MB caps per run.
# Variants: a 2400 s1.00 i0 · b 1920 s1.50 i48 · c classic
# 2400 s1.00 · p P7 corner hud1.30/mm1.50 2400 s1.50 ·
# d desktop; iteration extras e 2400 s1.50 · f 2340 s0.70
# right 48 · g 1920 s0.70 · q P7 hud0.80/mm1.50 1920 s1.50 i48.  Usage: bash Test/uip3_red.sh <tag> [letters]
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
TAG=${1:-red}
WANT=${2:-abcpd}
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
run() {
  # $1 letter, $2 mode, $3 win, $4 ts, $5 inset, $6.. extra args
  local l="$1" mode="$2" win="$3" ts="$4" ins="$5"; shift 5
  case "$WANT" in *"$l"*) ;; *) return ;; esac
  timeout 900 xvfb-run -a -s "-screen 0 ${win}x24" "$G" --path . \
    --rendering-driver opengl3 res://Test/phonehud.tscn -- \
    --mode="$mode" --scale="$ts" --win="$win" --inset="$ins" "$@" 2>&1 \
    | head -c 20000000 > "Test/out/uip3_${TAG}_${mode}_${l}_ubantu.log"
  echo "$l $mode $win $ts $ins $* rc=${PIPESTATUS[0]}" >> "$DONE"
}
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
