#!/bin/bash
# Standing export gate (hotfix 2026-10-25 — the blue-screen APK).
#
# Root cause it guards: backup copies of production scripts left in
# Test/out/zbak/ still declared `class_name ModelRig` / `class_name
# Player`. The editor's global script class cache resolved those
# class names to the backup paths; exports exclude Test/*, so the
# exported build's cache pointed at files that don't exist in the
# package -> world.gd failed to parse ("Could not find script for
# class ModelRig") -> main scene booted scriptless -> pure clear
# color on device, while the editor/harness (where the backups
# exist on disk) booted green.
#
# Invariants enforced:
#   1. No .gd file anywhere outside scripts/ declares a class_name
#      (Test harness scripts included — they must stay anonymous).
#   2. No .gd files live under Test/out/ (scratch output dir).
#   3. Every path in .godot/global_script_class_cache.cfg points
#      under res://scripts/ and exists on disk.
# Run from the project root. Exit non-zero on any violation.
set -u
cd "$(dirname "$0")/.."
fail=0

stray=$(grep -rl "^class_name" --include="*.gd" . 2>/dev/null \
  | grep -v "^\./scripts/" | grep -v "^\./\.godot/")
if [ -n "$stray" ]; then
  echo "GATE FAIL: class_name declared outside scripts/:"
  echo "$stray"
  fail=1
fi

if find Test/out -name "*.gd" | grep -q .; then
  echo "GATE FAIL: .gd files present under Test/out/:"
  find Test/out -name "*.gd"
  fail=1
fi

cache=".godot/global_script_class_cache.cfg"
if [ ! -f "$cache" ]; then
  echo "GATE FAIL: $cache missing (run a Godot import first)"
  fail=1
else
  for p in $(grep -o '"path": "[^"]*"' "$cache" | sed 's/"path": "//; s/"$//'); do
    case "$p" in
      res://scripts/*) ;;
      *) echo "GATE FAIL: class cache path outside scripts/: $p"; fail=1 ;;
    esac
    if [ ! -f "${p#res://}" ]; then
      echo "GATE FAIL: class cache path does not exist on disk: $p"
      fail=1
    fi
  done
fi

if [ "$fail" = 0 ]; then
  echo "GATE OK: class cache clean, no stray class_name, no Test/out scripts"
fi
exit $fail
