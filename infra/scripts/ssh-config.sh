#!/usr/bin/env bash
# Write the ssh config CI uses to reach VPS-1 and, through it, VPS-2 (B2-R1-4).
#
# Usage: infra/scripts/ssh-config.sh <dir> <vps2-host>
#
#   <dir>        holds the deploy key (`id`) and `known_hosts`; the config is written to <dir>/config
#   <vps2-host>  VPS-2's VCN IP; when empty, the vps2 block is left out
#
# `ssh -i key -J deploy@10.8.0.1` gives the jump host none of the command-line options, so the jump
# failed with "Permission denied (publickey)". A config file applies the identity, the pinned
# known_hosts and BatchMode to both hops; callers use `ssh -F <dir>/config vps1|vps2`.
set -Eeuo pipefail

dir=${1:?usage: ssh-config.sh <dir> <vps2-host>}
vps2=${2-}
config=$dir/config

block() {
  cat <<EOF
  User deploy
  IdentityFile $dir/id
  IdentitiesOnly yes
  BatchMode yes
  StrictHostKeyChecking yes
  UserKnownHostsFile $dir/known_hosts
  ConnectTimeout 20
  ServerAliveInterval 15
EOF
}

{
  printf 'Host vps1\n  HostName 10.8.0.1\n'
  block
  if [[ -n $vps2 ]]; then
    printf '\nHost vps2\n  HostName %s\n  ProxyJump vps1\n' "$vps2"
    block
  fi
} > "$config"
chmod 600 "$config"
