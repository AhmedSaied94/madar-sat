#!/usr/bin/env bash
# Add a peer to the WireGuard hub on VPS-1 (FR-022). The keys are generated here, on the host,
# and never enter the repo.
#
# Usage (root on VPS-1): infra/scripts/wg-add-peer.sh <name> [10.8.0.N]
#   <name>  owner-laptop, owner-phone, ci, home-box, ... (lowercase letters, digits, hyphens)
#
# It appends the peer to /etc/wireguard/wg0.conf, applies it to the running wg0, and writes the
# peer's client config to /root/wireguard-peers/<name>.conf (mode 600). Move that file to the
# device (for `ci`, paste it into the WG_CI_CONFIG secret), then delete it with `shred -u`.
set -Eeuo pipefail

die() { printf '[wg-add-peer] error: %s\n' "$*" >&2; exit 1; }

name=${1:-}
address=${2:-}
[[ $name =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]] || die "usage: $0 <name> [10.8.0.N]"
[[ $EUID -eq 0 ]] || die "run as root"

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
conf=/etc/wireguard/wg0.conf
hub_key=/etc/wireguard/wg0.key
env_file=/srv/madar/.env
out_dir=/root/wireguard-peers

[[ -f $conf && -f $hub_key ]] || die "no WireGuard hub here; run bootstrap-vps.sh vps1 first"
if grep -qxF "# peer: $name" "$conf"; then
  die "a peer named $name already exists in $conf"
fi

# Read one value from the env file without executing it.
env_get() { sed -n "s/^$1=//p" "$env_file" | tail -n 1; }
endpoint=$(env_get VPS1_IP)
[[ $endpoint =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || die "VPS1_IP is missing or invalid in $env_file"

used=$(grep -oE '^AllowedIPs *= *10\.8\.0\.[0-9]+/32' "$conf" | grep -oE '10\.8\.0\.[0-9]+' || true)
if [[ -z $address ]]; then
  for i in $(seq 2 254); do
    if ! grep -qxF "10.8.0.$i" <<<"$used"; then
      address=10.8.0.$i
      break
    fi
  done
  [[ -n $address ]] || die "no free address left in 10.8.0.0/24"
fi
if ! [[ $address =~ ^10\.8\.0\.([0-9]{1,3})$ ]] || ((10#${BASH_REMATCH[1]} < 2 || 10#${BASH_REMATCH[1]} > 254)); then
  die "address must be 10.8.0.2 to 10.8.0.254"
fi
if grep -qxF "$address" <<<"$used"; then
  die "$address is already taken"
fi

umask 077
private_key=$(wg genkey)
public_key=$(wg pubkey <<<"$private_key")
preshared_key=$(wg genpsk)
hub_public_key=$(wg pubkey < "$hub_key")

printf '\n[Peer]\n# peer: %s\nPublicKey = %s\nPresharedKey = %s\nAllowedIPs = %s/32\n' \
  "$name" "$public_key" "$preshared_key" "$address" >> "$conf"

if wg show wg0 >/dev/null 2>&1; then
  wg set wg0 peer "$public_key" preshared-key <(printf '%s\n' "$preshared_key") allowed-ips "$address/32"
fi

install -d -m 700 "$out_dir"
# shellcheck disable=SC2016 # envsubst takes the variable names literally
PEER_PRIVATE_KEY=$private_key PEER_PRESHARED_KEY=$preshared_key PEER_ADDRESS=$address \
  HUB_PUBLIC_KEY=$hub_public_key HUB_ENDPOINT=$endpoint \
  envsubst '${PEER_PRIVATE_KEY} ${PEER_PRESHARED_KEY} ${PEER_ADDRESS} ${HUB_PUBLIC_KEY} ${HUB_ENDPOINT}' \
  < "$infra/wireguard/peer.conf.tmpl" > "$out_dir/$name.conf"

echo "[wg-add-peer] added $name as $address"
echo "[wg-add-peer] client config: $out_dir/$name.conf (move it to the device, then: shred -u $out_dir/$name.conf)"
