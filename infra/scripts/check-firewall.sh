#!/usr/bin/env bash
# Print the active and the persisted firewall rules (IPv4 and IPv6), and fail if they differ.
#
# Usage (root): infra/scripts/check-firewall.sh
#
# The persisted files (/etc/iptables/rules.v4, rules.v6) are loaded into a scratch network
# namespace first, so both sides are printed by iptables-save in the same canonical form. Docker's
# own chains and its jumps in FORWARD are left out: Docker recreates them on every start and they
# are never persisted. Exit codes: 0 same, 1 different, 2 usage or setup error.
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "check-firewall: run as root" >&2
  exit 2
fi

ns="madar-fwcheck-$$"
# shellcheck disable=SC2329 # called by the EXIT trap below, which SC2329 doesn't count
cleanup() { ip netns delete "$ns" 2>/dev/null || true; }
trap cleanup EXIT
ip netns add "$ns"

# Keep the filter-table chains and rules this repo owns, in order, without packet counters.
normalize() {
  awk '
    /^:/ {
      if ($1 ~ /^:DOCKER/ && $1 != ":DOCKER-USER") next
      sub(/ \[[0-9]+:[0-9]+\]$/, "")
      print
      next
    }
    /^-A / {
      if ($2 ~ /^DOCKER/ && $2 != "DOCKER-USER") next
      if ($0 == "-A DOCKER-USER -j RETURN") next
      if ($2 == "FORWARD" && $0 ~ /DOCKER|docker0|br-[0-9a-f]+/) next
      print
    }'
}

# compare <label> <save-cmd> <restore-cmd> <persisted-file>
compare() {
  local label=$1 save=$2 restore=$3 file=$4 active persisted
  if [[ ! -r $file ]]; then
    echo "check-firewall: $file is missing" >&2
    return 1
  fi
  active=$("$save" -t filter | normalize)
  ip netns exec "$ns" "$restore" < "$file"
  persisted=$(ip netns exec "$ns" "$save" -t filter | normalize)

  printf '== %s active ==\n%s\n\n== %s persisted (%s) ==\n%s\n\n' "$label" "$active" "$label" "$file" "$persisted"
  if [[ $active == "$persisted" ]]; then
    echo "$label: active rules match $file"
    return 0
  fi
  echo "$label: active rules DIFFER from $file:"
  diff -u <(printf '%s\n' "$persisted") <(printf '%s\n' "$active") || true
  return 1
}

status=0
compare IPv4 iptables-save iptables-restore /etc/iptables/rules.v4 || status=1
echo
compare IPv6 ip6tables-save ip6tables-restore /etc/iptables/rules.v6 || status=1
echo

# Two rules matter more than the active/persisted diff (T082, research R21): Redis on wg0 exists
# only as a DOCKER-USER rule limited to the home box, and no INPUT rule accepts 6379 from every
# wg0 peer any more.
check_expectations() {
  local active=$1 status=0
  if ! grep -qE '^-A DOCKER-USER ! -s [0-9.]+/32 -p tcp -m conntrack --ctorigdst 10\.8\.0\.1 --ctorigdstport 6379 --ctdir ORIGINAL -j DROP$' <<<"$active"; then
    echo "IPv4: the home box's Redis rule is missing (DOCKER-USER, 10.8.0.1:6379, one source /32)" >&2
    status=1
  fi
  if grep -qE '^-A INPUT .*-i wg0 .*--dport 6379 .*-j ACCEPT$' <<<"$active"; then
    echo "IPv4: INPUT still accepts 6379 from every wg0 peer; only the home box may reach Redis" >&2
    status=1
  fi
  if grep -qE '^-A INPUT .*-s 10\.8\.0\.0/.*--dport 6379 .*-j ACCEPT$' <<<"$active"; then
    echo "IPv4: an INPUT rule accepts 6379 from the whole wg0 subnet" >&2
    status=1
  fi
  ((status == 0)) && echo "IPv4: the home-box Redis rules are in place"
  return "$status"
}

check_expectations "$(iptables-save -t filter | normalize)" || status=1
exit "$status"
