#!/bin/bash
cd ~/workspace/sprite-bonk-3d
G=~/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
echo "START $(date -Is) HEAD $(git rev-parse --short HEAD) plus uncommitted bisect patch" > Test/out/u3_fix2_probe.done
timeout 1500 xvfb-run -a -s "-screen 0 2400x1080x24" $G --path . --rendering-driver opengl3 res://Test/phonehud.tscn -- --mode=phone --scale=1.00 --win=2400x1080 --inset=0,0,0,0 > Test/out/u3_fix2_probe.log 2>&1
echo "ALLDONE $(date -Is)" >> Test/out/u3_fix2_probe.done
