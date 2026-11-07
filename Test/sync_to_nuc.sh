#!/bin/bash
# NUC ritual, VM -> NUC half (cycle 21: kept script).
#
# Delta-syncs the project tree (VM = source of truth) to the
# NUC station copy, then runs the tree-hash parity check
# (Test/check_tree_parity.sh) — the C20.2 stale-file incident
# (a pre-hotfix touch_controls.gd surviving on the NUC) must
# not recur, so a sync is not "done" until parity says OK.
#
# Excludes: build/ (artifacts are built ON the NUC), .tmp/,
# .godot/ (each host keeps its own import cache), Test/out/
# (evidence flows NUC -> VM, pulled back separately).
#
# Usage: bash Test/sync_to_nuc.sh [--no-delete]
#   --no-delete: do not remove NUC files that vanished on the
#   VM (default DOES mirror deletions inside the synced set;
#   Test/out is excluded and never touched either way).
set -u
cd "$(dirname "$0")/.."
NUC=lgh@100.124.16.117
DELETE="--delete"
if [ "${1:-}" = "--no-delete" ]; then DELETE=""; fi
rsync -az $DELETE \
  --exclude 'build/' --exclude '.tmp/' --exclude '.godot/' \
  --exclude 'Test/out/' \
  -e "$PWD/Test/nuc_ssh.sh" ./ "$NUC:~/workspace/sprite-bonk-3d/"
rc=$?
if [ $rc -ne 0 ]; then
  echo "SYNC FAIL: rsync rc=$rc"
  exit $rc
fi
echo "SYNC OK (delta rsync to NUC complete)"
bash Test/check_tree_parity.sh
