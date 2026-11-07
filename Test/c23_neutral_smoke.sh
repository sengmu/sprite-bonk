#!/bin/bash
# C23: verify the existing Linux export from outside the source tree.
set -u
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
LOG="$PWD/Test/out/c23_neutral_smoke.log"
DONE="$PWD/Test/out/c23_neutral_smoke.done"
: > "$LOG"
rm -f "$DONE"
neutral_dir=$(mktemp -d /tmp/c23-neutral.XXXXXX) || exit 1
cp -a build/linux/. "$neutral_dir/" || { echo 'rc=1 copy failed' > "$DONE"; exit 1; }
sha256sum build/linux/SpriteBonk.x86_64 build/linux/SpriteBonk.pck >> "$LOG"
echo "CWD=$neutral_dir" >> "$LOG"
cd "$neutral_dir" || exit 1
setsid xvfb-run -a -s '-screen 0 2400x1080x24' ./SpriteBonk.x86_64 >> "$LOG" 2>&1 &
smoke_pid=$!
alive=0
for tick in $(seq 1 75); do
  kill -0 "$smoke_pid" 2>/dev/null || break
  [ "$tick" -eq 75 ] && alive=1
  sleep 1
done
[ "$alive" -eq 1 ] && echo NEUTRAL_ALIVE_AT_75S >> "$LOG"
kill -TERM -"$smoke_pid" 2>/dev/null || true
wait "$smoke_pid" 2>/dev/null || true
errs=$(grep -c 'SCRIPT ERROR' "$LOG" || true)
rc=0
[ "$alive" -eq 1 ] && [ "$errs" -eq 0 ] || rc=1
echo "NEUTRAL_END rc=$rc" >> "$LOG"
# Remove only this script's unique scratch copy.
rm -rf "$neutral_dir"
echo "rc=$rc alive=$alive script_errors=$errs ALLDONE" > "$DONE"
exit "$rc"
