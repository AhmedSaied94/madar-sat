# Exposure check

Checks what the internet can reach on both VMs, and that the public sites carry valid certificates and the security headers. It is T065 (SC-009), and worth repeating after any firewall, Caddy or Compose change. It only reads; it changes nothing. Background: SD §7.2 and §8, and the Lane B2 section of `specs/001-d01-foundation/quickstart.md`.

## Before you start

- A machine **off** WireGuard: disconnect the tunnel. Another network than the one you administer from is better still.
- `nmap`, `curl`, `openssl` and `jq`. On Arch: `sudo pacman -S nmap`.
- The admin CA root on your device, for step 3 ([private-network.md](private-network.md#install-the-admin-ca-root)).

## 1. Ports

```bash
nmap -Pn -p 22,80,443,5432,6379,8000,8001 <ip1>     # 80 and 443 open; everything else filtered
sudo nmap -Pn -sU -p 51820 <ip1>                       # open|filtered
nmap -Pn -p 22,80,443,5432,6379,5555,8000 <ip2>       # everything filtered
```

- `filtered` is right for a closed port: the security list drops it, or iptables rejects it.
- WireGuard never answers a packet from an unknown key, so `nmap` can't tell 51820 from a closed port. Prove it answers with your own tunnel instead: connect, and check that `sudo wg show wg0` on VPS-1 shows a fresh handshake for your peer.

## 2. Certificates and headers

```bash
curl -sSI https://api.<ip1>.sslip.io/healthz
curl -sSI https://media.<ip1>.sslip.io/
curl -sSI https://app.<ip1>.sslip.io/
```

Each response must carry:

| Header | Value |
| --- | --- |
| `strict-transport-security` | `max-age=31536000; includeSubDomains` |
| `x-content-type-options` | `nosniff` |
| `referrer-policy` | `strict-origin-when-cross-origin` |
| `server` | Absent |

`media.` and `app.` may answer `404` at `/` (nothing is published there yet). The headers still apply. `media.` also sends `cache-control: public, max-age=31536000, immutable`.

```bash
curl -s https://api.<ip1>.sslip.io/healthz | jq .data       # {"db": "ok", "redis": "ok"}
curl -sI http://api.<ip1>.sslip.io/healthz | head -1          # a 308 redirect to https
for h in api media app; do
  echo | openssl s_client -connect "$h.<ip1>.sslip.io:443" -servername "$h.<ip1>.sslip.io" 2>/dev/null \
    | openssl x509 -noout -subject -issuer -enddate
done
```

The issuer is Let's Encrypt (or ZeroSSL, Caddy's fallback), and the end date is in the future. If not, see [tls-certificates.md](tls-certificates.md).

The PWA mirror allows only the two PWA origins:

```bash
curl -sI -H 'Origin: https://<project>.web.app' https://app.<ip1>.sslip.io/ | grep -i access-control-allow-origin   # echoes the origin
curl -sI -H 'Origin: https://example.org' https://app.<ip1>.sslip.io/ | grep -i access-control-allow-origin        # nothing
```

## 3. The admin isn't public

Off WireGuard:

```bash
curl -sk --max-time 5 -o /dev/null -w '%{http_code}\n' https://10.8.0.1/                      # 000: no route
curl -sk --max-time 5 -o /dev/null -w '%{http_code}\n' -H 'Host: 10.8.0.1' https://<ip1>/     # 000: the public listener has no site for it
```

Then connect the tunnel and check that it does answer:

```bash
curl -s --cacert madar-admin-root.crt https://10.8.0.1/admin/api/healthz | jq .data            # {"db": "ok", "redis": "ok"}
```

`api-admin` itself (`10.8.0.1:8001`) is reachable only from `wg0`: `8001` must show `filtered` in step 1.

## 4. Record

Paste the `nmap` output and the header checks into the notes for T065 (or the PR that ticks it), with the date. If anything is open that shouldn't be, stop and fix it before you go on: [firewall-changes.md](firewall-changes.md) for iptables, [provision-host.md §1](provision-host.md#1-reserve-the-ip-and-create-the-vm) for the security list.
