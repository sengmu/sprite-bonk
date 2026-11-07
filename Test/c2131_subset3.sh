#!/bin/bash
# Cycle 21.3.1 subset v3: the combos that failed or
# were stressed by the v2 fit rules (1920 all regimes,
# 2400 cluster-bound case, desktop).
cd "$HOME/workspace/sprite-bonk-3d" || exit 1
GODOT="$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64"
PROFILE="$HOME/.local/share/godot/app_userdata/SpriteBonk 3D/profile.json"
cp "$PROFILE" /tmp/c2131_profile_backup3.json 2>/dev/null
: > "$HOME/c2131_subset3.done"
run() {
  local w="$1" s="$2" ins="$3" mode="$4"
  local tag="${w}x1080_s$(echo "$s" | tr -d .)_i$(echo "$ins" | tr , _)"
  [ "$mode" = desktop ] && tag="desktop_$ins"
  "$GODOT" --headless --path . --resolution "${w}x1080" \
    res://Test/phonehud.tscn -- --mode="$mode" \
    --touchscale="$s" --inset="$ins" \
    > "Test/out/c2131_s3_${tag}_ubantu.log" 2>&1
  echo "$w $s $ins $mode rc=$?" >> "$HOME/c2131_subset3.done"
  cp /tmp/c2131_profile_backup3.json "$PROFILE" 2>/dev/null
}
run 1920 0.70 0,0,0,0 phone
run 1920 0.85 0,0,0,0 phone
run 1920 1.50 0,0,0,0 phone
run 1920 1.50 48,0,0,0 phone
run 1920 1.50 0,0,48,0 phone
run 2400 1.50 48,0,0,0 phone
run 2400 1.50 0,0,0,0 phone
run 0 1.00 0,0,0,0 desktop
echo ALLDONE >> "$HOME/c2131_subset3.done"
