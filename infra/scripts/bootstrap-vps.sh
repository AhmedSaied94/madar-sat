#!/usr/bin/env bash
# Prepare an OCI Ampere (Ubuntu, arm64) host for Madar Sat. Idempotent: safe to re-run after any
# change (research R12).
#
# Usage (root, from a checkout of this repo on the host):
#   infra/scripts/bootstrap-vps.sh <vps1|vps2> [--serial-console-tested]
#
# It installs Docker and WireGuard, creates the deploy user (docker group, SSH key only) and the
# /srv folders, and applies infra/firewall/<role>.rules. On VPS-1 it also sets up the WireGuard hub
# and makes docker.service wait for wg0, so api-admin's 10.8.0.1 binding exists when Docker starts.
#
# Public SSH stays open until the OCI serial console has been tested on this host (FR-023): pass
# --serial-console-tested or answer the prompt. On VPS-1 it also stays open until a WireGuard peer
# has completed a handshake, so you can always get back in over wg0.
set -Eeuo pipefail

usage() { echo "usage: $0 <vps1|vps2> [--serial-console-tested]" >&2; exit 2; }
log() { printf '[bootstrap] %s\n' "$*"; }
warn() { printf '[bootstrap] WARNING: %s\n' "$*" >&2; }
die() { printf '[bootstrap] error: %s\n' "$*" >&2; exit 1; }

role=${1:-}
[[ $role == vps1 || $role == vps2 ]] || usage
shift
serial_flag=no
while (($#)); do
  case $1 in
    --serial-console-tested) serial_flag=yes ;;
    *) usage ;;
  esac
  shift
done
[[ $EUID -eq 0 ]] || die "run as root (sudo)"

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file=/srv/madar/.env
state_dir=/etc/madar
serial_mark=$state_dir/serial-console-tested
oci_rules_backup=/etc/iptables/rules.v4.oci-original
# The non-root user of backend/Dockerfile: the one-off `cli` container writes media and reports.
app_uid=10001
# The `redis` user's gid inside redis:7.4.12. The rendered ACL is 640 and belongs to this group, so
# the server can read it; deploy writes it, so it must belong to the group (B2-R1-1).
acl_gid=999
acl_group=redis-acl
public_ssh_rule='-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT'
ipv4_re='^[0-9]{1,3}(\.[0-9]{1,3}){3}$'
# The fake values of infra/compose/example.env.
placeholder_re='(example|changeme|your-firebase|192\.0\.2\.)'

# Read one value from the env file without executing it.
env_get() { sed -n "s/^$1=//p" "$env_file" | tail -n 1; }

# The group with this gid, or nothing. `getent` exits 2 for a gid that has no group, and under
# `set -o pipefail` that aborted the script before its `groupadd` branch could run (B2-R2-10).
group_for_gid() { getent group "$1" 2>/dev/null | cut -d: -f1 || true; }

install_packages() {
  log "installing packages"
  export DEBIAN_FRONTEND=noninteractive
  # iptables-persistent must not snapshot the live rules on install; this script writes them.
  debconf-set-selections <<'EOF'
iptables-persistent iptables-persistent/autosave_v4 boolean false
iptables-persistent iptables-persistent/autosave_v6 boolean false
EOF
  apt-get update -q
  apt-get install -y -q ca-certificates curl gettext-base iproute2 iptables iptables-persistent \
    netfilter-persistent openssh-server rsync wireguard
}

install_docker() {
  if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
    log "docker already installed: $(docker --version)"
  else
    log "installing Docker from download.docker.com"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    local codename
    # shellcheck disable=SC1091 # /etc/os-release exists only on the host
    codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' \
      "$(dpkg --print-architecture)" "$codename" > /etc/apt/sources.list.d/docker.list
    apt-get update -q
    apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  systemctl enable --now docker
}

ensure_deploy_user() {
  if ! id -u deploy >/dev/null 2>&1; then
    log "creating the deploy user"
    useradd --create-home --shell /bin/bash deploy
  fi
  usermod -aG docker deploy
  passwd -l deploy >/dev/null # no password: SSH key only
  install -d -m 700 -o deploy -g deploy /home/deploy/.ssh

  # Password logins are off for everyone. sshd keeps the first value it reads, so this file
  # sorts before the image's own drop-ins (for example 50-cloud-init.conf).
  local sshd_dropin=/etc/ssh/sshd_config.d/05-madar.conf
  local want=$'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no'
  if [[ ! -f $sshd_dropin || $(<"$sshd_dropin") != "$want" ]]; then
    local previous=
    [[ -f $sshd_dropin ]] && previous=$(<"$sshd_dropin")
    printf '%s\n' "$want" > "$sshd_dropin"
    # sshd -t needs /run/sshd, which only exists while ssh.service runs. Ubuntu 24.04 starts sshd
    # from ssh.socket, so the directory is often missing.
    install -d -m 755 /run/sshd
    if ! sshd -t; then
      # Never leave a config sshd rejects: a socket-activated sshd reads it on the next connection.
      if [[ -n $previous ]]; then printf '%s\n' "$previous" > "$sshd_dropin"; else rm -f "$sshd_dropin"; fi
      die "sshd rejected $sshd_dropin, so it was put back as it was"
    fi
    # Reloads a running sshd; a socket-activated one reads the config on the next connection.
    systemctl try-reload-or-restart ssh.service || true
  fi
}

ensure_env_file() {
  install -d -m 750 -o deploy -g deploy /srv/madar
  if [[ ! -f $env_file ]]; then
    install -m 600 -o deploy -g deploy "$infra/compose/example.env" "$env_file"
    sed -i '/^MADAR_ENV_FILE=/d' "$env_file"
    die "created $env_file from example.env. Replace every value with the real one, then re-run."
  fi
  chown deploy:deploy "$env_file"
  chmod 600 "$env_file"
  grep -q '^MADAR_ENV_FILE=' "$env_file" && die "remove MADAR_ENV_FILE from $env_file (CI and dev only)"

  local required=(VCN_IP PEER_VCN_IP) key value
  [[ $role == vps1 ]] && required+=(VPS1_IP ACME_EMAIL FIREBASE_PROJECT_ID GHCR_OWNER POSTGRES_PASSWORD REDIS_PASSWORD \
    REDIS_HOMEBOX_PASSWORD HOME_BOX_WG_IP)
  for key in "${required[@]}"; do
    value=$(env_get "$key")
    [[ -n $value ]] || die "$key is empty in $env_file"
    if [[ $value =~ $placeholder_re ]]; then
      die "$key in $env_file still has its example value"
    fi
  done
  local address_keys=(VCN_IP PEER_VCN_IP)
  [[ $role == vps1 ]] && address_keys+=(HOME_BOX_WG_IP)
  for key in "${address_keys[@]}"; do
    [[ $(env_get "$key") =~ $ipv4_re ]] || die "$key is not an IPv4 address"
  done
  local leftovers
  leftovers=$(grep -E "^[A-Z_]+=.*$placeholder_re" "$env_file" | cut -d= -f1 | tr '\n' ' ' || true)
  [[ -z $leftovers ]] || warn "these keys in $env_file still have example values: $leftovers"

  local key_line tmp
  key_line=$(env_get DEPLOY_SSH_PUBLIC_KEY)
  tmp=$(mktemp)
  printf '%s\n' "$key_line" > "$tmp"
  if [[ -n $key_line ]] && ssh-keygen -l -f "$tmp" >/dev/null 2>&1; then
    local auth=/home/deploy/.ssh/authorized_keys
    touch "$auth"
    grep -qxF "$key_line" "$auth" || printf '%s\n' "$key_line" >> "$auth"
    chown deploy:deploy "$auth"
    chmod 600 "$auth"
  else
    warn "DEPLOY_SSH_PUBLIC_KEY is missing or invalid; CI can't deploy until it is set"
  fi
  rm -f "$tmp"
}

ensure_redis_acl_group() {
  # deploy renders the ACL; the redis user (gid 999) reads it. Docker would create a missing bind
  # source as root:root, which is why every folder here is created explicitly.
  local existing
  existing=$(group_for_gid "$acl_gid")
  if [[ -z $existing ]]; then
    log "creating group $acl_group (gid $acl_gid, the redis user's)"
    groupadd --gid "$acl_gid" "$acl_group"
    existing=$acl_group
  fi
  usermod -aG "$existing" deploy
  # 750, group 999: the directory has to be traversable by the redis user, not only the file
  # (B2-R2-1). Re-run after an older bootstrap to correct it.
  install -d -m 750 -o deploy -g "$existing" /srv/madar/redis
}

ensure_dirs() {
  log "creating /srv folders"
  install -d -m 750 -o deploy -g deploy /srv/madar /srv/madar/infra
  install -d -m 755 -o deploy -g deploy /srv/snapshot /srv/app-mirror
  install -d -m 755 -o "$app_uid" -g "$app_uid" /srv/media /srv/reports
  if [[ $role == vps1 ]]; then
    install -d -m 755 -o deploy -g deploy /srv/admin
    [[ -f /srv/admin/index.html ]] \
      || install -m 644 -o deploy -g deploy "$infra/admin-placeholder/index.html" /srv/admin/index.html
  fi
  if [[ $role == vps2 ]]; then
    # The raw pages. Docker would create the missing bind source as root:root, and the uid-10001
    # workers with cap_drop ALL could not write it (B2-R1-5).
    install -d -m 755 -o "$app_uid" -g "$app_uid" /srv/raw
    # D3: the backup staging file, Uptime Kuma's SQLite, and the FCM service account. The secrets
    # directory and the key belong to the image's user, because only worker-notify mounts it (R9).
    install -d -m 700 -o deploy -g deploy /srv/backup
    install -d -m 755 -o deploy -g deploy /srv/kuma
    install -d -m 700 -o "$app_uid" -g "$app_uid" /srv/secrets
  fi
}

setup_wireguard_hub() {
  log "setting up the WireGuard hub 10.8.0.1/24"
  install -d -m 700 /etc/wireguard
  if [[ ! -s /etc/wireguard/wg0.key ]]; then
    (umask 077 && wg genkey > /etc/wireguard/wg0.key)
  fi
  if [[ ! -f /etc/wireguard/wg0.conf ]]; then
    # shellcheck disable=SC2016 # envsubst takes the variable name literally
    (umask 077 && HUB_PRIVATE_KEY=$(< /etc/wireguard/wg0.key) envsubst '${HUB_PRIVATE_KEY}' \
      < "$infra/wireguard/wg0.conf.tmpl" > /etc/wireguard/wg0.conf)
  fi
  systemctl enable --now wg-quick@wg0
  log "hub public key: $(wg pubkey < /etc/wireguard/wg0.key)"
}

docker_after_wg0() {
  local dir=/etc/systemd/system/docker.service.d
  local dropin=$dir/10-after-wg0.conf
  local want=$'[Unit]\nWants=wg-quick@wg0.service\nAfter=wg-quick@wg0.service'
  install -d "$dir"
  if [[ ! -f $dropin || $(<"$dropin") != "$want" ]]; then
    log "making docker.service start after wg-quick@wg0"
    printf '%s\n' "$want" > "$dropin"
    systemctl daemon-reload
  fi
}

# Sets keep_public_ssh=1 or 0.
decide_public_ssh() {
  keep_public_ssh=1
  if [[ ! -f $serial_mark ]]; then
    local answer=
    if [[ $serial_flag == no && -t 0 ]]; then
      read -r -p "[bootstrap] Have you logged in through this host's OCI serial console? Type 'serial console tested' to close public SSH: " answer
    fi
    if [[ $serial_flag == yes || $answer == "serial console tested" ]]; then
      install -d -m 755 "$state_dir"
      printf 'serial console confirmed tested on %s by %s\n' "$(date -u +%FT%TZ)" "${SUDO_USER:-root}" > "$serial_mark"
    fi
  fi
  if [[ ! -f $serial_mark ]]; then
    warn "public SSH stays OPEN: test the OCI serial console, then re-run with --serial-console-tested"
    return
  fi
  if [[ $role == vps1 ]] && ! wg show wg0 latest-handshakes 2>/dev/null | awk '$2 > 0 { found = 1 } END { exit !found }'; then
    warn "public SSH stays OPEN: no WireGuard peer has connected yet. Add yours with wg-add-peer.sh, connect, then re-run"
    return
  fi
  keep_public_ssh=0
}

apply_firewall() {
  install -d -m 755 /etc/iptables
  if [[ ! -e $oci_rules_backup ]]; then
    if [[ -f /etc/iptables/rules.v4 ]]; then
      cp -p /etc/iptables/rules.v4 "$oci_rules_backup"
    else
      : > "$oci_rules_backup"
    fi
  fi

  local ssh_rule=
  ((keep_public_ssh)) && ssh_rule=$public_ssh_rule
  local oci_rules
  oci_rules=$(grep -E '^-A (OUTPUT .*-j InstanceServices$|InstanceServices )' "$oci_rules_backup" || true)

  local rendered
  rendered=$(mktemp)
  # shellcheck disable=SC2016 # envsubst takes the variable names literally
  VCN_IP=$(env_get VCN_IP) PEER_VCN_IP=$(env_get PEER_VCN_IP) HOME_BOX_WG_IP=$(env_get HOME_BOX_WG_IP) \
    envsubst '${VCN_IP} ${PEER_VCN_IP} ${HOME_BOX_WG_IP}' < "$infra/firewall/$role.rules" \
    | SSH_RULE=$ssh_rule OCI_RULES=$oci_rules awk '
        $0 == "# @PUBLIC_SSH@" { if (ENVIRON["SSH_RULE"] != "") print ENVIRON["SSH_RULE"]; next }
        $0 == "# @OCI_INSTANCE_SERVICES@" { if (ENVIRON["OCI_RULES"] != "") print ENVIRON["OCI_RULES"]; next }
        { print }' > "$rendered"
  iptables-restore --test < "$rendered" || die "the rendered IPv4 rules don't parse (kept in $rendered)"
  ip6tables-restore --test < "$infra/firewall/rules.v6" || die "infra/firewall/rules.v6 doesn't parse"

  if cmp -s "$rendered" /etc/iptables/rules.v4 && cmp -s "$infra/firewall/rules.v6" /etc/iptables/rules.v6 \
    && "$infra/scripts/check-firewall.sh" >/dev/null 2>&1; then
    log "firewall already up to date"
  else
    log "applying the firewall (public SSH: $( ((keep_public_ssh)) && echo open || echo closed ))"
    install -m 640 "$rendered" /etc/iptables/rules.v4
    install -m 640 "$infra/firewall/rules.v6" /etc/iptables/rules.v6
    iptables-restore < /etc/iptables/rules.v4
    ip6tables-restore < /etc/iptables/rules.v6
    # A full restore removes Docker's chains; a restart recreates them (containers restart too).
    if systemctl is-active --quiet docker; then
      systemctl restart docker
    fi
  fi
  rm -f "$rendered"
  systemctl enable netfilter-persistent >/dev/null
  "$infra/scripts/check-firewall.sh"
}

main() {
  install_packages
  install_docker
  ensure_deploy_user
  ensure_env_file
  [[ $role == vps1 ]] && ensure_redis_acl_group
  ensure_dirs
  # check-firewall.sh reads this to know which expectations apply (B2-R1-6).
  install -d -m 755 "$state_dir"
  printf '%s\n' "$role" > "$state_dir/host-role"
  if [[ $role == vps1 ]]; then
    setup_wireguard_hub
    docker_after_wg0
  fi
  decide_public_ssh
  apply_firewall
  log "done: $role is bootstrapped. Reboot once and run check-firewall.sh to prove the rules persist."
}

main
