#!/bin/bash
# ssh to the NUC station through the Tailscale proxy
# (kept wrapper so rsync -e and other tools get the full
# option set without quoting roulette). Usage: as ssh.
exec ssh -o ProxyCommand="python3 $HOME/workspace/tools/tsproxy.py 100.124.16.117 22" \
  -o UserKnownHostsFile="$HOME/workspace/tools/known_nuc" \
  -i "$HOME/.ssh/id_ed25519" -o BatchMode=yes -o ConnectTimeout=15 "$@"
