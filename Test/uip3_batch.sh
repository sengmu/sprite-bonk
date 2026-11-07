#!/bin/bash
# UI-mobile P3 verification batch (NUC, detached via
# setsid): parse gate -> .godot purge + reimport -> class
# cache gate -> phonehud full matrix -> full suite ->
# bootsmoke. No APK in this phase.
# Step RCs land in Test/out/uip3_batch.done as they
# complete; per-variant gate logs are copied to uip3_-
# prefixed names for the pull.
#
# Template: uip2_batch.sh (P3 adds ult_gauge / ui_medallion /
# profile to the parse gate; the matrix now carries the P7
# corners + the classic corner).
# Hardening (P1 recovery + P2): refuse to start while any
# Godot runs — matched on argv0 only (an unanchored -f
# pattern also matches the launching ssh session's own
# command line and false-aborts); import / suite are time-
# boxed and log-capped; a --check-only parse gate runs
# first (a parse error otherwise idles every gate run to
# its 900 s timeout with an empty, block-buffered log).
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
G="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
mkdir -p .tmp Test/out; export TMPDIR="$PWD/.tmp"
DONE=Test/out/uip3_batch.done
: > "$DONE"
echo "start $(date -Is)" >> "$DONE"
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
rm -rf .godot
timeout 900 "$G" --headless --import --path . 2>&1 \
  | head -c 20000000 > Test/out/uip3_import_ubantu.log
echo "import rc=${PIPESTATUS[0]}" >> "$DONE"
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  echo "ABORT: import produced no class cache" >> "$DONE"
  exit 1
fi
bash Test/check_class_cache.sh > Test/out/uip3_class_cache_ubantu.log 2>&1
echo "class_cache rc=$?" >> "$DONE"
rm -f Test/out/mobile_p3_*.png Test/out/phonehud_touch_*_ubantu.log Test/out/phonehud_desktop_ubantu_*.log
bash Test/check_phonehud.sh > Test/out/uip3_matrix_ubantu.log 2>&1
echo "matrix rc=$?" >> "$DONE"
for f in Test/out/phonehud_touch_*_ubantu.log Test/out/phonehud_desktop_ubantu_*.log; do
  [ -f "$f" ] && cp "$f" "Test/out/uip3_$(basename "$f")"
done
timeout 2400 xvfb-run -a -s "-screen 0 2400x1080x24" "$G" \
  --path . --rendering-driver opengl3 res://Test/harness.tscn \
  -- --mode=cycle9 2>&1 | head -c 20000000 > Test/out/uip3_suite_ubantu.log
echo "suite rc=${PIPESTATUS[0]}" >> "$DONE"
bash Test/check_bootsmoke.sh > Test/out/uip3_bootsmoke_wrap_ubantu.log 2>&1
echo "bootsmoke rc=$?" >> "$DONE"
cp Test/out/bootsmoke_ubantu.log Test/out/uip3_bootsmoke_ubantu.log 2>/dev/null
echo "ALLDONE $(date -Is)" >> "$DONE"
