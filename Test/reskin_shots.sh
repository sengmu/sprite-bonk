#!/bin/bash
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p Test/out .tmp/reskin_shots_data .tmp/reskin_shots_config .tmp/reskin_shots_cache
export XDG_DATA_HOME="$PWD/.tmp/reskin_shots_data" XDG_CONFIG_HOME="$PWD/.tmp/reskin_shots_config" XDG_CACHE_HOME="$PWD/.tmp/reskin_shots_cache" TMPDIR="$PWD/.tmp"
G=${GODOT:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}
rm -f Test/out/reskin_release_shots.done
timeout 1200 xvfb-run -a -s '-screen 0 2400x1080x24' "$G" --path . --rendering-driver opengl3 res://Test/reskin_shot.tscn -- --tag=reskin_release > Test/out/reskin_release_shots.log 2>&1
rc=$?
grep -q "SCRIPT ERROR" Test/out/reskin_release_shots.log && rc=1
grep -q "RESKIN SHOT DONE" Test/out/reskin_release_shots.log || rc=1
echo "rc=$rc ALLDONE" > Test/out/reskin_release_shots.done
exit "$rc"
