# TLS certificates and hostnames

There's no domain yet. The public hostnames use sslip.io, which answers a name with an IP in it (`api.130.110.117.215.sslip.io`) with that IP, so there is no DNS to manage. Caddy on VPS-1 gets a Let's Encrypt certificate for each of `api.`, `media.` and `app.130.110.117.215.sslip.io` over ports 80 and 443, stores it in the `madar_caddy_data` volume, and renews it on its own, about 30 days before it expires. The admin site uses Caddy's own CA instead ([private-network.md](private-network.md#install-the-admin-ca-root)). Background: SD §3 (O4), §7.2, research R12, and `infra/Caddyfile`.

## Check the certificates

From anywhere:

```bash
for h in api media app; do
  echo | openssl s_client -connect "$h.130.110.117.215.sslip.io:443" -servername "$h.130.110.117.215.sslip.io" 2>/dev/null \
    | openssl x509 -noout -subject -issuer -enddate
done
```

On VPS-1, over WireGuard, Caddy's log shows each issuance and renewal:

```bash
sudo docker logs --since 24h madar-caddy-1 2>&1 | grep -Ei 'certificate|acme|tls|error'
```

## First issuance

This is T058's last step. The first infra sync (README.md stage 4) starts Caddy, which asks for the three certificates within a minute or two. It needs:

- TCP 80 and 443 open in the security list and in VPS-1's iptables;
- `ACME_EMAIL` and `VPS1_IP` set in `/srv/madar/.env`;
- the names resolving: `dig +short api.130.110.117.215.sslip.io` prints `130.110.117.215`.

When all three show a Let's Encrypt issuer ("Check the certificates" above), tick T058.

## When issuance fails

| Log shows | Cause | Do |
| --- | --- | --- |
| Timeouts or `connection refused` on the challenge | Port 80 or 443 is blocked | The security list ([provision-host.md §1](provision-host.md#1-reserve-the-ip-and-create-the-vm)) and `sudo iptables -S INPUT`. Run [exposure-check.md](exposure-check.md). |
| `no such host`, or DNS errors | sslip.io isn't resolving | Nothing to fix on our side. Wait, and check `dig +short api.130.110.117.215.sslip.io`. A domain (O4) removes this dependency. |
| `rateLimited`, `too many certificates` | Let's Encrypt's limits. One is 5 certificates per exact set of names per week. | Wait it out. Caddy tries its other default issuer, ZeroSSL, meanwhile. |

**Don't delete the `madar_caddy_data` volume** to "start over". It holds the certificates, the ACME account, and the admin site's CA root. Losing it means new certificates (counted against the rate limits) and a new admin root on every device.

## If a public IP changes

A reserved IP survives a rebuild, so this happens only if the reservation itself is released. Everything that has `130.110.117.215` in it then changes:

| Where | What | Who |
| --- | --- | --- |
| VPS-1's `/srv/madar/.env` | `VPS1_IP`, `MEDIA_BASE_URL` | You |
| GitHub variable | `VPS1_IP` | You |
| Every WireGuard client config | `Endpoint = 130.110.117.215:51820`: edit it on each device, and in `WG_CI_CONFIG` | You |
| Firebase Remote Config | `api_base_url`, `media_base_url` (SD §5.1), once the app reads them | You, then Lane M |
| `app/env/prod.json` | The bundled API and media defaults (research R16) | Lane M, with a new release |
| The PWA's mirror address | `app.130.110.117.215.sslip.io` (from D4) | Lane M |
| The hosts tables | [README.md](README.md), [provision-host.md](provision-host.md#the-two-vms) | You |

These don't change:

- The Caddyfile reads `{$VPS1_IP}`, and the security list works by subnet.
- `CORS_ORIGINS` lists the PWA's origins on `web.app`.
- Stored media URLs: the API builds them from `MEDIA_BASE_URL` when it answers. The ETags include it, so clients refetch.

Then, in the "Working on VPS-1" shell ([deploy-and-rollback.md](deploy-and-rollback.md#working-on-vps-1)), recreate what reads the file:

```bash
dc up -d --force-recreate caddy api-public api-admin
```

Caddy then asks for certificates for the new names.

## A domain later

Buying a domain (O4, scheduled for D13–D14) replaces sslip.io. Update this runbook in that change: the new names, DNS records, and moving the admin site to a publicly trusted certificate.
