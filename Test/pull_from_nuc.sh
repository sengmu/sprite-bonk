#!/bin/bash
# NUC ritual, NUC -> VM half (kept script; counterpart of
# Test/sync_to_nuc.sh).
#
# Pulls evidence logs from the NUC station's Test/out back
# to the VM and VERIFIES them before claiming success.
#
# Why this exists (cycle 21.3, audit N6): the ad-hoc pull
# used in 21.3 wrote Test/out/c213_pull.done claiming
# RC=0 while its rsync had actually died with error 255
# (connection closed) — the NUC gate-matrix and suite
# logs never arrived, and two headline DIFF numbers were
# left resting on the record alone. The .done file in
# that flow was written by the launcher regardless of
# the transfer result.
#
# Honesty rule implemented here: the .done file is
# DELETED at start (a stale success can never survive a
# failed run) and is written ONLY AFTER verification —
# every file in the NUC-side manifest must exist locally
# with the exact byte size. The .done records the
# verified file count and byte total on success
# (RC=0 files=N bytes=B), or the failure (RC=<n>) with
# the unverified entries named in the pull log.
#
# Usage:
#   bash Test/pull_from_nuc.sh <tag> <glob> [<glob> ...]
# Globs match NUC-side Test/out basenames. Writes
# Test/out/<tag>_pull.log and Test/out/<tag>_pull.done.
set -u
cd "$(dirname "$0")/.."
if [ $# -lt 2 ]; then
  echo "usage: pull_from_nuc.sh <tag> <glob> [<glob> ...]" >&2
  exit 2
fi
TAG="$1"; shift
NUC=lgh@100.124.16.117
SSH="$PWD/Test/nuc_ssh.sh"
LOG="Test/out/${TAG}_pull.log"
DONE="Test/out/${TAG}_pull.done"
mkdir -p Test/out
rm -f "$DONE"
: > "$LOG"

fail_done() {  # $1 = rc, $2 = reason
  echo "RC=$1 $2" >> "$LOG"
  echo "RC=$1" > "$DONE"
  echo "PULL FAIL rc=$1: $2 (see $LOG)"
  exit "$1"
}

# --- 1. NUC-side manifest (name + size), with retries
# (the tsproxy route flaps; a failed fetch is not yet a
# failed pull, but it is never silently treated as one).
MANIFEST=".tmp/${TAG}_manifest.txt"
mkdir -p .tmp
remote_cmd="cd ~/workspace/sprite-bonk-3d/Test/out && find . -maxdepth 1 -type f \\("
sep=""
for g in "$@"; do
  remote_cmd="$remote_cmd $sep-name '$g'"
  sep="-o "
done
remote_cmd="$remote_cmd \\) -printf '%f %s\n' | sort"
got=""
for i in 1 2 3 4 5; do
  if timeout 120 "$SSH" "$NUC" "$remote_cmd" > "$MANIFEST" 2>>"$LOG"; then
    got=1; break
  fi
  echo "manifest attempt $i failed, retrying" >> "$LOG"
  sleep 5
done
[ -n "$got" ] || fail_done 3 "could not fetch NUC manifest"
[ -s "$MANIFEST" ] || fail_done 4 "manifest empty (no NUC files match)"
echo "--- NUC manifest ($(wc -l < "$MANIFEST") files) ---" >> "$LOG"
cat "$MANIFEST" >> "$LOG"

# --- 2. rsync the manifest files down, with retries.
LIST=".tmp/${TAG}_files.txt"
cut -d' ' -f1 "$MANIFEST" > "$LIST"
rc=1
for i in 1 2 3 4 5; do
  # Absolute remote path: in the pull direction rsync
  # does NOT expand a leading ~/ on the source spec
  # (it tried /home/lgh/~/workspace/... and died).
  # -rltz, NOT -a: archive mode also preserves owner,
  # and chown to the NUC uid is not permitted on the VM
  # receiver (rsync exits 23 although every byte landed).
  # Contents + mtimes are what evidence needs.
  rsync -rltz --files-from="$LIST" -e "$SSH" \
    "$NUC:/home/lgh/workspace/sprite-bonk-3d/Test/out/" Test/out/ >> "$LOG" 2>&1
  rc=$?
  [ $rc -eq 0 ] && break
  echo "rsync attempt $i rc=$rc, retrying" >> "$LOG"
  sleep 5
done
[ $rc -eq 0 ] || fail_done $rc "rsync failed after retries"

# --- 3. Verify BEFORE any success claim: every manifest
# entry present locally at the exact size.
bad=0; total=0; count=0
while read -r name size; do
  count=$((count + 1)); total=$((total + size))
  if [ ! -f "Test/out/$name" ]; then
    echo "MISSING $name" >> "$LOG"; bad=$((bad + 1)); continue
  fi
  local_size=$(stat -c %s "Test/out/$name")
  if [ "$local_size" != "$size" ]; then
    echo "SIZE MISMATCH $name nuc=$size vm=$local_size" >> "$LOG"
    bad=$((bad + 1))
  fi
done < "$MANIFEST"
if [ $bad -ne 0 ]; then
  fail_done 5 "verification failed for $bad of $count files"
fi
echo "VERIFIED files=$count bytes=$total" >> "$LOG"
echo "RC=0 files=$count bytes=$total" > "$DONE"
echo "PULL OK: $count files, $total bytes, verified (see $LOG)"
