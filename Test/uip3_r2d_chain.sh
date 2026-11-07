#!/bin/bash
# UI-mobile P3 fix round 2, class D close-out (NUC, detached via
# setsid): combos 2 + 3 once on the diagnostic subclass (frame
# trace) and twice on the plain gate, then the it3 nine corners;
# only if every one of those runs is fails=0 rc=0 does it go on
# to the final Test/uip3_batch.sh. Progress: uip3_r2d_chain.done.
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
C=Test/out/uip3_r2d_chain.done
: > "$C"
step() {  # $1 tag, $2 keys, [$3 scene]
  SCENE=${3:-res://Test/phonehud.tscn} bash Test/uip3_r2.sh "$1" "$2"
  echo "$1 $(date -Is)" >> "$C"
  cat "Test/out/uip3_$1.done" >> "$C"
  grep -q '^ALLDONE' "Test/out/uip3_$1.done" || return 1
  ! grep -E '^[a-z0-9] (phone|desktop) ' "Test/out/uip3_$1.done" | grep -vq 'rc=0 PHONEHUD DONE checks=[0-9]* fails=0$'
}
ok=1
step r2d1 23 res://Test/diag/p3r2_diag.tscn || ok=0
step r2d2 23 || ok=0
step r2d3 23 || ok=0
step r2d4 abcpefgqd || ok=0
if [ "$ok" = 1 ]; then
  echo "singles green -> final batch $(date -Is)" >> "$C"
  bash Test/uip3_batch.sh
  echo "batch exit=$? $(date -Is)" >> "$C"
else
  echo "STOP: a single run was not green; batch not started" >> "$C"
fi
echo CHAINDONE >> "$C"
