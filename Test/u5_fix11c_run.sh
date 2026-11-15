#!/bin/bash
# U5 fix11c batch: re-verify the leaves are gone from the ribbon after
# the ribbon texture was properly reimported (fix11b captures are VOID:
# the .ctex had been deleted and the game-run never reimports, so the
# ribbon drew nothing at all - see ledger fix11b verdict). Same legs
# and expectations as fix11b: 2400 s100 then 2340 s100, FAIL=0 each;
# then compare the victory captures vs U5 reference.
# Precondition (verified before start): .godot/imported/ribbon_green.png-8085d68b8954e2b82932ced920e37489.ctex
# exists and its .md5 sidecar records source_md5 7b4c7732 (fix11 texture).
cd ~/workspace/sprite-bonk-3d
mkdir -p .tmp Test/out
export TMPDIR=$PWD/.tmp
G=$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
DONE=Test/out/u5_fix11c.done
: > "$DONE"
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD)" >> "$DONE"
timeout 1500 xvfb-run -a -s "-screen 0 2400x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 --result=victory > Test/out/u5_fix11c_phonehud_2400.log 2>&1
echo "phonehud 2400 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u5_fix11c_phonehud_2400.log >> "$DONE" 2>/dev/null
timeout 1500 xvfb-run -a -s "-screen 0 2340x1080x24" "$G" --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2340x1080 --inset=0,0,0,0 --result=victory > Test/out/u5_fix11c_phonehud_2340.log 2>&1
echo "phonehud 2340 rc=$?" >> "$DONE"
grep "PHONEHUD DONE" Test/out/u5_fix11c_phonehud_2340.log >> "$DONE" 2>/dev/null
echo "ALLDONE $(date -Is)" >> "$DONE"
