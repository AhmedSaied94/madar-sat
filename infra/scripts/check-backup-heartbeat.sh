#!/usr/bin/env bash
# Prove a failed backup reports `down` to Uptime Kuma, whatever form the push URL has in `.env`
# (B2-R2-1). Usage: infra/scripts/check-backup-heartbeat.sh   (needs bash, curl and python3)
#
# Kuma shows a push monitor's URL as `…/api/push/<token>?status=up&msg=OK&ping=`. Both backup
# scripts used to append `?status=down&msg=…` to whatever `.env` held, so the `down` landed inside
# `ping` and Kuma recorded `up`: a backup that failed every night never raised the 25 h alarm.
#
# It runs the real scripts with `pg_dump` and `rclone` stubbed to fail (and to succeed), against a
# local HTTP stub that records the `status` and `msg` each push carries, with a Kuma-style URL and
# with the bare URL the runbook now documents. No database, bucket, restic or network is involved.
set -Eeuo pipefail

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

for tool in curl python3; do
  command -v "$tool" >/dev/null || { echo "check-backup-heartbeat: $tool is not installed" >&2; exit 2; }
done

tmp=$(mktemp -d)
stub_pid=
cleanup() {
  [[ -z $stub_pid ]] || kill "$stub_pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  printf 'check-backup-heartbeat: %s\n' "$*" >&2
  exit 1
}

# --- the Kuma stand-in: logs `status=<s> msg=<m>` for every push it receives ---------------------
cat > "$tmp/kuma.py" <<'STUB'
import http.server
import sys
import urllib.parse

log_file, port_file = sys.argv[1:3]


class Push(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
        with open(log_file, "a") as log:
            log.write("status=%s msg=%s\n" % (query.get("status", [""])[0], query.get("msg", [""])[0]))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"ok":true}')

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(("127.0.0.1", 0), Push)
with open(port_file, "w") as port:
    port.write(str(server.server_port))
server.serve_forever()
STUB
python3 "$tmp/kuma.py" "$tmp/pushes.log" "$tmp/port" &
stub_pid=$!
for _ in $(seq 1 50); do
  [[ -s $tmp/port ]] && break
  sleep 0.1
done
[[ -s $tmp/port ]] || fail "the Kuma stub did not start"
kuma="http://127.0.0.1:$(cat "$tmp/port")/api/push/ci-token"

# --- the scripts' two external commands, replaced ------------------------------------------------
mkdir -p "$tmp/bin" "$tmp/staging" "$tmp/media"
cat > "$tmp/bin/pg_dump" <<'STUB'
#!/usr/bin/env bash
exit "${STUB_EXIT:-1}"
STUB
cat > "$tmp/bin/rclone" <<'STUB'
#!/usr/bin/env bash
exit "${STUB_EXIT:-1}"
STUB
chmod +x "$tmp/bin/pg_dump" "$tmp/bin/rclone"
export PATH="$tmp/bin:$PATH"

export RESTIC_REPOSITORY="$tmp/repo"
export RESTIC_PASSWORD=ci-password
export B2_ACCOUNT_ID=ci-account
export B2_ACCOUNT_KEY=ci-key
export POSTGRES_PASSWORD=ci-password
export BACKUP_DB_HOST=127.0.0.1
export BACKUP_STAGING="$tmp/staging"
export MEDIA_ROOT="$tmp/media"
export RCLONE_CONFIG_OCI_ACCESS_KEY_ID=ci
export RCLONE_CONFIG_OCI_SECRET_ACCESS_KEY=ci

# The last push the stub saw, as `status=<s> msg=<m>`; empty when it saw none since the last reset.
last_push() { tail -n 1 "$tmp/pushes.log" 2>/dev/null || true; }

# A script whose command fails must exit non-zero and push `down`; the same script with the
# command succeeding must push `up`. $1 names the case, $2 the script, $3 the variable that holds
# its push URL, $4 the URL under test, $5 an optional flag for the script.
expect_down() {
  local name=$1 script=$2 variable=$3 url=$4 code=0 pushed
  local -a flag=()
  [[ -z ${5:-} ]] || flag=("$5")
  : > "$tmp/pushes.log"
  env "$variable=$url" STUB_EXIT=1 "$infra/backup/$script" "${flag[@]}" >/dev/null 2>&1 || code=$?
  ((code != 0)) || fail "$name: the script exited 0 although its command failed"
  pushed=$(last_push)
  [[ $pushed == status=down\ msg=* ]] \
    || fail "$name: a failed run pushed '${pushed:-nothing}' to $url; Kuma would not see it as down"
}

expect_up() {
  local name=$1 script=$2 variable=$3 url=$4 pushed
  : > "$tmp/pushes.log"
  # rclone succeeds; the media script then has nothing else to do in its nightly mode.
  env "$variable=$url" STUB_EXIT=0 "$infra/backup/$script" >/dev/null 2>&1 \
    || fail "$name: the script failed with its command stubbed to succeed"
  pushed=$(last_push)
  [[ $pushed == status=up\ msg=* ]] || fail "$name: a good run pushed '${pushed:-nothing}', not up"
}

kuma_style="$kuma?status=up&msg=OK&ping="

# The URL as Kuma displays it (what an owner pastes), and the bare one the runbook documents.
for url in "$kuma_style" "$kuma"; do
  if [[ $url == "$kuma" ]]; then form="bare"; else form="kuma-style"; fi
  expect_down "backup-db ($form URL)" backup-db.sh KUMA_PUSH_URL_BACKUP_DB "$url"
  expect_down "backup-media ($form URL)" backup-media.sh KUMA_PUSH_URL_BACKUP_MEDIA "$url"
  expect_down "backup-media --weekly ($form URL)" backup-media.sh KUMA_PUSH_URL_BACKUP_MEDIA_WEEKLY "$url" --weekly
done
expect_up "backup-media (kuma-style URL)" backup-media.sh KUMA_PUSH_URL_BACKUP_MEDIA "$kuma_style"

printf 'check-backup-heartbeat: ok (a failed backup pushes status=down on a Kuma-style and a bare push URL)\n'
