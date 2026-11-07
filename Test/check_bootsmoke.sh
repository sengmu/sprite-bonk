#!/bin/bash
# Standing boot-smoke for the SHIPPED Linux export
# (cycle 20.2: kept script — this replaces the ad-hoc
# NUC-side wrapper the C20.1 pass used, whose ALIVE marker
# existed in no file the auditors could inspect).
#
# Exports the Linux preset, boots the exported binary
# under Xvfb, and requires the process to still be alive
# after WAIT seconds (default 75) with zero SCRIPT ERROR
# lines. Emits into the per-host log:
#   EXPORT_DONE rc=<n>
#   BOOTSMOKE ALIVE_AT_<WAIT>S    (only if actually alive)
#   BOOTSMOKE END
# Env: WAIT=<sec> (default 75), BOOTSMOKE_SKIP_EXPORT=1
# reuses the existing build/linux binary.
# Run from the project root:  bash Test/check_bootsmoke.sh
set -u
cd "$(dirname "$0")/.."
mkdir -p .tmp Test/out build/linux
export TMPDIR="${TMPDIR:-$PWD/.tmp}"
GODOT=${GODOT:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}
HOST=$(hostname -s | tr 'A-Z' 'a-z')
WAIT=${WAIT:-75}
LOG="Test/out/bootsmoke_${HOST}.log"
BIN="build/linux/SpriteBonk.x86_64"
: > "$LOG"

if [ "${BOOTSMOKE_SKIP_EXPORT:-0}" != "1" ]; then
  "$GODOT" --headless --export-release "Linux" "$BIN" >> "$LOG" 2>&1
  echo "EXPORT_DONE rc=$?" >> "$LOG"
fi
if [ ! -x "$BIN" ]; then
  echo "BOOTSMOKE FAIL: no Linux binary at $BIN" | tee -a "$LOG"
  echo "BOOTSMOKE END" >> "$LOG"
  exit 1
fi

setsid xvfb-run -a -s "-screen 0 2400x1080x24" "$BIN" >> "$LOG" 2>&1 &
BPID=$!
alive=0
for i in $(seq 1 "$WAIT"); do
  if ! kill -0 "$BPID" 2>/dev/null; then
    break
  fi
  if [ "$i" -eq "$WAIT" ]; then
    alive=1
  fi
  sleep 1
done
if [ "$alive" -eq 1 ]; then
  echo "BOOTSMOKE ALIVE_AT_${WAIT}S" >> "$LOG"
fi
kill -TERM -"$BPID" 2>/dev/null
wait "$BPID" 2>/dev/null
errs=$(grep -c "SCRIPT ERROR" "$LOG" || true)
echo "BOOTSMOKE END" >> "$LOG"
if [ "$alive" -ne 1 ]; then
  echo "BOOTSMOKE FAIL: process died before ${WAIT}s (see $LOG)"
  exit 1
fi
if [ "$errs" -ne 0 ]; then
  echo "BOOTSMOKE FAIL: $errs SCRIPT ERROR lines (see $LOG)"
  exit 1
fi
echo "BOOTSMOKE OK (alive at ${WAIT}s, 0 script errors; log $LOG)"
