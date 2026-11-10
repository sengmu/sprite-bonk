#!/bin/bash
# Tree-hash parity check, VM vs NUC (cycle 21: kept script;
# chore from the C20.2 re-audit follow-ups).
#
# Compares sha256 manifests of scripts/ + Test/ + assets/ui/ (excluding
# Test/out/, which is per-host evidence) between this VM tree
# (source of truth) and the NUC station copy. Any file that
# differs, is missing on either side, or exists ONLY on the
# NUC (stale survivor — the C20.2 failure mode) is listed.
#
# Log: Test/out/tree_parity_<vmhost>.log with a final
#   TREE PARITY OK (n files)   or   TREE PARITY FAIL (k diffs)
# Exit code 0 iff parity holds.
set -u
cd "$(dirname "$0")/.."
NUC=lgh@100.124.16.117
HOST=$(hostname -s | tr 'A-Z' 'a-z')
LOG="Test/out/tree_parity_${HOST}.log"
mkdir -p Test/out .tmp
export TMPDIR="${TMPDIR:-$PWD/.tmp}"
MANIFEST_CMD='find scripts Test assets/ui -type f ! -path "Test/out/*" ! -name "*.uid" -print0 | sort -z | xargs -0 sha256sum | sed "s| \./| |" | sort -k2'
eval "$MANIFEST_CMD" > .tmp/parity_local.txt
ssh -o ProxyCommand="python3 $HOME/workspace/tools/tsproxy.py 100.124.16.117 22" \
    -o UserKnownHostsFile="$HOME/workspace/tools/known_nuc" \
    -i "$HOME/.ssh/id_ed25519" -o BatchMode=yes -o ConnectTimeout=15 \
    "$NUC" "cd ~/workspace/sprite-bonk-3d && $MANIFEST_CMD" > .tmp/parity_nuc.txt 2>.tmp/parity_nuc.err
if [ ! -s .tmp/parity_nuc.txt ]; then
  { echo "TREE PARITY FAIL: NUC manifest empty (ssh error?)"; cat .tmp/parity_nuc.err; } | tee "$LOG"
  exit 1
fi
n_local=$(wc -l < .tmp/parity_local.txt)
n_nuc=$(wc -l < .tmp/parity_nuc.txt)
diffs=$(diff .tmp/parity_local.txt .tmp/parity_nuc.txt | grep -c '^[<>]' || true)
{
  echo "tree parity $(date '+%Y-%m-%d %H:%M:%S %Z'): local files=$n_local nuc files=$n_nuc diffs=$diffs"
  if [ "$diffs" -ne 0 ]; then
    echo "--- diff (< VM only/VM hash, > NUC only/NUC hash) ---"
    diff .tmp/parity_local.txt .tmp/parity_nuc.txt | head -100
    echo "TREE PARITY FAIL ($diffs diffs)"
  else
    echo "TREE PARITY OK ($n_local files)"
  fi
} > "$LOG"
cat "$LOG"
[ "$diffs" -eq 0 ]
