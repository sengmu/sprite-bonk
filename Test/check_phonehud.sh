#!/bin/bash
# Standing phone-resolution HUD gate (cycle 19 hotfix;
# cycle 20.2: touchScale sweep + per-host logs;
# cycle 21.3: HARDENED per the official Claude UI audit
# §4 — touch layer forced on, deep rects, six driven
# states incl. modals, safe-area inset simulation).
#
# Matrix (audit §4): windows 2400x1080 / 2340x1080 /
# 1920x1080 x touchScale {0.70, 0.85, 1.00, 1.50} x
# insets {0, (48,0,0,0), (0,0,48,0)}, plus the 1280x720
# desktop baseline. Logs are per-run + per-host
# (phonehud_touch_<win>_<ts>_<inset>_<host>.log) so one
# station's evidence can never clobber another's.
#
# UI-mobile P3 (plan B0.7 / risk P7 + D6): four hudScale x
# minimapScale corners {0.80,1.30} x {0.75,1.50} (each on a
# different window / touchScale / inset) and the classic-
# layout corner (2400x1080 s1.00, plan D6) join the standing
# matrix; extra phonehud args ride after the inset and land
# in the log name (..._h130_m150_<host>.log / _classic_).
#
# PH_QUICK=1 trims the matrix for iteration (one window,
# scales {1.00}, insets {0, left}); the full matrix is
# the standing gate.
# Run from the project root:  bash Test/check_phonehud.sh
set -u
cd "$(dirname "$0")/.."
mkdir -p .tmp Test/out
export TMPDIR="${TMPDIR:-$PWD/.tmp}"
GODOT=${GODOT:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}
HOST=$(hostname -s | tr 'A-Z' 'a-z')
fail=0

run_variant() {
  # $1 = mode, $2 = window WxH, $3 = scale, $4 = inset L,T,R,B,
  # $5.. = extra phonehud args (--hud= / --mm= / --layout=)
  local mode="$1" win="$2" scale="$3" inset="$4"
  shift 4
  local extra="$*" sfx=""
  for a in "$@"; do
    case "$a" in
      --hud=*) sfx="${sfx}_h$(awk -v v="${a#--hud=}" 'BEGIN{printf "%03d", v*100+0.5}')" ;;
      --mm=*) sfx="${sfx}_m$(awk -v v="${a#--mm=}" 'BEGIN{printf "%03d", v*100+0.5}')" ;;
      --layout=classic) sfx="${sfx}_classic" ;;
    esac
  done
  local ts="s$(echo "$scale" | tr -d '.')"
  local ins="i0"
  if [ "$inset" != "0,0,0,0" ]; then
    ins="i$(echo "$inset" | tr ',.' '__')"
  fi
  local log
  if [ "$mode" = "desktop" ]; then
    log="Test/out/phonehud_desktop_${HOST}_${ts}.log"
  else
    log="Test/out/phonehud_touch_${win}_${ts}_${ins}${sfx}_${HOST}.log"
  fi
  # UI-mobile P5: the modal / menu tail adds ~6 min a run under
  # software GL; 900 s cut a loaded-NUC run short (rc=124 with a
  # truncated, block-buffered log). Cap only — no verdict change.
  timeout ${PH_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 ${win}x24" "$GODOT" --path . \
    --rendering-driver opengl3 res://Test/phonehud.tscn -- \
    --mode="$mode" --scale="$scale" --win="$win" --inset="$inset" $extra \
    > "$log" 2>&1
  if ! grep -q "PHONEHUD DONE .* fails=0" "$log"; then
    echo "PHONEHUD $mode $win ($scale) inset=$inset $extra FAIL (see $log)"
    fail=1
  else
    echo "PHONEHUD $mode $win ($scale) inset=$inset $extra OK"
  fi
}

if [ "${PH_QUICK:-0}" = "1" ]; then
  run_variant phone 2400x1080 1.00 "0,0,0,0"
  run_variant phone 2400x1080 1.00 "48,0,0,0"
  run_variant desktop 1280x720 1.00 "0,0,0,0"
  exit $fail
fi

WINS="2400x1080 2340x1080 1920x1080"
SCALES="0.70 0.85 1.00 1.50"
INSETS="0,0,0,0 48,0,0,0 0,0,48,0"
for win in $WINS; do
  for s in $SCALES; do
    for ins in $INSETS; do
      run_variant phone "$win" "$s" "$ins"
    done
  done
done
# P7 corners (hudScale x minimapScale) + the D6 classic corner.
run_variant phone 2400x1080 1.00 "0,0,0,0" --hud=0.80 --mm=0.75
run_variant phone 1920x1080 1.50 "48,0,0,0" --hud=0.80 --mm=1.50
run_variant phone 2340x1080 0.85 "0,0,48,0" --hud=1.30 --mm=0.75
run_variant phone 2400x1080 1.50 "0,0,0,0" --hud=1.30 --mm=1.50
run_variant phone 2400x1080 1.00 "0,0,0,0" --layout=classic
run_variant desktop 1280x720 1.00 "0,0,0,0"
exit $fail
