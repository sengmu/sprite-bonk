#!/bin/bash
set -u
cd "$(dirname "$0")/.." || exit 1
bash Test/assets_shots.sh
shot_rc=$?
bash Test/assets_batch.sh
batch_rc=$?
echo "shots rc=$shot_rc batch rc=$batch_rc ALLDONE" > Test/out/assets_run.done
