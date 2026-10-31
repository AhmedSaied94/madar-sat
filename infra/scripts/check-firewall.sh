#!/usr/bin/env bash
# Print the active and the persisted firewall rules (IPv4 and IPv6), and fail if they differ.
#
# Usage (root): infra/scripts/check-firewall.sh [--role vps1|vps2]
#   The role decides which extra rules must be present; without --role it is read from
#   /etc/madar/host-role, which bootstrap-vps.sh writes. VPS-2 has its own expectations: VPS-1's
#   Redis rule is not there, and its absence is not a failure (B2-R1-6).
#
# Usage (no root, CI): infra/scripts/check-firewall.sh --role <role> --expectations <file>
#   Runs the role's rule checks against a saved `iptables-save` file.
#
# The persisted files (/etc/iptables/rules.v4, rules.v6) are loaded into a scratch network
# namespace first, so both sides are printed by iptables-save in the same canonical form. Docker's
# own chains and its jumps in FORWARD are left out: Docker recreates them on every start and they
# are never persisted. Exit codes: 0 same, 1 different, 2 usage or setup error.
set -Eeuo pipefail

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

# The rules that matter more than the active/persisted diff (T082, research R21). What "correct"
# means depends on the host: VPS-1 publishes Postgres and Redis, VPS-2 publishes nothing.
check_expectations() {
  local active=$1 host_role=$2 status=0
  # Both hosts: nothing published on 127.0.0.1 may be reached from outside.
  if ! grep -qE '^-A DOCKER-USER -m conntrack --ctorigdst 127\.0\.0\.0/8 --ctdir ORIGINAL -j DROP$' <<<"$active"; then
    echo "IPv4: the loopback DOCKER-USER rule is missing" >&2
    status=1
  fi
  if [[ $host_role == vps1 ]]; then
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
  else
    # VPS-2 is reached by jumping through VPS-1: it must not publish Redis, Postgres or api-admin,
    # and it must not accept SSH from the internet.
    if grep -qE '^-A (INPUT|DOCKER-USER) .*--dport (6379|5432|8001) .*-j ACCEPT$' <<<"$active"; then
      echo "IPv4: VPS-2 accepts 6379, 5432 or 8001; reach it by jumping through VPS-1" >&2
      status=1
    fi
    if grep -qE '^-A INPUT -s 0\.0\.0\.0/0 .*--dport 22 .*-j ACCEPT$' <<<"$active"; then
      echo "IPv4: VPS-2 accepts SSH from anywhere; only VPS-1 may" >&2
      status=1
    fi
  fi
  ((status == 0)) && echo "IPv4: the $host_role expectations are in place"
  return "$status"
}

role=
expectations=
while (($#)); do
  case $1 in
    --role) role=${2:-}; shift 2 ;;
    --role=*) role=${1#*=}; shift ;;
    --expectations) expectations=${2:-}; shift 2 ;;
    --expectations=*) expectations=${1#*=}; shift ;;
    *)
      echo "check-firewall: usage: $0 [--role vps1|vps2] [--expectations <file>]" >&2
      exit 2
      ;;
  esac
done
[[ -n $role ]] || role=$(cat /etc/madar/host-role 2>/dev/null || true)
if [[ $role != vps1 && $role != vps2 ]]; then
  echo "check-firewall: pass --role vps1|vps2 (or write /etc/madar/host-role)" >&2
  exit 2
fi

if [[ -n $expectations ]]; then
  [[ -r $expectations ]] || { echo "check-firewall: $expectations is not readable" >&2; exit 2; }
  check_expectations "$(normalize < "$expectations")" "$role"
  exit $?
fi

if [[ $EUID -ne 0 ]]; then
  echo "check-firewall: run as root" >&2
  exit 2
fi

ns="madar-fwcheck-$$"
# shellcheck disable=SC2329 # called by the EXIT trap below, which SC2329 doesn't count
cleanup() { ip netns delete "$ns" 2>/dev/null || true; }
trap cleanup EXIT
ip netns add "$ns"

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

check_expectations "$(iptables-save -t filter | normalize)" "$role" || status=1
exit "$status"
